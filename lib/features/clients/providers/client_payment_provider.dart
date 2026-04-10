import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/clients/domain/models/client_payment.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';
import 'package:danaya_plus/features/finance/domain/models/financial_account.dart';
import 'package:danaya_plus/core/network/client_sync_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';

final clientPaymentsProvider = FutureProvider.family<List<ClientPayment>, String>((ref, clientId) async {
  final db = await ref.read(databaseServiceProvider).database;
  final maps = await db.query(
    'client_payments',
    where: 'client_id = ?',
    whereArgs: [clientId],
    orderBy: 'date DESC',
  );
  return maps.map((m) => ClientPayment.fromMap(m)).toList();
});

final clientPaymentActionsProvider = Provider((ref) => ClientPaymentActions(ref));

class ClientPaymentActions {
  final Ref ref;
  ClientPaymentActions(this.ref);

  Future<void> addPayment(ClientPayment payment) async {
    final db = await ref.read(databaseServiceProvider).database;
    final activeSession = await ref.read(activeSessionProvider.future);
    
    await db.transaction((txn) async {
      // --- 1. STRICT VULNERABILITY CHECKS ---
      final clientRow = await txn.query('clients', columns: ['credit', 'name'], where: 'id = ?', whereArgs: [payment.clientId]);
      if (clientRow.isNotEmpty) {
        final currentCredit = (clientRow.first['credit'] as num).toDouble();
        if (payment.amount > currentCredit) {
           final name = clientRow.first['name'] as String;
           final settings = ref.read(shopSettingsProvider).value;
           final currency = settings?.currency ?? 'FCFA';
           throw Exception("Surpaiement refusé : Le solde de la dette de '$name' est de $currentCredit $currency. Le paiement (${payment.amount} $currency) l'excède.");
        }
      }

      // 1. Insert payment record
      await txn.insert('client_payments', payment.toMap());

      // 2. Update client credit
      await txn.rawUpdate(
        'UPDATE clients SET credit = credit - ? WHERE id = ?',
        [payment.amount, payment.clientId],
      );

      // 3. Create financial transaction
      final tx = FinancialTransaction(
        accountId: payment.accountId,
        type: TransactionType.IN,
        amount: payment.amount,
        category: TransactionCategory.DEBT_REPAYMENT,
        description: payment.description ?? "Remboursement de dette client",
        date: payment.date,
        referenceId: payment.id,
        sessionId: activeSession?.id,
      );
      await txn.insert('financial_transactions', tx.toMap());

      // 4. Update account balance
      await txn.rawUpdate(
        'UPDATE financial_accounts SET balance = balance + ? WHERE id = ?',
        [payment.amount, payment.accountId],
      );
    });

    // Refresh providers
    ref.invalidate(clientPaymentsProvider(payment.clientId));
    ref.invalidate(clientListProvider);
    ref.read(treasuryProvider.notifier).refresh();

    // --- SYNCHRO RÉSEAU ---
    ref.read(clientSyncProvider).syncPendingAuditData();
  }
}

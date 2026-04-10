import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';
import 'package:danaya_plus/core/network/client_sync_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:uuid/uuid.dart';

final clientListProvider =
    AsyncNotifierProvider<ClientListNotifier, List<Client>>(() {
  return ClientListNotifier();
});

class ClientListNotifier extends AsyncNotifier<List<Client>> {
  @override
  Future<List<Client>> build() async {
    return _fetchAll();
  }

  Future<List<Client>> _fetchAll() async {
    final db = await ref.read(databaseServiceProvider).database;
    final maps = await db.query('clients', orderBy: 'name ASC');
    return maps.map((map) => Client.fromMap(map)).toList();
  }

  Future<void> addClient(Client client) async {
    final db = await ref.read(databaseServiceProvider).database;
    await db.insert('clients', client.toMap());
    state = AsyncData(await _fetchAll());

    // --- SYNCHRO RÉSEAU ---
    final settings = ref.read(shopSettingsProvider).value;
    if (settings?.networkMode == NetworkMode.client) {
      ref.read(clientSyncProvider).sendClientToServer(client);
      ref.read(clientSyncProvider).syncPendingAuditData();
    }
  }

  Future<void> updateClient(Client client) async {
    final db = await ref.read(databaseServiceProvider).database;
    await db.update(
      'clients',
      client.toMap(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
    state = AsyncData(await _fetchAll());

    // --- SYNCHRO RÉSEAU ---
    final settings = ref.read(shopSettingsProvider).value;
    if (settings?.networkMode == NetworkMode.client) {
      ref.read(clientSyncProvider).sendClientToServer(client);
      ref.read(clientSyncProvider).syncPendingAuditData();
    }
  }

  Future<void> deleteClient(String id) async {
    final db = await ref.read(databaseServiceProvider).database;
    await db.delete('clients', where: 'id = ?', whereArgs: [id]);
    state = AsyncData(await _fetchAll());
  }

  Future<void> addCredit(String clientId, double amount) async {
    final db = await ref.read(databaseServiceProvider).database;
    await db.rawUpdate(
      'UPDATE clients SET credit = credit + ? WHERE id = ?',
      [amount, clientId],
    );
    state = AsyncData(await _fetchAll());
  }

  Future<void> settleDebt({
    required String clientId,
    required double amount,
    required String accountId,
    String? description,
    String paymentMethod = 'CASH',
  }) async {
    final db = await ref.read(databaseServiceProvider).database;
    final activeSession = await ref.read(activeSessionProvider.future);
    final user = await ref.read(authServiceProvider.future);
    
    await db.transaction((txn) async {
      // --- 1. STRICT VULNERABILITY CHECKS ---
      final clientRow = await txn.query('clients', columns: ['credit', 'name'], where: 'id = ?', whereArgs: [clientId]);
      if (clientRow.isNotEmpty) {
        final currentCredit = (clientRow.first['credit'] as num).toDouble();
        if (amount > currentCredit) {
           final name = clientRow.first['name'] as String;
           final settings = ref.read(shopSettingsProvider).value;
           final currency = settings?.currency ?? 'FCFA';
           throw Exception("Surpaiement refusé : Le solde de la dette de '$name' est de $currentCredit $currency. Le paiement ($amount $currency) l'excède.");
        }
      }

      // 1. Réduire la dette du client
      await txn.rawUpdate(
        'UPDATE clients SET credit = credit - ? WHERE id = ?',
        [amount, clientId],
      );

      // 2. Enregistrer la transaction dans la trésorerie
      final txId = const Uuid().v4();
      await txn.insert('financial_transactions', {
        'id': txId,
        'account_id': accountId,
        'amount': amount,
        'type': 'IN',
        'category': 'DEBT_REPAYMENT', 
        'description': description ?? 'Règlement de dette client',
        'date': DateTime.now().toIso8601String(),
        'session_id': activeSession?.id,
      });
      
      // 3. Enregistrer dans client_payments (pour l'historique détaillé)
      final cpId = 'pay_${const Uuid().v4()}';
      await txn.insert('client_payments', {
        'id': cpId,
        'client_id': clientId,
        'account_id': accountId,
        'amount': amount,
        'date': DateTime.now().toIso8601String(),
        'payment_method': paymentMethod,
        'description': description,
        'user_id': user?.id ?? 'sysadmin',
        'session_id': activeSession?.id,
      });

      // 3. Mettre à jour le solde du compte
      await txn.execute(
        'UPDATE financial_accounts SET balance = balance + ? WHERE id = ?',
        [amount, accountId],
      );
    });

    state = AsyncData(await _fetchAll());
    // Invalidate treasury to reflect the new balance
    ref.invalidate(treasuryProvider);

    // --- SYNCHRO RÉSEAU ---
    ref.read(clientSyncProvider).syncPendingAuditData();
  }

  Future<void> search(String query) async {
    state = const AsyncLoading();
    if (query.isEmpty) {
      state = AsyncData(await _fetchAll());
    } else {
      final db = await ref.read(databaseServiceProvider).database;
      
      // Supreme Performance: Use FTS5 MATCH for ultra-fast client search
      final cleanQuery = query.replaceAll("'", "''");
      final ftsQuery = "$cleanQuery*";

      final maps = await db.rawQuery('''
        SELECT c.* 
        FROM clients c
        JOIN clients_fts fts ON c.id = fts.id
        WHERE clients_fts MATCH ?
        ORDER BY rank, c.name ASC
      ''', [ftsQuery]);
      
      state = AsyncData(maps.map((map) => Client.fromMap(map)).toList());
    }
  }
}

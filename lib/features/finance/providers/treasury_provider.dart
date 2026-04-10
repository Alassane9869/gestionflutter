import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/finance/domain/models/financial_account.dart';
import 'package:uuid/uuid.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';
import 'package:danaya_plus/core/network/client_sync_service.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';

final treasuryProvider = AsyncNotifierProvider<TreasuryNotifier, List<FinancialAccount>>(() {
  return TreasuryNotifier();
});

/// Filtrage intelligent des comptes selon les droits de l'employé connecté
final myTreasuryAccountsProvider = Provider<AsyncValue<List<FinancialAccount>>>((ref) {
  final user = ref.watch(authServiceProvider).value;
  final accountsAsync = ref.watch(treasuryProvider);

  if (user == null || accountsAsync.isLoading) return const AsyncValue.loading();
  if (accountsAsync.hasError) return AsyncValue.error(accountsAsync.error!, accountsAsync.stackTrace!);

  final accounts = accountsAsync.value!;
  
  // Apply filtering based on user permissions
  final filtered = accounts.where((a) => user.canAccessAccount(a.id)).toList();
  
  // FALLBACK: If no accounts are assigned, use the default cash account if available
  if (filtered.isEmpty && accounts.isNotEmpty) {
    try {
      final defaultAcc = accounts.firstWhere((a) => a.isDefault && a.type == AccountType.CASH);
      return AsyncValue.data([defaultAcc]);
    } catch (_) {
      // No default cash account, maybe just the first account as last resort?
      return AsyncValue.data([accounts.first]);
    }
  }
  
  return AsyncValue.data(filtered);
});

class TreasuryNotifier extends AsyncNotifier<List<FinancialAccount>> {
  bool _isProcessing = false;

  @override
  FutureOr<List<FinancialAccount>> build() async {
    return _fetchAccounts();
  }

  Future<List<FinancialAccount>> _fetchAccounts() async {
    final db = await ref.read(databaseServiceProvider).database;
    final List<Map<String, dynamic>> maps = await db.query('financial_accounts');
    return maps.map((m) => FinancialAccount.fromMap(m)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final accounts = await _fetchAccounts();
      state = AsyncValue.data(accounts);
      
      // Invalidate related providers to force refresh
      ref.invalidate(transactionHistoryProvider);
      ref.invalidate(financialStatsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTransaction(FinancialTransaction tx) async {
    if (_isProcessing) {
      debugPrint("⛔ Bloqué : Une transaction est déjà en cours de traitement.");
      return;
    }
    _isProcessing = true;
    try {
      final db = await ref.read(databaseServiceProvider).database;
      
      // Auto-attach sessionId if missing and a session is active
      FinancialTransaction finalTx = tx;
      if (tx.sessionId == null) {
      try {
        final activeSession = await ref.read(activeSessionProvider.future);
        if (activeSession != null) {
           finalTx = FinancialTransaction(
            id: tx.id,
            accountId: tx.accountId,
            type: tx.type,
            amount: tx.amount,
            category: tx.category,
            description: tx.description,
            date: tx.date,
            referenceId: tx.referenceId,
            sessionId: activeSession.id,
          );
        }
      } catch (_) {
        // Fallback if provider fails
      }
    }

    // --- SÉCURITÉ : BLOCAGE SOLDE NÉGATIF ---
    if (finalTx.type == TransactionType.OUT) {
      final accounts = state.asData?.value ?? await _fetchAccounts();
      final account = accounts.firstWhere((a) => a.id == finalTx.accountId);
      if (account.balance < finalTx.amount) {
        throw Exception(
          "Opération impossible : Solde insuffisant sur le compte '${account.name}'. "
          "Disponible : ${account.balance}. Montant requis : ${finalTx.amount}."
        );
      }
    }

    await db.transaction((txn) async {
      // 1. Enregistrer la transaction
      await txn.insert('financial_transactions', finalTx.toMap());

      // 2. Mettre à jour le solde du compte
      final double adjustment = finalTx.type == TransactionType.IN ? finalTx.amount : -finalTx.amount;
      await txn.execute(
        'UPDATE financial_accounts SET balance = balance + ? WHERE id = ?',
        [adjustment, finalTx.accountId],
      );
    });
    
      // --- SYNCHRO RÉSEAU ---
      ref.read(clientSyncProvider).syncPendingAuditData();

      refresh();
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> deleteTransaction(FinancialTransaction tx) async {
    final db = await ref.read(databaseServiceProvider).database;
    await db.transaction((txn) async {
      // 1. Inverser l'ajustement de solde
      final double adjustment = tx.type == TransactionType.IN ? -tx.amount : tx.amount;
      await txn.execute(
        'UPDATE financial_accounts SET balance = balance + ? WHERE id = ?',
        [adjustment, tx.accountId],
      );

      // 2. Supprimer la transaction
      await txn.delete('financial_transactions', where: 'id = ?', whereArgs: [tx.id]);
    });
    refresh();
  }

  Future<void> createAccount(String name, AccountType type, {double balance = 0.0, String? operator, bool isDefault = false}) async {
    final db = await ref.read(databaseServiceProvider).database;
    final id = 'acc_${const Uuid().v4()}';

    // If setting as default, unset all other defaults of same type first
    if (isDefault) {
      await db.execute(
        "UPDATE financial_accounts SET is_default = 0 WHERE type = ?",
        [type.name],
      );
    }

    await db.insert('financial_accounts', {
      'id': id,
      'name': name,
      'type': type.name,
      'balance': balance,
      'is_default': isDefault ? 1 : 0,
      'operator': operator,
    });
    refresh();
  }

  Future<FinancialAccount?> getDefaultAccount(AccountType type) async {
    final accounts = state.asData?.value;
    if (accounts == null) return null;
    try {
      return accounts.firstWhere((a) => a.type == type && a.isDefault);
    } catch (_) {
      try {
        return accounts.firstWhere((a) => a.type == type);
      } catch (_) {
        return accounts.isNotEmpty ? accounts.first : null;
      }
    }
  }

  Future<void> setDefaultAccount(String accountId) async {
    final db = await ref.read(databaseServiceProvider).database;
    // Get the account to find its type
    final result = await db.query('financial_accounts', where: 'id = ?', whereArgs: [accountId]);
    if (result.isEmpty) return;
    final type = result.first['type'] as String;

    // Unset all defaults of same type, then set this one
    await db.execute("UPDATE financial_accounts SET is_default = 0 WHERE type = ?", [type]);
    await db.execute("UPDATE financial_accounts SET is_default = 1 WHERE id = ?", [accountId]);
    refresh();
  }

  Future<void> updateAccountName(String accountId, String newName) async {
    final db = await ref.read(databaseServiceProvider).database;
    await db.update(
      'financial_accounts',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [accountId],
    );
    refresh();
  }

  Future<void> deleteAccount(String accountId) async {
    final db = await ref.read(databaseServiceProvider).database;
    
    // VERIFICATION: Ne pas permettre la suppression s'il y a un historique
    final countTarget = await db.rawQuery(
      'SELECT COUNT(*) as count FROM financial_transactions WHERE account_id = ?',
      [accountId],
    );
    final count = countTarget.first['count'] as int;
    if (count > 0) {
      throw Exception('Ce compte contient un historique de $count transaction(s). La suppression détruirait ces archives comptables. Veuillez plutôt le renommer ou ne plus l\'utiliser.');
    }

    await db.delete('financial_accounts', where: 'id = ?', whereArgs: [accountId]);
    refresh();
  }
}

// Provider for transaction history — filtered per user
final transactionHistoryProvider = FutureProvider<List<FinancialTransaction>>((ref) async {
  final db = await ref.read(databaseServiceProvider).database;
  final user = ref.watch(authServiceProvider).value;

  final List<Map<String, dynamic>> maps = await db.query(
    'financial_transactions',
    orderBy: 'date DESC',
    limit: 100,
  );
  final allTx = maps.map((m) => FinancialTransaction.fromMap(m)).toList();

  // Admin/Manager/AdminPlus → tout voir. Employé → ses comptes seulement
  if (user == null || user.role == UserRole.admin || user.role == UserRole.manager || user.role == UserRole.adminPlus) {
    return allTx;
  }
  return allTx.where((tx) => user.canAccessAccount(tx.accountId)).toList();
});

// Stats for Quick Report — filtered per user
final financialStatsProvider = FutureProvider<Map<String, double>>((ref) async {
  final db = await ref.read(databaseServiceProvider).database;
  final user = ref.watch(authServiceProvider).value;
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

  // Admin/Manager/AdminPlus → requête globale (pas de filtre)
  if (user == null || user.role == UserRole.admin || user.role == UserRole.manager || user.role == UserRole.adminPlus) {
    final resultIn = await db.rawQuery(
      "SELECT SUM(amount) as total FROM financial_transactions WHERE type = 'IN' AND date >= ?",
      [thirtyDaysAgo]
    );
    final resultOut = await db.rawQuery(
      "SELECT SUM(amount) as total FROM financial_transactions WHERE type = 'OUT' AND date >= ?",
      [thirtyDaysAgo]
    );
    return {
      'in': (resultIn.first['total'] as num?)?.toDouble() ?? 0.0,
      'out': (resultOut.first['total'] as num?)?.toDouble() ?? 0.0,
    };
  }

  // Employé → ne compter que les transactions de ses comptes assignés
  final myAccounts = ref.watch(myTreasuryAccountsProvider).value ?? [];
  if (myAccounts.isEmpty) return {'in': 0.0, 'out': 0.0};

  final ids = myAccounts.map((a) => a.id).toList();
  final placeholders = List.filled(ids.length, '?').join(',');
  
  final resultIn = await db.rawQuery(
    "SELECT SUM(amount) as total FROM financial_transactions WHERE type = 'IN' AND date >= ? AND account_id IN ($placeholders)",
    [thirtyDaysAgo, ...ids]
  );
  final resultOut = await db.rawQuery(
    "SELECT SUM(amount) as total FROM financial_transactions WHERE type = 'OUT' AND date >= ? AND account_id IN ($placeholders)",
    [thirtyDaysAgo, ...ids]
  );

  return {
    'in': (resultIn.first['total'] as num?)?.toDouble() ?? 0.0,
    'out': (resultOut.first['total'] as num?)?.toDouble() ?? 0.0,
  };
});

// Solde total — Admin: tout, Employé: ses comptes seulement
final totalBalanceProvider = FutureProvider<double>((ref) async {
  final user = ref.watch(authServiceProvider).value;
  
  // Admin/Manager/AdminPlus → somme de TOUS les comptes
  if (user == null || user.role == UserRole.admin || user.role == UserRole.manager || user.role == UserRole.adminPlus) {
    final accounts = await ref.watch(treasuryProvider.future);
    return accounts.fold<double>(0.0, (double sum, item) => sum + item.balance);
  }

  // Employé → somme uniquement de ses comptes assignés
  final myAccounts = ref.watch(myTreasuryAccountsProvider).value ?? [];
  return myAccounts.fold<double>(0.0, (double sum, item) => sum + item.balance);
});


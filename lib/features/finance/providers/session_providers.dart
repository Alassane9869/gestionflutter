import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/finance/domain/models/cash_session.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/features/finance/domain/models/financial_account.dart';
import 'package:danaya_plus/core/network/client_sync_service.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:uuid/uuid.dart';

class SessionConflictException implements Exception {
  final String ownerName;
  SessionConflictException(this.ownerName);
  @override
  String toString() => "La caisse est déjà ouverte par $ownerName.";
}

// Provider to get the currently active session (if any)
final activeSessionProvider = FutureProvider<CashSession?>((ref) async {
  final auth = ref.watch(authServiceProvider.notifier);
  
  // CRITICAL FIX: Attendre explicitement que l'auth soit résolu
  // avant de vérifier la session. Empêche la race condition au démarrage.
  final user = await ref.watch(authServiceProvider.future);
  
  if (user == null || auth.isImpersonating) return null;

  try {
    final db = await ref.watch(databaseServiceProvider).database;

    final maps = await db.query(
      'cash_sessions',
      where: 'user_id = ? AND status = ?',
      whereArgs: [user.id, SessionStatus.OPEN.name],
      orderBy: 'open_date DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return CashSession.fromMap(maps.first);
    }
  } catch (e) {
    debugPrint('⚠️ activeSessionProvider: Erreur de lecture session: $e');
    // Ne pas propager l'erreur pour les problèmes de DB temporaires au démarrage
    // Cela permet au retry du DashboardScreen de tenter à nouveau
    rethrow;
  }
  return null;
});


// Provider pour l'historique des sessions fermées (admin/manager)
final closedSessionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = await ref.watch(databaseServiceProvider).database;
  
  final results = await db.rawQuery('''
    SELECT cs.*, u.username 
    FROM cash_sessions cs 
    LEFT JOIN users u ON cs.user_id = u.id
    WHERE cs.status = 'CLOSED'
    ORDER BY cs.close_date DESC
    LIMIT 100
  ''');
  
  return results;
});

final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService(ref);
});

class SessionService {
  final Ref _ref;

  SessionService(this._ref);

  Future<CashSession?> openSession(double initialBalance, {bool forceClose = false}) async {
    final db = await _ref.read(databaseServiceProvider).database;
    final user = await _ref.read(authServiceProvider.future);
    
    if (user == null) throw Exception("Utilisateur non authentifié.");

    // Check if one is already open for THIS user
    final existing = await _ref.read(activeSessionProvider.future);
    if (existing != null) {
      throw Exception("Une session est déjà ouverte.");
    }

    // Vérifier s'il y a des sessions orphelines d'autres utilisateurs
    final orphanSessions = await db.query(
      'cash_sessions',
      where: 'status = ?',
      whereArgs: [SessionStatus.OPEN.name],
    );
    
    if (orphanSessions.isNotEmpty) {
      // Auto-fermer les sessions orphelines (anciens utilisateurs qui ont quitté sans fermer)
      for (final orphan in orphanSessions) {
        final orphanSession = CashSession.fromMap(orphan);
        // Seulement si la session a plus de 24h (sinon c'est peut-être un autre caissier actif)
        final sessionAge = DateTime.now().difference(orphanSession.openDate);
        if (sessionAge.inHours >= 24) {
          await _autoCloseStaleSession(orphanSession);
          debugPrint("Session orpheline auto-fermée: ${orphanSession.id} (${orphan['user_id']})");
        } else if (orphanSession.userId != user.id) {
          // Session d'un autre utilisateur — bloquer l'ouverture SAUF si l'utilisateur n'existe plus
          final ownerResult = await db.query('users', where: 'id = ?', whereArgs: [orphanSession.userId], columns: ['username']);
          if (ownerResult.isEmpty) {
            debugPrint("🚨 Session orpheline détectée (Inconnu). Fermeture forcée pour permettre l'ouverture.");
            await _autoCloseStaleSession(orphanSession);
          } else {
            final ownerName = ownerResult.first['username'] as String;
            if (forceClose && (user.isAdmin || user.isManager || user.isAdminPlus)) {
              debugPrint("🚀 Force-closing session of $ownerName by ${user.role.name} ${user.username}");
              await _autoCloseStaleSession(orphanSession);
            } else {
              throw SessionConflictException(ownerName);
            }
          }
        }
      }
    }

    final session = CashSession(
      userId: user.id,
      openingBalance: initialBalance,
    );

    await db.insert('cash_sessions', session.toMap());
    
    // Log d'audit
    await _logActivity(db, user.id, 'SESSION_OPEN', 'cash_session', session.id,
      'Ouverture de caisse — Fond: ${DateFormatter.formatNumber(initialBalance)}');
    
    // --- SYNCHRO RÉSEAU ---
    _ref.read(clientSyncProvider).syncPendingAuditData();
    
    // Refresh the active session state
    _ref.invalidate(activeSessionProvider);
    
    return session;
  }

  // Calculate what the system thinks should be in the drawer
  Future<double> getExpectedBalance(CashSession session) async {
    final db = await _ref.read(databaseServiceProvider).database;
    
    // We only track CASH transactions for the drawer
    final cashAccount = await _ref.read(treasuryProvider.notifier).getDefaultAccount(AccountType.CASH);
    if (cashAccount == null) return session.openingBalance;

    // Use session_id for absolute precision if available, otherwise fallback to date
    String whereIn = "account_id = ? AND type = 'IN' AND session_id = ?";
    List<Object?> argsIn = [cashAccount.id, session.id];
    
    // Fallback if session_id wasn't recorded (legacy)
    final hasSessionIdCount = ((await db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM financial_transactions WHERE session_id = ?", [session.id])).first['cnt'] as num?)?.toInt() ?? 0;
    
    if (hasSessionIdCount == 0) {
      whereIn = "account_id = ? AND type = 'IN' AND date >= ?";
      argsIn = [cashAccount.id, session.openDate.toIso8601String()];
    }

    final inResult = await db.rawQuery("SELECT SUM(amount) as total FROM financial_transactions WHERE $whereIn", argsIn);
    final totalIn = (inResult.first['total'] as num?)?.toDouble() ?? 0.0;

    String whereOut = hasSessionIdCount > 0 
      ? "account_id = ? AND type = 'OUT' AND session_id = ?" 
      : "account_id = ? AND type = 'OUT' AND date >= ?";
    List<Object?> argsOut = hasSessionIdCount > 0 
      ? [cashAccount.id, session.id] 
      : [cashAccount.id, session.openDate.toIso8601String()];

    final outResult = await db.rawQuery("SELECT SUM(amount) as total FROM financial_transactions WHERE $whereOut", argsOut);
    final totalOut = (outResult.first['total'] as num?)?.toDouble() ?? 0.0;

    return session.openingBalance + totalIn - totalOut;
  }

  Future<Map<String, double>> getSessionStats(CashSession session) async {
    final db = await _ref.read(databaseServiceProvider).database;
    
    // Check if we have session_id records
    final hasSessionIdCount = ((await db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM sales WHERE session_id = ?", [session.id])).first['cnt'] as num?)?.toInt() ?? 0;

    // Total Sales
    final salesWhere = hasSessionIdCount > 0 ? "session_id = ?" : "date >= ?";
    final salesArgs = hasSessionIdCount > 0 ? [session.id] : [session.openDate.toIso8601String()];

    final salesResult = await db.rawQuery("SELECT SUM(total_amount) as total FROM sales WHERE $salesWhere", salesArgs);
    final totalSales = (salesResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // Cash payments
    final cashAccount = await _ref.read(treasuryProvider.notifier).getDefaultAccount(AccountType.CASH);
    double totalCash = 0.0;
    if (cashAccount != null) {
      final cashWhere = hasSessionIdCount > 0 
        ? "account_id = ? AND type = 'IN' AND category != 'TRANSFER' AND category != 'ADJUSTMENT' AND session_id = ?"
        : "account_id = ? AND type = 'IN' AND category != 'TRANSFER' AND category != 'ADJUSTMENT' AND date >= ?";
      final cashArgs = hasSessionIdCount > 0 
        ? [cashAccount.id, session.id] 
        : [cashAccount.id, session.openDate.toIso8601String()];

      final cashResult = await db.rawQuery("SELECT SUM(amount) as total FROM financial_transactions WHERE $cashWhere", cashArgs);
      totalCash = (cashResult.first['total'] as num?)?.toDouble() ?? 0.0;
    }

    // Credits
    final creditResult = await db.rawQuery("SELECT SUM(credit_amount) as total FROM sales WHERE $salesWhere", salesArgs);
    final totalCredit = (creditResult.first['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'totalSales': totalSales,
      'totalCash': totalCash,
      'totalCredit': totalCredit,
    };
  }

  Future<void> closeSession(CashSession session, double actualBalance) async {
    final db = await _ref.read(databaseServiceProvider).database;
    final user = await _ref.read(authServiceProvider.future);
    
    if (user == null) throw Exception("Utilisateur non authentifié.");
    
    // Contrôle de propriété : seul le propriétaire ou un admin/manager peut fermer
    if (session.userId != user.id && !user.isAdmin && !user.isManager && !user.isAdminPlus) {
      throw Exception("Sécurité : seul le propriétaire de la session ou une autorité (Admin/Manager) peut fermer cette caisse.");
    }

    final expected = await getExpectedBalance(session);
    final difference = actualBalance - expected;

    DateTime closeDate = DateTime.now();

    await db.transaction((txn) async {
      // 1. Update session record
      await txn.update(
        'cash_sessions',
        {
          'status': SessionStatus.CLOSED.name,
          'close_date': closeDate.toIso8601String(),
          'closing_balance_actual': actualBalance,
          'closing_balance_theoretical': expected,
          'difference': difference,
        },
        where: 'id = ?',
        whereArgs: [session.id],
      );

      // 2. If there's a difference, record it as ADJUSTMENT (not TRANSFER!)
      if (difference != 0.0) {
        final cashAccount = await _ref.read(treasuryProvider.notifier).getDefaultAccount(AccountType.CASH);
        if (cashAccount != null) {
          final txType = difference > 0 ? TransactionType.IN : TransactionType.OUT;
          
          await txn.insert('financial_transactions', {
            'id': const Uuid().v4(),
            'account_id': cashAccount.id,
            'type': txType.name,
            'amount': difference.abs(),
            'category': 'ADJUSTMENT', // Catégorie dédiée, pas 'TRANSFER'
            'description': difference > 0 
                ? "Surplus Caisse — Écart +${DateFormatter.formatNumber(difference)} (${user.username})" 
                : "Manquant Caisse — Écart ${DateFormatter.formatNumber(difference)} (${user.username})",
            'date': closeDate.toIso8601String(),
            'reference_id': session.id,
            'session_id': session.id,
          });

          // Adjust real account balance
          if (difference > 0) {
            await txn.rawUpdate('UPDATE financial_accounts SET balance = balance + ? WHERE id = ?', [difference.abs(), cashAccount.id]);
          } else {
            await txn.rawUpdate('UPDATE financial_accounts SET balance = balance - ? WHERE id = ?', [difference.abs(), cashAccount.id]);
          }
        }
      }

      // 3. Enregistrer dans le journal d'audit
      await txn.insert('activity_logs', {
        'id': const Uuid().v4(),
        'user_id': user.id,
        'action_type': 'SESSION_CLOSE',
        'entity_type': 'cash_session',
        'entity_id': session.id,
        'description': 'Fermeture caisse — Théorique: ${DateFormatter.formatNumber(expected)}, Réel: ${DateFormatter.formatNumber(actualBalance)}, Écart: ${DateFormatter.formatNumber(difference)}',
        'date': closeDate.toIso8601String(),
      });
    });

    // Invalidate state
    _ref.invalidate(activeSessionProvider);
    _ref.invalidate(closedSessionsProvider);
    _ref.read(treasuryProvider.notifier).refresh();
    
    // --- SYNCHRO RÉSEAU ---
    _ref.read(clientSyncProvider).syncPendingAuditData();
  }

  /// Auto-ferme une session abandonnée (utilisateur a quitté l'app sans fermer)
  Future<void> _autoCloseStaleSession(CashSession session) async {
    final db = await _ref.read(databaseServiceProvider).database;
    final expected = await getExpectedBalance(session);
    
    DateTime closeDate = DateTime.now();
    
    await db.transaction((txn) async {
      await txn.update(
        'cash_sessions',
        {
          'status': SessionStatus.CLOSED.name,
          'close_date': closeDate.toIso8601String(),
          'closing_balance_actual': expected, // On met le théorique car personne n'a compté
          'closing_balance_theoretical': expected,
          'difference': 0.0, // Pas d'écart puisqu'on n'a pas compté
        },
        where: 'id = ?',
        whereArgs: [session.id],
      );

      // Enregistrer dans le journal d'audit (comme fermeture auto)
      // On vérifie si l'utilisateur existe encore pour éviter une erreur de clé étrangère
      final userExists = (await txn.query('users', where: 'id = ?', whereArgs: [session.userId])).isNotEmpty;

      await txn.insert('activity_logs', {
        'id': const Uuid().v4(),
        'user_id': userExists ? session.userId : null,
        'action_type': 'SESSION_AUTO_CLOSE',
        'entity_type': 'cash_session',
        'entity_id': session.id,
        'description': 'Session fermée automatiquement (abandonnée >24h) — Théorique: ${DateFormatter.formatNumber(expected)}',
        'date': closeDate.toIso8601String(),
      });
    });

    // --- SYNCHRO RÉSEAU ---
    _ref.read(clientSyncProvider).syncPendingAuditData();
  }
  
  /// Log utilitaire pour le journal d'audit
  Future<void> _logActivity(dynamic db, String userId, String actionType, String entityType, String entityId, String description) async {
    try {
      await db.insert('activity_logs', {
        'id': const Uuid().v4(),
        'user_id': userId,
        'action_type': actionType,
        'entity_type': entityType,
        'entity_id': entityId,
        'description': description,
        'date': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Activity log error: $e");
    }
  }
}

import 'dart:io';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';
import 'package:path/path.dart' as p_path;
import 'package:danaya_plus/core/database/database_service.dart';

final maintenanceServiceProvider = Provider<MaintenanceService>((ref) {
  return MaintenanceService(ref);
});

class MaintenanceService {
  final Ref _ref;
  MaintenanceService(this._ref);

  /// 💎 [Elite] Optimisation profonde de la base de données (SQLite)
  Future<void> optimizeDatabase() async {
    final db = await _ref.read(databaseServiceProvider).database;
    debugPrint("💎 Maintenance: Lancement de l'optimisation SQLite (VACUUM/ANALYZE)...");
    
    await db.execute('VACUUM');
    await db.execute('ANALYZE');
    
    debugPrint("✅ Maintenance: Optimisation terminée.");
  }

  /// 💎 [Elite] Diagnostic de l'intégrité logique du système
  Future<Map<String, dynamic>> performIntegrityCheck() async {
    final db = await _ref.read(databaseServiceProvider).database;
    
    final stockDiscrepancies = await db.rawQuery('''
      SELECT p.id, p.name, p.quantity as current_qty, 
             (SELECT SUM(CASE WHEN type = 'IN' THEN quantity ELSE -quantity END) 
              FROM stock_movements WHERE product_id = p.id) as movement_sum
      FROM products p
    ''');

    final List<Map<String, dynamic>> stockIssueDetails = [];
    int issueCount = 0;
    
    for (var row in stockDiscrepancies) {
       final current = (row['current_qty'] as num).toDouble();
       final sum = (row['movement_sum'] as num? ?? 0.0).toDouble();
       if ((current - sum).abs() > 0.01) {
         issueCount++;
         stockIssueDetails.add({
           'id': row['id'],
           'name': row['name'],
           'current': current,
           'sum': sum,
           'diff': (current - sum).abs(),
         });
       }
    }

    final orphanDetails = await _getOrphanImageDetails();
    final dbFile = File(await _ref.read(databaseServiceProvider).getDatabasePath());
    final dbSize = await dbFile.length();

    return {
      'stock_issues': issueCount,
      'stock_details': stockIssueDetails,
      'orphan_images': orphanDetails.length,
      'orphan_details': orphanDetails,
      'db_size_mb': (dbSize / 1024 / 1024).toStringAsFixed(2),
      'is_healthy': issueCount == 0 && orphanDetails.isEmpty,
    };
  }

  Future<List<String>> _getOrphanImageDetails() async {
    final db = await _ref.read(databaseServiceProvider).database;
    final products = await db.query('products', columns: ['image_path']);
    final referencedPaths = products
        .map((p) => p['image_path'] as String?)
        .where((path) => path != null)
        .toSet();

    List<String> orphans = [];
    try {
      final appDir = await getApplicationSupportDirectory();
      final imagesDir = Directory(p_path.join(appDir.path, 'product_images'));
      if (await imagesDir.exists()) {
        final files = await imagesDir.list().toList();
        for (final entity in files) {
          if (entity is File && !referencedPaths.contains(entity.path)) {
            orphans.add(entity.path);
          }
        }
      }
    } catch (_) {}
    return orphans;
  }

  Future<int> purgeActivityLogs(int monthsRetention) async {
    final db = await _ref.read(databaseServiceProvider).database;
    final cutoffDate = DateTime.now().subtract(Duration(days: 30 * monthsRetention)).toIso8601String();
    return await db.delete('activity_logs', where: 'date < ?', whereArgs: [cutoffDate]);
  }

  Future<void> resetFullDatabase() async {
    final db = await _ref.read(databaseServiceProvider).database;
    await db.transaction((txn) async {
       await txn.delete('activity_logs');
       await txn.delete('sale_items');
       await txn.delete('sales');
       await txn.delete('quote_items');
       await txn.delete('quotes');
       await txn.delete('purchase_order_items');
       await txn.delete('purchase_orders');
       await txn.delete('stock_movements');
       await txn.delete('stock_audit_items');
       await txn.delete('stock_audits');
       await txn.delete('products');
       await txn.delete('client_payments');
       await txn.delete('clients');
       await txn.delete('supplier_payments');
       await txn.delete('suppliers');
       await txn.delete('financial_transactions');
       await txn.delete('cash_sessions');
       await txn.delete('employee_contracts');
       await txn.delete('payrolls');
       await txn.delete('users', where: "id != 'sysadmin'");
    });
    await cleanupOrphanImages();
    await optimizeDatabase();
    _ref.invalidate(productListProvider);
  }

  /// 💎 [Elite] Supprime uniquement les données de vente et devis
  Future<void> clearSalesData() async {
    final db = await _ref.read(databaseServiceProvider).database;
    await db.transaction((txn) async {
      await txn.delete('sale_items');
      await txn.delete('sales');
      await txn.delete('quote_items');
      await txn.delete('quotes');
      await txn.delete('financial_transactions', where: 'category = ?', whereArgs: ['SALE']);
      await txn.delete('client_payments');
      await txn.delete('cash_sessions');
    });
    await optimizeDatabase();
  }

  /// 💎 [Elite] Réinitialise le stock (quantités à 0) et purge les mouvements
  Future<void> clearInventoryData() async {
    final db = await _ref.read(databaseServiceProvider).database;
    await db.transaction((txn) async {
      await txn.update('products', {'quantity': 0, 'weighted_average_cost': 0});
      await txn.delete('stock_movements');
      await txn.delete('purchase_order_items');
      await txn.delete('purchase_orders');
      await txn.delete('stock_audit_items');
      await txn.delete('stock_audits');
    });
    await optimizeDatabase();
    _ref.invalidate(productListProvider);
  }

  /// 💎 [Elite] Supprime les clients et fournisseurs
  Future<void> clearCRMData() async {
    final db = await _ref.read(databaseServiceProvider).database;
    await db.transaction((txn) async {
      await txn.delete('client_payments');
      await txn.delete('clients');
      await txn.delete('supplier_payments');
      await txn.delete('suppliers');
    });
    await optimizeDatabase();
  }

  /// 💎 [Elite] Purge complète des journaux d'activité
  Future<void> clearSystemLogs() async {
    final db = await _ref.read(databaseServiceProvider).database;
    await db.delete('activity_logs');
    await optimizeDatabase();
  }

  Future<void> recalculateAllWacs() async {
    final db = await _ref.read(databaseServiceProvider).database;
    await db.transaction((txn) async {
      final products = await txn.query('products', columns: ['id', 'purchasePrice']);
      for (final p in products) {
        final productId = p['id'] as String;
        final initialPrice = (p['purchasePrice'] as num? ?? 0.0).toDouble();
        final items = await txn.rawQuery('''
          SELECT i.quantity, i.unit_price 
          FROM purchase_order_items i
          JOIN purchase_orders o ON i.order_id = o.id
          WHERE i.product_id = ?
          ORDER BY o.date ASC
        ''', [productId]);
        double runningWac = initialPrice;
        int runningQty = 0;
        for (final item in items) {
          final qty = (item['quantity'] as num).toInt();
          final price = (item['unit_price'] as num).toDouble();
          if (runningQty <= 0) {
            runningWac = price;
            runningQty = qty;
          } else {
            runningWac = ((runningQty * runningWac) + (qty * price)) / (runningQty + qty);
            runningQty += qty;
          }
        }
        if (items.isNotEmpty) {
          await txn.update('products', {'weighted_average_cost': runningWac}, where: 'id = ?', whereArgs: [productId]);
        }
      }
    });
    _ref.invalidate(productListProvider);
  }

  Future<int> cleanupOrphanImages() async {
    final db = await _ref.read(databaseServiceProvider).database;
    final products = await db.query('products', columns: ['image_path']);
    final referencedPaths = products
        .map((p) => p['image_path'] as String?)
        .where((path) => path != null)
        .toSet();
    int deletedCount = 0;
    try {
      final appDir = await getApplicationSupportDirectory();
      final imagesDir = Directory(p_path.join(appDir.path, 'product_images'));
      if (await imagesDir.exists()) {
        final files = await imagesDir.list().toList();
        for (final entity in files) {
          if (entity is File && !referencedPaths.contains(entity.path)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }
    } catch (_) {}
    return deletedCount;
  }

  /// 💎 [Elite] Répare les écarts entre stock physique et historique des mouvements en insérant les mouvements manquants.
  Future<int> repairStockIntegrity() async {
    final db = await _ref.read(databaseServiceProvider).database;
    final user = await _ref.read(authServiceProvider.future);
    final activeSession = await _ref.read(activeSessionProvider.future);
    int repairCount = 0;
    
    await db.transaction((txn) async {
      final discrepancies = await txn.rawQuery('''
        SELECT p.id, p.quantity,
               (SELECT SUM(CASE WHEN type = 'IN' THEN quantity ELSE -quantity END) 
                FROM stock_movements WHERE product_id = p.id) as movement_sum
        FROM products p
      ''');

      for (var row in discrepancies) {
        final productId = row['id'] as String;
        final currentQty = (row['quantity'] as num).toDouble();
        final sum = (row['movement_sum'] as num? ?? 0.0).toDouble();
        
        final diff = currentQty - sum;
        
        // Si le stock affiché (currentQty) est différent de l'historique (sum),
        // on crée le mouvement manquant pour aligner l'historique sur l'affichage visuel, 
        // pas l'inverse !
        if (diff.abs() > 0.01) {
           final type = diff > 0 ? 'IN' : 'OUT';
           final qty = diff.abs();
           
           await txn.insert('stock_movements', {
              'id': const Uuid().v4(),
              'product_id': productId,
              'type': type,
              'quantity': qty,
              'reason': 'Ajustement Automatique (Intégrité)',
              'date': DateTime.now().toIso8601String(),
              'user_id': user?.id,
              'session_id': activeSession?.id,
           });
           repairCount++;
        }
      }
    });

    if (repairCount > 0) {
      _ref.invalidate(productListProvider);
    }
    return repairCount;
  }
}

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_service.dart';
import '../../inventory/domain/models/product.dart';
import '../../inventory/domain/models/stock_movement.dart';
import '../domain/models/stock_audit.dart';

final stockAuditListProvider = FutureProvider<List<StockAudit>>((ref) async {
  final db = await ref.read(databaseServiceProvider).database;
  final List<Map<String, dynamic>> maps = await db.query('stock_audits', orderBy: 'date DESC');
  return maps.map((m) => StockAudit.fromMap(m)).toList();
});

final activeAuditProvider = NotifierProvider<ActiveAuditNotifier, StockAudit?>(ActiveAuditNotifier.new);
class ActiveAuditNotifier extends Notifier<StockAudit?> {
  @override
  StockAudit? build() => null;
  void set(StockAudit? audit) => state = audit;
}

final stockAuditItemsProvider = FutureProvider.family<List<StockAuditItem>, String>((ref, auditId) async {
  final db = await ref.read(databaseServiceProvider).database;
  final List<Map<String, dynamic>> maps = await db.rawQuery('''
    SELECT i.*, p.name as product_name 
    FROM stock_audit_items i
    JOIN products p ON i.product_id = p.id
    WHERE i.audit_id = ?
  ''', [auditId]);
  return maps.map((m) => StockAuditItem.fromMap(m)).toList();
});

final stockAuditActionsProvider = Provider((ref) => StockAuditActions(ref));

class StockAuditActions {
  final Ref _ref;
  StockAuditActions(this._ref);

  Future<String> startNewAudit({String? notes, String? category}) async {
    final db = await _ref.read(databaseServiceProvider).database;
    final audit = StockAudit.create(notes: notes, category: category);
    
    await db.transaction((txn) async {
      await txn.insert('stock_audits', audit.toMap());
      
      // Snapshot products with optional category filter
      final List<Map<String, dynamic>> productMaps = category != null && category.isNotEmpty
          ? await txn.query('products', where: 'category = ?', whereArgs: [category])
          : await txn.query('products');

      final batch = txn.batch();
      for (var pMap in productMaps) {
        final product = Product.fromMap(pMap);
        final item = StockAuditItem(
          id: const Uuid().v4(),
          auditId: audit.id,
          productId: product.id,
          theoreticalQty: product.quantity,
          actualQty: product.quantity, // Default to same as theoretical
          difference: 0,
        );
        batch.insert('stock_audit_items', item.toMap());
      }
      await batch.commit(noResult: true);
    });

    _ref.invalidate(stockAuditListProvider);
    return audit.id;
  }

  Future<void> updateItemQty(String itemId, double actualQty) async {
    final db = await _ref.read(databaseServiceProvider).database;
    
    final List<Map<String, dynamic>> maps = await db.query('stock_audit_items', where: 'id = ?', whereArgs: [itemId]);
    if (maps.isEmpty) return;
    
    final item = StockAuditItem.fromMap(maps.first);
    final diff = actualQty - item.theoreticalQty;
    
    await db.update('stock_audit_items', {
      'actual_qty': actualQty.toDouble(),
      'difference': diff.toDouble(),
    }, where: 'id = ?', whereArgs: [itemId]);
  }

  /// Increments an item's actual quantity by 1 if the barcode matches an item in the current audit.
  Future<bool> incrementItemByBarcode(String auditId, String barcode) async {
    final db = await _ref.read(databaseServiceProvider).database;
    
    // Jointure pour trouver l'item d'audit via le code-barres du produit
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT i.* 
      FROM stock_audit_items i
      JOIN products p ON i.product_id = p.id
      WHERE i.audit_id = ? AND p.barcode = ?
    ''', [auditId, barcode]);

    if (maps.isEmpty) return false;

    final item = StockAuditItem.fromMap(maps.first);
    final newQty = item.actualQty + 1;
    await updateItemQty(item.id, newQty);
    _ref.invalidate(stockAuditItemsProvider(auditId));
    return true;
  }

  Future<void> finalizeAudit(String auditId) async {
    final db = await _ref.read(databaseServiceProvider).database;
    
    await db.transaction((txn) async {
      // Get all items in this audit
      final List<Map<String, dynamic>> itemMaps = await txn.query('stock_audit_items', where: 'audit_id = ?', whereArgs: [auditId]);
      final items = itemMaps.map((m) => StockAuditItem.fromMap(m)).toList();
      
      final now = DateTime.now();
      
      final batch = txn.batch();
      for (var item in items) {
        if (item.difference == 0) continue;
        
        // CHECK: Check if product still exists to avoid Foreign Key crash
        final List<Map<String, dynamic>> pCheck = await txn.query('products', columns: ['id'], where: 'id = ?', whereArgs: [item.productId]);
        if (pCheck.isEmpty) continue; // Product was deleted, skip movement/update

        // Update product stock
        batch.execute(
          'UPDATE products SET quantity = ? WHERE id = ?',
          [item.actualQty, item.productId],
        );
        
        // Record stock movement
        final movement = StockMovement(
          id: const Uuid().v4(),
          productId: item.productId,
          type: item.difference > 0 ? MovementType.IN : MovementType.OUT,
          quantity: item.difference.abs(),
          reason: "Inventaire physique (Audit #${auditId.substring(0, 5)})",
          date: now,
        );
        batch.insert('stock_movements', movement.toMap());
      }
      await batch.commit(noResult: true);
      
      // Mark audit as completed
      await txn.update('stock_audits', {
        'status': 'COMPLETED',
        'date': now.toIso8601String(), // Ensure date is set/updated
      }, where: 'id = ?', whereArgs: [auditId]);
    });

    // Log d'audit système
    unawaited(_ref.read(databaseServiceProvider).logActivity(
      actionType: 'STOCK_AUDIT_COMPLETED',
      entityType: 'AUDIT',
      entityId: auditId,
      description: "Finalisation de l'inventaire physique (#${auditId.substring(0, 5)})",
    ));

    _ref.invalidate(stockAuditListProvider);
    _ref.invalidate(stockAuditItemsProvider(auditId));
  }

  Future<void> deleteAudit(String auditId) async {
    final db = await _ref.read(databaseServiceProvider).database;
    await db.delete('stock_audits', where: 'id = ?', whereArgs: [auditId]);
    _ref.invalidate(stockAuditListProvider);
  }
}

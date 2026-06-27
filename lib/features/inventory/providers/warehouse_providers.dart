import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/inventory/domain/models/warehouse.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

// ── List of all warehouses ──
final warehouseListProvider = AsyncNotifierProvider<WarehouseListNotifier, List<Warehouse>>(() {
  return WarehouseListNotifier();
});

class WarehouseListNotifier extends AsyncNotifier<List<Warehouse>> {
  @override
  Future<List<Warehouse>> build() async {
    final db = await ref.read(databaseServiceProvider).database;
    final rows = await db.query('warehouses', orderBy: 'is_default DESC, name ASC');
    return rows.map((r) => Warehouse.fromMap(r)).toList();
  }

  Future<void> add(Warehouse warehouse) async {
    final db = await ref.read(databaseServiceProvider).database;
    await db.insert('warehouses', warehouse.toMap());
    ref.invalidateSelf();
  }

  Future<void> updateWarehouse(Warehouse warehouse) async {
    final db = await ref.read(databaseServiceProvider).database;
    await db.update('warehouses', warehouse.toMap(), where: 'id = ?', whereArgs: [warehouse.id]);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    final db = await ref.read(databaseServiceProvider).database;

    // PROTECTION: Ne pas supprimer si du stock existe dans cet entrepôt
    final stockCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM warehouse_stock WHERE warehouse_id = ? AND quantity > 0',
      [id],
    )) ?? 0;

    if (stockCount > 0) {
      throw Exception(
        "Impossible de supprimer cet entrepôt : il contient encore $stockCount produit(s) en stock. "
        "Veuillez d'abord transférer ou ajuster le stock.",
      );
    }

    await db.delete('warehouses', where: 'id = ?', whereArgs: [id]);
    ref.invalidateSelf();
  }
}

// ── Warehouse stock (products in a specific warehouse) ──
final warehouseStockProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, warehouseId) async {
  final db = await ref.read(databaseServiceProvider).database;
  return db.rawQuery('''
    SELECT ws.*, p.name as product_name, p.barcode, p.category, p.sellingPrice, p.purchasePrice
    FROM warehouse_stock ws
    JOIN products p ON ws.product_id = p.id
    WHERE ws.warehouse_id = ?
    ORDER BY p.name
  ''', [warehouseId]);
});

// ── Transfer stock between warehouses ──
final warehouseTransferProvider = Provider<WarehouseTransferService>((ref) {
  return WarehouseTransferService(ref);
});

class WarehouseTransferService {
  final Ref _ref;

  WarehouseTransferService(this._ref);

  Future<void> transferStock({
    required String fromWarehouseId,
    required String toWarehouseId,
    required String productId,
    required double quantity,
  }) async {
    final db = await _ref.read(databaseServiceProvider).database;
    final user = await _ref.read(authServiceProvider.future);
    final userId = user?.id ?? 'system';

    try {
      await db.transaction((txn) async {
        // --- 1. STRICT VULNERABILITY CHECKS ---
        final sourceStock = await txn.query('warehouse_stock',
          columns: ['quantity'],
          where: 'warehouse_id = ? AND product_id = ?',
          whereArgs: [fromWarehouseId, productId],
        );
        
        final currentQty = sourceStock.isEmpty ? 0.0 : (sourceStock.first['quantity'] as num).toDouble();
        if (currentQty < quantity) {
          throw Exception("Transfert impossible : Stock insuffisant dans l'entrepôt source. Disponible: $currentQty. Tentative de transfert: $quantity.");
        }

        // 2. Decrease from source
        await txn.rawUpdate(
          'UPDATE warehouse_stock SET quantity = quantity - ? WHERE warehouse_id = ? AND product_id = ?',
          [quantity, fromWarehouseId, productId],
        );

        // Increase in destination (upsert)
        final existing = await txn.query('warehouse_stock',
          where: 'warehouse_id = ? AND product_id = ?',
          whereArgs: [toWarehouseId, productId],
        );

        if (existing.isEmpty) {
          await txn.insert('warehouse_stock', {
            'id': const Uuid().v4(),
            'warehouse_id': toWarehouseId,
            'product_id': productId,
            'quantity': quantity,
          });
        } else {
          await txn.rawUpdate(
            'UPDATE warehouse_stock SET quantity = quantity + ? WHERE warehouse_id = ? AND product_id = ?',
            [quantity, toWarehouseId, productId],
          );
        }

        // Record stock movements
        final moveId = const Uuid().v4();
        // Negative movement for source
        await txn.insert('stock_movements', {
          'id': moveId,
          'product_id': productId,
          'type': 'OUT',
          'quantity': quantity,
          'reason': 'Transfert vers entrepôt destination',
          'date': DateTime.now().toIso8601String(),
          'user_id': userId,
          'warehouse_id': fromWarehouseId,
        });

        // Positive movement for destination
        await txn.insert('stock_movements', {
          'id': const Uuid().v4(),
          'product_id': productId,
          'type': 'IN',
          'quantity': quantity,
          'reason': 'Transfert depuis entrepôt source',
          'date': DateTime.now().toIso8601String(),
          'user_id': userId,
          'warehouse_id': toWarehouseId,
        });
      });

      _ref.invalidate(warehouseStockProvider(fromWarehouseId));
      _ref.invalidate(warehouseStockProvider(toWarehouseId));
    } catch (e) {
      rethrow;
    }
  }
}

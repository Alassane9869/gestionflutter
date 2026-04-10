import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/srm/domain/models/purchase_order.dart';

final purchaseOrderRepositoryProvider = Provider<PurchaseOrderRepository>((ref) {
  return PurchaseOrderRepository(ref.watch(databaseServiceProvider));
});

class PurchaseOrderRepository {
  final DatabaseService _dbService;

  PurchaseOrderRepository(this._dbService);

  // Insère la commande et ses articles dans une transaction
  Future<void> insertOrderWithItems(PurchaseOrder order, List<PurchaseOrderItem> items) async {
    final db = await _dbService.database;
    
    await db.transaction((txn) async {
      await txn.insert('purchase_orders', order.toMap());
      for (final item in items) {
        await txn.insert('purchase_order_items', item.toMap());
      }
    });
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final db = await _dbService.database;
    await db.update(
      'purchase_orders',
      {'status': newStatus.name},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<List<PurchaseOrder>> getAllOrders() async {
    final db = await _dbService.database;
    final maps = await db.query('purchase_orders', orderBy: 'date DESC');
    return maps.map((m) => PurchaseOrder.fromMap(m)).toList();
  }

  Future<List<PurchaseOrderItem>> getOrderItems(String orderId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'purchase_order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
    return maps.map((m) => PurchaseOrderItem.fromMap(m)).toList();
  }
}

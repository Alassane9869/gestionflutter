import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/inventory/domain/models/stock_movement.dart';

final stockMovementRepositoryProvider = Provider<StockMovementRepository>((ref) {
  return StockMovementRepository(ref.watch(databaseServiceProvider));
});

class StockMovementRepository {
  final DatabaseService _dbService;

  StockMovementRepository(this._dbService);

  Future<void> insert(StockMovement movement) async {
    final db = await _dbService.database;
    
    // Supreme Audit: Capture stock snapshots
    double currentQty = 0.0;
    
    // Si un entrepôt est spécifié, on prend la balance de cet entrepôt
    if (movement.warehouseId != null) {
      final wsRow = await db.query('warehouse_stock', 
        columns: ['quantity'], 
        where: 'product_id = ? AND warehouse_id = ?', 
        whereArgs: [movement.productId, movement.warehouseId]);
      if (wsRow.isNotEmpty) {
        currentQty = (wsRow.first['quantity'] as num).toDouble();
      }
    } else {
      // Sinon on prend la balance globale dans la table products
      final pRow = await db.query('products', 
        columns: ['quantity'], 
        where: 'id = ?', 
        whereArgs: [movement.productId]);
      if (pRow.isNotEmpty) {
        currentQty = (pRow.first['quantity'] as num).toDouble();
      }
    }

    final balanceBefore = currentQty;
    double balanceAfter;
    
    // Calcul de la nouvelle balance théorique
    if (movement.type == MovementType.IN) {
      balanceAfter = currentQty + movement.quantity;
    } else if (movement.type == MovementType.OUT) {
      balanceAfter = currentQty - movement.quantity;
    } else if (movement.type == MovementType.ADJUSTMENT) {
      // Pour un ajustement, la quantité dans le mouvement est souvent la DIFFÉRENCE
      // Mais ça dépend de l'implémentation. Ici on suit la logique IN/OUT
      balanceAfter = currentQty + movement.quantity; 
    } else {
      balanceAfter = currentQty; // Transfer ou autre (géré par legs IN/OUT)
    }

    final updatedMovement = movement.copyWith(
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
    );

    await db.insert('stock_movements', updatedMovement.toMap());

    // Log d'audit renforcé
    unawaited(_dbService.logActivity(
      userId: movement.userId,
      actionType: 'STOCK_MOVE',
      entityType: 'PRODUCT',
      entityId: movement.productId,
      description: "Mouvement de stock (${movement.type}): ${movement.quantity} unités. Balances: $balanceBefore -> $balanceAfter. Raison: ${movement.reason}",
      metadata: {
        'type': movement.type.name,
        'qty': movement.quantity,
        'before': balanceBefore,
        'after': balanceAfter,
        'warehouse': movement.warehouseId,
      },
    ));
  }

  Future<List<StockMovement>> getAll({String? warehouseId, String? userId}) async {
    final db = await _dbService.database;
    String query = '''
      SELECT sm.*, u.username
      FROM stock_movements sm
      LEFT JOIN users u ON sm.user_id = u.id
    ''';
    List<Object?> args = [];

    List<String> conditions = [];
    if (warehouseId != null) {
      conditions.add('sm.warehouse_id = ?');
      args.add(warehouseId);
    }
    if (userId != null) {
      conditions.add('sm.user_id = ?');
      args.add(userId);
    }

    if (conditions.isNotEmpty) {
      query += ' WHERE ${conditions.join(' AND ')}';
    }

    query += ' ORDER BY sm.date DESC';
    
    final maps = await db.rawQuery(query, args);
    return maps.map((m) => StockMovement.fromMap(m)).toList();
  }

  Future<List<StockMovement>> getByProductId(String productId, {String? userId}) async {
    final db = await _dbService.database;
    
    String query = '''
      SELECT sm.*, u.username
      FROM stock_movements sm
      LEFT JOIN users u ON sm.user_id = u.id
      WHERE sm.product_id = ?
    ''';
    List<Object?> args = [productId];

    if (userId != null) {
      query += ' AND sm.user_id = ?';
      args.add(userId);
    }

    query += ' ORDER BY sm.date DESC';
    
    final maps = await db.rawQuery(query, args);
    return maps.map((m) => StockMovement.fromMap(m)).toList();
  }
}

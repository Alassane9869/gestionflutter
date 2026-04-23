import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/inventory/domain/models/stock_movement.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';

final stockTransferServiceProvider = Provider((ref) => StockTransferService(ref));

class StockTransferService {
  final Ref _ref;
  final _uuid = const Uuid();

  StockTransferService(this._ref);

  /// Réalise un transfert atomique de stock entre deux entrepôts.
  Future<void> transferStock({
    required String productId,
    required String fromWarehouseId,
    required String toWarehouseId,
    required double quantity,
    String reason = "Transfert Inter-Entrepôt",
  }) async {
    if (fromWarehouseId == toWarehouseId) {
      throw Exception("Les entrepôts de départ et d'arrivée doivent être différents.");
    }
    if (quantity <= 0) {
      throw Exception("La quantité de transfert doit être supérieure à zéro.");
    }

    final dbService = _ref.read(databaseServiceProvider);
    final db = await dbService.database;

    final user = await _ref.read(authServiceProvider.future);
    final activeSession = await _ref.read(activeSessionProvider.future);
    final userId = user?.id ?? "admin";

    await db.transaction((txn) async {
      // 1. Vérifier la disponibilité dans l'entrepôt source
      final fromRows = await txn.query('warehouse_stock',
          where: 'product_id = ? AND warehouse_id = ?',
          whereArgs: [productId, fromWarehouseId]);

      double fromQtyBefore = 0.0;
      if (fromRows.isNotEmpty) {
        fromQtyBefore = (fromRows.first['quantity'] as num).toDouble();
      }

      if (fromQtyBefore < quantity) {
        throw Exception("Stock insuffisant dans l'entrepôt source (Actuel: $fromQtyBefore).");
      }

      // 2. Débiter l'entrepôt source
      final fromQtyAfter = fromQtyBefore - quantity;
      await txn.update(
        'warehouse_stock',
        {'quantity': fromQtyAfter},
        where: 'product_id = ? AND warehouse_id = ?',
        whereArgs: [productId, fromWarehouseId],
      );

      // 3. Créditer l'entrepôt destination
      final toRows = await txn.query('warehouse_stock',
          where: 'product_id = ? AND warehouse_id = ?',
          whereArgs: [productId, toWarehouseId]);

      double toQtyBefore = 0.0;
      if (toRows.isNotEmpty) {
        toQtyBefore = (toRows.first['quantity'] as num).toDouble();
        final toQtyAfter = toQtyBefore + quantity;
        await txn.update(
          'warehouse_stock',
          {'quantity': toQtyAfter},
          where: 'product_id = ? AND warehouse_id = ?',
          whereArgs: [productId, toWarehouseId],
        );
      } else {
        // Si le produit n'existait pas dans l'entrepôt cible, on le crée
        await txn.insert('warehouse_stock', {
          'id': _uuid.v4(),
          'warehouse_id': toWarehouseId,
          'product_id': productId,
          'quantity': quantity,
        });
      }

      // 4. Enregistrer les mouvements de stock pour l'audit (Double-Lég)
      // Leg 1: Sortie du Magasin A
      final moveOut = StockMovement(
        productId: productId,
        type: MovementType.TRANSFER, // On utilise Transfer pour les deux pour l'historique
        quantity: quantity,
        reason: "$reason (VERS: $toWarehouseId)",
        userId: userId,
        warehouseId: fromWarehouseId,
        sessionId: activeSession?.id,
        balanceBefore: fromQtyBefore,
        balanceAfter: fromQtyAfter,
      );
      await txn.insert('stock_movements', moveOut.toMap());

      // Leg 2: Entrée dans le Magasin B
      final moveIn = StockMovement(
        productId: productId,
        type: MovementType.TRANSFER,
        quantity: quantity,
        reason: "$reason (DE: $fromWarehouseId)",
        userId: userId,
        warehouseId: toWarehouseId,
        sessionId: activeSession?.id,
        balanceBefore: toQtyBefore,
        balanceAfter: toQtyBefore + quantity,
      );
      await txn.insert('stock_movements', moveIn.toMap());

      // 5. Audit Log global
      await dbService.logActivity(
        userId: userId,
        actionType: 'STOCK_TRANSFER',
        entityType: 'PRODUCT',
        entityId: productId,
        description: "Transfert de $quantity unités de $fromWarehouseId vers $toWarehouseId",
      );
    });
  }
}

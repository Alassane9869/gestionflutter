import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/features/inventory/data/stock_movement_repository.dart';
import 'package:danaya_plus/features/inventory/domain/models/stock_movement.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';

final stockMovementsProvider = AsyncNotifierProvider<StockMovementsNotifier, List<StockMovement>>(
  StockMovementsNotifier.new,
);

class StockMovementsNotifier extends AsyncNotifier<List<StockMovement>> {
  @override
  Future<List<StockMovement>> build() async {
    final warehouseId = ref.watch(selectedWarehouseIdProvider);
    final user = ref.watch(authServiceProvider).value;
    if (user == null) return [];
    
    // Un gestionnaire de stock OU un rôle global voit tous les mouvements
    final isGlobalStock = user.canViewGlobalSalesHistory || user.canManageInventory;
    
    final userId = isGlobalStock ? null : user.id;

    return ref.watch(stockMovementRepositoryProvider).getAll(
      warehouseId: warehouseId,
      userId: userId,
    );
  }

  Future<void> addMovement(StockMovement movement) async {
    final warehouseId = ref.read(selectedWarehouseIdProvider);
    final user = ref.read(authServiceProvider).value;
    if (user == null) return;

    final isGlobalStock = user.canViewGlobalSalesHistory || user.canManageInventory;
    final userId = isGlobalStock ? null : user.id;

    state = const AsyncLoading();
    await ref.read(stockMovementRepositoryProvider).insert(movement);
    state = AsyncData(await ref.read(stockMovementRepositoryProvider).getAll(
      warehouseId: warehouseId,
      userId: userId,
    ));
  }
}

final productMovementsProvider = FutureProvider.family<List<StockMovement>, String>((ref, productId) async {
  final user = ref.watch(authServiceProvider).value;
  // Un gestionnaire de stock OU un rôle global voit tous les mouvements produit
  final isGlobalStock = user?.canViewGlobalSalesHistory == true || user?.canManageInventory == true;
  final userId = isGlobalStock ? null : user?.id;

  return ref.watch(stockMovementRepositoryProvider).getByProductId(
    productId,
    userId: userId,
  );
});

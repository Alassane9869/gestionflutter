import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/features/inventory/data/product_repository.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/inventory/data/stock_movement_repository.dart';
import 'package:danaya_plus/features/inventory/domain/models/stock_movement.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/network/client_sync_service.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';
import 'package:danaya_plus/core/services/marketing_email_service.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';

final selectedWarehouseIdProvider =
    NotifierProvider<WarehouseSelectionNotifier, String?>(
      WarehouseSelectionNotifier.new,
    );

class WarehouseSelectionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setId(String? id) => state = id;
}

final productListProvider =
    AsyncNotifierProvider<ProductListNotifier, List<Product>>(
      ProductListNotifier.new,
    );

class ProductListNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    final warehouseId = ref.watch(selectedWarehouseIdProvider);
    return ref
        .watch(productRepositoryProvider)
        .getAll(warehouseId: warehouseId);
  }

  Future<void> addProduct(Product product, {String? warehouseId}) async {
    state = const AsyncLoading();
    await ref.read(productRepositoryProvider).insert(product, warehouseId: warehouseId);

    // Historisation du stock initial si > 0
    if (product.quantity > 0) {
      final user = await ref.read(authServiceProvider.future);
      final activeSession = await ref.read(activeSessionProvider.future);
      final userId = user?.id ?? "admin";
      final movement = StockMovement(
        productId: product.id,
        type: MovementType.IN,
        quantity: product.quantity,
        reason: "Création du produit / Stock initial",
        userId: userId,
        warehouseId: warehouseId ?? 'default_warehouse',
        sessionId: activeSession?.id,
      );
      await ref.read(stockMovementRepositoryProvider).insert(movement);

      // --- SYNCHRO RÉSEAU ---
      final settings = ref.read(shopSettingsProvider).value;
      if (settings?.networkMode == NetworkMode.client) {
        ref.read(clientSyncProvider).sendProductToServer(product);
        ref.read(clientSyncProvider).sendStockMovementToServer(movement);
        ref.read(clientSyncProvider).syncPendingAuditData();
      }
    }

    // --- MARKETING NOTIFICATION ---
    _triggerNewProductEmail(product);

    final currentWarehouseId = ref.read(selectedWarehouseIdProvider);
    state = AsyncData(
      await ref
          .read(productRepositoryProvider)
          .getAll(warehouseId: currentWarehouseId),
    );
  }

  Future<void> updateProduct(Product product) async {
    state = const AsyncLoading();

    // Récupérer l'ancien état du produit pour comparer la quantité
    final oldProduct = await ref
        .read(productRepositoryProvider)
        .getById(product.id);

    await ref.read(productRepositoryProvider).update(product);

    if (oldProduct != null && oldProduct.quantity != product.quantity) {
      final diff = product.quantity - oldProduct.quantity;
      final type = diff > 0 ? MovementType.IN : MovementType.OUT;
      final quantityAbs = diff.abs();

      final user = await ref.read(authServiceProvider.future);
      final activeSession = await ref.read(activeSessionProvider.future);
      final userId = user?.id ?? "admin";

      final movement = StockMovement(
        productId: product.id,
        type: type,
        quantity: quantityAbs,
        reason: "Ajustement d'inventaire manuel",
        userId: userId,
        sessionId: activeSession?.id,
      );
      await ref.read(stockMovementRepositoryProvider).insert(movement);

      // --- SYNCHRO RÉSEAU ---
      final settings = ref.read(shopSettingsProvider).value;
      if (settings?.networkMode == NetworkMode.client) {
        ref.read(clientSyncProvider).sendProductToServer(product);
        ref.read(clientSyncProvider).sendStockMovementToServer(movement);
        ref.read(clientSyncProvider).syncPendingAuditData();
      }
    } else {
      // --- SYNCHRO RÉSEAU (Même sans mouvement de stock) ---
      final settings = ref.read(shopSettingsProvider).value;
      if (settings?.networkMode == NetworkMode.client) {
        ref.read(clientSyncProvider).sendProductToServer(product);
        ref.read(clientSyncProvider).syncPendingAuditData();
      }
    }

    final warehouseId = ref.read(selectedWarehouseIdProvider);
    state = AsyncData(
      await ref
          .read(productRepositoryProvider)
          .getAll(warehouseId: warehouseId),
    );
  }

  Future<void> deleteProduct(String id) async {
    state = const AsyncLoading();
    await ref.read(productRepositoryProvider).delete(id);
    final warehouseId = ref.read(selectedWarehouseIdProvider);
    state = AsyncData(
      await ref
          .read(productRepositoryProvider)
          .getAll(warehouseId: warehouseId),
    );
  }

  Future<void> refresh() async {
    final warehouseId = ref.read(selectedWarehouseIdProvider);
    state = const AsyncLoading();
    state = AsyncData(
      await ref
          .read(productRepositoryProvider)
          .getAll(warehouseId: warehouseId),
    );
  }

  Future<void> search(String query) async {
    final warehouseId = ref.read(selectedWarehouseIdProvider);
    state = const AsyncLoading();
    if (query.isEmpty) {
      state = AsyncData(
        await ref
            .read(productRepositoryProvider)
            .getAll(warehouseId: warehouseId),
      );
    } else {
      state = AsyncData(
        await ref
            .read(productRepositoryProvider)
            .search(query, warehouseId: warehouseId),
      );
    }
  }

  Future<void> _triggerNewProductEmail(Product product) async {
    try {
      final settings = ref.read(shopSettingsProvider).value;
      if (settings != null && settings.marketingEmailsEnabled) {
        final clients = await ref.read(clientListProvider.future);
        final marketingEmailService = ref.read(marketingEmailServiceProvider);
        
        // Asynchronous call (don't await to avoid blocking UI)
        marketingEmailService.broadcastNewProduct(product, clients);
      }
    } catch (_) {
      // Sliently fail for marketing
    }
  }
}

// Provider pour les statistiques du dashboard
final stockStatsProvider = Provider<StockStats>((ref) {
  final productsAsync = ref.watch(productListProvider);
  return productsAsync.when(
    data: (products) => StockStats.fromProducts(products),
    loading: () => StockStats.empty(),
    error: (_, __) => StockStats.empty(),
  );
});

class StockStats {
  final int totalProducts;
  final double totalQuantity;
  final double totalStockValue;
  final int lowStockCount;
  final int outOfStockCount;
  final double totalPotentialRevenue;

  StockStats({
    required this.totalProducts,
    required this.totalQuantity,
    required this.totalStockValue,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.totalPotentialRevenue,
  });

  int get criticalStockCount => lowStockCount + outOfStockCount;

  factory StockStats.fromProducts(List<Product> products) {
    return StockStats(
      totalProducts: products.length,
      totalQuantity: products.fold(0.0, (sum, p) => sum + (p.isService ? 0.0 : p.quantity)),
      totalStockValue: products.fold(0.0, (sum, p) => sum + p.stockValue),
      lowStockCount: products.where((p) => p.isLowStock).length,
      outOfStockCount: products.where((p) => p.isOutOfStock).length,
      totalPotentialRevenue: products.fold(
        0.0,
        (sum, p) => sum + (p.sellingPrice * (p.isService ? 0.0 : p.quantity)),
      ),
    );
  }

  factory StockStats.empty() {
    return StockStats(
      totalProducts: 0,
      totalQuantity: 0.0,
      totalStockValue: 0.0,
      lowStockCount: 0,
      outOfStockCount: 0,
      totalPotentialRevenue: 0.0,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/features/srm/domain/models/supplier.dart';
import 'package:danaya_plus/features/srm/data/supplier_repository.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/network/client_sync_service.dart';

final supplierListProvider =
    AsyncNotifierProvider<SupplierListNotifier, List<Supplier>>(
  SupplierListNotifier.new,
);

class SupplierListNotifier extends AsyncNotifier<List<Supplier>> {
  @override
  Future<List<Supplier>> build() async {
    return ref.watch(supplierRepositoryProvider).getAll();
  }

  Future<void> addSupplier(Supplier supplier) async {
    state = const AsyncLoading();
    await ref.read(supplierRepositoryProvider).insert(supplier);
    
    // --- SYNCHRO RÉSEAU ---
    final settings = ref.read(shopSettingsProvider).value;
    if (settings?.networkMode == NetworkMode.client) {
      ref.read(clientSyncProvider).sendSupplierToServer(supplier);
      ref.read(clientSyncProvider).syncPendingAuditData();
    }

    state = AsyncData(await ref.read(supplierRepositoryProvider).getAll());
  }

  Future<void> updateSupplier(Supplier supplier) async {
    state = const AsyncLoading();
    await ref.read(supplierRepositoryProvider).update(supplier);
    
    // --- SYNCHRO RÉSEAU ---
    final settings = ref.read(shopSettingsProvider).value;
    if (settings?.networkMode == NetworkMode.client) {
      ref.read(clientSyncProvider).sendSupplierToServer(supplier);
      ref.read(clientSyncProvider).syncPendingAuditData();
    }

    state = AsyncData(await ref.read(supplierRepositoryProvider).getAll());
  }

  Future<void> deleteSupplier(String id) async {
    state = const AsyncLoading();
    await ref.read(supplierRepositoryProvider).delete(id);
    state = AsyncData(await ref.read(supplierRepositoryProvider).getAll());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await ref.read(supplierRepositoryProvider).getAll());
  }
}

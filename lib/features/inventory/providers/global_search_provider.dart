import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/inventory/data/product_repository.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';

enum SearchResultType { product, client }

class GlobalSearchResult {
  final String id;
  final String title;
  final String subtitle;
  final SearchResultType type;
  final dynamic original;

  GlobalSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.original,
  });
}

final globalSearchProvider = AsyncNotifierProvider<GlobalSearchNotifier, List<GlobalSearchResult>>(
  GlobalSearchNotifier.new,
);

final searchSelectionProvider =
    NotifierProvider<SearchSelectionNotifier, String?>(
  SearchSelectionNotifier.new,
);

class SearchSelectionNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

class GlobalSearchNotifier extends AsyncNotifier<List<GlobalSearchResult>> {
  @override
  Future<List<GlobalSearchResult>> build() async {
    return [];
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const AsyncData([]);
      return;
    }

    state = const AsyncLoading();
    
    try {
      final productRepo = ref.read(productRepositoryProvider);
      final db = await ref.read(databaseServiceProvider).database;

      final settings = ref.read(shopSettingsProvider).value;
      final currency = settings?.currency ?? 'FCFA';

      final products = await productRepo.search(query); 
      final clientMaps = await db.query( 
        'clients',
        where: 'name LIKE ? OR phone LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        limit: 10,
      );
      final clients = clientMaps.map((m) => Client.fromMap(m)).toList();

      final List<GlobalSearchResult> results = [];

      // Search Products
      final productMatches = products; // Repo search is already filtered

      for (var p in productMatches) {
        final stockStatus = p.quantity <= 0 ? "🔴 Rupture" : (p.quantity <= p.alertThreshold ? "🟡 Bas" : "🟢 En stock");
        final barcode = p.barcode != null ? " | ${p.barcode}" : "";
        results.add(GlobalSearchResult(
          id: p.id,
          title: p.name,
          subtitle: "$stockStatus (${DateFormatter.formatQuantity(p.quantity)})$barcode | ${p.sellingPrice} $currency",
          type: SearchResultType.product,
          original: p,
        ));
      }

      // Search Clients
      final clientMatches = clients;
      for (var c in clientMatches) {
        final debt = c.credit > 0 ? " | ⚠️ Dette: ${c.credit} $currency" : "";
        results.add(GlobalSearchResult(
          id: c.id,
          title: c.name,
          subtitle: "Client${c.phone != null ? ' | ${c.phone}' : ''}$debt",
          type: SearchResultType.client,
          original: c,
        ));
      }

      state = AsyncData(results);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void clear() {
    state = const AsyncData([]);
  }
}

import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/pos/providers/sales_history_providers.dart';
import 'package:danaya_plus/features/assistant/application/assistant_tone.dart';

class HorizonPrediction {
  final double predictedValue;
  final String trend;
  final String suggestion;
  final String key; // Unique key for deduplication

  HorizonPrediction({
    required this.predictedValue,
    required this.trend,
    required this.suggestion,
    String? key,
  }) : key = key ?? trend;
}

class HorizonEngine {
  // ═══════════════════════════════════════════════════════════════════════
  //  MAIN ENTRY — Generate all business insights
  // ═══════════════════════════════════════════════════════════════════════
  List<HorizonPrediction> generateBusinessInsights({
    required List<SaleWithDetails> sales,
    required List<Client> clients,
    required List<Product> products,
    required String Function(double) formatCurrency,
  }) {
    final insights = <HorizonPrediction>[];

    // 1. Survival Guard
    insights.addAll(_checkSurvivalGuard(products));

    // 2. Smart Trader
    insights.addAll(findDormantProducts(products, sales, formatCurrency));

    // 3. Human CRM
    insights.addAll(_checkHumanCRM(clients));

    // 4. Stock Depletion Prediction (Titan Feature)
    insights.addAll(_predictStockDepletion(products, sales));

    return insights;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SURVIVAL GUARD — Real margin analysis by category
  // ═══════════════════════════════════════════════════════════════════════
  List<HorizonPrediction> _checkSurvivalGuard(List<Product> products) {
    final insights = <HorizonPrediction>[];
    if (products.isEmpty) return insights;

    // Group products by category and calculate average margin
    final Map<String, List<Product>> byCategory = {};
    for (final p in products) {
      if (p.isService) continue;
      final cat = p.category ?? 'Sans catégorie';
      byCategory.putIfAbsent(cat, () => []).add(p);
    }

    for (final entry in byCategory.entries) {
      final prods = entry.value.where((p) => p.sellingPrice > 0).toList();
      if (prods.isEmpty) continue;
      final avgMargin = prods.fold(0.0, (sum, p) => sum + p.marginPercent) / prods.length;
      if (avgMargin < 10 && avgMargin >= 0) {
        insights.add(HorizonPrediction(
          predictedValue: avgMargin,
          trend: "SURVIE",
          key: "survie_${entry.key}",
          suggestion: "⚠️ Alerte Survie : La catégorie '${entry.key}' a une marge moyenne de ${avgMargin.toStringAsFixed(1)}%. Réajustez vos prix !",
        ));
      }
    }
    return insights;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SMART TRADER — Dormant stock detection
  // ═══════════════════════════════════════════════════════════════════════
  List<HorizonPrediction> findDormantProducts(List<Product> products, List<SaleWithDetails> sales, String Function(double) formatCurrency) {
    final insights = <HorizonPrediction>[];
    if (products.isEmpty) return insights;

    // Collect all productIds sold in the last 60 days
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 60));
    final soldIds = <String>{};
    for (final swd in sales) {
      if (swd.sale.date.isAfter(cutoff)) {
        for (final item in swd.items) {
          if (item.item.productId != null) soldIds.add(item.item.productId!);
        }
      }
    }

    // Find products with stock but no sales
    final dormant = products.where((p) => !p.isService && p.quantity > 0 && !soldIds.contains(p.id)).toList();
    if (dormant.isNotEmpty) {
      final totalValue = dormant.fold(0.0, (sum, p) => sum + p.stockValue);
      final topNames = dormant.take(3).map((p) => p.name).join(', ');
      final tone = AssistantTone.deadStock();
      insights.add(HorizonPrediction(
        predictedValue: totalValue,
        trend: "TRADER",
        key: "trader_dormant_${dormant.length}_${now.day}", // Key changes daily so it can trigger again
        suggestion: "$tone\n\n**Produits concernés** : $topNames (${dormant.length} au total).\n**Valeur immobilisée** : ${formatCurrency(totalValue)}.",
      ));
    }
    return insights;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  HUMAN CRM — Inactive client detection
  // ═══════════════════════════════════════════════════════════════════════
  List<HorizonPrediction> _checkHumanCRM(List<Client> clients) {
    final insights = <HorizonPrediction>[];
    final now = DateTime.now();
    int inactiveCount = 0;
    final inactiveNames = <String>[];

    for (var client in clients) {
      if (client.lastPurchaseDate != null) {
        final diff = now.difference(client.lastPurchaseDate!).inDays;
        if (diff > 30) {
          inactiveCount++;
          if (inactiveNames.length < 3) inactiveNames.add(client.name);
        }
      }
    }

    if (inactiveCount > 0) {
      final tone = AssistantTone.clientChurn();
      insights.add(HorizonPrediction(
        predictedValue: inactiveCount.toDouble(),
        trend: "CRM",
        key: "crm_inactive_${inactiveCount}_${now.day}",
        suggestion: "$tone\n\n**Exemples de clients absents depuis 30j** : ${inactiveNames.join(', ')}.",
      ));
    }
    return insights;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  RUSH HOUR — Sales velocity detection
  // ═══════════════════════════════════════════════════════════════════════
  bool isRushHour(List<SaleWithDetails> recentSales) {
    if (recentSales.length < 3) return false;
    final now = DateTime.now();
    final tenMinAgo = now.subtract(const Duration(minutes: 10));
    final recentCount = recentSales.where((s) => s.sale.date.isAfter(tenMinAgo)).length;
    return recentCount >= 3;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  STOCK DEPLETION PREDICTION (TITAN)
  // ═══════════════════════════════════════════════════════════════════════
  List<HorizonPrediction> _predictStockDepletion(List<Product> products, List<SaleWithDetails> sales) {
    final insights = <HorizonPrediction>[];
    
    // We only care about products with stock > 0
    final activeProducts = products.where((p) => !p.isService && p.quantity > 0).toList();
    if (activeProducts.isEmpty) return insights;

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Map productId -> total qty sold in last 30 days
    final Map<String, double> qtySoldLast30Days = {};
    for (final swd in sales) {
      if (swd.sale.date.isAfter(thirtyDaysAgo)) {
        for (final item in swd.items) {
          final pid = item.item.productId;
          if (pid != null) {
            qtySoldLast30Days[pid] = (qtySoldLast30Days[pid] ?? 0) + item.item.quantity;
          }
        }
      }
    }

    final topDepletions = <MapEntry<Product, int>>[];

    for (final p in activeProducts) {
      final sold = qtySoldLast30Days[p.id] ?? 0;
      if (sold > 0) {
        final avgDailySales = sold / 30.0;
        final daysLeft = (p.quantity / avgDailySales).floor();
        
        // If stock will deplete in less than 4 days
        if (daysLeft < 4) {
          topDepletions.add(MapEntry(p, daysLeft));
        }
      }
    }

    if (topDepletions.isNotEmpty) {
      // Sort to show the most urgent first
      topDepletions.sort((a, b) => a.value.compareTo(b.value));
      for (int i = 0; i < topDepletions.length && i < 2; i++) {
        final p = topDepletions[i].key;
        final d = topDepletions[i].value;
        String dayText = d == 0 ? "moins de 24h" : "$d jour(s)";
        insights.add(HorizonPrediction(
          predictedValue: d.toDouble(),
          trend: "DEPLETION",
          key: "depletion_${p.id}_$d",
          suggestion: "⏳ **Prédiction Horizon** : Au rythme actuel, le produit '${p.name}' sera en rupture totale dans **$dayText**. Pensez à ré-approvisionner !",
        ));
      }
    }

    return insights;
  }
}

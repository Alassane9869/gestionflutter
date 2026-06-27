import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/reports/domain/models/report_models.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';

final dateRangeProvider = NotifierProvider<DateRangeNotifier, DateTimeRange>(() {
  return DateRangeNotifier();
});

class DateRangeNotifier extends Notifier<DateTimeRange> {
  @override
  DateTimeRange build() {
    final now = DateTime.now();
    return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
  }

  void updateRange(DateTimeRange newRange) {
    state = newRange;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. KPI Provider (Revenue, Profit, Margins, Count)
//
// FORMULES DE CALCUL :
//
// ● CA (Chiffre d'Affaires) = Σ(total_amount) - Σ(refunded_amount)
//     → C'est le CA net après remboursements
//
// ● Bénéfice (Profit) = Σ((prix_vente - coût_réel) × quantité_nette)
//     → coût_réel = weighted_average_cost SI > 0, SINON purchasePrice
//     → quantité_nette = quantity - returned_quantity
//     → Calcul PRODUIT PAR PRODUIT via sale_items + products
//     → Ne déduit PAS les dépenses (c'est la marge brute commerciale)
//
// ● Dépenses = Σ(financial_transactions WHERE type='OUT' AND category='EXPENSE')
//     → Sorties catégorisées comme dépenses uniquement
//
// ● Marge (%) = (Bénéfice / CA) × 100
//     → Marge brute commerciale, pas marge nette
//     → Pour la marge nette : (Bénéfice - Dépenses) / CA × 100
// ─────────────────────────────────────────────────────────────────────────────
final reportKPIsProvider = FutureProvider.family<ReportKPIs, DateTimeRange>((ref, range) async {
  final db = await ref.read(databaseServiceProvider).database;
  
  final startStr = range.start.toIso8601String();
  final endStr = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59).toIso8601String();

  // CA NET = Σ(total_amount) - Σ(refunded_amount)
  final salesData = await db.rawQuery('''
    SELECT 
      COUNT(id) as sales_count,
      COALESCE(SUM(total_amount), 0) as total_revenue,
      COALESCE(SUM(refunded_amount), 0) as total_refunded
    FROM sales
    WHERE date >= ? AND date <= ?
  ''', [startStr, endStr]);

  final revData = salesData.first;
  final revenue = (revData['total_revenue'] as num).toDouble() - (revData['total_refunded'] as num).toDouble();
  final count = (revData['sales_count'] as num).toInt();

  // BÉNÉFICE = Σ((prix_vente_net - coût_réel) × quantité_nette) - Σ(remises_globales)
  final profitData = await db.rawQuery('''
    SELECT 
      si.product_id,
      p.name,
      p.purchasePrice,
      p.weighted_average_cost,
      SUM(si.quantity - si.returned_quantity) as net_qty,
      SUM(
        (si.unit_price * (1 - COALESCE(si.discount_percent, 0)/100) - 
         COALESCE(NULLIF(si.cost_price, 0), p.weighted_average_cost, p.purchasePrice, 0)
        ) * (si.quantity - si.returned_quantity)
      ) as item_profit
    FROM sale_items si
    JOIN sales s ON si.sale_id = s.id
    LEFT JOIN products p ON si.product_id = p.id
    WHERE s.date >= ? AND s.date <= ?
    GROUP BY si.product_id, p.name, p.purchasePrice, p.weighted_average_cost
  ''', [startStr, endStr]);

  double grossProfit = 0;
  for (var row in profitData) {
    final itemProfit = (row['item_profit'] as num).toDouble();
    final pPrice = (row['purchasePrice'] as num).toDouble();
    final pWac = (row['weighted_average_cost'] as num? ?? 0.0).toDouble();
    
    if (pPrice < 0 || pWac < 0 || pPrice > 1000000000 || pWac > 1000000000) {
      debugPrint("!!! DONNÉE CORROMPUE DÉTECTÉE !!! Produit: ${row['name']} (ID: ${row['product_id']}) | Prix d'achat: $pPrice | CMUP: $pWac");
    }
    
    grossProfit += itemProfit;
  }

  // Global discounts for the period
  final discountData = await db.rawQuery('''
    SELECT COALESCE(SUM(discount_amount), 0) as total_discount
    FROM sales
    WHERE date >= ? AND date <= ?
  ''', [startStr, endStr]);
  
  final totalGlobalDiscount = (discountData.first['total_discount'] as num).toDouble();
  final profit = grossProfit - totalGlobalDiscount;

  // DÉPENSES = Sorties catégorisées "EXPENSE"
  final expensesData = await db.rawQuery('''
    SELECT COALESCE(SUM(amount), 0) as total_expenses
    FROM financial_transactions
    WHERE type = 'OUT' AND category = 'EXPENSE' AND date >= ? AND date <= ?
  ''', [startStr, endStr]);
  
  final expenses = (expensesData.first['total_expenses'] as num).toDouble();

  return ReportKPIs(
    totalRevenue: revenue > 0 ? revenue : 0, 
    totalProfit: profit, 
    totalExpenses: expenses, 
    salesCount: count
  );
});

// 2. Top Products Provider
final topProductsProvider = FutureProvider.family<List<TopProduct>, DateTimeRange>((ref, range) async {
  final db = await ref.read(databaseServiceProvider).database;
  
  final startStr = range.start.toIso8601String();
  final endStr = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59).toIso8601String();

  final result = await db.rawQuery('''
    SELECT 
      p.id, p.name, 
      SUM(si.quantity - si.returned_quantity) as total_qty,
      SUM((si.quantity - si.returned_quantity) * si.unit_price * (1 - COALESCE(si.discount_percent, 0)/100)) as total_rev
    FROM sale_items si
    JOIN sales s ON si.sale_id = s.id
    JOIN products p ON si.product_id = p.id
    WHERE s.date >= ? AND s.date <= ?
    GROUP BY p.id, p.name
    HAVING total_qty > 0
    ORDER BY total_qty DESC
    LIMIT 10
  ''', [startStr, endStr]);

  return result.map((row) => TopProduct(
    id: row['id'] as String,
    name: row['name'] as String,
    totalQuantity: (row['total_qty'] as num).toInt(),
    totalRevenue: (row['total_rev'] as num).toDouble(),
  )).toList();
});

// 3. Revenue Trend Chart Provider (Last 7 days or Monthly depending on range size)
final revenueChartProvider = FutureProvider.family<List<ChartDataPoint>, DateTimeRange>((ref, range) async {
  final db = await ref.read(databaseServiceProvider).database;
  final diffDays = range.end.difference(range.start).inDays;
  
  final startStr = range.start.toIso8601String();
  final endStr = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59).toIso8601String();

  if (diffDays <= 31) {
    // Daily breakdown
    final result = await db.rawQuery('''
      SELECT 
        STRFTIME('%Y-%m-%d', date) as day_date,
        SUM(total_amount - refunded_amount) as daily_revenue
      FROM sales
      WHERE date >= ? AND date <= ?
      GROUP BY day_date
      ORDER BY day_date ASC
    ''', [startStr, endStr]);

    return result.map((row) {
      final date = DateTime.parse(row['day_date'] as String);
      return ChartDataPoint(
        label: DateFormatter.formatCompactDate(date),
        value: (row['daily_revenue'] as num).toDouble(),
      );
    }).toList();
  } else {
    // Monthly breakdown
    final result = await db.rawQuery('''
      SELECT 
        STRFTIME('%Y-%m', date) as month_date,
        SUM(total_amount - refunded_amount) as monthly_revenue
      FROM sales
      WHERE date >= ? AND date <= ?
      GROUP BY month_date
      ORDER BY month_date ASC
    ''', [startStr, endStr]);

    return result.map((row) {
      final str = row['month_date'] as String;
      final year = int.parse(str.split('-')[0]);
      final month = int.parse(str.split('-')[1]);
      final date = DateTime(year, month);
      return ChartDataPoint(
        label: DateFormatter.formatMonthYear(date),
        value: (row['monthly_revenue'] as num).toDouble(),
      );
    }).toList();
  }
});

// 4. Sales by User Provider
final userSalesSummaryProvider = FutureProvider.family<List<UserSaleSummary>, DateTimeRange>((ref, range) async {
  final db = await ref.read(databaseServiceProvider).database;
  
  final startStr = range.start.toIso8601String();
  final endStr = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59).toIso8601String();

  final res = await db.rawQuery('''
    SELECT 
      u.username,
      COUNT(s.id) as sales_count,
      SUM(s.total_amount - s.refunded_amount) as net_revenue
    FROM sales s
    JOIN users u ON s.user_id = u.id
    WHERE s.date >= ? AND s.date <= ?
    GROUP BY u.id, u.username
    ORDER BY net_revenue DESC
  ''', [startStr, endStr]);

  return res.map((row) => UserSaleSummary(
    username: row['username'] as String,
    totalRevenue: (row['net_revenue'] as num).toDouble(),
    salesCount: (row['sales_count'] as num).toInt(),
  )).toList();
});

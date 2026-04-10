import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';

enum DashboardFilter { today, week, month, custom }

final dashboardFilterProvider =
    NotifierProvider<DashboardFilterNotifier, DashboardFilterState>(
      DashboardFilterNotifier.new,
    );

class DashboardFilterState {
  final DashboardFilter filter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const DashboardFilterState({
    required this.filter,
    this.customStartDate,
    this.customEndDate,
  });
}

class DashboardFilterNotifier extends Notifier<DashboardFilterState> {
  @override
  DashboardFilterState build() =>
      const DashboardFilterState(filter: DashboardFilter.today);

  void setFilter(DashboardFilter filter) {
    state = DashboardFilterState(
      filter: filter,
      customStartDate: state.customStartDate,
      customEndDate: state.customEndDate,
    );
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = DashboardFilterState(
      filter: DashboardFilter.custom,
      customStartDate: start,
      customEndDate: end,
    );
  }
}

class DashboardMetrics {
  final double totalRevenue;
  final double periodRevenue;
  final double revenueTrend;
  final double salesTrend;
  final double averageBasket;
  final double basketTrend;
  final int periodSalesCount;
  final int totalClientsCount;
  final int totalProductsCount;
  final double totalDebtAmount;
  final int debtClientsCount;
  final double totalProfitPeriod;
  final double profitTrend;
  final List<Map<String, dynamic>> topProducts;
  final List<Map<String, dynamic>> recentSales;
  final List<double> revenueSparkline;
  final List<double> basketSparkline;
  final List<Map<String, dynamic>> revenueChartData;
  final List<Map<String, dynamic>> topDebtors;
  final List<Map<String, dynamic>> lowStockProducts;
  final int lowStockCount;
  final int outOfStockCount;
  final double totalStockValue;
  final double totalPotentialProfit;
  final double totalExpensesPeriod;

  const DashboardMetrics({
    this.totalRevenue = 0.0,
    this.periodRevenue = 0.0,
    this.revenueTrend = 0.0,
    this.salesTrend = 0.0,
    this.averageBasket = 0.0,
    this.basketTrend = 0.0,
    this.periodSalesCount = 0,
    this.totalClientsCount = 0,
    this.totalProductsCount = 0,
    this.totalDebtAmount = 0.0,
    this.debtClientsCount = 0,
    this.totalProfitPeriod = 0.0,
    this.profitTrend = 0.0,
    this.topProducts = const [],
    this.recentSales = const [],
    this.revenueSparkline = const [],
    this.basketSparkline = const [],
    this.revenueChartData = const [],
    this.topDebtors = const [],
    this.lowStockProducts = const [],
    this.lowStockCount = 0,
    this.outOfStockCount = 0,
    this.totalStockValue = 0.0,
    this.totalPotentialProfit = 0.0,
    this.totalExpensesPeriod = 0.0,
  });
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardMetrics>(
      DashboardNotifier.new,
    );

class DashboardNotifier extends AsyncNotifier<DashboardMetrics> {
  @override
  Future<DashboardMetrics> build() async {
    final filter = ref.watch(dashboardFilterProvider);
    return _fetchMetrics(filter);
  }

  Future<DashboardMetrics> _fetchMetrics(
    DashboardFilterState filterState,
  ) async {
    final filter = filterState.filter;
    
    // GUARD: S'assurer que la DB est prête avant de lancer les requêtes
    Database db;
    try {
      db = await ref.read(databaseServiceProvider).database;
    } catch (e) {
      debugPrint('⚠️ DashboardProvider: DB non prête, abandon: $e');
      return const DashboardMetrics(); // Retourner des métriques vides plutôt qu'une erreur
    }

    final user = ref.read(authServiceProvider).value;
    // GUARD: Si l'utilisateur n'est pas encore connecté, retourner vide
    if (user == null) {
      debugPrint('⚠️ DashboardProvider: Utilisateur null, retour métriques vides');
      return const DashboardMetrics();
    }
    
    final isGlobalRole =
        user.role == UserRole.admin ||
        user.role == UserRole.manager ||
        user.role == UserRole.adminPlus;

    try {


    // 1. Total Revenue (Overall or Individual)
    String totalRevQuery = 'SELECT SUM(total_amount) as total FROM sales';
    List<dynamic> totalRevArgs = [];
    if (!isGlobalRole) {
      totalRevQuery += ' WHERE user_id = ?';
      totalRevArgs.add(user.id);
    }

    final totalRevenueResult = await db.rawQuery(totalRevQuery, totalRevArgs);
    final totalRevenue =
        (totalRevenueResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // 2. Period Calculations
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime startDate;

    switch (filter) {
      case DashboardFilter.today:
        startDate = today;
        break;
      case DashboardFilter.week:
        startDate = today.subtract(const Duration(days: 7));
        break;
      case DashboardFilter.month:
        startDate = DateTime(now.year, now.month, 1);
        break;
      case DashboardFilter.custom:
        startDate = filterState.customStartDate ?? today;
        break;
    }

    // Determine query parameters based on filter type
    String dateCondition = 'date >= ?';
    List<dynamic> dateArgs = [startDate.toIso8601String()];

    if (filter == DashboardFilter.custom && filterState.customEndDate != null) {
      dateCondition = 'date >= ? AND date <= ?';
      dateArgs = [
        startDate.toIso8601String(),
        // End of the selected day
        DateTime(
          filterState.customEndDate!.year,
          filterState.customEndDate!.month,
          filterState.customEndDate!.day,
          23,
          59,
          59,
        ).toIso8601String(),
      ];
    }

    // Add user filter for individual roles
    String userCondition = '';
    List<dynamic> userArgs = [];
    if (!isGlobalRole) {
      userCondition = ' AND user_id = ?';
      userArgs.add(user.id);
    }

    final periodResult = await db.rawQuery(
      'SELECT SUM(total_amount - refunded_amount) as period_total, COUNT(*) as period_count FROM sales WHERE $dateCondition$userCondition',
      [...dateArgs, ...userArgs],
    );
    final periodRevenue =
        (periodResult.first['period_total'] as num?)?.toDouble() ?? 0.0;
    final periodCount =
        (periodResult.first['period_count'] as num?)?.toInt() ?? 0;
    final averageBasket = periodCount > 0 ? periodRevenue / periodCount : 0.0;

    // 3. Trends (Current Period vs Previous Period)
    double trend = 0.0;
    double sTrend = 0.0;
    double bTrend = 0.0;
    double pTrend = 0.0;

    DateTime prevStartDate = startDate;
    DateTime prevEndDate = startDate;

    if (filter == DashboardFilter.today) {
      prevStartDate = today.subtract(const Duration(days: 1));
      prevEndDate = today;
    } else if (filter == DashboardFilter.week) {
      prevStartDate = startDate.subtract(const Duration(days: 7));
      prevEndDate = startDate;
    } else if (filter == DashboardFilter.month) {
      int prevMonth = startDate.month - 1;
      int prevYear = startDate.year;
      if (prevMonth == 0) {
        prevMonth = 12;
        prevYear -= 1;
      }
      prevStartDate = DateTime(prevYear, prevMonth, 1);
      prevEndDate = startDate;
    } else if (filter == DashboardFilter.custom &&
        filterState.customEndDate != null) {
      final diff = filterState.customEndDate!.difference(
        filterState.customStartDate ?? today,
      );
      prevEndDate = filterState.customStartDate ?? today;
      prevStartDate = prevEndDate.subtract(diff);
    }

    if (filter != DashboardFilter.custom || filterState.customEndDate != null) {
      // Comparison period results
      final prevResult = await db.rawQuery(
        'SELECT SUM(total_amount - refunded_amount) as prev_total, COUNT(*) as prev_count FROM sales WHERE date >= ? AND date <= ?$userCondition',
        [
          prevStartDate.toIso8601String(),
          DateTime(
            prevEndDate.year,
            prevEndDate.month,
            prevEndDate.day,
            23,
            59,
            59,
          ).toIso8601String(),
          ...userArgs,
        ],
      );
      final prevRevenue =
          (prevResult.first['prev_total'] as num?)?.toDouble() ?? 0.0;
      final prevCount = (prevResult.first['prev_count'] as num?)?.toInt() ?? 0;
      final prevAvgBasket = prevCount > 0 ? prevRevenue / prevCount : 0.0;

      if (prevRevenue > 0) {
        trend = ((periodRevenue - prevRevenue) / prevRevenue) * 100;
      }
      if (prevCount > 0) {
        sTrend = ((periodCount - prevCount) / prevCount) * 100;
      }
      if (prevAvgBasket > 0) {
        bTrend = ((averageBasket - prevAvgBasket) / prevAvgBasket) * 100;
      }
    }

    // 4. Top Products (Filtered by user for individual roles)
    String topProductsQuery;
    List<dynamic> topProductsArgs = [];
    if (isGlobalRole) {
      topProductsQuery = '''
        SELECT p.name, SUM(si.quantity) as total_qty, SUM(si.quantity * si.unit_price) as total_sales
        FROM sale_items si
        JOIN products p ON si.product_id = p.id
        GROUP BY si.product_id
        ORDER BY total_qty DESC
        LIMIT 5
      ''';
    } else {
      topProductsQuery = '''
        SELECT p.name, SUM(si.quantity) as total_qty, SUM(si.quantity * si.unit_price) as total_sales
        FROM sale_items si
        JOIN products p ON si.product_id = p.id
        JOIN sales s ON si.sale_id = s.id
        WHERE s.user_id = ?
        GROUP BY si.product_id
        ORDER BY total_qty DESC
        LIMIT 5
      ''';
      topProductsArgs.add(user.id);
    }
    final topProducts = await db.rawQuery(topProductsQuery, topProductsArgs);

    // 5. Recent Sales
    final recentSales = await db.query(
      'sales',
      where: isGlobalRole ? null : 'user_id = ?',
      whereArgs: isGlobalRole ? null : [user.id],
      orderBy: 'date DESC',
      limit: 10,
    );

    // 6. Chart Data (Last 7 Days or selected period)
    final chartData = await db.rawQuery(
      '''
      SELECT SUBSTR(date, 1, 10) as day, SUM(total_amount) as total, AVG(total_amount) as avg_basket
      FROM sales
      WHERE $dateCondition$userCondition
      GROUP BY day
      ORDER BY day ASC
    ''',
      [...dateArgs, ...userArgs],
    );

    final revenueSparkline = chartData
        .map((e) => (e['total'] as num?)?.toDouble() ?? 0.0)
        .toList();
    final basketSparkline = chartData
        .map((e) => (e['avg_basket'] as num?)?.toDouble() ?? 0.0)
        .toList();

    // 7. Top Debtors (VISIBLE ONLY FOR GLOBAL ROLES)
    final topDebtors = !isGlobalRole
        ? <Map<String, dynamic>>[]
        : await db.rawQuery('''
      SELECT name, phone, credit 
      FROM clients 
      WHERE credit > 0 
      ORDER BY credit DESC 
      LIMIT 5
    ''');

    // 8. Stock Alerts (quantity and alertThreshold columns)
    final stockAlerts = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN quantity <= alertThreshold AND quantity > 0 THEN 1 ELSE 0 END) as low_stock,
        SUM(CASE WHEN quantity <= 0 THEN 1 ELSE 0 END) as out_of_stock
      FROM products
    ''');
    final lowStockCount =
        (stockAlerts.first['low_stock'] as num?)?.toInt() ?? 0;
    final outOfStockCount =
        (stockAlerts.first['out_of_stock'] as num?)?.toInt() ?? 0;

    // ═══ NOUVEAUX INDICATEURS ═══

    // 9. Total Clients
    final clientsResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM clients',
    );
    final totalClientsCount =
        (clientsResult.first['cnt'] as num?)?.toInt() ?? 0;

    // 10. Total Products & Stock Value
    // Valeur Stock = Quantité * CMUP
    // Profit Potentiel = Quantité * (Marge unitaire)
    final productsResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as cnt,
        SUM(quantity * COALESCE(NULLIF(weighted_average_cost, 0), purchasePrice, 0)) as total_val,
        SUM(quantity * (sellingPrice - COALESCE(NULLIF(weighted_average_cost, 0), purchasePrice, 0))) as potential_profit
      FROM products
      WHERE is_service = 0
    ''');
    final totalProductsCount =
        (productsResult.first['cnt'] as num?)?.toInt() ?? 0;
    final totalStockValue =
        (productsResult.first['total_val'] as num?)?.toDouble() ?? 0.0;
    final totalPotentialProfit =
        (productsResult.first['potential_profit'] as num?)?.toDouble() ?? 0.0;

    // 11. Total Debt Amount & Count (VISIBLE ONLY FOR GLOBAL ROLES)
    double totalDebtAmount = 0.0;
    int debtClientsCount = 0;
    if (isGlobalRole) {
      final debtResult = await db.rawQuery(
        'SELECT SUM(credit) as total_debt, COUNT(*) as debt_count FROM clients WHERE credit > 0',
      );
      totalDebtAmount =
          (debtResult.first['total_debt'] as num?)?.toDouble() ?? 0.0;
      debtClientsCount = (debtResult.first['debt_count'] as num?)?.toInt() ?? 0;
    }

    // 12. Period Profit (revenue - cost - discounts)
    // Utilise cost_price capturé (Phase A) si possible, sinon fallback CMUP
    double totalProfitPeriod = 0.0;
    double totalExpensesPeriod = 0.0;
    try {
      final profitResult = await db.rawQuery('''
        SELECT SUM(
          (si.quantity - si.returned_quantity) * 
          (si.unit_price * (1 - COALESCE(si.discount_percent, 0)/100) - 
           COALESCE(NULLIF(p.weighted_average_cost, 0), p.purchasePrice, 0))
        ) as gross_profit
        FROM sale_items si
        JOIN products p ON si.product_id = p.id
        JOIN sales s ON si.sale_id = s.id
        WHERE s.$dateCondition
      ''', dateArgs);

      final grossProfit =
          (profitResult.first['gross_profit'] as num?)?.toDouble() ?? 0.0;

      final discountResult = await db.rawQuery(
        'SELECT SUM(discount_amount) as total_discount FROM sales WHERE $dateCondition$userCondition',
        [...dateArgs, ...userArgs],
      );
      final totalGlobalDiscount =
          (discountResult.first['total_discount'] as num?)?.toDouble() ?? 0.0;

      // 12b. Dépenses de la période (Audit Phase 3)
      // Note: We'll filter expenses by account access in the treasury provider,
      // but here we can optionally filter by user if specific user-expenses are needed.
      // For now, if not global, we show 0 or individual if we had a user_id in financial_transactions.
      // Since financial_transactions doesn't strictly have a user_id (it uses account access),
      // we'll show 0 profit for individuals to hide sensitive margins.
      if (!isGlobalRole) {
        totalProfitPeriod = 0.0;
        totalExpensesPeriod = 0.0;
      } else {
        final expenseResult = await db.rawQuery(
          "SELECT SUM(amount) as total FROM financial_transactions WHERE category = 'EXPENSE' AND $dateCondition",
          dateArgs,
        );
        totalExpensesPeriod =
            (expenseResult.first['total'] as num?)?.toDouble() ?? 0.0;
        totalProfitPeriod =
            grossProfit - totalGlobalDiscount - totalExpensesPeriod;
      }

      if (filter != DashboardFilter.custom ||
          filterState.customEndDate != null) {
        final prevRangeArgs = [
          prevStartDate.toIso8601String(),
          DateTime(
            prevEndDate.year,
            prevEndDate.month,
            prevEndDate.day,
            23,
            59,
            59,
          ).toIso8601String(),
        ];

        final prevProfitResult = await db.rawQuery('''
            SELECT SUM(
              (si.quantity - si.returned_quantity) * 
              (si.unit_price * (1 - COALESCE(si.discount_percent, 0)/100) - 
               COALESCE(NULLIF(p.weighted_average_cost, 0), p.purchasePrice, 0))
            ) as gross_profit
            FROM sale_items si
            JOIN products p ON si.product_id = p.id
            JOIN sales s ON si.sale_id = s.id
            WHERE s.date >= ? AND s.date <= ?
          ''', prevRangeArgs);

        final prevGrossProfit =
            (prevProfitResult.first['prev_profit'] as num?)?.toDouble() ??
            (prevProfitResult.first['gross_profit'] as num?)?.toDouble() ??
            0.0;

        final prevDiscountResult = await db.rawQuery(
          'SELECT SUM(discount_amount) as total_discount FROM sales WHERE date >= ? AND date <= ?',
          prevRangeArgs,
        );
        final prevGlobalDiscount =
            (prevDiscountResult.first['total_discount'] as num?)?.toDouble() ??
            0.0;

        final prevExpenseResult = await db.rawQuery(
          "SELECT SUM(amount) as total FROM financial_transactions WHERE category = 'EXPENSE' AND date >= ? AND date <= ?",
          prevRangeArgs,
        );
        final prevExpenses =
            (prevExpenseResult.first['total'] as num?)?.toDouble() ?? 0.0;

        final prevProfit = prevGrossProfit - prevGlobalDiscount - prevExpenses;

        if (prevProfit > 0) {
          pTrend = ((totalProfitPeriod - prevProfit) / prevProfit) * 100;
        }
      }
    } catch (e) {
      debugPrint("Dashboard Profit Error: $e");
    }

    // 13. Low Stock Products (détail)
    final lowStockProducts = await db.rawQuery('''
      SELECT name, quantity, alertThreshold
      FROM products
      WHERE quantity <= alertThreshold AND quantity > 0
      ORDER BY quantity ASC
      LIMIT 5
    ''');

    return DashboardMetrics(
      totalRevenue: totalRevenue,
      periodRevenue: periodRevenue,
      revenueTrend: trend,
      salesTrend: sTrend,
      averageBasket: averageBasket,
      basketTrend: bTrend,
      periodSalesCount: periodCount,
      totalClientsCount: totalClientsCount,
      totalProductsCount: totalProductsCount,
      totalDebtAmount: totalDebtAmount,
      debtClientsCount: debtClientsCount,
      totalProfitPeriod: totalProfitPeriod,
      profitTrend: pTrend,
      topProducts: topProducts,
      recentSales: recentSales,
      revenueSparkline: revenueSparkline,
      basketSparkline: basketSparkline,
      revenueChartData: chartData,
      topDebtors: topDebtors,
      lowStockProducts: lowStockProducts,
      lowStockCount: lowStockCount,
      outOfStockCount: outOfStockCount,
      totalStockValue: isGlobalRole ? totalStockValue : 0.0,
      totalPotentialProfit: isGlobalRole ? totalPotentialProfit : 0.0,
      totalExpensesPeriod: totalExpensesPeriod,
    );
    } catch (e, st) {
      debugPrint('🚨 DashboardProvider: Erreur fatale de chargement: $e');
      debugPrint(st.toString().split('\n').take(5).join('\n'));
      // Retourner des métriques vides plutôt que propager l'erreur
      // Cela évite le blocage complet du dashboard
      return const DashboardMetrics();
    }
  }

  void refresh() => ref.invalidateSelf();
}


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardCustomizationSettings {
  final bool showKpis;
  final bool showRevenueChart;
  final bool showProductMix;
  final bool showTopSales;
  final bool showRecentSales;
  final bool showStockAlerts;
  final bool showFinancialSummary;
  final bool showDebtors;

  // Caissier
  final bool showCashierRecentSales;
  final bool showCashierTopProducts;
  final bool showCashierSessionInfo;
  final bool showCashierStockAlerts;

  const DashboardCustomizationSettings({
    this.showKpis = true,
    this.showRevenueChart = true,
    this.showProductMix = true,
    this.showTopSales = true,
    this.showRecentSales = true,
    this.showStockAlerts = true,
    this.showFinancialSummary = true,
    this.showDebtors = true,
    this.showCashierRecentSales = true,
    this.showCashierTopProducts = true,
    this.showCashierSessionInfo = true,
    this.showCashierStockAlerts = true,
  });

  DashboardCustomizationSettings copyWith({
    bool? showKpis,
    bool? showRevenueChart,
    bool? showProductMix,
    bool? showTopSales,
    bool? showRecentSales,
    bool? showStockAlerts,
    bool? showFinancialSummary,
    bool? showDebtors,
    bool? showCashierRecentSales,
    bool? showCashierTopProducts,
    bool? showCashierSessionInfo,
    bool? showCashierStockAlerts,
  }) {
    return DashboardCustomizationSettings(
      showKpis: showKpis ?? this.showKpis,
      showRevenueChart: showRevenueChart ?? this.showRevenueChart,
      showProductMix: showProductMix ?? this.showProductMix,
      showTopSales: showTopSales ?? this.showTopSales,
      showRecentSales: showRecentSales ?? this.showRecentSales,
      showStockAlerts: showStockAlerts ?? this.showStockAlerts,
      showFinancialSummary: showFinancialSummary ?? this.showFinancialSummary,
      showDebtors: showDebtors ?? this.showDebtors,
      showCashierRecentSales: showCashierRecentSales ?? this.showCashierRecentSales,
      showCashierTopProducts: showCashierTopProducts ?? this.showCashierTopProducts,
      showCashierSessionInfo: showCashierSessionInfo ?? this.showCashierSessionInfo,
      showCashierStockAlerts: showCashierStockAlerts ?? this.showCashierStockAlerts,
    );
  }
}

final dashboardCustomizationProvider =
    NotifierProvider<DashboardCustomizationNotifier, DashboardCustomizationSettings>(
      DashboardCustomizationNotifier.new,
    );

class DashboardCustomizationNotifier extends Notifier<DashboardCustomizationSettings> {
  static const _prefix = 'dash_custom_';

  @override
  DashboardCustomizationSettings build() {
    _loadSettings();
    return const DashboardCustomizationSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = DashboardCustomizationSettings(
      showKpis: prefs.getBool('${_prefix}kpis') ?? true,
      showRevenueChart: prefs.getBool('${_prefix}revenue_chart') ?? true,
      showProductMix: prefs.getBool('${_prefix}product_mix') ?? true,
      showTopSales: prefs.getBool('${_prefix}top_sales') ?? true,
      showRecentSales: prefs.getBool('${_prefix}recent_sales') ?? true,
      showStockAlerts: prefs.getBool('${_prefix}stock_alerts') ?? true,
      showFinancialSummary: prefs.getBool('${_prefix}financial_summary') ?? true,
      showDebtors: prefs.getBool('${_prefix}debtors') ?? true,
      showCashierRecentSales: prefs.getBool('${_prefix}cashier_recent_sales') ?? true,
      showCashierTopProducts: prefs.getBool('${_prefix}cashier_top_products') ?? true,
      showCashierSessionInfo: prefs.getBool('${_prefix}cashier_session_info') ?? true,
      showCashierStockAlerts: prefs.getBool('${_prefix}cashier_stock_alerts') ?? true,
    );
  }

  Future<void> toggleSection(String section, bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    switch (section.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '')) {
      case 'kpis':
      case 'kpi':
        state = state.copyWith(showKpis: visible);
        await prefs.setBool('${_prefix}kpis', visible);
        break;
      case 'revenuechart':
      case 'revenu':
      case 'revenus':
      case 'graphiquerevenu':
      case 'graphiquerevenus':
      case 'graphiquedesrevenus':
        state = state.copyWith(showRevenueChart: visible);
        await prefs.setBool('${_prefix}revenue_chart', visible);
        break;
      case 'productmix':
      case 'mixproduit':
      case 'mixproduits':
      case 'meilleuresventesgraphique':
        state = state.copyWith(showProductMix: visible);
        await prefs.setBool('${_prefix}product_mix', visible);
        break;
      case 'topsales':
      case 'topventes':
      case 'meilleuresventes':
        state = state.copyWith(showTopSales: visible);
        await prefs.setBool('${_prefix}top_sales', visible);
        break;
      case 'recentsales':
      case 'ventesrecentes':
      case 'activiterecente':
      case 'activiterecentes':
      case 'activitérecente':
      case 'activitérécentes':
        state = state.copyWith(showRecentSales: visible);
        await prefs.setBool('${_prefix}recent_sales', visible);
        break;
      case 'stockalerts':
      case 'alertesstock':
      case 'alertestock':
        state = state.copyWith(showStockAlerts: visible);
        await prefs.setBool('${_prefix}stock_alerts', visible);
        break;
      case 'financialsummary':
      case 'finance':
      case 'financier':
      case 'valeurstockdepenses':
      case 'valeurdustocketdepenses':
      case 'résuméfinancier':
      case 'resumefinancier':
        state = state.copyWith(showFinancialSummary: visible);
        await prefs.setBool('${_prefix}financial_summary', visible);
        break;
      case 'debtors':
      case 'dettes':
      case 'dettesclients':
        state = state.copyWith(showDebtors: visible);
        await prefs.setBool('${_prefix}debtors', visible);
        break;
      
      // Caissier
      case 'cashierrecentsales':
        state = state.copyWith(showCashierRecentSales: visible);
        await prefs.setBool('${_prefix}cashier_recent_sales', visible);
        break;
      case 'cashiertopproducts':
        state = state.copyWith(showCashierTopProducts: visible);
        await prefs.setBool('${_prefix}cashier_top_products', visible);
        break;
      case 'cashiersessioninfo':
        state = state.copyWith(showCashierSessionInfo: visible);
        await prefs.setBool('${_prefix}cashier_session_info', visible);
        break;
      case 'cashierstockalerts':
        state = state.copyWith(showCashierStockAlerts: visible);
        await prefs.setBool('${_prefix}cashier_stock_alerts', visible);
        break;
    }
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    state = const DashboardCustomizationSettings();
    await prefs.remove('${_prefix}kpis');
    await prefs.remove('${_prefix}revenue_chart');
    await prefs.remove('${_prefix}product_mix');
    await prefs.remove('${_prefix}top_sales');
    await prefs.remove('${_prefix}recent_sales');
    await prefs.remove('${_prefix}stock_alerts');
    await prefs.remove('${_prefix}financial_summary');
    await prefs.remove('${_prefix}debtors');
    await prefs.remove('${_prefix}cashier_recent_sales');
    await prefs.remove('${_prefix}cashier_top_products');
    await prefs.remove('${_prefix}cashier_session_info');
    await prefs.remove('${_prefix}cashier_stock_alerts');
  }
}

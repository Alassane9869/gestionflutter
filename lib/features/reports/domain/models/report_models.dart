class ReportKPIs {
  final double totalRevenue;
  final double totalProfit;
  final double totalExpenses;
  final int salesCount;

  const ReportKPIs({
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalExpenses,
    required this.salesCount,
  });

  double get marginPercentage {
    if (totalRevenue == 0) return 0;
    return (totalProfit / totalRevenue) * 100;
  }

  double get netProfit => totalProfit - totalExpenses;
  
  double get netMarginPercentage {
    if (totalRevenue == 0) return 0;
    return (netProfit / totalRevenue) * 100;
  }
}

class TopProduct {
  final String id;
  final String name;
  final int totalQuantity;
  final double totalRevenue;

  const TopProduct({
    required this.id,
    required this.name,
    required this.totalQuantity,
    required this.totalRevenue,
  });
}

class ChartDataPoint {
  final String label;
  final double value;

  const ChartDataPoint({required this.label, required this.value});
}

class UserSaleSummary {
  final String username;
  final double totalRevenue;
  final int salesCount;

  const UserSaleSummary({
    required this.username,
    required this.totalRevenue,
    required this.salesCount,
  });
}

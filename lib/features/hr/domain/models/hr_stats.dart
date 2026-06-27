class HrStats {
  final int totalEmployees;
  final int activeContracts;
  final double monthlyPayrollSum;
  final int pendingLeaves;
  final int expiringContractsCount;

  HrStats({
    required this.totalEmployees,
    required this.activeContracts,
    required this.monthlyPayrollSum,
    required this.pendingLeaves,
    required this.expiringContractsCount,
  });

  factory HrStats.empty() => HrStats(
    totalEmployees: 0,
    activeContracts: 0,
    monthlyPayrollSum: 0,
    pendingLeaves: 0,
    expiringContractsCount: 0,
  );
}

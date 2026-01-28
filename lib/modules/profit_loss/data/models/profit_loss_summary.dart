// =======================
// MODEL: ProfitLossSummary
// =======================
class ProfitLossSummary {
  final double totalSales;
  final double totalCostOfGoods;
  final double grossProfit;
  final double totalExpenses;
  final double netProfit;
  final double totalDiscounts;
  final double totalReceived;
  final double pendingFromCustomers;
  final double pendingToSuppliers;
  final double totalPurchases;
  final double inHandCash;
  final double expiredStockLoss;
  final double expiredStockRefunds;
  final double netExpiredLoss;

  // Additional detail fields
  final Map<String, double> expenseBreakdown;
  final double? previousNetProfit; // For trend analysis

  ProfitLossSummary({
    required this.totalSales,
    required this.totalCostOfGoods,
    required this.grossProfit,
    required this.totalExpenses,
    required this.netProfit,
    required this.totalDiscounts,
    required this.totalReceived,
    required this.pendingFromCustomers,
    required this.pendingToSuppliers,
    required this.totalPurchases,
    required this.inHandCash,
    this.expiredStockLoss = 0.0,
    this.expiredStockRefunds = 0.0,
    this.netExpiredLoss = 0.0,
    this.expenseBreakdown = const {},
    this.previousNetProfit,
  });

  double get profitMargin =>
      totalSales == 0 ? 0 : (netProfit / totalSales) * 100;

  double get trendPercentage {
    if (previousNetProfit == null || previousNetProfit == 0) return 0;
    return ((netProfit - previousNetProfit!) / previousNetProfit!.abs()) * 100;
  }
}

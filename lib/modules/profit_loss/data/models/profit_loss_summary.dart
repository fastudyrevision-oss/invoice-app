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
  final double pendingFromCustomers;
  final double pendingToSuppliers;
  final double totalPurchases;
  final double inHandCash;

  ProfitLossSummary({
    required this.totalSales,
    required this.totalCostOfGoods,
    required this.grossProfit,
    required this.totalExpenses,
    required this.netProfit,
    required this.totalDiscounts,
    required this.pendingFromCustomers,
    required this.pendingToSuppliers,
    required this.totalPurchases,
    required this.inHandCash,
  });
}

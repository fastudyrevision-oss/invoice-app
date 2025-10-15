class ProfitLossReport {
  final double totalSales;      // from invoices
  final double totalCOGS;       // cost of goods sold from purchase_items
  final double totalExpenses;   // from expenses
  final double grossProfit;     // sales - COGS
  final double netProfit;       // grossProfit - expenses

  ProfitLossReport({
    required this.totalSales,
    required this.totalCOGS,
    required this.totalExpenses,
    required this.grossProfit,
    required this.netProfit,
  });

  Map<String, dynamic> toMap() => {
        "total_sales": totalSales,
        "total_cogs": totalCOGS,
        "total_expenses": totalExpenses,
        "gross_profit": grossProfit,
        "net_profit": netProfit,
      };
}

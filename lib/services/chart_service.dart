import '../models/stock_report_model.dart';

/// ChartService is responsible for preparing summarized chart-ready data
/// from the full StockReport list.
class ChartService {
  /// Builds a bar chart dataset showing stock quantities (Remaining, Purchased, Sold)
  /// while respecting filters like low stock and detailedView.
  List<Map<String, dynamic>> getBarChartData(
    List<StockReport> reports, {
    bool detailedView = false,
    bool onlyLowStock = false,
    int topN = 10, // limit for visualization
  }) {
    if (reports.isEmpty) return [];

    // Optionally filter low stock items
    final filtered = onlyLowStock
        ? reports.where((r) {
            final reorder = r.reorderLevel ?? 0;
            return reorder > 0 && r.remainingQty <= reorder;
          }).toList()
        : reports;

    // Sort by remaining quantity descending
    filtered.sort((a, b) => b.remainingQty.compareTo(a.remainingQty));

    // Limit to top N for readability
    final topItems = filtered.take(topN).toList();

    // Prepare chart data
    return topItems.map((r) {
      final item = {
        'name': r.productName,
        'remaining': r.remainingQty,
        'purchased': r.purchasedQty,
        'sold': r.soldQty,
      };

      // If detailed view is active, add extra metrics
      if (detailedView) {
        item.addAll({
          'profit': r.profitValue,
          'value': r.totalSellValue,
          'reorderLevel': r.reorderLevel ?? 0,
        });
      }

      return item;
    }).toList();
  }

  /// Calculates total stock summary for dashboard widgets or chart legends.
  Map<String, num> getSummaryStats(List<StockReport> reports) {
    if (reports.isEmpty) return {};

    double totalRemaining = 0;
    double totalPurchased = 0;
    double totalSold = 0;
    double totalProfit = 0;
    double totalValue = 0;

    for (var r in reports) {
      totalRemaining += r.remainingQty;
      totalPurchased += r.purchasedQty;
      totalSold += r.soldQty;
      totalProfit += r.profitValue;
      totalValue += r.totalSellValue;
    }

    return {
      'totalRemaining': totalRemaining,
      'totalPurchased': totalPurchased,
      'totalSold': totalSold,
      'totalProfit': totalProfit,
      'totalValue': totalValue,
    };
  }

  /// Optional: Top profitable items chart
  List<Map<String, dynamic>> getTopProfitItems(
    List<StockReport> reports, {
    int topN = 5,
  }) {
    if (reports.isEmpty) return [];

    final sorted = List<StockReport>.from(reports)
      ..sort((a, b) => b.profitValue.compareTo(a.profitValue));

    return sorted.take(topN).map((r) {
      return {
        'name': r.productName,
        'profit': r.profitValue,
        'remaining': r.remainingQty,
      };
    }).toList();
  }
}

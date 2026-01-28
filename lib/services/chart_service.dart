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

  /// Groups stock data by category for Pie Chart visualization.
  List<Map<String, dynamic>> getCategoryData(List<StockReport> reports) {
    if (reports.isEmpty) return [];

    final Map<String, double> categories = {};
    double totalQty = 0;

    for (var r in reports) {
      final cat = r.categoryName ?? 'Other';
      final qty = r.remainingQty.toDouble();
      categories[cat] = (categories[cat] ?? 0) + qty;
      totalQty += qty;
    }

    return categories.entries.map((e) {
      return {
        'category': e.key,
        'quantity': e.value,
        'percentage': totalQty > 0 ? (e.value / totalQty) * 100 : 0,
      };
    }).toList();
  }

  /// ✅ ABC Analysis (Pareto Principle)
  /// Classifies products into:
  /// A - Top 70% of total stock value (Cost)
  /// B - Next 20%
  /// C - Remaining 10%
  Map<String, Map<String, dynamic>> getABCAnalysis(List<StockReport> reports) {
    if (reports.isEmpty) return {};

    final List<StockReport> sorted = List.from(reports)
      ..sort((a, b) => b.stockValueCost!.compareTo(a.stockValueCost!));

    double totalValue = reports.fold(
      0.0,
      (sum, r) => sum + (r.stockValueCost ?? 0.0),
    );
    if (totalValue == 0) return {};

    double runningValue = 0;
    int aCount = 0;
    int bCount = 0;
    int cCount = 0;
    double aValue = 0;
    double bValue = 0;
    double cValue = 0;

    for (var r in sorted) {
      final val = r.stockValueCost ?? 0;
      runningValue += val;
      final percentOfTotal = (runningValue / totalValue) * 100;

      if (percentOfTotal <= 70) {
        aCount++;
        aValue += val;
      } else if (percentOfTotal <= 90) {
        bCount++;
        bValue += val;
      } else {
        cCount++;
        cValue += val;
      }
    }

    return {
      'A': {'count': aCount, 'value': aValue, 'label': 'High Value (A)'},
      'B': {'count': bCount, 'value': bValue, 'label': 'Medium (B)'},
      'C': {'count': cCount, 'value': cValue, 'label': 'Low Value (C)'},
    };
  }

  /// Returns data for a "Stock Value vs Volume" chart
  List<Map<String, dynamic>> getStockValueVolumeData(
    List<StockReport> reports,
  ) {
    // Take top 20 by value to keep chart readable
    final sorted = List.from(reports)
      ..sort((a, b) => b.stockValueCost!.compareTo(a.stockValueCost!));

    return sorted
        .take(20)
        .map(
          (r) => {
            'name': r.productName,
            'qty': r.remainingQty,
            'value': r.stockValueCost,
            'profit': r.profitValue,
          },
        )
        .toList();
  }
}

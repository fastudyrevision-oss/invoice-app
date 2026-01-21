import '../dao/stock_report_dao.dart';
import '../models/stock_report_model.dart';

class StockRepository {
  final StockDao _stockDao = StockDao();

  // Cache for stock report data
  List<StockReport>? _cachedReport;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// 🔹 Get the full stock report (with caching)
  Future<List<StockReport>> getStockReport({bool forceRefresh = false}) async {
    // Return cached data if available and not expired
    if (!forceRefresh &&
        _cachedReport != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      print('📦 Returning cached stock report');
      return _cachedReport!;
    }

    try {
      print('🔄 Fetching fresh stock report from database');
      final reportList = await _stockDao.getStockReport();

      // Update cache
      _cachedReport = reportList;
      _cacheTime = DateTime.now();

      return reportList;
    } catch (e) {
      print('Error loading stock report: $e');

      // Return cached data if available, even if expired
      if (_cachedReport != null) {
        print('⚠️ Returning stale cached data due to error');
        return _cachedReport!;
      }

      rethrow;
    }
  }

  /// Clear the cache (useful after data modifications)
  void clearCache() {
    _cachedReport = null;
    _cacheTime = null;
    print('🗑️ Stock report cache cleared');
  }

  /// 🔹 Get only low-stock (below min level) products
  Future<List<StockReport>> getLowStockReport() async {
    try {
      final allReports = await getStockReport(); // Use cached version
      return allReports
          .where(
            (r) =>
                r.reorderLevel != null &&
                r.reorderLevel! > 0 &&
                r.remainingQty <= r.reorderLevel!,
          )
          .toList();
    } catch (e) {
      print('Error filtering low stock: $e');
      rethrow;
    }
  }

  /// 🔹 Get expired or near-expiry products
  Future<List<StockReport>> getExpiryReport({int daysBefore = 0}) async {
    try {
      final allReports = await getStockReport(); // Use cached version
      final now = DateTime.now();
      return allReports.where((r) {
        if (r.expiryDate == null) return false;
        if (daysBefore == 0) return r.expiryDate!.isBefore(now);
        final threshold = now.add(Duration(days: daysBefore));
        return r.expiryDate!.isBefore(threshold);
      }).toList();
    } catch (e) {
      print('Error filtering expiry report: $e');
      rethrow;
    }
  }

  /// 🔹 Calculate total stock value (cost and selling)
  Future<Map<String, double>> getStockSummary() async {
    try {
      final reports = await getStockReport(); // Use cached version

      double totalCostValue = 0;
      double totalSellValue = 0;
      double totalProfit = 0;

      for (var r in reports) {
        totalCostValue += r.totalCostValue;
        totalSellValue += r.totalSellValue;
        totalProfit += r.profitValue;
      }

      return {
        'totalCostValue': totalCostValue,
        'totalSellValue': totalSellValue,
        'totalProfit': totalProfit,
      };
    } catch (e) {
      print('Error calculating stock summary: $e');
      return {'totalCostValue': 0, 'totalSellValue': 0, 'totalProfit': 0};
    }
  }

  // ---------------------------------------------------------------------------
  // 🔸 EXTENDED FUNCTIONS BELOW (New additions using supplier + batch + company)
  // ---------------------------------------------------------------------------

  /// 🔹 Group stock reports by supplier
  Future<Map<String, List<StockReport>>> getStockBySupplier() async {
    try {
      final reports = await _stockDao.getStockReport();
      final Map<String, List<StockReport>> grouped = {};

      for (var r in reports) {
        final key = r.supplierName ?? 'Unknown Supplier';
        grouped.putIfAbsent(key, () => []).add(r);
      }

      return grouped;
    } catch (e) {
      print('Error grouping stock by supplier: $e');
      rethrow;
    }
  }

  /// 🔹 Group stock by company (brand)
  Future<Map<String, List<StockReport>>> getStockByCompany() async {
    try {
      final reports = await _stockDao.getStockReport();
      final Map<String, List<StockReport>> grouped = {};

      for (var r in reports) {
        final key = r.companyName ?? 'Unknown Company';
        grouped.putIfAbsent(key, () => []).add(r);
      }

      return grouped;
    } catch (e) {
      print('Error grouping stock by company: $e');
      rethrow;
    }
  }

  /// 🔹 Group stock by category
  Future<Map<String, List<StockReport>>> getStockByCategory() async {
    try {
      final reports = await _stockDao.getStockReport();
      final Map<String, List<StockReport>> grouped = {};

      for (var r in reports) {
        final key = r.categoryName ?? 'Uncategorized';
        grouped.putIfAbsent(key, () => []).add(r);
      }

      return grouped;
    } catch (e) {
      print('Error grouping stock by category: $e');
      rethrow;
    }
  }

  /// 🔹 Get batch-level report (for batch expiry tracking or detailed traceability)
  Future<List<StockReport>> getBatchWiseReport() async {
    try {
      final reports = await _stockDao.getStockReport();
      // filter only those with batch info (useful for per-batch analytics)
      return reports
          .where((r) => r.batchNo != null && r.batchNo!.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error getting batch-wise report: $e');
      rethrow;
    }
  }

  /// 🔹 Get top N most profitable products
  Future<List<StockReport>> getTopProfitableProducts({int limit = 10}) async {
    try {
      final reports = await _stockDao.getStockReport();
      reports.sort((a, b) => b.profitValue.compareTo(a.profitValue));
      return reports.take(limit).toList();
    } catch (e) {
      print('Error fetching top profitable products: $e');
      rethrow;
    }
  }

  /// 🔹 Get underperforming / loss products
  Future<List<StockReport>> getLossProducts() async {
    try {
      final reports = await _stockDao.getStockReport();
      return reports.where((r) => r.profitValue < 0).toList();
    } catch (e) {
      print('Error filtering loss products: $e');
      rethrow;
    }
  }
}

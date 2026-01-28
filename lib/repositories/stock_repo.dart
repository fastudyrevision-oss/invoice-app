import '../dao/stock_report_dao.dart';
import '../models/stock_report_model.dart';
import '../services/logger_service.dart';

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
      logger.info('StockRepo', 'Returning cached stock report');
      return _cachedReport!;
    }

    try {
      logger.info('StockRepo', 'Fetching fresh stock report from database');
      final reportList = await _stockDao.getStockReport();

      // Update cache
      _cachedReport = reportList;
      _cacheTime = DateTime.now();

      return reportList;
    } catch (e, stackTrace) {
      logger.error(
        'StockRepo',
        'Error loading stock report',
        error: e,
        stackTrace: stackTrace,
      );

      // Return cached data if available, even if expired
      if (_cachedReport != null) {
        logger.warning('StockRepo', 'Returning stale cached data due to error');
        return _cachedReport!;
      }

      rethrow;
    }
  }

  /// Clear the cache (useful after data modifications)
  void clearCache() {
    _cachedReport = null;
    _cacheTime = null;
    logger.info('StockRepo', 'Stock report cache cleared');
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
      logger.error('StockRepo', 'Error filtering low stock', error: e);
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
      logger.error('StockRepo', 'Error filtering expiry report', error: e);
      rethrow;
    }
  }

  /// 🔹 Get a paged stock report (optimized for large datasets)
  Future<List<StockReport>> getPagedStockReport({
    int limit = 50,
    int offset = 0,
    String? searchQuery,
    bool onlyLowStock = false,
    String? abcFilter,
    String? orderBy,
  }) async {
    try {
      return await _stockDao.getPagedStockReport(
        limit: limit,
        offset: offset,
        searchQuery: searchQuery,
        onlyLowStock: onlyLowStock,
        abcFilter: abcFilter,
        orderBy: orderBy,
      );
    } catch (e) {
      logger.error('StockRepo', 'Error fetching paged stock report', error: e);
      rethrow;
    }
  }

  /// 🔹 Get total count of stock items
  Future<int> getStockTotalCount({
    String? searchQuery,
    bool onlyLowStock = false,
    String? abcFilter,
  }) async {
    try {
      return await _stockDao.getStockTotalCount(
        searchQuery: searchQuery,
        onlyLowStock: onlyLowStock,
        abcFilter: abcFilter,
      );
    } catch (e) {
      logger.error('StockRepo', 'Error getting stock total count', error: e);
      return 0;
    }
  }

  /// 🔹 Calculate total stock value (cost and selling) - Optimized
  Future<Map<String, double>> getStockSummary() async {
    try {
      // Use the optimized DAO method instead of iterating in memory
      return await _stockDao.getStockTotalSummary();
    } catch (e) {
      logger.error('StockRepo', 'Error calculating stock summary', error: e);
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
      logger.error('StockRepo', 'Error grouping stock by supplier', error: e);
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
      logger.error('StockRepo', 'Error grouping stock by company', error: e);
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
      logger.error('StockRepo', 'Error grouping stock by category', error: e);
      rethrow;
    }
  }

  /// 🔹 Get top N products by total quantity (product-centric for charts)
  Future<List<StockReport>> getTopStockByQuantity({int limit = 10}) async {
    try {
      return await _stockDao.getTopProducts(limit: limit);
    } catch (e) {
      logger.error('StockRepo', 'Error fetching top products', error: e);
      return [];
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
      logger.error('StockRepo', 'Error getting batch-wise report', error: e);
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
      logger.error(
        'StockRepo',
        'Error fetching top profitable products',
        error: e,
      );
      rethrow;
    }
  }

  /// 🔹 Get underperforming / loss products
  Future<List<StockReport>> getLossProducts() async {
    try {
      final reports = await _stockDao.getStockReport();
      return reports.where((r) => r.profitValue < 0).toList();
    } catch (e) {
      logger.error('StockRepo', 'Error filtering loss products', error: e);
      rethrow;
    }
  }

  /// 🔹 Get stable ABC statistics (full inventory)
  Future<Map<String, Map<String, dynamic>>> getABCStatistics() async {
    try {
      return await _stockDao.getABCStatistics();
    } catch (e) {
      logger.error('StockRepo', 'Error getting ABC statistics', error: e);
      return <String, Map<String, dynamic>>{};
    }
  }
}

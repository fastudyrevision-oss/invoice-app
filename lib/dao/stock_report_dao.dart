import 'dart:convert';
import '../db/database_helper.dart';
import '../models/stock_report_model.dart';
import '../models/stock_batch.dart';
import '../services/logger_service.dart';

class StockDao {
  final dbHelper = DatabaseHelper.instance;

  // Circuit breaker to prevent repeated failures
  int _failureCount = 0;
  static const int _maxFailures = 3;
  DateTime? _lastFailureTime;

  /// ✅ Fetches a paged stock report with search support
  /// 🔧 Optimized for large datasets (10,000+ items)
  Future<List<StockReport>> getPagedStockReport({
    required int limit,
    required int offset,
    String? searchQuery,
    bool onlyLowStock = false,
    String? abcFilter, // 'A', 'B', or 'C'
    String? orderBy,
  }) async {
    final dbClient = await dbHelper.db;

    List<String> whereClauses = ["p.is_deleted = 0"];
    List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClauses.add(
        "(p.name LIKE ? OR pb.batch_no LIKE ? OR s.name LIKE ?)",
      );
      whereArgs.addAll(["%$searchQuery%", "%$searchQuery%", "%$searchQuery%"]);
    }

    if (onlyLowStock) {
      whereClauses.add("pb.qty <= p.min_stock AND p.min_stock > 0");
    }

    final whereString = whereClauses.join(" AND ");

    // If ABC filter is present, we use a CTE with Window Functions (Pareto analysis)
    final String sql;
    if (abcFilter != null && abcFilter.isNotEmpty) {
      sql =
          """
WITH ProductTotals AS (
    SELECT 
        p.id as pid,
        SUM(IFNULL(pb.qty, 0) * IFNULL(pb.purchase_price, 0)) as p_val
    FROM products p
    LEFT JOIN product_batches pb ON p.id = pb.product_id
    WHERE p.is_deleted = 0
    GROUP BY p.id
),
ParetoCalculation AS (
    SELECT 
        pid,
        p_val,
        SUM(p_val) OVER (ORDER BY p_val DESC, pid) as running_total,
        SUM(p_val) OVER () as grand_total
    FROM ProductTotals
),
CategorizedProducts AS (
    SELECT 
        pid,
        CASE 
            WHEN grand_total = 0 THEN 'C'
            WHEN (running_total - p_val) <= (grand_total * 0.7) THEN 'A'
            WHEN (running_total - p_val) <= (grand_total * 0.9) THEN 'B'
            ELSE 'C'
        END as abc_category
    FROM ParetoCalculation
)
SELECT
    pb.id AS batch_id,
    pb.batch_no,
    p.id AS product_id,
    p.name AS product_name,
    c.name AS category_name,
    IFNULL(pb.qty, 0) AS remaining_qty,
    IFNULL(pb.purchase_price, 0) AS cost_price,
    IFNULL(pb.sell_price, 0) AS sell_price,
    pb.expiry_date,
    s.id AS supplier_id,
    s.name AS supplier_name,
    sc.name AS company_name,
    pb.created_at AS purchase_date,
    p.min_stock AS reorder_level,
    IFNULL((
        SELECT SUM(pi.qty)
        FROM purchase_items pi
        WHERE pi.batch_no = pb.batch_no
    ), 0) AS purchased_qty,
    (SELECT MAX(ii2.created_at)
     FROM invoice_items ii2
     WHERE ii2.product_id = p.id) AS last_sold_date
FROM products p
LEFT JOIN product_batches pb ON p.id = pb.product_id
JOIN CategorizedProducts cp ON p.id = cp.pid
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN suppliers s ON pb.supplier_id = s.id
LEFT JOIN supplier_companies sc ON s.company_id = sc.id
WHERE cp.abc_category = ? AND $whereString
ORDER BY ${orderBy ?? 'p.name ASC, pb.created_at DESC'}
LIMIT ? OFFSET ?;
      """;
      // FIX: abcFilter is the first parameter in this SQL variant
      whereArgs.insert(0, abcFilter);
    } else {
      sql =
          """
SELECT
    pb.id AS batch_id,
    pb.batch_no,
    p.id AS product_id,
    p.name AS product_name,
    c.name AS category_name,
    IFNULL(pb.qty, 0) AS remaining_qty,
    IFNULL(pb.purchase_price, 0) AS cost_price,
    IFNULL(pb.sell_price, 0) AS sell_price,
    pb.expiry_date,
    s.id AS supplier_id,
    s.name AS supplier_name,
    sc.name AS company_name,
    pb.created_at AS purchase_date,
    p.min_stock AS reorder_level,
    IFNULL((
        SELECT SUM(pi.qty)
        FROM purchase_items pi
        WHERE pi.batch_no = pb.batch_no
    ), 0) AS purchased_qty,
    (SELECT MAX(ii2.created_at)
     FROM invoice_items ii2
     WHERE ii2.product_id = p.id) AS last_sold_date
FROM products p
LEFT JOIN product_batches pb ON p.id = pb.product_id
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN suppliers s ON pb.supplier_id = s.id
LEFT JOIN supplier_companies sc ON s.company_id = sc.id
WHERE $whereString
ORDER BY ${orderBy ?? 'p.name ASC, pb.created_at DESC'}
LIMIT ? OFFSET ?;
      """;
    }

    final List<Map<String, dynamic>> results = await dbClient.rawQuery(sql, [
      ...whereArgs,
      limit,
      offset,
    ]);

    // Note: soldQty is approximated as purchased - remaining in this paged view
    return results.map((row) {
      final int purchased = row['purchased_qty'] ?? 0;
      final int remaining = row['remaining_qty'] ?? 0;
      final int sold = (purchased - remaining).clamp(0, purchased);

      return StockReport(
        productId: row['product_id']?.toString() ?? '',
        productName: row['product_name'] ?? 'Unknown',
        purchasedQty: purchased,
        remainingQty: remaining,
        soldQty: sold,
        costPrice: (row['cost_price'] ?? 0).toDouble(),
        sellPrice: (row['sell_price'] ?? 0).toDouble(),
        totalCostValue: (row['cost_price'] ?? 0).toDouble() * purchased,
        totalSellValue: (row['sell_price'] ?? 0).toDouble() * purchased,
        profitValue:
            ((row['sell_price'] ?? 0).toDouble() -
                (row['cost_price'] ?? 0).toDouble()) *
            sold,
        profitMargin: (row['cost_price'] ?? 0).toDouble() > 0
            ? (((row['sell_price'] ?? 0).toDouble() -
                          (row['cost_price'] ?? 0).toDouble()) /
                      (row['cost_price'] ?? 0).toDouble()) *
                  100
            : 0,
        batchNo: row['batch_no'],
        expiryDate: row['expiry_date'] != null
            ? DateTime.tryParse(row['expiry_date'])
            : null,
        companyName: row['company_name'],
        supplierId: row['supplier_id']?.toString(),
        supplierName: row['supplier_name'],
        categoryName: row['category_name'],
        lastPurchaseDate: row['purchase_date'] != null
            ? DateTime.tryParse(row['purchase_date'])
            : null,
        lastSoldDate: row['last_sold_date'] != null
            ? DateTime.tryParse(row['last_sold_date'])
            : null,
        stockValueCost: (row['cost_price'] ?? 0).toDouble() * remaining,
        stockValueSell: (row['sell_price'] ?? 0).toDouble() * remaining,
        reorderLevel: row['reorder_level'],
      );
    }).toList();
  }

  /// ✅ Gets the total count of stock items (batches) matching filter
  Future<int> getStockTotalCount({
    String? searchQuery,
    bool onlyLowStock = false,
    String? abcFilter,
  }) async {
    final dbClient = await dbHelper.db;
    List<String> whereClauses = ["p.is_deleted = 0"];
    List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClauses.add(
        "(p.name LIKE ? OR pb.batch_no LIKE ? OR s.name LIKE ?)",
      );
      whereArgs.addAll(["%$searchQuery%", "%$searchQuery%", "%$searchQuery%"]);
    }

    if (onlyLowStock) {
      whereClauses.add("pb.qty <= p.min_stock AND p.min_stock > 0");
    }

    final whereString = whereClauses.join(" AND ");

    final String sql;
    if (abcFilter != null && abcFilter.isNotEmpty) {
      sql =
          """
WITH ProductTotals AS (
    SELECT 
        p.id as pid,
        SUM(IFNULL(pb.qty, 0) * IFNULL(pb.purchase_price, 0)) as p_val
    FROM products p
    LEFT JOIN product_batches pb ON p.id = pb.product_id
    WHERE p.is_deleted = 0
    GROUP BY p.id
),
ParetoCalculation AS (
    SELECT 
        pid,
        p_val,
        SUM(p_val) OVER (ORDER BY p_val DESC, pid) as running_total,
        SUM(p_val) OVER () as grand_total
    FROM ProductTotals
),
CategorizedProducts AS (
    SELECT 
        pid,
        CASE 
            WHEN grand_total = 0 THEN 'C'
            WHEN (running_total - p_val) <= (grand_total * 0.7) THEN 'A'
            WHEN (running_total - p_val) <= (grand_total * 0.9) THEN 'B'
            ELSE 'C'
        END as abc_category
    FROM ParetoCalculation
)
SELECT COUNT(DISTINCT CASE 
    WHEN pb.id IS NOT NULL THEN pb.id 
    ELSE p.id 
END) as count 
FROM products p
LEFT JOIN product_batches pb ON p.id = pb.product_id
JOIN CategorizedProducts cp ON p.id = cp.pid
LEFT JOIN suppliers s ON pb.supplier_id = s.id
WHERE cp.abc_category = ? AND $whereString;
      """;
      whereArgs.insert(0, abcFilter);
    } else {
      sql =
          "SELECT COUNT(*) as count FROM products p LEFT JOIN product_batches pb ON p.id = pb.product_id LEFT JOIN suppliers s ON pb.supplier_id = s.id WHERE $whereString";
    }

    final result = await dbClient.rawQuery(sql, whereArgs);

    return result.isNotEmpty
        ? (result.first.values.first as num?)?.toInt() ?? 0
        : 0;
  }

  /// ✅ Optimized summary totals using SQL aggregation
  Future<Map<String, double>> getStockTotalSummary() async {
    final dbClient = await dbHelper.db;
    final result = await dbClient.rawQuery("""
      SELECT 
        SUM(qty * purchase_price) as total_cost,
        SUM(qty * sell_price) as total_sell
      FROM product_batches
    """);

    if (result.isEmpty) {
      return {'totalCostValue': 0.0, 'totalSellValue': 0.0, 'totalProfit': 0.0};
    }

    final totalCost = (result.first['total_cost'] as num?)?.toDouble() ?? 0.0;
    final totalSell = (result.first['total_sell'] as num?)?.toDouble() ?? 0.0;

    return {
      'totalCostValue': totalCost,
      'totalSellValue': totalSell,
      'totalProfit': totalSell - totalCost,
    };
  }

  /// ✅ Fetches all product batches, aggregates them into stock reports
  /// 🔧 With error handling and circuit breaker
  Future<List<StockReport>> getStockReport() async {
    // Circuit breaker: if we've failed too many times recently, return empty
    if (_failureCount >= _maxFailures && _lastFailureTime != null) {
      final timeSinceFailure = DateTime.now().difference(_lastFailureTime!);
      if (timeSinceFailure.inMinutes < 5) {
        logger.warning(
          'StockDao',
          'Circuit breaker active - too many recent failures',
        );
        return [];
      } else {
        // Reset after 5 minutes
        _failureCount = 0;
        _lastFailureTime = null;
      }
    }

    try {
      final batches = await getAllProductBatches();
      _failureCount = 0; // Reset on success
      return calculateStockReport(batches);
    } catch (e, stackTrace) {
      _failureCount++;
      _lastFailureTime = DateTime.now();

      logger.error(
        'StockDao',
        'Error loading stock report',
        error: e,
        stackTrace: stackTrace,
        context: {'failureCount': _failureCount},
      );

      // Return empty list instead of throwing
      return [];
    }
  }

  /// ✅ Reads all product batches with supplier and company info
  /// 🔧 Android-compatible version - no JSON functions in SQL
  Future<List<StockBatch>> getAllProductBatches() async {
    final dbClient = await dbHelper.db;

    // Step 1: Get all product batches with basic info (no JSON functions)
    final List<Map<String, dynamic>> batchesResult = await dbClient.rawQuery(
      r"""
SELECT
    pb.id AS batch_id,
    pb.batch_no,
    pb.product_id,
    p.name AS product_name,
    c.name AS category_name,
    pb.qty AS remaining_qty,
    pb.purchase_price AS cost_price,
    pb.sell_price,
    pb.expiry_date,
    s.id AS supplier_id,
    s.name AS supplier_name,
    sc.name AS company_name,
    pb.created_at AS purchase_date,
    IFNULL((
        SELECT SUM(pi.qty)
        FROM purchase_items pi
        WHERE pi.batch_no = pb.batch_no
    ), 0) AS purchased_qty,
    (SELECT MAX(ii2.created_at)
     FROM invoice_items ii2
     WHERE ii2.product_id = pb.product_id) AS last_sold_date
FROM product_batches pb
JOIN products p ON pb.product_id = p.id
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN suppliers s ON pb.supplier_id = s.id
LEFT JOIN supplier_companies sc ON s.company_id = sc.id
WHERE p.is_deleted = 0
ORDER BY pb.product_id ASC, pb.created_at ASC;
    """,
    );

    // Step 2: Get all invoice items with reserved_batches for sold qty calculation
    final List<Map<String, dynamic>> invoiceItemsResult = await dbClient
        .rawQuery(r"""
SELECT
    ii.product_id,
    ii.reserved_batches
FROM invoice_items ii
WHERE ii.reserved_batches IS NOT NULL
  AND ii.reserved_batches != ''
  AND ii.reserved_batches != '[]';
    """);

    // Step 3: Parse JSON in Dart and calculate sold quantities per batch
    final Map<String, int> soldQtyByBatchId = {};

    for (final item in invoiceItemsResult) {
      try {
        final reservedBatchesJson = item['reserved_batches'] as String?;
        if (reservedBatchesJson != null && reservedBatchesJson.isNotEmpty) {
          final List<dynamic> reservedBatches =
              jsonDecode(reservedBatchesJson) as List<dynamic>;

          for (final batch in reservedBatches) {
            if (batch is Map<String, dynamic>) {
              final batchId = batch['batchId']?.toString();
              final qty = batch['qty'];

              if (batchId != null && qty != null) {
                final qtyInt = qty is int
                    ? qty
                    : int.tryParse(qty.toString()) ?? 0;
                soldQtyByBatchId[batchId] =
                    (soldQtyByBatchId[batchId] ?? 0) + qtyInt;
              }
            }
          }
        }
      } catch (e) {
        logger.warning(
          'StockDao',
          'Failed to parse reserved_batches JSON',
          error: e,
        );
        // Continue processing other items
      }
    }

    // Step 4: Map batches to StockBatch model with sold quantities
    return batchesResult.map<StockBatch>((row) {
      try {
        final batchId = row['batch_id']?.toString();
        final soldQty = soldQtyByBatchId[batchId] ?? 0;

        return StockBatch.fromMap({
          ...row,
          'sold_by_batch': soldQty,
          'current_qty': row['remaining_qty'] ?? 0,
        });
      } catch (e) {
        logger.warning('StockDao', 'StockBatch mapping failed', error: e);
        return StockBatch(
          batchNo: row['batch_no'] ?? 'UNKNOWN',
          productId: int.tryParse(row['product_id']?.toString() ?? '0') ?? 0,
          productName: row['product_name'] ?? 'Unnamed Product',
          purchasedQty: row['purchased_qty'] ?? 0,
          costPrice: (row['cost_price'] ?? 0).toDouble(),
          sellPrice: (row['sell_price'] ?? 0).toDouble(),
          expiryDate: null,
        );
      }
    }).toList();
  }

  /// ✅ Combine batches into stock reports
  List<StockReport> calculateStockReport(List<StockBatch> batches) {
    return batches.map((batch) {
      final soldQty = batch.soldByBatch ?? 0;
      final remainingQty = batch.currentQty ?? (batch.purchasedQty - soldQty);

      return StockReport(
        productId: batch.productId.toString(),
        productName: batch.productName,
        purchasedQty: batch.purchasedQty,
        remainingQty: remainingQty,
        soldQty: soldQty,
        costPrice: batch.costPrice,
        sellPrice: batch.sellPrice,
        totalCostValue: batch.costPrice * batch.purchasedQty,
        totalSellValue: batch.sellPrice * batch.purchasedQty,
        profitValue: (batch.sellPrice - batch.costPrice) * soldQty,
        profitMargin: batch.costPrice > 0
            ? ((batch.sellPrice - batch.costPrice) / batch.costPrice) * 100
            : 0,
        batchNo: batch.batchNo,
        expiryDate: batch.expiryDate,
        companyName: batch.companyName,
        supplierId: batch.supplierId?.toString(),
        supplierName: batch.supplierName,
        categoryName: batch.categoryName,
        lastPurchaseDate: batch.purchaseDate,
        lastSoldDate: batch.lastSoldDate,
        stockValueCost: batch.costPrice * remainingQty,
        stockValueSell: batch.sellPrice * remainingQty,
      );
    }).toList();
  }

  /// ✅ Calculates stable ABC Statistics for the entire inventory
  /// Updated to be product-centric and include all active products (even 0 stock)
  Future<Map<String, Map<String, dynamic>>> getABCStatistics() async {
    final dbClient = await dbHelper.db;

    const sql = """
WITH ProductTotals AS (
    SELECT 
        p.id as product_id,
        SUM(IFNULL(pb.qty, 0) * IFNULL(pb.purchase_price, 0)) as product_val
    FROM products p
    LEFT JOIN product_batches pb ON p.id = pb.product_id
    WHERE p.is_deleted = 0
    GROUP BY p.id
),
ParetoCalculation AS (
    SELECT 
        product_id,
        product_val,
        SUM(product_val) OVER (ORDER BY product_val DESC, product_id) as running_total,
        SUM(product_val) OVER () as grand_total
    FROM ProductTotals
),
Categorized AS (
    SELECT 
        product_val,
        CASE 
            WHEN grand_total = 0 THEN 'C'
            WHEN (running_total - product_val) <= (grand_total * 0.7) THEN 'A'
            WHEN (running_total - product_val) <= (grand_total * 0.9) THEN 'B'
            ELSE 'C'
        END as abc_cat
    FROM ParetoCalculation
)
SELECT 
    abc_cat,
    COUNT(*) as item_count,
    SUM(product_val) as total_val
FROM Categorized
GROUP BY abc_cat;
    """;

    final results = await dbClient.rawQuery(sql);
    final stats = {
      'A': {'count': 0, 'value': 0.0},
      'B': {'count': 0, 'value': 0.0},
      'C': {'count': 0, 'value': 0.0},
    };

    for (var row in results) {
      final cat = row['abc_cat']?.toString();
      if (cat != null && stats.containsKey(cat)) {
        stats[cat] = {
          'count': (row['item_count'] as num?)?.toInt() ?? 0,
          'value': (row['total_val'] as num?)?.toDouble() ?? 0.0,
        };
      }
    }
    return stats;
  }

  /// ✅ Fetches top products by total quantity (summed across all batches)
  /// 🔧 Optimized for chart visualization
  Future<List<StockReport>> getTopProducts({int limit = 10}) async {
    final dbClient = await dbHelper.db;

    const sql = """
SELECT
    p.id AS product_id,
    p.name AS product_name,
    c.name AS category_name,
    SUM(IFNULL(pb.qty, 0)) AS remaining_qty,
    IFNULL((
        SELECT SUM(pi.qty)
        FROM purchase_items pi
        JOIN product_batches pb2 ON pi.batch_no = pb2.batch_no
        WHERE pb2.product_id = p.id
    ), 0) AS purchased_qty
FROM products p
LEFT JOIN product_batches pb ON p.id = pb.product_id
LEFT JOIN categories c ON p.category_id = c.id
WHERE p.is_deleted = 0
GROUP BY p.id, p.name, c.name
ORDER BY remaining_qty DESC
LIMIT ?;
    """;

    final List<Map<String, dynamic>> results = await dbClient.rawQuery(sql, [
      limit,
    ]);

    return results.map((row) {
      final int purchased = row['purchased_qty'] ?? 0;
      final int remaining = row['remaining_qty'] ?? 0;
      final int sold = (purchased - remaining).clamp(0, purchased);

      return StockReport(
        productId: row['product_id']?.toString() ?? '',
        productName: row['product_name'] ?? 'Unknown',
        purchasedQty: purchased,
        remainingQty: remaining,
        soldQty: sold,
        costPrice: 0, // Summarized view doesn't have a single price
        sellPrice: 0,
        totalCostValue: 0,
        totalSellValue: 0,
        profitValue: 0,
        profitMargin: 0,
        categoryName: row['category_name'],
      );
    }).toList();
  }
}

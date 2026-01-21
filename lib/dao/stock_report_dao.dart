import 'dart:convert';
import '../db/database_helper.dart';
import '../models/stock_report_model.dart';
import '../models/stock_batch.dart';

class StockDao {
  final dbHelper = DatabaseHelper.instance;

  // Circuit breaker to prevent repeated failures
  int _failureCount = 0;
  static const int _maxFailures = 3;
  DateTime? _lastFailureTime;

  /// ✅ Fetches all product batches, aggregates them into stock reports
  /// 🔧 With error handling and circuit breaker
  Future<List<StockReport>> getStockReport() async {
    // Circuit breaker: if we've failed too many times recently, return empty
    if (_failureCount >= _maxFailures && _lastFailureTime != null) {
      final timeSinceFailure = DateTime.now().difference(_lastFailureTime!);
      if (timeSinceFailure.inMinutes < 5) {
        print('⚠️ Circuit breaker active - too many recent failures');
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
      print('❌ Error loading stock report (failure #$_failureCount): $e');
      print('Stack trace: $stackTrace');

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
        print('⚠️ Failed to parse reserved_batches JSON: $e');
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
        print('⚠️ StockBatch mapping failed: $e');
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
        lastPurchaseDate: batch.purchaseDate,
        lastSoldDate: batch.lastSoldDate,
        stockValueCost: batch.costPrice * remainingQty,
        stockValueSell: batch.sellPrice * remainingQty,
      );
    }).toList();
  }
}

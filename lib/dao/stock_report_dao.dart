import '../db/database_helper.dart';
import '../models/stock_report_model.dart';
import '../models/stock_batch.dart';

class StockDao {
  final dbHelper = DatabaseHelper.instance;

  /// ✅ Fetches all product batches, aggregates them into stock reports
  Future<List<StockReport>> getStockReport() async {
    final batches = await getAllProductBatches();
    return calculateStockReport(batches);
  }

  /// ✅ Reads all product batches with supplier and company info
  Future<List<StockBatch>> getAllProductBatches() async {
    final dbClient = await dbHelper.db;

    final List<Map<String, dynamic>> result = await dbClient.rawQuery(r"""
      -- 🔹 Unified Stock Report Query
SELECT
    pb.id AS batch_id,
    pb.batch_no,
    pb.product_id,
    p.name AS product_name,

    -- ✅ Quantities
    pb.qty AS remaining_qty,  -- current qty in stock
    IFNULL((
        SELECT SUM(pi.qty)
        FROM purchase_items pi
        WHERE pi.batch_no = pb.batch_no
    ), 0) AS purchased_qty,
    IFNULL(SUM(json_extract(rb.value, '$.qty')), 0) AS sold_qty,

    -- ✅ Pricing
    pb.purchase_price AS cost_price,
    pb.sell_price,

    -- ✅ Meta info
    pb.expiry_date,
    s.id AS supplier_id,
    s.name AS supplier_name,
    sc.name AS company_name,
    pb.created_at AS purchase_date,

    (SELECT MAX(ii2.created_at)
     FROM invoice_items ii2
     WHERE ii2.product_id = pb.product_id) AS last_sold_date

FROM product_batches pb
JOIN products p ON pb.product_id = p.id
LEFT JOIN suppliers s ON pb.supplier_id = s.id
LEFT JOIN supplier_companies sc ON s.company_id = sc.id

-- 🔹 Join invoice_items to extract sold qty from JSON
LEFT JOIN invoice_items ii ON ii.product_id = pb.product_id
LEFT JOIN json_each(ii.reserved_batches) AS rb
    ON rb.value IS NOT NULL
    AND json_extract(rb.value, '$.batchId') = pb.id

WHERE p.is_deleted = 0

GROUP BY pb.id, pb.batch_no, pb.product_id
ORDER BY pb.product_id ASC, pb.created_at ASC;
    """);

    // ✅ Map query results safely to StockBatch model
    return result.map<StockBatch>((row) {
      try {
        // ✅ Explicitly link SQL columns to Dart field names
        return StockBatch.fromMap({
          ...row,
          'sold_by_batch':
              row['sold_qty'] ?? 0, // 🔹 Map sold_qty → soldByBatch
          'current_qty':
              row['remaining_qty'] ?? 0, // 🔹 Map remaining_qty → currentQty
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

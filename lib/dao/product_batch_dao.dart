import 'package:sqflite/sqflite.dart';
import '../models/product_batch.dart';
import '../dao/product_dao.dart';

class ProductBatchDao {
  final DatabaseExecutor db;
  ProductBatchDao(this.db);

  /// Insert a batch
  Future<void> insertBatch(ProductBatch batch) async {
    await db.insert(
      "product_batches",
      batch.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // ✅ Sync main product stock after batch insert
    final productDao = ProductDao(db);
    await productDao.refreshProductQuantityFromBatches(batch.productId);
  }

  /// Get all batches by product ID
  Future<List<ProductBatch>> getBatchesByProduct(String productId) async {
    final result = await db.query(
      "product_batches",
      where: "product_id = ?",
      whereArgs: [productId],
      orderBy: "created_at DESC",
    );
    return result.map((row) => ProductBatch.fromMap(row)).toList();
  }

  /// Get all batches by purchase ID
  Future<List<ProductBatch>> getBatchesByPurchaseId(String purchaseId) async {
    final result = await db.query(
      "product_batches",
      where: "purchase_id = ?",
      whereArgs: [purchaseId],
      orderBy: "created_at DESC",
    );
    return result.map((row) => ProductBatch.fromMap(row)).toList();
  }

  /// Get batches by supplier ID (✅ new helper)
  Future<List<ProductBatch>> getBatchesBySupplier(String supplierId) async {
    final result = await db.query(
      "product_batches",
      where: "supplier_id = ?",
      whereArgs: [supplierId],
      orderBy: "created_at DESC",
    );
    return result.map((row) => ProductBatch.fromMap(row)).toList();
  }

  /// Update a batch
  Future<int> updateBatch(ProductBatch batch) async {
    final count = await db.update(
      "product_batches",
      batch.toMap(),
      where: "id = ?",
      whereArgs: [batch.id],
    );

    // ✅ Sync product quantity after batch update
    final productDao = ProductDao(db);
    await productDao.refreshProductQuantityFromBatches(batch.productId);

    return count;
  }

  /// Delete a batch by ID
  Future<int> deleteBatch(String id) async {
    return await db.delete(
      "product_batches",
      where: "id = ?",
      whereArgs: [id],
    );
  }

  /// Delete all batches linked to a purchase
  Future<int> deleteBatchesByPurchaseId(String purchaseId) async {
    return await db.delete(
      "product_batches",
      where: "purchase_id = ?",
      whereArgs: [purchaseId],
    );
  }

  /// ✅ Get expiring soon
  Future<List<ProductBatch>> getExpiringBatches(int days) async {
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));

    final result = await db.query(
      "product_batches",
      where: "expiry_date IS NOT NULL AND expiry_date <= ?",
      whereArgs: [cutoff.toIso8601String()],
      orderBy: "expiry_date ASC",
    );

    return result.map((e) => ProductBatch.fromMap(e)).toList();
  }

  /// ✅ FIFO stock deduction (supports supplier & expiry-based order)
  Future<List<Map<String, dynamic>>> deductFromBatches(
    String productId,
    int qtyToDeduct, {
    bool trackUsage = false,
  }) async {
    if (qtyToDeduct <= 0) return [];

    final batches = await db.query(
      "product_batches",
      where: "product_id = ? AND qty > 0",
      whereArgs: [productId],
      orderBy: "expiry_date ASC, created_at ASC",
    );

    int remaining = qtyToDeduct;
    final reserved = <Map<String, dynamic>>[];

    for (final batchMap in batches) {
      if (remaining <= 0) break;

      final batch = ProductBatch.fromMap(batchMap);
      final deductQty = remaining > batch.qty ? batch.qty : remaining;
      final newQty = batch.qty - deductQty;

      await db.update(
        "product_batches",
        {"qty": newQty, "updated_at": DateTime.now().toIso8601String()},
        where: "id = ?",
        whereArgs: [batch.id],
      );

      if (trackUsage) {
        reserved.add({
          "batchId": batch.id,
          "supplierId": batch.supplierId,
          "qty": deductQty,
        });
      }

      remaining -= deductQty;
    }

    final productDao = ProductDao(db);
    await productDao.refreshProductQuantityFromBatches(productId);

    return reserved;
  }

  /// ✅ Add back quantity to a batch (e.g., cancel sale)
  Future<void> addBackToBatch(String batchId, int qty) async {
    final result = await db.query(
      "product_batches",
      where: "id = ?",
      whereArgs: [batchId],
    );

    if (result.isEmpty) return;

    final batch = ProductBatch.fromMap(result.first);
    final newQty = batch.qty + qty;

    await db.update(
      "product_batches",
      {"qty": newQty, "updated_at": DateTime.now().toIso8601String()},
      where: "id = ?",
      whereArgs: [batchId],
    );

    final productDao = ProductDao(db);
    await productDao.refreshProductQuantityFromBatches(batch.productId);
  }
}

import 'package:sqflite/sqflite.dart';
import '../dao/purchase_dao.dart';
import '../dao/purchase_item_dao.dart';
import '../dao/product_batch_dao.dart';
import '../dao/product_dao.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../models/product_batch.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/expiring_batch_detail.dart';
import '../dao/invoice_item_dao.dart';
import '../exceptions/stock_exception.dart';

class PurchaseRepository {
  final Database db;

  late final PurchaseDao _purchaseDao;
  late final PurchaseItemDao _itemDao;
  late final ProductBatchDao _batchDao;
  late final ProductDao _productDao;

  PurchaseRepository(this.db) {
    _purchaseDao = PurchaseDao(db);
    _itemDao = PurchaseItemDao(db);
    _batchDao = ProductBatchDao(db);
    _productDao = ProductDao(db);
  }

  /// ✅ Get product by ID (ignores deleted unless includeDeleted = true)
  Future<Product?> getProductById(
    String productId, {
    bool includeDeleted = false,
  }) async {
    return await _productDao.getById(productId, includeDeleted: includeDeleted);
  }

  /// ✅ Update product
  Future<int> updateProduct(Product product) async {
    return await _productDao.update(product);
  }

  /// Insert purchase with items and batches
  Future<void> insertPurchaseWithItems({
    required Purchase purchase,
    required List<PurchaseItem> items,
    required List<ProductBatch> batches,
  }) async {
    await db.transaction((txn) async {
      final pDao = PurchaseDao(txn);
      final iDao = PurchaseItemDao(txn);
      final bDao = ProductBatchDao(txn);
      final prodDao = ProductDao(txn);

      await pDao.insertPurchase(purchase);

      // ✅ Safety Guard: Delete any existing batches for this ID (prevents duplication on retries)
      await bDao.deleteBatchesByPurchaseId(purchase.id);

      final productIdsToRefresh = <String>{};

      for (var item in items) {
        await iDao.insertPurchaseItem(item);
        productIdsToRefresh.add(item.productId);
      }

      for (var batch in batches) {
        await bDao.insertBatchSimple(batch);
        productIdsToRefresh.add(batch.productId);
      }

      // ✅ Single final sync for all affected products
      for (var pId in productIdsToRefresh) {
        await prodDao.recalculateProductFromBatches(pId);
      }
    });
  }

  /// Update purchase with items and batches (Revert and Re-insert)
  Future<void> updatePurchaseWithItems({
    required Purchase purchase,
    required List<PurchaseItem> items,
    required List<ProductBatch> batches,
    required List<PurchaseItem> oldItems,
    required List<ProductBatch> oldBatches,
  }) async {
    await db.transaction((txn) async {
      final pDao = PurchaseDao(txn);
      final iDao = PurchaseItemDao(txn);
      final bDao = ProductBatchDao(txn);
      final prodDao = ProductDao(txn);
      final invItemDao = InvoiceItemDao(txn);

      // --- ADVANCED CONSISTENCY CHECKS ---
      // We query the DB for ALL batches currently linked to this purchase (the source of truth)
      final actualOldBatches = await bDao.getBatchesByPurchaseId(purchase.id);

      // Collect product IDs and current SOLD quantities from actualOldBatches for later use
      final productIdsToRefresh = <String>{};
      final batchSoldMap = <String, int>{};
      for (var b in actualOldBatches) {
        productIdsToRefresh.add(b.productId);
        final sold = await getSoldQtyForBatch(b.id, txn);
        batchSoldMap[b.id] = sold;
      }
      for (var item in items) {
        productIdsToRefresh.add(item.productId);
      }

      for (var oldBatch in actualOldBatches) {
        // 1. Get total qty sold from this batch
        final qtySoldFromBatch = batchSoldMap[oldBatch.id] ?? 0;

        // 2. Find what the new purchase qty will be for this batch (matching by ID or Product+Batch)
        final newBatch = batches.firstWhere(
          (b) => b.id == oldBatch.id,
          orElse: () {
            // Priority 1: Match by productId AND batchNo (Greedy)
            final exactMatches = batches
                .where(
                  (b) =>
                      b.productId == oldBatch.productId &&
                      b.batchNo == oldBatch.batchNo,
                )
                .toList();
            if (exactMatches.isNotEmpty) return exactMatches.first;

            // Priority 2: Match by productId (Greedy)
            final sameProductBatches = batches
                .where((b) => b.productId == oldBatch.productId)
                .toList();
            if (sameProductBatches.isNotEmpty) return sameProductBatches.first;

            // Truly removed from purchase if no match found for this product
            return oldBatch.copyWith(qty: 0);
          },
        );
        final newQty = newBatch.qty;

        // Get product name once for this batch to use in multiple guards
        final prodRes = await txn.query(
          'products',
          columns: ['name'],
          where: 'id = ?',
          whereArgs: [oldBatch.productId],
        );
        final productName = prodRes.isNotEmpty
            ? (prodRes.first['name'] as String? ?? 'Product')
            : 'Product';

        // Validation: Cannot reduce below what's already sold
        if (newQty < qtySoldFromBatch) {
          final relatedInvoices = <String>{};
          final invItems = await invItemDao.getItemsByBatch(oldBatch.id);
          for (var item in invItems) {
            final invRes = await txn.query(
              'invoices',
              columns: ['invoice_no'],
              where: 'id = ?',
              whereArgs: [item.invoiceId],
            );
            if (invRes.isNotEmpty) {
              relatedInvoices.add(
                invRes.first['invoice_no'] as String? ?? 'N/A',
              );
            }
          }

          throw StockConstraintException(
            "Cannot reduce quantity for '$productName' below $qtySoldFromBatch (Already Sold). "
            "You requested $newQty units.",
            relatedInvoices: relatedInvoices.toList(),
          );
        }

        // 3. Chronological Guard: Purchase Date must not be after any related sale
        final relatedItems = await invItemDao.getItemsByBatch(oldBatch.id);
        for (var item in relatedItems) {
          final invRes = await txn.query(
            'invoices',
            columns: ['date', 'invoice_no'],
            where: 'id = ?',
            whereArgs: [item.invoiceId],
          );
          if (invRes.isNotEmpty) {
            final saleDateStr = invRes.first['date'] as String?;
            if (saleDateStr == null) continue;
            final saleDate = DateTime.parse(saleDateStr);
            final newPurchaseDate = DateTime.parse(purchase.date);
            if (newPurchaseDate.isAfter(saleDate)) {
              throw StockConstraintException(
                "Purchase date for '$productName' cannot be updated to ${purchase.date} because it is after a sale on ${invRes.first['date']}.",
                relatedInvoices: [
                  (invRes.first['invoice_no'] as String? ?? 'N/A'),
                ],
              );
            }
          }
        }
      }

      // ------------------------------------
      // REVERT AND RE-INSERT LOGIC:
      // Revert effect: Delete ALL batches for this purchase
      await bDao.deleteBatchesByPurchaseId(purchase.id);

      // Delete old items
      await iDao.deleteItemsByPurchaseId(purchase.id);

      // 2. Insert new data
      await pDao.updatePurchase(purchase);
      for (var item in items) {
        await iDao.insertPurchaseItem(item);
      }
      for (var batch in batches) {
        // ✅ SOLD-QTY PRESERVATION:
        // If this batch existed before, we must subtract what was already sold.
        // Otherwise, re-inserting the full purchase 'qty' will double the stock.
        final previouslySold = batchSoldMap[batch.id] ?? 0;
        final correctedBatch = batch.copyWith(qty: batch.qty - previouslySold);
        await bDao.insertBatchSimple(correctedBatch);
      }

      // 3. Final recalculation
      // This will scan the product_batches table and update the product's main quantity/cost.
      for (var productId in productIdsToRefresh) {
        await prodDao.recalculateProductFromBatches(productId);
      }
    });
  }

  /// Get all purchases
  Future<List<Purchase>> getAllPurchases() async {
    return await _purchaseDao.getAllPurchases();
  }

  /// Get all suppliers
  Future<List<Supplier>> getAllSuppliers() async {
    final rows = await db.query("suppliers", orderBy: "name ASC");
    return rows.map((row) => Supplier.fromMap(row)).toList();
  }

  /// Get supplier by ID
  Future<Supplier?> getSupplierById(String id) async {
    final rows = await db.query(
      "suppliers",
      where: "id = ?",
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return Supplier.fromMap(rows.first);
    }
    return null;
  }

  /// Calculates how many units from a specific batch have been sold.
  /// Used for stock guard validation.
  Future<int> getSoldQtyForBatch(String batchId, [dynamic txn]) async {
    final executor = txn ?? db;
    final soldRes = await executor.rawQuery(
      '''
      SELECT ii.qty, ii.reserved_batches
      FROM invoice_items ii
      WHERE ii.reserved_batches LIKE ?
      ''',
      ['%"batchId":"$batchId"%'],
    );

    int qtySoldFromBatch = 0;
    for (final row in soldRes) {
      final reservedRaw = row['reserved_batches'];
      if (reservedRaw != null && reservedRaw.toString().isNotEmpty) {
        try {
          final json = reservedRaw.toString();
          final batchPattern = '"batchId":"$batchId"';
          int searchFrom = 0;
          while (true) {
            final idx = json.indexOf(batchPattern, searchFrom);
            if (idx == -1) break;

            final objStart = json.lastIndexOf('{', idx);
            final objEnd = json.indexOf('}', idx);
            if (objStart == -1 || objEnd == -1) break;

            final obj = json.substring(objStart, objEnd + 1);
            final qtyMatch = RegExp(r'"qty"\s*:\s*(\d+)').firstMatch(obj);
            if (qtyMatch != null) {
              qtySoldFromBatch += int.tryParse(qtyMatch.group(1)!) ?? 0;
            }
            searchFrom = objEnd;
          }
        } catch (_) {
          qtySoldFromBatch += (row['qty'] as num?)?.toInt() ?? 0;
        }
      }
    }
    return qtySoldFromBatch;
  }

  /// Update supplier
  Future<int> updateSupplier(Supplier supplier) async {
    return await db.update(
      "suppliers",
      supplier.toMap(),
      where: "id = ?",
      whereArgs: [supplier.id],
    );
  }

  /// ✅ Get all active products (ignores deleted unless includeDeleted = true)
  Future<List<Product>> getAllProducts({bool includeDeleted = false}) async {
    return await _productDao.getAll(includeDeleted: includeDeleted);
  }

  /// Get purchase by ID
  Future<Purchase?> getPurchaseById(String id) async {
    return await _purchaseDao.getPurchaseById(id);
  }

  /// Update purchase
  Future<int> updatePurchase(Purchase purchase) async {
    return await _purchaseDao.updatePurchase(purchase);
  }

  /// Delete purchase with items and batches (with stock guards)
  Future<void> deletePurchase(String purchaseId) async {
    await db.transaction((txn) async {
      final pDao = PurchaseDao(txn);
      final iDao = PurchaseItemDao(txn);
      final bDao = ProductBatchDao(txn);
      final prodDao = ProductDao(txn);
      final invItemDao = InvoiceItemDao(txn);

      // 1. Check if any items from this purchase have been sold
      final batches = await bDao.getBatchesByPurchaseId(purchaseId);
      final relatedInvoices = <String>{};

      for (var batch in batches) {
        final usedItems = await invItemDao.getItemsByBatch(batch.id);
        for (var ui in usedItems) {
          final invRes = await txn.query(
            'invoices',
            columns: ['invoice_no'],
            where: 'id = ?',
            whereArgs: [ui.invoiceId],
          );
          if (invRes.isNotEmpty) {
            relatedInvoices.add(invRes.first['invoice_no'] as String? ?? 'N/A');
          }
        }
      }

      if (relatedInvoices.isNotEmpty) {
        throw StockConstraintException(
          "Cannot delete purchase because some of its items have already been sold. ",
          relatedInvoices: relatedInvoices.toList(),
        );
      }

      // 2. No sales found, safe to delete
      final items = await iDao.getItemsByPurchaseId(purchaseId);
      for (var item in items) {
        final product = await prodDao.getById(
          item.productId,
          includeDeleted: true,
        );
        if (product != null && !product.isDeleted) {
          final updatedQty = product.quantity - item.qty;
          await prodDao.update(product.copyWith(quantity: updatedQty));
        }
      }
      await iDao.deleteItemsByPurchaseId(purchaseId);

      for (var batch in batches) {
        await bDao.deleteBatch(batch.id);
      }

      await pDao.deletePurchase(purchaseId);
    });
  }

  Future<List<Purchase>> getPurchasesForSupplier(String supplierId) async {
    final result = await db.query(
      'purchases',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
    );
    return result.map((row) => Purchase.fromMap(row)).toList();
  }

  /// Get items of a purchase
  Future<List<PurchaseItem>> getItemsByPurchaseId(String purchaseId) async {
    return await _itemDao.getItemsByPurchaseId(purchaseId);
  }

  /// Get batches for a product
  Future<List<ProductBatch>> getBatchesByProduct(String productId) async {
    return await _batchDao.getBatchesByProduct(productId);
  }

  /// Get batches for a purchase
  Future<List<ProductBatch>> getBatchesByPurchaseId(String purchaseId) async {
    return await _batchDao.getBatchesByPurchaseId(purchaseId);
  }

  Future<List<ProductBatch>> getExpiringBatches(int days) async {
    return await _batchDao.getExpiringBatches(days);
  }

  Future<List<ExpiringBatchDetail>> getExpiringBatchesDetailed(int days) async {
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: days));

    final result = await db.rawQuery(
      '''
    SELECT pb.id as batch_id, pb.batch_no, pb.expiry_date, pb.qty, pb.purchase_price,
           p.id as product_id, p.name as product_name, p.sku as product_code,
           s.id as supplier_id, s.name as supplier_name,
           pb.purchase_id
    FROM product_batches pb
    INNER JOIN products p ON pb.product_id = p.id
    LEFT JOIN suppliers s ON COALESCE(pb.supplier_id, p.supplier_id) = s.id
    WHERE date(pb.expiry_date) <= date(?)
    ORDER BY pb.expiry_date ASC
  ''',
      [futureDate.toIso8601String()],
    );

    return result.map((map) => ExpiringBatchDetail.fromMap(map)).toList();
  }
}

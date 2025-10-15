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
  Future<Product?> getProductById(String productId,
      {bool includeDeleted = false}) async {
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

      for (var item in items) {
        await iDao.insertPurchaseItem(item);

        //final product = await prodDao.getById(item.productId);
        //if (product != null && product.isDeleted == 0) {
        //  final updatedQty = product.quantity + item.qty;
          //await prodDao.update(product.copyWith(quantity: updatedQty));
        //}
      }

      for (var batch in batches) {
        await bDao.insertBatch(batch);
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

  /// Delete purchase with items and batches
  Future<void> deletePurchase(String purchaseId) async {
    await db.transaction((txn) async {
      final pDao = PurchaseDao(txn);
      final iDao = PurchaseItemDao(txn);
      final bDao = ProductBatchDao(txn);
      final prodDao = ProductDao(txn);

      final items = await iDao.getItemsByPurchaseId(purchaseId);
      for (var item in items) {
        final product =
            await prodDao.getById(item.productId, includeDeleted: true);
        if (product != null && product.isDeleted == 0) {
          final updatedQty = product.quantity - item.qty;
          await prodDao.update(product.copyWith(quantity: updatedQty));
        }
      }
      await iDao.deleteItemsByPurchaseId(purchaseId);

      final batches = await bDao.getBatchesByPurchaseId(purchaseId);
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

  final result = await db.rawQuery('''
    SELECT pb.id, pb.batch_no, pb.expiry_date, pb.qty,
           p.id as product_id, p.name as product_name,
           s.id as supplier_id, s.name as supplier_name,
           pb.purchase_id
    FROM product_batches pb
    INNER JOIN products p ON pb.product_id = p.id
    LEFT JOIN suppliers s ON p.supplier_id = s.id
    WHERE date(pb.expiry_date) <= date(?)
    ORDER BY pb.expiry_date ASC
  ''', [futureDate.toIso8601String()]);

  return result.map((map) => ExpiringBatchDetail.fromMap(map)).toList();
  }


 

}

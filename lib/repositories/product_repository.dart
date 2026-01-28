import '../models/product.dart';
import '../db/database_helper.dart';
import '../dao/product_dao.dart';
import '../dao/product_batch_dao.dart';
import '../models/product_batch.dart';

class ProductRepository {
  final dbHelper = DatabaseHelper.instance;

  /// Helper to always get a fresh DAO with the active database
  Future<ProductDao> _dao() async {
    final db = await DatabaseHelper.instance.db;
    return ProductDao(db);
  }

  Future<List<Product>> getAllProducts() async {
    final dao = await _dao();
    return dao.getAll();
  }

  Future<Product?> getProduct(String id) async {
    final dao = await _dao();
    return dao.getById(id);
  }

  Future<List<Product>> getProductsPage({
    required int page,
    required int pageSize,
    String? searchQuery,
    String? categoryId,
    String? supplierId,
    bool onlyLowStock = false,
    String orderBy = 'name',
    bool isAscending = true,
  }) async {
    final dao = await _dao();
    return dao.getProductsPage(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      categoryId: categoryId,
      supplierId: supplierId,
      onlyLowStock: onlyLowStock,
      orderBy: orderBy,
      isAscending: isAscending,
    );
  }

  Future<Map<String, dynamic>> getInventoryStats({
    String? searchQuery,
    String? categoryId,
    String? supplierId,
    bool onlyLowStock = false,
  }) async {
    final dao = await _dao();
    return dao.getInventoryStats(
      searchQuery: searchQuery,
      categoryId: categoryId,
      supplierId: supplierId,
      onlyLowStock: onlyLowStock,
    );
  }

  Future<int> addProduct(Product product) async {
    final dao = await _dao();
    return dao.insert(product);
  }

  Future<int> updateProduct(Product product) async {
    final dao = await _dao();
    return dao.update(product);
  }

  Future<int> deleteProduct(String id) async {
    final dao = await _dao();
    return dao.delete(id);
  }

  Future<int> increaseStock(String id, int qty) async {
    final dao = await _dao();
    return dao.increaseStock(id, qty);
  }

  Future<int> decreaseStock(String id, int qty) async {
    final dao = await _dao();
    return dao.decreaseStock(id, qty);
  }

  Future<void> refreshProductQuantity(String productId) async {
    final dao = await _dao();
    await dao.refreshProductQuantityFromBatches(productId);
  }

  Future<void> recalculateProductFromBatches(String productId) async {
    final db = await dbHelper.db;
    final productDao = ProductDao(db);
    await productDao.recalculateProductFromBatches(productId);
  }

  Future<List<ProductBatch>> getProductBatches(String productId) async {
    final db = await dbHelper.db;
    final batchDao = ProductBatchDao(db);
    return batchDao.getBatchesByProduct(productId);
  }
}

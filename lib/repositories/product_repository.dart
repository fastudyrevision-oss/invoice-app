import '../dao/product_dao.dart';
import '../models/product.dart';
import '../db/database_helper.dart';

class ProductRepository {
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

}

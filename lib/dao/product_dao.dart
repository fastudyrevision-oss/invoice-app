import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/product.dart';

class ProductDao {
  final DatabaseExecutor db;
  ProductDao(this.db);

  /// Helper to create DAO outside a transaction
  static Future<ProductDao> create() async {
    final dbInstance = await DatabaseHelper.instance.db;
    return ProductDao(dbInstance);
  }

  /// Insert or replace a product
  Future<int> insert(Product p) async {
    return await db.insert(
      "products",
      p.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all active (non-deleted) products
  Future<List<Product>> getAll({bool includeDeleted = false}) async {
    final result = await db.query(
      "products",
      where: includeDeleted ? null : "is_deleted = 0",
    );
    return result.map((e) => Product.fromMap(e)).toList();
  }

  /// Get product by ID
  Future<Product?> getById(String id, {bool includeDeleted = false}) async {
    final res = await db.query(
      "products",
      where: includeDeleted ? "id = ?" : "id = ? AND is_deleted = 0",
      whereArgs: [id],
      limit: 1,
    );
    return res.isNotEmpty ? Product.fromMap(res.first) : null;
  }

  /// Update an existing product
  Future<int> update(Product p) async {
    return await db.update(
      "products",
      p.toMap(),
      where: "id = ?",
      whereArgs: [p.id],
    );
  }

  /// Soft delete (mark as deleted)
  Future<int> delete(String id) async {
    return await db.update(
      "products",
      {
        "is_deleted": 1,
        "updated_at": DateTime.now().toIso8601String(),
      },
      where: "id = ?",
      whereArgs: [id],
    );
  }

  /// Update product quantity safely
  Future<int> updateQuantity(String id, int newQuantity) async {
    final args = [newQuantity, DateTime.now().toIso8601String(), id];
    return await db.rawUpdate(
      '''
      UPDATE products
      SET quantity = ?, updated_at = ?
      WHERE id = ? AND is_deleted = 0
      ''',
      args,
    );
  }

  /// Increase stock quantity
  Future<int> increaseStock(String id, int addedQty) async {
    final product = await getById(id);
    if (product == null) return 0;

    final newQty = product.quantity + addedQty;
    return await updateQuantity(id, newQty);
  }

  /// Decrease stock quantity (ensures non-negative)
  Future<int> decreaseStock(String id, int removedQty) async {
    final product = await getById(id);
    if (product == null) return 0;

    final newQty = (product.quantity - removedQty).clamp(0, double.maxFinite.toInt());
    return await updateQuantity(id, newQty);
  }

  /// Refresh product quantity from related batches
  Future<void> refreshProductQuantityFromBatches(String productId) async {
    final result = await db.rawQuery('''
      SELECT IFNULL(SUM(qty), 0) AS totalQty
      FROM product_batches
      WHERE product_id = ?
    ''', [productId]);

    final totalQty = (result.first['totalQty'] ?? 0) as int;

    await db.rawUpdate(
      '''
      UPDATE products
      SET quantity = ?, updated_at = ?
      WHERE id = ? AND is_deleted = 0
      ''',
      [totalQty, DateTime.now().toIso8601String(), productId],
    );
  }
    Future<void> recalculateProductFromBatches(String productId) async {
    // Step 1: get total qty
    final qtyResult = await db.rawQuery('''
      SELECT IFNULL(SUM(qty), 0) AS totalQty,
            IFNULL(SUM(qty * purchase_price), 0) AS totalCost,
            IFNULL(SUM(qty * sell_price), 0) AS totalSell
      FROM product_batches
      WHERE product_id = ?
    ''', [productId]);

    final row = qtyResult.first;
    final totalQty = (row['totalQty'] ?? 0) as num;
    final totalCost = (row['totalCost'] ?? 0) as num;
    final totalSell = (row['totalSell'] ?? 0) as num;

    final avgCost = totalQty > 0 ? totalCost / totalQty : 0;
    final avgSell = totalQty > 0 ? totalSell / totalQty : 0;

    // Step 2: update product master table
    await db.rawUpdate('''
      UPDATE products
      SET quantity = ?, cost_price = ?, sell_price = ?, updated_at = ?
      WHERE id = ?
    ''', [totalQty, avgCost, avgSell, DateTime.now().toIso8601String(), productId]);
  }
  Future<void> resyncAllProducts() async {
    final allProducts = await db.query("products", columns: ["id"]);
    for (final row in allProducts) {
      await recalculateProductFromBatches(row["id"] as String);
    }
  }


}

import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/product.dart';
import '../core/services/audit_logger.dart';

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
    // Assign "Uncategorized" if categoryId is null
    if (p.categoryId == null) {
      p = p.copyWith(categoryId: 'cat-001');
    }
    final id = await db.insert(
      "products",
      p.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await AuditLogger.log(
      'CREATE',
      'products',
      recordId: p.id,
      userId: 'system',
      newData: p.toMap(),
      txn: db,
    );

    return id;
  }

  /// Get all active (non-deleted) products
  Future<List<Product>> getAll({bool includeDeleted = false}) async {
    final result = await db.query(
      "products",
      where: includeDeleted ? null : "is_deleted = 0",
    );
    return result.map((e) => Product.fromMap(e)).toList();
  }

  /// Get products by page for lazy loading
  Future<List<Product>> getProductsPage({
    required int page,
    required int pageSize,
    bool includeDeleted = false,
    String? searchQuery, // optional search
    String? categoryId, // optional category filter
  }) async {
    final offset = page * pageSize;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (!includeDeleted) {
      whereClauses.add("is_deleted = 0");
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClauses.add("(name LIKE ? OR sku LIKE ?)");
      whereArgs.addAll(["%$searchQuery%", "%$searchQuery%"]);
    }

    if (categoryId != null) {
      whereClauses.add("category_id = ?");
      whereArgs.add(categoryId);
    }

    final whereString = whereClauses.isNotEmpty
        ? whereClauses.join(" AND ")
        : null;

    final result = await db.query(
      "products",
      where: whereString,
      whereArgs: whereArgs,
      orderBy: "name ASC",
      limit: pageSize,
      offset: offset,
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
    // Fetch old data
    final oldData = await getById(p.id, includeDeleted: true);

    final count = await db.update(
      "products",
      p.toMap(),
      where: "id = ?",
      whereArgs: [p.id],
    );

    await AuditLogger.log(
      'UPDATE',
      'products',
      recordId: p.id,
      userId: 'system',
      oldData: oldData?.toMap(),
      newData: p.toMap(),
      txn: db,
    );

    return count;
  }

  /// Soft delete (mark as deleted)
  Future<int> delete(String id) async {
    // Fetch old data
    final oldData = await getById(id, includeDeleted: true);

    final count = await db.update(
      "products",
      {"is_deleted": 1, "updated_at": DateTime.now().toIso8601String()},
      where: "id = ?",
      whereArgs: [id],
    );

    if (oldData != null) {
      await AuditLogger.log(
        'DELETE',
        'products',
        recordId: id,
        userId: 'system',
        oldData: oldData.toMap(),
        txn: db,
      );
    }

    return count;
  }

  /// Update product quantity safely
  Future<int> updateQuantity(String id, int newQuantity) async {
    final args = [newQuantity, DateTime.now().toIso8601String(), id];
    return await db.rawUpdate('''
      UPDATE products
      SET quantity = ?, updated_at = ?
      WHERE id = ? AND is_deleted = 0
      ''', args);
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

    final newQty = (product.quantity - removedQty).clamp(
      0,
      double.maxFinite.toInt(),
    );
    return await updateQuantity(id, newQty);
  }

  /// Refresh product quantity from related batches
  Future<void> refreshProductQuantityFromBatches(String productId) async {
    final result = await db.rawQuery(
      '''
      SELECT IFNULL(SUM(qty), 0) AS totalQty
      FROM product_batches
      WHERE product_id = ?
    ''',
      [productId],
    );

    final totalQty = ((result.first['totalQty'] ?? 0) as num).toInt();

    await db.rawUpdate(
      '''
      UPDATE products
      SET quantity = ?, updated_at = ?
      WHERE id = ? AND is_deleted = 0
      ''',
      [totalQty, DateTime.now().toIso8601String(), productId],
    );
  }

  /// Recalculate product from batches (avg price logic)
  Future<void> recalculateProductFromBatches(String productId) async {
    final qtyResult = await db.rawQuery(
      '''
      SELECT 
        IFNULL(SUM(qty), 0) AS totalQty,
        IFNULL(SUM(qty * purchase_price), 0) AS totalCost,
        IFNULL(SUM(qty * sell_price), 0) AS totalSell
      FROM product_batches
      WHERE product_id = ?
    ''',
      [productId],
    );

    final row = qtyResult.first;
    final totalQty = (row['totalQty'] ?? 0) as num;
    final totalCost = (row['totalCost'] ?? 0) as num;
    final totalSell = (row['totalSell'] ?? 0) as num;

    final avgCost = totalQty > 0 ? totalCost / totalQty : 0;
    final avgSell = totalQty > 0 ? totalSell / totalQty : 0;

    await db.rawUpdate(
      '''
      UPDATE products
      SET quantity = ?, cost_price = ?, sell_price = ?, updated_at = ?
      WHERE id = ?
    ''',
      [
        totalQty.toInt(),
        avgCost,
        avgSell,
        DateTime.now().toIso8601String(),
        productId,
      ],
    );
  }

  /// Recalculate all products from batches (bulk resync)
  Future<void> resyncAllProducts() async {
    final allProducts = await db.query("products", columns: ["id"]);
    for (final row in allProducts) {
      await recalculateProductFromBatches(row["id"] as String);
    }
  }
}

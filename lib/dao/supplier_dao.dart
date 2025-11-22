import '../db/database_helper.dart';
import '../models/supplier.dart';

class SupplierDao {
  final dbHelper = DatabaseHelper();

  /// Insert a new supplier
  Future<int> insertSupplier(Supplier supplier) async {
    return await dbHelper.insert("suppliers", supplier.toMap());
  }

  /// Get all suppliers, optionally including deleted ones
  Future<List<Supplier>> getAllSuppliers({bool showDeleted = false}) async {
    final data = await dbHelper.queryAll("suppliers");
    final filtered = showDeleted
        ? data
        : data.where((e) => (e['deleted'] ?? 0) == 0).toList();
    return filtered.map((e) => Supplier.fromMap(e)).toList();
  }

  Future<List<Supplier>> getSuppliersPaged({
    required int offset,
    required int limit,
    bool showDeleted = false,
    String? keyword,
  }) async {
    final db = await dbHelper.db;
    final whereClauses = <String>[];
    final args = <dynamic>[];

    if (!showDeleted) {
      whereClauses.add('deleted = 0');
    }

    if (keyword != null && keyword.isNotEmpty) {
      whereClauses.add('(name LIKE ? OR phone LIKE ?)');
      args.addAll(['%$keyword%', '%$keyword%']);
    }

    final whereString = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT * FROM suppliers $whereString ORDER BY name ASC LIMIT ? OFFSET ?',
      [...args, limit, offset],
    );

    // ✅ explicitly cast to List<Supplier>
    final List<Supplier> suppliers = result
        .map((row) => Supplier.fromMap(row))
        .toList();

    return suppliers;
  }

  /// Get a supplier by ID (ignore deleted)
  Future<Supplier?> getSupplierById(String id) async {
    final data = await dbHelper.queryById("suppliers", id);
    if (data == null) return null;
    if ((data['deleted'] ?? 0) == 1) return null; // ignore deleted
    return Supplier.fromMap(data);
  }

  /// Update a supplier
  Future<int> updateSupplier(Supplier supplier) async {
    return await dbHelper.update("suppliers", supplier.toMap(), supplier.id);
  }

  /// Soft delete a supplier
  Future<int> deleteSupplier(String id) async {
    return await dbHelper.update("suppliers", {"deleted": 1}, id);
  }

  /// Restore a previously deleted supplier
  Future<int> restoreSupplier(String id) async {
    return await dbHelper.update("suppliers", {"deleted": 0}, id);
  }
}

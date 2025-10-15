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

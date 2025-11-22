import '../db/database_helper.dart';
import '../models/supplier_company.dart';

class SupplierCompanyDao {
  final dbHelper = DatabaseHelper();

  Future<int> insertCompany(SupplierCompany company) async {
    return await dbHelper.insert("supplier_companies", company.toMap());
  }

  Future<List<SupplierCompany>> getAllCompanies({
    bool showDeleted = false,
  }) async {
    final data = await dbHelper.queryAll("supplier_companies");
    final filtered = showDeleted
        ? data
        : data.where((e) => (e['deleted'] ?? 0) == 0).toList();
    return filtered.map((e) => SupplierCompany.fromMap(e)).toList();
  }

  Future<SupplierCompany?> getCompanyById(String id) async {
    final data = await dbHelper.queryById("supplier_companies", id);
    if (data == null) return null;
    if ((data['deleted'] ?? 0) == 1) return null; // ignore deleted
    return SupplierCompany.fromMap(data);
  }

  Future<int> updateCompany(SupplierCompany company) async {
    return await dbHelper.update(
      "supplier_companies",
      company.toMap(),
      company.id,
    );
  }

  Future<int> deleteCompany(String id) async {
    // Soft delete
    return await dbHelper.update("supplier_companies", {"deleted": 1}, id);
  }

  Future<int> restoreCompany(String id) async {
    return await dbHelper.update("supplier_companies", {"deleted": 0}, id);
  }
}

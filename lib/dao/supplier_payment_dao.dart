import '../db/database_helper.dart';
import '../models/supplier_payment.dart';

class SupplierPaymentDao {
  final dbHelper = DatabaseHelper();

  /// Insert a new payment
  Future<int> insertPayment(SupplierPayment payment) async {
    return await dbHelper.insert("supplier_payments", payment.toMap());
  }

  /// Get all payments for a specific supplier
  /// If includeDeleted = false, soft-deleted payments are filtered out
  Future<List<SupplierPayment>> getPayments(
    String supplierId, {
    bool includeDeleted = false,
  }) async {
    final data = await dbHelper.queryWhere(
      "supplier_payments",
      "supplier_id = ?",
      [supplierId],
    );

    // Filter by deleted flag if needed
    final filtered = includeDeleted
        ? data
        : data.where((e) => (e['deleted'] ?? 0) == 0).toList();

    return filtered.map((e) => SupplierPayment.fromMap(e)).toList();
  }

  /// Get payments by purchaseId (optional helper)
  Future<List<SupplierPayment>> getPaymentsByPurchase(
    String purchaseId, {
    bool includeDeleted = false,
  }) async {
    final data = await dbHelper.queryWhere(
      "supplier_payments",
      "purchase_id = ?",
      [purchaseId],
    );

    final filtered = includeDeleted
        ? data
        : data.where((e) => (e['deleted'] ?? 0) == 0).toList();

    return filtered.map((e) => SupplierPayment.fromMap(e)).toList();
  }

  /// Update an existing payment
  Future<int> updatePayment(SupplierPayment payment) async {
    return await dbHelper.update(
      "supplier_payments",
      payment.toMap(),
      payment.id,
    );
  }

  /// Soft delete a payment (mark deleted = 1)
  Future<int> softDeletePayment(String id) async {
    return await dbHelper.update(
      "supplier_payments",
      {"deleted": 1},
      id,
    );
  }

  /// Restore a soft-deleted payment (mark deleted = 0)
  Future<int> restorePayment(String id) async {
    return await dbHelper.update(
      "supplier_payments",
      {"deleted": 0},
      id,
    );
  }

  /// Permanently delete a payment
  Future<int> deletePayment(String id) async {
    return await dbHelper.delete("supplier_payments", id);
  }

  /// Get all payments (optionally include deleted)
  Future<List<SupplierPayment>> getAllPayments({bool includeDeleted = false}) async {
    final data = await dbHelper.queryAll("supplier_payments");

    final filtered = includeDeleted
        ? data
        : data.where((e) => (e['deleted'] ?? 0) == 0).toList();

    return filtered.map((e) => SupplierPayment.fromMap(e)).toList();
  }
}

import '../db/database_helper.dart';
import '../models/supplier_payment.dart';

import 'package:sqflite/sqflite.dart';
import '../core/services/audit_logger.dart';
import '../services/auth_service.dart';

class SupplierPaymentDao {
  final DatabaseExecutor? db;

  SupplierPaymentDao([this.db]);

  Future<DatabaseExecutor> get _db async =>
      db ?? await DatabaseHelper.instance.db;

  /// Insert a new payment
  Future<int> insertPayment(SupplierPayment payment) async {
    final dbClient = await _db;

    // 🔢 Calculate next Counting ID (UX display, preserves UUID structure)
    final lastIdRes = await dbClient.rawQuery(
      "SELECT MAX(display_id) as last_id FROM supplier_payments",
    );
    final nextDisplayId = (lastIdRes.first['last_id'] as int? ?? 0) + 1;

    // Inject display_id into map
    final map = payment.toMap();
    map['display_id'] = payment.displayId ?? nextDisplayId;

    final id = await dbClient.insert("supplier_payments", map);

    await AuditLogger.log(
      'CREATE',
      'supplier_payments',
      recordId: payment.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      newData: map,
      txn: dbClient,
    );

    return id;
  }

  /// Get all payments for a specific supplier
  /// If includeDeleted = false, soft-deleted payments are filtered out
  Future<List<SupplierPayment>> getPayments(
    String supplierId, {
    bool includeDeleted = false,
  }) async {
    final dbClient = await _db;
    final data = await dbClient.query(
      "supplier_payments",
      where: "supplier_id = ?",
      whereArgs: [supplierId],
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
    final dbClient = await _db;
    final data = await dbClient.query(
      "supplier_payments",
      where: "purchase_id = ?",
      whereArgs: [purchaseId],
    );

    final filtered = includeDeleted
        ? data
        : data.where((e) => (e['deleted'] ?? 0) == 0).toList();

    return filtered.map((e) => SupplierPayment.fromMap(e)).toList();
  }

  /// Update an existing payment
  Future<int> updatePayment(SupplierPayment payment) async {
    final dbClient = await _db;

    // Fetch old data
    final oldDataList = await dbClient.query(
      "supplier_payments",
      where: "id = ?",
      whereArgs: [payment.id],
    );
    final oldData = oldDataList.isNotEmpty ? oldDataList.first : null;

    final count = await dbClient.update(
      "supplier_payments",
      payment.toMap(),
      where: "id = ?",
      whereArgs: [payment.id],
    );

    await AuditLogger.log(
      'UPDATE',
      'supplier_payments',
      recordId: payment.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      oldData: oldData,
      newData: payment.toMap(),
      txn: dbClient,
    );

    return count;
  }

  /// Soft delete a payment (mark deleted = 1)
  Future<int> softDeletePayment(String id) async {
    final dbClient = await _db;

    // Fetch old data
    final oldDataList = await dbClient.query(
      "supplier_payments",
      where: "id = ?",
      whereArgs: [id],
    );
    final oldData = oldDataList.isNotEmpty ? oldDataList.first : null;

    final count = await dbClient.update(
      "supplier_payments",
      {"deleted": 1},
      where: "id = ?",
      whereArgs: [id],
    );

    if (oldData != null) {
      await AuditLogger.log(
        'DELETE',
        'supplier_payments',
        recordId: id,
        userId: AuthService.instance.currentUser?.id ?? 'system',
        oldData: oldData,
        txn: dbClient,
      );
    }

    return count;
  }

  /// Restore a soft-deleted payment (mark deleted = 0)
  Future<int> restorePayment(String id) async {
    final dbClient = await _db;
    return await dbClient.update(
      "supplier_payments",
      {"deleted": 0},
      where: "id = ?",
      whereArgs: [id],
    );
  }

  /// Permanently delete a payment
  Future<int> deletePayment(String id) async {
    final dbClient = await _db;

    // Fetch old data
    final oldDataList = await dbClient.query(
      "supplier_payments",
      where: "id = ?",
      whereArgs: [id],
    );
    final oldData = oldDataList.isNotEmpty ? oldDataList.first : null;

    final count = await dbClient.delete(
      "supplier_payments",
      where: "id = ?",
      whereArgs: [id],
    );

    if (oldData != null) {
      await AuditLogger.log(
        'DELETE',
        'supplier_payments',
        recordId: id,
        userId: AuthService.instance.currentUser?.id ?? 'system',
        oldData: oldData,
        txn: dbClient,
      );
    }

    return count;
  }

  /// Get all payments (optionally include deleted)
  Future<List<SupplierPayment>> getAllPayments({
    bool includeDeleted = false,
  }) async {
    final dbClient = await _db;
    final data = await dbClient.query("supplier_payments");

    final filtered = includeDeleted
        ? data
        : data.where((e) => (e['deleted'] ?? 0) == 0).toList();

    return filtered.map((e) => SupplierPayment.fromMap(e)).toList();
  }
}

import '../db/database_helper.dart';
import '../models/supplier.dart';

import 'package:sqflite/sqflite.dart';
import '../core/services/audit_logger.dart';
import '../services/auth_service.dart';

class SupplierDao {
  final DatabaseExecutor? db;

  SupplierDao([this.db]);

  Future<DatabaseExecutor> get _db async =>
      db ?? await DatabaseHelper.instance.db;

  /// Insert a new supplier
  Future<int> insertSupplier(Supplier supplier) async {
    final dbClient = await _db;

    // ✅ Ensure numeric fields are properly typed to prevent string concatenation
    final supplierMap = supplier.toMap();
    supplierMap['pending_amount'] = (supplierMap['pending_amount'] as num)
        .toDouble();
    supplierMap['credit_limit'] = (supplierMap['credit_limit'] as num)
        .toDouble();

    final id = await dbClient.insert("suppliers", supplierMap);

    await AuditLogger.log(
      'CREATE',
      'suppliers',
      recordId: supplier.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      newData: supplierMap,
      txn: dbClient,
    );

    return id;
  }

  /// Get all suppliers, optionally including deleted ones
  Future<List<Supplier>> getAllSuppliers({bool showDeleted = false}) async {
    final dbClient = await _db;
    final data = await dbClient.query("suppliers");
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
    final dbClient = await _db;
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

    final List<Map<String, dynamic>> result = await dbClient.rawQuery(
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
    final dbClient = await _db;
    final dataList = await dbClient.query(
      "suppliers",
      where: "id = ?",
      whereArgs: [id],
    );
    if (dataList.isEmpty) return null;
    final data = dataList.first;
    if ((data['deleted'] ?? 0) == 1) return null; // ignore deleted
    return Supplier.fromMap(data);
  }

  /// Update a supplier
  Future<int> updateSupplier(Supplier supplier) async {
    final dbClient = await _db;

    // Fetch old data
    final oldDataList = await dbClient.query(
      "suppliers",
      where: "id = ?",
      whereArgs: [supplier.id],
    );
    final oldData = oldDataList.isNotEmpty ? oldDataList.first : null;

    // ✅ Ensure numeric fields are properly typed to prevent string concatenation
    final supplierMap = supplier.toMap();
    supplierMap['pending_amount'] = (supplierMap['pending_amount'] as num)
        .toDouble();
    supplierMap['credit_limit'] = (supplierMap['credit_limit'] as num)
        .toDouble();

    final count = await dbClient.update(
      "suppliers",
      supplierMap,
      where: "id = ?",
      whereArgs: [supplier.id],
    );

    await AuditLogger.log(
      'UPDATE',
      'suppliers',
      recordId: supplier.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      oldData: oldData,
      newData: supplierMap,
      txn: dbClient,
    );

    return count;
  }

  /// Soft delete a supplier
  Future<int> deleteSupplier(String id) async {
    final dbClient = await _db;

    // Fetch old data
    final oldDataList = await dbClient.query(
      "suppliers",
      where: "id = ?",
      whereArgs: [id],
    );
    final oldData = oldDataList.isNotEmpty ? oldDataList.first : null;

    final count = await dbClient.update(
      "suppliers",
      {"deleted": 1},
      where: "id = ?",
      whereArgs: [id],
    );

    if (oldData != null) {
      await AuditLogger.log(
        'DELETE',
        'suppliers',
        recordId: id,
        userId: AuthService.instance.currentUser?.id ?? 'system',
        oldData: oldData,
        txn: dbClient,
      );
    }

    return count;
  }

  /// Restore a previously deleted supplier
  Future<int> restoreSupplier(String id) async {
    final dbClient = await _db;
    return await dbClient.update(
      "suppliers",
      {"deleted": 0},
      where: "id = ?",
      whereArgs: [id],
    );
  }
}

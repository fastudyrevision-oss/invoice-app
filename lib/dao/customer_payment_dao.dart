import '../db/database_helper.dart';
import '../models/customer_payment.dart';

import 'package:sqflite/sqflite.dart';
import '../core/services/audit_logger.dart';

class CustomerPaymentDao {
  final DatabaseExecutor? db; // Optional for transaction support

  CustomerPaymentDao([this.db]);

  Future<DatabaseExecutor> get _db async =>
      db ?? await DatabaseHelper.instance.db;

  Future<int> insert(CustomerPayment payment) async {
    final dbClient = await _db;
    final id = await dbClient.insert("customer_payments", payment.toMap());

    await AuditLogger.log(
      'CREATE',
      'customer_payments',
      recordId: payment.id,
      userId: 'system',
      newData: payment.toMap(),
      txn: dbClient,
    );

    return id;
  }

  Future<List<CustomerPayment>> getByCustomerId(String customerId) async {
    final dbClient = await _db;
    final data = await dbClient.query(
      "customer_payments",
      where: "customer_id = ?",
      whereArgs: [customerId],
      orderBy: "date DESC",
    );
    return data.map((e) => CustomerPayment.fromMap(e)).toList();
  }

  /// Get all payments with customer information
  Future<List<Map<String, dynamic>>> getAllPaymentsWithCustomer() async {
    final dbClient = await _db;
    final result = await dbClient.rawQuery('''
      SELECT 
        cp.*,
        c.name as customer_name,
        c.phone as customer_phone
      FROM customer_payments cp
      LEFT JOIN customers c ON cp.customer_id = c.id
      ORDER BY cp.date DESC
    ''');
    return result;
  }

  /// Search payments with filters
  Future<List<Map<String, dynamic>>> searchPayments({
    String? customerId,
    String? startDate,
    String? endDate,
    String? method,
    String? searchQuery,
  }) async {
    final dbClient = await _db;
    final whereClauses = <String>[];
    final args = <dynamic>[];

    if (customerId != null && customerId.isNotEmpty) {
      whereClauses.add('cp.customer_id = ?');
      args.add(customerId);
    }

    if (startDate != null && startDate.isNotEmpty) {
      whereClauses.add('cp.date >= ?');
      args.add(startDate);
    }

    if (endDate != null && endDate.isNotEmpty) {
      whereClauses.add('cp.date <= ?');
      args.add(endDate);
    }

    if (method != null && method.isNotEmpty && method != 'all') {
      whereClauses.add('cp.method = ?');
      args.add(method);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClauses.add('(c.name LIKE ? OR cp.transaction_ref LIKE ?)');
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
    }

    final whereString = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    final result = await dbClient.rawQuery('''
      SELECT 
        cp.*,
        c.name as customer_name,
        c.phone as customer_phone
      FROM customer_payments cp
      LEFT JOIN customers c ON cp.customer_id = c.id
      $whereString
      ORDER BY cp.date DESC
    ''', args);
    return result;
  }

  /// Get payment by ID
  Future<CustomerPayment?> getPaymentById(String id) async {
    final dbClient = await _db;
    final data = await dbClient.query(
      "customer_payments",
      where: "id = ?",
      whereArgs: [id],
    );
    return data.isNotEmpty ? CustomerPayment.fromMap(data.first) : null;
  }

  Future<int> update(CustomerPayment payment) async {
    final dbClient = await _db;

    // Fetch old data
    final oldDataList = await dbClient.query(
      "customer_payments",
      where: "id = ?",
      whereArgs: [payment.id],
    );
    final oldData = oldDataList.isNotEmpty ? oldDataList.first : null;

    final count = await dbClient.update(
      "customer_payments",
      payment.toMap(),
      where: "id = ?",
      whereArgs: [payment.id],
    );

    await AuditLogger.log(
      'UPDATE',
      'customer_payments',
      recordId: payment.id,
      userId: 'system',
      oldData: oldData,
      newData: payment.toMap(),
      txn: dbClient,
    );

    return count;
  }

  Future<int> delete(String id) async {
    final dbClient = await _db;

    // Fetch old data
    final oldDataList = await dbClient.query(
      "customer_payments",
      where: "id = ?",
      whereArgs: [id],
    );
    final oldData = oldDataList.isNotEmpty ? oldDataList.first : null;

    final count = await dbClient.delete(
      "customer_payments",
      where: "id = ?",
      whereArgs: [id],
    );

    if (oldData != null) {
      await AuditLogger.log(
        'DELETE',
        'customer_payments',
        recordId: id,
        userId: 'system',
        oldData: oldData,
        txn: dbClient,
      );
    }

    return count;
  }
}

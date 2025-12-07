import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/customer.dart';
import '../core/services/audit_logger.dart';
import '../services/auth_service.dart';

class CustomerDao {
  final DatabaseExecutor db; // Can be either Database or Transaction

  CustomerDao(this.db);

  /// Helper to create DAO outside a transaction
  static Future<CustomerDao> create() async {
    final dbInstance = await DatabaseHelper.instance.db;
    return CustomerDao(dbInstance);
  }

  /// Insert a new customer
  Future<int> insertCustomer(Customer customer) async {
    final id = await db.insert("customers", customer.toMap());

    await AuditLogger.log(
      'CREATE',
      'customers',
      recordId: customer.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      newData: customer.toMap(),
      txn: db,
    );

    return id;
  }

  /// Get all customers with proper typing
  Future<List<Customer>> getAllCustomers() async {
    final data = await db.query("customers");
    return data.map<Customer>((e) => Customer.fromMap(e)).toList();
  }

  /// Get customers with pagination, sorting, and filtering
  Future<List<Customer>> getCustomersPage({
    required int page,
    required int pageSize,
    String query = "",
    String sortField = "name",
    bool sortAsc = true,
  }) async {
    final offset = page * pageSize;
    final orderBy = "$sortField ${sortAsc ? 'ASC' : 'DESC'}";

    String? whereClause;
    List<Object?>? whereArgs;

    if (query.isNotEmpty) {
      whereClause = "name LIKE ? OR phone LIKE ? OR email LIKE ?";
      whereArgs = ['%$query%', '%$query%', '%$query%'];
    }

    final data = await db.query(
      "customers",
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: pageSize,
      offset: offset,
    );

    return data.map<Customer>((e) => Customer.fromMap(e)).toList();
  }

  /// Get customer by ID
  Future<Customer?> getCustomerById(String id) async {
    final data = await db.query("customers", where: "id = ?", whereArgs: [id]);
    return data.isNotEmpty ? Customer.fromMap(data.first) : null;
  }

  /// Update a customer
  Future<int> updateCustomer(Customer customer) async {
    // Fetch old data
    final oldData = await getCustomerById(customer.id);

    final count = await db.update(
      "customers",
      customer.toMap(),
      where: "id = ?",
      whereArgs: [customer.id],
    );

    await AuditLogger.log(
      'UPDATE',
      'customers',
      recordId: customer.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      oldData: oldData?.toMap(),
      newData: customer.toMap(),
      txn: db,
    );

    return count;
  }

  /// Delete a customer
  Future<int> deleteCustomer(String id) async {
    // Fetch old data
    final oldData = await getCustomerById(id);

    final count = await db.delete(
      "customers",
      where: "id = ?",
      whereArgs: [id],
    );

    if (oldData != null) {
      await AuditLogger.log(
        'DELETE',
        'customers',
        recordId: id,
        userId: AuthService.instance.currentUser?.id ?? 'system',
        oldData: oldData.toMap(),
        txn: db,
      );
    }

    return count;
  }

  /// Safely update a customer's pending amount
  Future<void> updatePendingAmount(
    String customerId,
    double pendingToAdd,
  ) async {
    if (customerId.isEmpty) return; // safety check

    // Fetch current pending amount
    final result = await db.query(
      'customers',
      columns: ['pending_amount'],
      where: 'id = ?',
      whereArgs: [customerId],
    );

    final currentPending = result.isNotEmpty
        ? (result.first['pending_amount'] ?? 0) as num
        : 0;

    final newPending = currentPending + pendingToAdd;

    // Update the new pending amount
    await db.update(
      'customers',
      {'pending_amount': newPending},
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }
}

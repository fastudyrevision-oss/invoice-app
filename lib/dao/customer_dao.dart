import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/customer.dart';

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
    return await db.insert("customers", customer.toMap());
  }

  /// Get all customers with proper typing
  Future<List<Customer>> getAllCustomers() async {
    final data = await db.query("customers");
    return data.map<Customer>((e) => Customer.fromMap(e)).toList();
  }

  /// Get customer by ID
  Future<Customer?> getCustomerById(String id) async {
    final data = await db.query("customers", where: "id = ?", whereArgs: [id]);
    return data.isNotEmpty ? Customer.fromMap(data.first) : null;
  }

  /// Update a customer
  Future<int> updateCustomer(Customer customer) async {
    return await db.update(
      "customers",
      customer.toMap(),
      where: "id = ?",
      whereArgs: [customer.id],
    );
  }

  /// Delete a customer
  Future<int> deleteCustomer(String id) async {
    return await db.delete("customers", where: "id = ?", whereArgs: [id]);
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

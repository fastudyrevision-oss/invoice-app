import '../db/database_helper.dart';
import '../models/customer_payment.dart';

import 'package:sqflite/sqflite.dart';
import '../core/services/audit_logger.dart';
import '../services/auth_service.dart';
import '../services/logger_service.dart';
import 'invoice_dao.dart';
import 'customer_dao.dart';

class CustomerPaymentDao {
  final DatabaseExecutor? db; // Optional for transaction support

  CustomerPaymentDao([this.db]);

  LoggerService get logger => LoggerService.instance;

  Future<DatabaseExecutor> get _db async =>
      db ?? await DatabaseHelper.instance.db;

  Future<int> insert(CustomerPayment payment) async {
    final dbClient = await _db;
    final id = await dbClient.insert("customer_payments", payment.toMap());

    await AuditLogger.log(
      'CREATE',
      'customer_payments',
      recordId: payment.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
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
      userId: AuthService.instance.currentUser?.id ?? 'system',
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
        userId: AuthService.instance.currentUser?.id ?? 'system',
        oldData: oldData,
        txn: dbClient,
      );
    }

    return count;
  }

  /// ✅ Transacted Payment Processing
  /// Updates Payment Record + Invoice Balance + Customer Balance
  Future<void> processPayment({
    required CustomerPayment payment,
    bool isUpdate = false,
    CustomerPayment? oldPayment,
  }) async {
    final dbClient = await DatabaseHelper.instance.db;

    await dbClient.transaction((txn) async {
      final invDao = InvoiceDao(txn);
      final custDao = CustomerDao(txn);
      final cpDao = CustomerPaymentDao(txn);

      if (isUpdate && oldPayment != null) {
        logger.info(
          'CustomerPaymentDao',
          'Updated payment ${payment.id}: Processing balance changes',
        );

        // ✅ CASE 1: Editing payment for THE SAME invoice (only amount changed)
        if (oldPayment.invoiceId != null &&
            payment.invoiceId != null &&
            oldPayment.invoiceId == payment.invoiceId) {
          // Apply only the DIFFERENCE to avoid double-update
          final amountDifference = payment.amount - oldPayment.amount;

          logger.info(
            'CustomerPaymentDao',
            'CASE 1: Same invoice edit - Old: ${oldPayment.amount}, New: ${payment.amount}, Difference: $amountDifference',
          );

          // Update invoice with difference
          await invDao.updatePendingAmount(
            payment.invoiceId!,
            -amountDifference, // Negative = reduce pending
          );

          // Update customer with difference
          await custDao.updatePendingAmount(
            payment.customerId,
            -amountDifference, // Negative = reduce pending
          );
        }
        // ✅ CASE 2: Moving payment to a DIFFERENT invoice or changing assignment
        else {
          logger.info(
            'CustomerPaymentDao',
            'CASE 2: Different invoice or assignment change (Revert + Apply)',
          );
          // 1. Revert Old Payment Effects
          if (oldPayment.invoiceId != null) {
            logger.info(
              'CustomerPaymentDao',
              'Reverting old payment from invoice ${oldPayment.invoiceId}',
            );
            await invDao.updatePendingAmount(
              oldPayment.invoiceId!,
              oldPayment.amount, // Adding back to pending
            );
          }
          await custDao.updatePendingAmount(
            oldPayment.customerId,
            oldPayment.amount, // Adding back to customer pending
          );

          // 2. Apply New Payment Effects
          if (payment.invoiceId != null) {
            logger.info(
              'CustomerPaymentDao',
              'Applying new payment to invoice ${payment.invoiceId}',
            );
            await invDao.updatePendingAmount(
              payment.invoiceId!,
              -payment.amount, // Deducting from pending
            );
          }
          await custDao.updatePendingAmount(
            payment.customerId,
            -payment.amount, // Deducting from customer pending
          );
        }

        // Update the payment record
        await cpDao.update(payment);
      } else {
        // New Payment - Insert record
        logger.info(
          'CustomerPaymentDao',
          'New payment ${payment.id}: Inserting record',
        );
        await cpDao.insert(payment);

        // Apply New Payment Effects
        if (payment.invoiceId != null) {
          logger.info(
            'CustomerPaymentDao',
            'Applying balance reduction to invoice ${payment.invoiceId}',
          );
          await invDao.updatePendingAmount(
            payment.invoiceId!,
            -payment.amount, // Deducting from pending
          );
        }
        logger.info(
          'CustomerPaymentDao',
          'Applying balance reduction to customer ${payment.customerId}',
        );
        await custDao.updatePendingAmount(
          payment.customerId,
          -payment.amount, // Deducting from customer pending
        );
      }
    });
  }

  /// ✅ Safe Delete with Balance Reversion
  Future<void> deleteWithBalanceUpdate(CustomerPayment payment) async {
    final dbClient = await DatabaseHelper.instance.db;

    await dbClient.transaction((txn) async {
      final invDao = InvoiceDao(txn);
      final custDao = CustomerDao(txn);
      final cpDao = CustomerPaymentDao(txn);

      logger.info(
        'CustomerPaymentDao',
        'Deleting payment ${payment.id}: Reverting balances',
      );
      // 1. Revert effects
      if (payment.invoiceId != null) {
        await invDao.updatePendingAmount(payment.invoiceId!, payment.amount);
      }
      await custDao.updatePendingAmount(payment.customerId, payment.amount);

      // 2. Delete record
      await cpDao.delete(payment.id);
    });
  }
}

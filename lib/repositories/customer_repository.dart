import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import "../dao/customer_dao.dart";
import "../dao/customer_payment_dao.dart";
import "../dao/invoice_dao.dart";
import "../models/customer.dart";
import "../models/customer_payment.dart";
import "../models/invoice.dart";

class CustomerRepository {
  final DatabaseExecutor db;
  late final CustomerDao _customerDao;
  late final CustomerPaymentDao _paymentDao;

  CustomerRepository(this.db) {
    _customerDao = CustomerDao(db);
    _paymentDao = CustomerPaymentDao(db);
  }

  /// Helper to create repository outside of a transaction
  static Future<CustomerRepository> create() async {
    final dbInstance = await DatabaseHelper.instance.db;
    return CustomerRepository(dbInstance);
  }

  Future<List<Customer>> getAllCustomers() => _customerDao.getAllCustomers();
  Future<Customer?> getCustomer(String id) => _customerDao.getCustomerById(id);
  Future<int> addCustomer(Customer customer) =>
      _customerDao.insertCustomer(customer);
  Future<int> updateCustomer(Customer customer) =>
      _customerDao.updateCustomer(customer);
  Future<int> deleteCustomer(String id) => _customerDao.deleteCustomer(id);

  Future<List<CustomerPayment>> getPayments(String customerId) =>
      _paymentDao.getByCustomerId(customerId);

  /// Add payment + update customer's pending balance
  Future<int> addPayment(CustomerPayment payment) async {
    // Run all DB changes in a single transaction so they are atomic
    final res = await DatabaseHelper.instance.runInTransaction<int>((
      txn,
    ) async {
      // `txn` is a DatabaseExecutor (sqflite Transaction or Database)
      final exec = txn as DatabaseExecutor;

      // Use DAOs bound to the transaction executor so all reads/writes are consistent
      final txnPaymentDao = CustomerPaymentDao(exec);
      final txnCustomerDao = CustomerDao(exec);
      final txnInvoiceDao = InvoiceDao(exec);

      // Insert payment using the transaction executor
      final insertResult = await txnPaymentDao.insert(payment);

      final customer = await txnCustomerDao.getCustomerById(payment.customerId);
      if (customer != null) {
        customer.pendingAmount -= payment.amount;
        await txnCustomerDao.updateCustomer(customer);
      }

      // Apply payment amount to customer's pending invoices (oldest first)
      var remaining = payment.amount;
      if (remaining > 0) {
        final invoices = await txnInvoiceDao.getPendingByCustomerId(
          payment.customerId,
        );
        for (final inv in invoices) {
          if (remaining <= 0) break;
          final toApply = remaining <= inv.pending ? remaining : inv.pending;
          final updated = Invoice(
            id: inv.id,
            customerId: inv.customerId,
            customerName: inv.customerName,
            total: inv.total,
            discount: inv.discount,
            paid: (inv.paid) + toApply,
            pending: (inv.pending) - toApply,
            date: inv.date,
            createdAt: inv.createdAt,
            updatedAt: DateTime.now().toIso8601String(),
          );
          await txnInvoiceDao.update(updated);
          remaining -= toApply;
        }
      }

      return insertResult;
    });

    return res;
  }
}

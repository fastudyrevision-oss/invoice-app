import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import "../dao/customer_dao.dart";
import "../dao/customer_payment_dao.dart";
import "../models/customer.dart";
import "../models/customer_payment.dart";

class CustomerRepository {
  final DatabaseExecutor db;
  late final CustomerDao _customerDao;
  late final CustomerPaymentDao _paymentDao;

  CustomerRepository(this.db) {
    _customerDao = CustomerDao(db);
    _paymentDao = CustomerPaymentDao();
  }

  /// Helper to create repository outside of a transaction
  static Future<CustomerRepository> create() async {
    final dbInstance = await DatabaseHelper.instance.db;
    return CustomerRepository(dbInstance);
  }

  Future<List<Customer>> getAllCustomers() => _customerDao.getAllCustomers();
  Future<Customer?> getCustomer(String id) => _customerDao.getCustomerById(id);
  Future<int> addCustomer(Customer customer) => _customerDao.insertCustomer(customer);
  Future<int> updateCustomer(Customer customer) => _customerDao.updateCustomer(customer);
  Future<int> deleteCustomer(String id) => _customerDao.deleteCustomer(id);

  Future<List<CustomerPayment>> getPayments(String customerId) =>
      _paymentDao.getByCustomerId(customerId);

  /// Add payment + update customer's pending balance
  Future<int> addPayment(CustomerPayment payment) async {
    final result = await _paymentDao.insert(payment);

    final customer = await _customerDao.getCustomerById(payment.customerId);
    if (customer != null) {
      customer.pendingAmount -= payment.amount;
      await _customerDao.updateCustomer(customer);
    }

    return result;
  }
}

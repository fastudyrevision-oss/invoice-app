/*
import 'package:flutter/material.dart';
import '../../models/invoice.dart';
import '../../models/invoice_item.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import '../../repositories/order_repository.dart';
import '../../db/database_helper.dart';
import '../../dao/customer_dao.dart';
import '../../dao/product_dao.dart';
import ''

class OrderViewModel extends ChangeNotifier {
  final OrderRepository _repo = OrderRepository();
  final _dbHelper = DatabaseHelper.instance;

  List<Invoice> _orders = [];
  List<Invoice> get orders => _orders;

  bool _loading = false;
  bool get loading => _loading;

  Future<void> loadOrders() async {
    _loading = true;
    notifyListeners();
    _orders = await _repo.getAllOrders();
    _loading = false;
    notifyListeners();
  }

  Future<void> createOrder({
    required String customerId,
    required String customerName,
    required List<InvoiceItem> items,
    required double total,
    required double discount,
    required double paid,
  }) async {
    final pending = total - discount - paid;
    await _repo.createOrder(
      customerId: customerId,
      customerName: customerName,
      items: items,
      total: total,
      discount: discount,
      paid: paid,
      pending: pending,
    );
    await loadOrders();
  }

  /// 🧠 Load customers for dropdown
  Future<List<Customer>> getCustomers() async {
    final dao = CustomerDao();
    return await dao.getAllCustomers();
  }

  /// 🧠 Load products for dropdown
  Future<List<Product>> getProducts() async {
    final db = await _dbHelper.db;
    final dao = ProductDao(db);
    return await dao.getAll();
  }
}

*/


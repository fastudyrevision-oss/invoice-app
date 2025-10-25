import 'package:flutter/material.dart';
import '../../dao/invoice_dao.dart';
import '../../models/invoice.dart';
import '../../db/database_helper.dart';

class OrderListController extends ChangeNotifier {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  bool isLoading = false;
  String? errorMessage;
  List<Invoice> orders = [];

  Future<void> loadOrders() async {
    try {
      isLoading = true;
      notifyListeners();

      final db = await dbHelper.db;
      final dao = InvoiceDao(db);
      orders = await dao.getAllInvoices();

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
    }
  }
}

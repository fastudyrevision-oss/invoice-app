import 'dart:io';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'main_frame.dart';
import 'db/database_helper.dart';
import 'repositories/report_repository.dart';

void main() async {
  if (!kIsWeb) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Only for desktop
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // Android/iOS: no need to set databaseFactory, default sqflite will work
  }
  WidgetsFlutterBinding.ensureInitialized(); // Required for async init

  await DatabaseHelper().init(); // Initialize DB first

  final reportRepo = ReportRepository();

  // 🔹 Test Supplier Reports
  final suppliers = await reportRepo.getSupplierReports();
  for (var s in suppliers) {
    print(
      "Supplier: ${s.supplierName}, Purchases: ${s.totalPurchases}, Paid: ${s.totalPaid}, Balance: ${s.balance}",
    );
  }

  // 🔹 Test Product Reports
  final products = await reportRepo.getProductReports();
  for (var p in products) {
    print(
      "Product: ${p.productName}, Qty: ${p.totalQtyPurchased}, Spent: ${p.totalSpent}",
    );
  }

  // 🔹 Test Expense Reports
  final expenses = await reportRepo.getExpenseReports();
  for (var e in expenses) {
    print("Category: ${e.category}, Total Spent: ${e.totalSpent}");
  }

  runApp(const InvoiceApp());
}

class InvoiceApp extends StatelessWidget {
  const InvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Invoice App',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      home: MainFrame(),
    );
  }
}

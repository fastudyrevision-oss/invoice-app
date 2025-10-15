import 'package:flutter/material.dart';
import 'supplier_report_frame.dart';
import 'product_report_frame.dart';
import 'expense_report_frame.dart';
import 'expiry_report_frame.dart';
import 'payment_report_frame.dart';
import '../stock/stock_report_frame.dart';

class ReportsDashboard extends StatelessWidget {
  const ReportsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6, // updated count
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Reports Dashboard"),
          bottom: const TabBar(
            isScrollable: true, // helps if there are many tabs
            tabs: [
              Tab(text: "Suppliers"),
              
              Tab(text: "Products"),
              Tab(text: "Expenses"),
              Tab(text: "Expiry"),
              Tab(text: "Payments"),
              Tab(text: "Stock Report"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SupplierReportFrame(),
            ProductReportFrame(),
            ExpenseReportFrame(),
            ExpiryReportFrame(),
            PaymentReportFrame(),
            StockReportFrame(),
          ],
        ),
      ),
    );
  }
}

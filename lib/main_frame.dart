import 'package:flutter/material.dart';
import 'ui/customer_frame.dart';
import 'ui/product_frame.dart';
import 'ui/expense_frame.dart';
import 'ui/supplier/supplier_frame.dart';
import 'ui/purchase_frame.dart';
import 'ui/expiring_products_frame.dart';
import 'ui/reports/reports_dashboard.dart';
import 'ui/order/order_list_screen.dart'; // ✅ Added this import
import 'ui/category/category_list_frame.dart';
import 'ui/backup/backup_frame.dart';


import '../repositories/purchase_repo.dart';
import '../repositories/supplier_repo.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_payment_repo.dart';
import '../db/database_helper.dart';
import '../dao/supplier_dao.dart';
import '../dao/supplier_report_dao.dart';
import '../dao/supplier_payment_dao.dart';
import '../dao/supplier_company_dao.dart';
import 'package:sqflite/sqflite.dart';

class MainFrame extends StatefulWidget {
  const MainFrame({super.key});

  @override
  State<MainFrame> createState() => _MainFrameState();
}

class _MainFrameState extends State<MainFrame>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<Tab> _tabs;

  PurchaseRepository? _purchaseRepo;
  ProductRepository? _productRepo;
  SupplierRepository? _supplierRepo;
  SupplierPaymentRepository? _supplierPaymentRepo;

  Database? _db;
  int _expiringCount = 0;

  @override
  void initState() {
    super.initState();
    _buildTabs();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _initRepos();
  }

  void _buildTabs() {
    _tabs = [
      const Tab(text: "Reports"),
      const Tab(text: "Customers"),
      const Tab(text: "Products"),
      const Tab(text: "Expenses"),
      const Tab(text: "Suppliers"),
      const Tab(text: "Purchases"),
      const Tab(text: "Orders"), // ✅ New Orders Tab added here
       const Tab(text: "Categories"), // <-- NEW TAB
       const Tab(text: "BackUp/Restore"), // <-- NEW TAB
      Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Expiring"),
            if (_expiringCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$_expiringCount',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Future<void> _initRepos() async {
    _db = await DatabaseHelper.instance.db;

    setState(() {
      _purchaseRepo = PurchaseRepository(_db!);
      _productRepo = ProductRepository();
      _supplierRepo = SupplierRepository(
        SupplierDao(),
        SupplierPaymentDao(),
        SupplierReportDao(),
        SupplierCompanyDao(),
      );
      _supplierPaymentRepo = SupplierPaymentRepository(
        SupplierPaymentDao(),
        SupplierDao(),
        _purchaseRepo!,
      );
    });

    await _refreshExpiringCount();
  }

  Future<void> _refreshExpiringCount({int days = 30}) async {
    if (_purchaseRepo == null) return;
    final expiring = await _purchaseRepo!.getExpiringBatches(days);
    setState(() {
      _expiringCount = expiring.length;
      _buildTabs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Invoice App"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const ReportsDashboard(),
          const CustomerFrame(),
          const ProductFrame(),
          const ExpenseFrame(),
          _supplierRepo == null || _supplierPaymentRepo == null
              ? const Center(child: CircularProgressIndicator())
              : SupplierFrame(
                  repo: _supplierRepo!,
                  repo2: _supplierPaymentRepo!,
                ),
          _purchaseRepo == null || _productRepo == null || _supplierRepo == null
              ? const Center(child: CircularProgressIndicator())
              : PurchaseFrame(
                  repo: _purchaseRepo!,
                  productRepo: _productRepo!,
                  supplierRepo: _supplierRepo!,
                ),
          const OrderListScreen(), // ✅ Inserted here as the new tab view
           const CategoryListFrame(), // <-- NEW TAB VIEW
           const BackupRestoreScreen(), // <-- NEW TAB VIEW
          _purchaseRepo == null || _db == null
              ? const Center(child: CircularProgressIndicator())
              : ExpiringProductsFrame(
                  db: _db!,
                  onDataChanged: () {
                    _refreshExpiringCount();
                  },
                ),
        ],
      ),
    );
  }
}

// Profit & Loss UI Module for Flutter
// Includes: UI Controller, Filters (Daily/Weekly/Monthly/Yearly/Custom),
// Summary Widgets, Charts, PDF Export Helper

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../data/models/profit_loss_model.dart';
import '../data/models/category_profit.dart';
import '../data/models/supplier_profit.dart';
import '../data/models/product_profit.dart';
import '../data/repository/profit_loss_repo.dart';
import 'profit_loss_chart.dart';

// ---------------------- ENUM ----------------------
enum PLFilterType { daily, weekly, monthly, yearly, custom }
enum PLDataType { summary, category, product, supplier }

// ---------------------- CONTROLLER ----------------------
class ProfitLossUIController {
  final ProfitLossRepository repo;

  ProfitLossUIController(this.repo);

  Future<ProfitLossModel> getData(
      PLFilterType filter, {
        DateTime? start,
        DateTime? end,
        PLDataType type = PLDataType.summary,
      }) async {
    final now = DateTime.now();
    DateTime rangeStart;
    DateTime rangeEnd;

    switch (filter) {
      case PLFilterType.daily:
        rangeStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
        rangeEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case PLFilterType.weekly:
        rangeStart = now.subtract(Duration(days: now.weekday - 1));
        rangeEnd = now;
        break;
      case PLFilterType.monthly:
        rangeStart = DateTime(now.year, now.month, 1);
        rangeEnd = now;
        break;
      case PLFilterType.yearly:
        rangeStart = DateTime(now.year, 1, 1);
        rangeEnd = now;
        break;
      case PLFilterType.custom:
        if (start == null || end == null) throw Exception("Custom range requires start & end");
        rangeStart = start;
        rangeEnd = end;
        break;
    }

    switch (type) {
      case PLDataType.summary:
        final summary = await repo.loadSummary(rangeStart, rangeEnd);
        return ProfitLossModel.fromSummary(summary);
      case PLDataType.category:
        final categories = await repo.loadCategoryProfit(rangeStart, rangeEnd);
        return ProfitLossModel.fromCategoryList(categories);
      case PLDataType.product:
        final products = await repo.loadProductProfit(rangeStart,rangeEnd);
        return ProfitLossModel.fromProductList(products);
      case PLDataType.supplier:
        final suppliers = await repo.loadSupplierProfit(rangeStart, rangeEnd);
        return ProfitLossModel.fromSupplierList(suppliers);
    }
  }
}

// ---------------------- UI WIDGET ----------------------
class ProfitLossScreen extends StatefulWidget {
  final ProfitLossUIController controller;

  const ProfitLossScreen({required this.controller, Key? key}) : super(key: key);

  @override
  State<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
  PLFilterType selected = PLFilterType.daily;
  DateTime? customStart;
  DateTime? customEnd;

  ProfitLossModel? summaryData;
  List<CategoryProfit> categories = [];
  List<ProductProfit> products = [];
  List<SupplierProfit> suppliers = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchAll();
  }

  Future<void> fetchAll() async {
    setState(() => loading = true);

    final summary = await widget.controller.getData(
    selected,
    start: customStart,
    end: customEnd,
    type: PLDataType.summary,
);

final categoryData = await widget.controller.getData(
    selected,
    start: customStart,
    end: customEnd,
    type: PLDataType.category,
);

final productData = await widget.controller.getData(
    selected,
    start: customStart,
    end: customEnd,
    type: PLDataType.product,
);

final supplierData = await widget.controller.getData(
    selected,
    start: customStart,
    end: customEnd,
    type: PLDataType.supplier,
);

setState(() {
  summaryData = summary;
  categories = categoryData.categories; // if you modify ProfitLossModel to hold lists
  products = productData.products;
  suppliers = supplierData.suppliers;
  loading = false;
});

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profit & Loss Dashboard")),
      body: Column(
        children: [
          _buildFilters(),
          if (selected == PLFilterType.custom) _buildCustomRange(),
          Expanded(
            child: loading
                ? Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: fetchAll,
                    child: ListView(
                      children: [
                        if (summaryData != null) ProfitLossSummaryChart(data: summaryData!),
                        if (categories.isNotEmpty) CategoryProfitChart(categories: categories),
                        if (products.isNotEmpty) ProductProfitChart(products: products),
                        if (suppliers.isNotEmpty) SupplierProfitChart(suppliers: suppliers),
                      ],
                    ),
                  ),
          ),
          _buildExportButton(),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      children: [
        _chip("Daily", PLFilterType.daily),
        _chip("Weekly", PLFilterType.weekly),
        _chip("Monthly", PLFilterType.monthly),
        _chip("Yearly", PLFilterType.yearly),
        _chip("Custom", PLFilterType.custom),
      ],
    );
  }

  Widget _chip(String label, PLFilterType type) {
    final active = selected == type;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) {
  setState(() => selected = type);
  if (type != PLFilterType.custom) {
    fetchAll();
  }
}

    );
  }

  Widget _buildCustomRange() {
    return Row(
      children: [
        TextButton(
          onPressed: () async {
            customStart = await _pickDate();
            setState(() {});
          },
          child: Text("Start: ${_fmtOrDash(customStart)}"),
        ),
        TextButton(
          onPressed: () async {
            customEnd = await _pickDate();
            setState(() {});
          },
          child: Text("End: ${_fmtOrDash(customEnd)}"),
        ),
        ElevatedButton(
          onPressed: () => fetchAll(),
          child: Text("Apply"),
        ),
      ],
    );
  }

  String _fmtOrDash(DateTime? dt) => dt == null ? "-" : DateFormat("dd MMM").format(dt);

  Future<DateTime?> _pickDate() async {
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
  }

  Widget _buildExportButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton.icon(
        icon: Icon(Icons.picture_as_pdf),
        label: Text("Export PDF"),
        onPressed: () => PDFExporter.exportDashboard(
          summary: summaryData!,
          categories: categories,
          products: products,
          suppliers: suppliers,
        ),
      ),
    );
  }
}

// ---------------------- PDF EXPORT HELPER ----------------------
class PDFExporter {
  static Future<void> exportDashboard({
    required ProfitLossModel summary,
    required List<CategoryProfit> categories,
    required List<ProductProfit> products,
    required List<SupplierProfit> suppliers,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(pw.Page(
      build: (pw.Context ctx) {
        return pw.ListView(
          children: [
            pw.Text("Profit & Loss Dashboard", style: pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 20),
            _row("Total Sales", summary.totalSales),
            _row("Total Purchase Cost", summary.totalPurchaseCost),
            _row("Total Profit", summary.totalProfit),
            if (summary.totalExpenses > 0) _row("Total Expenses", summary.totalExpenses),
            if (summary.totalDiscounts > 0) _row("Total Discounts", summary.totalDiscounts),
            if (summary.pendingFromCustomers > 0) _row("Pending From Customers", summary.pendingFromCustomers),
            if (summary.pendingToSuppliers > 0) _row("Pending To Suppliers", summary.pendingToSuppliers),
            if (summary.inHandCash > 0) _row("In-Hand Cash", summary.inHandCash),
            pw.SizedBox(height: 20),
            if (categories.isNotEmpty) pw.Text("Category-wise Profit", style: pw.TextStyle(fontSize: 18)),
            ...categories.map((c) => _row(c.name, c.profit)),
            pw.SizedBox(height: 20),
            if (products.isNotEmpty) pw.Text("Product-wise Profit", style: pw.TextStyle(fontSize: 18)),
            ...products.map((p) => _row(p.name, p.profit)),
            pw.SizedBox(height: 20),
            if (suppliers.isNotEmpty) pw.Text("Supplier Purchases & Pending", style: pw.TextStyle(fontSize: 18)),
            ...suppliers.map((s) => _row("${s.name} (Pending: ${s.pendingToSupplier})", s.totalPurchases)),
          ],
        );
      },
    ));

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/profit_loss_dashboard.pdf");
    await file.writeAsBytes(await pdf.save());
    print("PDF saved at: ${file.path}");
  }

  static pw.Widget _row(String title, num value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(title), pw.Text(value.toString())],
      ),
    );
  }
}

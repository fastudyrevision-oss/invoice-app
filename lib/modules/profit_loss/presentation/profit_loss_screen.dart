import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart'; // Keeping this as it is used for PdfColors and PdfPageFormat
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart'; // Added for swipe actions

import '../data/models/profit_loss_model.dart';
import '../data/models/category_profit.dart';
import '../data/models/supplier_profit.dart';
import '../data/models/product_profit.dart';
import '../data/repository/profit_loss_repo.dart';
import 'profit_loss_chart.dart';
import 'manual_entry_dialog.dart';
import '../data/models/manual_entry.dart';
import 'widgets/summary_card.dart'; // Import the new widget
import '../../../../utils/responsive_utils.dart';

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
        // Start of week (Monday at 00:00:00)
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        rangeStart = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day,
          0,
          0,
          0,
        );
        // End of today (23:59:59)
        rangeEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
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
        if (start == null || end == null) {
          throw Exception("Custom range requires start & end");
        }
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
        final products = await repo.loadProductProfit(rangeStart, rangeEnd);
        return ProfitLossModel.fromProductList(products);
      case PLDataType.supplier:
        final suppliers = await repo.loadSupplierProfit(rangeStart, rangeEnd);
        return ProfitLossModel.fromSupplierList(suppliers);
    }
  }

  Future<ProfitLossModel?> getPreviousPeriodData(
    PLFilterType filter, {
    DateTime? start,
    DateTime? end,
  }) async {
    final now = DateTime.now();
    DateTime rangeStart;
    DateTime rangeEnd;

    switch (filter) {
      case PLFilterType.daily:
        // Previous day
        rangeStart = DateTime(now.year, now.month, now.day - 1, 0, 0, 0);
        rangeEnd = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
        break;
      case PLFilterType.weekly:
        // Previous week
        final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
        final prevWeekStart = currentWeekStart.subtract(
          const Duration(days: 7),
        );
        rangeStart = DateTime(
          prevWeekStart.year,
          prevWeekStart.month,
          prevWeekStart.day,
          0,
          0,
          0,
        );
        final prevWeekEnd = prevWeekStart.add(const Duration(days: 6));
        rangeEnd = DateTime(
          prevWeekEnd.year,
          prevWeekEnd.month,
          prevWeekEnd.day,
          23,
          59,
          59,
        );
        break;
      case PLFilterType.monthly:
        // Previous month
        rangeStart = DateTime(now.year, now.month - 1, 1, 0, 0, 0);
        // Last day of prev month at 23:59:59
        rangeEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
        break;
      case PLFilterType.yearly:
        // Previous year
        rangeStart = DateTime(now.year - 1, 1, 1, 0, 0, 0);
        rangeEnd = DateTime(now.year - 1, 12, 31, 23, 59, 59);
        break;
      case PLFilterType.custom:
        if (start == null || end == null) return null;
        final duration = end.difference(start);
        rangeEnd = start.subtract(const Duration(days: 1));
        rangeStart = rangeEnd.subtract(duration);
        break;
    }

    try {
      final summary = await repo.loadSummary(rangeStart, rangeEnd);
      return ProfitLossModel.fromSummary(summary);
    } catch (e) {
      return null;
    }
  }

  /// Convenience to load manual entries
  Future<List<ManualEntry>> getManualEntries({
    DateTime? start,
    DateTime? end,
  }) async {
    try {
      {
        final dao = repo.manualEntryDao;
        if (start != null && end != null) {
          return await dao.getByDateRange(start, end);
        }
        return await dao.getAll();
      }
    } catch (e) {
      // ignore
    }
    return [];
  }
}

// ---------------------- UI WIDGET ----------------------
class ProfitLossScreen extends StatefulWidget {
  final ProfitLossUIController controller;

  const ProfitLossScreen({required this.controller, super.key});

  @override
  State<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
  PLFilterType selected = PLFilterType.daily;
  DateTime? customStart;
  DateTime? customEnd;

  ProfitLossModel? summaryData;
  ProfitLossModel? previousSummaryData;
  List<CategoryProfit> categories = [];
  List<ProductProfit> products = [];
  List<SupplierProfit> suppliers = [];
  List<ManualEntry> manualEntries = [];
  List<ManualEntry> filteredManualEntries = [];

  bool loading = true;
  bool isCogsBased = true; // Toggle state
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterManualEntries(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredManualEntries = List.from(manualEntries);
      } else {
        filteredManualEntries = manualEntries
            .where(
              (entry) =>
                  entry.description.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  Future<void> fetchAll() async {
    setState(() => loading = true);

    try {
      final summary = await widget.controller.getData(
        selected,
        start: customStart,
        end: customEnd,
        type: PLDataType.summary,
      );

      final prevSummary = await widget.controller.getPreviousPeriodData(
        selected,
        start: customStart,
        end: customEnd,
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

      final entries = await widget.controller.getManualEntries(
        start: customStart,
        end: customEnd,
      );

      setState(() {
        summaryData = summary;
        previousSummaryData = prevSummary;
        categories = categoryData.categories;
        products = productData.products;
        suppliers = supplierData.suppliers;
        manualEntries = entries;
        filteredManualEntries = entries;
        loading = false;
      });
    } catch (e, st) {
      debugPrint('Failed to load dashboard data: $e\n$st');
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveUtils.isMobile(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text("Profit & Loss Dashboard"),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: summaryData != null ? _exportPDF : null,
              ),
            ],
          ),
          body: Column(
            children: [
              _buildFilters(),
              if (selected == PLFilterType.custom) _buildCustomRange(isMobile),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: fetchAll,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildModeToggle(isMobile),
                              const SizedBox(height: 12),
                              if (summaryData != null) _buildSummaryCards(),
                              const SizedBox(height: 16),
                              if (summaryData != null) _buildDetailedCards(),
                              const SizedBox(height: 16),
                              if (summaryData != null)
                                ProfitLossSummaryChart(
                                  data: summaryData!,
                                  isCogsBased: isCogsBased,
                                ),
                              const SizedBox(height: 16),
                              _buildChartsGrid(isMobile),
                              const SizedBox(height: 16),
                              _buildManualEntriesSection(),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeToggle(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            "Profit Mode: ",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ToggleButtons(
            borderRadius: BorderRadius.circular(8),
            isSelected: [isCogsBased, !isCogsBased],
            onPressed: (index) {
              setState(() {
                isCogsBased = index == 0;
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text("Accrual (COGS)"),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text("Cash Flow"),
              ),
            ],
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          "Profit Mode: ",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        ToggleButtons(
          borderRadius: BorderRadius.circular(8),
          isSelected: [isCogsBased, !isCogsBased],
          onPressed: (index) {
            setState(() {
              isCogsBased = index == 0;
            });
          },
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text("Accrual (COGS)"),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text("Cash Flow (Purchases)"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    double calculateGrowth(num current, num previous) {
      if (previous == 0) return 0.0;
      return ((current - previous) / previous) * 100;
    }

    double profitGrowth = 0.0;
    double salesGrowth = 0.0;
    double expenseGrowth = 0.0;

    // Calculate profit based on mode
    final currentProfit = isCogsBased
        ? summaryData!.totalProfit
        : (summaryData!.totalSales -
              summaryData!.totalPurchases -
              summaryData!.totalExpenses);

    final currentCost = isCogsBased
        ? summaryData!.totalPurchaseCost
        : summaryData!.totalPurchases;

    if (previousSummaryData != null) {
      final prevProfit = isCogsBased
          ? previousSummaryData!.totalProfit
          : (previousSummaryData!.totalSales -
                previousSummaryData!.totalPurchases -
                previousSummaryData!.totalExpenses);

      profitGrowth = calculateGrowth(currentProfit, prevProfit);
      salesGrowth = calculateGrowth(
        summaryData!.totalSales,
        previousSummaryData!.totalSales,
      );
      expenseGrowth = calculateGrowth(
        summaryData!.totalExpenses,
        previousSummaryData!.totalExpenses,
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: "Total Sales",
                value: summaryData!.totalSales,
                color: Colors.blue,
                growthPercentage: salesGrowth,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SummaryCard(
                title: isCogsBased ? "Net Profit (COGS)" : "Net Profit (Cash)",
                value: currentProfit,
                color: Colors.green,
                growthPercentage: profitGrowth,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: isCogsBased ? "COGS" : "Total Purchases",
                value: currentCost,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SummaryCard(
                title: "Expenses",
                value: summaryData!.totalExpenses,
                color: Colors.red,
                growthPercentage: expenseGrowth,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailedCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Financial Health",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: "Discounts Given",
                value: summaryData!.totalDiscounts,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SummaryCard(
                title: "In-Hand Cash",
                value: summaryData!.inHandCash,
                color: Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: "Receivables",
                value: summaryData!.pendingFromCustomers,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SummaryCard(
                title: "Payables",
                value: summaryData!.pendingToSuppliers,
                color: Colors.deepOrange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartsGrid(bool isMobile) {
    return GridView.count(
      crossAxisCount: isMobile ? 1 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: isMobile ? 1.5 : 0.9,
      children: [
        if (categories.isNotEmpty) CategoryProfitChart(categories: categories),
        if (products.isNotEmpty) ProductProfitChart(products: products),
        if (suppliers.isNotEmpty) SupplierProfitChart(suppliers: suppliers),
        // Add more charts or placeholders here if needed
      ],
    );
  }

  Widget _buildManualEntriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Manual Entries",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.blue),
              onPressed: () => _showManualEntryDialog(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Search entries...",
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onChanged: _filterManualEntries,
        ),
        const SizedBox(height: 8),
        if (filteredManualEntries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("No manual entries found."),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredManualEntries.length,
            itemBuilder: (context, index) {
              final entry = filteredManualEntries[index];
              final isExpense = entry.type == 'expense';
              return Slidable(
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (ctx) => _deleteManualEntry(entry),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Delete',
                    ),
                  ],
                ),
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isExpense
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      child: Icon(
                        isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isExpense ? Colors.red : Colors.green,
                      ),
                    ),
                    title: Text(entry.description),
                    subtitle: Text(
                      DateFormat('dd MMM yyyy').format(entry.date),
                    ),
                    trailing: Text(
                      "${isExpense ? '-' : '+'}Rs ${entry.amount.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: isExpense ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _showManualEntryDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          ManualEntryDialog(dao: widget.controller.repo.manualEntryDao),
    );

    if (result == true) {
      fetchAll();
    }
  }

  Future<void> _deleteManualEntry(ManualEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Entry"),
        content: const Text("Are you sure you want to delete this entry?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.controller.repo.manualEntryDao.delete(entry.id);
      fetchAll();
    }
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8,
        children: [
          _chip("Daily", PLFilterType.daily),
          _chip("Weekly", PLFilterType.weekly),
          _chip("Monthly", PLFilterType.monthly),
          _chip("Yearly", PLFilterType.yearly),
          _chip("Custom", PLFilterType.custom),
        ],
      ),
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
          // refresh immediately for non-custom selections
          fetchAll();
        }
      },
    );
  }

  Widget _buildCustomRange(bool isMobile) {
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () async {
                final picked = await _pickDate();
                if (picked != null) {
                  setState(() => customStart = picked);
                }
              },
              child: Text("Start: ${_fmtOrDash(customStart)}"),
            ),
            TextButton(
              onPressed: () async {
                final picked = await _pickDate();
                if (picked != null) setState(() => customEnd = picked);
              },
              child: Text("End: ${_fmtOrDash(customEnd)}"),
            ),
            ElevatedButton(
              onPressed: () => fetchAll(),
              child: const Text("Apply"),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
      child: Row(
        children: [
          TextButton(
            onPressed: () async {
              final picked = await _pickDate();
              if (picked != null) {
                setState(() => customStart = picked);
              }
            },
            child: Text("Start: ${_fmtOrDash(customStart)}"),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              final picked = await _pickDate();
              if (picked != null) setState(() => customEnd = picked);
            },
            child: Text("End: ${_fmtOrDash(customEnd)}"),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => fetchAll(),
            child: const Text("Apply"),
          ),
        ],
      ),
    );
  }

  String _fmtOrDash(DateTime? dt) =>
      dt == null ? "-" : DateFormat("dd MMM").format(dt);

  Future<DateTime?> _pickDate() async {
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
  }

  Future<void> _exportPDF() async {
    if (summaryData == null) return;

    await PDFExporter.exportDashboard(
      summary: summaryData!,
      categories: categories,
      products: products,
      suppliers: suppliers,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF exported to Documents folder')),
      );
    }
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
    try {
      // Debug logging
      debugPrint(
        "Exporting PDF: sales=${_sanitizeValue(summary.totalSales)}, "
        "profit=${_sanitizeValue(summary.totalProfit)}, "
        "expenses=${_sanitizeValue(summary.totalExpenses)}",
      );

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  "Profit & Loss Dashboard",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Summary Cards Row 1
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _summaryCardPdf(
                    "Total Sales",
                    summary.totalSales,
                    PdfColors.blue,
                  ),
                  _summaryCardPdf(
                    "COGS Profit",
                    summary.totalProfit,
                    PdfColors.green,
                  ),
                  _summaryCardPdf(
                    "Expenses",
                    summary.totalExpenses,
                    PdfColors.red,
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Summary Cards Row 2
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _summaryCardPdf(
                    "Discounts",
                    summary.totalDiscounts,
                    PdfColors.orange,
                  ),
                  _summaryCardPdf(
                    "Receivables",
                    summary.pendingFromCustomers,
                    PdfColors.indigo,
                  ),
                  _summaryCardPdf(
                    "Payables",
                    summary.pendingToSuppliers,
                    PdfColors.deepOrange,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Detailed Financial Breakdown
              pw.Text(
                "Financial Breakdown",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ["Metric", "Amount"],
                data: [
                  [
                    "Gross Sales",
                    _safeMoneyFormat(
                      summary.totalSales + summary.totalDiscounts,
                    ),
                  ],
                  ["Less: Discounts", _safeMoneyFormat(summary.totalDiscounts)],
                  ["Net Sales", _safeMoneyFormat(summary.totalSales)],
                  ["", ""],
                  ["Less: COGS", _safeMoneyFormat(summary.totalPurchaseCost)],
                  [
                    "Gross Profit (COGS-based)",
                    _safeMoneyFormat(
                      summary.totalSales - summary.totalPurchaseCost,
                    ),
                  ],
                  ["", ""],
                  [
                    "Less: Total Expenses",
                    _safeMoneyFormat(summary.totalExpenses),
                  ],
                  [
                    "Net Profit (COGS-based)",
                    _safeMoneyFormat(summary.totalProfit),
                  ],
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 15),

              // Profit Calculation Comparison
              pw.Text(
                "Profit Calculation Comparison",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // COGS-Based
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "COGS-Based (Standard)",
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          _buildCalcRow("Sales", summary.totalSales),
                          _buildCalcRow("- COGS", summary.totalPurchaseCost),
                          _buildCalcRow("- Expenses", summary.totalExpenses),
                          pw.Divider(height: 4),
                          _buildCalcRow(
                            "= Net Profit",
                            summary.totalProfit,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  // Purchase-Based
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Purchase-Based (Cash Flow)",
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.purple900,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          _buildCalcRow("Sales", summary.totalSales),
                          _buildCalcRow("- Purchases", summary.totalPurchases),
                          _buildCalcRow("- Expenses", summary.totalExpenses),
                          pw.Divider(height: 4),
                          _buildCalcRow(
                            "= Cash Profit",
                            summary.totalSales -
                                summary.totalPurchases -
                                summary.totalExpenses,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 15),

              // Cash Flow Analysis
              pw.Text(
                "Cash Flow Analysis",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ["Metric", "Amount"],
                data: [
                  [
                    "Cash Received (Paid)",
                    _safeMoneyFormat(
                      summary.totalSales - summary.pendingFromCustomers,
                    ),
                  ],
                  [
                    "Receivables (Pending)",
                    _safeMoneyFormat(summary.pendingFromCustomers),
                  ],
                  ["Total Sales Value", _safeMoneyFormat(summary.totalSales)],
                  ["", ""],
                  [
                    "Payables (Pending to Suppliers)",
                    _safeMoneyFormat(summary.pendingToSuppliers),
                  ],
                  ["In-Hand Cash", _safeMoneyFormat(summary.inHandCash)],
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 15),

              // Purchase & Inventory Analysis
              pw.Text(
                "Purchase & Inventory Analysis",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ["Metric", "Amount", "Note"],
                data: [
                  [
                    "Total Purchases Made",
                    _safeMoneyFormat(summary.totalPurchases),
                    "All purchases in period",
                  ],
                  [
                    "COGS (Goods Sold)",
                    _safeMoneyFormat(summary.totalPurchaseCost),
                    "Cost of items sold",
                  ],
                  [
                    "Inventory Added",
                    _safeMoneyFormat(
                      summary.totalPurchases - summary.totalPurchaseCost,
                    ),
                    "Stock remaining",
                  ],
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),

              // Charts
              pw.SizedBox(height: 20),
              pw.Container(
                height: 200,
                child: pw.Chart(
                  grid: pw.CartesianGrid(
                    xAxis: pw.FixedAxis(
                      [0, 1, 2, 3],
                      format: (v) =>
                          ["Sales", "COGS", "Exp", "Profit"][v.toInt()],
                    ),
                    yAxis: pw.FixedAxis(
                      _generateYAxisTicks(summary),
                      format: (v) => "Rs ${v.toInt()}",
                    ),
                  ),
                  datasets: [
                    pw.BarDataSet(
                      color: PdfColors.blue,
                      data: [
                        pw.PointChartValue(
                          0,
                          _sanitizeValue(summary.totalSales),
                        ),
                      ],
                      width: 30,
                      legend: "Sales",
                    ),
                    pw.BarDataSet(
                      color: PdfColors.orange,
                      data: [
                        pw.PointChartValue(
                          1,
                          _sanitizeValue(summary.totalPurchaseCost),
                        ),
                      ],
                      width: 30,
                      legend: "COGS",
                    ),
                    pw.BarDataSet(
                      color: PdfColors.red,
                      data: [
                        pw.PointChartValue(
                          2,
                          _sanitizeValue(summary.totalExpenses),
                        ),
                      ],
                      width: 30,
                      legend: "Expenses",
                    ),
                    pw.BarDataSet(
                      color: PdfColors.green,
                      data: [
                        pw.PointChartValue(
                          3,
                          _sanitizeValue(summary.totalProfit),
                        ),
                      ],
                      width: 30,
                      legend: "Profit",
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Detailed Tables
              pw.Text(
                "Category-wise Profit",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.TableHelper.fromTextArray(
                headers: ["Category", "Profit"],
                data: categories
                    .map((c) => [c.name, _safeMoneyFormat(c.profit)])
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 20),

              pw.Text(
                "Product-wise Profit (Top 10)",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.TableHelper.fromTextArray(
                headers: ["Product", "Profit"],
                data: products
                    .take(10)
                    .map((p) => [p.name, _safeMoneyFormat(p.profit)])
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),

              if (suppliers.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  "Supplier Purchases (Top 10)",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.TableHelper.fromTextArray(
                  headers: ["Supplier", "Purchases", "Pending"],
                  data: suppliers
                      .take(10)
                      .map(
                        (s) => [
                          s.name,
                          _safeMoneyFormat(s.totalPurchases),
                          _safeMoneyFormat(s.pendingToSupplier),
                        ],
                      )
                      .toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
              ],
            ];
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/profit_loss_dashboard.pdf");
      await file.writeAsBytes(await pdf.save());
    } catch (e, st) {
      debugPrint("PDF export failed: $e\n$st");
      rethrow;
    }
  }

  // Helper to sanitize values and prevent NaN
  static double _sanitizeValue(num? value) {
    if (value == null) return 0.0;
    final doubleVal = value.toDouble();
    if (doubleVal.isNaN || doubleVal.isInfinite) {
      return 0.0;
    }
    return doubleVal;
  }

  // Safe format for money (prevents errors if value is NaN/null)
  static String _safeMoneyFormat(num? value) {
    final v = _sanitizeValue(value);
    return "Rs ${v.toStringAsFixed(2)}";
  }

  static List<num> _generateYAxisTicks(ProfitLossModel summary) {
    // Collect only finite values
    final numbers = <double>[
      _sanitizeValue(summary.totalSales),
      _sanitizeValue(summary.totalPurchaseCost),
      _sanitizeValue(summary.totalExpenses),
      _sanitizeValue(summary.totalProfit),
    ];

    final maxVal = numbers.reduce((curr, next) => curr > next ? curr : next);

    if (maxVal <= 0) return [0, 100];

    final step = maxVal / 4;
    return [0, step, step * 2, step * 3, step * 4]; // 5 ticks
  }

  static pw.Widget _buildCalcRow(
    String label,
    double value, {
    bool bold = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold ? pw.FontWeight.bold : null,
          ),
        ),
        pw.Text(
          _safeMoneyFormat(value),
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold ? pw.FontWeight.bold : null,
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryCardPdf(String title, num? value, PdfColor color) {
    final safeVal = _sanitizeValue(value);
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            _safeMoneyFormat(safeVal),
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

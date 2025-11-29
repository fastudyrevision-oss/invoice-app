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
        rangeStart = currentWeekStart.subtract(const Duration(days: 7));
        rangeEnd = currentWeekStart.subtract(const Duration(seconds: 1));
        break;
      case PLFilterType.monthly:
        // Previous month
        rangeStart = DateTime(now.year, now.month - 1, 1);
        rangeEnd = DateTime(now.year, now.month, 0); // Last day of prev month
        break;
      case PLFilterType.yearly:
        // Previous year
        rangeStart = DateTime(now.year - 1, 1, 1);
        rangeEnd = DateTime(now.year - 1, 12, 31);
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
      // Calculate total purchases for previous period if needed for consistency
      // For now, we'll just return summary as is, or fetch suppliers if we want strict accuracy for "Cash Flow" mode in previous period.
      // Let's fetch suppliers to be consistent with getData.
      final suppliers = await repo.loadSupplierProfit(rangeStart, rangeEnd);
      double totalPurchases = 0;
      for (var s in suppliers) {
        totalPurchases += s.totalPurchases;
      }
      return ProfitLossModel.fromSummary(
        summary,
        totalPurchases: totalPurchases,
      );
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
        if (start != null && end != null && dao.getByDateRange != null) {
          return await dao.getByDateRange(start, end);
        }
        if (dao.getAll != null) return await dao.getAll();
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

  const ProfitLossScreen({required this.controller, Key? key})
    : super(key: key);

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
          if (selected == PLFilterType.custom) _buildCustomRange(),
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
                          _buildModeToggle(),
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
                          _buildChartsGrid(),
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
  }

  Widget _buildModeToggle() {
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

  Widget _buildChartsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.9, // Adjust for card height
      children: [
        if (categories.isNotEmpty) CategoryProfitChart(categories: categories),
        if (products.isNotEmpty) ProductProfitChart(products: products),
        if (suppliers.isNotEmpty) SupplierProfitChart(suppliers: suppliers),
        // Add more charts or placeholders here if needed
      ],
    );
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

  Widget _buildCustomRange() {
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

  Widget _buildExportButton() {
    final enabled = summaryData != null;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text("Export PDF"),
        onPressed: enabled
            ? () async {
                await PDFExporter.exportDashboard(
                  summary: summaryData!,
                  categories: categories,
                  products: products,
                  suppliers: suppliers,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PDF exported to Documents folder'),
                  ),
                );
              }
            : null,
      ),
    );
  }

  Widget _buildManualEntriesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
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
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search entries...",
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: _filterManualEntries,
            ),
            const SizedBox(height: 8),
            if (filteredManualEntries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('No manual entries found')),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredManualEntries.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final entry = filteredManualEntries[i];
                  return Slidable(
                    key: ValueKey(entry.id),
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (_) =>
                              _showManualEntryDialog(entry: entry),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          icon: Icons.edit,
                          label: 'Edit',
                        ),
                        SlidableAction(
                          onPressed: (_) => _deleteManualEntry(entry),
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: 'Delete',
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      title: Text(
                        entry.description,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd').format(entry.date),
                      ),
                      trailing: Text(
                        '${entry.type == "income" ? "+" : "-"}Rs ${entry.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: entry.type == "income"
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showManualEntryDialog({ManualEntry? entry}) async {
    final result = await showDialog<bool?>(
      context: context,
      builder: (context) => ManualEntryDialog(
        dao: widget.controller.repo.manualEntryDao,
        entry: entry,
      ),
    );
    if (result == true) await fetchAll();
  }

  Future<void> _deleteManualEntry(ManualEntry entry) async {
    // Optimistic update or confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.controller.repo.manualEntryDao.delete(entry.id);
      await fetchAll();
    }
  }

  Future<void> _exportPDF() async {
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
// ---------------------- PDF EXPORT HELPER ----------------------
class PDFExporter {
  static Future<void> exportDashboard({
    required ProfitLossModel summary,
    required List<CategoryProfit> categories,
    required List<ProductProfit> products,
    required List<SupplierProfit> suppliers,
  }) async {
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

            // Summary Cards Row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _summaryCardPdf(
                  "Total Sales",
                  summary.totalSales,
                  PdfColors.blue,
                ),
                _summaryCardPdf(
                  "Net Profit",
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
            pw.SizedBox(height: 20),

            // Main Chart (Bar Chart)
            pw.Text(
              "Income vs Expense Breakdown",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
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
                    format: (v) => "\$${v.toInt()}",
                  ),
                ),
                datasets: [
                  pw.BarDataSet(
                    color: PdfColors.blue,
                    data: [
                      pw.PointChartValue(0, summary.totalSales.toDouble()),
                    ],
                    width: 30,
                    legend: "Sales",
                  ),
                  pw.BarDataSet(
                    color: PdfColors.orange,
                    data: [
                      pw.PointChartValue(
                        1,
                        summary.totalPurchaseCost.toDouble(),
                      ),
                    ],
                    width: 30,
                    legend: "COGS",
                  ),
                  pw.BarDataSet(
                    color: PdfColors.red,
                    data: [
                      pw.PointChartValue(2, summary.totalExpenses.toDouble()),
                    ],
                    width: 30,
                    legend: "Expenses",
                  ),
                  pw.BarDataSet(
                    color: PdfColors.green,
                    data: [
                      pw.PointChartValue(3, summary.totalProfit.toDouble()),
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
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.TableHelper.fromTextArray(
              headers: ["Category", "Profit"],
              data: categories
                  .map((c) => [c.name, c.profit.toStringAsFixed(2)])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 20),

            pw.Text(
              "Product-wise Profit (Top 10)",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.TableHelper.fromTextArray(
              headers: ["Product", "Profit"],
              data: products
                  .take(10)
                  .map((p) => [p.name, p.profit.toStringAsFixed(2)])
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
                        s.totalPurchases.toStringAsFixed(2),
                        s.pendingToSupplier.toStringAsFixed(2),
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
  }

  static List<num> _generateYAxisTicks(ProfitLossModel summary) {
    final maxVal = [
      summary.totalSales,
      summary.totalPurchaseCost,
      summary.totalExpenses,
      summary.totalProfit,
    ].reduce((curr, next) => curr > next ? curr : next).toDouble();

    if (maxVal <= 0) return [0, 100];

    final step = maxVal / 4;
    return [0, step, step * 2, step * 3, step * 4]; // 5 ticks
  }

  static pw.Widget _summaryCardPdf(String title, num value, PdfColor color) {
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
            "\$${value.toStringAsFixed(2)}",
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

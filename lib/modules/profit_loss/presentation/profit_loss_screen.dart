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
import '../data/models/customer_profit.dart';
import '../data/repository/profit_loss_repo.dart';
import 'profit_loss_chart.dart';
import 'manual_entry_dialog.dart';
import '../data/models/manual_entry.dart';
import 'widgets/summary_card.dart'; // Import the new widget
import '../../../../utils/responsive_utils.dart';
import '../../../core/services/audit_logger.dart';
import '../../../services/auth_service.dart';
import '../../../services/logger_service.dart';

// ---------------------- ENUM ----------------------
enum PLFilterType { daily, weekly, monthly, yearly, custom }

enum PLDataType { summary, category, product, supplier, customer }

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
      case PLDataType.customer:
        final customers = await repo.loadCustomerProfit(rangeStart, rangeEnd);
        return ProfitLossModel(customerProfits: customers);
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
  List<CustomerProfit> customerProfits = [];
  List<Map<String, dynamic>> recentTransactions = [];
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

      final customerData = await widget.controller.getData(
        selected,
        start: customStart,
        end: customEnd,
        type: PLDataType.customer,
      );

      final recentTx = await widget.controller.repo.loadRecentTransactions(10);

      setState(() {
        summaryData = summary;
        previousSummaryData = prevSummary;
        categories = categoryData.categories;
        products = productData.products;
        suppliers = supplierData.suppliers;
        customerProfits = customerData.customerProfits;
        recentTransactions = recentTx;
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
                onPressed: summaryData != null ? _showPDFOptionsDialog : null,
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
                              if (summaryData != null) _buildTrendAnalysis(),
                              const SizedBox(height: 16),
                              if (summaryData != null)
                                _buildCompanyProfitability(),
                              const SizedBox(height: 16),
                              if (summaryData != null) _buildDetailedCards(),
                              const SizedBox(height: 16),
                              _buildCategoryInsights(),
                              const SizedBox(height: 16),
                              if (summaryData != null)
                                _buildIncomeBreakdown(), // ✅ Added
                              const SizedBox(height: 16),
                              _buildSupplierInsights(),
                              const SizedBox(height: 16),
                              if (summaryData != null) _buildExpenseBreakdown(),
                              const SizedBox(height: 16),
                              if (summaryData != null)
                                ProfitLossSummaryChart(
                                  data: summaryData!,
                                  isCogsBased: isCogsBased,
                                ),
                              const SizedBox(height: 16),
                              _buildChartsGrid(isMobile),
                              const SizedBox(height: 16),
                              _buildCustomerInsights(),
                              const SizedBox(height: 16),
                              _buildRecentTransactions(),
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
              summaryData!
                  .totalDiscounts - // ✅ Subtract discounts from Gross Sales
              summaryData!.totalPurchases -
              summaryData!.totalExpenses);

    final currentCost = isCogsBased
        ? summaryData!.totalPurchaseCost
        : summaryData!.totalPurchases;

    if (previousSummaryData != null) {
      final prevProfit = isCogsBased
          ? previousSummaryData!.totalProfit
          : (previousSummaryData!.totalSales -
                previousSummaryData!
                    .totalDiscounts - // ✅ Subtract discounts here too
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
        const SizedBox(height: 8),
        if (summaryData!.netExpiredLoss > 0)
          SummaryCard(
            title: "Expired Stock Loss",
            value: summaryData!.netExpiredLoss,
            color: Colors.brown,
            subtitle:
                "Write-offs: Rs ${summaryData!.expiredStockLoss.toStringAsFixed(2)}, Refunds: Rs ${summaryData!.expiredStockRefunds.toStringAsFixed(2)}",
          ),
      ],
    );
  }

  Widget _buildIncomeBreakdown() {
    final breakdown = summaryData!.incomeBreakdown;
    if (breakdown.isEmpty) return const SizedBox();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  'Manual Income Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 24),
            ...breakdown.entries.map((e) {
              final val = e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: TextStyle(color: Colors.grey.shade700)),
                    Text(
                      'Rs ${val.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseBreakdown() {
    final breakdown = summaryData!.expenseBreakdown;
    if (breakdown.isEmpty) return const SizedBox();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart_outline, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text(
                  'Expense Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 24),
            ...breakdown.entries.map((e) {
              final val = e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: TextStyle(color: Colors.grey.shade700)),
                    Text(
                      'Rs ${val.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Expenses',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Rs ${summaryData!.totalExpenses.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsGrid(bool isMobile) {
    return GridView.count(
      crossAxisCount: isMobile ? 1 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: isMobile ? 1.2 : 0.85,
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
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
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

  Widget _buildRecentTransactions() {
    if (recentTransactions.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Recent Transactions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(onPressed: fetchAll, child: const Text("Refresh")),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentTransactions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tx = recentTransactions[index];
              final isSale = tx['type'] == 'sale';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSale
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  child: Icon(
                    isSale ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isSale ? Colors.green : Colors.red,
                    size: 18,
                  ),
                ),
                title: Text(isSale ? "Sale" : "Purchase"),
                subtitle: Text(
                  DateFormat(
                    'yyyy-MM-dd HH:mm',
                  ).format(DateTime.parse(tx['date'])),
                ),
                trailing: Text(
                  "Rs ${tx['total'].toStringAsFixed(2)}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerInsights() {
    if (customerProfits.isEmpty) return const SizedBox();
    // Support only Top 10
    final topCustomers = customerProfits.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Top 10 Customers by Profit",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: topCustomers.length,
            itemBuilder: (context, index) {
              final cp = topCustomers[index];
              return Container(
                width: 250,
                margin: const EdgeInsets.only(right: 12),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cp.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        _buildInsightRow("Sales", cp.totalSales, Colors.blue),
                        const SizedBox(height: 4),
                        _buildInsightRow("Cost", cp.totalCost, Colors.orange),
                        const Divider(),
                        _buildInsightRow(
                          "Profit",
                          cp.profit,
                          Colors.green,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrendAnalysis() {
    if (summaryData == null || previousSummaryData == null) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Trend Analysis (vs Previous Period)",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _trendCard(
              "Sales",
              summaryData!.totalSales,
              previousSummaryData!.totalSales,
              Colors.blue,
            ),
            const SizedBox(width: 12),
            _trendCard(
              "Profit",
              isCogsBased
                  ? summaryData!.totalProfit
                  : (summaryData!.totalSales -
                        summaryData!.totalPurchases -
                        summaryData!.totalExpenses),
              isCogsBased
                  ? previousSummaryData!.totalProfit
                  : (previousSummaryData!.totalSales -
                        previousSummaryData!.totalPurchases -
                        previousSummaryData!.totalExpenses),
              Colors.green,
            ),
            const SizedBox(width: 12),
            _trendCard(
              "Expenses",
              summaryData!.totalExpenses,
              previousSummaryData!.totalExpenses,
              Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _trendCard(
    String label,
    double current,
    double previous,
    Color color,
  ) {
    final diff = current - previous;
    final percent = previous > 0 ? (diff / previous) * 100 : 0.0;
    final isPositive = diff >= 0;

    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                "Rs ${current.toStringAsFixed(0)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    size: 14,
                    color: isPositive ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${percent.abs().toStringAsFixed(1)}%",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyProfitability() {
    if (summaryData == null) return const SizedBox();
    final netProfit = isCogsBased
        ? summaryData!.totalProfit
        : (summaryData!.totalSales -
              summaryData!.totalPurchases -
              summaryData!.totalExpenses);
    final margin = summaryData!.totalSales > 0
        ? (netProfit / summaryData!.totalSales) * 100
        : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.business, color: Colors.white, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Company Profitability Margin",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    "${margin.toStringAsFixed(1)}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "Status",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  margin > 15
                      ? "Excellent"
                      : margin > 5
                      ? "Good"
                      : "Critical",
                  style: TextStyle(
                    color: margin > 5 ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryInsights() {
    if (categories.isEmpty) return const SizedBox();
    final topCategories = categories.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Top 10 Categories by Profit",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: topCategories.length,
            itemBuilder: (context, index) {
              final cat = topCategories[index];
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 12),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          cat.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Rs ${cat.profit.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Text("Profit", style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierInsights() {
    if (suppliers.isEmpty) return const SizedBox();
    final topSuppliers = suppliers.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Top 10 Suppliers (Purchase Value)",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: topSuppliers.length,
            itemBuilder: (context, index) {
              final s = topSuppliers[index];
              return Container(
                width: 220,
                margin: const EdgeInsets.only(right: 12),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Purchases:",
                              style: TextStyle(fontSize: 12),
                            ),
                            Text(
                              "Rs ${s.totalPurchases.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Pending:",
                              style: TextStyle(fontSize: 12),
                            ),
                            Text(
                              "Rs ${s.pendingToSupplier.toStringAsFixed(0)}",
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInsightRow(
    String label,
    double value,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(
          "Rs ${value.toStringAsFixed(0)}",
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showPDFOptionsDialog() {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => _PLReportOptionsDialog(
        onExport: (options) async {
          Navigator.pop(dialogCtx);
          setState(() => loading = true);
          try {
            await PDFExporter.exportDashboard(
              summary: summaryData!,
              previousSummary: previousSummaryData,
              isCogsBased: isCogsBased,
              categories: options['Categories'] == true ? categories : [],
              products: options['Products'] == true ? products : [],
              suppliers: options['Suppliers'] == true ? suppliers : [],
              customerProfits: options['Customers'] == true
                  ? customerProfits
                  : [],
            );

            // 📝 ADD AUDIT LOG
            await AuditLogger.log(
              'PDF_EXPORT',
              'profit_loss_report',
              recordId: 'PL-${DateTime.now().millisecondsSinceEpoch}',
              userId: AuthService.instance.currentUser?.id ?? 'system',
              newData: options,
            );

            // 📝 ADD SYSTEM LOG
            logger.info(
              'ProfitLoss',
              'P&L Report exported as PDF',
              context: options,
            );

            if (mounted) {
              messenger.showSnackBar(
                const SnackBar(content: Text('PDF Exported Successfully')),
              );
            }
          } catch (e, st) {
            logger.error(
              'ProfitLoss',
              'PDF Export failed',
              error: e,
              stackTrace: st,
            );
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text('Export failed: $e')),
              );
            }
          } finally {
            if (mounted) {
              setState(() => loading = false);
            }
          }
        },
      ),
    );
  }
}

class _PLReportOptionsDialog extends StatefulWidget {
  final Function(Map<String, bool>) onExport;
  const _PLReportOptionsDialog({required this.onExport});

  @override
  State<_PLReportOptionsDialog> createState() => _PLReportOptionsDialogState();
}

class _PLReportOptionsDialogState extends State<_PLReportOptionsDialog> {
  final Map<String, bool> _options = {
    'Summary': true,
    'Trends': true,
    'Analysis': true,
    'Categories': true,
    'Products': true,
    'Suppliers': true,
    'Customers': true,
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Export Options"),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _options.keys.map((key) {
            return CheckboxListTile(
              title: Text(key),
              value: _options[key],
              onChanged: (val) => setState(() => _options[key] = val ?? false),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () => widget.onExport(_options),
          child: const Text("Export PDF"),
        ),
      ],
    );
  }
}

// ---------------------- PDF EXPORT HELPER ----------------------
class PDFExporter {
  static Future<void> exportDashboard({
    required ProfitLossModel summary,
    ProfitLossModel? previousSummary,
    required bool isCogsBased,
    required List<CategoryProfit> categories,
    required List<ProductProfit> products,
    required List<SupplierProfit> suppliers,
    required List<CustomerProfit> customerProfits,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (ctx) => pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Profit & Loss Report",
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        isCogsBased
                            ? "(COGS Based)"
                            : "(Purchase Based / Cash Profit)",
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    DateFormat('dd MMM yyyy').format(DateTime.now()),
                    style: const pw.TextStyle(color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.blue900, thickness: 2),
              pw.SizedBox(height: 20),
            ],
          ),
          build: (pw.Context ctx) {
            final netProfit = isCogsBased
                ? summary.totalProfit
                : (summary.totalSales -
                      summary.totalPurchases -
                      summary.totalExpenses);

            return [
              // Summary Section
              pw.Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _summaryCardPdf(
                    "Total Sales",
                    summary.totalSales,
                    PdfColors.blue,
                  ),
                  _summaryCardPdf(
                    isCogsBased ? "Net Profit" : "Cash Profit",
                    netProfit,
                    PdfColors.green,
                  ),
                  _summaryCardPdf(
                    "Total Expenses",
                    summary.totalExpenses,
                    PdfColors.red,
                  ),
                  _summaryCardPdf(
                    "Total Purchases",
                    summary.totalPurchases,
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
              pw.SizedBox(height: 30),

              // Trend Analysis Section
              if (previousSummary != null) ...[
                pw.Text(
                  "Trend Analysis (vs Previous Period)",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  headers: ["Metric", "Current", "Previous", "Change", "%"],
                  data: [
                    _trendRow(
                      "Sales",
                      summary.totalSales,
                      previousSummary.totalSales,
                    ),
                    _trendRow(
                      "Profit",
                      netProfit,
                      isCogsBased
                          ? previousSummary.totalProfit
                          : (previousSummary.totalSales -
                                previousSummary.totalPurchases -
                                previousSummary.totalExpenses),
                    ),
                    _trendRow(
                      "Expenses",
                      summary.totalExpenses,
                      previousSummary.totalExpenses,
                    ),
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                pw.SizedBox(height: 30),
              ],

              // Detailed Profit Calculation logic
              pw.Text(
                "Profit Calculation Methodology",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ["Component", "Calculation", "Amount"],
                data: isCogsBased
                    ? [
                        [
                          "Gross Sales",
                          "Direct Revenue",
                          _safeMoneyFormat(
                            summary.totalSales + summary.totalDiscounts,
                          ),
                        ],
                        [
                          "- Discounts",
                          "Customer Deductions",
                          _safeMoneyFormat(summary.totalDiscounts),
                        ],
                        [
                          "Net Sales (A)",
                          "Revenue - Discounts",
                          _safeMoneyFormat(summary.totalSales),
                        ],
                        [
                          "- COGS (B)",
                          "Cost of Goods Sold",
                          _safeMoneyFormat(summary.totalPurchaseCost),
                        ],
                        [
                          "Gross Profit (A-B)",
                          "Trading Margin",
                          _safeMoneyFormat(
                            summary.totalSales - summary.totalPurchaseCost,
                          ),
                        ],
                        [
                          "- Expenses (C)",
                          "Operating Costs",
                          _safeMoneyFormat(summary.totalExpenses),
                        ],
                        [
                          "Net Profit",
                          "(A - B - C)",
                          _safeMoneyFormat(summary.totalProfit),
                        ],
                      ]
                    : [
                        [
                          "Total Sales (A)",
                          "Cash & Credits Generated",
                          _safeMoneyFormat(summary.totalSales),
                        ],
                        [
                          "- Purchases (B)",
                          "Inventory Acquisition",
                          _safeMoneyFormat(summary.totalPurchases),
                        ],
                        [
                          "- Expenses (C)",
                          "Operating Costs",
                          _safeMoneyFormat(summary.totalExpenses),
                        ],
                        [
                          "Cash Profit",
                          "(A - B - C)",
                          _safeMoneyFormat(netProfit),
                        ],
                      ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 30),

              // Cash Flow Analysis
              pw.Text(
                "Cash Flow & Liquidity Analysis",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ["Cash Position", "Description", "Value"],
                data: [
                  [
                    "Cash Received",
                    "Actual cash collected from sales",
                    _safeMoneyFormat(summary.totalReceived),
                  ],
                  [
                    "Receivables",
                    "Pending payments from customers",
                    _safeMoneyFormat(summary.pendingFromCustomers),
                  ],
                  [
                    "Payables",
                    "Pending payments to suppliers",
                    _safeMoneyFormat(summary.pendingToSuppliers),
                  ],
                  [
                    "Net Cash Position",
                    "Cash Received - Pending Payables",
                    _safeMoneyFormat(
                      summary.totalReceived - summary.pendingToSuppliers,
                    ),
                  ],
                ],
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 30),

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
                headers: ["Metric", "Description", "Value"],
                data: [
                  [
                    "Total Purchases",
                    "Raw stock acquisition cost",
                    _safeMoneyFormat(summary.totalPurchases),
                  ],
                  [
                    "COGS (Used)",
                    "Stock consumed in sales",
                    _safeMoneyFormat(summary.totalPurchaseCost),
                  ],
                  [
                    "Inventory Delta",
                    "New stock added to warehouse (Purchases - COGS)",
                    _safeMoneyFormat(
                      summary.totalPurchases - summary.totalPurchaseCost,
                    ),
                  ],
                ],
              ),
              pw.SizedBox(height: 30),

              // Performance Chart
              pw.Text(
                "Key Performance Chart",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                height: 150,
                child: pw.Chart(
                  grid: pw.CartesianGrid(
                    xAxis: pw.FixedAxis(
                      [0, 1, 2, 3],
                      format: (v) => [
                        "Sales",
                        isCogsBased ? "COGS" : "Purchases",
                        "Exp",
                        "Profit",
                      ][v.toInt()],
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
                      width: 25,
                    ),
                    pw.BarDataSet(
                      color: PdfColors.orange,
                      data: [
                        pw.PointChartValue(
                          1,
                          _sanitizeValue(
                            isCogsBased
                                ? summary.totalPurchaseCost
                                : summary.totalPurchases,
                          ),
                        ),
                      ],
                      width: 25,
                    ),
                    pw.BarDataSet(
                      color: PdfColors.red,
                      data: [
                        pw.PointChartValue(
                          2,
                          _sanitizeValue(summary.totalExpenses),
                        ),
                      ],
                      width: 25,
                    ),
                    pw.BarDataSet(
                      color: PdfColors.green,
                      data: [pw.PointChartValue(3, _sanitizeValue(netProfit))],
                      width: 25,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),

              // Top Listings (Hard-limited to 10)
              if (categories.isNotEmpty) ...[
                pw.Text(
                  "Top 10 Categories by Profit",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.TableHelper.fromTextArray(
                  headers: ["Category", "Profit"],
                  data: categories
                      .take(10)
                      .map((c) => [c.name, _safeMoneyFormat(c.profit)])
                      .toList(),
                ),
                pw.SizedBox(height: 20),
              ],

              if (products.isNotEmpty) ...[
                pw.Text(
                  "Top 10 Products by Profit",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.TableHelper.fromTextArray(
                  headers: ["Product", "Profit"],
                  data: products
                      .take(10)
                      .map((p) => [p.name, _safeMoneyFormat(p.profit)])
                      .toList(),
                ),
                pw.SizedBox(height: 20),
              ],

              if (customerProfits.isNotEmpty) ...[
                pw.Text(
                  "Top 10 Customers by Profit",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.TableHelper.fromTextArray(
                  headers: ["Customer", "Sales", "Profit"],
                  data: customerProfits
                      .take(10)
                      .map(
                        (c) => [
                          c.name,
                          _safeMoneyFormat(c.totalSales),
                          _safeMoneyFormat(c.profit),
                        ],
                      )
                      .toList(),
                ),
                pw.SizedBox(height: 20),
              ],

              if (suppliers.isNotEmpty) ...[
                pw.Text(
                  "Top 10 Suppliers (Purchase Value)",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
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
                ),
              ],
            ];
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        "${dir.path}/profit_loss_report_${DateTime.now().millisecondsSinceEpoch}.pdf",
      );
      await file.writeAsBytes(await pdf.save());
    } catch (e, st) {
      debugPrint("PDF export failed: $e\n$st");
      rethrow;
    }
  }

  static List<String> _trendRow(String label, double current, double previous) {
    final diff = current - previous;
    final percent = previous > 0 ? (diff / previous) * 100 : 0.0;
    return [
      label,
      "Rs ${current.toStringAsFixed(0)}",
      "Rs ${previous.toStringAsFixed(0)}",
      "${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(0)}",
      "${percent.toStringAsFixed(1)}%",
    ];
  }

  static double _sanitizeValue(num? value) {
    if (value == null) return 0.0;
    final d = value.toDouble();
    return (d.isNaN || d.isInfinite) ? 0.0 : d;
  }

  static String _safeMoneyFormat(num? value) {
    return "Rs ${_sanitizeValue(value).toStringAsFixed(0)}";
  }

  static List<num> _generateYAxisTicks(ProfitLossModel summary) {
    final values = [
      summary.totalSales,
      summary.totalPurchases,
      summary.totalExpenses,
    ];
    final maxVal = values.isNotEmpty
        ? values.reduce((a, b) => a > b ? a : b)
        : 0;
    if (maxVal <= 0) return [0, 100];
    final step = maxVal / 4;
    return [0, step, step * 2, step * 3, step * 4];
  }

  static pw.Widget _summaryCardPdf(String title, num? value, PdfColor color) {
    return pw.Container(
      width: 155,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _safeMoneyFormat(value),
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

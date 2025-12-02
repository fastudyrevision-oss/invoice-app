import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../dao/customer_payment_dao.dart';
import '../../repositories/report_repository.dart';
import '../../services/report_export_service.dart';
import '../../models/reports/combined_payment_entry.dart';

enum PaymentType { all, suppliers, customers }

class PaymentReportFrame extends StatefulWidget {
  const PaymentReportFrame({super.key});

  @override
  State<PaymentReportFrame> createState() => _PaymentReportFrameState();
}

class _PaymentReportFrameState extends State<PaymentReportFrame> {
  final _reportRepo = ReportRepository();
  final _exportService = ReportExportService();
  final _customerPaymentDao = CustomerPaymentDao();

  List<CombinedPaymentEntry> _allEntries = [];
  List<CombinedPaymentEntry> _filteredEntries = [];
  bool _isLoading = true;

  PaymentType _selectedType = PaymentType.all;
  DateTime? _startDate;
  DateTime? _endDate;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllPayments() async {
    setState(() => _isLoading = true);

    try {
      // Load supplier payments (purchases and payments)
      final supplierReports = await _reportRepo.getPaymentReports();

      // Load customer payments
      final customerPayments = await _customerPaymentDao
          .getAllPaymentsWithCustomer();

      final List<CombinedPaymentEntry> entries = [];

      // Add supplier transactions
      for (final report in supplierReports) {
        // LOGIC CHANGE: Only count Supplier Payments (Credit) as Money Out.
        // Purchases (Debit) are ignored for Cash Flow view.
        if (report.credit > 0) {
          entries.add(
            CombinedPaymentEntry(
              date: report.date,
              entityName: report.supplierName,
              reference: report.reference,
              moneyOut: report.credit, // Payment to Supplier
              moneyIn: 0,
              type: 'supplier',
              description: 'Payment to Supplier',
            ),
          );
        }
      }

      // Add customer payments (money coming in)
      for (final payment in customerPayments) {
        entries.add(
          CombinedPaymentEntry(
            date: DateTime.parse(payment['date']),
            entityName: payment['customer_name'] ?? 'Unknown',
            reference:
                payment['transaction_ref'] ?? payment['method'] ?? 'Payment',
            moneyOut: 0,
            moneyIn: (payment['amount'] as num).toDouble(),
            type: 'customer',
            description: 'Payment from Customer',
          ),
        );
      }

      // Sort by date descending
      entries.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _allEntries = entries;
        _filteredEntries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading payments: $e')));
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredEntries = _allEntries.where((entry) {
        // Type filter
        if (_selectedType == PaymentType.suppliers &&
            entry.type != 'supplier') {
          return false;
        }
        if (_selectedType == PaymentType.customers &&
            entry.type != 'customer') {
          return false;
        }

        // Date filter
        if (_startDate != null && entry.date.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null && entry.date.isAfter(_endDate!)) {
          return false;
        }

        // Search filter
        final searchQuery = _searchController.text.toLowerCase();
        if (searchQuery.isNotEmpty) {
          return entry.entityName.toLowerCase().contains(searchQuery) ||
              entry.reference.toLowerCase().contains(searchQuery);
        }

        return true;
      }).toList();
    });
  }

  Widget _buildSummaryCards() {
    final totalMoneyOut = _filteredEntries.fold<double>(
      0,
      (sum, e) => sum + e.moneyOut,
    );
    final totalMoneyIn = _filteredEntries.fold<double>(
      0,
      (sum, e) => sum + e.moneyIn,
    );
    final netCashFlow = totalMoneyIn - totalMoneyOut;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              'Money Out',
              'Rs ${totalMoneyOut.toStringAsFixed(2)}',
              Colors.red.shade100,
              Icons.arrow_upward,
              'Supplier Payments',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _summaryCard(
              'Money In',
              'Rs ${totalMoneyIn.toStringAsFixed(2)}',
              Colors.green.shade100,
              Icons.arrow_downward,
              'Customer Payments',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _summaryCard(
              'Net Cash Flow',
              'Rs ${netCashFlow.toStringAsFixed(2)}',
              netCashFlow >= 0 ? Colors.blue.shade100 : Colors.orange.shade100,
              netCashFlow >= 0 ? Icons.trending_up : Icons.trending_down,
              netCashFlow >= 0 ? 'Positive' : 'Negative',
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    Color color,
    IconData icon,
    String subtitle,
  ) {
    return Card(
      color: color,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_filteredEntries.isEmpty) return const SizedBox.shrink();

    // Group by date
    final Map<DateTime, double> dailyNet = {};
    // Sort ascending for chart
    final sorted = List<CombinedPaymentEntry>.from(_filteredEntries);
    sorted.sort((a, b) => a.date.compareTo(b.date));

    for (var e in sorted) {
      final date = DateTime(e.date.year, e.date.month, e.date.day);
      dailyNet[date] = (dailyNet[date] ?? 0) + (e.moneyIn - e.moneyOut);
    }

    final spots = dailyNet.entries.map((e) {
      return FlSpot(e.key.millisecondsSinceEpoch.toDouble(), e.value);
    }).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final date = DateTime.fromMillisecondsSinceEpoch(
                    value.toInt(),
                  );
                  return Text(
                    DateFormat('MM/dd').format(date),
                    style: const TextStyle(fontSize: 10),
                  );
                },
                interval: 86400000 * 5, // ~5 days
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            // Type filter
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<PaymentType>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Payment Type',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: PaymentType.all,
                    child: Text('All Payments'),
                  ),
                  DropdownMenuItem(
                    value: PaymentType.suppliers,
                    child: Text('Suppliers Only'),
                  ),
                  DropdownMenuItem(
                    value: PaymentType.customers,
                    child: Text('Customers Only'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedType = value!);
                  _applyFilters();
                },
              ),
            ),
            // Search
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search',
                  hintText: 'Name or reference',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                ),
                onChanged: (_) => _applyFilters(),
              ),
            ),
            // Date range
            SizedBox(
              width: 250,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(
                  _startDate == null && _endDate == null
                      ? 'Select Date Range'
                      : '${_startDate != null ? DateFormat('dd/MM/yy').format(_startDate!) : ''} - ${_endDate != null ? DateFormat('dd/MM/yy').format(_endDate!) : ''}',
                ),
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _startDate != null && _endDate != null
                        ? DateTimeRange(start: _startDate!, end: _endDate!)
                        : null,
                  );
                  if (range != null) {
                    setState(() {
                      _startDate = range.start;
                      _endDate = range.end;
                    });
                    _applyFilters();
                  }
                },
              ),
            ),
            // Clear date filter
            if (_startDate != null || _endDate != null)
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear date filter',
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                  _applyFilters();
                },
              ),

            // Export Button
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("Export PDF"),
              onPressed: () async {
                await _exportService.exportCombinedCashFlowPdf(
                  _filteredEntries,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allEntries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No payment records found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final dateFmt = DateFormat('dd/MM/yyyy');

    return Column(
      children: [
        _buildSummaryCards(),
        _buildChart(),
        const SizedBox(height: 8),
        _buildFilters(),
        const SizedBox(height: 16),
        // Data Table
        Expanded(
          child: _filteredEntries.isEmpty
              ? const Center(
                  child: Text(
                    'No records match your filters',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Colors.grey.shade200,
                      ),
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Date',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Type',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Name',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Description',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Reference',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Money Out',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Money In',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Net Cash Flow',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: _buildTableRows(dateFmt),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  List<DataRow> _buildTableRows(DateFormat dateFmt) {
    double runningCashFlow = 0;
    return _filteredEntries.map((entry) {
      runningCashFlow += (entry.moneyIn - entry.moneyOut);

      return DataRow(
        color: WidgetStateProperty.all(
          entry.type == 'customer' ? Colors.green.shade50 : Colors.red.shade50,
        ),
        cells: [
          DataCell(Text(dateFmt.format(entry.date))),
          DataCell(
            Chip(
              label: Text(
                entry.type == 'customer' ? 'Customer' : 'Supplier',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: entry.type == 'customer'
                  ? Colors.green.shade200
                  : Colors.red.shade200,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            ),
          ),
          DataCell(Text(entry.entityName)),
          DataCell(Text(entry.description)),
          DataCell(Text(entry.reference.isEmpty ? '-' : entry.reference)),
          DataCell(
            Text(
              entry.moneyOut > 0
                  ? 'Rs ${entry.moneyOut.toStringAsFixed(2)}'
                  : '-',
              style: TextStyle(
                color: entry.moneyOut > 0 ? Colors.red.shade700 : Colors.grey,
                fontWeight: entry.moneyOut > 0
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          DataCell(
            Text(
              entry.moneyIn > 0
                  ? 'Rs ${entry.moneyIn.toStringAsFixed(2)}'
                  : '-',
              style: TextStyle(
                color: entry.moneyIn > 0 ? Colors.green.shade700 : Colors.grey,
                fontWeight: entry.moneyIn > 0
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          DataCell(
            Text(
              'Rs ${runningCashFlow.toStringAsFixed(2)}',
              style: TextStyle(
                color: runningCashFlow >= 0
                    ? Colors.blue.shade700
                    : Colors.orange.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }).toList();
  }
}

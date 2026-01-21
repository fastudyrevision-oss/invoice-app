import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../repositories/stock_repo.dart';
import '../../models/stock_report_model.dart';
import '../../services/stock_export_service.dart';
import '../../services/chart_service.dart';
import '../../services/file_print_service.dart'; // 🆕 Add this helper (handles file_picker + print)
import 'stock_filter_dialog.dart';
import '../../utils/responsive_utils.dart';

class StockReportFrame extends StatefulWidget {
  const StockReportFrame({super.key});

  @override
  State<StockReportFrame> createState() => _StockReportFrameState();
}

class _StockReportFrameState extends State<StockReportFrame> {
  final StockRepository _repo = StockRepository();
  final StockExportService _exportService = StockExportService();
  final ChartService _chartService = ChartService();
  final FilePrintService _printService = FilePrintService(); // 🆕

  List<StockReport> _report = [];
  List<StockReport> _filteredReport = [];
  bool _loading = true;
  String? _error; // 🆕 Error state
  bool _includePrice = true;
  bool _onlyLowStock = false;
  bool _showExpiry = false;
  bool _detailedView = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // 🆕 Summary values
  double _totalCost = 0;
  double _totalSell = 0;
  double _totalProfit = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null; // Clear previous errors
    });

    try {
      List<StockReport> data;
      if (_onlyLowStock) {
        data = await _repo.getLowStockReport();
      } else {
        data = await _repo.getStockReport();
      }

      final summary = await _repo.getStockSummary();

      setState(() {
        _report = data;
        _filteredReport = data;
        _totalCost = summary['totalCostValue'] ?? 0;
        _totalSell = summary['totalSellValue'] ?? 0;
        _totalProfit = summary['totalProfit'] ?? 0;
        _loading = false;
        _error = null;
      });
    } catch (e, stackTrace) {
      debugPrint("❌ Error loading stock report: $e");
      debugPrint("Stack trace: $stackTrace");

      setState(() {
        _loading = false;
        _error = e.toString().contains('json_each')
            ? 'Database compatibility issue detected. Please contact support.'
            : 'Failed to load stock report. Please try again.';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error!),
            action: SnackBarAction(label: 'Retry', onPressed: _loadReport),
          ),
        );
      }
    }
  }

  void _openFilterDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => StockFilterDialog(
        includePrice: _includePrice,
        onlyLowStock: _onlyLowStock,
        showExpiry: _showExpiry,
        detailedView: _detailedView,
      ),
    );

    if (result != null) {
      setState(() {
        _includePrice = result['includePrice'];
        _onlyLowStock = result['onlyLowStock'];
        _showExpiry = result['showExpiry'];
        _detailedView = result['detailedView'];
      });
      _loadReport();
    }
  }

  // Enhanced Summary widget with modern design
  Widget _buildSummaryCard(bool isMobile) {
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            _modernSummaryCard(
              title: "Total Cost",
              value: _totalCost,
              icon: Icons.shopping_cart,
              gradientColors: [Colors.blue.shade400, Colors.blue.shade600],
            ),
            const SizedBox(height: 12),
            _modernSummaryCard(
              title: "Total Sell Value",
              value: _totalSell,
              icon: Icons.attach_money,
              gradientColors: [Colors.orange.shade400, Colors.orange.shade600],
            ),
            const SizedBox(height: 12),
            _modernSummaryCard(
              title: "Profit",
              value: _totalProfit,
              icon: Icons.trending_up,
              gradientColors: [Colors.green.shade400, Colors.green.shade600],
              isProfit: true,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: _modernSummaryCard(
              title: "Total Cost",
              value: _totalCost,
              icon: Icons.shopping_cart,
              gradientColors: [Colors.blue.shade400, Colors.blue.shade600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _modernSummaryCard(
              title: "Total Sell Value",
              value: _totalSell,
              icon: Icons.attach_money,
              gradientColors: [Colors.orange.shade400, Colors.orange.shade600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _modernSummaryCard(
              title: "Profit",
              value: _totalProfit,
              icon: Icons.trending_up,
              gradientColors: [Colors.green.shade400, Colors.green.shade600],
              isProfit: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernSummaryCard({
    required String title,
    required double value,
    required IconData icon,
    required List<Color> gradientColors,
    bool isProfit = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors[1].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white.withOpacity(0.9), size: 32),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isProfit ? Icons.arrow_upward : Icons.inventory,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Rs ${value.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _filterReport(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredReport = _report;
      } else {
        _filteredReport = _report.where((item) {
          return item.productName.toLowerCase().contains(query.toLowerCase()) ||
              (item.batchNo?.toLowerCase().contains(query.toLowerCase()) ??
                  false) ||
              (item.supplierName?.toLowerCase().contains(query.toLowerCase()) ??
                  false);
        }).toList();
      }
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by product, batch, or supplier...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterReport('');
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        onChanged: _filterReport,
      ),
    );
  }

  Widget _buildDataTable() {
    if (_filteredReport.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? "No data available" : "No results found",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final columns = <String>[
      'Product',
      'Batch', // ✅ NEW COLUMN
      'Purchased',

      'Sold',
      'Remaining',
      if (_showExpiry) 'Supplier',
      if (_showExpiry) 'Company',
      if (_showExpiry) 'Expiry',
      if (_includePrice) 'Cost',
      if (_includePrice) 'Sell',
      if (_detailedView) 'Profit/Unit',
      if (_detailedView) 'Total Profit',
      if (_includePrice) 'Total Value',
      if (_detailedView) 'Reorder Level',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
        headingRowHeight: 56,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 56,
        columnSpacing: 20,
        horizontalMargin: 16,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        columns: columns
            .map(
              (col) => DataColumn(
                label: Text(
                  col,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            )
            .toList(),
        rows: _filteredReport.asMap().entries.map((entry) {
          final index = entry.key;
          final r = entry.value;
          final isLow =
              r.reorderLevel != null &&
              r.reorderLevel! > 0 &&
              r.remainingQty <= r.reorderLevel!;
          final rowColor = isLow
              ? Colors.red.shade50
              : (index % 2 == 0 ? Colors.white : Colors.grey.shade50);

          return DataRow(
            color: WidgetStateProperty.all(rowColor),
            cells: [
              DataCell(
                Row(
                  children: [
                    if (isLow)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        r.productName,
                        style: TextStyle(
                          color: isLow ? Colors.red.shade900 : Colors.black87,
                          fontWeight: isLow ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(Text(r.batchNo ?? '-')), // ✅ NEW DATA CELL for Batch No
              DataCell(Text(r.purchasedQty.toString())),
              DataCell(Text(r.soldQty.toString())),
              DataCell(Text(r.remainingQty.toString())),
              if (_showExpiry) DataCell(Text(r.supplierName ?? "-")),
              if (_showExpiry) DataCell(Text(r.companyName ?? "-")), // NEW
              if (_showExpiry)
                DataCell(
                  Text(
                    r.expiryDate != null
                        ? "${r.expiryDate!.toLocal()}".split(' ')[0]
                        : "-",
                  ),
                ),
              if (_includePrice) DataCell(Text(r.costPrice.toStringAsFixed(2))),
              if (_includePrice) DataCell(Text(r.sellPrice.toStringAsFixed(2))),
              if (_detailedView)
                DataCell(Text(r.profitPerUnit.toStringAsFixed(2))),
              if (_detailedView)
                DataCell(Text(r.profitValue.toStringAsFixed(2))),
              if (_includePrice)
                DataCell(Text(r.totalSellValue.toStringAsFixed(2))),
              if (_detailedView)
                DataCell(Text(r.reorderLevel?.toString() ?? "-")),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChart() {
    final chartData = _chartService.getBarChartData(
      _report,
      detailedView: _detailedView,
      onlyLowStock: _onlyLowStock,
    );

    if (chartData.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Stock Overview",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= chartData.length) {
                            return const SizedBox();
                          }
                          return Transform.rotate(
                            angle: -0.8,
                            child: Text(
                              chartData[value.toInt()]['name'],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: chartData.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: (e['remaining'] ?? 0).toDouble(),
                          width: 20,
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade300,
                              Colors.blue.shade600,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopButtons() {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 10,
      children: [
        ElevatedButton.icon(
          onPressed: _openFilterDialog,
          icon: const Icon(Icons.filter_list),
          label: const Text("Filters"),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () => _exportService.exportToPDF(
            _filteredReport, // Use filtered data
            includePrice: _includePrice,
            showExpiry: _showExpiry,
            detailedView: _detailedView,
          ),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text("Export PDF"),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () => _exportService.exportToExcel(
            _filteredReport, // Use filtered data
            includePrice: _includePrice,
            showExpiry: _showExpiry,
            detailedView: _detailedView,
          ),
          icon: const Icon(Icons.table_chart),
          label: const Text("Export Excel"),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () => _printService.printStockReport(
            _filteredReport,
          ), // Use filtered data
          icon: const Icon(Icons.print),
          label: const Text("Print"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stock Report"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReport),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = ResponsiveUtils.isMobile(context);

          return _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error Loading Stock Report',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadReport,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildTopButtons(),
                      const SizedBox(height: 16),
                      _buildSummaryCard(isMobile),
                      _buildSearchBar(),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Column(
                            children: [_buildDataTable(), _buildChart()],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../repositories/stock_repo.dart';
import '../../models/stock_report_model.dart';
import '../../services/stock_export_service.dart';
import '../../services/chart_service.dart';
import '../../services/file_print_service.dart'; // 🆕 Add this helper (handles file_picker + print)
import 'stock_filter_dialog.dart';

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
  bool _loading = true;
  bool _includePrice = true;
  bool _onlyLowStock = false;
  bool _showExpiry = false;
  bool _detailedView = false;

  // 🆕 Summary values
  double _totalCost = 0;
  double _totalSell = 0;
  double _totalProfit = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);

    List<StockReport> data;
    if (_onlyLowStock) {
      data = await _repo.getLowStockReport();
    } else {
      data = await _repo.getStockReport();
    }

    final summary = await _repo.getStockSummary();

    setState(() {
      _report = data;
      _totalCost = summary['totalCostValue'] ?? 0;
      _totalSell = summary['totalSellValue'] ?? 0;
      _totalProfit = summary['totalProfit'] ?? 0;
      _loading = false;
    });
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

  // 🆕 Summary widget
  Widget _buildSummaryCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey.shade100,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryTile("Total Cost", _totalCost),
            _summaryTile("Total Sell", _totalSell),
            _summaryTile("Profit", _totalProfit, isProfit: true),
          ],
        ),
      ),
    );
  }

  Widget _summaryTile(String label, double value, {bool isProfit = false}) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: Colors.black54)),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isProfit ? Colors.green.shade700 : Colors.blueGrey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable() {
    if (_report.isEmpty) {
      return const Center(child: Text("No data available"));
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
        headingRowColor: WidgetStateProperty.all(Colors.grey.shade300),
        columnSpacing: 24,
        columns: columns
            .map(
              (col) => DataColumn(
                label: Text(
                  col,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )
            .toList(),
        rows: _report.map((r) {
          final isLow = r.reorderLevel != null &&
              r.reorderLevel! > 0 &&
              r.remainingQty <= r.reorderLevel!;
          final rowColor = isLow ? Colors.red.shade50 : Colors.white;

          return DataRow(
            color: WidgetStateProperty.all(rowColor),
            cells: [
              DataCell(Text(
                r.productName,
                style: TextStyle(
                  color: isLow ? Colors.red : Colors.black,
                  fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
                ),
              )),
              DataCell(Text(r.batchNo ?? '-')), // ✅ NEW DATA CELL for Batch No
              DataCell(Text(r.purchasedQty.toString())),
              DataCell(Text(r.soldQty.toString())),
              DataCell(Text(r.remainingQty.toString())),
              if (_showExpiry)
                DataCell(Text(r.supplierName ?? "-")),
              if (_showExpiry)
                DataCell(Text(r.companyName ?? "-")),  // NEW
              if (_showExpiry)
                DataCell(Text(r.expiryDate != null
                    ? "${r.expiryDate!.toLocal()}".split(' ')[0]
                    : "-")),
              if (_includePrice)
                DataCell(Text(r.costPrice.toStringAsFixed(2))),
              if (_includePrice)
                DataCell(Text(r.sellPrice.toStringAsFixed(2))),
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
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: (e['remaining'] ?? 0).toDouble(),
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ]);
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: _openFilterDialog,
          icon: const Icon(Icons.filter_list),
          label: const Text("Filters"),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () => _exportService.exportToPDF(
            _report,
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
            _report,
            includePrice: _includePrice,
            showExpiry: _showExpiry,
            detailedView: _detailedView,
          ),
          icon: const Icon(Icons.table_chart),
          label: const Text("Export Excel"),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () => _printService.printStockReport(_report),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTopButtons(),
                  const SizedBox(height: 16),
                  _buildSummaryCard(),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        children: [
                          _buildDataTable(),
                          _buildChart(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

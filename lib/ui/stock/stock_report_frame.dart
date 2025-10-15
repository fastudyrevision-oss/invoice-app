import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../repositories/stock_repo.dart' as repo;
import '../../models/stock_report_model.dart';
import '../../services/stock_export_service.dart' as svc;
import '../../services/chart_service.dart';
import 'stock_filter_dialog.dart';

class StockReportFrame extends StatefulWidget {
  const StockReportFrame({super.key});

  @override
  State<StockReportFrame> createState() => _StockReportFrameState();
}

class _StockReportFrameState extends State<StockReportFrame> {
  final repo.StockRepository _repo = repo.StockRepository();
  final svc.StockExportService _exportService = svc.StockExportService();
  final ChartService _chartService = ChartService();

  List<StockReport> _report = [];
  bool _loading = true;
  bool _includePrice = true;
  bool _onlyLowStock = false;
  bool _showExpiry = false;
  bool _detailedView = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    final data = await _repo.fetchStockReport(
      includePrice: _includePrice,
      onlyLowStock: _onlyLowStock,
    );
    setState(() {
      _report = data;
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

  Widget _buildDataTable() {
    if (_report.isEmpty) {
      return const Center(child: Text("No data available"));
    }

    final columns = [
      'Product',
      'Purchased',
      'Sold',
      'Remaining',
      if (_includePrice) 'Cost',
      if (_includePrice) 'Sell',
      if (_includePrice) 'Total Value',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.grey.shade300),
        columns: columns
            .map((col) => DataColumn(
                  label: Text(
                    col,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ))
            .toList(),
        rows: _report.map((r) {
          return DataRow(cells: [
            DataCell(Text(r.productName)),
            DataCell(Text(r.purchasedQty.toString())),
            DataCell(Text(r.soldQty.toString())),
            DataCell(Text(r.remainingQty.toString())),
            if (_includePrice)
              DataCell(Text(r.costPrice.toStringAsFixed(2))),
            if (_includePrice)
              DataCell(Text(r.sellPrice.toStringAsFixed(2))),
            if (_includePrice)
              DataCell(Text(r.totalValue.toStringAsFixed(2))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildChart() {
    final chartData = _chartService.getBarChartData(_report);
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
                    leftTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: true)),
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
          onPressed: () => _exportService.exportToPDF(_report),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text("Export PDF"),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Implement Excel export
          },
          icon: const Icon(Icons.table_chart),
          label: const Text("Export Excel"),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Implement POS printing
          },
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
                  // ✅ Entire table + chart scroll both ways
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

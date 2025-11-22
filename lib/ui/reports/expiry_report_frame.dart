import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:invoice_app/repositories/report_repository.dart';
import 'package:invoice_app/models/reports/expiry_report.dart';
import 'package:intl/intl.dart';
import 'package:invoice_app/services/report_export_service.dart';

class ExpiryReportFrame extends StatefulWidget {
  const ExpiryReportFrame({super.key});

  @override
  State<ExpiryReportFrame> createState() => _ExpiryReportFrameState();
}

class _ExpiryReportFrameState extends State<ExpiryReportFrame> {
  final repo = ReportRepository();
  final _exportReportService = ReportExportService();
  late Future<List<ExpiryReport>> _futureReports;

  @override
  void initState() {
    super.initState();
    _futureReports = repo.getExpiryReports();
  }

  Future<void> _exportToPdf(List<ExpiryReport> reports) async {
    await _exportReportService.exportExpiryReportPdf(reports);
  }

  Future<void> _exportToExcel(List<ExpiryReport> reports) async {
    await _exportReportService.exportExpiryReportExcel(reports);
  }

  Future<void> _printReports(List<ExpiryReport> reports) async {
    // TODO: Implement printing logic
    debugPrint("Sending ${reports.length} reports to printer...");
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ExpiryReport>>(
      future: _futureReports,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No expiring products found."));
        }

        final reports = snapshot.data!;
        final dateFmt = DateFormat('yyyy-MM-dd');

        return Column(
          children: [
            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _exportToPdf(reports),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("Export PDF"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _exportToExcel(reports),
                    icon: const Icon(Icons.table_chart),
                    label: const Text("Export Excel"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _printReports(reports),
                    icon: const Icon(Icons.print),
                    label: const Text("Print"),
                  ),
                ],
              ),
            ),

            // Chart
            Expanded(
              flex: 1,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) =>
                            Text(value.toInt().toString()),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= reports.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            reports[index].productName,
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: reports.asMap().entries.map((entry) {
                    final i = entry.key;
                    final r = entry.value;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: r.qty.toDouble(),
                          color: Colors.redAccent,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),

            // List
            Expanded(
              flex: 1,
              child: ListView.builder(
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final r = reports[index];
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text(r.productName),
                      subtitle: Text(
                        "Batch: ${r.batchNo} | Expiry: ${dateFmt.format(r.expiryDate)}",
                      ),
                      trailing: Text("Qty: ${r.qty}"),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

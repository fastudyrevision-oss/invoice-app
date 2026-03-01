import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:invoice_app/repositories/report_repository.dart';
import 'package:invoice_app/models/reports/expiry_report.dart';
import 'package:intl/intl.dart';
import 'package:invoice_app/services/report_export_service.dart';
import '../../services/logger_service.dart';

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

  Future<void> _exportToExcel(List<ExpiryReport> reports) async {
    await _exportReportService.exportExpiryReportExcel(reports);
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
                    onPressed: () => _exportToExcel(reports),
                    icon: const Icon(Icons.table_chart),
                    label: const Text("Excel"),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.print, color: Colors.blue),
                    tooltip: "Print Report",
                    onPressed: () async {
                      try {
                        logger.info(
                          'ExpiryReportFrame',
                          'Printing expiry report',
                        );
                        await _exportReportService.printExpiryReport(reports);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Sent to printer'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Print error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          logger.error(
                            'ExpiryReportFrame',
                            'Print error',
                            error: e,
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.save, color: Colors.green),
                    tooltip: "Save PDF",
                    onPressed: () async {
                      try {
                        logger.info(
                          'ExpiryReportFrame',
                          'Saving expiry report PDF',
                        );
                        final file = await _exportReportService
                            .saveExpiryReportPdf(reports);
                        if (context.mounted && file != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Saved: ${file.path}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Save error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          logger.error(
                            'ExpiryReportFrame',
                            'Save PDF error',
                            error: e,
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.orange),
                    tooltip: "Share PDF",
                    onPressed: () async {
                      logger.info(
                        'ExpiryReportFrame',
                        'Sharing expiry report PDF',
                      );
                      await _exportReportService.exportExpiryReportPdf(reports);
                    },
                  ),
                ],
              ),
            ),

            // Chart
            SizedBox(
              height: 250,
              child: Padding(
                padding: const EdgeInsets.only(top: 20, right: 16),
                child: RepaintBoundary(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width:
                          reports.length * 60.0 >
                              MediaQuery.of(context).size.width
                          ? reports.length * 60.0
                          : MediaQuery.of(context).size.width,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY:
                              reports
                                  .map((e) => e.qty.toDouble())
                                  .reduce((a, b) => a > b ? a : b) *
                              1.2,
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) => Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 10),
                                ),
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
                                  final name = reports[index].productName;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Transform.rotate(
                                      angle: -0.5,
                                      child: Text(
                                        name.length > 10
                                            ? "${name.substring(0, 8)}..."
                                            : name,
                                        style: const TextStyle(fontSize: 9),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey.withValues(alpha: 0.1),
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: reports.asMap().entries.map((entry) {
                            final i = entry.key;
                            final r = entry.value;
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: r.qty.toDouble(),
                                  color: Colors.redAccent,
                                  width: 16,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
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

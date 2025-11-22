import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:invoice_app/repositories/report_repository.dart';
import 'package:invoice_app/models/reports/supplier_report.dart';

class SupplierReportFrame extends StatefulWidget {
  const SupplierReportFrame({super.key});

  @override
  State<SupplierReportFrame> createState() => _SupplierReportFrameState();
}

class _SupplierReportFrameState extends State<SupplierReportFrame> {
  final repo = ReportRepository();
  late Future<List<SupplierReport>> _futureReports;

  @override
  void initState() {
    super.initState();
    _futureReports = repo.getSupplierReports();
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return "${(value / 1000000).toStringAsFixed(1)}M";
    } else if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}k";
    } else {
      return value.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SupplierReport>>(
      future: _futureReports,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!;
        if (reports.isEmpty) {
          return const Center(child: Text("No supplier reports found."));
        }

        // --- Safe interval calculation ---
        final maxPurchase = reports
            .map((e) => e.totalPurchases)
            .fold<double>(0, (prev, elem) => elem > prev ? elem : elem);

        final interval = maxPurchase > 0
            ? (maxPurchase / 5).ceilToDouble()
            : 1.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Supplier Report",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // --- Data List ---
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final r = reports[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(r.supplierName),
                      subtitle: Text(
                        "Purchases: ${r.totalPurchases}, Paid: ${r.totalPaid}",
                      ),
                      trailing: Text("Balance: ${r.balance}"),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // --- Chart ---
              SizedBox(
                height: 300,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              _formatNumber(value),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                          interval: interval, // use safe interval
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < reports.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  reports[index].supplierName,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }
                            return const Text("");
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
                    barGroups: reports.asMap().entries.map((entry) {
                      final index = entry.key;
                      final r = entry.value;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: r.totalPurchases.toDouble(),
                            color: Colors.blue,
                            width: 14,
                          ),
                          BarChartRodData(
                            toY: r.totalPaid.toDouble(),
                            color: Colors.green,
                            width: 14,
                          ),
                        ],
                        barsSpace: 6,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

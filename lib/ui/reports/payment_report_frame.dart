import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:invoice_app/repositories/report_repository.dart';
import 'package:invoice_app/models/reports/payment_report.dart';
import 'package:intl/intl.dart';

class PaymentReportFrame extends StatefulWidget {
  const PaymentReportFrame({super.key});

  @override
  State<PaymentReportFrame> createState() => _PaymentReportFrameState();
}

class _PaymentReportFrameState extends State<PaymentReportFrame> {
  final repo = ReportRepository();
  late Future<List<PaymentReport>> _futureReports;

  @override
  void initState() {
    super.initState();
    _futureReports = repo.getPaymentReports();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PaymentReport>>(
      future: _futureReports,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!;
        if (reports.isEmpty) {
          return const Center(child: Text("No payment records found."));
        }

        final dateFmt = DateFormat('yyyy-MM-dd');

        return Column(
          children: [
            Expanded(
              flex: 1,
              child: LineChart(
                LineChartData(
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= reports.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            dateFmt.format(reports[index].date),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) =>
                            Text(value.toInt().toString()),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: Colors.blue,
                      spots: reports.asMap().entries.map((entry) {
                        final i = entry.key;
                        final r = entry.value;
                        return FlSpot(i.toDouble(), r.debit);
                      }).toList(),
                      barWidth: 2,
                    ),
                    LineChartBarData(
                      isCurved: true,
                      color: Colors.green,
                      spots: reports.asMap().entries.map((entry) {
                        final i = entry.key;
                        final r = entry.value;
                        return FlSpot(i.toDouble(), r.credit);
                      }).toList(),
                      barWidth: 2,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: ListView.builder(
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final r = reports[index];
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text(r.supplierName),
                      subtitle: Text(
                        "Ref: ${r.reference} | Date: ${dateFmt.format(r.date)}",
                      ),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Debit: ${r.debit}"),
                          Text("Credit: ${r.credit}"),
                        ],
                      ),
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

import 'package:flutter/material.dart';
import 'package:invoice_app/repositories/report_repository.dart';
import 'package:invoice_app/models/reports/expense_report.dart';

class ExpenseReportFrame extends StatefulWidget {
  const ExpenseReportFrame({super.key});

  @override
  State<ExpenseReportFrame> createState() => _ExpenseReportFrameState();
}

class _ExpenseReportFrameState extends State<ExpenseReportFrame> {
  final repo = ReportRepository();
  late Future<List<ExpenseReport>> _futureReports;

  @override
  void initState() {
    super.initState();
    _futureReports = repo.getExpenseReports();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ExpenseReport>>(
      future: _futureReports,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!;
        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final r = reports[index];
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text(r.category),
                trailing: Text("Spent: ${r.totalSpent}"),
              ),
            );
          },
        );
      },
    );
  }
}

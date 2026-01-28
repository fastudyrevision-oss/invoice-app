import 'package:flutter/material.dart';
import 'package:invoice_app/repositories/report_repository.dart';
import 'package:invoice_app/services/report_export_service.dart';
import 'package:invoice_app/models/reports/expense_report.dart';

class ExpenseReportFrame extends StatefulWidget {
  const ExpenseReportFrame({super.key});

  @override
  State<ExpenseReportFrame> createState() => _ExpenseReportFrameState();
}

class _ExpenseReportFrameState extends State<ExpenseReportFrame> {
  final repo = ReportRepository();
  final _exportService = ReportExportService();
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
        if (reports.isEmpty) {
          return const Center(child: Text("No expense reports found."));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const Text(
                    "Expense Report",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Export Buttons
                  IconButton(
                    icon: const Icon(Icons.print, color: Colors.blue),
                    tooltip: "Print Report",
                    onPressed: () async {
                      try {
                        await _exportService.printExpenseReport(reports);
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
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.save, color: Colors.green),
                    tooltip: "Save PDF",
                    onPressed: () async {
                      try {
                        final file = await _exportService.saveExpenseReportPdf(
                          reports,
                        );
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
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.orange),
                    tooltip: "Share PDF",
                    onPressed: () async {
                      await _exportService.exportExpenseReportPdf(reports);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final r = reports[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      title: Text(r.category),
                      trailing: Text("Spent: ${r.totalSpent}"),
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

import 'package:flutter/material.dart';
import 'package:invoice_app/repositories/report_repository.dart';
import 'package:invoice_app/services/report_export_service.dart';
import 'package:invoice_app/models/reports/product_report.dart';

class ProductReportFrame extends StatefulWidget {
  const ProductReportFrame({super.key});

  @override
  State<ProductReportFrame> createState() => _ProductReportFrameState();
}

class _ProductReportFrameState extends State<ProductReportFrame> {
  final repo = ReportRepository();
  final _exportService = ReportExportService();
  late Future<List<ProductReport>> _futureReports;

  @override
  void initState() {
    super.initState();
    _futureReports = repo.getProductReports();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductReport>>(
      future: _futureReports,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Changed to const CircularProgressIndicator to fix lint? No, just keep simple
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!;
        if (reports.isEmpty) {
          return const Center(child: Text("No product reports found."));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const Text(
                    "Product Report",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Export Buttons
                  IconButton(
                    icon: const Icon(Icons.print, color: Colors.blue),
                    tooltip: "Print Report",
                    onPressed: () async {
                      try {
                        await _exportService.printProductReport(reports);
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
                        final file = await _exportService.saveProductReportPdf(
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
                      await _exportService.exportProductReportPdf(reports);
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
                      title: Text(r.productName),
                      subtitle: Text("Qty: ${r.totalQtyPurchased}"),
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

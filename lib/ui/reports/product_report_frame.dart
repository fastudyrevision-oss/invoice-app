import 'package:flutter/material.dart';
import 'package:invoice_app/repositories/report_repository.dart';
import 'package:invoice_app/models/reports/product_report.dart';

class ProductReportFrame extends StatefulWidget {
  const ProductReportFrame({super.key});

  @override
  State<ProductReportFrame> createState() => _ProductReportFrameState();
}

class _ProductReportFrameState extends State<ProductReportFrame> {
  final repo = ReportRepository();
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
                title: Text(r.productName),
                subtitle: Text("Qty: ${r.totalQtyPurchased}"),
                trailing: Text("Spent: ${r.totalSpent}"),
              ),
            );
          },
        );
      },
    );
  }
}

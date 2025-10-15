import 'package:flutter/material.dart';
import '../../repositories/supplier_repo.dart';
import '../../models/supplier_report.dart';

class SupplierReportFrame extends StatefulWidget {
  final SupplierRepository repo;
  const SupplierReportFrame({super.key, required this.repo});

  @override
  State<SupplierReportFrame> createState() => _SupplierReportFrameState();
}

class _SupplierReportFrameState extends State<SupplierReportFrame> {
  late Future<List<SupplierReport>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  void _loadReports() {
    setState(() {
      _reportsFuture = widget.repo.getSupplierReports("2025-01-01", "2025-12-31");
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SupplierReport>>(
      future: _reportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No reports found."));
        }

        final reports = snapshot.data!;
        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final r = reports[index];
            return Card(
              child: ListTile(
                title: Text(r.supplierName),
                subtitle: Text("Company: ${r.companyName ?? '-'}"),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Purchases: ${r.totalPurchases.toStringAsFixed(2)}"),
                    Text("Paid: ${r.totalPaid.toStringAsFixed(2)}"),
                    Text("Pending: ${r.totalPending.toStringAsFixed(2)}",
                        style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

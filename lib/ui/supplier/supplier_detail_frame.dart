import 'package:flutter/material.dart';

import 'package:invoice_app/repositories/supplier_payment_repo.dart';
import '../../repositories/supplier_repo.dart';
import '../../models/supplier.dart';
import 'supplier_payment_frame.dart';

class SupplierDetailFrame extends StatelessWidget {
  final SupplierRepository repo;
  final SupplierPaymentRepository repo2;
  final Supplier supplier;

  const SupplierDetailFrame({
    super.key,
    required this.repo2,
    required this.repo,
    required this.supplier,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(supplier.name),
              bottom: const TabBar(
                tabs: [
                  Tab(text: "Info"),
                  Tab(text: "Payments"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildInfoTab(),
                SupplierPaymentFrame(repo: repo2, supplier: supplier),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("📞 Phone: ${supplier.phone ?? '-'}"),
          Text("🏢 Address: ${supplier.address ?? '-'}"),
          Text("👤 Contact: ${supplier.contactPerson ?? '-'}"),
          const SizedBox(height: 12),
          Text(
            "Pending: ${supplier.pendingAmount.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text("Credit Limit: ${supplier.creditLimit.toStringAsFixed(2)}"),
        ],
      ),
    );
  }
}

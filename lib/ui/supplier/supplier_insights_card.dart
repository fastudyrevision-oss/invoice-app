import 'package:flutter/material.dart';
import '../../models/supplier.dart';
import '../common/summary_insight_card.dart';

/// Supplier insights card displaying key metrics
class SupplierInsightsCard extends StatelessWidget {
  final List<Supplier> suppliers;
  final bool loading;
  final DateTime? lastUpdated;
  final int companiesCount;

  const SupplierInsightsCard({
    super.key,
    required this.suppliers,
    this.loading = false,
    this.lastUpdated,
    this.companiesCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate metrics (excluding deleted suppliers)
    final activeSuppliers = suppliers.where((s) => s.deleted != 1).toList();
    final totalSuppliers = activeSuppliers.length;
    final pendingSuppliers = activeSuppliers
        .where((s) => s.pendingAmount > 0)
        .length;
    final totalPending = activeSuppliers.fold<double>(
      0.0,
      (sum, s) => sum + s.pendingAmount,
    );

    final metrics = [
      InsightMetric(
        icon: Icons.store,
        label: 'Total',
        value: totalSuppliers.toString(),
        color: Colors.blue,
      ),
      InsightMetric(
        icon: Icons.pending_actions,
        label: 'Pending',
        value: pendingSuppliers.toString(),
        color: Colors.orange,
        subtitle: 'suppliers',
      ),
      InsightMetric(
        icon: Icons.currency_rupee,
        label: 'Amount',
        value: 'Rs ${totalPending.toStringAsFixed(0)}',
        color: Colors.red,
      ),
      InsightMetric(
        icon: Icons.business,
        label: 'Companies',
        value: companiesCount.toString(),
        color: Colors.purple,
      ),
    ];

    return SummaryInsightCard(
      title: 'Supplier Insights',
      metrics: metrics,
      loading: loading,
      lastUpdated: lastUpdated,
      expandedContent: _buildExpandedContent(activeSuppliers),
    );
  }

  Widget _buildExpandedContent(List<Supplier> activeSuppliers) {
    // Get top 5 suppliers by pending amount
    final sortedSuppliers = List<Supplier>.from(activeSuppliers)
      ..sort((a, b) => b.pendingAmount.compareTo(a.pendingAmount));
    final topSuppliers = sortedSuppliers.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top 5 Suppliers by Pending Amount',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        if (topSuppliers.isEmpty)
          const Text(
            'No suppliers available',
            style: TextStyle(color: Colors.grey),
          )
        else
          ...topSuppliers.where((s) => s.pendingAmount > 0).map((s) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(s.name, overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    'Rs ${s.pendingAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            );
          }),
        if (topSuppliers.every((s) => s.pendingAmount == 0))
          const Text(
            'All suppliers are paid up! 🎉',
            style: TextStyle(color: Colors.green),
          ),
      ],
    );
  }
}

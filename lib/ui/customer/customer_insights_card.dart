import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../common/summary_insight_card.dart';

/// Customer insights card displaying key metrics
class CustomerInsightsCard extends StatelessWidget {
  final List<Customer> customers;
  final bool loading;
  final DateTime? lastUpdated;

  const CustomerInsightsCard({
    super.key,
    required this.customers,
    this.loading = false,
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate metrics
    final totalCustomers = customers.length;
    final activeCustomers = customers.where((c) => c.pendingAmount > 0).length;
    final totalPending = customers.fold<double>(
      0.0,
      (sum, c) => sum + c.pendingAmount,
    );
    final avgPending = totalCustomers > 0 ? totalPending / totalCustomers : 0.0;

    final metrics = [
      InsightMetric(
        icon: Icons.people,
        label: 'Total',
        value: totalCustomers.toString(),
        color: Colors.blue,
      ),
      InsightMetric(
        icon: Icons.account_circle,
        label: 'Active',
        value: activeCustomers.toString(),
        color: Colors.green,
        subtitle: 'with pending',
      ),
      InsightMetric(
        icon: Icons.currency_rupee,
        label: 'Pending',
        value: 'Rs ${totalPending.toStringAsFixed(0)}',
        color: Colors.orange,
      ),
      InsightMetric(
        icon: Icons.trending_up,
        label: 'Avg/Customer',
        value: 'Rs ${avgPending.toStringAsFixed(0)}',
        color: Colors.purple,
      ),
    ];

    return SummaryInsightCard(
      title: 'Customer Insights',
      metrics: metrics,
      loading: loading,
      lastUpdated: lastUpdated,
      expandedContent: _buildExpandedContent(context),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    // Group customers by pending amount ranges
    final ranges = {
      '0': customers.where((c) => c.pendingAmount == 0).length,
      '1-1000': customers
          .where((c) => c.pendingAmount > 0 && c.pendingAmount <= 1000)
          .length,
      '1001-5000': customers
          .where((c) => c.pendingAmount > 1000 && c.pendingAmount <= 5000)
          .length,
      '5001+': customers.where((c) => c.pendingAmount > 5000).length,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customers by Pending Amount',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        ...ranges.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Rs ${e.key}:'),
                Text(
                  '${e.value} customers',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

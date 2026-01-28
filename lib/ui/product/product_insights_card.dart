import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../common/summary_insight_card.dart';

/// Product insights card displaying key metrics
class ProductInsightsCard extends StatelessWidget {
  final List<Product> products;
  final bool loading;
  final DateTime? lastUpdated;
  final int categoriesCount;
  final Map<String, dynamic>? stats;

  const ProductInsightsCard({
    super.key,
    required this.products,
    this.loading = false,
    this.lastUpdated,
    this.categoriesCount = 0,
    this.stats,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate metrics
    final totalProducts = stats?['totalProducts'] ?? products.length;
    final lowStockCount =
        stats?['lowStockCount'] ??
        products
            .where((p) => p.quantity <= p.minStock && p.minStock > 0)
            .length;
    final totalInventoryValue =
        (stats?['totalValue'] as num?)?.toDouble() ??
        products.fold<double>(
          0.0,
          (sum, p) => sum + (p.quantity * p.costPrice),
        );

    final metrics = [
      InsightMetric(
        icon: Icons.inventory_2,
        label: 'Total',
        value: totalProducts.toString(),
        color: Colors.blue,
      ),
      InsightMetric(
        icon: Icons.warning,
        label: 'Low Stock',
        value: lowStockCount.toString(),
        color: Colors.red,
      ),
      InsightMetric(
        icon: Icons.attach_money,
        label: 'Inventory',
        value: 'Rs ${totalInventoryValue.toStringAsFixed(0)}',
        color: Colors.green,
      ),
      InsightMetric(
        icon: Icons.category,
        label: 'Categories',
        value: categoriesCount.toString(),
        color: Colors.purple,
      ),
    ];

    return SummaryInsightCard(
      title: 'Product Insights',
      metrics: metrics,
      loading: loading,
      lastUpdated: lastUpdated,
      expandedContent: _buildExpandedContent(),
    );
  }

  Widget _buildExpandedContent() {
    // Get top 5 products by inventory value
    final sortedProducts = List<Product>.from(products)
      ..sort(
        (a, b) =>
            (b.quantity * b.costPrice).compareTo(a.quantity * a.costPrice),
      );
    final topProducts = sortedProducts.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top 5 Products by Value',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        if (topProducts.isEmpty)
          const Text(
            'No products available',
            style: TextStyle(color: Colors.grey),
          )
        else
          ...topProducts.map((p) {
            final value = p.quantity * p.costPrice;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    'Rs ${value.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

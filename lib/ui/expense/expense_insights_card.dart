import 'package:flutter/material.dart';
import '../../models/expense.dart';
import '../common/summary_insight_card.dart';

/// Expense insights card displaying key metrics
class ExpenseInsightsCard extends StatelessWidget {
  final List<Expense> expenses;
  final bool loading;
  final DateTime? lastUpdated;

  const ExpenseInsightsCard({
    super.key,
    required this.expenses,
    this.loading = false,
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate metrics
    final totalExpenses = expenses.length;
    final totalAmount = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);

    // This month's expenses
    final now = DateTime.now();
    final thisMonthExpenses = expenses.where((e) {
      final expenseDate = DateTime.parse(e.date);
      return expenseDate.year == now.year && expenseDate.month == now.month;
    }).toList();
    final thisMonthAmount = thisMonthExpenses.fold<double>(
      0.0,
      (sum, e) => sum + e.amount,
    );

    // Count unique categories
    final categories = expenses.map((e) => e.category).toSet();
    final categoriesCount = categories.length;

    // Average expense
    final avgExpense = totalExpenses > 0 ? totalAmount / totalExpenses : 0.0;

    final metrics = [
      InsightMetric(
        icon: Icons.receipt_long,
        label: 'Total',
        value: totalExpenses.toString(),
        color: Colors.blue,
      ),
      InsightMetric(
        icon: Icons.calendar_month,
        label: 'This Month',
        value: 'Rs ${thisMonthAmount.toStringAsFixed(0)}',
        color: Colors.orange,
      ),
      InsightMetric(
        icon: Icons.category,
        label: 'Categories',
        value: categoriesCount.toString(),
        color: Colors.purple,
      ),
      InsightMetric(
        icon: Icons.trending_up,
        label: 'Avg/Expense',
        value: 'Rs ${avgExpense.toStringAsFixed(0)}',
        color: Colors.green,
      ),
    ];

    return SummaryInsightCard(
      title: 'Expense Insights',
      metrics: metrics,
      loading: loading,
      lastUpdated: lastUpdated,
      expandedContent: _buildExpandedContent(categories, expenses),
    );
  }

  Widget _buildExpandedContent(Set<String> categories, List<Expense> expenses) {
    // Group expenses by category and calculate totals
    final categoryTotals = <String, double>{};
    for (final expense in expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0.0) + expense.amount;
    }

    // Sort by amount descending
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sortedCategories.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Expense Categories',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        if (topCategories.isEmpty)
          const Text(
            'No expenses available',
            style: TextStyle(color: Colors.grey),
          )
        else
          ...topCategories.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(entry.key, overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    'Rs ${entry.value.toStringAsFixed(0)}',
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

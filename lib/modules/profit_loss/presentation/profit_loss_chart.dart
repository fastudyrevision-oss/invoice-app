import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../utils/responsive_utils.dart';
import '../../../../ui/common/scrollable_chart_wrapper.dart'; // Import the wrapper

import '../data/models/category_profit.dart';
import '../data/models/product_profit.dart';
import '../data/models/supplier_profit.dart';
import '../data/models/profit_loss_model.dart';

/// ---------------------- SUMMARY BAR CHART ----------------------
class ProfitLossSummaryChart extends StatelessWidget {
  final ProfitLossModel data;
  final bool isCogsBased;

  const ProfitLossSummaryChart({
    required this.data,
    this.isCogsBased = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final costLabel = isCogsBased ? "COGS" : "Purchases";
    final costValue = isCogsBased
        ? data.totalPurchaseCost
        : data.totalPurchases;

    // Approximate Profit Calculation
    final profitValue = isCogsBased
        ? data.totalProfit
        : (data.totalProfit + data.totalPurchaseCost - data.totalPurchases);

    final bars = [
      _ChartData("Sales", data.totalSales.toDouble(), Colors.blue),
      _ChartData(costLabel, costValue.toDouble(), Colors.orange),
      _ChartData("Expenses", data.totalExpenses.toDouble(), Colors.redAccent),
      _ChartData("Profit", profitValue.toDouble(), Colors.green),
    ];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Income vs Expense Breakdown",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // Summary doesn't usually need scrolling as it's fixed 4 bars,
            // but we ensure it fits nicely.
            SizedBox(
              height: 280,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _calculateMaxY(bars) * 1.5,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (group) => Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          "${bars[group.x.toInt()].label}\n",
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: "Rs ${rod.toY.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.yellow,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox();
                          return Text(
                            _compactNumber(value),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _calculateInterval(bars),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: bars.asMap().entries.map((e) {
                    final index = e.key;
                    final item = e.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: item.value,
                          color: item.color,
                          width: 32, // Wider bars for summary
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: _calculateMaxY(bars) * 1.6,
                            color: Colors.grey.withValues(alpha: 0.05),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compactNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }

  double _calculateMaxY(List<_ChartData> bars) {
    double max = 0;
    for (var b in bars) {
      if (b.value > max) max = b.value;
    }
    return max == 0 ? 100 : max;
  }

  double _calculateInterval(List<_ChartData> bars) {
    final max = _calculateMaxY(bars);
    return max == 0 ? 20 : max / 5;
  }
}

class _ChartData {
  final String label;
  final double value;
  final Color color;
  _ChartData(this.label, this.value, this.color);
}

/// ---------------------- COMPACT CHART BASE ----------------------
class _ResponsiveChartBase extends StatelessWidget {
  final String title;
  final List<BarChartGroupData> barGroups;
  final List<String> labels;

  const _ResponsiveChartBase({
    required this.title,
    required this.barGroups,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: AspectRatio(
          aspectRatio: ResponsiveUtils.isMobile(context) ? 1.2 : 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                "Top ${labels.length} items",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              // Use Wrapper for horizontal scrolling
              Expanded(
                // Added Expanded to make ScrollableChartWrapper take available space
                child: ScrollableChartWrapper(
                  itemCount: barGroups.length,
                  minItemWidth: 60, // Ensure enough space per bar
                  height: 280,
                  child: BarChart(
                    BarChartData(
                      maxY: _calculateMaxY(),
                      alignment: BarChartAlignment.center, // or spaceBetween
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipColor: (group) => Colors.blueGrey,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              "${labels[group.x.toInt()]}\n",
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight
                                    .w500, // Changed to w500 for consistency
                                fontSize: 13,
                              ),
                              children: [
                                TextSpan(
                                  text: rod.toY.toStringAsFixed(1),
                                  style: const TextStyle(color: Colors.yellow),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: false,
                          ), // Clean look for sparklines
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: _calculateMaxY() / 4,
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: barGroups,
                      groupsSpace: 20, // Add explicit space
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateMaxY() {
    double max = 0;
    for (var group in barGroups) {
      for (var rod in group.barRods) {
        if (rod.toY > max) max = rod.toY;
      }
    }
    return max == 0 ? 100 : max * 1.6; // Further increased buffer for tooltips
  }
}

/// ---------------------- CATEGORY PROFIT CHART ----------------------
class CategoryProfitChart extends StatelessWidget {
  final List<CategoryProfit> categories;

  const CategoryProfitChart({required this.categories, super.key});

  @override
  Widget build(BuildContext context) {
    // INCREASE LIMIT to 20
    final displayList = categories.take(20).toList();

    return _ResponsiveChartBase(
      title: "Category Profit Performance",
      labels: displayList.map((e) => e.name).toList(),
      barGroups: displayList.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value.profit.toDouble() < 0
                  ? 0
                  : e.value.profit.toDouble(), // Handle negative visually?
              color: Colors.teal.shade400,
              width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

/// ---------------------- PRODUCT PROFIT CHART ----------------------
class ProductProfitChart extends StatelessWidget {
  final List<ProductProfit> products;

  const ProductProfitChart({required this.products, super.key});

  @override
  Widget build(BuildContext context) {
    // INCREASE LIMIT to 20
    final displayList = products.take(20).toList();

    return _ResponsiveChartBase(
      title: "Top Products by Profit",
      labels: displayList.map((e) => e.name).toList(),
      barGroups: displayList.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value.profit.toDouble() < 0
                  ? 0
                  : e.value.profit.toDouble(),
              color: Colors.indigo.shade400,
              width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

/// ---------------------- SUPPLIER PROFIT CHART ----------------------
class SupplierProfitChart extends StatelessWidget {
  final List<SupplierProfit> suppliers;

  const SupplierProfitChart({required this.suppliers, super.key});

  @override
  Widget build(BuildContext context) {
    // INCREASE LIMIT to 20
    final displayList = suppliers.take(20).toList();

    return _ResponsiveChartBase(
      title: "Top Suppliers (by Purchase Vol)",
      labels: displayList.map((e) => e.name).toList(),
      barGroups: displayList.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value.totalPurchases.toDouble(),
              color: Colors.purple.shade400,
              width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

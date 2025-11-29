import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

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
    // Data preparation
    final costLabel = isCogsBased ? "COGS" : "Purchases";
    final costValue = isCogsBased
        ? data.totalPurchaseCost
        : data.totalPurchases;

    // Profit calculation for chart
    // Note: Manual income is not explicitly in the model but is part of netProfit.
    // We assume netProfit = Sales - COGS - Expenses + ManualIncome
    // So ManualIncome = netProfit - Sales + COGS + Expenses
    // For Purchase mode: Profit = Sales - Purchases - Expenses + ManualIncome
    // We can approximate: Profit(Purchases) = Profit(COGS) + COGS - Purchases
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
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _calculateMaxY(bars),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
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
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < bars.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                bars[index].label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
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
                      color: Colors.grey.withOpacity(0.2),
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
                          width: 22,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: _calculateMaxY(bars) * 1.1,
                            color: Colors.grey.withOpacity(0.1),
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

  double _calculateMaxY(List<_ChartData> bars) {
    double max = 0;
    for (var b in bars) {
      if (b.value > max) max = b.value;
    }
    return max == 0 ? 100 : max;
  }

  double _calculateInterval(List<_ChartData> bars) {
    final max = _calculateMaxY(bars);
    return max / 5;
  }
}

class _ChartData {
  final String label;
  final double value;
  final Color color;
  _ChartData(this.label, this.value, this.color);
}

/// ---------------------- COMPACT CHART BASE ----------------------
class _CompactChartBase extends StatelessWidget {
  final String title;
  final List<BarChartGroupData> barGroups;
  final List<String> labels;

  const _CompactChartBase({
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: BarChart(
                BarChartData(
                  maxY: _calculateMaxY(),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          "${labels[group.x.toInt()]}\n",
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < labels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                labels[index].length > 6
                                    ? "${labels[index].substring(0, 5)}..."
                                    : labels[index],
                                style: const TextStyle(fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                        reservedSize: 20,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
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
    return max == 0 ? 100 : max * 1.2; // 20% buffer
  }
}

/// ---------------------- CATEGORY PROFIT CHART ----------------------
class CategoryProfitChart extends StatelessWidget {
  final List<CategoryProfit> categories;

  const CategoryProfitChart({required this.categories, super.key});

  @override
  Widget build(BuildContext context) {
    // Limit to top 5 for compact view
    final displayList = categories.take(5).toList();

    return _CompactChartBase(
      title: "Top Categories",
      labels: displayList.map((e) => e.name).toList(),
      barGroups: displayList.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value.profit.toDouble(),
              color: Colors.teal,
              width: 12,
              borderRadius: BorderRadius.circular(4),
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
    // Limit to top 5
    final displayList = products.take(5).toList();

    return _CompactChartBase(
      title: "Top Products",
      labels: displayList.map((e) => e.name).toList(),
      barGroups: displayList.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value.profit.toDouble(),
              color: Colors.indigo,
              width: 12,
              borderRadius: BorderRadius.circular(4),
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
    // Limit to top 5
    final displayList = suppliers.take(5).toList();

    return _CompactChartBase(
      title: "Top Suppliers",
      labels: displayList.map((e) => e.name).toList(),
      barGroups: displayList.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value.totalPurchases.toDouble(),
              color: Colors.purple,
              width: 12,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }).toList(),
    );
  }
}

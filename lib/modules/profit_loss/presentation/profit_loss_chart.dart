import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/models/category_profit.dart';
import '../data/models/product_profit.dart';
import '../data/models/supplier_profit.dart';
import '../data/models/profit_loss_model.dart';

/// ---------------------- SUMMARY BAR CHART ----------------------
class ProfitLossSummaryChart extends StatelessWidget {
  final ProfitLossModel data; // <- change type here

  const ProfitLossSummaryChart({required this.data, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bars = [
      data.totalSales,
      data.totalPurchaseCost,
      data.totalProfit,
      data.totalExpenses,
      data.totalDiscounts,
    ];

    final labels = ["Sales", "COGS", "Profit", "Expenses", "Discounts"];

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Profit & Loss Breakdown",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < labels.length) {
                            return Text(labels[index]);
                          }
                          return Text("");
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    bars.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [BarChartRodData(toY: bars[index].toDouble(), width: 18)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// ---------------------- CATEGORY PROFIT CHART ----------------------
class CategoryProfitChart extends StatelessWidget {
  final List<CategoryProfit> categories;

  const CategoryProfitChart({required this.categories, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Category-wise Profit",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < categories.length) {
                            return Text(categories[index].name, textAlign: TextAlign.center);
                          }
                          return Text("");
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    categories.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                            toY: categories[index].profit.toDouble(), width: 16)
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------- PRODUCT PROFIT CHART ----------------------
class ProductProfitChart extends StatelessWidget {
  final List<ProductProfit> products;

  const ProductProfitChart({required this.products, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Product-wise Profit",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < products.length) {
                            return Text(products[index].name, textAlign: TextAlign.center);
                          }
                          return Text("");
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    products.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(toY: products[index].profit.toDouble(), width: 16)
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------- SUPPLIER PROFIT CHART ----------------------
class SupplierProfitChart extends StatelessWidget {
  final List<SupplierProfit> suppliers;

  const SupplierProfitChart({required this.suppliers, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Supplier Purchases & Pending",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < suppliers.length) {
                            return Text(suppliers[index].name, textAlign: TextAlign.center);
                          }
                          return Text("");
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    suppliers.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(toY: suppliers[index].totalPurchases.toDouble(), width: 16),
                        BarChartRodData(toY: suppliers[index].pendingToSupplier.toDouble(), width: 16, color: Colors.red),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

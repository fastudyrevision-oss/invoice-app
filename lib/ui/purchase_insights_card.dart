import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';

import '../../models/purchase.dart';
import 'purchase_pdf_export_helper.dart'; // create or reuse order helper

class PurchaseInsightCard extends StatefulWidget {
  final List<Purchase> purchases;
  final bool loading;
  final DateTime? lastUpdated;

  const PurchaseInsightCard({
    super.key,
    required this.purchases,
    required this.loading,
    required this.lastUpdated,
  });

  @override
  State<PurchaseInsightCard> createState() => _PurchaseInsightCardState();
}

class _PurchaseInsightCardState extends State<PurchaseInsightCard> {
  bool expanded = false;
  final GlobalKey chartKey = GlobalKey();

  double _safeDouble(num? n) => (n == null) ? 0.0 : n.toDouble();

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: const SizedBox(height: 88),
          ),
        ),
      );
    }

    final total = widget.purchases.length;
    final pendingCount = widget.purchases
        .where((p) => _safeDouble(p.pending) > 0)
        .length;
    final paidCount = total - pendingCount;

    final totalAmount = widget.purchases.fold<double>(
      0.0,
      (s, p) => s + _safeDouble(p.total),
    );

    final avgPurchase = total > 0 ? totalAmount / total : 0.0;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => expanded = !expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Header stats ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _insightItem(
                      Icons.shopping_cart,
                      "Total",
                      total.toString(),
                      Colors.blue,
                    ),
                    _insightItem(
                      Icons.pending_actions,
                      "Pending",
                      pendingCount.toString(),
                      Colors.orange,
                    ),
                    _insightItem(
                      Icons.check_circle,
                      "Paid",
                      paidCount.toString(),
                      Colors.green,
                    ),
                    _insightItem(
                      Icons.receipt_long,
                      "Amount",
                      totalAmount.toStringAsFixed(0),
                      Colors.purple,
                    ),
                  ],
                ),

                if (widget.lastUpdated != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "Last updated: ${DateFormat('dd MMM yyyy, hh:mm a').format(widget.lastUpdated!)}",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // --- Expandable Section ---
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    children: [
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      Text(
                        "Average Purchase: Rs ${avgPurchase.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // --- Chart area ---
                      RepaintBoundary(
                        key: chartKey,
                        child: SizedBox(
                          height: 180,
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  isCurved: true,
                                  color: Colors.blueAccent,
                                  spots: _buildPurchaseSpots(widget.purchases),
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.blueAccent.withOpacity(0.2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text("Export as PDF"),
                        onPressed: () async => await _exportChartToPdf(
                          chartKey,
                          total: total,
                          totalAmount: totalAmount,
                          avgPurchase: avgPurchase,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _insightItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  List<FlSpot> _buildPurchaseSpots(List<Purchase> purchases) {
    if (purchases.isEmpty) return [const FlSpot(0, 0)];

    final sorted = List<Purchase>.from(purchases)
      ..sort((a, b) => a.date.compareTo(b.date));

    return List.generate(
      sorted.length,
      (i) => FlSpot(i.toDouble(), _safeDouble(sorted[i].total)),
    );
  }

  Future<void> _exportChartToPdf(
    GlobalKey chartKey, {
    required int total,
    required double totalAmount,
    required double avgPurchase,
  }) async {
    try {
      final boundary =
          chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final pdfFile = await generatePurchasePdfWithChart(
        title: 'Purchase Insights Report',
        chartBytes: pngBytes,
        totalAmount: totalAmount,
        avgPurchase: avgPurchase,
      );

      if (pdfFile != null) {
        await shareOrPrintPdf(pdfFile);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ PDF saved: ${pdfFile.path}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to generate PDF')),
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

/// Reusable summary insight card component used across all modules
/// Provides consistent design for displaying metrics with optional expandable content
class SummaryInsightCard extends StatefulWidget {
  final List<InsightMetric> metrics;
  final DateTime? lastUpdated;
  final bool loading;
  final Widget? expandedContent; // Charts, details, etc.
  final VoidCallback? onExportPdf;
  final String title;

  const SummaryInsightCard({
    super.key,
    required this.metrics,
    this.lastUpdated,
    this.loading = false,
    this.expandedContent,
    this.onExportPdf,
    this.title = 'Insights',
  });

  @override
  State<SummaryInsightCard> createState() => _SummaryInsightCardState();
}

class _SummaryInsightCardState extends State<SummaryInsightCard> {
  bool _expanded = false;

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

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.expandedContent != null
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                if (widget.title.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.expandedContent != null)
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.grey,
                          ),
                      ],
                    ),
                  ),

                // Metrics row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: widget.metrics
                      .take(4) // Max 4 metrics for consistent layout
                      .map((metric) => _buildMetricItem(metric))
                      .toList(),
                ),

                // Last updated timestamp
                if (widget.lastUpdated != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Last updated: ${DateFormat('dd MMM yyyy, hh:mm a').format(widget.lastUpdated!)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Expandable content
                if (widget.expandedContent != null)
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    crossFadeState: _expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      children: [
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        widget.expandedContent!,
                        if (widget.onExportPdf != null) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Export as PDF'),
                            onPressed: widget.onExportPdf,
                          ),
                        ],
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

  Widget _buildMetricItem(InsightMetric metric) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: metric.color.withOpacity(0.1),
          child: Icon(metric.icon, color: metric.color),
        ),
        const SizedBox(height: 6),
        Text(
          metric.value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          metric.label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        if (metric.subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            metric.subtitle!,
            style: TextStyle(
              fontSize: 10,
              color: metric.subtitleColor ?? Colors.grey,
            ),
          ),
        ],
      ],
    );
  }
}

/// Metric data model for displaying in summary cards
class InsightMetric {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;
  final Color? subtitleColor;

  const InsightMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
    this.subtitleColor,
  });
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../repositories/stock_repo.dart';
import '../../models/stock_report_model.dart';
import '../../services/stock_export_service.dart';

import '../../services/chart_service.dart';
import '../../services/logger_service.dart';
import 'stock_filter_dialog.dart';
import '../../utils/responsive_utils.dart';

class StockReportFrame extends StatefulWidget {
  const StockReportFrame({super.key});

  @override
  State<StockReportFrame> createState() => _StockReportFrameState();
}

class _StockReportFrameState extends State<StockReportFrame> {
  final StockRepository _repo = StockRepository();
  final StockExportService _exportService = StockExportService();
  final ChartService _chartService = ChartService();

  List<StockReport> _report = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  // 🔢 Pagination
  int _currentPage = 0;
  final int _pageSize = 50;
  int _totalCount = 0;

  bool _includePrice = true;
  bool _onlyLowStock = false;
  bool _showExpiry = false;
  bool _detailedView = false;
  Map<String, Map<String, dynamic>> _abcData = {};
  List<StockReport> _topReports = []; // 🆕 Top products for chart

  // Use ValueNotifier for efficient updates without rebuilding the whole frame
  final ValueNotifier<int> _scrolledIndex = ValueNotifier<int>(-1);
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 🆕 Summary values
  double _totalCost = 0;
  double _totalSell = 0;
  double _totalProfit = 0;
  String? _abcFilter; // 🆕 Added ABC filter state

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _scrolledIndex.dispose(); // Dispose the ValueNotifier
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _error = null;
      _currentPage = 0;
      _report = [];
    });

    try {
      // 1. Load Summary (Optimized)
      final summary = await _repo.getStockSummary();

      // 2. Load Total Count for Pagination
      final count = await _repo.getStockTotalCount(
        searchQuery: _searchQuery,
        onlyLowStock: _onlyLowStock,
        abcFilter: _abcFilter,
      );

      // 3. Load First Page
      final data = await _repo.getPagedStockReport(
        limit: _pageSize,
        offset: 0,
        searchQuery: _searchQuery,
        onlyLowStock: _onlyLowStock,
        abcFilter: _abcFilter,
      );

      // 4. Load Rigid Statistics (SQL-Aggregated for stability)
      final abcStats = await _repo.getABCStatistics();

      // 5. Load Top Items for Chart
      final topItems = await _repo.getTopStockByQuantity(limit: 10);

      if (!mounted) return;
      setState(() {
        _totalCost = summary['totalCostValue'] ?? 0;
        _totalSell = summary['totalSellValue'] ?? 0;
        _totalProfit = summary['totalProfit'] ?? 0;
        _totalCount = count;
        _report = data;
        _abcData = abcStats;
        _topReports = topItems;
        _loading = false;
      });
    } catch (e, stackTrace) {
      if (mounted) _handleError(e, stackTrace);
    }
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore || (_currentPage + 1) * _pageSize >= _totalCount) return;

    setState(() => _loadingMore = true);

    try {
      _currentPage++;
      final newData = await _repo.getPagedStockReport(
        limit: _pageSize,
        offset: _currentPage * _pageSize,
        searchQuery: _searchQuery,
        onlyLowStock: _onlyLowStock,
        abcFilter: _abcFilter,
      );

      setState(() {
        _report.addAll(newData);
        _loadingMore = false;
      });
    } catch (e, stackTrace) {
      logger.error(
        'StockReportFrame',
        'Error loading next page',
        error: e,
        stackTrace: stackTrace,
      );
      setState(() => _loadingMore = false);
    }
  }

  void _handleError(Object e, StackTrace st) {
    logger.error(
      'StockReportFrame',
      'Error loading stock report',
      error: e,
      stackTrace: st,
    );
    setState(() {
      _loading = false;
      _error = 'Failed to load stock report. Please try again.';
    });
  }

  void _openFilterDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => StockFilterDialog(
        includePrice: _includePrice,
        onlyLowStock: _onlyLowStock,
        showExpiry: _showExpiry,
        detailedView: _detailedView,
      ),
    );

    if (result != null) {
      setState(() {
        _includePrice = result['includePrice'];
        _onlyLowStock = result['onlyLowStock'];
        _showExpiry = result['showExpiry'];
        _detailedView = result['detailedView'];
      });
      _loadInitialData();
    }
  }

  // Enhanced Summary widget with modern design
  Widget _buildSummaryCard(bool isMobile) {
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            _modernSummaryCard(
              title: "Total Cost",
              value: _totalCost,
              icon: Icons.shopping_cart,
              gradientColors: [Colors.blue.shade400, Colors.blue.shade600],
            ),
            const SizedBox(height: 12),
            _modernSummaryCard(
              title: "Total Sell Value",
              value: _totalSell,
              icon: Icons.attach_money,
              gradientColors: [Colors.orange.shade400, Colors.orange.shade600],
            ),
            const SizedBox(height: 12),
            _modernSummaryCard(
              title: "Expected Profit",
              value: _totalProfit,
              icon: Icons.trending_up,
              gradientColors: [Colors.green.shade400, Colors.green.shade600],
              isProfit: true,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: _modernSummaryCard(
              title: "Total Cost",
              value: _totalCost,
              icon: Icons.shopping_cart,
              gradientColors: [Colors.blue.shade400, Colors.blue.shade600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _modernSummaryCard(
              title: "Total Sell Value",
              value: _totalSell,
              icon: Icons.attach_money,
              gradientColors: [Colors.orange.shade400, Colors.orange.shade600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _modernSummaryCard(
              title: "Expected Profit",
              value: _totalProfit,
              icon: Icons.trending_up,
              gradientColors: [Colors.green.shade400, Colors.green.shade600],
              isProfit: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernSummaryCard({
    required String title,
    required double value,
    required IconData icon,
    required List<Color> gradientColors,
    bool isProfit = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            gradientColors[0].withValues(alpha: 0.8),
            gradientColors[1].withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors[1].withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Glass effect overlay
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: Colors.white, size: 24),
                      ),
                      if (isProfit)
                        const Icon(
                          Icons.trending_up,
                          color: Colors.white70,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Rs ${value.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _filterReport(String query) {
    _searchQuery = query;
    // Debounce search
    Future.delayed(const Duration(milliseconds: 500), () {
      if (query == _searchQuery) {
        _loadInitialData();
      }
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search 10,000+ products...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: const Icon(Icons.search, color: Colors.blue),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _filterReport('');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onChanged: _filterReport,
        ),
      ),
    );
  }

  Widget _buildSliverReportList() {
    if (_report.isEmpty && !_loading) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                "No products found",
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == _report.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }

          final r = _report[index];
          return _buildStockCard(r);
        }, childCount: _report.length + (_loadingMore ? 1 : 0)),
      ),
    );
  }

  Widget _buildStockCard(StockReport r) {
    final bool isLow =
        r.reorderLevel != null &&
        r.reorderLevel! > 0 &&
        r.remainingQty <= r.reorderLevel!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isLow ? Colors.red.shade100 : Colors.grey.shade100,
          width: 1,
        ),
      ),
      color: isLow ? Colors.red.shade50.withValues(alpha: 0.5) : Colors.white,
      child: ExpansionTile(
        key: PageStorageKey(r.productId + (r.batchNo ?? '')),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isLow ? Colors.red.shade100 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isLow ? Icons.warning_amber_rounded : Icons.inventory_2,
            color: isLow ? Colors.red : Colors.blue,
            size: 20,
          ),
        ),
        title: Text(
          r.productName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isLow ? Colors.red.shade900 : Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          "Stock: ${r.remainingQty} | Batch: ${r.batchNo ?? '-'}",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          constraints: const BoxConstraints(maxWidth: 80),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                child: Text(
                  "Rs ${r.remainingQty * r.sellPrice}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Text(
                "Value",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (r.companyName != null && r.companyName!.isNotEmpty)
                  _buildDetailRow("Company", r.companyName!),
                _buildDetailRow("Supplier", r.supplierName ?? "-"),
                _buildDetailRow("Cost Price", "Rs ${r.costPrice}"),
                _buildDetailRow(
                  "Total Cost",
                  "Rs ${r.remainingQty * r.costPrice}",
                ),
                _buildDetailRow(
                  "Profit Pot.",
                  "Rs ${(r.sellPrice - r.costPrice) * r.remainingQty}",
                ),
                if (r.expiryDate != null)
                  _buildDetailRow(
                    "Expiry",
                    r.expiryDate.toString().split(' ')[0],
                  ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        // Action: Navigate to edit or dispose
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text("Manage"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final barData = _chartService.getBarChartData(_topReports);
    final pieData = _chartService
        .getCategoryData(_topReports)
        .where((e) => (e['quantity'] ?? 0) > 0)
        .toList();

    if (barData.isEmpty && pieData.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 📊 Statistical Analytics Section
        const Padding(
          padding: EdgeInsets.only(top: 24, bottom: 8),
          child: Text(
            "Inventory Analytics",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),

        // 🏆 Top Stocks by Quantity (Expert Bar Chart)
        Card(
          margin: const EdgeInsets.only(top: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Top Stock Distribution",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Visualizing product volume against target levels",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 250,
                  child: RepaintBoundary(
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (() {
                          num maxVal = 100;
                          if (barData.isNotEmpty) {
                            maxVal = barData
                                .map((e) => e['remaining'] as num)
                                .reduce((a, b) => a > b ? a : b);
                          }
                          return (maxVal > 0 ? maxVal : 100) * 1.2;
                        })(),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) =>
                                Colors.blueAccent.withValues(alpha: 0.9),
                            tooltipRoundedRadius: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final item = barData[groupIndex];
                              return BarTooltipItem(
                                "${item['name']}\n",
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                children: [
                                  TextSpan(
                                    text: "Qty: ${item['remaining']}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.normal,
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
                                if (value.toInt() < 0 ||
                                    value.toInt() >= barData.length) {
                                  return const SizedBox();
                                }
                                final name = barData[value.toInt()]['name']
                                    .toString();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    name.length > 3
                                        ? name.substring(0, 3).toUpperCase()
                                        : name.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) => Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.shade200,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: barData.asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: (entry.value['remaining'] ?? 0).toDouble(),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade400,
                                    Colors.blue.shade700,
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                width: 18,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: (entry.value['purchased'] ?? 0)
                                      .toDouble(),
                                  color: Colors.grey.shade100,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 🥧 Segmented Analytics (Category & ABC)
        Row(
          children: [
            // Category Split (Pie Chart)
            if (pieData.isNotEmpty)
              Expanded(
                flex: 3,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          "Category Mix",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 150,
                          child: ValueListenableBuilder<int>(
                            valueListenable: _scrolledIndex,
                            builder: (context, touchedIndex, _) {
                              return RepaintBoundary(
                                child: PieChart(
                                  PieChartData(
                                    pieTouchData: PieTouchData(
                                      touchCallback:
                                          (FlTouchEvent event, response) {
                                            if (!mounted) return;

                                            if (response == null ||
                                                response.touchedSection ==
                                                    null ||
                                                !event
                                                    .isInterestedForInteractions) {
                                              if (touchedIndex != -1) {
                                                WidgetsBinding.instance
                                                    .addPostFrameCallback((_) {
                                                      if (mounted) {
                                                        _scrolledIndex.value =
                                                            -1;
                                                      }
                                                    });
                                              }
                                              return;
                                            }
                                            final newIndex = response
                                                .touchedSection!
                                                .touchedSectionIndex;

                                            if (touchedIndex != newIndex) {
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                    if (mounted) {
                                                      _scrolledIndex.value =
                                                          newIndex;
                                                    }
                                                  });
                                            }
                                          },
                                    ),
                                    sectionsSpace: 4,
                                    centerSpaceRadius: 30,
                                    sections: pieData.asMap().entries.map((
                                      entry,
                                    ) {
                                      final isTouched =
                                          entry.key == touchedIndex;
                                      final fontSize = isTouched ? 14.0 : 10.0;
                                      final radius = isTouched ? 55.0 : 45.0;
                                      final List<Color> colors = [
                                        Colors.blue,
                                        Colors.teal,
                                        Colors.orange,
                                        Colors.purple,
                                        Colors.red,
                                      ];

                                      return PieChartSectionData(
                                        color:
                                            colors[entry.key % colors.length],
                                        value: (entry.value['quantity'] ?? 0)
                                            .toDouble(),
                                        title: isTouched
                                            ? entry.value['category']
                                            : "${(entry.value['percentage'] ?? 0).toStringAsFixed(0)}%",
                                        radius: radius,
                                        titleStyle: TextStyle(
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            // ABC Analysis (Pareto Distribution)
            Expanded(
              flex: 2,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        "ABC Audit",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildABCRow(
                        "A",
                        "${_abcData['A']?['count'] ?? 0} items",
                        Colors.green,
                        onTap: () => _toggleABCFilter('A'),
                        isSelected: _abcFilter == 'A',
                      ),
                      _buildABCRow(
                        "B",
                        "${_abcData['B']?['count'] ?? 0} items",
                        Colors.orange,
                        onTap: () => _toggleABCFilter('B'),
                        isSelected: _abcFilter == 'B',
                      ),
                      _buildABCRow(
                        "C",
                        "${_abcData['C']?['count'] ?? 0} items",
                        Colors.red,
                        onTap: () => _toggleABCFilter('C'),
                        isSelected: _abcFilter == 'C',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Value dist.",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildABCRow(
    String label,
    String percent,
    Color color, {
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                  color: isSelected ? color : Colors.black,
                ),
              ),
              const Spacer(),
              Text(
                percent,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? color : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleABCFilter(String category) {
    setState(() {
      if (_abcFilter == category) {
        _abcFilter = null;
      } else {
        _abcFilter = category;
      }
    });
    _loadInitialData();
  }

  Future<void> _handleExport(String outputType) async {
    if (_report.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No data to export')));
      return;
    }

    try {
      // Export functions with current filter settings
      if (outputType == 'print') {
        await _exportService.printStockReport(
          _report,
          includePrice: _includePrice,
          showExpiry: _showExpiry,
          detailedView: _detailedView,
        );
      } else if (outputType == 'save') {
        await _exportService.saveStockReportPdf(
          _report,
          includePrice: _includePrice,
          showExpiry: _showExpiry,
          detailedView: _detailedView,
        );
      } else if (outputType == 'share') {
        await _exportService.exportToPDF(
          _report,
          includePrice: _includePrice,
          showExpiry: _showExpiry,
          detailedView: _detailedView,
        );
      } else if (outputType == 'excel') {
        await _exportService.exportToExcel(
          _report,
          includePrice: _includePrice,
          showExpiry: _showExpiry,
          detailedView: _detailedView,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Excel file exported successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Stock Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export Options',
            onSelected: _handleExport,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print, size: 20),
                    SizedBox(width: 12),
                    Text('Print'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 20),
                    SizedBox(width: 12),
                    Text('Save PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, size: 20, color: Colors.green),
                    SizedBox(width: 12),
                    Text('Export Excel'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildSummaryCard(ResponsiveUtils.isMobile(context)),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  Expanded(
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverToBoxAdapter(child: _buildChart()),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        SliverToBoxAdapter(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "Inventory Items ($_totalCount)",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_abcFilter != null) ...[
                                    const SizedBox(width: 8),
                                    ActionChip(
                                      label: Text(
                                        "ABC: $_abcFilter",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                      backgroundColor: _abcFilter == 'A'
                                          ? Colors.green
                                          : (_abcFilter == 'B'
                                                ? Colors.orange
                                                : Colors.red),
                                      onPressed: () =>
                                          _toggleABCFilter(_abcFilter!),
                                      avatar: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ],
                                ],
                              ),
                              if (_loadingMore)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        _buildSliverReportList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

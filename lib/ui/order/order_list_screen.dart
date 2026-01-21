import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../dao/invoice_dao.dart';
import '../../models/invoice.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';
import '../../db/database_helper.dart';
import 'order_insights_card.dart';
import 'pdf_export_helper.dart';
import '../../utils/responsive_utils.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final dbHelper = DatabaseHelper.instance;

  List<Invoice> _orders = [];
  List<Invoice> _filtered = [];

  bool _loading = true;
  final bool _hasMore = true;
  bool _error = false;
  DateTime? _lastUpdated;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _showPendingOnly = false;
  DateTimeRange? _selectedDateRange;
  String? _quickFilter; // "today", "week", "month"

  late AnimationController _animController;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _loadOrders();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 300 && !_showScrollToTop) {
      setState(() => _showScrollToTop = true);
    } else if (_scrollController.offset <= 300 && _showScrollToTop) {
      setState(() => _showScrollToTop = false);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  void _onSearchChanged() {
    // debounce search to avoid frequent filtering
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _applyFilters();
    });
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final db = await dbHelper.db;
      final dao = InvoiceDao(db);
      final data = await dao.getAllInvoices();
      await Future.delayed(const Duration(milliseconds: 200)); // smooth UX

      setState(() {
        _orders = data;
        _applyFilters(); // sets _filtered
        _loading = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load orders: $e')));
      }
    }
  }

  Future<void> _exportAllOrders() async {
    if (_filtered.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No orders to export.")));
      return;
    }

    final file = await generateAllOrdersPdf(
      _filtered,
      searchQuery: _searchController.text.trim(),
      showPendingOnly: _showPendingOnly,
      dateRange: _selectedDateRange,
      quickFilter: _quickFilter,
    );
    if (file != null) {
      await shareOrPrintPdf(file);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    List<Invoice> results = List.from(_orders);

    try {
      if (query.isNotEmpty) {
        results = results.where((o) {
          final customer = o.customerName?.toLowerCase() ?? '';
          final id = o.id.toLowerCase();
          return customer.contains(query) || id.contains(query);
        }).toList();
      }

      if (_showPendingOnly) {
        results = results.where((o) => o.pending > 0).toList();
      }

      // quick filters
      if (_quickFilter != null) {
        final now = DateTime.now();
        if (_quickFilter == 'today') {
          results = results.where((o) {
            final date = _safeParseDate(o.date);
            return date != null &&
                date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          }).toList();
        } else if (_quickFilter == 'week') {
          final weekAgo = DateTime.now().subtract(const Duration(days: 7));
          results = results
              .where((o) => _safeParseDate(o.date)?.isAfter(weekAgo) ?? false)
              .toList();
        } else if (_quickFilter == 'month') {
          final now2 = DateTime.now();
          results = results.where((o) {
            final date = _safeParseDate(o.date);
            return date != null &&
                date.month == now2.month &&
                date.year == now2.year;
          }).toList();
        }
      }

      // date range filter
      if (_selectedDateRange != null) {
        results = results.where((o) {
          final date = _safeParseDate(o.date);
          if (date == null) return false;
          return date.isAfter(
                _selectedDateRange!.start.subtract(const Duration(days: 1)),
              ) &&
              date.isBefore(
                _selectedDateRange!.end.add(const Duration(days: 1)),
              );
        }).toList();
      }
    } catch (e) {
      // safety fallback: if filtering fails, show all orders and report quietly
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Filter error: $e')));
      }
      results = List.from(_orders);
    }

    setState(() {
      _filtered = results;
      _animController.forward(from: 0);
    });
  }

  DateTime? _safeParseDate(String? iso) {
    if (iso == null) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  double _safeDouble(num? n) => (n == null) ? 0.0 : n.toDouble();

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text("Show Pending Only"),
                  value: _showPendingOnly,
                  onChanged: (v) => setSheetState(() => _showPendingOnly = v),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDateRange == null
                          ? "No Date Filter"
                          : "${DateFormat('dd MMM').format(_selectedDateRange!.start)} → ${DateFormat('dd MMM').format(_selectedDateRange!.end)}",
                      style: const TextStyle(fontSize: 14),
                    ),
                    IconButton(
                      icon: const Icon(Icons.date_range),
                      onPressed: () async {
                        final now = DateTime.now();
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(now.year - 5),
                          lastDate: DateTime(now.year + 5),
                          initialDateRange: _selectedDateRange,
                        );
                        if (range != null) {
                          setSheetState(() => _selectedDateRange = range);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.filter_alt),
                        label: const Text("Apply"),
                        onPressed: () {
                          Navigator.pop(context);
                          _applyFilters();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDateRange = null;
                      _showPendingOnly = false;
                      _quickFilter = null;
                    });
                    Navigator.pop(context);
                    _applyFilters();
                  },
                  child: const Text("Clear Filters"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _navigateToForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrderFormScreen()),
    );
    await _loadOrders();
  }

  Widget _buildShimmerList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      controller: _scrollController,
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    final filters = {
      'today': 'Today',
      'week': 'This Week',
      'month': 'This Month',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: filters.entries.map((entry) {
          final active = _quickFilter == entry.key;
          return ChoiceChip(
            label: Text(entry.value),
            selected: active,
            selectedColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.12),
            onSelected: (val) {
              setState(() => _quickFilter = val ? entry.key : null);
              _applyFilters();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInsightCard() {
    final total = _filtered.length;
    final pendingCount = _filtered
        .where((o) => _safeDouble(o.pending) > 0)
        .length;
    final paidCount = total - pendingCount;
    final revenue = _filtered.fold<double>(
      0.0,
      (s, o) => s + _safeDouble(o.total),
    );

    if (_loading) {
      // shimmer placeholder for insights
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
            child: SizedBox(height: 88),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _insightItem(
                    Icons.shopping_bag,
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
                    Icons.attach_money,
                    "Revenue",
                    revenue.toStringAsFixed(0),
                    Colors.purple,
                  ),
                ],
              ),
              if (_lastUpdated != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "Last updated: ${DateFormat('dd MMM yyyy, hh:mm a').format(_lastUpdated!)}",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _insightItem(IconData icon, String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            "No orders found",
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          const Text(
            "Try clearing filters or creating a new order",
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
  void _showOrderActions(Invoice invoice) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text("Export Invoice as PDF"),
              onTap: () async {
                Navigator.pop(context);
                final file = await generateInvoicePdf(invoice);
                if (file != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("✅ Invoice PDF saved successfully"),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text("Print Thermal Receipt"),
              onTap: () async {
                Navigator.pop(context);
                final file = await generateThermalReceipt(invoice);
                if (file != null) {
                  await printPdfFile(file);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("✅ Sending to thermal printer..."),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text("Print Invoice"),
              onTap: () async {
                Navigator.pop(context);
                final file = await generateInvoicePdf(invoice);
                if (file != null) await printPdfFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text("Share PDF"),
              onTap: () async {
                Navigator.pop(context);
                final file = await generateInvoicePdf(invoice);
                if (file != null) await shareOrPrintPdf(file);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.redAccent),
              title: const Text("Cancel"),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _getGradientColors(int index) {
    final gradients = [
      [const Color(0xFF4A00E0), const Color(0xFF8E2DE2)], // Violet → Purple
      [const Color(0xFF00B4DB), const Color(0xFF0083B0)], // Cyan → Blue
      [const Color(0xFFFF512F), const Color(0xFFF09819)], // Orange → Yellow
      [const Color(0xFF11998E), const Color(0xFF38EF7D)], // Green → Lime
      [const Color(0xFFFC466B), const Color(0xFF3F5EFB)], // Pink → Blue
      [const Color(0xFFFF5F6D), const Color(0xFFFFC371)], // Red → Peach
    ];
    return gradients[index % gradients.length];
  }

  List<Color> _getNextGradientColors(int index) {
    // shift by 1 to get the "next" gradient in sequence
    return _getGradientColors(index + 1);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required for AutomaticKeepAliveClientMixin
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Orders"),
        elevation: 0,
        actions: isMobile
            ? [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'filter') {
                      _openFilterSheet();
                    } else if (value == 'refresh') {
                      _loadOrders();
                    } else if (value == 'export') {
                      _exportAllOrders();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'filter',
                      child: Row(
                        children: [
                          Icon(Icons.filter_list),
                          SizedBox(width: 8),
                          Text('Filters'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh),
                          SizedBox(width: 8),
                          Text('Refresh'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf),
                          SizedBox(width: 8),
                          Text('Export PDF'),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : [
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _openFilterSheet,
                  tooltip: 'Filters',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadOrders,
                  tooltip: 'Refresh',
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: _exportAllOrders,
                  tooltip: 'Export PDF',
                ),
                const SizedBox(width: 10),
              ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(140),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.1),
                  Theme.of(context).primaryColor.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search invoices or customers...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickFilterChip('Today', 'today'),
                      _buildQuickFilterChip('This Week', 'week'),
                      _buildQuickFilterChip('This Month', 'month'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: OrderInsightCard(
              orders: _filtered,
              loading: false,
              lastUpdated: _lastUpdated,
            ),
          ),

          // list area
          Expanded(
            child: _loading
                ? _buildShimmerList()
                : RefreshIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    onRefresh: _loadOrders,
                    child: _filtered.isEmpty
                        ? _emptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 80,
                            ),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final o = _filtered[index];
                              final isPending = _safeDouble(o.pending) > 0;
                              final date =
                                  _safeParseDate(o.date) ?? DateTime.now();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white,
                                      isPending
                                          ? Colors.orange.withOpacity(0.05)
                                          : Colors.green.withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (isPending
                                                  ? Colors.orange
                                                  : Colors.green)
                                              .withOpacity(0.2),
                                      spreadRadius: 1,
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color:
                                        (isPending
                                                ? Colors.orange
                                                : Colors.green)
                                            .withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Status Strip
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isPending
                                                ? [
                                                    Colors.orange.shade600,
                                                    Colors.orange.shade400,
                                                  ]
                                                : [
                                                    Colors.green.shade600,
                                                    Colors.green.shade400,
                                                  ],
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isPending
                                                  ? Icons.pending_actions
                                                  : Icons.check_circle,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              isPending
                                                  ? "Payment Pending"
                                                  : "Fully Paid",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      InkWell(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                OrderDetailScreen(invoice: o),
                                          ),
                                        ),
                                        onLongPress: () => _showOrderActions(o),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Header Row
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Invoice Badge
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                        colors: [
                                                          Colors.blue.shade600,
                                                          Colors.blue.shade400,
                                                        ],
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.blue
                                                              .withOpacity(0.3),
                                                          blurRadius: 8,
                                                          offset: const Offset(
                                                            0,
                                                            2,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Icon(
                                                      Icons.receipt_long,
                                                      color: Colors.white,
                                                      size: 28,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),

                                                  // Customer & Invoice Info
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          o.customerName ??
                                                              "Unknown Customer",
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors
                                                                .purple
                                                                .shade50,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  6,
                                                                ),
                                                            border: Border.all(
                                                              color: Colors
                                                                  .purple
                                                                  .shade200,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            "Invoice #${o.id}",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .purple
                                                                  .shade900,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  // Date Badge
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          10,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        Text(
                                                          date.day.toString(),
                                                          style: TextStyle(
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors
                                                                .grey
                                                                .shade800,
                                                          ),
                                                        ),
                                                        Text(
                                                          _getMonthName(
                                                            date.month,
                                                          ),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors
                                                                .grey
                                                                .shade600,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              const SizedBox(height: 16),
                                              const Divider(),
                                              const SizedBox(height: 12),

                                              // Metrics Row
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  _buildMetric(
                                                    "TOTAL",
                                                    "Rs ${_safeDouble(o.total).toStringAsFixed(0)}",
                                                    Colors.blue,
                                                  ),
                                                  _buildMetric(
                                                    "PAID",
                                                    "Rs ${_safeDouble(o.paid).toStringAsFixed(0)}",
                                                    Colors.green,
                                                  ),
                                                  _buildMetric(
                                                    "PENDING",
                                                    "Rs ${_safeDouble(o.pending).toStringAsFixed(0)}",
                                                    isPending
                                                        ? Colors.red
                                                        : Colors.green,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showScrollToTop)
            FloatingActionButton(
              heroTag: 'scrollTop',
              mini: true,
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                );
              },
              child: const Icon(Icons.arrow_upward),
            ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'newOrder',
            onPressed: _navigateToForm,
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text("New Order"),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChip(String label, String filterKey) {
    final isActive = _quickFilter == filterKey;
    Color chipColor;
    IconData chipIcon;

    switch (filterKey) {
      case 'today':
        chipColor = Colors.orange;
        chipIcon = Icons.today;
        break;
      case 'week':
        chipColor = Colors.blue;
        chipIcon = Icons.calendar_view_week;
        break;
      case 'month':
        chipColor = Colors.purple;
        chipIcon = Icons.calendar_month;
        break;
      default:
        chipColor = Colors.grey;
        chipIcon = Icons.all_inclusive;
    }

    return FilterChip(
      avatar: Icon(chipIcon, size: 16),
      label: Text(label),
      selected: isActive,
      onSelected: (val) {
        setState(() => _quickFilter = val ? filterKey : null);
        _applyFilters();
      },
      selectedColor: chipColor.withOpacity(0.2),
      checkmarkColor: chipColor,
      backgroundColor: Colors.white,
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

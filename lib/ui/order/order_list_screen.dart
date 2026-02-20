import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../dao/invoice_dao.dart';
import '../../models/invoice.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';
import '../../dao/customer_dao.dart';
import '../customer_payment/customer_payment_dialog.dart';
import '../../db/database_helper.dart';
import 'order_insights_card.dart';
import 'pdf_export_helper.dart';
import '../../utils/responsive_utils.dart';
import '../../services/logger_service.dart';
import '../../utils/date_helper.dart';
import '../common/unified_search_bar.dart';

enum OrderViewMode { table, compact, card }

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
  OrderViewMode _viewMode = OrderViewMode.card;

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
    });

    try {
      logger.info('OrderList', 'Loading all invoices');
      final db = await dbHelper.db;
      final dao = InvoiceDao(db);
      final data = await dao.getAllInvoices();
      await Future.delayed(const Duration(milliseconds: 200)); // smooth UX

      setState(() {
        _orders = data;
        _applyFilters(); // sets _filtered
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      logger.error('OrderList', 'Failed to load orders', error: e);
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
      logger.warning(
        'OrderList',
        'Filter error caught, showing all orders',
        error: e,
      );
    }

    setState(() {
      _filtered = results;
      _animController.forward(from: 0);
    });
  }

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

  Future<void> _fastPrintOrder(Invoice invoice) async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🖨️ Preparing thermal receipt...")),
      );

      final db = await dbHelper.db;
      final rawItems = await db.rawQuery(
        '''
        SELECT ii.qty, ii.price, p.name as product_name
        FROM invoice_items ii
        JOIN products p ON ii.product_id = p.id
        WHERE ii.invoice_id = ?
      ''',
        [invoice.id],
      );

      final success = await printSilentThermalReceipt(invoice, items: rawItems);
      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ Sent to printer")));
      }
    } catch (e) {
      logger.error('OrderList', 'Fast print error', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Print error: $e")));
      }
    }
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
                if (file != null && context.mounted) {
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
                final success = await printSilentThermalReceipt(invoice);
                if (success && context.mounted) {
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

  Future<void> _payInvoice(Invoice invoice) async {
    try {
      final customerDao = await CustomerDao.create();
      final customers = await customerDao.getAllCustomers();

      if (!mounted) return;

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => CustomerPaymentDialog(
          customers: customers,
          paymentData: {
            'customer_id': invoice.customerId,
            'amount': invoice.pending,
            'date': DateTime.now().toIso8601String(),
            'invoice_id': invoice.id,
          },
        ),
      );

      if (result == true) {
        _loadOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening payment dialog: $e')),
        );
      }
    }
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
                IconButton(
                  icon: Icon(_viewModeIcon()),
                  tooltip: 'View: ${_viewModeLabel()}',
                  onPressed: _cycleViewMode,
                ),
                IconButton(
                  icon: const Icon(Icons.insights),
                  tooltip: 'Insights',
                  onPressed: _showInsightsDialog,
                ),
                IconButton(
                  onPressed: _navigateToForm,
                  icon: const Icon(Icons.add_circle),
                  tooltip: 'Add Order',
                ),
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
                // View toggle
                Tooltip(
                  message: 'View: ${_viewModeLabel()}',
                  child: TextButton.icon(
                    icon: Icon(_viewModeIcon(), size: 20),
                    label: Text(_viewModeLabel()),
                    onPressed: _cycleViewMode,
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).appBarTheme.foregroundColor ??
                          Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.insights),
                  tooltip: 'Insights',
                  onPressed: _showInsightsDialog,
                ),
                const SizedBox(width: 4),
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
                IconButton(
                  onPressed: _navigateToForm,
                  icon: const Icon(Icons.add_circle, size: 28),
                  tooltip: 'Add Order',
                ),
                const SizedBox(width: 10),
              ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            ResponsiveUtils.getAppBarBottomHeight(
              context,
              baseHeight: isMobile ? 140 : 120,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  Theme.of(context).primaryColor.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: UnifiedSearchBar(
                    hintText: "Search invoices or customers...",
                    controller: _searchController,
                    onChanged:
                        (_) {}, // searchController is already listened to
                    onClear: () {
                      _searchController.clear();
                      _applyFilters();
                    },
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
      body: _buildBody(),

      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
              mini: true,
              child: const Icon(Icons.arrow_upward),
            )
          : null,
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
      selectedColor: chipColor.withValues(alpha: 0.2),
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

  DateTime? _safeParseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    return DateHelper.parseDate(dateStr) ?? DateTime.tryParse(dateStr);
  }

  IconData _viewModeIcon() {
    switch (_viewMode) {
      case OrderViewMode.table:
        return Icons.table_chart;
      case OrderViewMode.compact:
        return Icons.view_list;
      case OrderViewMode.card:
        return Icons.grid_view;
    }
  }

  String _viewModeLabel() {
    switch (_viewMode) {
      case OrderViewMode.table:
        return 'Table';
      case OrderViewMode.compact:
        return 'Compact';
      case OrderViewMode.card:
        return 'Card';
    }
  }

  void _cycleViewMode() {
    setState(() {
      _viewMode = OrderViewMode
          .values[(_viewMode.index + 1) % OrderViewMode.values.length];
    });
  }

  void _showInsightsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text("Order Insights"),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: OrderInsightCard(
                    orders: _orders,
                    loading: _loading,
                    lastUpdated: DateTime.now(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return _buildShimmerList();
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              "No orders found",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (_searchController.text.isNotEmpty ||
                _quickFilter != null ||
                _showPendingOnly)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _quickFilter = null;
                    _showPendingOnly = false;
                    _selectedDateRange = null;
                  });
                  _applyFilters();
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Clear all filters"),
              ),
          ],
        ),
      );
    }

    switch (_viewMode) {
      case OrderViewMode.table:
        return _buildTableView();
      case OrderViewMode.compact:
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _filtered.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) => _buildCompactItem(_filtered[index]),
        );
      case OrderViewMode.card:
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _filtered.length,
          itemBuilder: (context, index) => _buildCardItem(_filtered[index]),
        );
    }
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Pending')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _filtered.map((o) {
            final isPending = o.pending > 0;
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    o.id
                        .substring(o.id.length > 6 ? o.id.length - 6 : 0)
                        .toUpperCase(),
                  ),
                ),
                DataCell(Text(o.date)),
                DataCell(Text(o.customerName ?? 'N/A')),
                DataCell(Text("Rs ${o.total.toStringAsFixed(0)}")),
                DataCell(
                  Text(
                    "Rs ${o.pending.toStringAsFixed(0)}",
                    style: TextStyle(
                      color: isPending ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(_buildStatusChip(o)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 20),
                        onPressed: () => _viewDetails(o),
                        tooltip: "View Details",
                      ),
                      IconButton(
                        icon: const Icon(Icons.print, size: 20),
                        onPressed: () => _fastPrintOrder(o),
                        tooltip: "Fast Print",
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCompactItem(Invoice o) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getStatusColor(o).withValues(alpha: 0.1),
        child: Icon(Icons.receipt_long, color: _getStatusColor(o), size: 20),
      ),
      title: Text(
        o.customerName ?? "Unknown Customer",
        style: const TextStyle(fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "#${o.id.substring(o.id.length > 6 ? o.id.length - 6 : 0).toUpperCase()} • ${o.date}",
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            "Rs ${o.total.toStringAsFixed(0)}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (o.pending > 0)
            Text(
              "Rs ${o.pending.toStringAsFixed(0)} pending",
              style: const TextStyle(color: Colors.red, fontSize: 11),
            ),
        ],
      ),
      onTap: () => _viewDetails(o),
    );
  }

  Widget _buildCardItem(Invoice o) {
    final isPending = o.pending > 0;
    final date = _safeParseDate(o.date) ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewDetails(o),
        onLongPress: () => _showOrderActions(o),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.customerName ?? "Unknown Customer",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "Invoice #${o.id.substring(o.id.length > 6 ? o.id.length - 6 : 0).toUpperCase()}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(o),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetric(
                    "TOTAL",
                    "Rs ${o.total.toStringAsFixed(0)}",
                    Colors.blue,
                  ),
                  _buildMetric(
                    "PAID",
                    "Rs ${o.paid.toStringAsFixed(0)}",
                    Colors.green,
                  ),
                  _buildMetric(
                    "PENDING",
                    "Rs ${o.pending.toStringAsFixed(0)}",
                    isPending ? Colors.red : Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy').format(date),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _fastPrintOrder(o),
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text(
                          "PRINT",
                          style: TextStyle(fontSize: 11),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isPending)
                        ElevatedButton(
                          onPressed: () => _payInvoice(o),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            "PAY",
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(Invoice o) {
    final color = _getStatusColor(o);
    final isPending = o.pending > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isPending ? "PENDING" : "PAID",
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(Invoice o) {
    return o.pending > 0 ? Colors.red : Colors.green;
  }

  void _viewDetails(Invoice o) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailScreen(invoice: o)),
    );
  }
}

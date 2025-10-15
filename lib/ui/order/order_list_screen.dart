import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../dao/invoice_dao.dart';
import '../../models/invoice.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  List<Invoice> _orders = [];
  List<Invoice> _filtered = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  bool _showPendingOnly = false;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    final dao = InvoiceDao();
    final data = await dao.getAllInvoices();
    setState(() {
      _orders = data;
      _applyFilters();
      _loading = false;
    });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    List<Invoice> results = List.from(_orders);

    // 🔍 Search by customer name or ID
    if (query.isNotEmpty) {
      results = results.where((o) {
        final matchCustomer = o.customerName?.toLowerCase().contains(query) ?? false;
        final matchId = o.id.toLowerCase().contains(query);
        return matchCustomer || matchId;
      }).toList();
    }

    // ⏰ Filter by pending status
    if (_showPendingOnly) {
      results = results.where((o) => o.pending > 0).toList();
    }

    // 📅 Filter by selected date range
    if (_selectedDateRange != null) {
      results = results.where((o) {
        try {
          final date = DateTime.parse(o.date);
          return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
              date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
        } catch (_) {
          return true;
        }
      }).toList();
    }

    setState(() => _filtered = results);
  }

  void _search(String query) => _applyFilters();

  Future<void> _navigateToForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrderFormScreen()),
    );
    _loadOrders(); // reload after returning
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _selectedDateRange,
    );

    if (range != null) {
      setState(() => _selectedDateRange = range);
      _applyFilters();
    }
  }

  void _clearDateFilter() {
    setState(() => _selectedDateRange = null);
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Orders"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Search by invoice or customer",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // ⚙️ Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Pending toggle
                Row(
                  children: [
                    Switch(
                      value: _showPendingOnly,
                      onChanged: (val) {
                        setState(() => _showPendingOnly = val);
                        _applyFilters();
                      },
                    ),
                    const Text("Show Pending Only"),
                  ],
                ),

                // Date filter
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.date_range),
                      onPressed: _pickDateRange,
                    ),
                    if (_selectedDateRange != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: "Clear date filter",
                        onPressed: _clearDateFilter,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 🧾 Orders List
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text("No orders found"))
                : RefreshIndicator(
                    onRefresh: _loadOrders,
                    child: ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final o = _filtered[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            title: Text(
                              "Invoice #${o.id}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "Customer: ${o.customerName ?? 'Unknown'}\nDate: ${_formatDate(o.date)}",
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("Total: ${o.total.toStringAsFixed(2)}"),
                                Text(
                                  o.pending > 0
                                      ? "Pending: ${o.pending.toStringAsFixed(2)}"
                                      : "Paid",
                                  style: TextStyle(
                                    color: o.pending > 0 ? Colors.red : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrderDetailScreen(invoice: o),
                                ),
                              );
                            },
                            onLongPress: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Delete Order"),
                                  content: const Text("Are you sure you want to delete this order?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text("Cancel"),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text("Delete"),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                final dao = InvoiceDao();
                                await dao.delete(o.id);
                                _loadOrders();
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../models/customer_payment.dart';
import '../../repositories/customer_repository.dart';
import '../../dao/invoice_dao.dart';
import '../../db/database_helper.dart';
import '../customer_payment/customer_payment_dialog.dart';

class CustomerDetailFrame extends StatefulWidget {
  final Customer customer;
  final CustomerRepository repository;

  const CustomerDetailFrame({
    super.key,
    required this.customer,
    required this.repository,
  });

  @override
  State<CustomerDetailFrame> createState() => _CustomerDetailFrameState();
}

class _CustomerDetailFrameState extends State<CustomerDetailFrame>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  List<Invoice> _orders = [];
  List<CustomerPayment> _payments = [];

  double _totalSpent = 0;
  double _pendingAmount = 0;
  int _totalOrders = 0;
  DateTime? _lastOrderDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final db = await DatabaseHelper.instance.db;
    final invoiceDao = InvoiceDao(db);

    // Get all invoices and filter by customer
    final allInvoices = await invoiceDao.getAllInvoices();
    _orders = allInvoices
        .where((inv) => inv.customerId == widget.customer.id)
        .toList();
    _orders.sort((a, b) => b.date.compareTo(a.date));

    // Get payments using correct method name
    _payments = await widget.repository.getPayments(widget.customer.id);

    //Calculate metrics
    _pendingAmount = widget.customer.pendingAmount;
    _totalOrders = _orders.length;
    _totalSpent = _orders.fold<double>(0, (sum, inv) => sum + inv.total);

    if (_orders.isNotEmpty) {
      _lastOrderDate = DateTime.parse(_orders.first.date);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _showAddPaymentDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => CustomerPaymentDialog(customers: [widget.customer]),
    );

    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: 'Orders'),
            Tab(icon: Icon(Icons.payment), text: 'Payments'),
            Tab(icon: Icon(Icons.account_balance), text: 'Ledger'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card),
            tooltip: 'Add Payment',
            onPressed: _showAddPaymentDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCustomerHeader(),
                _buildSummaryCards(),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOrdersTab(),
                      _buildPaymentsTab(),
                      _buildLedgerTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCustomerHeader() {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                widget.customer.name.isNotEmpty
                    ? widget.customer.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.customer.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.customer.phone.isNotEmpty)
                    Text(
                      '📞 ${widget.customer.phone}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  if (widget.customer.email != null &&
                      widget.customer.email!.isNotEmpty)
                    Text(
                      '✉️ ${widget.customer.email}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              'Total Orders',
              _totalOrders.toString(),
              Icons.shopping_cart,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricCard(
              'Total Spent',
              'Rs ${_totalSpent.toStringAsFixed(0)}',
              Icons.attach_money,
              Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricCard(
              'Pending',
              'Rs ${_pendingAmount.toStringAsFixed(0)}',
              Icons.pending_actions,
              _pendingAmount > 0 ? Colors.orange : Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricCard(
              'Last Order',
              _lastOrderDate != null
                  ? DateFormat('dd MMM').format(_lastOrderDate!)
                  : 'N/A',
              Icons.event,
              Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersTab() {
    if (_orders.isEmpty) {
      return const Center(
        child: Text('No orders yet', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final isPaid = order.pending <= 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPaid
                  ? Colors.green.shade100
                  : Colors.orange.shade100,
              child: Icon(
                Icons.receipt,
                color: isPaid ? Colors.green : Colors.orange,
              ),
            ),
            title: Text(
              'Invoice #${order.id.substring(0, 8)}...',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${DateFormat('dd MMM yyyy').format(DateTime.parse(order.date))} • ${isPaid ? "Paid" : "Pending"}',
            ),
            trailing: Text(
              'Rs ${order.total.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab() {
    if (_payments.isEmpty) {
      return const Center(
        child: Text('No payments yet', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.check, color: Colors.white),
            ),
            title: Text(
              'Rs ${payment.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${DateFormat('dd MMM yyyy').format(DateTime.parse(payment.date))}${payment.note != null && payment.note!.isNotEmpty ? " • ${payment.note}" : ""}',
            ),
          ),
        );
      },
    );
  }

  Widget _buildLedgerTab() {
    final List<Map<String, dynamic>> ledgerEntries = [];

    for (var order in _orders) {
      ledgerEntries.add({
        'date': order.date,
        'description': 'Invoice #${order.id.substring(0, 8)}',
        'debit': order.total,
        'credit': 0.0,
        'pending': order.pending > 0,
      });
    }

    for (var payment in _payments) {
      ledgerEntries.add({
        'date': payment.date,
        'description':
            'Payment${payment.note != null && payment.note!.isNotEmpty ? " - ${payment.note}" : ""}',
        'debit': 0.0,
        'credit': payment.amount,
        'pending': false,
      });
    }

    ledgerEntries.sort((a, b) => b['date'].compareTo(a['date']));

    if (ledgerEntries.isEmpty) {
      return const Center(
        child: Text(
          'No transactions yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: ledgerEntries.length,
      itemBuilder: (context, index) {
        final entry = ledgerEntries[index];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat(
                        'dd MMM yyyy',
                      ).format(DateTime.parse(entry['date'])),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (entry['pending'])
                      const Chip(
                        label: Text('Pending', style: TextStyle(fontSize: 10)),
                        backgroundColor: Colors.orange,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(entry['description']),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (entry['debit'] > 0)
                      Text(
                        'Debit: Rs ${entry['debit'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (entry['credit'] > 0)
                      Text(
                        'Credit: Rs ${entry['credit'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

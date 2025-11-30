import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../dao/customer_payment_dao.dart';
import '../../dao/customer_dao.dart';
import '../../models/customer.dart';
import 'customer_payment_dialog.dart';

class CustomerPaymentScreen extends StatefulWidget {
  const CustomerPaymentScreen({super.key});

  @override
  State<CustomerPaymentScreen> createState() => _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends State<CustomerPaymentScreen> {
  final _paymentDao = CustomerPaymentDao();
  final _customerDao = CustomerDao.create();

  List<Map<String, dynamic>> _payments = [];
  List<Customer> _customers = [];
  bool _isLoading = true;

  // Filters
  String? _selectedCustomerId;
  String? _selectedMethod = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  final _searchController = TextEditingController();

  final List<String> _paymentMethods = [
    'all',
    'cash',
    'card',
    'bank_transfer',
    'upi',
    'cheque',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final customerDao = await _customerDao;
      final customers = await customerDao.getAllCustomers();
      final payments = await _paymentDao.searchPayments(
        customerId: _selectedCustomerId,
        startDate: _startDate?.toIso8601String().split('T')[0],
        endDate: _endDate?.toIso8601String().split('T')[0],
        method: _selectedMethod,
        searchQuery: _searchController.text,
      );

      setState(() {
        _customers = customers;
        _payments = payments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _showPaymentDialog([Map<String, dynamic>? paymentData]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CustomerPaymentDialog(
        customers: _customers,
        paymentData: paymentData,
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _deletePayment(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment'),
        content: const Text('Are you sure you want to delete this payment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _paymentDao.delete(id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting payment: $e')));
        }
      }
    }
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Customer filter
                SizedBox(
                  width: 250,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCustomerId,
                    decoration: const InputDecoration(
                      labelText: 'Customer',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Customers'),
                      ),
                      ..._customers.map(
                        (customer) => DropdownMenuItem(
                          value: customer.id,
                          child: Text(customer.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCustomerId = value);
                      _loadData();
                    },
                  ),
                ),
                // Payment method filter
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _selectedMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _paymentMethods
                        .map(
                          (method) => DropdownMenuItem(
                            value: method,
                            child: Text(
                              method == 'all'
                                  ? 'All Methods'
                                  : method.toUpperCase(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedMethod = value);
                      _loadData();
                    },
                  ),
                ),
                // Date range
                SizedBox(
                  width: 200,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _startDate == null && _endDate == null
                          ? 'Select Date Range'
                          : '${_startDate != null ? DateFormat('dd/MM/yy').format(_startDate!) : ''} - ${_endDate != null ? DateFormat('dd/MM/yy').format(_endDate!) : ''}',
                    ),
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: _startDate != null && _endDate != null
                            ? DateTimeRange(start: _startDate!, end: _endDate!)
                            : null,
                      );
                      if (range != null) {
                        setState(() {
                          _startDate = range.start;
                          _endDate = range.end;
                        });
                        _loadData();
                      }
                    },
                  ),
                ),
                // Clear date filter
                if (_startDate != null || _endDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                      _loadData();
                    },
                  ),
                // Search
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      hintText: 'Customer name or transaction ref',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _loadData,
                      ),
                    ),
                    onSubmitted: (_) => _loadData(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Payments'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _payments.isEmpty
                ? const Center(
                    child: Text(
                      'No payments found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Amount')),
                          DataColumn(label: Text('Method')),
                          DataColumn(label: Text('Transaction Ref')),
                          DataColumn(label: Text('Note')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _payments.map((payment) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(DateTime.parse(payment['date'])),
                                ),
                              ),
                              DataCell(
                                Text(payment['customer_name'] ?? 'Unknown'),
                              ),
                              DataCell(
                                Text(
                                  'Rs ${(payment['amount'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  (payment['method'] ?? 'cash')
                                      .toString()
                                      .toUpperCase(),
                                ),
                              ),
                              DataCell(Text(payment['transaction_ref'] ?? '-')),
                              DataCell(Text(payment['note'] ?? '-')),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () =>
                                          _showPaymentDialog(payment),
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          _deletePayment(payment['id']),
                                      tooltip: 'Delete',
                                    ),
                                  ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPaymentDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Payment'),
      ),
    );
  }
}

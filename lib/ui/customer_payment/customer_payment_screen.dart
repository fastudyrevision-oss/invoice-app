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

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final date = DateTime.parse(payment['date']);
    final amount = (payment['amount'] as num).toDouble();
    final method = payment['method'] ?? 'cash';
    final customerName = payment['customer_name'] ?? 'Unknown';
    final ref = payment['transaction_ref'];
    final note = payment['note'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.blue.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Status Strip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getMethodIcon(method),
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        method.toString().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  if (ref != null && ref.toString().isNotEmpty)
                    Text(
                      "REF: $ref",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('dd').format(date),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(date).toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          DateFormat('yy').format(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                customerName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'Rs ${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (note != null && note.toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.note,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Actions Divider
            Divider(height: 1, color: Colors.blue.withOpacity(0.1)),

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showPaymentDialog(payment),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text("Edit"),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _deletePayment(payment['id']),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text("Delete"),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.attach_money;
      case 'card':
        return Icons.credit_card;
      case 'bank_transfer':
        return Icons.account_balance;
      case 'upi':
        return Icons.qr_code;
      case 'cheque':
        return Icons.receipt;
      default:
        return Icons.payment;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Customer Payments'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
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
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search customer, ref...',
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
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadData();
                        },
                      ),
                    ),
                    onSubmitted: (_) => _loadData(),
                  ),
                ),

                // Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Customer Filter
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: InputChip(
                          label: Text(
                            _selectedCustomerId == null
                                ? 'All Customers'
                                : _customers
                                      .firstWhere(
                                        (c) => c.id == _selectedCustomerId,
                                        orElse: () => Customer(
                                          id: '',
                                          phone:'',
                                          name: 'Unknown',
                                          createdAt: '',
                                          updatedAt: '',
                                        ),
                                      )
                                      .name,
                          ),
                          avatar: const Icon(Icons.person, size: 18),
                          selected: _selectedCustomerId != null,
                          onSelected: (bool selected) {
                            // Show customer picker dialog
                            showDialog(
                              context: context,
                              builder: (context) => SimpleDialog(
                                title: const Text('Select Customer'),
                                children: [
                                  SimpleDialogOption(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      setState(
                                        () => _selectedCustomerId = null,
                                      );
                                      _loadData();
                                    },
                                    child: const Text('All Customers'),
                                  ),
                                  ..._customers.map(
                                    (c) => SimpleDialogOption(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        setState(
                                          () => _selectedCustomerId = c.id,
                                        );
                                        _loadData();
                                      },
                                      child: Text(c.name),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDeleted: _selectedCustomerId != null
                              ? () {
                                  setState(() => _selectedCustomerId = null);
                                  _loadData();
                                }
                              : null,
                        ),
                      ),

                      // Method Filter
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: InputChip(
                          label: Text(
                            _selectedMethod == 'all'
                                ? 'All Methods'
                                : _selectedMethod!.toUpperCase(),
                          ),
                          avatar: const Icon(Icons.payment, size: 18),
                          selected: _selectedMethod != 'all',
                          onSelected: (bool selected) {
                            // Show method picker
                            showDialog(
                              context: context,
                              builder: (context) => SimpleDialog(
                                title: const Text('Payment Method'),
                                children: _paymentMethods
                                    .map(
                                      (m) => SimpleDialogOption(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          setState(() => _selectedMethod = m);
                                          _loadData();
                                        },
                                        child: Text(
                                          m == 'all'
                                              ? 'All Methods'
                                              : m.toUpperCase(),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            );
                          },
                        ),
                      ),

                      // Date Filter
                      InputChip(
                        label: Text(
                          _startDate == null
                              ? 'Date Range'
                              : '${DateFormat('dd/MM').format(_startDate!)} - ${_endDate != null ? DateFormat('dd/MM').format(_endDate!) : 'Now'}',
                        ),
                        avatar: const Icon(Icons.date_range, size: 18),
                        selected: _startDate != null,
                        onSelected: (bool selected) async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            initialDateRange:
                                _startDate != null && _endDate != null
                                ? DateTimeRange(
                                    start: _startDate!,
                                    end: _endDate!,
                                  )
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
                        onDeleted: _startDate != null
                            ? () {
                                setState(() {
                                  _startDate = null;
                                  _endDate = null;
                                });
                                _loadData();
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.payment_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No payments found',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _payments.length,
              itemBuilder: (context, index) {
                return _buildPaymentCard(_payments[index]);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPaymentDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Payment'),
      ),
    );
  }
}

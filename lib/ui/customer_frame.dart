import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/customer_payment.dart';
import '../repositories/customer_repository.dart';
import '../db/database_helper.dart';

// Enum for sort mode
enum SortMode { name, pending }

class CustomerFrame extends StatefulWidget {
  const CustomerFrame({super.key});

  @override
  _CustomerFrameState createState() => _CustomerFrameState();
}

class _CustomerFrameState extends State<CustomerFrame> {
  CustomerRepository? _repo;
  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _sortAscending = true;
  SortMode _sortMode = SortMode.name;

  final int _pageSize = 20;
  int _currentMax = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initRepo();
    _scrollController.addListener(_scrollListener);
  }

  Future<void> _initRepo() async {
    final db = await DatabaseHelper.instance.db;
    _repo = CustomerRepository(db);
    await _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final data = await _repo!.getAllCustomers();
    setState(() {
      _allCustomers = data;
      _applySearchFilter();
      _isLoading = false;
    });
  }

  void _applySearchFilter() {
    _filteredCustomers = _allCustomers.where((c) {
      final query = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(query) ||
          c.phone.toLowerCase().contains(query) ||
          (c.email?.toLowerCase().contains(query) ?? false);
    }).toList();
    _sortCustomers();
    _currentMax = (_filteredCustomers.length < _pageSize)
        ? _filteredCustomers.length
        : _pageSize;
  }

  void _sortCustomers() {
    if (_sortMode == SortMode.name) {
      _filteredCustomers.sort(
        (a, b) => _sortAscending
            ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
            : b.name.toLowerCase().compareTo(a.name.toLowerCase()),
      );
    } else if (_sortMode == SortMode.pending) {
      _filteredCustomers.sort(
        (a, b) => _sortAscending
            ? a.pendingAmount.compareTo(b.pendingAmount)
            : b.pendingAmount.compareTo(a.pendingAmount),
      );
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      setState(() {
        if (_currentMax < _filteredCustomers.length) {
          _currentMax += _pageSize;
          if (_currentMax > _filteredCustomers.length) {
            _currentMax = _filteredCustomers.length;
          }
        }
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applySearchFilter();
    });
  }

  // ---------------- Dialogs ----------------

  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Customer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: "Phone"),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final customer = Customer(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text,
                phone: phoneController.text,
                email: emailController.text,
                pendingAmount: 0.0,
                createdAt: DateTime.now().toIso8601String(),
                updatedAt: DateTime.now().toIso8601String(),
              );
              await _repo!.addCustomer(customer);
              Navigator.pop(context);
              _loadCustomers();
            },
            child: const Text("Add"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _showEditCustomerDialog(Customer customer) {
    final nameController = TextEditingController(text: customer.name);
    final phoneController = TextEditingController(text: customer.phone);
    final emailController = TextEditingController(text: customer.email ?? "");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Customer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: "Phone"),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final updatedCustomer = Customer(
                id: customer.id,
                name: nameController.text,
                phone: phoneController.text,
                email: emailController.text,
                pendingAmount: customer.pendingAmount,
                createdAt: customer.createdAt,
                updatedAt: DateTime.now().toIso8601String(),
              );

              await _repo!.updateCustomer(updatedCustomer);
              Navigator.pop(context);
              _loadCustomers();
            },
            child: const Text("Update"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentDialog(Customer customer) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Add Payment for ${customer.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: "Amount"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: "Note"),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final payment = CustomerPayment(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                customerId: customer.id,
                amount: double.tryParse(amountController.text) ?? 0.0,
                note: noteController.text,
                date: DateTime.now().toIso8601String(),
              );
              await _repo!.addPayment(payment);
              Navigator.pop(context);
              _loadCustomers();
            },
            child: const Text("Add Payment"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  // ---------------- Build UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Customers"),
        actions: [
          IconButton(
            onPressed: _showAddCustomerDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar with clear
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _applySearchFilter();
                                });
                              },
                            )
                          : null,
                      hintText: "Search by name, phone, email...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),

                // Sort options card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text("Sort by: "),
                          ChoiceChip(
                            label: const Text("Name"),
                            selected: _sortMode == SortMode.name,
                            onSelected: (selected) {
                              setState(() {
                                _sortMode = SortMode.name;
                                _sortCustomers();
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text("Pending"),
                            selected: _sortMode == SortMode.pending,
                            onSelected: (selected) {
                              setState(() {
                                _sortMode = SortMode.pending;
                                _sortCustomers();
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              _sortAscending
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                            ),
                            onPressed: () {
                              setState(() {
                                _sortAscending = !_sortAscending;
                                _sortCustomers();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Customer list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadCustomers,
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _currentMax,
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Customer info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${customer.phone}\n${customer.email ?? ''}",
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),

                                // Pending + actions
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Pending amount chip
                                    Chip(
                                      label: Text(
                                        "Rs ${customer.pendingAmount.toStringAsFixed(2)}",
                                      ),
                                      backgroundColor:
                                          customer.pendingAmount > 0
                                          ? Colors.red.shade100
                                          : Colors.green.shade100,
                                      labelStyle: TextStyle(
                                        color: customer.pendingAmount > 0
                                            ? Colors.red
                                            : Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Action buttons
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.payment),
                                          tooltip: "Add Payment",
                                          onPressed: () =>
                                              _showAddPaymentDialog(customer),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          tooltip: "Edit Customer",
                                          onPressed: () =>
                                              _showEditCustomerDialog(customer),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          tooltip: "Delete Customer",
                                          onPressed: () async {
                                            await _repo!.deleteCustomer(
                                              customer.id,
                                            );
                                            await _loadCustomers();
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ],
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
    );
  }
}

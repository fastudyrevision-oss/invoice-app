import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../repositories/customer_repository.dart';
import '../db/database_helper.dart';
import 'customer/customer_insights_card.dart';
import 'customer/customer_detail_frame.dart';
import 'common/unified_search_bar.dart';
import '../services/customer_export_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';
import 'customer_payment/customer_payment_dialog.dart';

// Enum for sort mode
enum SortMode { name, pending }

class CustomerFrame extends StatefulWidget {
  const CustomerFrame({super.key});

  @override
  _CustomerFrameState createState() => _CustomerFrameState();
}

class _CustomerFrameState extends State<CustomerFrame> {
  final CustomerExportService _exportService = CustomerExportService();
  CustomerRepository? _repo;

  final List<Customer> _customers = [];
  bool _isLoading = true;
  bool _isLoadingPage = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 50;
  String _searchQuery = '';
  SortMode _sortMode = SortMode.name;
  bool _sortAscending = true;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initRepo();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initRepo() async {
    final db = await DatabaseHelper.instance.db;
    _repo = CustomerRepository(db);
    await _loadNextPage();
    setState(() => _isLoading = false);
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _isLoadingPage) return;
    if (!mounted) return;

    setState(() => _isLoadingPage = true);
    logger.info(
      'CustomerFrame',
      'Loading next customer page',
      context: {'page': _currentPage},
    );

    final sortField = _sortMode == SortMode.name ? 'name' : 'pending_amount';
    final newCustomers = await _repo!.getCustomersPage(
      page: _currentPage,
      pageSize: _pageSize,
      query: _searchQuery,
      sortField: sortField,
      sortAsc: _sortAscending,
    );

    if (newCustomers.isEmpty) {
      _hasMore = false;
    } else {
      _customers.addAll(newCustomers);
      _currentPage++;
    }

    setState(() => _isLoadingPage = false);
  }

  void _onSearchChanged(String query) {
    _searchQuery = query.toLowerCase();
    _resetPagination();
  }

  void _onSortChanged() {
    _resetPagination();
  }

  void _resetPagination() {
    setState(() {
      _customers.clear();
      _currentPage = 0;
      _hasMore = true;
    });
    _loadNextPage();
  }

  Future<void> _handleExport(String outputType) async {
    if (_customers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No data to export')));
      }
      return;
    }

    try {
      if (outputType == 'print') {
        logger.info('CustomerFrame', 'Printing customer report');
        await _exportService.printCustomerReport(_customers);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Sent to printer'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (outputType == 'save') {
        logger.info('CustomerFrame', 'Saving customer report PDF');
        final file = await _exportService.saveCustomerReportPdf(_customers);
        if (mounted && file != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Saved: ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (outputType == 'share') {
        logger.info('CustomerFrame', 'Sharing customer report PDF');
        await _exportService.exportToPDF(_customers);
      }
    } catch (e, stackTrace) {
      logger.error(
        'CustomerFrame',
        'Export error',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ---------------- Dialogs ----------------

  void _showAddCustomerDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Customer"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name *"),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Phone"),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!RegExp(r'^[0-9+]+$').hasMatch(value)) {
                      return 'Invalid phone number';
                    }
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
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
                if (context.mounted) Navigator.pop(context);
                _resetPagination();
              }
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
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: customer.name);
    final phoneController = TextEditingController(text: customer.phone);
    final emailController = TextEditingController(text: customer.email ?? "");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Customer"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name *"),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Phone"),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!RegExp(r'^[0-9+]+$').hasMatch(value)) {
                      return 'Invalid phone number';
                    }
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
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
                if (context.mounted) Navigator.pop(context);
                _resetPagination();
              }
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

  Future<void> _showAddPaymentDialog(Customer customer) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => CustomerPaymentDialog(customers: [customer]),
    );

    if (result == true) {
      // Refresh list to show updated pending amounts
      _resetPagination();
    }
  }

  // ---------------- Build UI ----------------
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveUtils.isMobile(context);
        final appBarBottomHeight = ResponsiveUtils.getAppBarBottomHeight(
          context,
          baseHeight: 120,
        );

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Text(
              "Customers",
              style: TextStyle(
                fontSize: ResponsiveUtils.responsiveFontSize(context, 20),
              ),
            ),
            elevation: 0,
            actions: isMobile
                ? [
                    // On mobile, show only the most important action
                    IconButton(
                      onPressed: _showAddCustomerDialog,
                      icon: const Icon(Icons.add_circle),
                      tooltip: 'Add Customer',
                    ),
                    // Menu for other actions
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        if (value == 'refresh') {
                          _resetPagination();
                        } else {
                          await _handleExport(value);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'print',
                          child: Row(
                            children: [
                              Icon(Icons.print),
                              SizedBox(width: 8),
                              Text('Print List'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'save',
                          child: Row(
                            children: [
                              Icon(Icons.save),
                              SizedBox(width: 8),
                              Text('Save PDF'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share),
                              SizedBox(width: 8),
                              Text('Share PDF'),
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
                      ],
                    ),
                  ]
                : [
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.print),
                      tooltip: 'Print List',
                      onPressed: () => _handleExport('print'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      tooltip: 'Save PDF',
                      onPressed: () => _handleExport('save'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      tooltip: 'Share PDF',
                      onPressed: () => _handleExport('share'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                      onPressed: _resetPagination,
                    ),
                    IconButton(
                      onPressed: _showAddCustomerDialog,
                      icon: const Icon(Icons.add_circle, size: 28),
                      tooltip: 'Add Customer',
                    ),
                    const SizedBox(width: 10),
                  ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(appBarBottomHeight),
              child: Container(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 8 : 16,
                        isMobile ? 6 : 8,
                        isMobile ? 8 : 16,
                        isMobile ? 6 : 8,
                      ),
                      child: UnifiedSearchBar(
                        hintText: "Search by name, phone, email...",
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onClear: () => _onSearchChanged(''),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 8 : 16,
                        isMobile ? 4 : 8,
                        isMobile ? 8 : 16,
                        isMobile ? 8 : 12,
                      ),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Sort chips
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    const Text(
                                      "Sort: ",
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    FilterChip(
                                      label: const Text(
                                        "Name",
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      selected: _sortMode == SortMode.name,
                                      onSelected: (selected) {
                                        setState(() {
                                          _sortMode = SortMode.name;
                                          _onSortChanged();
                                        });
                                      },
                                      selectedColor: Colors.blue.shade100,
                                      checkmarkColor: Colors.blue,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    FilterChip(
                                      label: const Text(
                                        "Pending",
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      selected: _sortMode == SortMode.pending,
                                      onSelected: (selected) {
                                        setState(() {
                                          _sortMode = SortMode.pending;
                                          _onSortChanged();
                                        });
                                      },
                                      selectedColor: Colors.red.shade100,
                                      checkmarkColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    // Order toggle
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _sortAscending = !_sortAscending;
                                          _onSortChanged();
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _sortAscending
                                                  ? Icons.arrow_upward
                                                  : Icons.arrow_downward,
                                              size: 14,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                const Text(
                                  "Sort by: ",
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: const Text("Name"),
                                  selected: _sortMode == SortMode.name,
                                  onSelected: (selected) {
                                    setState(() {
                                      _sortMode = SortMode.name;
                                      _onSortChanged();
                                    });
                                  },
                                  selectedColor: Colors.blue.shade100,
                                  checkmarkColor: Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: const Text("Pending"),
                                  selected: _sortMode == SortMode.pending,
                                  onSelected: (selected) {
                                    setState(() {
                                      _sortMode = SortMode.pending;
                                      _onSortChanged();
                                    });
                                  },
                                  selectedColor: Colors.red.shade100,
                                  checkmarkColor: Colors.red,
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        "Order:",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _sortAscending
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _sortAscending = !_sortAscending;
                                            _onSortChanged();
                                          });
                                        },
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
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
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Insights Card
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: CustomerInsightsCard(
                        customers: _customers,
                        loading: false,
                      ),
                    ),

                    // Customer list
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          _resetPagination();
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: _customers.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _customers.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final customer = _customers[index];
                            final hasPending = customer.pendingAmount > 0;

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    spreadRadius: 1,
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                border: Border.all(
                                  color: hasPending
                                      ? Colors.red.shade200
                                      : Colors.transparent,
                                  width: hasPending ? 1.5 : 0,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Status Strip
                                    if (hasPending)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                          horizontal: 12,
                                        ),
                                        color: Colors.red.shade50,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.account_balance_wallet,
                                              size: 16,
                                              color: Colors.red.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              "Pending Payment",
                                              style: TextStyle(
                                                color: Colors.red.shade900,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                CustomerDetailFrame(
                                                  customer: customer,
                                                  repository: _repo!,
                                                ),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Header: Name & Actions
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        customer.name,
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.phone,
                                                            size: 14,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            customer.phone,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: Colors
                                                                  .grey[700],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Actions
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.payment,
                                                        color: Colors.green,
                                                      ),
                                                      onPressed: () =>
                                                          _showAddPaymentDialog(
                                                            customer,
                                                          ),
                                                      tooltip: 'Add Payment',
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.edit_outlined,
                                                        color: Colors.blue,
                                                      ),
                                                      onPressed: () =>
                                                          _showEditCustomerDialog(
                                                            customer,
                                                          ),
                                                      tooltip: 'Edit',
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        color: Colors.red,
                                                      ),
                                                      onPressed: () async {
                                                        final confirm = await showDialog<bool>(
                                                          context: context,
                                                          builder: (ctx) => AlertDialog(
                                                            title: const Text(
                                                              "Delete Customer?",
                                                            ),
                                                            content: Text(
                                                              "Are you sure you want to delete '${customer.name}'?",
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      ctx,
                                                                      false,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      "Cancel",
                                                                    ),
                                                              ),
                                                              ElevatedButton(
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor:
                                                                      Colors
                                                                          .red,
                                                                  foregroundColor:
                                                                      Colors
                                                                          .white,
                                                                ),
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      ctx,
                                                                      true,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      "Delete",
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        );

                                                        if (confirm == true) {
                                                          await _repo!
                                                              .deleteCustomer(
                                                                customer.id,
                                                              );
                                                          _resetPagination();
                                                        }
                                                      },
                                                      tooltip: 'Delete',
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 12),

                                            // Email Chip (if present)
                                            if (customer.email != null &&
                                                customer.email!.isNotEmpty)
                                              Chip(
                                                avatar: const Icon(
                                                  Icons.email_outlined,
                                                  size: 16,
                                                ),
                                                label: Text(customer.email!),
                                                backgroundColor:
                                                    Colors.purple.shade50,
                                                labelStyle: TextStyle(
                                                  color: Colors.purple.shade900,
                                                  fontSize: 12,
                                                ),
                                                padding: const EdgeInsets.all(
                                                  0,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),

                                            const SizedBox(height: 16),
                                            const Divider(),
                                            const SizedBox(height: 8),

                                            // Pending Amount Metric
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "PENDING AMOUNT",
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors
                                                            .grey
                                                            .shade500,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      "Rs ${customer.pendingAmount.toStringAsFixed(0)}",
                                                      style: TextStyle(
                                                        fontSize: 20,
                                                        color: hasPending
                                                            ? Colors
                                                                  .red
                                                                  .shade700
                                                            : Colors
                                                                  .green
                                                                  .shade700,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (hasPending)
                                                  ElevatedButton.icon(
                                                    onPressed: () =>
                                                        _showAddPaymentDialog(
                                                          customer,
                                                        ),
                                                    icon: const Icon(
                                                      Icons.payment,
                                                      size: 18,
                                                    ),
                                                    label: const Text(
                                                      "Pay Now",
                                                    ),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors
                                                                  .green
                                                                  .shade600,
                                                          foregroundColor:
                                                              Colors.white,
                                                        ),
                                                  )
                                                else
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.green.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors
                                                            .green
                                                            .shade200,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.check_circle,
                                                          size: 16,
                                                          color: Colors
                                                              .green
                                                              .shade700,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          "All Clear",
                                                          style: TextStyle(
                                                            color: Colors
                                                                .green
                                                                .shade900,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
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
        );
      },
    );
  }
}

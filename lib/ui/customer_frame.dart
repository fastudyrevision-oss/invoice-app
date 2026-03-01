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

// Enum for view mode
enum CustomerViewMode { table, compact, card }

class CustomerFrame extends StatefulWidget {
  const CustomerFrame({super.key});

  @override
  State<CustomerFrame> createState() => _CustomerFrameState();
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
  bool _showArchived = false;
  SortMode _sortMode = SortMode.name;
  bool _sortAscending = true;
  CustomerViewMode _viewMode = CustomerViewMode.table;

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
      showArchived: _showArchived,
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

  // ─── Insights Dialog ───
  void _showInsightsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Customer Insights',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: CustomerInsightsCard(
                    customers: _customers,
                    loading: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Dialogs ───

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
                if (!context.mounted) return;
                Navigator.pop(context);
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
                if (!context.mounted) return;
                Navigator.pop(context);
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
      _resetPagination();
    }
  }

  // ─── Archive / Restore ───
  Future<void> _archiveCustomer(Customer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Archive Customer?"),
        content: Text(
          "Are you sure you want to archive '${customer.name}'? Their history will be preserved.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Archive"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repo!.deleteCustomer(customer.id);
      _resetPagination();
    }
  }

  Future<void> _restoreCustomer(Customer customer) async {
    await _repo!.restoreCustomer(customer.id);
    _resetPagination();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Customer restored successfully")),
    );
  }

  // ─── Navigate to detail ───
  void _openCustomerDetail(Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CustomerDetailFrame(customer: customer, repository: _repo!),
      ),
    ).then((_) => _resetPagination());
  }

  // ─── View mode helpers ───
  IconData _viewModeIcon() {
    switch (_viewMode) {
      case CustomerViewMode.table:
        return Icons.table_chart;
      case CustomerViewMode.compact:
        return Icons.view_list;
      case CustomerViewMode.card:
        return Icons.view_agenda;
    }
  }

  void _cycleViewMode() {
    setState(() {
      switch (_viewMode) {
        case CustomerViewMode.table:
          _viewMode = CustomerViewMode.compact;
          break;
        case CustomerViewMode.compact:
          _viewMode = CustomerViewMode.card;
          break;
        case CustomerViewMode.card:
          _viewMode = CustomerViewMode.table;
          break;
      }
    });
  }

  String _viewModeLabel() {
    switch (_viewMode) {
      case CustomerViewMode.table:
        return 'Table';
      case CustomerViewMode.compact:
        return 'Compact';
      case CustomerViewMode.card:
        return 'Card';
    }
  }

  // ─── Build UI ───
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    // Auto-select default: table on desktop, compact on mobile
    // (only on first build – user can override via toggle)

    return LayoutBuilder(
      builder: (context, constraints) {
        final appBarBottomHeight = ResponsiveUtils.getAppBarBottomHeight(
          context,
          baseHeight: 130,
        );

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            title: Text(
              "Customers",
              style: TextStyle(
                fontSize: ResponsiveUtils.responsiveFontSize(context, 20),
              ),
            ),
            elevation: 0,
            actions: isMobile
                ? [
                    // View toggle
                    IconButton(
                      color: Colors.blueAccent,
                      icon: Icon(_viewModeIcon()),
                      tooltip: 'View: ${_viewModeLabel()}',
                      onPressed: _cycleViewMode,
                    ),
                    // Insights button
                    IconButton(
                      icon: const Icon(Icons.insights),
                      tooltip: 'Insights',
                      onPressed: _showInsightsDialog,
                    ),
                    // Add button
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
                    // Insights button
                    IconButton(
                      icon: const Icon(Icons.insights),
                      tooltip: 'Insights',
                      onPressed: _showInsightsDialog,
                    ),
                    const SizedBox(width: 4),
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
                        isMobile ? 4 : 6,
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
                        0,
                        isMobile ? 8 : 16,
                        isMobile ? 6 : 8,
                      ),
                      child: _buildSortChips(isMobile),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(),
        );
      },
    );
  }

  Widget _buildSortChips(bool isMobile) {
    final chips = [
      FilterChip(
        label: Text("Name", style: TextStyle(fontSize: isMobile ? 11 : 13)),
        selected: _sortMode == SortMode.name,
        onSelected: (selected) {
          setState(() {
            _sortMode = SortMode.name;
            _onSortChanged();
          });
        },
        selectedColor: Colors.blue.shade100,
        checkmarkColor: Colors.blue,
        padding: isMobile ? const EdgeInsets.symmetric(horizontal: 4) : null,
        visualDensity: VisualDensity.compact,
      ),
      FilterChip(
        label: Text("Pending", style: TextStyle(fontSize: isMobile ? 11 : 13)),
        selected: _sortMode == SortMode.pending,
        onSelected: (selected) {
          setState(() {
            _sortMode = SortMode.pending;
            _onSortChanged();
          });
        },
        selectedColor: Colors.red.shade100,
        checkmarkColor: Colors.red,
        padding: isMobile ? const EdgeInsets.symmetric(horizontal: 4) : null,
        visualDensity: VisualDensity.compact,
      ),
      FilterChip(
        label: Text("Archived", style: TextStyle(fontSize: isMobile ? 11 : 13)),
        selected: _showArchived,
        onSelected: (selected) {
          setState(() {
            _showArchived = selected;
            _resetPagination();
          });
        },
        selectedColor: Colors.grey.shade300,
        checkmarkColor: Colors.black,
        padding: isMobile ? const EdgeInsets.symmetric(horizontal: 4) : null,
        visualDensity: VisualDensity.compact,
      ),
    ];

    final sortToggle = InkWell(
      onTap: () {
        setState(() {
          _sortAscending = !_sortAscending;
          _onSortChanged();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMobile) const Text("Order:", style: TextStyle(fontSize: 12)),
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: isMobile ? 14 : 18,
            ),
          ],
        ),
      ),
    );

    if (isMobile) {
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text("Sort: ", style: TextStyle(fontSize: isMobile ? 11 : 12)),
          ...chips,
          sortToggle,
        ],
      );
    }

    return Row(
      children: [
        const Text("Sort by: ", style: TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        ...chips.expand((chip) => [chip, const SizedBox(width: 8)]),
        const Spacer(),
        sortToggle,
      ],
    );
  }

  // ─── Body: switch between views ───
  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: () async {
        _resetPagination();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: _viewMode == CustomerViewMode.table
          ? _buildTableView()
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _customers.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _customers.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final customer = _customers[index];
                return _viewMode == CustomerViewMode.compact
                    ? _buildCompactItem(customer)
                    : _buildCardItem(customer);
              },
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TABLE VIEW — DataTable (desktop-optimized, works on mobile)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTableView() {
    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
            dataRowMinHeight: 40,
            dataRowMaxHeight: 52,
            columnSpacing: 24,
            horizontalMargin: 16,
            columns: const [
              DataColumn(
                label: Text(
                  'Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Phone',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Email',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Pending',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                numeric: true,
              ),
              DataColumn(
                label: Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: [
              ..._customers.map((customer) {
                final hasPending = customer.pendingAmount > 0;
                return DataRow(
                  color: hasPending
                      ? WidgetStateProperty.all(Colors.red.shade50)
                      : null,
                  cells: [
                    DataCell(
                      Text(
                        customer.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => _openCustomerDetail(customer),
                    ),
                    DataCell(
                      Text(customer.phone),
                      onTap: () => _openCustomerDetail(customer),
                    ),
                    DataCell(
                      Text(customer.email ?? '—'),
                      onTap: () => _openCustomerDetail(customer),
                    ),
                    DataCell(
                      Text(
                        'Rs ${customer.pendingAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasPending
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                      onTap: () => _openCustomerDetail(customer),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: hasPending
                              ? Colors.orange.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          hasPending ? 'Pending' : 'Clear',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: hasPending
                                ? Colors.orange.shade900
                                : Colors.green.shade900,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: _buildActionButtons(customer, compact: true),
                      ),
                    ),
                  ],
                );
              }),
              if (_hasMore)
                DataRow(
                  cells: List.generate(6, (_) => const DataCell(SizedBox())),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // COMPACT VIEW — dense ListTile (mobile-optimized)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCompactItem(Customer customer) {
    final hasPending = customer.pendingAmount > 0;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: hasPending
            ? BorderSide(color: Colors.red.shade200, width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openCustomerDetail(customer),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: hasPending
                    ? Colors.red.shade100
                    : Colors.blue.shade100,
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: hasPending
                        ? Colors.red.shade700
                        : Colors.blue.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Name + phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (customer.phone.isNotEmpty)
                      Text(
                        customer.phone,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              // Pending amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rs ${customer.pendingAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: hasPending
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                  if (hasPending)
                    Text(
                      'Pending',
                      style: TextStyle(fontSize: 9, color: Colors.red.shade400),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              // Quick action popup
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (value) async {
                  switch (value) {
                    case 'payment':
                      _showAddPaymentDialog(customer);
                      break;
                    case 'edit':
                      _showEditCustomerDialog(customer);
                      break;
                    case 'archive':
                      _archiveCustomer(customer);
                      break;
                    case 'restore':
                      _restoreCustomer(customer);
                      break;
                  }
                },
                itemBuilder: (_) => _showArchived
                    ? [
                        const PopupMenuItem(
                          value: 'restore',
                          child: Text('Restore'),
                        ),
                      ]
                    : [
                        const PopupMenuItem(
                          value: 'payment',
                          child: Text('Add Payment'),
                        ),
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                          value: 'archive',
                          child: Text('Archive'),
                        ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CARD VIEW — original rich card (preserved from before)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCardItem(Customer customer) {
    final hasPending = customer.pendingAmount > 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          color: hasPending ? Colors.red.shade200 : Colors.transparent,
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
              onTap: () => _openCustomerDetail(customer),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Name & Actions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    customer.phone,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Actions
                        Row(
                          children: _buildActionButtons(
                            customer,
                            compact: false,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Email Chip (if present)
                    if (customer.email != null && customer.email!.isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.email_outlined, size: 16),
                        label: Text(customer.email!),
                        backgroundColor: Colors.purple.shade50,
                        labelStyle: TextStyle(
                          color: Colors.purple.shade900,
                          fontSize: 12,
                        ),
                        padding: const EdgeInsets.all(0),
                        visualDensity: VisualDensity.compact,
                      ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Pending Amount Metric
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "PENDING AMOUNT",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Rs ${customer.pendingAmount.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 20,
                                color: hasPending
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (hasPending)
                          ElevatedButton.icon(
                            onPressed: () => _showAddPaymentDialog(customer),
                            icon: const Icon(Icons.payment, size: 18),
                            label: const Text("Pay Now"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "All Clear",
                                  style: TextStyle(
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.bold,
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
  }

  // ─── Shared action buttons builder ───
  List<Widget> _buildActionButtons(Customer customer, {required bool compact}) {
    final iconSize = compact ? 18.0 : 24.0;
    if (_showArchived) {
      return [
        IconButton(
          icon: Icon(Icons.restore, color: Colors.green, size: iconSize),
          onPressed: () => _restoreCustomer(customer),
          tooltip: 'Restore Customer',
          constraints: compact ? const BoxConstraints() : null,
          padding: compact ? const EdgeInsets.all(4) : null,
        ),
      ];
    }
    return [
      IconButton(
        icon: Icon(Icons.payment, color: Colors.green, size: iconSize),
        onPressed: () => _showAddPaymentDialog(customer),
        tooltip: 'Add Payment',
        constraints: compact ? const BoxConstraints() : null,
        padding: compact ? const EdgeInsets.all(4) : null,
      ),
      IconButton(
        icon: Icon(Icons.edit_outlined, color: Colors.blue, size: iconSize),
        onPressed: () => _showEditCustomerDialog(customer),
        tooltip: 'Edit',
        constraints: compact ? const BoxConstraints() : null,
        padding: compact ? const EdgeInsets.all(4) : null,
      ),
      IconButton(
        icon: Icon(Icons.delete_outline, color: Colors.red, size: iconSize),
        onPressed: () => _archiveCustomer(customer),
        tooltip: 'Archive',
        constraints: compact ? const BoxConstraints() : null,
        padding: compact ? const EdgeInsets.all(4) : null,
      ),
    ];
  }
}

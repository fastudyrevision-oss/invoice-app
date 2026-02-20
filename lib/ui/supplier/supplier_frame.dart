import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../repositories/supplier_repo.dart';
import '../../repositories/supplier_payment_repo.dart';
import '../../repositories/purchase_repo.dart';
import '../../models/supplier.dart';
import '../../models/supplier_company.dart';
import '../../services/supplier_export_service.dart';
import 'supplier_detail_frame.dart';
import 'supplier_form_frame.dart';
import 'supplier_company_frame.dart';
import 'supplier_insights_card.dart';
import '../common/unified_search_bar.dart';
import '../../utils/responsive_utils.dart';
import '../../services/logger_service.dart';

enum SupplierViewMode { table, compact, card }

class SupplierFrame extends StatefulWidget {
  final SupplierRepository repo;
  final SupplierPaymentRepository repo2;
  final PurchaseRepository purchaseRepo;
  const SupplierFrame({
    super.key,
    required this.repo,
    required this.repo2,
    required this.purchaseRepo,
  });

  @override
  State<SupplierFrame> createState() => _SupplierFrameState();
}

class _SupplierFrameState extends State<SupplierFrame> {
  bool _showDeleted = false;
  String _searchKeyword = "";
  List<SupplierCompany> _companies = [];
  SupplierCompany? _selectedCompany;
  List<Supplier> _suppliers = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 50;
  final ScrollController _scrollController = ScrollController();
  late final SupplierCompany allCompaniesOption;
  bool? _pendingFilter;
  final TextEditingController _minCreditCtrl = TextEditingController();
  final TextEditingController _maxCreditCtrl = TextEditingController();
  final TextEditingController _minPendingCtrl = TextEditingController();
  final TextEditingController _maxPendingCtrl = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  SupplierViewMode _viewMode = SupplierViewMode.card;

  IconData _viewModeIcon() {
    switch (_viewMode) {
      case SupplierViewMode.table:
        return Icons.table_chart;
      case SupplierViewMode.compact:
        return Icons.view_list;
      case SupplierViewMode.card:
        return Icons.grid_view;
    }
  }

  String _viewModeLabel() {
    switch (_viewMode) {
      case SupplierViewMode.table:
        return 'Table';
      case SupplierViewMode.compact:
        return 'Compact';
      case SupplierViewMode.card:
        return 'Card';
    }
  }

  void _cycleViewMode() {
    setState(() {
      _viewMode = SupplierViewMode
          .values[(_viewMode.index + 1) % SupplierViewMode.values.length];
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
                title: const Text("Supplier Insights"),
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
                  child: SupplierInsightsCard(
                    suppliers: _suppliers,
                    loading: false,
                    lastUpdated: DateTime.now(),
                    companiesCount: _companies
                        .where((c) => c.id != '-1')
                        .length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController.text = _searchKeyword;
    allCompaniesOption = SupplierCompany(
      id: "-1",
      name: "All Companies",
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadNextPage();
      }
    });

    _loadCompanies();
    _resetAndLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _minCreditCtrl.dispose();
    _maxCreditCtrl.dispose();
    _minPendingCtrl.dispose();
    _maxPendingCtrl.dispose();
    super.dispose();
  }

  void _resetAndLoad() {
    _suppliers = [];
    _currentPage = 0;
    _hasMore = true;
    _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);
    logger.info(
      'SupplierFrame',
      'Loading next supplier page',
      context: {'page': _currentPage},
    );

    try {
      final nextPage = await widget.repo.getSuppliersPaged(
        page: _currentPage,
        pageSize: _pageSize,
        keyword: _searchKeyword,
        showDeleted: _showDeleted,
      );

      final filtered = nextPage.where((s) {
        final minCredit =
            double.tryParse(_minCreditCtrl.text) ?? double.negativeInfinity;
        final maxCredit =
            double.tryParse(_maxCreditCtrl.text) ?? double.infinity;
        if (s.creditLimit < minCredit || s.creditLimit > maxCredit) {
          return false;
        }

        final minPending =
            double.tryParse(_minPendingCtrl.text) ?? double.negativeInfinity;
        final maxPending =
            double.tryParse(_maxPendingCtrl.text) ?? double.infinity;
        if (s.pendingAmount < minPending || s.pendingAmount > maxPending) {
          return false;
        }

        if (_selectedCompany != null && _selectedCompany!.id != "-1") {
          if (s.companyId != _selectedCompany!.id) return false;
        }
        if (_pendingFilter != null) {
          if (_pendingFilter == true && s.pendingAmount <= 0) return false;
          if (_pendingFilter == false && s.pendingAmount > 0) return false;
        }
        return true;
      }).toList();

      setState(() {
        _suppliers.addAll(filtered);
        _isLoading = false;
        _currentPage++;
        if (nextPage.length < _pageSize) _hasMore = false;
      });
    } catch (e, stackTrace) {
      logger.error(
        'SupplierFrame',
        'Error loading suppliers',
        error: e,
        stackTrace: stackTrace,
      );
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading suppliers: $e")));
      }
    }
  }

  Future<void> _loadCompanies() async {
    final allCompanies = await widget.repo.getAllCompanies();
    setState(() {
      _companies = allCompanies;
      _companies.insert(0, allCompaniesOption);
    });
  }

  Future<void> _editSupplier(Supplier supplier) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SupplierFormFrame(repo: widget.repo, supplier: supplier),
      ),
    );
    if (result == true) _resetAndLoad();
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Supplier"),
        content: Text("Are you sure you want to delete '${supplier.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repo.deleteSupplier(supplier.id);
      _resetAndLoad();
    }
  }

  Future<void> _restoreSupplier(Supplier supplier) async {
    await widget.repo.restoreSupplier(supplier.id);
    _resetAndLoad();
  }

  Future<void> _handleExport(String outputType) async {
    if (_suppliers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No suppliers to export')));
      return;
    }

    final exportService = SupplierExportService();
    final companyName = _selectedCompany?.name;
    final companyNames = {for (var c in _companies) c.id: c.name};
    final minCredit = double.tryParse(_minCreditCtrl.text);
    final maxCredit = double.tryParse(_maxCreditCtrl.text);
    final minPending = double.tryParse(_minPendingCtrl.text);
    final maxPending = double.tryParse(_maxPendingCtrl.text);

    try {
      if (outputType == 'print') {
        logger.info('SupplierFrame', 'Printing supplier list');
        await exportService.printSupplierList(
          _suppliers,
          searchKeyword: _searchKeyword.isNotEmpty ? _searchKeyword : null,
          companyName: companyName,
          companyNames: companyNames,
          pendingFilter: _pendingFilter,
          minCredit: minCredit,
          maxCredit: maxCredit,
          minPending: minPending,
          maxPending: maxPending,
          showDeleted: _showDeleted,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Sent to printer'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (outputType == 'save') {
        logger.info('SupplierFrame', 'Saving supplier list PDF');
        final file = await exportService.saveSupplierListPdf(
          _suppliers,
          searchKeyword: _searchKeyword.isNotEmpty ? _searchKeyword : null,
          companyName: companyName,
          companyNames: companyNames,
          pendingFilter: _pendingFilter,
          minCredit: minCredit,
          maxCredit: maxCredit,
          minPending: minPending,
          maxPending: maxPending,
          showDeleted: _showDeleted,
        );
        if (mounted && file != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Saved: ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (outputType == 'share') {
        logger.info('SupplierFrame', 'Sharing supplier list PDF');
        await exportService.exportToPDF(
          _suppliers,
          searchKeyword: _searchKeyword.isNotEmpty ? _searchKeyword : null,
          companyName: companyName,
          companyNames: companyNames,
          pendingFilter: _pendingFilter,
          minCredit: minCredit,
          maxCredit: maxCredit,
          minPending: minPending,
          maxPending: maxPending,
          showDeleted: _showDeleted,
        );
      }
    } catch (e, stackTrace) {
      logger.error(
        'SupplierFrame',
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

  Widget _buildFilterBar() {
    return Container(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: UnifiedSearchBar(
              hintText: "Search by name or phone...",
              controller: _searchController,
              onChanged: (val) {
                _searchKeyword = val;
                _resetAndLoad();
              },
              onClear: () {
                setState(() {
                  _searchKeyword = "";
                  _resetAndLoad();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownSearch<SupplierCompany>(
                    items: (filter, props) => _companies,
                    selectedItem: _selectedCompany ?? allCompaniesOption,
                    itemAsString: (c) => c.name,
                    compareFn: (a, b) => a.id == b.id,
                    popupProps: const PopupProps.modalBottomSheet(
                      showSearchBox: true,
                      constraints: BoxConstraints(maxHeight: 500),
                    ),
                    decoratorProps: DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: "Company",
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    onChanged: (c) {
                      setState(() {
                        if (c != null && c.id == "-1") {
                          _selectedCompany = null;
                        } else {
                          _selectedCompany = c;
                        }
                        _resetAndLoad();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text("All"),
                    selected: _pendingFilter == null,
                    onSelected: (selected) {
                      setState(() {
                        _pendingFilter = null;
                        _resetAndLoad();
                      });
                    },
                    selectedColor: Colors.blue.shade100,
                    checkmarkColor: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text("Pending"),
                    selected: _pendingFilter == true,
                    onSelected: (selected) {
                      setState(() {
                        _pendingFilter = true;
                        _resetAndLoad();
                      });
                    },
                    selectedColor: Colors.red.shade100,
                    checkmarkColor: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text("Paid"),
                    selected: _pendingFilter == false,
                    onSelected: (selected) {
                      setState(() {
                        _pendingFilter = false;
                        _resetAndLoad();
                      });
                    },
                    selectedColor: Colors.green.shade100,
                    checkmarkColor: Colors.green,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _suppliers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 72,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "No suppliers found",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    _resetAndLoad();
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: _viewMode == SupplierViewMode.table
                      ? _buildTableView()
                      : _viewMode == SupplierViewMode.compact
                      ? ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _suppliers.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (index >= _suppliers.length) {
                              return const _LoadingFooter();
                            }
                            return _buildCompactItem(_suppliers[index]);
                          },
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: _suppliers.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _suppliers.length) {
                              return const _LoadingFooter();
                            }
                            return _buildCardItem(_suppliers[index]);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Company')),
            DataColumn(label: Text('Pending Amount')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _suppliers.map((s) {
            final company = _companies.firstWhere(
              (c) => c.id == s.companyId,
              orElse: () => allCompaniesOption,
            );
            final isDeleted = s.deleted == 1;

            return DataRow(
              color: isDeleted
                  ? WidgetStateProperty.all(Colors.grey.shade100)
                  : null,
              cells: [
                DataCell(
                  Text(
                    s.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: isDeleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                DataCell(Text(s.phone ?? "")),
                DataCell(Text(company.name)),
                DataCell(
                  Text(
                    "Rs ${s.pendingAmount.toStringAsFixed(0)}",
                    style: TextStyle(
                      color: s.pendingAmount > 0 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(_buildStatusChip(s)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 20),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SupplierDetailFrame(
                              supplier: s,
                              repo: widget.repo,
                              repo2: widget.repo2,
                              purchaseRepo: widget.purchaseRepo,
                            ),
                          ),
                        ).then((_) => _resetAndLoad()),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onPressed: () => _showSupplierActions(context, s),
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

  Widget _buildCompactItem(Supplier s) {
    final company = _companies.firstWhere(
      (c) => c.id == s.companyId,
      orElse: () => allCompaniesOption,
    );
    final hasPending = s.pendingAmount > 0;
    final isDeleted = s.deleted == 1;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (hasPending ? Colors.orange : Colors.blue).withValues(
          alpha: 0.1,
        ),
        child: Text(
          s.name[0].toUpperCase(),
          style: TextStyle(
            color: hasPending ? Colors.orange : Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        s.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          decoration: isDeleted ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text("${company.name} • ${s.phone}"),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            "Rs ${s.pendingAmount.toStringAsFixed(0)}",
            style: TextStyle(
              color: hasPending ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isDeleted)
            const Text(
              "DELETED",
              style: TextStyle(color: Colors.red, fontSize: 10),
            ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SupplierDetailFrame(
            supplier: s,
            repo: widget.repo,
            repo2: widget.repo2,
            purchaseRepo: widget.purchaseRepo,
          ),
        ),
      ).then((_) => _resetAndLoad()),
    );
  }

  Widget _buildCardItem(Supplier s) {
    final isDeleted = s.deleted == 1;
    final hasPending = s.pendingAmount > 0;
    final company = _companies.firstWhere(
      (c) => c.id == s.companyId,
      orElse: () => allCompaniesOption,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDeleted ? Colors.grey.shade300 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: hasPending
              ? Colors.orange.withValues(alpha: 0.3)
              : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: (hasPending ? Colors.orange : Colors.blue)
              .withValues(alpha: 0.1),
          radius: 28,
          child: Text(
            s.name[0].toUpperCase(),
            style: TextStyle(
              color: hasPending ? Colors.orange : Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                s.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            if (isDeleted) _buildDeletedBadge(),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _buildInfoRow(Icons.business, company.name),
            const SizedBox(height: 2),
            _buildInfoRow(Icons.phone, s.phone ?? ""),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "Pending",
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            Text(
              "Rs ${s.pendingAmount.toStringAsFixed(0)}",
              style: TextStyle(
                color: hasPending ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SupplierDetailFrame(
              supplier: s,
              repo: widget.repo,
              repo2: widget.repo2,
              purchaseRepo: widget.purchaseRepo,
            ),
          ),
        ).then((_) => _resetAndLoad()),
        onLongPress: () => _showSupplierActions(context, s),
      ),
    );
  }

  Widget _buildStatusChip(Supplier s) {
    final hasPending = s.pendingAmount > 0;
    final color = hasPending ? Colors.orange : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        hasPending ? "PENDING" : "PAID",
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDeletedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        "DELETED",
        style: TextStyle(
          color: Colors.red,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  void _showSupplierActions(BuildContext context, Supplier supplier) {
    final isDeleted = supplier.deleted == 1;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.blue),
              title: const Text("View Details"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupplierDetailFrame(
                      supplier: supplier,
                      repo: widget.repo,
                      repo2: widget.repo2,
                      purchaseRepo: widget.purchaseRepo,
                    ),
                  ),
                ).then((_) => _resetAndLoad());
              },
            ),
            if (!isDeleted) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.orange),
                title: const Text("Edit Supplier"),
                onTap: () {
                  Navigator.pop(context);
                  _editSupplier(supplier);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text("Delete Supplier"),
                onTap: () {
                  Navigator.pop(context);
                  _deleteSupplier(supplier);
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.green),
                title: const Text("Restore Supplier"),
                onTap: () {
                  Navigator.pop(context);
                  _restoreSupplier(supplier);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text("Suppliers & Companies"),
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person), text: "Suppliers"),
              Tab(icon: Icon(Icons.business), text: "Companies"),
            ],
          ),
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
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'print' ||
                          value == 'save' ||
                          value == 'share') {
                        _handleExport(value);
                      } else if (value == 'toggle_deleted') {
                        setState(() {
                          _showDeleted = !_showDeleted;
                          _resetAndLoad();
                        });
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
                      PopupMenuItem(
                        value: 'toggle_deleted',
                        child: Row(
                          children: [
                            Icon(
                              _showDeleted
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            SizedBox(width: 8),
                            Text(
                              _showDeleted ? 'Hide Deleted' : 'Show Deleted',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ]
              : [
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
                  IconButton(
                    icon: const Icon(Icons.insights),
                    tooltip: 'Insights',
                    onPressed: _showInsightsDialog,
                  ),
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
                  const SizedBox(width: 10),
                  IconButton(
                    icon: Icon(
                      _showDeleted ? Icons.visibility_off : Icons.visibility,
                    ),
                    tooltip: _showDeleted ? "Hide Deleted" : "Show Deleted",
                    onPressed: () {
                      setState(() {
                        _showDeleted = !_showDeleted;
                        _resetAndLoad();
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                ],
        ),
        body: TabBarView(
          children: [
            _buildBody(),
            SupplierCompanyFrame(repo: widget.repo),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabIndex = DefaultTabController.of(context).index;
            if (tabIndex == 0) {
              return FloatingActionButton(
                heroTag: null,
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupplierFormFrame(repo: widget.repo),
                    ),
                  );
                  if (result == true) _resetAndLoad();
                },
                child: const Icon(Icons.person_add),
              );
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }
}

class _LoadingFooter extends StatelessWidget {
  const _LoadingFooter();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

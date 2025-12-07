import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../repositories/supplier_repo.dart';
import '../../repositories/supplier_payment_repo.dart';
import '../../models/supplier.dart';
import '../../models/supplier_company.dart';
import '../../services/supplier_export_service.dart';
import 'supplier_detail_frame.dart';
import 'supplier_form_frame.dart';
import 'supplier_company_frame.dart';
import 'supplier_insights_card.dart';
import '../common/unified_search_bar.dart';
import '../../utils/responsive_utils.dart';

class SupplierFrame extends StatefulWidget {
  final SupplierRepository repo;
  final SupplierPaymentRepository repo2;
  const SupplierFrame({super.key, required this.repo, required this.repo2});

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
  final int _pageSize = 50; // Optimized for 1000+ suppliers
  final ScrollController _scrollController = ScrollController();
  // Dummy "All Companies" option
  late final SupplierCompany allCompaniesOption;
  // Payment status filter: null = All, true = Pending, false = Paid
  bool? _pendingFilter;
  // Controllers for credit limit range
  final TextEditingController _minCreditCtrl = TextEditingController();
  final TextEditingController _maxCreditCtrl = TextEditingController();

  final TextEditingController _minPendingCtrl = TextEditingController();
  final TextEditingController _maxPendingCtrl = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

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

    try {
      final nextPage = await widget.repo.getSuppliersPaged(
        page: _currentPage,
        pageSize: _pageSize,
        keyword: _searchKeyword,
        showDeleted: _showDeleted,
      );

      // Apply filters
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

        // Company filter
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
    } catch (e) {
      debugPrint("Error loading suppliers: $e");
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
      _companies.insert(0, allCompaniesOption); // adds at the beginning
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
      await widget.repo.deleteSupplier(supplier.id); // <- actually delete
      _resetAndLoad();
    }
  }

  Future<void> _restoreSupplier(Supplier supplier) async {
    await widget.repo.restoreSupplier(supplier.id);
    _resetAndLoad();
  }

  Future<void> _exportToPDF() async {
    if (_suppliers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No suppliers to export')));
      return;
    }

    final exportService = SupplierExportService();
    await exportService.exportToPDF(
      _suppliers,
      searchKeyword: _searchKeyword.isNotEmpty ? _searchKeyword : null,
      companyName: _selectedCompany?.name,
      pendingFilter: _pendingFilter,
      minCredit: double.tryParse(_minCreditCtrl.text),
      maxCredit: double.tryParse(_maxCreditCtrl.text),
      minPending: double.tryParse(_minPendingCtrl.text),
      maxPending: double.tryParse(_maxPendingCtrl.text),
      showDeleted: _showDeleted,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF exported successfully!')),
      );
    }
  }

  // --- Credit Limit Range Filter ---
  Widget _buildCreditLimitFilter() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          child: TextField(
            controller: _minCreditCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Min Pending"),
            onSubmitted: (_) => _resetAndLoad(),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 80,
          child: TextField(
            controller: _maxCreditCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Max Pending"),
            onSubmitted: (_) => _resetAndLoad(),
          ),
        ),
      ],
    );
  }

  // --- Credit Limit Range Filter ---
  Widget _buildPendingLimitFilter() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          child: TextField(
            controller: _minPendingCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Min Credit"),
            onSubmitted: (_) => _resetAndLoad(),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 80,
          child: TextField(
            controller: _maxPendingCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Max Credit"),
            onSubmitted: (_) => _resetAndLoad(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.05),
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
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      fit: FlexFit.loose,
                      constraints: const BoxConstraints(maxHeight: 300),
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
              actions: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'Export to PDF',
                  onPressed: _exportToPDF,
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
                // --- SUPPLIERS TAB ---
                Column(
                  children: [
                    _buildFilterBar(),

                    // Supplier Insights Card
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SupplierInsightsCard(
                        suppliers: _suppliers,
                        loading: false,
                        lastUpdated: DateTime.now(),
                        companiesCount: _companies
                            .where((c) => c.id != '-1')
                            .length,
                      ),
                    ),

                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _suppliers.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _suppliers.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final supplier = _suppliers[index];
                          final isDeleted = supplier.deleted == 1;
                          final hasPending = supplier.pendingAmount > 0;
                          final company = _companies.firstWhere(
                            (c) => c.id == supplier.companyId,
                            orElse: () => SupplierCompany(
                              id: "0",
                              name: "No Company",
                              createdAt: DateTime.now().toIso8601String(),
                              updatedAt: DateTime.now().toIso8601String(),
                            ),
                          );

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDeleted
                                  ? Colors.grey.shade300
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              border: Border.all(
                                color: isDeleted
                                    ? Colors.grey.shade400
                                    : hasPending
                                    ? Colors.red.shade200
                                    : Colors.transparent,
                                width: isDeleted || hasPending ? 1.5 : 0,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Status Strip
                                  if (isDeleted)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 12,
                                      ),
                                      color: Colors.grey.shade400,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline,
                                            size: 16,
                                            color: Colors.grey.shade700,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Deleted Supplier",
                                            style: TextStyle(
                                              color: Colors.grey.shade900,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (hasPending)
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
                                          builder: (_) => SupplierDetailFrame(
                                            repo: widget.repo,
                                            repo2: widget.repo2,
                                            supplier: supplier,
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
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      supplier.name,
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: isDeleted
                                                            ? Colors
                                                                  .grey
                                                                  .shade700
                                                            : Colors.black87,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    if (supplier.phone != null)
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
                                                            supplier.phone!,
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
                                              if (!isDeleted)
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.edit_outlined,
                                                        color: Colors.blue,
                                                      ),
                                                      onPressed: () =>
                                                          _editSupplier(
                                                            supplier,
                                                          ),
                                                      tooltip: 'Edit',
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        color: Colors.red,
                                                      ),
                                                      onPressed: () =>
                                                          _deleteSupplier(
                                                            supplier,
                                                          ),
                                                      tooltip: 'Delete',
                                                    ),
                                                  ],
                                                )
                                              else
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.restore,
                                                    color: Colors.orange,
                                                  ),
                                                  onPressed: () =>
                                                      _restoreSupplier(
                                                        supplier,
                                                      ),
                                                  tooltip: 'Restore',
                                                ),
                                            ],
                                          ),

                                          const SizedBox(height: 12),

                                          // Company Chip
                                          if (company.id != "0")
                                            Chip(
                                              avatar: const Icon(
                                                Icons.business,
                                                size: 16,
                                              ),
                                              label: Text(company.name),
                                              backgroundColor:
                                                  Colors.blue.shade50,
                                              labelStyle: TextStyle(
                                                color: Colors.blue.shade900,
                                                fontSize: 12,
                                              ),
                                              padding: const EdgeInsets.all(0),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),

                                          const SizedBox(height: 16),
                                          const Divider(),
                                          const SizedBox(height: 8),

                                          // Metrics Row
                                          // Metrics Row
                                          isMobile
                                              ? Column(
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              "PENDING AMOUNT",
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: Colors
                                                                    .grey
                                                                    .shade500,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              "Rs ${supplier.pendingAmount.toStringAsFixed(0)}",
                                                              style: TextStyle(
                                                                fontSize: 20,
                                                                color:
                                                                    hasPending
                                                                    ? Colors
                                                                          .red
                                                                          .shade700
                                                                    : Colors
                                                                          .green
                                                                          .shade700,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              "CREDIT LIMIT",
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: Colors
                                                                    .grey
                                                                    .shade500,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              "Rs ${supplier.creditLimit.toStringAsFixed(0)}",
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                color: Colors
                                                                    .blue
                                                                    .shade700,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
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
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          "Rs ${supplier.pendingAmount.toStringAsFixed(0)}",
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
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: [
                                                        Text(
                                                          "CREDIT LIMIT",
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors
                                                                .grey
                                                                .shade500,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          "Rs ${supplier.creditLimit.toStringAsFixed(0)}",
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            color: Colors
                                                                .blue
                                                                .shade700,
                                                            fontWeight:
                                                                FontWeight.bold,
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
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                // --- COMPANIES TAB ---
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
      },
    );
  }
}

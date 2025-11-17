import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../repositories/supplier_repo.dart';
import '../../repositories/supplier_payment_repo.dart';
import '../../models/supplier.dart';
import '../../models/supplier_company.dart';
import 'supplier_detail_frame.dart';
import 'supplier_form_frame.dart';
import 'supplier_company_frame.dart';

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
  final int _pageSize = 10;
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


  @override
  void initState() {
    super.initState();
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

  void _resetAndLoad() {
    _suppliers = [];
    _currentPage = 0;
    _hasMore = true;
    _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    

    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    final nextPage = await widget.repo.getSuppliersPaged(
      page: _currentPage,
      pageSize: _pageSize,
      keyword: _searchKeyword,
      showDeleted: _showDeleted,
    );

    // Apply filters
    final filtered = nextPage.where((s) {
      final minCredit = double.tryParse(_minCreditCtrl.text) ?? double.negativeInfinity;
final maxCredit = double.tryParse(_maxCreditCtrl.text) ?? double.infinity;
if (s.creditLimit < minCredit || s.creditLimit > maxCredit) return false;

final minPending = double.tryParse(_minPendingCtrl.text) ?? double.negativeInfinity;
final maxPending = double.tryParse(_maxPendingCtrl.text) ?? double.infinity;
if (s.pendingAmount < minPending || s.pendingAmount > maxPending) return false;

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
        builder: (_) => SupplierFormFrame(repo: widget.repo, supplier: supplier),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
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

  Widget _buildFilterSection() {
    

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              // Company DropdownSearch
              Expanded(
                child: DropdownSearch<SupplierCompany>(
                  items: (filter , props) => _companies,
                  selectedItem: _selectedCompany ?? allCompaniesOption ,
                  itemAsString: (c) => c.name,
                  compareFn: (a, b) => a.id == b.id,
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    fit: FlexFit.loose,
                  ),
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: "Filter by Company",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  onChanged: (c) {
                    setState(() {
                      if (c != null && c.id == "-1") {
                        _selectedCompany = null; // Show all
                      } else {
                        _selectedCompany = c;
                      }
                      _resetAndLoad();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Search button
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () async {
                  final keyword = await showDialog<String>(
                    context: context,
                    builder: (ctx) {
                      final ctrl = TextEditingController(text: _searchKeyword);
                      return AlertDialog(
                        title: const Text("Search Supplier"),
                        content: TextField(
                          controller: ctrl,
                          decoration: const InputDecoration(labelText: "Name or Phone"),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                              child: const Text("Search")),
                        ],
                      );
                    },
                  );
                  if (keyword != null) {
                    _searchKeyword = keyword;
                    _resetAndLoad();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Pending/ Paid / All filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _pendingFilter == null
                      ? "All"
                      : _pendingFilter == true
                          ? "Pending"
                          : "Paid",
                  items: const [
                    DropdownMenuItem(value: "All", child: Text("All")),
                    DropdownMenuItem(value: "Pending", child: Text("Pending")),
                    DropdownMenuItem(value: "Paid", child: Text("Paid")),
                  ],
                  decoration: const InputDecoration(
                    labelText: "Payment Status",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    setState(() {
                      if (v == "Pending") {
                        _pendingFilter = true;
                      } else if (v == "Paid") _pendingFilter = false;
                      else _pendingFilter = null;
                      _resetAndLoad();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
        _buildCreditLimitFilter(),
         const SizedBox(width: 8),
        _buildPendingLimitFilter(),
              // TODO: Add range filter / additional filters if needed
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Suppliers & Companies"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person), text: "Suppliers"),
              Tab(icon: Icon(Icons.business), text: "Companies"),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(_showDeleted ? Icons.visibility_off : Icons.visibility),
              tooltip: _showDeleted ? "Hide Deleted" : "Show Deleted",
              onPressed: () {
                setState(() {
                  _showDeleted = !_showDeleted;
                  _resetAndLoad();
                });
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // --- SUPPLIERS TAB ---
            Column(
              children: [
                _buildFilterSection(),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _suppliers.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _suppliers.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _loadNextPage,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text("Load More"),
                          ),
                        );
                      }

                      final supplier = _suppliers[index];
                      final isDeleted = supplier.deleted == 1;

                      return Card(
                        color: isDeleted ? const Color.fromARGB(255, 204, 93, 93) : null,
                        child: ListTile(
                          leading: CircleAvatar(child: Text("${index + 1}")),
                          title: Text(supplier.name),
                          subtitle: Text(supplier.phone ?? "No phone"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Pending: ${supplier.pendingAmount.toStringAsFixed(2)}",
                                style: const TextStyle(color: Colors.red),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editSupplier(supplier);
                                  } else if (value == 'delete') _deleteSupplier(supplier);
                                  else if (value == 'restore') _restoreSupplier(supplier);
                                },
                                itemBuilder: (ctx) => [
                                  if (!isDeleted) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  if (!isDeleted) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  if (isDeleted) const PopupMenuItem(value: 'restore', child: Text('Restore')),
                                ],
                              ),
                            ],
                          ),
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
                    MaterialPageRoute(builder: (_) => SupplierFormFrame(repo: widget.repo)),
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

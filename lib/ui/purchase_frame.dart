// Enhanced PurchaseFrame with search, sorting, filtering, and lazy loading
// NOTE: Integrate into your project and adjust repos and models if needed.

import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../repositories/purchase_repo.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_repo.dart';
import '../models/purchase.dart';
import '../models/supplier.dart';
import 'purchase_detail_frame.dart';
import 'purchase_form.dart';
import 'purchase_insights_card.dart';

class PurchaseFrame extends StatefulWidget {
  final PurchaseRepository repo;
  final ProductRepository productRepo;
  final SupplierRepository supplierRepo;

  const PurchaseFrame({
    super.key,
    required this.repo,
    required this.productRepo,
    required this.supplierRepo,
  });

  @override
  State<PurchaseFrame> createState() => _PurchaseFrameState();
}

class _PurchaseFrameState extends State<PurchaseFrame> {
  List<Purchase> _allPurchases = [];
  List<Purchase> _displayedPurchases = [];
  List<Supplier> _suppliers = [];

  int _currentPage = 1;
  final int _pageSize = 20;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  String _searchQuery = "";
  String? _selectedSupplierId;
  final String _sortBy = "date_desc";

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final suppliers = await widget.supplierRepo.getAllSuppliers();
    final purchases = await widget.repo.getAllPurchases();

    setState(() {
      _suppliers = suppliers;
      _allPurchases = purchases;
    });

    _applyFilters();
  }

  void _applyFilters() {
    List<Purchase> filtered = [..._allPurchases];

    // Search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) => p.invoiceNo.contains(_searchQuery)).toList();
    }

    // Filter by supplier
    if (_selectedSupplierId != null) {
      filtered = filtered.where((p) => p.supplierId == _selectedSupplierId).toList();
    }

    // Sorting
    if (_sortBy == "date_desc") {
      filtered.sort((a, b) => b.date.compareTo(a.date));
    } else if (_sortBy == "date_asc") {
      filtered.sort((a, b) => a.date.compareTo(b.date));
    } else if (_sortBy == "total_desc") {
      filtered.sort((a, b) => b.total.compareTo(a.total));
    }

    _currentPage = 1;
    _hasMore = true;
    _displayedPurchases = filtered.take(_pageSize).toList();

    setState(() {});
  }

  void _loadMore() {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    Future.delayed(const Duration(milliseconds: 300), () {
      final filtered = _getFilteredList();
      final start = _currentPage * _pageSize;
      final nextItems = filtered.skip(start).take(_pageSize).toList();

      if (nextItems.isEmpty) {
        _hasMore = false;
      } else {
        _displayedPurchases.addAll(nextItems);
        _currentPage++;
      }

      setState(() => _isLoadingMore = false);
    });
  }

  List<Purchase> _getFilteredList() {
    List<Purchase> list = [..._allPurchases];
    if (_searchQuery.isNotEmpty) list = list.where((p) => p.invoiceNo.contains(_searchQuery)).toList();
    if (_selectedSupplierId != null) list = list.where((p) => p.supplierId == _selectedSupplierId).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Purchases"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          )
        ],
      ),
      body: Column(
        children: [
          PurchaseInsightCard(purchases: _displayedPurchases, loading: _allPurchases.isEmpty, lastUpdated: DateTime.now()),
          _buildSearchBar(),
          _buildFilters(),
          _buildSortingDropdown(),
          Expanded(child: _buildPurchaseList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PurchaseForm(
                repo: widget.repo,
                productRepo: widget.productRepo,
                supplierRepo: widget.supplierRepo,
              ),
            ),
          );
          if (added == true) _loadInitialData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: const InputDecoration(
          hintText: "Search invoice...",
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          _searchQuery = value;
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: DropdownButtonFormField<String?>(
        initialValue: _selectedSupplierId,
        decoration: const InputDecoration(
          labelText: "Filter by Supplier",
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text("All Suppliers")),
          ..._suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
        ],
        onChanged: (value) {
          _selectedSupplierId = value;
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildSortingDropdown() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child:  DropdownSearch<String?>(
  selectedItem: _selectedSupplierId,
  compareFn: (a, b) => a == b,

  items: (items , props)=> _suppliers.map((s) => s.id).toList(),
  itemAsString: (id) => id == null
      ? "All Suppliers"
      : _suppliers.firstWhere((s) => s.id == id).name,
  decoratorProps: const DropDownDecoratorProps(
    decoration: InputDecoration(
      labelText: "Filter by Supplier",
      border: OutlineInputBorder(),
    ),
  ),
  onChanged: (value) {
    _selectedSupplierId = value;
    _applyFilters();
  },
  popupProps: const PopupProps.menu(
    showSearchBox: true,
    searchFieldProps: TextFieldProps(
      decoration: InputDecoration(hintText: "Search supplier..."),
    ),
  ),
)
    );
  }

  Widget _buildPurchaseList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll.metrics.pixels == scroll.metrics.maxScrollExtent) {
          _loadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: _displayedPurchases.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _displayedPurchases.length) {
            return const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final purchase = _displayedPurchases[index];

          return FutureBuilder<Supplier?>(
            future: widget.repo.getSupplierById(purchase.supplierId),
            builder: (context, supSnap) {
              if (!supSnap.hasData) return const SizedBox.shrink();
              final supplier = supSnap.data!;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text("Invoice: ${purchase.invoiceNo}"),
                  subtitle: Text(
                    "Supplier: ${supplier.name}\n"
                    "Total: ${purchase.total} | Paid: ${purchase.paid} | Pending: ${purchase.pending}",
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PurchaseDetailFrame(
                          repo: widget.repo,
                          purchase: purchase,
                        ),
                      ),
                    );
                    _loadInitialData();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

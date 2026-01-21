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
import 'common/unified_search_bar.dart';
import '../services/purchase_export_service.dart';
import '../utils/responsive_utils.dart';
import '../services/thermal_printer/index.dart';

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
  final PurchaseExportService _exportService = PurchaseExportService();
  List<Purchase> _allPurchases = [];
  List<Purchase> _displayedPurchases = [];
  List<Supplier> _suppliers = [];

  int _currentPage = 1;
  final int _pageSize = 50; // Optimized for 2000+ purchases
  bool _isLoadingMore = false;
  bool _hasMore = true;

  String _searchQuery = "";
  String? _selectedSupplierId;
  final String _sortBy = "date_desc";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = _searchQuery;
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      filtered = filtered
          .where((p) => p.invoiceNo.contains(_searchQuery))
          .toList();
    }

    // Filter by supplier
    if (_selectedSupplierId != null) {
      filtered = filtered
          .where((p) => p.supplierId == _selectedSupplierId)
          .toList();
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
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) => p.invoiceNo.contains(_searchQuery)).toList();
    }
    if (_selectedSupplierId != null) {
      list = list.where((p) => p.supplierId == _selectedSupplierId).toList();
    }
    return list;
  }

  void _showPurchaseOptions(Purchase purchase) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text("Print Thermal Receipt"),
              onTap: () async {
                Navigator.pop(context);
                await thermalPrinting.printPurchase(
                  purchase,
                  items: const [],
                  context: context,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text("Print Purchase"),
              onTap: () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Print feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text("Share PDF"),
              onTap: () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share feature coming soon')),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.redAccent),
              title: const Text("Cancel"),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveUtils.isMobile(context);

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: const Text("Purchases"),
            elevation: 0,
            actions: isMobile
                ? [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadInitialData,
                      tooltip: 'Refresh',
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'pdf') {
                          _exportService.exportToPDF(_displayedPurchases);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'pdf',
                          child: Row(
                            children: [
                              Icon(Icons.picture_as_pdf),
                              SizedBox(width: 8),
                              Text('Export PDF'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ]
                : [
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf),
                      tooltip: 'Export to PDF',
                      onPressed: () =>
                          _exportService.exportToPDF(_displayedPurchases),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadInitialData,
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
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: UnifiedSearchBar(
                        hintText: "Search invoice...",
                        controller: _searchController,
                        onChanged: (value) {
                          _searchQuery = value;
                          _applyFilters();
                        },
                        onClear: () {
                          setState(() {
                            _searchQuery = "";
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: DropdownSearch<String?>(
                        selectedItem: _selectedSupplierId,
                        compareFn: (a, b) => a == b,
                        items: (items, props) => [
                          null,
                          ..._suppliers.map((s) => s.id),
                        ],
                        itemAsString: (id) => id == null
                            ? "All Suppliers"
                            : _suppliers
                                  .firstWhere(
                                    (s) => s.id == id,
                                    orElse: () => Supplier(
                                      id: '',
                                      name: 'Unknown',
                                      createdAt: DateTime.now()
                                          .toIso8601String(),
                                      updatedAt: DateTime.now()
                                          .toIso8601String(),
                                    ),
                                  )
                                  .name,
                        decoratorProps: DropDownDecoratorProps(
                          decoration: InputDecoration(
                            labelText: "Filter by Supplier",
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
                        onChanged: (value) {
                          _selectedSupplierId = value;
                          _applyFilters();
                        },
                        popupProps: const PopupProps.menu(
                          showSearchBox: true,
                          constraints: BoxConstraints(maxHeight: 300),
                          searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
                              hintText: "Search supplier...",
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: PurchaseInsightCard(
                  purchases: _displayedPurchases,
                  loading: false,
                  lastUpdated: DateTime.now(),
                ),
              ),
              Expanded(child: _buildPurchaseList(isMobile)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
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
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text("New Purchase"),
          ),
        );
      },
    );
  }

  Widget _buildPurchaseList(bool isMobile) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll.metrics.pixels == scroll.metrics.maxScrollExtent) {
          _loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadInitialData();
        },
        child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _displayedPurchases.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _displayedPurchases.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final purchase = _displayedPurchases[index];

          return FutureBuilder<Supplier?>(
            future: widget.repo.getSupplierById(purchase.supplierId),
            builder: (context, supSnap) {
              if (!supSnap.hasData) return const SizedBox.shrink();
              final supplier = supSnap.data!;
              final hasPending = purchase.pending > 0;
              final isPaid = purchase.pending <= 0;
              final date = DateTime.tryParse(purchase.date) ?? DateTime.now();

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      isPaid
                          ? Colors.green.withOpacity(0.05)
                          : Colors.orange.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (isPaid ? Colors.green : Colors.orange)
                          .withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: (isPaid ? Colors.green : Colors.orange).withOpacity(
                      0.3,
                    ),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Strip
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isPaid
                                ? [Colors.green.shade600, Colors.green.shade400]
                                : [
                                    Colors.orange.shade600,
                                    Colors.orange.shade400,
                                  ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPaid
                                  ? Icons.check_circle
                                  : Icons.pending_actions,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isPaid ? "Fully Paid" : "Pending Payment",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      InkWell(
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
                        onLongPress: () => _showPurchaseOptions(purchase),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Invoice Badge
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.indigo.shade600,
                                          Colors.indigo.shade400,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.indigo.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Invoice Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Invoice #${purchase.invoiceNo}",
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.blue.shade200,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.business,
                                                size: 14,
                                                color: Colors.blue.shade700,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                supplier.name,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blue.shade900,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Date Badge
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          date.day.toString(),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        Text(
                                          _getMonthName(date.month),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),

                              // Metrics Row
                              isMobile
                                  ? Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildMetric(
                                              "TOTAL",
                                              "Rs ${purchase.total.toStringAsFixed(0)}",
                                              Colors.blue,
                                            ),
                                            _buildMetric(
                                              "PAID",
                                              "Rs ${purchase.paid.toStringAsFixed(0)}",
                                              Colors.green,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            _buildMetric(
                                              "PENDING",
                                              "Rs ${purchase.pending.toStringAsFixed(0)}",
                                              hasPending
                                                  ? Colors.red
                                                  : Colors.green,
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildMetric(
                                          "TOTAL",
                                          "Rs ${purchase.total.toStringAsFixed(0)}",
                                          Colors.blue,
                                        ),
                                        _buildMetric(
                                          "PAID",
                                          "Rs ${purchase.paid.toStringAsFixed(0)}",
                                          Colors.green,
                                        ),
                                        _buildMetric(
                                          "PENDING",
                                          "Rs ${purchase.pending.toStringAsFixed(0)}",
                                          hasPending
                                              ? Colors.red
                                              : Colors.green,
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
          );
        }
      ),
    ));
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

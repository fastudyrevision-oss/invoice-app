import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../repositories/category_repository.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_repo.dart';
import '../models/supplier.dart';
import '../dao/supplier_dao.dart';
import '../dao/supplier_report_dao.dart';
import '../dao/supplier_payment_dao.dart';
import '../dao/supplier_company_dao.dart';
import 'product/product_insights_card.dart';
import 'common/unified_search_bar.dart';
import '../services/product_export_service.dart';

enum ProductSortOption { name, quantity, costPrice, sellPrice }

class ProductFrame extends StatefulWidget {
  const ProductFrame({super.key});

  @override
  _ProductFrameState createState() => _ProductFrameState();
}

class _ProductFrameState extends State<ProductFrame> {
  final ProductExportService _exportService = ProductExportService();
  final ProductRepository _repo = ProductRepository();
  final SupplierRepository _supplierRepo = SupplierRepository(
    SupplierDao(),
    SupplierPaymentDao(),
    SupplierReportDao(),
    SupplierCompanyDao(),
  );

  final List<Product> _products = [];
  List<Supplier> _suppliers = [];
  List<Category> _categories = [];

  // Filters & Sorting
  Category? _selectedCategory;
  Supplier? _selectedSupplier;
  bool _lowStockOnly = false;
  ProductSortOption _sortOption = ProductSortOption.name;

  bool _isLoading = true;
  bool _isLoadingPage = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 50; // Optimized for 1000+ products
  String _searchQuery = "";

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();

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

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final categoryRepo = await CategoryRepository.create();
    _categories = await categoryRepo.getAllCategories();
    _suppliers = await _supplierRepo.getAllSuppliers();

    // Insert pseudo "All Suppliers" option
    _suppliers.insert(
      0,
      Supplier(
        id: 'all',
        name: 'Unlinked/All',
        phone: null,
        address: null,
        createdAt: '',
        updatedAt: '',
      ),
    );
    // Insert pseudo "All" category
    _categories.insert(
      0,
      Category(
        id: "all",
        name: "All Categories",
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ),
    );

    await _loadNextPage();
    setState(() => _isLoading = false);
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore) return;
    if (!mounted) return;

    setState(() => _isLoadingPage = true);

    final newProducts = await _repo.getProductsPage(
      page: _currentPage,
      pageSize: _pageSize,
    );

    if (newProducts.isEmpty) {
      _hasMore = false;
    } else {
      _products.addAll(newProducts);
      _currentPage++;
    }

    setState(() => _isLoadingPage = false);
  }

  void _onSearchChanged(String query) {
    _searchQuery = query.toLowerCase();
    _resetPagination();
  }

  void _onCategoryChanged(Category? category) {
    if (category == null || category.id == "all") {
      _selectedCategory = null; // means ALL categories
    } else {
      _selectedCategory = category;
    }
    _resetPagination();
  }

  void _onSupplierChanged(Supplier? supplier) {
    // Null means "All"
    _selectedSupplier = (supplier?.id == 'all') ? null : supplier;
    _resetPagination();
  }

  void _onLowStockChanged(bool? value) {
    _lowStockOnly = value ?? false;
    _resetPagination();
  }

  void _onSortOptionChanged(ProductSortOption? option) {
    if (option != null) {
      _sortOption = option;
      setState(() {});
    }
  }

  void _resetPagination() {
    _products.clear();
    _currentPage = 0;
    _hasMore = true;
    _loadNextPage();
  }

  List<Product> _applyFilters(List<Product> products) {
    var filtered = products;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((p) => p.name.toLowerCase().contains(_searchQuery))
          .toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered
          .where((p) => p.categoryId == _selectedCategory!.id)
          .toList();
    }

    if (_selectedSupplier != null) {
      filtered = filtered
          .where((p) => p.supplierId == _selectedSupplier!.id)
          .toList();
    }

    if (_lowStockOnly) {
      filtered = filtered.where((p) => p.quantity <= p.minStock).toList();
    }

    // Sorting
    filtered.sort((a, b) {
      switch (_sortOption) {
        case ProductSortOption.name:
          return a.name.compareTo(b.name);
        case ProductSortOption.quantity:
          return a.quantity.compareTo(b.quantity);
        case ProductSortOption.costPrice:
          return a.costPrice.compareTo(b.costPrice);
        case ProductSortOption.sellPrice:
          return a.sellPrice.compareTo(b.sellPrice);
      }
    });

    return filtered;
  }

  void _showAddEditProductDialog([Product? product]) {
    final nameController = TextEditingController(text: product?.name ?? "");
    final skuController = TextEditingController(text: product?.sku ?? "");
    final unitController = TextEditingController(
      text: product?.defaultUnit ?? "",
    );
    final costController = TextEditingController(
      text: product?.costPrice.toString() ?? "",
    );
    final sellController = TextEditingController(
      text: product?.sellPrice.toString() ?? "",
    );
    final quantityController = TextEditingController(
      text: product?.quantity.toString() ?? "",
    );
    final minStockController = TextEditingController(
      text: product?.minStock.toString() ?? "",
    );
    final descController = TextEditingController(
      text: product?.description ?? "",
    );
    bool trackExpiry = product?.trackExpiry ?? false;
    String? selectedSupplierId = product?.supplierId;
    Category? selectedCategory = product != null
        ? _categories.firstWhere(
            (c) => c.id == product.categoryId,
            orElse: () => _categories.firstWhere((c) => c.id == 'cat-001'),
          )
        : _categories.firstWhere((c) => c.id == 'cat-001');

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(product == null ? "Add Product" : "Edit Product"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Name"),
                ),
                TextField(
                  controller: skuController,
                  decoration: const InputDecoration(labelText: "SKU"),
                ),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(labelText: "Default Unit"),
                ),
                TextField(
                  controller: costController,
                  decoration: const InputDecoration(labelText: "Cost Price"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: sellController,
                  decoration: const InputDecoration(labelText: "Sell Price"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: "Quantity"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: minStockController,
                  decoration: const InputDecoration(labelText: "Min Stock"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: "Description"),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: DropdownSearch<Category>(
                    items: (filter, _) => _categories,
                    selectedItem: selectedCategory,
                    itemAsString: (c) => c.name,
                    compareFn: (a, b) => a.id == b.id,
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      fit: FlexFit.loose,
                    ),
                    decoratorProps: DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: "Category",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    onChanged: (c) => setStateDialog(
                      () => selectedCategory =
                          c ?? _categories.firstWhere((x) => x.id == 'cat-001'),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: DropdownSearch<Supplier>(
                    items: (filter, _) => _suppliers,
                    selectedItem: _suppliers.firstWhere(
                      (s) => s.id == selectedSupplierId,
                      orElse: () => _suppliers.first,
                    ),
                    itemAsString: (s) => s.name,
                    compareFn: (a, b) => a.id == b.id,
                    popupProps: PopupProps.menu(showSearchBox: true),
                    decoratorProps: DropDownDecoratorProps(
                      decoration: const InputDecoration(
                        labelText: "Supplier",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    onChanged: (s) =>
                        setStateDialog(() => selectedSupplierId = s?.id),
                  ),
                ),

                Row(
                  children: [
                    Checkbox(
                      value: trackExpiry,
                      onChanged: (val) =>
                          setStateDialog(() => trackExpiry = val ?? false),
                    ),
                    const Text("Track Expiry"),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final newProduct = Product(
                  id:
                      product?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  description: descController.text,
                  sku: skuController.text,
                  defaultUnit: unitController.text,
                  costPrice: double.tryParse(costController.text) ?? 0.0,
                  sellPrice: double.tryParse(sellController.text) ?? 0.0,
                  quantity: int.tryParse(quantityController.text) ?? 0,
                  minStock: int.tryParse(minStockController.text) ?? 0,
                  trackExpiry: trackExpiry,
                  supplierId: (selectedSupplierId == "all")
                      ? null
                      : selectedSupplierId,
                  categoryId: selectedCategory?.id ?? 'cat-001',
                  createdAt:
                      product?.createdAt ?? DateTime.now().toIso8601String(),
                  updatedAt: DateTime.now().toIso8601String(),
                );

                if (product == null) {
                  await _repo.addProduct(newProduct);
                } else {
                  await _repo.updateProduct(newProduct);
                }

                Navigator.pop(context);
                _resetPagination();
              },
              child: Text(product == null ? "Add" : "Update"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedProducts = _applyFilters(_products);
    if (_isLoading || _categories.isEmpty || _suppliers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.grey[100], // Light background for better contrast
      appBar: AppBar(
        title: const Text("Products"),
        elevation: 0,
        actions: [
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export to PDF',
            onPressed: () => _exportService.exportToPDF(displayedProducts),
          ),
          IconButton(
            onPressed: () => _showAddEditProductDialog(),
            icon: const Icon(Icons.add_circle, size: 28),
            tooltip: 'Add Product',
          ),
          const SizedBox(width: 10 , height: 10,),
          const SizedBox(height: 10),
        ],
        
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(150), // Increased height
          child: Container(
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: UnifiedSearchBar(
                    hintText: "Search products by name...",
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: () => _onSearchChanged(''),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      // Category Filter
                      Expanded(
                        child: DropdownSearch<Category>(
                          items: (filter, _) => _categories,
                          selectedItem: _selectedCategory,
                          itemAsString: (c) => c.name,
                          compareFn: (a, b) => a.id == b.id,
                          onChanged: _onCategoryChanged,
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                            fit: FlexFit.loose,
                            constraints: const BoxConstraints(maxHeight: 300),
                          ),
                          decoratorProps: DropDownDecoratorProps(
                            decoration: InputDecoration(
                              labelText: "Category",
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Supplier Filter
                      Expanded(
                        child: DropdownSearch<Supplier>(
                          items: (filter, props) => _suppliers,
                          selectedItem: _selectedSupplier,
                          itemAsString: (s) => s.name,
                          compareFn: (a, b) => a.id == b.id,
                          onChanged: _onSupplierChanged,
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                            fit: FlexFit.loose,
                            constraints: const BoxConstraints(maxHeight: 300),
                          ),
                          decoratorProps: DropDownDecoratorProps(
                            decoration: InputDecoration(
                              labelText: "Supplier",
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
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      // Low stock
                      FilterChip(
                        label: const Text("Low Stock"),
                        selected: _lowStockOnly,
                        onSelected: _onLowStockChanged,
                        selectedColor: Colors.red.shade100,
                        checkmarkColor: Colors.red,
                        labelStyle: TextStyle(
                          color: _lowStockOnly ? Colors.red[900] : Colors.black,
                          fontWeight: _lowStockOnly
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const Spacer(),
                      // Sorting
                      const Text("Sort by: ", style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<ProductSortOption>(
                            value: _sortOption,
                            isDense: true,
                            items: ProductSortOption.values
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e.name[0].toUpperCase() +
                                          e.name.substring(1),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _onSortOptionChanged,
                          ),
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
                // Product Insights Card
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ProductInsightsCard(
                    products: _products,
                    loading: false,
                    lastUpdated: DateTime.now(),
                    categoriesCount: _categories
                        .where((c) => c.id != 'all')
                        .length,
                  ),
                ),

                // Product List
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: displayedProducts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= displayedProducts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final p = displayedProducts[index];
                      final supplier = _suppliers.firstWhere(
                        (s) => s.id == p.supplierId,
                        orElse: () => Supplier(
                          id: "0",
                          name: "Unlinked",
                          phone: null,
                          address: null,
                          createdAt: "",
                          updatedAt: "",
                        ),
                      );
                      final category = _categories.firstWhere(
                        (c) => c.id == p.categoryId,
                        orElse: () => Category(
                          id: "0",
                          name: "Uncategorized",
                          createdAt: DateTime.now().toIso8601String(),
                          updatedAt: DateTime.now().toIso8601String(),
                        ),
                      );

                      final isLowStock = p.quantity <= p.minStock;
                      final profit = p.sellPrice - p.costPrice;
                      final profitPercent = p.costPrice > 0
                          ? (profit / p.costPrice) * 100
                          : 0.0;

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
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(
                            color: isLowStock
                                ? Colors.red.shade200
                                : Colors.transparent,
                            width: isLowStock ? 1.5 : 0,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status Strip
                              if (isLowStock)
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
                                        Icons.warning_amber_rounded,
                                        size: 16,
                                        color: Colors.red.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Low Stock Alert",
                                        style: TextStyle(
                                          color: Colors.red.shade900,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Name & SKU
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
                                                p.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "SKU: ${p.sku}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                  fontFamily: 'Monospace',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Actions
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                color: Colors.blue,
                                              ),
                                              onPressed: () =>
                                                  _showAddEditProductDialog(p),
                                              tooltip: 'Edit',
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                              ),
                                              onPressed: () async {
                                                // Confirm delete
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                      "Delete Product?",
                                                    ),
                                                    content: Text(
                                                      "Are you sure you want to delete '${p.name}'?",
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              false,
                                                            ),
                                                        child: const Text(
                                                          "Cancel",
                                                        ),
                                                      ),
                                                      ElevatedButton(
                                                        style:
                                                            ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.red,
                                                              foregroundColor:
                                                                  Colors.white,
                                                            ),
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              true,
                                                            ),
                                                        child: const Text(
                                                          "Delete",
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );

                                                if (confirm == true) {
                                                  await _repo.deleteProduct(
                                                    p.id,
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

                                    // Chips: Category & Supplier
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        Chip(
                                          avatar: const Icon(
                                            Icons.category_outlined,
                                            size: 16,
                                          ),
                                          label: Text(category.name),
                                          backgroundColor: Colors.blue.shade50,
                                          labelStyle: TextStyle(
                                            color: Colors.blue.shade900,
                                            fontSize: 12,
                                          ),
                                          padding: const EdgeInsets.all(0),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        Chip(
                                          avatar: const Icon(
                                            Icons.store_outlined,
                                            size: 16,
                                          ),
                                          label: Text(supplier.name),
                                          backgroundColor:
                                              Colors.orange.shade50,
                                          labelStyle: TextStyle(
                                            color: Colors.orange.shade900,
                                            fontSize: 12,
                                          ),
                                          padding: const EdgeInsets.all(0),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        if (p.trackExpiry)
                                          Chip(
                                            avatar: const Icon(
                                              Icons.access_time,
                                              size: 16,
                                            ),
                                            label: const Text("Expiry Tracked"),
                                            backgroundColor:
                                                Colors.purple.shade50,
                                            labelStyle: TextStyle(
                                              color: Colors.purple.shade900,
                                              fontSize: 12,
                                            ),
                                            padding: const EdgeInsets.all(0),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),
                                    const Divider(),
                                    const SizedBox(height: 8),

                                    // Metrics Grid
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildMetricColumn(
                                          "Cost",
                                          "Rs ${p.costPrice.toStringAsFixed(0)}",
                                          Colors.grey.shade700,
                                        ),
                                        _buildMetricColumn(
                                          "Sell",
                                          "Rs ${p.sellPrice.toStringAsFixed(0)}",
                                          Colors.black87,
                                          isBold: true,
                                        ),
                                        _buildMetricColumn(
                                          "Profit",
                                          "Rs ${profit.toStringAsFixed(0)}",
                                          profit > 0
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                          subtext:
                                              "(${profitPercent.toStringAsFixed(0)}%)",
                                        ),
                                        Container(
                                          width: 1,
                                          height: 30,
                                          color: Colors.grey.shade300,
                                        ),
                                        _buildMetricColumn(
                                          "Stock",
                                          "${p.quantity} ${p.defaultUnit}",
                                          isLowStock
                                              ? Colors.red.shade700
                                              : Colors.blue.shade700,
                                          isBold: true,
                                        ),
                                      ],
                                    ),
                                  ],
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
    );
  }

  Widget _buildMetricColumn(
    String label,
    String value,
    Color color, {
    bool isBold = false,
    String? subtext,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
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
            fontSize: 14,
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (subtext != null)
          Text(
            subtext,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
          ),
      ],
    );
  }
}

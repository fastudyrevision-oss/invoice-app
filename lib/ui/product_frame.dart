import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../repositories/category_repository.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_repo.dart';
import '../models/supplier.dart';
import '../models/category.dart';
import '../dao/supplier_dao.dart';
import '../dao/supplier_report_dao.dart';
import '../dao/supplier_payment_dao.dart';
import '../dao/supplier_company_dao.dart';

enum ProductSortOption { name, quantity, costPrice, sellPrice }

class ProductFrame extends StatefulWidget {
  const ProductFrame({super.key});

  @override
  _ProductFrameState createState() => _ProductFrameState();
}

class _ProductFrameState extends State<ProductFrame> {
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
  final int _pageSize = 20;
  String _searchQuery = "";

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingPage &&
          _hasMore) {
        _loadNextPage();
      }
    });
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
        name: 'All',
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
      appBar: AppBar(
        title: const Text("Products"),
        actions: [
          IconButton(
            onPressed: () => _showAddEditProductDialog(),
            icon: const Icon(Icons.add),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search products...",
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                        popupProps: PopupProps.menu(showSearchBox: true),
                        decoratorProps: DropDownDecoratorProps(
                          decoration: const InputDecoration(
                            labelText: "Category",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Supplier Filter with "All"
                    Expanded(
                      child: DropdownSearch<Supplier>(
                        items: (filter, props) => _suppliers,
                        selectedItem: _selectedSupplier,
                        itemAsString: (s) => s.name,
                        compareFn: (a, b) => a?.id == b?.id,
                        onChanged: _onSupplierChanged,
                        popupProps: PopupProps.menu(showSearchBox: true),
                        decoratorProps: DropDownDecoratorProps(
                          decoration: const InputDecoration(
                            labelText: "Supplier",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Low stock
                    Column(
                      children: [
                        const Text("Low Stock"),
                        Checkbox(
                          value: _lowStockOnly,
                          onChanged: _onLowStockChanged,
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    // Sorting
                    DropdownButton<ProductSortOption>(
                      value: _sortOption,
                      items: ProductSortOption.values
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                e.name[0].toUpperCase() + e.name.substring(1),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _onSortOptionChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
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

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: index.isEven ? Colors.blue.shade50 : Colors.white,
                  child: ListTile(
                    title: Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("SKU: ${p.sku} | Unit: ${p.defaultUnit}"),
                        Text(
                          "Category: ${category.name} | Supplier: ${supplier.name}",
                        ),
                        Text(
                          "Cost: \$${p.costPrice.toStringAsFixed(2)} | Sell: \$${p.sellPrice.toStringAsFixed(2)}",
                        ),
                        Text("Qty: ${p.quantity} | Min Stock: ${p.minStock}"),
                        Row(
                          children: [
                            const Text("Expiry tracked: "),
                            Icon(
                              p.trackExpiry ? Icons.check_circle : Icons.cancel,
                              color: p.trackExpiry ? Colors.green : Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showAddEditProductDialog(p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await _repo.deleteProduct(p.id);
                            _resetPagination();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

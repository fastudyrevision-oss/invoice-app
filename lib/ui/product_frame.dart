import 'dart:async';
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
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';
import '../services/preferences_service.dart';
import '../models/product_batch.dart';

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

  bool _isAscending = true; // Added for sort direction
  bool _loadAll = false; // Added for "Load All" feature

  Map<String, dynamic>? _overallStats; // Added for dashboard stats

  // Batch expansion state
  final Set<String> _expandedProductIds = {};
  final Map<String, List<ProductBatch>> _batchesCache = {};
  final Map<String, bool> _loadingBatches = {};

  bool _isLoading = true;
  bool _isFetchingPage = false; // Lock for concurrent fetches
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 50; // Optimized for 1000+ products
  final int _fullPageSize = 10000; // Large size for "Load All"
  String _searchQuery = "";
  Timer? _debounce;

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
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    logger.info('ProductFrame', 'Loading initial product data');

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

    await _refreshStats();
    await _loadNextPage();
    setState(() => _isLoading = false);
  }

  Future<void> _refreshStats() async {
    try {
      final stats = await _repo.getInventoryStats(
        searchQuery: _searchQuery,
        categoryId: _selectedCategory?.id,
        supplierId: _selectedSupplier?.id,
        onlyLowStock: _lowStockOnly,
      );
      if (mounted) {
        setState(() {
          _overallStats = stats;
        });
      }
    } catch (e) {
      logger.error('ProductFrame', 'Error fetching stats', error: e);
    }
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _isFetchingPage) {
      if (_isFetchingPage) {
        logger.info('ProductFrame', 'Skipping fetch: already in progress');
      }
      return;
    }
    if (!mounted) return;

    setState(() => _isFetchingPage = true);
    try {
      final int currentLimit = _loadAll ? _fullPageSize : _pageSize;

      logger.info(
        'ProductFrame',
        'Fetching page $_currentPage (Limit: $currentLimit)',
      );
      final newProducts = await _repo.getProductsPage(
        page: _currentPage,
        pageSize: currentLimit,
        searchQuery: _searchQuery,
        categoryId: _selectedCategory?.id,
        supplierId: _selectedSupplier?.id,
        onlyLowStock: _lowStockOnly,
        orderBy: _sortOption.name,
        isAscending: _isAscending,
      );

      if (mounted) {
        if (newProducts.isEmpty) {
          logger.info(
            'ProductFrame',
            'No more products found at page $_currentPage',
          );
          _hasMore = false;
          setState(() {});
        } else {
          logger.info(
            'ProductFrame',
            'Loaded ${newProducts.length} items for page $_currentPage',
          );
          setState(() {
            _products.addAll(newProducts);
            _currentPage++;
            if (_loadAll || newProducts.length < currentLimit) {
              _hasMore = false;
            }
          });
        }
      }
    } catch (e, stack) {
      logger.error(
        'ProductFrame',
        'Error loading next page',
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load products: $e')));
        setState(() {
          _hasMore = false; // Stop trying if we crashed
        });
      }
    } finally {
      if (mounted) setState(() => _isFetchingPage = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchQuery = query.toLowerCase();
      _resetPagination();
    });
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
      _resetPagination();
    }
  }

  void _toggleSortDirection() {
    setState(() {
      _isAscending = !_isAscending;
    });
    _resetPagination();
  }

  Future<void> _toggleExpansion(String productId) async {
    setState(() {
      if (_expandedProductIds.contains(productId)) {
        _expandedProductIds.remove(productId);
      } else {
        _expandedProductIds.add(productId);
      }
    });

    if (_expandedProductIds.contains(productId) &&
        !_batchesCache.containsKey(productId)) {
      setState(() => _loadingBatches[productId] = true);
      try {
        final batches = await _repo.getProductBatches(productId);
        setState(() {
          _batchesCache[productId] = batches;
          _loadingBatches[productId] = false;
        });
      } catch (e) {
        setState(() => _loadingBatches[productId] = false);
      }
    }
  }

  void _toggleLoadAll() {
    setState(() {
      _loadAll = !_loadAll;
      _resetPagination();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _loadAll ? "🚀 Loading all products" : "📑 Switched to paged loading",
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _resetPagination() {
    _products.clear();
    _currentPage = 0;
    _hasMore = true;
    _refreshStats();
    _loadNextPage();
  }

  // Client-side filtering removed. Used directly in _loadNextPage via repository.

  void _showAddEditProductDialog([Product? product]) {
    final formKey = GlobalKey<FormState>(); // Form Key for validation
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
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Name *"),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  TextFormField(
                    controller: skuController,
                    decoration: const InputDecoration(labelText: "SKU"),
                  ),
                  TextFormField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: "Default Unit",
                    ),
                  ),
                  TextFormField(
                    controller: costController,
                    decoration: const InputDecoration(
                      labelText: "Cost Price *",
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final v = double.tryParse(value);
                      if (v == null || v < 0) return 'Invalid amount';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: sellController,
                    decoration: const InputDecoration(
                      labelText: "Sell Price *",
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final v = double.tryParse(value);
                      if (v == null || v <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: "Quantity *"),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final v = int.tryParse(value);
                      if (v == null || v < 0) return 'Must be 0 or more';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: minStockController,
                    decoration: const InputDecoration(labelText: "Min Stock"),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final v = int.tryParse(value);
                        if (v == null || v < 0) return 'Invalid';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
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
                            c ??
                            _categories.firstWhere((x) => x.id == 'cat-001'),
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
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
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
                }
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

  Future<void> _handleExport(String outputType, List<Product> products) async {
    if (products.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No products to export')));
      return;
    }

    // Common filter metadata
    final categoryName = _selectedCategory?.id == 'all'
        ? null
        : _selectedCategory?.name;
    final supplierName = _selectedSupplier?.id == 'all'
        ? null
        : _selectedSupplier?.name;

    try {
      if (outputType == 'print') {
        logger.info('ProductFrame', 'Printing product list');
        await _exportService.printProductList(
          products,
          categoryName: categoryName,
          supplierName: supplierName,
          lowStockOnly: _lowStockOnly,
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
        logger.info('ProductFrame', 'Saving product list PDF');
        final file = await _exportService.saveProductListPdf(
          products,
          categoryName: categoryName,
          supplierName: supplierName,
          lowStockOnly: _lowStockOnly,
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
        logger.info('ProductFrame', 'Sharing product list PDF');
        await _exportService.exportToPDF(
          products,
          categoryName: categoryName,
          supplierName: supplierName,
          lowStockOnly: _lowStockOnly,
        );
      }
    } catch (e, stackTrace) {
      logger.error(
        'ProductFrame',
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

  Future<void> _showSettingsDialog() async {
    final prefs = PreferencesService.instance;
    bool includeExpired = await prefs.getIncludeExpiredInOrders();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Product Settings"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text("Include Expired Products in Orders"),
                  subtitle: const Text(
                    "If disabled, expired batches will be hidden from stock",
                    style: TextStyle(fontSize: 12),
                  ),
                  value: includeExpired,
                  onChanged: (val) async {
                    await prefs.setIncludeExpiredInOrders(val);
                    setStateDialog(() => includeExpired = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveUtils.isMobile(context);
        final displayedProducts = _products;
        if (_isLoading || _categories.isEmpty || _suppliers.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          backgroundColor:
              Colors.grey[100], // Light background for better contrast
          appBar: AppBar(
            title: const Text("Products"),
            elevation: 0,
            actions: isMobile
                ? [
                    IconButton(
                      onPressed: () => _showAddEditProductDialog(),
                      icon: const Icon(Icons.add_circle),
                      tooltip: 'Add Product',
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'print' ||
                            value == 'save' ||
                            value == 'share') {
                          _handleExport(value, displayedProducts);
                        } else if (value == 'refresh') {
                          setState(() {
                            _products.clear();
                            _currentPage = 0;
                            _hasMore = true;
                          });
                          _loadInitialData();
                        } else if (value == 'load_all') {
                          _toggleLoadAll();
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
                        PopupMenuItem(
                          value: 'load_all',
                          child: Row(
                            children: [
                              Icon(_loadAll ? Icons.pages : Icons.speed),
                              const SizedBox(width: 8),
                              Text(_loadAll ? 'Paged Mode' : 'Load All Mode'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ]
                : [
                    const SizedBox(width: 10),
                    IconButton(
                      icon: Icon(_loadAll ? Icons.pages : Icons.speed),
                      tooltip: _loadAll ? 'Paged Mode' : 'Load All Mode',
                      onPressed: _toggleLoadAll,
                    ),
                    IconButton(
                      icon: const Icon(Icons.print),
                      tooltip: 'Print List',
                      onPressed: () =>
                          _handleExport('print', displayedProducts),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      tooltip: 'Save PDF',
                      onPressed: () => _handleExport('save', displayedProducts),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      tooltip: 'Share PDF',
                      onPressed: () =>
                          _handleExport('share', displayedProducts),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                      onPressed: () {
                        setState(() {
                          _products.clear();
                          _currentPage = 0;
                          _hasMore = true;
                        });
                        _loadInitialData();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      tooltip: 'Settings',
                      onPressed: _showSettingsDialog,
                    ),
                    IconButton(
                      onPressed: () => _showAddEditProductDialog(),
                      icon: const Icon(Icons.add_circle, size: 28),
                      tooltip: 'Add Product',
                    ),
                    const SizedBox(width: 10),
                  ],

            bottom: PreferredSize(
              preferredSize: Size.fromHeight(
                isMobile ? 220 : 160,
              ), // Adjusted for proper spacing
              child: Container(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
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
                      child: isMobile
                          ? Column(
                              children: [
                                DropdownSearch<Category>(
                                  items: (filter, _) => _categories,
                                  selectedItem: _selectedCategory,
                                  itemAsString: (c) => c.name,
                                  compareFn: (a, b) => a.id == b.id,
                                  onChanged: _onCategoryChanged,
                                  popupProps: const PopupProps.modalBottomSheet(
                                    showSearchBox: true,
                                    constraints: BoxConstraints(maxHeight: 500),
                                  ),
                                  decoratorProps: DropDownDecoratorProps(
                                    decoration: InputDecoration(
                                      labelText: "Category",
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                                const SizedBox(height: 8),
                                DropdownSearch<Supplier>(
                                  items: (filter, props) => _suppliers,
                                  selectedItem: _selectedSupplier,
                                  itemAsString: (s) => s.name,
                                  compareFn: (a, b) => a.id == b.id,
                                  onChanged: _onSupplierChanged,
                                  popupProps: const PopupProps.modalBottomSheet(
                                    showSearchBox: true,
                                    constraints: BoxConstraints(maxHeight: 500),
                                  ),
                                  decoratorProps: DropDownDecoratorProps(
                                    decoration: InputDecoration(
                                      labelText: "Supplier",
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                              ],
                            )
                          : Row(
                              children: [
                                // Category Filter
                                Expanded(
                                  child: DropdownSearch<Category>(
                                    items: (filter, _) => _categories,
                                    selectedItem: _selectedCategory,
                                    itemAsString: (c) => c.name,
                                    compareFn: (a, b) => a.id == b.id,
                                    onChanged: _onCategoryChanged,
                                    popupProps:
                                        const PopupProps.modalBottomSheet(
                                          showSearchBox: true,
                                          constraints: BoxConstraints(
                                            maxHeight: 500,
                                          ),
                                        ),
                                    decoratorProps: DropDownDecoratorProps(
                                      decoration: InputDecoration(
                                        labelText: "Category",
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                    popupProps:
                                        const PopupProps.modalBottomSheet(
                                          showSearchBox: true,
                                          constraints: BoxConstraints(
                                            maxHeight: 500,
                                          ),
                                        ),
                                    decoratorProps: DropDownDecoratorProps(
                                      decoration: InputDecoration(
                                        labelText: "Supplier",
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                              color: _lowStockOnly
                                  ? Colors.red[900]
                                  : Colors.black,
                              fontWeight: _lowStockOnly
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const Spacer(),
                          // Sorting
                          const Text(
                            "Sort by: ",
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          // Sort Direction Toggle
                          IconButton(
                            onPressed: _toggleSortDirection,
                            icon: Icon(
                              _isAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 18,
                              color: Theme.of(context).primaryColor,
                            ),
                            tooltip: _isAscending ? 'Ascending' : 'Descending',
                          ),
                          const SizedBox(width: 4),
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
                        stats: _overallStats,
                        loading: false,
                        lastUpdated: DateTime.now(),
                        categoriesCount: _categories
                            .where((c) => c.id != 'all')
                            .length,
                      ),
                    ),

                    // Product List
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          _resetPagination();
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );
                        },
                        child: displayedProducts.isEmpty && !_isLoading
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 64,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "No products found",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (_searchQuery.isNotEmpty ||
                                        _selectedCategory != null)
                                      TextButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          _onSearchChanged('');
                                          _onCategoryChanged(null);
                                        },
                                        child: const Text("Clear Filters"),
                                      ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.only(bottom: 80),
                                itemCount:
                                    displayedProducts.length +
                                    (_hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= displayedProducts.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
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
                                      createdAt: DateTime.now()
                                          .toIso8601String(),
                                      updatedAt: DateTime.now()
                                          .toIso8601String(),
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
                                          color: Colors.grey.withValues(
                                            alpha: 0.1,
                                          ),
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
                                    child: InkWell(
                                      onTap: () => _toggleExpansion(p.id),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Status Strip
                                          if (isLowStock)
                                            Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                      color:
                                                          Colors.red.shade900,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                          Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Header: Name & SKU
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      _expandedProductIds
                                                              .contains(p.id)
                                                          ? Icons.expand_less
                                                          : Icons.expand_more,
                                                      size: 20,
                                                      color: Colors.grey,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            p.name,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            "SKU: ${p.sku}",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .grey[600],
                                                              fontFamily:
                                                                  'Monospace',
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
                                                              _showAddEditProductDialog(
                                                                p,
                                                              ),
                                                          tooltip: 'Edit',
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons
                                                                .delete_outline,
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
                                                                    child: const Text(
                                                                      "Delete",
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );

                                                            if (confirm ==
                                                                true) {
                                                              await _repo
                                                                  .deleteProduct(
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
                                                      label: Text(
                                                        category.name,
                                                      ),
                                                      backgroundColor:
                                                          Colors.blue.shade50,
                                                      labelStyle: TextStyle(
                                                        color: Colors
                                                            .blue
                                                            .shade900,
                                                        fontSize: 12,
                                                      ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            0,
                                                          ),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                    ),
                                                    Chip(
                                                      avatar: const Icon(
                                                        Icons.store_outlined,
                                                        size: 16,
                                                      ),
                                                      label: Text(
                                                        supplier.name,
                                                      ),
                                                      backgroundColor:
                                                          Colors.orange.shade50,
                                                      labelStyle: TextStyle(
                                                        color: Colors
                                                            .orange
                                                            .shade900,
                                                        fontSize: 12,
                                                      ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            0,
                                                          ),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                    ),
                                                    if (p.trackExpiry)
                                                      Chip(
                                                        avatar: const Icon(
                                                          Icons.access_time,
                                                          size: 16,
                                                        ),
                                                        label: const Text(
                                                          "Expiry Tracked",
                                                        ),
                                                        backgroundColor: Colors
                                                            .purple
                                                            .shade50,
                                                        labelStyle: TextStyle(
                                                          color: Colors
                                                              .purple
                                                              .shade900,
                                                          fontSize: 12,
                                                        ),
                                                        padding:
                                                            const EdgeInsets.all(
                                                              0,
                                                            ),
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                      ),
                                                  ],
                                                ),

                                                const SizedBox(height: 16),
                                                const Divider(),
                                                const SizedBox(height: 8),

                                                // Metrics Grid
                                                // Metrics Grid
                                                isMobile
                                                    ? Column(
                                                        children: [
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              _buildMetricColumn(
                                                                "Cost",
                                                                "Rs ${p.costPrice.toStringAsFixed(0)}",
                                                                Colors
                                                                    .grey
                                                                    .shade700,
                                                              ),
                                                              _buildMetricColumn(
                                                                "Sell",
                                                                "Rs ${p.sellPrice.toStringAsFixed(0)}",
                                                                Colors.black87,
                                                                isBold: true,
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                            height: 12,
                                                          ),
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              _buildMetricColumn(
                                                                "Profit",
                                                                "Rs ${profit.toStringAsFixed(0)}",
                                                                profit > 0
                                                                    ? Colors
                                                                          .green
                                                                          .shade700
                                                                    : Colors
                                                                          .red
                                                                          .shade700,
                                                                subtext:
                                                                    "(${profitPercent.toStringAsFixed(0)}%)",
                                                              ),
                                                              _buildMetricColumn(
                                                                "Stock",
                                                                "${p.quantity} ${p.defaultUnit}",
                                                                isLowStock
                                                                    ? Colors
                                                                          .red
                                                                          .shade700
                                                                    : Colors
                                                                          .blue
                                                                          .shade700,
                                                                isBold: true,
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
                                                          _buildMetricColumn(
                                                            "Cost",
                                                            "Rs ${p.costPrice.toStringAsFixed(0)}",
                                                            Colors
                                                                .grey
                                                                .shade700,
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
                                                                ? Colors
                                                                      .green
                                                                      .shade700
                                                                : Colors
                                                                      .red
                                                                      .shade700,
                                                            subtext:
                                                                "(${profitPercent.toStringAsFixed(0)}%)",
                                                          ),
                                                          Container(
                                                            width: 1,
                                                            height: 30,
                                                            color: Colors
                                                                .grey
                                                                .shade300,
                                                          ),
                                                          _buildMetricColumn(
                                                            "Stock",
                                                            "${p.quantity} ${p.defaultUnit}",
                                                            isLowStock
                                                                ? Colors
                                                                      .red
                                                                      .shade700
                                                                : Colors
                                                                      .blue
                                                                      .shade700,
                                                            isBold: true,
                                                          ),
                                                        ],
                                                      ),
                                              ],
                                            ),
                                          ),
                                          // Expandable Batch Section
                                          if (_expandedProductIds.contains(
                                            p.id,
                                          )) ...[
                                            const Divider(height: 1),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(16),
                                              color: Colors.grey.shade50,
                                              child:
                                                  _loadingBatches[p.id] == true
                                                  ? const Center(
                                                      child: Padding(
                                                        padding: EdgeInsets.all(
                                                          8.0,
                                                        ),
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      ),
                                                    )
                                                  : _batchesCache[p.id] ==
                                                            null ||
                                                        _batchesCache[p.id]!
                                                            .isEmpty
                                                  ? const Text(
                                                      "No batch information available",
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey,
                                                      ),
                                                    )
                                                  : Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            const Text(
                                                              "Batch Breakdown",
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                            Text(
                                                              "${_batchesCache[p.id]!.length} Batches",
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .grey
                                                                    .shade600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        SingleChildScrollView(
                                                          scrollDirection:
                                                              Axis.horizontal,
                                                          child: Theme(
                                                            data:
                                                                Theme.of(
                                                                  context,
                                                                ).copyWith(
                                                                  dividerColor:
                                                                      Colors
                                                                          .grey
                                                                          .shade200,
                                                                ),
                                                            child: DataTable(
                                                              columnSpacing: 24,
                                                              horizontalMargin:
                                                                  0,
                                                              headingRowHeight:
                                                                  32,
                                                              dataRowMinHeight:
                                                                  32,
                                                              dataRowMaxHeight:
                                                                  44,
                                                              headingTextStyle:
                                                                  TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Colors
                                                                        .grey
                                                                        .shade700,
                                                                  ),
                                                              columns: const [
                                                                DataColumn(
                                                                  label: Text(
                                                                    "BATCH NO",
                                                                  ),
                                                                ),
                                                                DataColumn(
                                                                  label: Text(
                                                                    "QTY",
                                                                  ),
                                                                ),
                                                                DataColumn(
                                                                  label: Text(
                                                                    "EXPIRY",
                                                                  ),
                                                                ),
                                                                DataColumn(
                                                                  label: Text(
                                                                    "SELL",
                                                                  ),
                                                                ),
                                                              ],
                                                              rows: _batchesCache[p.id]!.map((
                                                                b,
                                                              ) {
                                                                return DataRow(
                                                                  cells: [
                                                                    DataCell(
                                                                      Text(
                                                                        b.batchNo ??
                                                                            "-",
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    DataCell(
                                                                      Text(
                                                                        "${b.qty}",
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    DataCell(
                                                                      Text(
                                                                        b.expiryDate ??
                                                                            "-",
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    DataCell(
                                                                      Text(
                                                                        "Rs ${(b.sellPrice ?? 0).toStringAsFixed(0)}",
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                );
                                                              }).toList(),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ],
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
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
          ),
      ],
    );
  }
}


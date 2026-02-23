import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../services/preferences_service.dart';
import '../../models/invoice_item.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../dao/customer_dao.dart';
import '../../dao/product_dao.dart';
import '../../dao/product_batch_dao.dart';
import '../../dao/invoice_dao.dart';
import '../../dao/invoice_item_dao.dart';
import '../../models/invoice.dart';
import '../../db/database_helper.dart';
import '../../services/logger_service.dart';
import 'pdf_export_helper.dart';

class OrderFormScreen extends StatefulWidget {
  final bool isTab;
  const OrderFormScreen({super.key, this.isTab = false});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  Customer? _selectedCustomer;
  Product? _selectedProduct;
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController(); // 👈 New price controller
  final _discountController = TextEditingController(text: "0");
  final _paidController = TextEditingController(text: "0");
  final _qtyFocusNode = FocusNode();
  final _priceFocusNode = FocusNode(); // 👈 New focus node for price

  List<Customer> _customers = [];
  List<Product> _products = [];
  final List<InvoiceItem> _items = [];

  bool _loading = true;
  int _availableStock = 0;

  double get _total => _items.fold(0, (sum, i) => sum + (i.price * i.qty));

  double get _pending {
    final discount = double.tryParse(_discountController.text) ?? 0;
    final paid = double.tryParse(_paidController.text) ?? 0;
    return (_total - discount - paid).clamp(0, double.infinity);
  }

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
    _discountController.addListener(() => setState(() {}));
    _paidController.addListener(() => setState(() {}));

    _qtyController.addListener(() {
      setState(() {}); // rebuild to refresh button state
    });
    _priceController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _paidController.dispose();
    _qtyFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDropdownData() async {
    final db = await DatabaseHelper.instance.db;
    final customerDao = CustomerDao(db);
    final productDao = ProductDao(db);

    final customers = await customerDao.getAllCustomers();
    final products = await productDao.getAll();

    setState(() {
      _customers = customers;
      _products = products;

      // Auto-select Walk-in customer if available
      if (_customers.any(
        (c) =>
            c.name.toLowerCase().contains("walk-in") ||
            c.name.toLowerCase().contains("general"),
      )) {
        _selectedCustomer = _customers.firstWhere(
          (c) =>
              c.name.toLowerCase().contains("walk-in") ||
              c.name.toLowerCase().contains("general"),
        );
      } else if (_customers.isNotEmpty) {
        // Option: add a virtual walk-in or just take the first one
      }

      _loading = false;
    });
  }

  Future<void> _loadAvailableStock() async {
    if (_selectedProduct == null) {
      setState(() => _availableStock = 0);
      return;
    }

    final prefs = PreferencesService.instance;
    final includeExpired = await prefs.getIncludeExpiredInOrders();

    final db = await DatabaseHelper.instance.db;
    final batchDao = ProductBatchDao(db);

    // ✅ Use new method to get filtered batches
    final batches = await batchDao.getAvailableBatches(
      _selectedProduct!.id,
      includeExpired: includeExpired,
    );

    final totalStock = batches.fold<int>(0, (sum, b) => sum + b.qty);

    setState(() => _availableStock = totalStock);
  }

  Future<void> _addItem() async {
    if (_selectedProduct == null || _qtyController.text.isEmpty) return;

    if (!_products.any((p) => p.id == _selectedProduct?.id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid product selected")));
      return;
    }

    // Refresh stock check before adding
    await _loadAvailableStock();

    if (_availableStock <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This product is out of stock!")),
      );
      return;
    }

    final qty = (num.tryParse(_qtyController.text) ?? 1).toInt();
    final customPrice =
        double.tryParse(_priceController.text) ??
        (_selectedProduct?.sellPrice ?? 0.0);

    if (qty <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Quantity must be greater than zero")),
      );
      return;
    }

    if (qty > _availableStock) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Only $_availableStock items available!")),
      );
      return;
    }

    final db = await DatabaseHelper.instance.db;
    final batchDao = ProductBatchDao(db);
    final prefs = PreferencesService.instance;
    final includeExpired = await prefs.getIncludeExpiredInOrders();

    // ✅ Use stored weighted average cost from products table
    // The products.cost_price is automatically updated via recalculateProductFromBatches()
    // when new stock arrives or batches are modified, ensuring consistent costing
    final costPrice = _selectedProduct!.costPrice;

    // Deduct stock (FIFO)
    final reservedBatches = await batchDao.deductFromBatches(
      _selectedProduct!.id,
      qty,
      trackUsage: true,
      includeExpired: includeExpired,
    );
    assert(costPrice >= 0, "Cost price cannot be negative");

    final item = InvoiceItem(
      id: _uuid.v4(),
      invoiceId: "",
      productId: _selectedProduct!.id,
      qty: qty,
      price: customPrice, // 👈 Use custom price instead of default
      costPrice: costPrice, // 👈 Capture historical cost for COGS
      reservedBatches: reservedBatches,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    setState(() {
      _items.add(item);
      _selectedProduct = null;
      _qtyController.clear();
      _priceController.clear();
    });

    await _loadAvailableStock();
  }

  Future<void> _removeItem(InvoiceItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Item?"),
        content: const Text("Do you want to remove this item from the order?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final db = await DatabaseHelper.instance.db;
    final batchDao = ProductBatchDao(db);

    if (item.reservedBatches != null) {
      await Future.wait(
        item.reservedBatches!.map((batchInfo) async {
          final batchId = batchInfo['batchId'] as String;
          final qty = (batchInfo['qty'] as num).toInt();
          await batchDao.addBackToBatch(batchId, qty);
        }),
      );
    }

    setState(() => _items.remove(item));
    await _loadAvailableStock();
  }

  Future<void> _saveOrder() async {
    if (_selectedCustomer == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a customer and add at least one item"),
        ),
      );
      return;
    }

    // 1️⃣ Calculate totals and pending
    final discount = double.tryParse(_discountController.text) ?? 0;
    final paid = double.tryParse(_paidController.text) ?? 0;
    final total = _total;
    // The actual balance change for the customer (can be negative if overpaid)
    final realPending = total - discount - paid;
    // The invoice pending amount (cannot be negative)
    final invoicePending = realPending.clamp(0, double.infinity);

    // 2️⃣ Overpayment Validation
    if (realPending < 0) {
      final overpaidAmount = realPending.abs();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Overpayment Detected"),
          content: Text(
            "The paid amount exceeds the total due by ${_selectedCustomer != null ? "" : "Rs "}${overpaidAmount.toStringAsFixed(2)}.\n\n"
            "Do you want to credit this excess amount to the customer's wallet?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Yes, Credit Customer"),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    if (!mounted) return;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final db = await DatabaseHelper.instance.db;
    final invoiceId = _uuid.v4();

    await db.transaction((txn) async {
      final invoiceDao = InvoiceDao(txn);
      final itemDao = InvoiceItemDao(txn);
      final productDao = ProductDao(txn);
      final customerDao = CustomerDao(txn);

      final invoice = Invoice(
        id: invoiceId,
        customerId: _selectedCustomer!.id,
        total: total,
        discount: discount,
        paid: paid,
        pending: invoicePending
            .toDouble(), // Invoice record gets 0 if fully paid
        status: 'posted',
        date: DateTime.now().toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      await invoiceDao.insert(invoice, _selectedCustomer!.name);

      // 👇 Allocate discount proportionally to items
      double remainingDiscount = discount;
      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        double itemDiscount = 0.0;

        if (i == _items.length - 1) {
          // Last item gets remainder to avoid rounding drift
          itemDiscount = remainingDiscount;
        } else {
          // Proportional allocation
          final itemTotal = item.qty * item.price;
          itemDiscount = double.parse(
            ((itemTotal / total) * discount).toStringAsFixed(2),
          );
          remainingDiscount -= itemDiscount;
        }

        // Create item with allocated discount
        final itemWithDiscount = InvoiceItem(
          id: item.id,
          invoiceId: invoiceId,
          productId: item.productId,
          qty: item.qty,
          price: item.price,
          costPrice: item.costPrice,
          discount: itemDiscount,
          reservedBatches: item.reservedBatches,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        );

        await itemDao.insert(itemWithDiscount);
        await productDao.refreshProductQuantityFromBatches(item.productId);
      }

      // 3️⃣ Update Customer Ledger with REAL Pending (allows negative/credit)
      await customerDao.updatePendingAmount(
        _selectedCustomer!.id,
        realPending.toDouble(),
      );
    });

    // 4️⃣ Direct Printing
    try {
      final printItems = _items.map((item) {
        final product = _products.firstWhere((p) => p.id == item.productId);
        return {
          'product_name': product.name,
          'qty': item.qty,
          'price': item.price,
        };
      }).toList();

      final printInvoice = Invoice(
        id: invoiceId,
        customerId: _selectedCustomer!.id,
        customerName: _selectedCustomer!.name,
        total: total,
        discount: discount,
        paid: paid,
        pending: invoicePending.toDouble(),
        date: DateTime.now().toIso8601String(),
        status: 'posted',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      await printSilentThermalReceipt(printInvoice, items: printItems);
    } catch (e) {
      logger.error('OrderFormScreen', 'Direct printing failed', error: e);
    }

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Order created successfully!")),
    );

    if (widget.isTab) {
      // Reset form instead of popping
      setState(() {
        _items.clear();
        _selectedProduct = null;
        _qtyController.clear();
        _priceController.clear();
        _discountController.text = "0";
        _paidController.text = "0";
        // Keep customer if it's a walk-in, or clear? Better clear or reset to default.
        _loadDropdownData();
      });
    } else {
      Navigator.pop(context); // Close screen
    }
  }

  Future<void> _showAddCustomerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final dialogFormKey = GlobalKey<FormState>();

    final result = await showDialog<Customer>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Customer"),
        content: Form(
          key: dialogFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Customer Name *"),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Phone Number"),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!RegExp(r'^[0-9+]+$').hasMatch(value)) {
                      return 'Invalid number';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (dialogFormKey.currentState!.validate()) {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();

                final db = await DatabaseHelper.instance.db;
                final customerDao = CustomerDao(db);
                final now = DateTime.now().toIso8601String();
                final newCustomer = Customer(
                  id: const Uuid().v4(),
                  name: name,
                  phone: phone,
                  pendingAmount: 0,
                  createdAt: now,
                  updatedAt: now,
                );
                await customerDao.insertCustomer(newCustomer);
                if (!context.mounted) return;
                Navigator.pop(context, newCustomer);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _customers.add(result);
        _selectedCustomer = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.isTab
          ? const Center(child: CircularProgressIndicator())
          : const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final content = SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 🧍 Customer Section
                    _buildCustomerCard(),

                    // 📦 Product Selection Section
                    _buildProductSelectionCard(),

                    const SizedBox(height: 12),

                    // 🧾 Order Items Table
                    _buildItemsTable(),

                    const SizedBox(height: 100), // Space for sticky footer
                  ],
                ),
              ),
            ),
          ),
          _buildStickyFooter(),
        ],
      ),
    );

    if (widget.isTab) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Create Order"), elevation: 0),
      body: content,
    );
  }

  Widget _buildCustomerCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person, size: 20, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  "Customer Details",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownSearch<Customer>(
                    items: (items, props) => _customers,
                    selectedItem: _selectedCustomer,
                    compareFn: (a, b) => a.id == b.id,
                    itemAsString: (c) => c.name,
                    popupProps: PopupProps.modalBottomSheet(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          hintText: "Search Customer...",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    decoratorProps: DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: "Select Customer",
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _selectedCustomer = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.person_add, color: Colors.blue),
                    onPressed: _showAddCustomerDialog,
                    tooltip: "Add New Customer",
                  ),
                ),
              ],
            ),
            if (_selectedCustomer != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "Current Balance: Rs ${_selectedCustomer!.pendingAmount.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSelectionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory, size: 20, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  "Product Selection",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownSearch<Product>(
                    items: (items, props) => _products,
                    selectedItem: _selectedProduct,
                    compareFn: (a, b) => a.id == b.id,
                    itemAsString: (p) => "${p.name} (${p.sku})",
                    popupProps: PopupProps.modalBottomSheet(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          hintText: "Search Product / SKU...",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    decoratorProps: DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: "Select Product",
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    onChanged: (val) async {
                      setState(() {
                        _selectedProduct = val;
                        if (val != null) {
                          _priceController.text = val.sellPrice.toString();
                        } else {
                          _priceController.clear();
                        }
                      });
                      await _loadAvailableStock();
                      if (val != null) {
                        _qtyFocusNode.requestFocus();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _qtyController,
                    focusNode: _qtyFocusNode,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: "Qty",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onFieldSubmitted: (_) => _priceFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _priceController,
                    focusNode: _priceFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: "Price",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onFieldSubmitted: (_) => _addItem(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed:
                        (_selectedProduct != null &&
                            _qtyController.text.isNotEmpty &&
                            _priceController.text.isNotEmpty)
                        ? _addItem
                        : null,
                    tooltip: "Add to Order",
                  ),
                ),
              ],
            ),
            if (_selectedProduct != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    _buildInfoChip(
                      icon: Icons.store,
                      label: "Stock: $_availableStock",
                      color: _availableStock > 0 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.payments,
                      label: "Price: Rs ${_selectedProduct!.sellPrice}",
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                "No items added yet",
                style: TextStyle(color: Colors.grey[500], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    "Product",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    "Qty",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Total",
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 40),
              ],
            ),
          ),
          ..._items.map((item) {
            final product = _products.firstWhere(
              (p) => p.id == item.productId,
              orElse: () => Product(
                id: item.productId,
                name: "Unknown",
                description: "",
                sku: "",
                defaultUnit: "pcs",
                costPrice: 0,
                sellPrice: item.price,
                quantity: 0,
                minStock: 0,
                trackExpiry: false,
                supplierId: null,
                createdAt: "",
                updatedAt: "",
              ),
            );
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          "@ ${item.price}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text("${item.qty}", textAlign: TextAlign.center),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "Rs ${(item.qty * item.price).toStringAsFixed(2)}",
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () => _removeItem(item),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: "Discount",
                    prefixText: "Rs ",
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _paidController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: "Paid",
                    prefixText: "Rs ",
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total Payable",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    "Rs ${_total.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Balance Due",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    "Rs ${_pending.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _pending > 0
                          ? Colors.orange[700]
                          : Colors.green[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saveOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline),
                  SizedBox(width: 8),
                  Text(
                    "COMPLETE ORDER",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

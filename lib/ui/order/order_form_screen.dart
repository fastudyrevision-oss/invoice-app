import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/invoice_item.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../dao/customer_dao.dart';
import '../../dao/product_dao.dart';
import '../../dao/product_batch_dao.dart';
import '../../dao/invoice_dao.dart';
import '../../dao/invoice_item_dao.dart';
import '../../models/invoice.dart';
import '../../models/product_batch.dart';
import '../../db/database_helper.dart';

class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  Customer? _selectedCustomer;
  Product? _selectedProduct;
  final _qtyController = TextEditingController();
  final _discountController = TextEditingController(text: "0");
  final _paidController = TextEditingController(text: "0");

  List<Customer> _customers = [];
  List<Product> _products = [];
  final List<InvoiceItem> _items = [];

  bool _loading = true;
  int _availableStock = 0;

  double get _total => _items.fold(0, (sum, i) => sum + (i.price * i.qty));

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _discountController.dispose();
    _paidController.dispose();
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
      _loading = false;
    });
  }

  Future<void> _loadAvailableStock() async {
    if (_selectedProduct == null) {
      setState(() => _availableStock = 0);
      return;
    }

    final db = await DatabaseHelper.instance.db;
    final batchDao = ProductBatchDao(db);
    final batches = await batchDao.getBatchesByProduct(_selectedProduct!.id);
    final totalStock = batches.fold<int>(0, (sum, b) => sum + b.qty);

    setState(() => _availableStock = totalStock);
  }

  Future<void> _addItem() async {
    if (_selectedProduct == null || _qtyController.text.isEmpty) return;

    // ✅ Validate valid product
    if (!_products.any((p) => p.id == _selectedProduct?.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid product selected")),
      );
      return;
    }

    // ✅ Validate stock
    if (_availableStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This product is out of stock!")),
      );
      return;
    }

    final qty = (num.tryParse(_qtyController.text) ?? 1).toInt();

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Quantity must be greater than zero")),
      );
      return;
    }

    if (qty > _availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Only $_availableStock items available!")),
      );
      return;
    }

    final db = await DatabaseHelper.instance.db;
    final batchDao = ProductBatchDao(db);

    final batches = await batchDao.getBatchesByProduct(_selectedProduct!.id);
    batches.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Snapshot original quantities
    final originalQtys = {for (var b in batches) b.id: b.qty};

    int remainingQty = qty;
    final List<ProductBatch> updatedBatches = [];

    for (final batch in batches) {
      if (remainingQty <= 0) break;
      final deduction = batch.qty >= remainingQty ? remainingQty : batch.qty;
      batch.qty -= deduction;
      remainingQty -= deduction;
      updatedBatches.add(batch);
    }

    // ✅ Sequential batch update
    await Future.wait(updatedBatches.map(batchDao.updateBatch));

    // Build reserved batch list
    final reservedBatches = updatedBatches.map((b) {
      final deducted = (originalQtys[b.id] ?? 0) - b.qty;
      return {'batchId': b.id, 'qty': deducted};
    }).where((b) => ((b['qty'] ?? 0) as num) > 0).toList();

    // ✅ Add product to order
    final item = InvoiceItem(
      id: _uuid.v4(),
      invoiceId: "",
      productId: _selectedProduct!.id,
      qty: qty,
      price: _selectedProduct!.sellPrice,
      reservedBatches: reservedBatches,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    setState(() {
      _items.add(item);
      _selectedProduct = null;
      _qtyController.clear();
    });

    await _loadAvailableStock(); // ✅ refresh stock
  }

  Future<void> _removeItem(InvoiceItem item) async {
    final db = await DatabaseHelper.instance.db;
    final batchDao = ProductBatchDao(db);

    if (item.reservedBatches != null) {
      await Future.wait(item.reservedBatches!.map((batchInfo) async {
        final batchId = batchInfo['batchId'] as String;
        final qty = (batchInfo['qty'] as num).toInt();
        await batchDao.addBackToBatch(batchId, qty);
      }));
    }

    setState(() => _items.remove(item));
    await _loadAvailableStock(); // ✅ refresh stock after removal
  }

  Future<void> _saveOrder() async {
    if (_selectedCustomer == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a customer and add at least one item")),
      );
      return;
    }

    final discount = double.tryParse(_discountController.text) ?? 0;
    final paid = double.tryParse(_paidController.text) ?? 0;
    final total = _total;
    final pending = (total - discount - paid).clamp(0, double.infinity);

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
        pending: pending.toDouble(),
        date: DateTime.now().toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      await invoiceDao.insert(invoice, _selectedCustomer!.name);

      // ✅ Sequential item + product refresh
      for (final item in _items) {
        item.invoiceId = invoiceId;
        await itemDao.insert(item);
        await productDao.refreshProductQuantityFromBatches(item.productId);
      }

      await customerDao.updatePendingAmount(_selectedCustomer!.id, invoice.pending);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Order created successfully!")),
    );

    Navigator.pop(context);
  }

  Future<void> _showAddCustomerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<Customer>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Customer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Customer Name"),
            ),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Phone Number"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isEmpty) return;

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
              Navigator.pop(context, newCustomer);
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Create Order")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text("Select Customer"),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Customer>(
                      value: _selectedCustomer,
                      items: [
                        ..._customers.map(
                          (c) => DropdownMenuItem(value: c, child: Text(c.name)),
                        ),
                        const DropdownMenuItem<Customer>(
                          value: null,
                          child: Text("➕ Add New Customer"),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == null) {
                          _showAddCustomerDialog();
                        } else {
                          setState(() => _selectedCustomer = val);
                        }
                      },
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text("Add Product"),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<Product>(
                      value: _selectedProduct,
                      items: _products
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.name),
                              ))
                          .toList(),
                      onChanged: (val) async {
                        setState(() => _selectedProduct = val);
                        await _loadAvailableStock();
                      },
                      decoration: const InputDecoration(labelText: "Product"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Qty"),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: _addItem,
                  ),
                ],
              ),

              if (_selectedProduct != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, bottom: 12.0),
                  child: Text(
                    "Available Stock: $_availableStock",
                    style: TextStyle(
                      color: _availableStock > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              if (_items.isNotEmpty)
                Column(
                  children: _items.map((item) {
                    final product = _products.firstWhere((p) => p.id == item.productId);
                    return ListTile(
                      title: Text(product.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Qty: ${item.qty} × ${item.price}"),
                          if (item.reservedBatches != null && item.reservedBatches!.isNotEmpty)
                            Text(
                              "Batches: ${item.reservedBatches!.map((b) => '${b['batchId'].substring(0, 6)}(${b['qty']})').join(', ')}",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeItem(item),
                      ),
                    );
                  }).toList(),
                ),

              const Divider(),
              Text("Total: $_total"),
              TextFormField(
                controller: _discountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Discount"),
              ),
              TextFormField(
                controller: _paidController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Paid"),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _saveOrder,
                icon: const Icon(Icons.save),
                label: const Text("Save Order"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

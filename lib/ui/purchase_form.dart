import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../repositories/purchase_repo.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../models/product_batch.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_repo.dart';
import '../repositories/supplier_payment_repo.dart';
// 🔹 Import ProductDialog from your file
import 'product_dialogue_frame.dart';
import '../utils/responsive_utils.dart';
import '../utils/date_helper.dart';
import 'package:intl/intl.dart';

class PurchaseForm extends StatefulWidget {
  final PurchaseRepository repo;
  final ProductRepository productRepo;
  final SupplierRepository supplierRepo;
  final SupplierPaymentRepository paymentRepo;

  const PurchaseForm({
    super.key,
    required this.repo,
    required this.productRepo,
    required this.supplierRepo,
    required this.paymentRepo,
  });

  @override
  State<PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends State<PurchaseForm> {
  final _formKey = GlobalKey<FormState>();
  final _paidCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _paymentMethod = 'cash';
  String? _selectedSupplierId;
  DateTime _selectedDate = DateTime.now();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  final List<PurchaseItem> _items = [];
  final List<ProductBatch> _batches = [];
  double _total = 0.0;

  void _addItem() async {
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select a supplier first")));
      return;
    }
    final newItemData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PurchaseItemDialog(
        repo: widget.repo,
        productRepo: widget.productRepo,
        supplierRepo: widget.supplierRepo,
        supplierId: _selectedSupplierId!, // ✅ pass from parent
      ),
    );

    if (newItemData != null) {
      final item = newItemData["item"] as PurchaseItem;
      final batch = newItemData["batch"] as ProductBatch;

      setState(() {
        _items.add(item);
        _batches.add(batch);
        _total += item.purchasePrice * item.qty;
      });
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplierId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select a supplier")));
      return;
    }

    final purchaseId = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    final dateStr = _selectedDate.toIso8601String();
    final paidAmount = double.tryParse(_paidCtrl.text) ?? 0.0;

    // ✅ FIX: Initialize purchase with paid=0, pending=total
    // This prevents double-counting when addPayment is called
    final purchase = Purchase(
      id: purchaseId,
      supplierId: _selectedSupplierId!,
      invoiceNo: purchaseId,
      total: _total,
      paid: 0.0, // ✅ Start at 0, let addPayment handle it
      pending: _total, // ✅ Full amount is pending initially
      date: dateStr,
      createdAt: now,
      updatedAt: now,
    );

    final items = _items
        .map((i) => i.copyWith(purchaseId: purchaseId))
        .toList();
    final batches = _batches
        .map((b) => b.copyWith(purchaseId: purchaseId))
        .toList();

    await widget.repo.insertPurchaseWithItems(
      purchase: purchase,
      items: items,
      batches: batches,
    );

    // ✅ Recalculate each product's average price & stock directly from batches
    for (var item in items) {
      await widget.productRepo.recalculateProductFromBatches(item.productId);
    }

    // 💰 Record formal payment record if any money was paid upfront
    // addPayment will update the purchase paid/pending AND recalculate supplier balance
    if (paidAmount > 0) {
      await widget.paymentRepo.addPayment(
        _selectedSupplierId!,
        paidAmount,
        purchaseId: purchaseId,
        method: _paymentMethod,
        transactionRef: _refCtrl.text.trim(),
        note: "Upfront payment for Purchase #$purchaseId",
      );
    } else {
      // ✅ If no payment, still need to recalculate supplier balance to reflect the new debt
      // Use centralized calculation to ensure consistency and prevent double-counting
      await widget.paymentRepo.recalculateSupplierBalance(_selectedSupplierId!);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveUtils.isMobile(context);
        return Scaffold(
          appBar: AppBar(title: const Text("Add Purchase")),
          body: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const SizedBox(height: 10),
                  // Date Picker Row
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Purchase Date",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateHelper.formatDate(_selectedDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<Supplier>>(
                    future: widget.repo.getAllSuppliers(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final suppliers = snapshot.data!;

                      return DropdownSearch<String>(
                        items: (items, props) =>
                            suppliers.map((s) => s.id).toList(),
                        selectedItem: _selectedSupplierId,
                        itemAsString: (id) {
                          final supplier = suppliers.firstWhere(
                            (s) => s.id == id,
                          );
                          return supplier.name;
                        },
                        popupProps: const PopupProps.modalBottomSheet(
                          showSearchBox: true,
                          constraints: BoxConstraints(maxHeight: 500),
                          searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
                              labelText: "Search Supplier",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        decoratorProps: const DropDownDecoratorProps(
                          decoration: InputDecoration(
                            labelText: "Supplier",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() => _selectedSupplierId = val);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _paidCtrl,
                    decoration: const InputDecoration(labelText: "Paid Amount"),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  if ((double.tryParse(_paidCtrl.text) ?? 0) > 0) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: "Payment Method",
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text("Cash")),
                        DropdownMenuItem(value: 'bank', child: Text("Bank")),
                        DropdownMenuItem(value: 'card', child: Text("Card")),
                        DropdownMenuItem(
                          value: 'cheque',
                          child: Text("Cheque"),
                        ),
                      ],
                      onChanged: (v) => setState(() => _paymentMethod = v!),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _refCtrl,
                      decoration: const InputDecoration(
                        labelText: "Ref No / Cheque No",
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text("Total: $_total"),
                  Text(
                    "Pending: ${(_total - (double.tryParse(_paidCtrl.text) ?? 0)).toStringAsFixed(2)}",
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Item"),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Items: ${_items.length}",
                    style: const TextStyle(fontSize: 16),
                  ),
                  for (var item in _items)
                    ListTile(
                      title: Text("Product: ${item.productId}"),
                      subtitle: Text(
                        "Qty: ${item.qty}, Price: ${item.purchasePrice}",
                      ),
                    ),
                  const Divider(),
                  Text(
                    "Total: $_total",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _save,
                    child: const Text("Save Purchase"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PurchaseItemDialog extends StatefulWidget {
  final PurchaseRepository repo;
  final ProductRepository productRepo;
  final SupplierRepository supplierRepo;
  final String supplierId; // ✅ add this

  const _PurchaseItemDialog({
    required this.repo,
    required this.productRepo,
    required this.supplierRepo,
    required this.supplierId, // ✅ required param
  });

  @override
  State<_PurchaseItemDialog> createState() => _PurchaseItemDialogState();
}

class _PurchaseItemDialogState extends State<_PurchaseItemDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedProductId;
  final _qtyCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController();
  final _sellPriceCtrl = TextEditingController();
  final _batchNoCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    final purchasePrice = double.tryParse(_purchasePriceCtrl.text) ?? 0.0;
    final sellPrice = double.tryParse(_sellPriceCtrl.text) ?? 0.0;

    final item = PurchaseItem(
      id: const Uuid().v4(),
      purchaseId: "",
      productId: _selectedProductId!,
      qty: qty,
      purchasePrice: purchasePrice,
      sellPrice: sellPrice,
      batchNo: _batchNoCtrl.text,
      expiryDate: _expiryCtrl.text.isEmpty ? null : _expiryCtrl.text,
    );

    final batch = ProductBatch(
      id: const Uuid().v4(),
      productId: _selectedProductId!,
      batchNo: _batchNoCtrl.text,
      supplierId: widget.supplierId, // ✅ assign supplierId here
      expiryDate: _expiryCtrl.text.isEmpty ? null : _expiryCtrl.text,
      qty: qty,
      purchasePrice: purchasePrice,
      sellPrice: sellPrice,
      purchaseId: "",
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    Navigator.pop(context, {"item": item, "batch": batch});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Item"),
      content: Form(
        key: _formKey,
        child: FutureBuilder<List<Product>>(
          future: widget.repo.getAllProducts(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            final products = snapshot.data!;

            return SingleChildScrollView(
              child: Column(
                children: [
                  DropdownSearch<String>(
                    items: (items, props) =>
                        products.map((p) => p.id).toList() +
                        ["__new__"], // option for adding a new product
                    selectedItem: _selectedProductId,
                    itemAsString: (id) {
                      if (id == "__new__") return "+ Add New Product";
                      final product = products.firstWhere((p) => p.id == id);
                      return "${product.name} (${product.sku})";
                    },
                    popupProps: const PopupProps.modalBottomSheet(
                      showSearchBox: true,
                      constraints: BoxConstraints(maxHeight: 500),
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          labelText: "Search Product",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: "Product",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    onChanged: (val) async {
                      if (val == "__new__") {
                        final newProduct = await showDialog<Product>(
                          context: context,
                          builder: (_) => ProductDialog(
                            productRepo: widget.productRepo,
                            supplierRepo: widget.supplierRepo,
                          ),
                        );

                        if (newProduct != null) {
                          setState(() {
                            products.add(newProduct);
                            _selectedProductId = newProduct.id;
                          });
                        }
                        return;
                      }

                      setState(() => _selectedProductId = val);
                    },
                    validator: (v) => v == null ? "Required" : null,
                  ),

                  TextFormField(
                    controller: _qtyCtrl,
                    decoration: const InputDecoration(labelText: "Quantity"),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Required";
                      if (int.tryParse(v) == null) return "Invalid number";
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _purchasePriceCtrl,
                    decoration: const InputDecoration(
                      labelText: "Purchase Price",
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        if (double.tryParse(v) == null) return "Invalid price";
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _sellPriceCtrl,
                    decoration: const InputDecoration(labelText: "Sell Price"),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        if (double.tryParse(v) == null) return "Invalid price";
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _batchNoCtrl,
                    decoration: const InputDecoration(labelText: "Batch No"),
                  ),
                  TextFormField(
                    controller: _expiryCtrl,
                    decoration: InputDecoration(
                      labelText: "Expiry Date",
                      hintText: "yyyy-MM-dd",
                      helperText:
                          "Example: ${DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)))}",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 5),
                            ),
                          );
                          if (picked != null) {
                            _expiryCtrl.text = DateFormat(
                              'yyyy-MM-dd',
                            ).format(picked);
                          }
                        },
                      ),
                    ),
                    keyboardType: TextInputType.datetime,
                    validator: (val) {
                      if (val != null && val.isNotEmpty) {
                        try {
                          DateFormat('yyyy-MM-dd').parseStrict(val);
                        } catch (e) {
                          return "Invalid format (yyyy-MM-dd)";
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(onPressed: _submit, child: const Text("Add")),
      ],
    );
  }
}

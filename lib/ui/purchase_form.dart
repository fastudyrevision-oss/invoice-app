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
import '../core/services/audit_logger.dart';
import '../models/ledger_entry.dart';
import '../dao/ledger_dao.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';
import '../exceptions/stock_exception.dart';

class PurchaseForm extends StatefulWidget {
  final PurchaseRepository repo;
  final ProductRepository productRepo;
  final SupplierRepository supplierRepo;
  final SupplierPaymentRepository paymentRepo;
  final Product? prefilledProduct;
  final Purchase? existingPurchase; // 👈 Added for editing
  final List<PurchaseItem>? existingItems; // 👈 Added for editing
  final List<ProductBatch>? existingBatches; // 👈 Added for editing

  const PurchaseForm({
    super.key,
    required this.repo,
    required this.productRepo,
    required this.supplierRepo,
    required this.paymentRepo,
    this.prefilledProduct,
    this.existingPurchase,
    this.existingItems,
    this.existingBatches,
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
  // ✅ Stored future so it can be refreshed after adding a supplier
  late Future<List<Supplier>> _suppliersFuture;

  final List<PurchaseItem> _items = [];
  final List<ProductBatch> _batches = [];
  double _total = 0.0;
  bool _isSaving = false; // Prevents double-submission

  bool get _isEditing => widget.existingPurchase != null;

  // Track original data for "Delete and Re-insert" strategy
  late final List<PurchaseItem> _originalItems;
  late final List<ProductBatch> _originalBatches;

  @override
  void initState() {
    super.initState();
    _suppliersFuture = widget.repo.getAllSuppliers();
    if (_isEditing) {
      _selectedSupplierId = widget.existingPurchase!.supplierId;
      _selectedDate =
          DateTime.tryParse(widget.existingPurchase!.date) ?? DateTime.now();
      _paidCtrl.text = widget.existingPurchase!.paid.toString();
      _total = widget.existingPurchase!.total;

      // ✅ Safe item-to-batch pairing: match each item to a batch by productId
      // This avoids crashes from index mismatches caused by different query orderings.
      final rawItems = List<PurchaseItem>.from(widget.existingItems ?? []);
      final rawBatches = List<ProductBatch>.from(widget.existingBatches ?? []);
      final unmatchedBatches = List<ProductBatch>.from(rawBatches);

      for (final item in rawItems) {
        // Find first unmatched batch for this product + batchNo (higher precision)
        final batchIndex = unmatchedBatches.indexWhere(
          (b) => b.productId == item.productId && b.batchNo == item.batchNo,
        );

        if (batchIndex != -1) {
          _items.add(item);
          _batches.add(unmatchedBatches[batchIndex].copyWith(qty: item.qty));
          unmatchedBatches.removeAt(batchIndex);
        } else {
          // Fallback: match by productId only if unique
          final fallbackIndex = unmatchedBatches.indexWhere(
            (b) => b.productId == item.productId,
          );
          if (fallbackIndex != -1) {
            _items.add(item);
            _batches.add(
              unmatchedBatches[fallbackIndex].copyWith(qty: item.qty),
            );
            unmatchedBatches.removeAt(fallbackIndex);
          } else {
            // No matching batch found — add a placeholder batch to keep lists in sync
            _items.add(item);
            _batches.add(
              ProductBatch(
                id: const Uuid().v4(),
                productId: item.productId,
                batchNo: item.batchNo ?? '',
                supplierId: widget.existingPurchase!.supplierId,
                expiryDate: item.expiryDate,
                qty: item.qty,
                purchasePrice: item.purchasePrice,
                sellPrice: item.sellPrice,
                purchaseId: widget.existingPurchase!.id,
                createdAt: DateTime.now().toIso8601String(),
                updatedAt: DateTime.now().toIso8601String(),
              ),
            );
          }
        }
      }

      _originalItems = List.from(_items);
      _originalBatches = List.from(_batches);
    } else {
      _originalItems = [];
      _originalBatches = [];
    }
  }

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

  void _editItem(int index) async {
    final item = _items[index];
    final batch = _batches[index];

    final updatedData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PurchaseItemDialog(
        repo: widget.repo,
        productRepo: widget.productRepo,
        supplierRepo: widget.supplierRepo,
        supplierId: _selectedSupplierId!,
        initialProductId: item.productId,
        existingItem: item, // 👈 Pass existing item
        existingBatch: batch, // 👈 Pass existing batch
      ),
    );

    if (updatedData != null) {
      setState(() {
        _total -= item.purchasePrice * item.qty;
        _items[index] = updatedData["item"] as PurchaseItem;
        _batches[index] = updatedData["batch"] as ProductBatch;
        _total += _items[index].purchasePrice * _items[index].qty;
      });
    }
  }

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
        initialProductId: widget.prefilledProduct?.id, // ✅ prefill product
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
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    if (_selectedSupplierId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Please select a supplier"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Please add at least one item to the purchase"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final purchaseId = _isEditing
        ? widget.existingPurchase!.id
        : const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    final dateStr = _selectedDate.toIso8601String();
    final paidAmount = double.tryParse(_paidCtrl.text) ?? 0.0;

    final purchase =
        (_isEditing
                ? widget.existingPurchase!
                : Purchase(
                    id: purchaseId,
                    supplierId: _selectedSupplierId!,
                    invoiceNo: purchaseId,
                    total: _total,
                    paid: 0.0,
                    pending: _total,
                    date: dateStr,
                    createdAt: now,
                    updatedAt: now,
                  ))
            .copyWith(
              total: _total,
              date: dateStr,
              updatedAt: now,
              // Note: paid/pending will be managed by recalculateSupplierBalance or addPayment
            );

    final items = _items
        .map((i) => i.copyWith(purchaseId: purchaseId))
        .toList();
    final batches = _batches
        .map((b) => b.copyWith(purchaseId: purchaseId))
        .toList();

    try {
      if (_isEditing) {
        await widget.repo.updatePurchaseWithItems(
          purchase: purchase,
          items: items,
          batches: batches,
          oldItems: _originalItems,
          oldBatches: _originalBatches,
        );

        // ✅ Step 2: Record additional payment if "Paid Amount" was increased in the UI
        final oldPaid = widget.existingPurchase!.paid;
        final newPaidFromUI = double.tryParse(_paidCtrl.text) ?? 0.0;

        if (newPaidFromUI > oldPaid + 0.01) {
          final extra = newPaidFromUI - oldPaid;
          await widget.paymentRepo.addPayment(
            _selectedSupplierId!,
            extra,
            purchaseId: purchaseId,
            method: _paymentMethod,
            transactionRef: _refCtrl.text.trim(),
            note: "Additional payment during Purchase Edit #$purchaseId",
          );
        } else if (newPaidFromUI < oldPaid - 0.01) {
          // UX/Safety: Don't allow reducing paid amount here as it breaks audit trail
          // (Requires deleting specific payment records from detail frame)
          debugPrint("Warning: Reduction in Paid amount ignored in edit form.");
        }

        // ✅ Step 3: Immediately recalculate purchase.paid/pending from ALL actual payments
        final db = widget.repo.db;
        final paymentRows = await db.query(
          'supplier_payments',
          where: 'purchase_id = ? AND deleted = 0',
          whereArgs: [purchaseId],
        );
        double actualPaid = 0;
        for (var row in paymentRows) {
          actualPaid += (row['amount'] as num? ?? 0).toDouble();
        }
        final newPending = _total - actualPaid;
        await db.update(
          'purchases',
          {'total': _total, 'paid': actualPaid, 'pending': newPending},
          where: 'id = ?',
          whereArgs: [purchaseId],
        );

        // ✅ Step 4: Log ledger adjustment if total changed
        final oldTotal = widget.existingPurchase!.total;
        final diff = _total - oldTotal;

        if (diff.abs() > 0.01) {
          final ledgerDao = LedgerDao(widget.repo.db);
          await ledgerDao.insert(
            LedgerEntry(
              id: const Uuid().v4(),
              entityId: _selectedSupplierId!,
              entityType: 'supplier',
              date: now,
              description:
                  "Adjustment for Purchase #$purchaseId (Total changed from $oldTotal to $_total)",
              debit: diff < 0 ? diff.abs() : 0,
              credit: diff > 0 ? diff : 0,
              balance: 0,
            ),
          );
        }

        await AuditLogger.log(
          'PURCHASE_ADJUST',
          'purchases',
          recordId: purchaseId,
          userId: AuthService.instance.currentUser?.id ?? 'system',
          oldData: {
            'total': oldTotal,
            'items': _originalItems.map((e) => e.toMap()).toList(),
          },
          newData: {
            'total': _total,
            'items': items.map((e) => e.toMap()).toList(),
          },
          txn: widget.repo.db,
        );
      } else {
        await widget.repo.insertPurchaseWithItems(
          purchase: purchase,
          items: items,
          batches: batches,
        );

        // Record upfront payment for new purchase
        if (paidAmount > 0) {
          await widget.paymentRepo.addPayment(
            _selectedSupplierId!,
            paidAmount,
            purchaseId: purchaseId,
            method: _paymentMethod,
            transactionRef: _refCtrl.text.trim(),
            note: "Upfront payment for Purchase #$purchaseId",
          );
        }
      }

      // ✅ Step 3: Now recalculate the supplier's overall balance
      // At this point purchase.pending is already correct in the DB
      await widget.paymentRepo.recalculateSupplierBalance(_selectedSupplierId!);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      if (e is StockConstraintException) {
        _showStockConflictDialog(e);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showStockConflictDialog(StockConstraintException e) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text("Stock Constraint"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.message),
            if (e.relatedInvoices.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                "Related Sales Invoices:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: e.relatedInvoices.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.receipt_long, size: 20),
                      title: Text("Invoice #${e.relatedInvoices[index]}"),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Please edit or delete these sales invoices before reducing this purchase quantity.",
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Understand"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddNewSupplier() async {
    final newSupplier = await showDialog<Supplier>(
      context: context,
      builder: (_) => const _QuickAddSupplierDialog(),
    );
    if (newSupplier != null && mounted) {
      // Persist to DB, then refresh the future so FutureBuilder re-runs with new list
      await widget.supplierRepo.insertSupplier(newSupplier);
      setState(() {
        _selectedSupplierId = newSupplier.id;
        _suppliersFuture = widget.repo
            .getAllSuppliers(); // ✅ forces list refresh
      });
    }
  }

  Future<void> _removeItem(int idx) async {
    final batch = _batches[idx];
    final item = _items[idx];

    // ✅ QA Guard: Check if anything from this batch has been sold
    final soldQty = await widget.repo.getSoldQtyForBatch(batch.id);
    if (soldQty > 0) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Cannot Delete Item"),
            content: Text(
              "This item cannot be deleted because $soldQty units have already been sold. "
              "Please delete or edit the related sales invoices first.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Understand"),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Confirmation for non-sold items
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text(
          "Are you sure you want to remove this item from the purchase?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _total -= item.purchasePrice * item.qty;
        _items.removeAt(idx);
        _batches.removeAt(idx);
      });
    }
  }

  Future<bool> _handleBackPress() async {
    if (_items.isEmpty && !_isEditing) return true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Discard Changes?"),
        content: const Text(
          "You have unsaved changes. Are you sure you want to discard them?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Keep Editing"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Discard"),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  void _forceRefreshItems() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🔄 Synchronizing item identities...")),
    );
    setState(() {
      final rawItems = List<PurchaseItem>.from(_items);
      final rawBatches = List<ProductBatch>.from(_originalBatches);
      final unmatchedBatches = List<ProductBatch>.from(rawBatches);

      _items.clear();
      _batches.clear();

      for (final item in rawItems) {
        final batchIndex = unmatchedBatches.indexWhere(
          (b) => b.productId == item.productId && b.batchNo == item.batchNo,
        );
        if (batchIndex != -1) {
          _items.add(item);
          _batches.add(unmatchedBatches[batchIndex].copyWith(qty: item.qty));
          unmatchedBatches.removeAt(batchIndex);
        } else {
          final fallbackIndex = unmatchedBatches.indexWhere(
            (b) => b.productId == item.productId,
          );
          if (fallbackIndex != -1) {
            _items.add(item);
            _batches.add(
              unmatchedBatches[fallbackIndex].copyWith(qty: item.qty),
            );
            unmatchedBatches.removeAt(fallbackIndex);
          } else {
            // Placeholder fallback
            _items.add(item);
            _batches.add(
              ProductBatch(
                id: const Uuid().v4(),
                productId: item.productId,
                batchNo: item.batchNo ?? '',
                supplierId: _selectedSupplierId,
                qty: item.qty,
                purchasePrice: item.purchasePrice,
                sellPrice: item.sellPrice,
                purchaseId: widget.existingPurchase?.id ?? "",
                createdAt: DateTime.now().toIso8601String(),
                updatedAt: DateTime.now().toIso8601String(),
              ),
            );
          }
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Items synchronized! Try saving now."),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveUtils.isMobile(context);
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldPop = await _handleBackPress();
            if (shouldPop && context.mounted) {
              Navigator.pop(context);
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                _isEditing ? "Edit Purchase" : "Add Purchase",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              actions: [
                if (_isEditing)
                  IconButton(
                    tooltip: "Fix Stock Identities",
                    icon: const Icon(Icons.sync, color: Colors.white),
                    onPressed: _forceRefreshItems,
                  ),
              ],
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade800, Colors.indigo.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              elevation: 4,
            ),
            body: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12 : 24),
              child: Form(
                key: _formKey,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- SECTION 1: Supplier & Date ---
                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.business, color: Colors.indigo),
                                    SizedBox(width: 8),
                                    Text(
                                      "Supplier Information",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: FutureBuilder<List<Supplier>>(
                                        future: _suppliersFuture,
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) {
                                            return const SizedBox();
                                          }
                                          final suppliers = snapshot.data!;

                                          return DropdownSearch<String>(
                                            items: (items, props) {
                                              final ids = suppliers
                                                  .map((s) => s.id)
                                                  .toList();
                                              // ✅ "Add New Supplier" always first
                                              return [
                                                '__new_supplier__',
                                                ...ids,
                                              ];
                                            },
                                            selectedItem: _selectedSupplierId,
                                            itemAsString: (id) {
                                              if (id == '__new_supplier__') {
                                                return '+ Add New Supplier';
                                              }
                                              // ✅ orElse prevents crash when list
                                              // hasn't refreshed yet after add
                                              final supplier = suppliers
                                                  .firstWhere(
                                                    (s) => s.id == id,
                                                    orElse: () => Supplier(
                                                      id: id,
                                                      name: 'Loading...',
                                                      pendingAmount: 0,
                                                      creditLimit: 0,
                                                      createdAt: '',
                                                      updatedAt: '',
                                                      deleted: 0,
                                                    ),
                                                  );
                                              return supplier.name;
                                            },
                                            popupProps:
                                                const PopupProps.modalBottomSheet(
                                                  showSearchBox: true,
                                                  constraints: BoxConstraints(
                                                    maxHeight: 500,
                                                  ),
                                                  searchFieldProps: TextFieldProps(
                                                    decoration: InputDecoration(
                                                      labelText:
                                                          'Search Supplier',
                                                      prefixIcon: Icon(
                                                        Icons.search,
                                                      ),
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                  ),
                                                ),
                                            decoratorProps:
                                                const DropDownDecoratorProps(
                                                  decoration: InputDecoration(
                                                    labelText: 'Supplier',
                                                    border:
                                                        OutlineInputBorder(),
                                                    prefixIcon: Icon(
                                                      Icons.person,
                                                    ),
                                                  ),
                                                ),
                                            onChanged: (val) async {
                                              if (val == '__new_supplier__') {
                                                await _handleAddNewSupplier();
                                                return;
                                              }
                                              setState(
                                                () => _selectedSupplierId = val,
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // ✅ Quick-add supplier button
                                    Tooltip(
                                      message: 'Quick Add New Supplier',
                                      child: InkWell(
                                        onTap: _handleAddNewSupplier,
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.shade50,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.indigo.shade200,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.person_add,
                                            color: Colors.indigo,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 1,
                                      child: InkWell(
                                        onTap: _pickDate,
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: "Purchase Date",
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(
                                              Icons.calendar_today,
                                            ),
                                          ),
                                          child: Text(
                                            DateHelper.formatDate(
                                              _selectedDate,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- SECTION 2: Payment Details ---
                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.payment, color: Colors.indigo),
                                    SizedBox(width: 8),
                                    Text(
                                      "Payment Details",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _paidCtrl,
                                        decoration: const InputDecoration(
                                          labelText: "Paid Amount",
                                          prefixIcon: Icon(
                                            Icons.monetization_on,
                                          ),
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    if ((double.tryParse(_paidCtrl.text) ?? 0) >
                                        0) ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: _paymentMethod,
                                          decoration: const InputDecoration(
                                            labelText: "Method",
                                            border: OutlineInputBorder(),
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'cash',
                                              child: Text("Cash"),
                                            ),
                                            DropdownMenuItem(
                                              value: 'bank',
                                              child: Text("Bank"),
                                            ),
                                            DropdownMenuItem(
                                              value: 'card',
                                              child: Text("Card"),
                                            ),
                                            DropdownMenuItem(
                                              value: 'cheque',
                                              child: Text("Cheque"),
                                            ),
                                          ],
                                          onChanged: (v) => setState(
                                            () => _paymentMethod = v!,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if ((double.tryParse(_paidCtrl.text) ?? 0) >
                                    0) ...[
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _refCtrl,
                                    decoration: const InputDecoration(
                                      labelText: "Reference / Cheque No",
                                      prefixIcon: Icon(Icons.numbers),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- SECTION 3: Items List ---
                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.shopping_cart,
                                          color: Colors.indigo,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Purchase Items",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _addItem,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(Icons.add),
                                      label: const Text("Add Item"),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                if (_items.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 32,
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.add_shopping_cart,
                                          size: 48,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "No items added yet",
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ..._items.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final item = entry.value;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: ListTile(
                                        title: FutureBuilder<Product?>(
                                          future: widget.productRepo.getProduct(
                                            item.productId,
                                          ),
                                          builder: (context, snapshot) {
                                            return Text(
                                              snapshot.data?.name ??
                                                  "Loading Product...",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            );
                                          },
                                        ),
                                        subtitle: Text(
                                          "Qty: ${item.qty} | Buy: ${item.purchasePrice} | Sell: ${item.sellPrice} | Total: ${item.qty * item.purchasePrice}",
                                          style: TextStyle(
                                            color: Colors.indigo.shade700,
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors.blue,
                                              ),
                                              onPressed: () => _editItem(idx),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              onPressed: () => _removeItem(idx),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- SUMMARY & SAVE ---
                        Card(
                          elevation: 5,
                          color: Colors.indigo.shade900,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                _SummaryRow(
                                  label: "Grand Total",
                                  value: _total.toStringAsFixed(2),
                                  isHeader: true,
                                ),
                                const Divider(color: Colors.white24),
                                _SummaryRow(
                                  label: "Paid Amount",
                                  value: (double.tryParse(_paidCtrl.text) ?? 0)
                                      .toStringAsFixed(2),
                                ),
                                _SummaryRow(
                                  label: "Ending Balance",
                                  value:
                                      (_total -
                                              (double.tryParse(
                                                    _paidCtrl.text,
                                                  ) ??
                                                  0))
                                          .toStringAsFixed(2),
                                  isImportant: true,
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isSaving ? null : _save,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.indigo.shade900,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.indigo,
                                            ),
                                          )
                                        : const Text(
                                            "CONFIRM & SAVE PURCHASE",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHeader;
  final bool isImportant;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isHeader = false,
    this.isImportant = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isHeader ? Colors.white : Colors.white70,
              fontSize: isHeader ? 16 : 14,
              fontWeight: isHeader || isImportant
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isImportant ? Colors.orangeAccent : Colors.white,
              fontSize: isHeader ? 20 : 16,
              fontWeight: isHeader || isImportant
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseItemDialog extends StatefulWidget {
  final PurchaseRepository repo;
  final ProductRepository productRepo;
  final SupplierRepository supplierRepo;
  final String supplierId; // ✅ add this
  final String? initialProductId; // ✅ added for prefilling
  final PurchaseItem? existingItem; // 👈 Added for editing
  final ProductBatch? existingBatch; // 👈 Added for editing

  const _PurchaseItemDialog({
    required this.repo,
    required this.productRepo,
    required this.supplierRepo,
    required this.supplierId, // ✅ required param
    this.initialProductId,
    this.existingItem,
    this.existingBatch,
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
  int _soldQty = 0; // ✅ track how much was already sold from this batch
  static const int _maxQty = 1000000; // Sanity check for typos

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.initialProductId;
    if (widget.existingItem != null) {
      _qtyCtrl.text = widget.existingItem!.qty.toString();
      _purchasePriceCtrl.text = widget.existingItem!.purchasePrice.toString();
      _sellPriceCtrl.text = widget.existingItem!.sellPrice.toString();
      _batchNoCtrl.text = widget.existingItem!.batchNo ?? "";
      _expiryCtrl.text = widget.existingItem!.expiryDate ?? "";

      // ✅ Fetch sold qty for validation if we have an existing batch ID
      if (widget.existingBatch != null) {
        widget.repo.getSoldQtyForBatch(widget.existingBatch!.id).then((val) {
          if (mounted) setState(() => _soldQty = val);
        });
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    final purchasePrice = double.tryParse(_purchasePriceCtrl.text) ?? 0.0;
    final sellPrice = double.tryParse(_sellPriceCtrl.text) ?? 0.0;

    final item =
        (widget.existingItem ??
                PurchaseItem(
                  id: const Uuid().v4(),
                  purchaseId: "",
                  productId: _selectedProductId!,
                  qty: qty,
                  purchasePrice: purchasePrice,
                  sellPrice: sellPrice,
                  batchNo: _batchNoCtrl.text,
                  expiryDate: _expiryCtrl.text.isEmpty
                      ? null
                      : _expiryCtrl.text,
                ))
            .copyWith(
              id: widget
                  .existingItem
                  ?.id, // ✅ Force preservation of existing ID
              qty: qty,
              purchasePrice: purchasePrice,
              sellPrice: sellPrice,
              batchNo: _batchNoCtrl.text,
              expiryDate: _expiryCtrl.text.isEmpty ? null : _expiryCtrl.text,
            );

    final batch =
        (widget.existingBatch ??
                ProductBatch(
                  id: const Uuid().v4(),
                  productId: _selectedProductId!,
                  batchNo: _batchNoCtrl.text,
                  supplierId: widget.supplierId,
                  expiryDate: _expiryCtrl.text.isEmpty
                      ? null
                      : _expiryCtrl.text,
                  qty: qty,
                  purchasePrice: purchasePrice,
                  sellPrice: sellPrice,
                  purchaseId: "",
                  createdAt: DateTime.now().toIso8601String(),
                  updatedAt: DateTime.now().toIso8601String(),
                ))
            .copyWith(
              id: widget
                  .existingBatch
                  ?.id, // ✅ Force preservation of existing ID
              qty: qty,
              purchasePrice: purchasePrice,
              sellPrice: sellPrice,
              batchNo: _batchNoCtrl.text,
              expiryDate: _expiryCtrl.text.isEmpty ? null : _expiryCtrl.text,
            );

    Navigator.pop(context, {"item": item, "batch": batch});
  }

  Future<void> _handleAddNewProduct(List<Product> products) async {
    final newProduct = await showDialog<Product>(
      context: context,
      builder: (_) => ProductDialog(
        productRepo: widget.productRepo,
        supplierRepo: widget.supplierRepo,
      ),
    );

    if (newProduct != null && mounted) {
      setState(() {
        products.add(newProduct);
        _selectedProductId = newProduct.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade800, Colors.indigo.shade500],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.add_shopping_cart, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              widget.existingItem != null ? "Edit Item" : "Add Item",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
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
                  Row(
                    children: [
                      Expanded(
                        child: DropdownSearch<String>(
                          items: (items, props) {
                            final pIds = products.map((p) => p.id).toList();
                            return [
                              "__new__",
                              ...pIds,
                            ]; // 🔥 "__new__" is now FIRST
                          },
                          selectedItem: _selectedProductId,
                          itemAsString: (id) {
                            if (id == "__new__") return "+ Add New Product";
                            final product = products.firstWhere(
                              (p) => p.id == id,
                            );
                            return "${product.name} (${product.sku})";
                          },
                          popupProps: const PopupProps.modalBottomSheet(
                            showSearchBox: true,
                            constraints: BoxConstraints(maxHeight: 500),
                            searchFieldProps: TextFieldProps(
                              decoration: InputDecoration(
                                labelText: "Search Product",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                          ),
                          decoratorProps: DropDownDecoratorProps(
                            decoration: InputDecoration(
                              labelText: "Select Product",
                              border: const OutlineInputBorder(),
                              helperText: widget.existingItem != null
                                  ? "Product cannot be changed once added. Delete and re-add if needed."
                                  : null,
                              enabled: widget.existingItem == null,
                            ),
                          ),
                          onChanged: widget.existingItem != null
                              ? null
                              : (val) async {
                                  if (val == "__new__") {
                                    _handleAddNewProduct(products);
                                    return;
                                  }
                                  setState(() => _selectedProductId = val);
                                },
                          validator: (v) => v == null ? "Required" : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: "Quick Add New Product",
                        child: InkWell(
                          onTap: () => _handleAddNewProduct(products),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.indigo.shade200),
                            ),
                            child: const Icon(
                              Icons.add_business,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _qtyCtrl,
                    decoration: const InputDecoration(labelText: "Quantity"),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Required";
                      final val = int.tryParse(v);
                      if (val == null) return "Invalid number";
                      if (val <= 0) return "Must be > 0";

                      // ✅ Check against sold qty
                      if (val < _soldQty) {
                        return "Min $_soldQty units (already sold)";
                      }

                      // ✅ QA Guard: Sanity check for infinite quantities (typos)
                      if (val > _maxQty) {
                        return "Qty too large (max $_maxQty)";
                      }
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
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(widget.existingItem != null ? "Update" : "Add Item"),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick-Add Supplier Dialog (inline, returns a Supplier on save)
// ─────────────────────────────────────────────────────────────────────────────
class _QuickAddSupplierDialog extends StatefulWidget {
  const _QuickAddSupplierDialog();

  @override
  State<_QuickAddSupplierDialog> createState() =>
      _QuickAddSupplierDialogState();
}

class _QuickAddSupplierDialogState extends State<_QuickAddSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(BuildContext ctx) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final now = DateTime.now().toIso8601String();
      final supplier = Supplier(
        id: const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        contactPerson: _contactCtrl.text.trim().isEmpty
            ? null
            : _contactCtrl.text.trim(),
        companyId: null,
        pendingAmount: 0.0,
        creditLimit: 0.0,
        createdAt: now,
        updatedAt: now,
        deleted: 0,
      );

      // We need a SupplierRepository — get it from the nearest PurchaseForm ancestor
      // by navigating to it via context. Instead, we pop with the supplier object
      // and let the parent handle the insert.
      if (ctx.mounted) Navigator.pop(ctx, supplier);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade800, Colors.indigo.shade500],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: const Row(
          children: [
            Icon(Icons.person_add, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Quick Add Supplier',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Contact Person',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.contact_page),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : () => _save(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Add Supplier'),
        ),
      ],
    );
  }
}

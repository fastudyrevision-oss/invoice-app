import 'package:flutter/material.dart';
import '../repositories/purchase_repo.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../models/product_batch.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../services/thermal_printer/index.dart';
import 'purchase_pdf_export_helper.dart';
import '../../utils/date_helper.dart';
import '../db/database_helper.dart';
import '../core/services/audit_logger.dart';
import '../services/auth_service.dart';

class PurchaseDetailFrame extends StatefulWidget {
  final PurchaseRepository repo;
  final Purchase purchase;

  const PurchaseDetailFrame({
    super.key,
    required this.repo,
    required this.purchase,
  });

  @override
  State<PurchaseDetailFrame> createState() => _PurchaseDetailFrameState();
}

class _PurchaseDetailFrameState extends State<PurchaseDetailFrame> {
  late Future<List<PurchaseItem>> _itemsFuture;
  late Purchase _purchase;
  Supplier? _supplier;

  @override
  void initState() {
    super.initState();
    _purchase = widget.purchase;
    _itemsFuture = widget.repo.getItemsByPurchaseId(widget.purchase.id);
    _loadSupplier();
  }

  void _loadSupplier() async {
    final s = await widget.repo.getSupplierById(_purchase.supplierId);
    setState(() => _supplier = s);
  }

  Future<void> _addPayment() async {
    // Enhanced dialog with amount and payment method
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PaymentInputDialog(maxAmount: _purchase.pending),
    );

    if (result != null) {
      final amount = result['amount'] as double;
      final method = result['method'] as String;
      final reference = result['reference'] as String?;
      final note = result['note'] as String?;

      try {
        // Update purchase
        final newPaid = _purchase.paid + amount;
        final newPending = _purchase.total - newPaid;

        final updated = _purchase.copyWith(
          paid: newPaid,
          pending: newPending,
          updatedAt: DateTime.now().toIso8601String(),
        );

        await widget.repo.updatePurchase(updated);

        // Update supplier balance
        if (_supplier != null) {
          final updatedSupplier = _supplier!.copyWith(
            pendingAmount: _supplier!.pendingAmount - amount,
          );
          await widget.repo.updateSupplier(updatedSupplier);
          _supplier = updatedSupplier;
        }

        // ✅ Create payment record in supplier_payments table
        final db = await DatabaseHelper.instance.db;
        final paymentId = DateTime.now().millisecondsSinceEpoch.toString();
        final paymentData = {
          'id': paymentId,
          'supplier_id': _purchase.supplierId,
          'purchase_id': _purchase.id,
          'amount': amount,
          'method': method,
          'transaction_ref': reference,
          'note': note ?? 'Payment for Purchase #${_purchase.invoiceNo}',
          'date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'deleted': 0,
          'is_synced': 0,
        };

        await db.insert('supplier_payments', paymentData);

        // ✅ Add audit log for payment creation
        await AuditLogger.log(
          'CREATE',
          'supplier_payments',
          recordId: paymentId,
          userId: AuthService.instance.currentUser?.id ?? 'system',
          newData: paymentData,
          txn: db,
        );

        setState(() => _purchase = updated);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment of Rs ${amount.toStringAsFixed(0)} added successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add payment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPending = _purchase.pending > 0;
    final isPaid = _purchase.pending <= 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Text("Invoice #${_purchase.invoiceNo}"),
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isPaid
                      ? [Colors.green.shade700, Colors.green.shade500]
                      : [Colors.orange.shade700, Colors.orange.shade500],
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPaid ? Icons.check_circle : Icons.pending,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPaid ? "Paid" : "Pending",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: FutureBuilder<List<PurchaseItem>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No items recorded for this purchase",
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return FutureBuilder<Product?>(
                    future: widget.repo.getProductById(item.productId),
                    builder: (context, productSnap) {
                      final product = productSnap.data;

                      return FutureBuilder<List<ProductBatch>>(
                        future: widget.repo.getBatchesByProduct(item.productId),
                        builder: (context, batchSnapshot) {
                          final batches = batchSnapshot.data ?? [];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  Colors.blue.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade600,
                                        Colors.blue.shade400,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  product?.name ?? "Product: ${item.productId}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      _buildItemChip(
                                        "Qty: ${item.qty}",
                                        Colors.purple,
                                        Icons.inventory,
                                      ),
                                      _buildItemChip(
                                        "Rs ${item.purchasePrice}",
                                        Colors.green,
                                        Icons.attach_money,
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.indigo.shade600,
                                        Colors.indigo.shade400,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Rs ${(item.qty * item.purchasePrice).toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                children: [
                                  if (batches.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "No batches recorded",
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    ...batches.map(
                                      (b) => Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.teal.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.qr_code_2,
                                                color: Colors.teal.shade700,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "Batch: ${b.batchNo}",
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "Expiry: ${b.expiryDate != null ? DateHelper.formatIso(b.expiryDate!) : 'N/A'} | Qty: ${b.qty}",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                "Rs ${b.sellPrice}",
                                                style: TextStyle(
                                                  color: Colors.green.shade900,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.grey.shade50],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Supplier Info
                if (_supplier != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.business, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          _supplier!.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Metrics Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBottomMetric(
                      "Total",
                      "Rs ${_purchase.total.toStringAsFixed(0)}",
                      Colors.blue,
                      Icons.receipt,
                    ),
                    _buildBottomMetric(
                      "Paid",
                      "Rs ${_purchase.paid.toStringAsFixed(0)}",
                      Colors.green,
                      Icons.check_circle,
                    ),
                    _buildBottomMetric(
                      "Pending",
                      "Rs ${_purchase.pending.toStringAsFixed(0)}",
                      hasPending ? Colors.red : Colors.green,
                      Icons.pending_actions,
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                // Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Date: ${DateHelper.formatIso(_purchase.date)}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Add Payment Button
                if (hasPending)
                  ElevatedButton.icon(
                    onPressed: _addPayment,
                    icon: const Icon(Icons.payment),
                    label: const Text("Add Payment"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade600, Colors.green.shade400],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "Fully Paid",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Thermal Print & Export Options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        // Convert purchase items to receipt items
                        final receiptItems = _buildReceiptItems();

                        // Use new ESC/POS thermal printing service
                        await thermalPrinting.printPurchase(
                          _purchase,
                          items: receiptItems,
                          supplierName: _supplier?.name,
                          context: context,
                        );
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text("Thermal Receipt"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _handleUsbPrint,
                      icon: const Icon(Icons.usb),
                      label: const Text("USB Print"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Print feature available'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.print),
                      label: const Text("Print"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleUsbPrint() async {
    // 1. Show loading
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Preparing print data...')));

    try {
      // 2. Fetch items
      final items = await widget.repo.getItemsByPurchaseId(_purchase.id);

      // 3. Map to print format (requires fetching product names)
      final List<Map<String, dynamic>> printItems = [];
      for (var item in items) {
        final product = await widget.repo.getProductById(item.productId);
        printItems.add({
          'product_name': product?.name ?? 'Item ${item.productId}',
          'qty': item.qty,
          'price': item.purchasePrice,
        });
      }

      // 4. Generate PDF bytes/file for thermal layout
      final pdfFile = await generateThermalReceipt(
        _purchase,
        items: printItems,
        supplierName: _supplier?.name,
      );

      // 5. Trigger System Print Dialog (USB/Default Printer)
      if (pdfFile != null) {
        await printPdfFile(pdfFile);
      }
    } catch (e) {
      debugPrint("Print Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Print failed: $e')));
      }
    }
  }

  /// Helper method to convert purchase items to receipt items
  List<ReceiptItem> _buildReceiptItems() {
    final items = <ReceiptItem>[];
    // In a real app, you would fetch PurchaseItems from database
    // For now, returning empty list (pass it from parent or fetch dynamically)
    return items;
  }

  Widget _buildItemChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomMetric(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
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
}

/// Payment Input Dialog with amount, method, and reference
class _PaymentInputDialog extends StatefulWidget {
  final double maxAmount;

  const _PaymentInputDialog({required this.maxAmount});

  @override
  State<_PaymentInputDialog> createState() => _PaymentInputDialogState();
}

class _PaymentInputDialogState extends State<_PaymentInputDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();
  String _paymentMethod = 'cash';

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      Navigator.pop(context, {
        'amount': amount,
        'method': _paymentMethod,
        'reference': _referenceController.text.trim().isNotEmpty
            ? _referenceController.text.trim()
            : null,
        'note': _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Payment'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'Rs ',
                  helperText: 'Max: Rs ${widget.maxAmount.toStringAsFixed(0)}',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  if (amount > widget.maxAmount) {
                    return 'Amount exceeds pending (${widget.maxAmount.toStringAsFixed(0)})';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _paymentMethod = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Reference / Cheque No (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  hintText: 'Add a note for this payment...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Add Payment')),
      ],
    );
  }
}

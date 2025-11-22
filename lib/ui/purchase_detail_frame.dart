import 'package:flutter/material.dart';
import '../repositories/purchase_repo.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../models/product_batch.dart';
import '../models/product.dart';
import '../models/supplier.dart';

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
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Payment"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Amount"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, double.tryParse(controller.text) ?? 0.0);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );

    if (amount != null && amount > 0) {
      final newPaid = _purchase.paid + amount;
      final newPending = _purchase.total - newPaid;

      final updated = _purchase.copyWith(
        paid: newPaid,
        pending: newPending,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await widget.repo.updatePurchase(updated);

      if (_supplier != null) {
        final updatedSupplier = _supplier!.copyWith(
          pendingAmount: _supplier!.pendingAmount - amount,
        );
        await widget.repo.updateSupplier(updatedSupplier);
        _supplier = updatedSupplier;
      }

      setState(() => _purchase = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Invoice #${_purchase.invoiceNo}")),
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
            return const Center(
              child: Text("No items recorded for this purchase"),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(),
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

                      return ExpansionTile(
                        leading: const Icon(Icons.shopping_bag),
                        title: Text(
                          product?.name ?? "Product: ${item.productId}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          "Qty: ${item.qty} | Unit Price: ${item.purchasePrice} | Subtotal: ${(item.qty * item.purchasePrice).toStringAsFixed(2)}",
                        ),
                        children: [
                          if (batches.isEmpty)
                            const ListTile(title: Text("No batches recorded"))
                          else
                            ...batches.map(
                              (b) => ListTile(
                                leading: const Icon(Icons.qr_code_2),
                                title: Text("Batch: ${b.batchNo}"),
                                subtitle: Text(
                                  "Expiry: ${b.expiryDate ?? 'N/A'} | Qty: ${b.qty} | Sell Price: ${b.sellPrice}",
                                ),
                              ),
                            ),
                        ],
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
        color: Colors.grey.shade100,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Total: ${_purchase.total.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text("Paid: ${_purchase.paid.toStringAsFixed(2)}"),
            Text(
              "Pending: ${_purchase.pending.toStringAsFixed(2)}",
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 4),
            Text(
              "Date: ${_purchase.date.split('T').first}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _addPayment,
              icon: const Icon(Icons.payment),
              label: const Text("Add Payment"),
            ),
          ],
        ),
      ),
    );
  }
}

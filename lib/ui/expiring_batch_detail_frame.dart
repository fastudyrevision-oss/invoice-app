import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expiring_batch_detail.dart';
import '../repositories/purchase_repo.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/purchase.dart';
import 'package:sqflite/sqflite.dart';

class BatchDetailFrame extends StatefulWidget {
  final ExpiringBatchDetail batch;
  final Database db;

  const BatchDetailFrame({super.key, required this.batch, required this.db});

  @override
  State<BatchDetailFrame> createState() => _BatchDetailFrameState();
}

class _BatchDetailFrameState extends State<BatchDetailFrame> {
  late final PurchaseRepository _repo;

  Product? _product;
  Supplier? _supplier;
  Purchase? _purchase;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = PurchaseRepository(widget.db); // initialize with db
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final product = await _repo.getProductById(widget.batch.productId);

    Supplier? supplier;
    if (product?.supplierId != null) {
      supplier = await _repo.getSupplierById(product!.supplierId!);
    }

    // ✅ fallback: if repo fetch fails but batch has supplierName
    if (supplier == null && widget.batch.supplierName != null) {
      supplier = Supplier(
        id: widget
            .batch
            .purchaseId, // placeholder id (better if you add supplier_id in ExpiringBatchDetail)
        name: widget.batch.supplierName!,
        phone: null,
        address: null,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(), // required
      );
    }

    final purchase = await _repo.getPurchaseById(widget.batch.purchaseId);

    if (!mounted) return;
    setState(() {
      _product = product;
      _supplier = supplier;
      _purchase = purchase;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd');
    final expiryDate = widget.batch.expiryDate;

    return Scaffold(
      appBar: AppBar(title: const Text("Batch Details")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  // Product info
                  Text(
                    _product?.name ?? widget.batch.productName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),

                  // Batch info
                  Text("Batch No: ${widget.batch.batchNo}"),
                  Text("Quantity: ${widget.batch.qty}"),
                  Text("Expiry: ${formatter.format(expiryDate)}"),
                  const Divider(),

                  // Supplier info
                  if (_supplier != null) ...[
                    Text(
                      "Supplier: ${_supplier!.name}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_supplier!.phone != null)
                      Text("Phone: ${_supplier!.phone}"),
                    if (_supplier!.address != null)
                      Text("Address: ${_supplier!.address}"),
                    const Divider(),
                  ],

                  // Purchase info
                  if (_purchase != null) ...[
                    Text(
                      "Purchase Ref: ${_purchase!.id}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text("Date: ${_purchase!.date}"),
                    Text("Invoice No: ${_purchase!.invoiceNo ?? 'N/A'}"),
                  ],

                  if (_purchase == null)
                    const Text(
                      "Purchase details not available.",
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

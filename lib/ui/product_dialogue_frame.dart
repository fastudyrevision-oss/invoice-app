import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_repo.dart';

class ProductDialog extends StatefulWidget {
  final ProductRepository productRepo;
  final SupplierRepository supplierRepo;
  final Product? product; // for edit, null = add

  const ProductDialog({
    super.key,
    required this.productRepo,
    required this.supplierRepo,
    this.product,
  });

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameCtrl;
  late TextEditingController skuCtrl;
  late TextEditingController unitCtrl;
  late TextEditingController descCtrl;

  bool trackExpiry = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    nameCtrl = TextEditingController(text: p?.name ?? "");
    skuCtrl = TextEditingController(text: p?.sku ?? "");
    unitCtrl = TextEditingController(text: p?.defaultUnit ?? "");
    descCtrl = TextEditingController(text: p?.description ?? "");
    trackExpiry = p?.trackExpiry ?? false;
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final newProduct = Product(
      id: widget.product?.id ?? const Uuid().v4(),
      name: nameCtrl.text,
      description: descCtrl.text,
      sku: skuCtrl.text,
      defaultUnit: unitCtrl.text,
      costPrice: widget.product?.costPrice ?? 0.0, // default
      sellPrice: widget.product?.sellPrice ?? 0.0, // default
      quantity: widget.product?.quantity ?? 0, // default
      minStock: widget.product?.minStock ?? 0, // default
      trackExpiry: trackExpiry,
      supplierId: widget.product?.supplierId, // untouched
      createdAt: widget.product?.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    if (widget.product == null) {
      await widget.productRepo.addProduct(newProduct);
    } else {
      await widget.productRepo.updateProduct(newProduct);
    }

    Navigator.pop(context, newProduct); // return product
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? "Add Product" : "Edit Product"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: skuCtrl,
                decoration: const InputDecoration(labelText: "SKU"),
              ),
              TextFormField(
                controller: unitCtrl,
                decoration: const InputDecoration(labelText: "Default Unit"),
              ),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              Row(
                children: [
                  Checkbox(
                    value: trackExpiry,
                    onChanged: (v) => setState(() => trackExpiry = v ?? false),
                  ),
                  const Text("Track Expiry"),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text("Save"),
        ),
      ],
    );
  }
}

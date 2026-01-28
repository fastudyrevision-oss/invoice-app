import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_repo.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';

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
  Category? selectedCategory;
  List<Category> categories = [];
  late CategoryRepository categoryRepo;

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
    // Initialize Category repository and fetch categories
    // Async init safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initCategories(p?.categoryId);
    });
  }

  void initCategories(String? currentCategoryId) async {
    categoryRepo = await CategoryRepository.create();
    final allCategories = await categoryRepo.getAllCategories();
    setState(() {
      categories = allCategories;
      selectedCategory = categories.firstWhere(
        (c) => c.id == (currentCategoryId ?? 'cat-001'),
        orElse: () => categories.firstWhere((c) => c.id == 'cat-001'),
      );
    });
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
      categoryId: selectedCategory?.id ?? 'cat-001', // ✅ set category
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
    // 🔥 1. FIRST handle loading state BEFORE returning the dialog
    if (categories.isEmpty) {
      return AlertDialog(
        title: Text(widget.product == null ? "Add Product" : "Edit Product"),
        content: const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    // 🔥 2. Categories loaded → show normal dialog

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
                  const SizedBox(width: 8),
                  const Text("Track Expiry"),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownSearch<Category>(
                  items: (filter, props) => categories,
                  selectedItem:
                      selectedCategory ??
                      categories.firstWhere((c) => c.id == 'cat-001'),
                  itemAsString: (c) => c.name,
                  compareFn: (a, b) => a.id == b.id,
                  popupProps: const PopupProps.modalBottomSheet(
                    showSearchBox: true,
                    constraints: BoxConstraints(maxHeight: 500),
                  ),
                  decoratorProps: const DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: "Category",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  onChanged: (c) {
                    setState(() {
                      if (c != null) {
                        selectedCategory = c;
                      } else {
                        // Default to 'Uncategorized' if somehow null
                        selectedCategory = categories.firstWhere(
                          (c) => c.id == 'cat-001',
                        );
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
          },
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            _save();
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}

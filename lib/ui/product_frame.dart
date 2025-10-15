import 'package:flutter/material.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_repo.dart'; // ✅ repo for suppliers
import '../models/supplier.dart';
import '../dao/supplier_dao.dart';
import '../dao/supplier_report_dao.dart';
import '../dao/supplier_payment_dao.dart';
import '../dao/supplier_company_dao.dart';
class ProductFrame extends StatefulWidget {
  const ProductFrame({super.key});

  @override
  _ProductFrameState createState() => _ProductFrameState();
}

class _ProductFrameState extends State<ProductFrame> {
  final ProductRepository _repo = ProductRepository();
  final SupplierRepository _supplierRepo = SupplierRepository(SupplierDao(),
        SupplierPaymentDao(),
        SupplierReportDao(),
        SupplierCompanyDao(),);

  List<Product> _products = [];
  List<Supplier> _suppliers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadSuppliers();
  }

  Future<void> _loadProducts() async {
    final data = await _repo.getAllProducts();
    setState(() {
      _products = data;
      _isLoading = false;
    });
  }

  Future<void> _loadSuppliers() async {
    final data = await _supplierRepo.getAllSuppliers();
    setState(() {
      _suppliers = data;
    });
  }

  void _showAddEditProductDialog([Product? product]) {
    final nameController = TextEditingController(text: product?.name ?? "");
    final skuController = TextEditingController(text: product?.sku ?? "");
    final unitController = TextEditingController(text: product?.defaultUnit ?? "");
    final costController = TextEditingController(text: product?.costPrice.toString() ?? "");
    final sellController = TextEditingController(text: product?.sellPrice.toString() ?? "");
    final quantityController = TextEditingController(text: product?.quantity.toString() ?? "");
    final minStockController = TextEditingController(text: product?.minStock.toString() ?? "");
    final descController = TextEditingController(text: product?.description ?? "");
    bool trackExpiry = product?.trackExpiry ?? false;

    String? selectedSupplierId = product?.supplierId; // ✅ keep existing supplier

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(product == null ? "Add Product" : "Edit Product"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: InputDecoration(labelText: "Name")),
                TextField(controller: skuController, decoration: InputDecoration(labelText: "SKU")),
                TextField(controller: unitController, decoration: InputDecoration(labelText: "Default Unit")),
                TextField(controller: costController, decoration: InputDecoration(labelText: "Cost Price"), keyboardType: TextInputType.number),
                TextField(controller: sellController, decoration: InputDecoration(labelText: "Sell Price"), keyboardType: TextInputType.number),
                TextField(controller: quantityController, decoration: InputDecoration(labelText: "Quantity"), keyboardType: TextInputType.number),
                TextField(controller: minStockController, decoration: InputDecoration(labelText: "Min Stock"), keyboardType: TextInputType.number),
                TextField(controller: descController, decoration: InputDecoration(labelText: "Description")),

                // ✅ Supplier Dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedSupplierId,
                  decoration: const InputDecoration(labelText: "Supplier"),
                  items: _suppliers.map((s) {
                    return DropdownMenuItem(
                      value: s.id,
                      child: Text(s.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setStateDialog(() {
                      selectedSupplierId = val;
                    });
                  },
                ),

                Row(
                  children: [
                    Checkbox(
                      value: trackExpiry,
                      onChanged: (val) {
                        setStateDialog(() {
                          trackExpiry = val ?? false;
                        });
                      },
                    ),
                    const Text("Track Expiry"),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final newProduct = Product(
                  id: product?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  description: descController.text,
                  sku: skuController.text,
                  defaultUnit: unitController.text,
                  costPrice: double.tryParse(costController.text) ?? 0.0,
                  sellPrice: double.tryParse(sellController.text) ?? 0.0,
                  quantity: int.tryParse(quantityController.text) ?? 0,
                  minStock: int.tryParse(minStockController.text) ?? 0,
                  trackExpiry: trackExpiry,
                  supplierId: selectedSupplierId, // ✅ now linked
                  createdAt: product?.createdAt ?? DateTime.now().toIso8601String(),
                  updatedAt: DateTime.now().toIso8601String(),
                );

                if (product == null) {
                  await _repo.addProduct(newProduct);
                } else {
                  await _repo.updateProduct(newProduct);
                }

                Navigator.pop(context);
                _loadProducts();
              },
              child: Text(product == null ? "Add" : "Update"),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Products"),
        actions: [
          IconButton(onPressed: () => _showAddEditProductDialog(), icon: const Icon(Icons.add)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text("Name")),
                  DataColumn(label: Text("SKU")),
                  DataColumn(label: Text("Unit")),
                  DataColumn(label: Text("Cost Price")),
                  DataColumn(label: Text("Sell Price")),
                  DataColumn(label: Text("Quantity")),
                  DataColumn(label: Text("Min Stock")),
                  DataColumn(label: Text("Supplier")), // ✅ new column
                  DataColumn(label: Text("Expiry Tracked")),
                  DataColumn(label: Text("Actions")),
                ],
                rows: _products
                    .map(
                      (p) => DataRow(cells: [
                        DataCell(Text(p.name)),
                        DataCell(Text(p.sku)),
                        DataCell(Text(p.defaultUnit)),
                        DataCell(Text("\$${p.costPrice.toStringAsFixed(2)}")),
                        DataCell(Text("\$${p.sellPrice.toStringAsFixed(2)}")),
                        DataCell(Text(p.quantity.toString())),
                        DataCell(Text(p.minStock.toString())),
                        DataCell(Text(_suppliers.firstWhere(
                          (s) => s.id == p.supplierId,
                          orElse: () => Supplier(id: "0", name: "Unlinked", phone: null, address: null, createdAt: "", updatedAt: ""),
                        ).name)),
                        DataCell(Icon(p.trackExpiry ? Icons.check : Icons.close, color: p.trackExpiry ? Colors.green : Colors.red)),
                        DataCell(Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: "Edit Product",
                              onPressed: () => _showAddEditProductDialog(p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: "Delete Product",
                              onPressed: () async {
                                await _repo.deleteProduct(p.id);
                                _loadProducts();
                              },
                            ),
                          ],
                        )),
                      ]),
                    )
                    .toList(),
              ),
            ),
    );
  }
}

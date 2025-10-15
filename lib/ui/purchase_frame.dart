import 'package:flutter/material.dart';
import '../repositories/purchase_repo.dart';

import '../repositories/product_repository.dart';
import '../repositories/supplier_repo.dart';

import '../models/purchase.dart';
import '../models/supplier.dart';
import 'purchase_detail_frame.dart';
import 'purchase_form.dart';

/// =====================
/// PURCHASE FRAME (List)
/// =====================
class PurchaseFrame extends StatefulWidget {
  final PurchaseRepository repo;
  final ProductRepository productRepo;
  final SupplierRepository supplierRepo;

  const PurchaseFrame({super.key, required this.repo,required this.productRepo,
    required this.supplierRepo,});

  @override
  State<PurchaseFrame> createState() => _PurchaseFrameState();
}

class _PurchaseFrameState extends State<PurchaseFrame> {
  late Future<List<Purchase>> _futurePurchases;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  void _loadPurchases() {
    setState(() {
      _futurePurchases = widget.repo.getAllPurchases();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Purchases")),
      body: FutureBuilder<List<Purchase>>(
        future: _futurePurchases,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final purchases = snapshot.data ?? [];
          if (purchases.isEmpty) {
            return const Center(child: Text("No purchases yet"));
          }

          return ListView.builder(
            itemCount: purchases.length,
            itemBuilder: (context, index) {
              final purchase = purchases[index];
              return FutureBuilder<Supplier?>(
                future: widget.repo.getSupplierById(purchase.supplierId),
                builder: (context, supSnap) {
                  if (!supSnap.hasData) {
                    return const SizedBox.shrink();
                  }
                  final supplier = supSnap.data!;
                  return ListTile(
                    title: Text("Invoice: ${purchase.invoiceNo}"),
                    subtitle: Text(
                      "Supplier: ${supplier.name}\n"
                      "Total: ${purchase.total} | "
                      "Paid: ${purchase.paid} | "
                      "Pending: ${purchase.pending}",
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PurchaseDetailFrame(
                            repo: widget.repo,
                            purchase: purchase,
                          ),
                        ),
                      );
                      _loadPurchases();
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PurchaseForm(repo: widget.repo, productRepo: widget.productRepo,
                                                                  supplierRepo: widget.supplierRepo,),
            ),
          );
          if (added == true) {
            _loadPurchases();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

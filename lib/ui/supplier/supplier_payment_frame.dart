import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../repositories/supplier_payment_repo.dart';
import '../../repositories/purchase_repo.dart'; // 👈 make sure you have this
import '../../models/supplier.dart';
import '../../models/supplier_payment.dart';
import '../../db/database_helper.dart';

class SupplierPaymentFrame extends StatefulWidget {
  final SupplierPaymentRepository repo;
  final Supplier supplier;

  const SupplierPaymentFrame({
    super.key,
    required this.repo,
    required this.supplier,
  });

  @override
  State<SupplierPaymentFrame> createState() => _SupplierPaymentFrameState();
}

class _SupplierPaymentFrameState extends State<SupplierPaymentFrame> {
  late Future<List<SupplierPayment>> _paymentsFuture;
  

  // inside your state
late PurchaseRepository purchaseRepo;

@override
void initState() {
  super.initState();
  _paymentsFuture = widget.repo.getPayments(widget.supplier.id); // ✅ initialize here
  DatabaseHelper.instance.db.then((db) {
    setState(() {
      purchaseRepo = PurchaseRepository(db);
       // ✅ fixed
    });
    _loadPayments();
  });
}


  void _loadPayments() {
    setState(() {
      _paymentsFuture = widget.repo.getPayments(widget.supplier.id);
    });
  }

  /// Add or edit a payment
  void _addOrEditPayment([SupplierPayment? payment]) async {
    final amountCtrl =
        TextEditingController(text: payment?.amount.toString() ?? "");
    final noteCtrl = TextEditingController(text: payment?.note ?? "");

    // ✅ Load purchases for this supplier
    final purchases =
        await purchaseRepo.getPurchasesForSupplier(widget.supplier.id);

    String? selectedPurchaseId = payment?.purchaseId;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(payment == null ? "Add Payment" : "Edit Payment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Amount"),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: "Note / Details"),
            ),
            const SizedBox(height: 10),
            DropdownSearch<String>(
              items:(items, props)=> purchases.map((p) => p.id).toList(),
  selectedItem: selectedPurchaseId,
  itemAsString: (id) {
    final p = purchases.firstWhere((p) => p.id == id);
    return "Invoice: ${p.invoiceNo} | ${p.id.substring(0, 6)} | Total: ${p.total} | Pending: ${p.pending}";
  },
  popupProps: PopupProps.menu(
    showSearchBox: true,
    
    searchFieldProps: TextFieldProps(
      decoration: const InputDecoration(
        labelText: "Search Purchase",
        border: OutlineInputBorder(),
      ),
    ),
  ),
  decoratorProps: const DropDownDecoratorProps(
    decoration: InputDecoration(
      labelText: "Select Purchase",
      border: OutlineInputBorder(),
    ),
  ),
  onChanged: (val) {
    selectedPurchaseId = val;
  },
  validator: (v) => v == null ? "Required" : null,
),

          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              final amt = double.tryParse(amountCtrl.text);
              if (amt != null && amt > 0 && selectedPurchaseId != null) {
                Navigator.pop(ctx, {
                  "amount": amt,
                  "note": noteCtrl.text,
                  "purchaseId": selectedPurchaseId,
                });
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (result != null) {
      if (payment == null) {
  final amount = result["amount"] as double;
  final purchaseId = result["purchaseId"] as String;

  // 1️⃣ Insert supplier payment record
  await widget.repo.addPayment(
    widget.supplier.id,
    amount,
    note: result["note"],
    purchaseId: purchaseId,
  );

  // -------------------------------------------------------------------
  // 2️⃣ Update Purchase (paid, pending)
 

  // -------------------------------------------------------------------
  // 3️⃣ Update Supplier pending amount
  // -------------------------------------------------------------------
  
}
else {
        final updated = payment.copyWith(
          amount: result["amount"],
          note: result["note"],
          purchaseId: result["purchaseId"],
        );
        await widget.repo.updatePayment(updated);
      }
      _loadPayments();
    }
  }

  void _deletePayment(SupplierPayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Payment"),
        content: const Text("Are you sure you want to delete this payment?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete")),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.repo.softDeletePayment(payment);
      _loadPayments();
    }
  }

  void _restorePayment(SupplierPayment payment) async {
    await widget.repo.restorePayment(payment);
    _loadPayments();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => _addOrEditPayment(),
          child: const Text("➕ Add Payment"),
        ),
        Expanded(
          child: FutureBuilder<List<SupplierPayment>>(
            future: _paymentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No payments found."));
              }

              final payments = snapshot.data!;
              return ListView.builder(
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final p = payments[index];
                  final isDeleted = p.deleted == 1;

                  return Card(
                    color: isDeleted ? Colors.grey[300] : null,
                    child: ListTile(
                      title: Text("Amount: ${p.amount.toStringAsFixed(2)}"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Date: ${p.date}"),
                          if ((p.note ?? "").isNotEmpty)
                            Text("Note: ${p.note}"),
                          if ((p.purchaseId ?? "").isNotEmpty)
                            Text("Purchase ID: ${p.purchaseId}"),
                          if (isDeleted)
                            const Text("Deleted",
                                style: TextStyle(color: Colors.red)),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _addOrEditPayment(p);
                          if (value == 'delete') _deletePayment(p);
                          if (value == 'restore') _restorePayment(p);
                        },
                        itemBuilder: (ctx) => [
                          if (!isDeleted)
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                          if (!isDeleted)
                            const PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          if (isDeleted)
                            const PopupMenuItem(
                                value: 'restore', child: Text('Restore')),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

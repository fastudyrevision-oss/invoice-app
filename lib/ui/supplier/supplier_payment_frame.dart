import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../repositories/supplier_payment_repo.dart';
import '../../repositories/purchase_repo.dart';
import '../../models/supplier.dart';
import '../../models/supplier_payment.dart';
import '../../db/database_helper.dart';
import '../../utils/responsive_utils.dart';

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
  PurchaseRepository? purchaseRepo;

  @override
  void initState() {
    super.initState();
    _paymentsFuture = widget.repo.getPayments(widget.supplier.id);
    DatabaseHelper.instance.db.then((db) {
      setState(() {
        purchaseRepo = PurchaseRepository(db);
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
    if (purchaseRepo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please wait, loading data...")),
      );
      return;
    }
    final amountCtrl = TextEditingController(
      text: payment?.amount.toString() ?? "",
    );
    final noteCtrl = TextEditingController(text: payment?.note ?? "");
    final transactionRefCtrl = TextEditingController(
      text: payment?.transactionRef ?? "",
    );

    // Payment methods
    const paymentMethods = ['cash', 'cheque', 'bank_transfer', 'upi', 'card'];
    String selectedMethod = payment?.method ?? 'cash';

    // Load purchases for this supplier
    final purchases = await purchaseRepo!.getPurchasesForSupplier(
      widget.supplier.id,
    );

    String? selectedPurchaseId = payment?.purchaseId;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(payment == null ? "Add Payment" : "Edit Payment"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Purchase selector
                DropdownSearch<String>(
                  items: (items, props) => purchases.map((p) => p.id).toList(),
                  selectedItem: selectedPurchaseId,
                  itemAsString: (id) {
                    final p = purchases.firstWhere((p) => p.id == id);
                    return "Invoice: ${p.invoiceNo} | Total: Rs ${p.total} | Pending: Rs ${p.pending}";
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
                      labelText: "Select Purchase *",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  onChanged: (val) {
                    setDialogState(() => selectedPurchaseId = val);
                  },
                ),
                const SizedBox(height: 16),

                // Amount
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Amount *",
                    border: OutlineInputBorder(),
                    prefixText: 'Rs ',
                  ),
                ),
                const SizedBox(height: 16),

                // Payment method dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedMethod,
                  decoration: const InputDecoration(
                    labelText: "Payment Method *",
                    border: OutlineInputBorder(),
                  ),
                  items: paymentMethods.map((method) {
                    return DropdownMenuItem(
                      value: method,
                      child: Text(method.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedMethod = value!);
                  },
                ),
                const SizedBox(height: 16),

                // Transaction reference (required for non-cash)
                if (selectedMethod != 'cash')
                  TextField(
                    controller: transactionRefCtrl,
                    decoration: InputDecoration(
                      labelText: selectedMethod == 'cheque'
                          ? 'Cheque Number *'
                          : 'Transaction Reference *',
                      border: const OutlineInputBorder(),
                      hintText: selectedMethod == 'cheque'
                          ? 'e.g., CHQ123456'
                          : 'e.g., TXN789012',
                    ),
                  ),
                if (selectedMethod != 'cash') const SizedBox(height: 16),

                // Note
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: "Note / Details",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text);

                // Validation
                if (amt == null || amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                    ),
                  );
                  return;
                }

                if (selectedPurchaseId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a purchase')),
                  );
                  return;
                }

                // Check for transaction ref on non-cash payments
                if (selectedMethod != 'cash' &&
                    transactionRefCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please enter ${selectedMethod == 'cheque' ? 'cheque number' : 'transaction reference'}',
                      ),
                    ),
                  );
                  return;
                }

                // Check for overpayment
                final selectedPurchase = purchases.firstWhere(
                  (p) => p.id == selectedPurchaseId,
                );

                // Calculate max allowed amount
                // If editing the same purchase, we can use the pending amount + the amount we already paid
                double maxAllowed = selectedPurchase.pending;
                if (payment != null &&
                    payment.purchaseId == selectedPurchaseId) {
                  maxAllowed += payment.amount;
                }

                if (amt > maxAllowed) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Overpayment Warning'),
                      content: Text(
                        'Payment amount (Rs ${amt.toStringAsFixed(2)}) exceeds pending balance.\n'
                        'Max allowed: Rs ${maxAllowed.toStringAsFixed(2)}\n\n'
                        'Only Rs ${selectedPurchase.pending.toStringAsFixed(2)} will be applied to this purchase. '
                        'The extra Rs ${(amt - selectedPurchase.pending).toStringAsFixed(2)} will be recorded but not applied.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // Close warning
                            Navigator.pop(ctx, {
                              "amount": amt,
                              "note": noteCtrl.text,
                              "purchaseId": selectedPurchaseId,
                              "method": selectedMethod,
                              "transactionRef":
                                  transactionRefCtrl.text.trim().isEmpty
                                  ? null
                                  : transactionRefCtrl.text.trim(),
                            });
                          },
                          child: const Text('Proceed Anyway'),
                        ),
                      ],
                    ),
                  );
                } else {
                  Navigator.pop(ctx, {
                    "amount": amt,
                    "note": noteCtrl.text,
                    "purchaseId": selectedPurchaseId,
                    "method": selectedMethod,
                    "transactionRef": transactionRefCtrl.text.trim().isEmpty
                        ? null
                        : transactionRefCtrl.text.trim(),
                  });
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      if (payment == null) {
        await widget.repo.addPayment(
          widget.supplier.id,
          result["amount"],
          note: result["note"],
          purchaseId: result["purchaseId"],
          method: result["method"],
          transactionRef: result["transactionRef"],
        );
      } else {
        final updated = payment.copyWith(
          amount: result["amount"],
          note: result["note"],
          purchaseId: result["purchaseId"],
          method: result["method"],
          transactionRef: result["transactionRef"],
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
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.repo.softDeletePayment(payment);
        _loadPayments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting payment: $e')));
        }
      }
    }
  }

  void _restorePayment(SupplierPayment payment) async {
    try {
      await widget.repo.restorePayment(payment);
      _loadPayments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error restoring payment: $e')));
      }
    }
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Payment Summary Cards
        FutureBuilder<List<SupplierPayment>>(
          future: _paymentsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            final payments = snapshot.data!;
            final activePayments = payments
                .where((p) => p.deleted == 0)
                .toList();
            final totalPaid = activePayments.fold<double>(
              0,
              (sum, p) => sum + p.amount,
            );
            final paymentCount = activePayments.length;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = ResponsiveUtils.isMobile(context);
                final summaryCards = [
                  _buildSummaryCard(
                    'Total Paid',
                    'Rs ${totalPaid.toStringAsFixed(2)}',
                    Icons.payment,
                    Colors.green.shade100,
                  ),
                  _buildSummaryCard(
                    'Pending Balance',
                    'Rs ${widget.supplier.pendingAmount.toStringAsFixed(2)}',
                    Icons.pending_actions,
                    Colors.orange.shade100,
                  ),
                  _buildSummaryCard(
                    'Payment Count',
                    paymentCount.toString(),
                    Icons.receipt_long,
                    Colors.blue.shade100,
                  ),
                ];

                return Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: isMobile
                        ? Column(
                            children: summaryCards
                                .map(
                                  (card) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: card,
                                    ),
                                  ),
                                )
                                .toList(),
                          )
                        : Row(
                            children: summaryCards
                                .map(
                                  (card) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: card,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                );
              },
            );
          },
        ),

        // Add Payment Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _addOrEditPayment(),
              icon: const Icon(Icons.add),
              label: const Text("Add Payment"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Payment List
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
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      title: Text("Rs ${p.amount.toStringAsFixed(2)}"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Date: ${p.date}"),
                          if (p.method != null)
                            Text("Method: ${p.method!.toUpperCase()}"),
                          if (p.transactionRef != null)
                            Text("Ref: ${p.transactionRef}"),
                          if ((p.note ?? "").isNotEmpty)
                            Text("Note: ${p.note}"),
                          if ((p.purchaseId ?? "").isNotEmpty)
                            Text("Purchase ID: ${p.purchaseId}"),
                          if (isDeleted)
                            const Text(
                              "Deleted",
                              style: TextStyle(color: Colors.red),
                            ),
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
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                          if (!isDeleted)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          if (isDeleted)
                            const PopupMenuItem(
                              value: 'restore',
                              child: Text('Restore'),
                            ),
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/supplier_payment_repo.dart';
import '../../repositories/supplier_repo.dart';
import '../../models/supplier.dart';
import '../../models/purchase.dart';
import '../../models/supplier_payment.dart';
import 'supplier_payment_frame.dart';
import '../../repositories/purchase_repo.dart';
import '../purchase_detail_frame.dart';

class SupplierDetailFrame extends StatefulWidget {
  final SupplierRepository repo;
  final SupplierPaymentRepository repo2;
  final PurchaseRepository purchaseRepo;
  final Supplier supplier;

  const SupplierDetailFrame({
    super.key,
    required this.repo,
    required this.repo2,
    required this.purchaseRepo,
    required this.supplier,
  });

  @override
  State<SupplierDetailFrame> createState() => _SupplierDetailFrameState();
}

class _SupplierDetailFrameState extends State<SupplierDetailFrame>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  List<Purchase> _purchases = [];
  List<SupplierPayment> _payments = [];

  double _totalPurchased = 0;
  double _totalPaid = 0;
  double _pendingAmount = 0;
  DateTime? _lastPurchaseDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load purchases
      _purchases = await widget.repo.getPurchases(widget.supplier.id);

      // Load payments
      _payments = await widget.repo.getPayments(widget.supplier.id);

      // Calculate metrics
      _totalPurchased = _purchases.fold(0.0, (sum, p) => sum + p.total);
      _totalPaid = _payments.fold(0.0, (sum, p) => sum + p.amount);
      _pendingAmount = widget.supplier.pendingAmount;

      if (_purchases.isNotEmpty) {
        _lastPurchaseDate = DateTime.tryParse(_purchases.first.date);
      }
    } catch (e) {
      debugPrint("Error loading supplier details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplier.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_bag), text: "History"),
            Tab(icon: Icon(Icons.payment), text: "Payments"),
            Tab(icon: Icon(Icons.account_balance), text: "Ledger"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSupplierHeader(),
                _buildSummaryCards(),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildHistoryTab(),
                      _buildPaymentsTab(),
                      _buildLedgerTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSupplierHeader() {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.shade50,
              child: const Icon(Icons.business, color: Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.supplier.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.supplier.phone != null)
                    Text(
                      "📞 ${widget.supplier.phone}",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  if (widget.supplier.address != null)
                    Text(
                      "📍 ${widget.supplier.address}",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  if (_lastPurchaseDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Last Purchase: ${DateFormat('dd MMM yyyy').format(_lastPurchaseDate!)}",
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _buildMetricItem("Purchases", _totalPurchased, Colors.blue),
          _buildMetricItem("Paid", _totalPaid, Colors.green),
          _buildMetricItem("Pending", _pendingAmount, Colors.red),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, double value, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                "Rs ${value.toStringAsFixed(0)}",
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_purchases.isEmpty) {
      return const Center(child: Text("No purchase history found."));
    }
    return ListView.builder(
      itemCount: _purchases.length,
      itemBuilder: (context, index) {
        final purchase = _purchases[index];
        final isPaid = purchase.pending <= 0;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPaid
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              child: Icon(
                Icons.receipt,
                color: isPaid ? Colors.green : Colors.red,
              ),
            ),
            title: Text("Invoice: ${purchase.invoiceNo}"),
            subtitle: Text(
              DateFormat('dd MMM yyyy').format(DateTime.parse(purchase.date)),
            ),
            trailing: Text(
              "Rs ${purchase.total.toStringAsFixed(2)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PurchaseDetailFrame(
                    repo: widget.purchaseRepo,
                    purchase: purchase,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab() {
    // Current SupplierPaymentFrame is integrated in the TabBarView
    return SupplierPaymentFrame(repo: widget.repo2, supplier: widget.supplier);
  }

  Widget _buildLedgerTab() {
    final List<Map<String, dynamic>> ledger = [];

    for (var p in _purchases) {
      ledger.add({
        'date': p.date,
        'desc': "Purchase Invoice #${p.invoiceNo}",
        'debit': p.total,
        'credit': 0.0,
      });
    }

    for (var pay in _payments) {
      ledger.add({
        'date': pay.date,
        'desc':
            "Payment${pay.note != null && pay.note!.isNotEmpty ? " (${pay.note})" : ""}",
        'debit': 0.0,
        'credit': pay.amount,
      });
    }

    ledger.sort((a, b) => b['date'].compareTo(a['date']));

    if (ledger.isEmpty) {
      return const Center(child: Text("No transactions recorded."));
    }

    return ListView.builder(
      itemCount: ledger.length,
      itemBuilder: (context, index) {
        final item = ledger[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: InkWell(
            onTap: () async {
              if (item['desc'].toString().contains("Purchase Invoice")) {
                // Find the purchase object
                final invoiceNo = item['desc'].toString().split("#").last;
                final purchase = _purchases.firstWhere(
                  (p) => p.invoiceNo == invoiceNo,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PurchaseDetailFrame(
                      repo: widget.purchaseRepo,
                      purchase: purchase,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat(
                          'dd MMM yyyy',
                        ).format(DateTime.parse(item['date'])),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (item['debit'] > 0)
                        Text(
                          "Debit: Rs ${item['debit']}",
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        Text(
                          "Credit: Rs ${item['credit']}",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['desc'],
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

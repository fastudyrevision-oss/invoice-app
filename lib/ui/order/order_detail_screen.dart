import 'package:flutter/material.dart';
import 'pdf_export_helper.dart'; // adjust path if needed
import 'dart:io';
import '../../models/invoice.dart';
import '../../models/customer.dart';
import '../../dao/customer_dao.dart';
import '../../db/database_helper.dart';

class OrderDetailScreen extends StatefulWidget {
  final Invoice invoice;

  const OrderDetailScreen({super.key, required this.invoice});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Customer? _customer;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final db = await DatabaseHelper.instance.db;
    final customerDao = CustomerDao(db);
    final customer = await customerDao.getCustomerById(
      widget.invoice.customerId,
    );

    final rawItems = await db.rawQuery(
      '''
      SELECT ii.qty, ii.price, p.name as product_name
      FROM invoice_items ii
      JOIN products p ON ii.product_id = p.id
      WHERE ii.invoice_id = ?
    ''',
      [widget.invoice.id],
    );

    setState(() {
      _customer = customer;
      _items = rawItems;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final invoice = widget.invoice;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.blueGrey[900],
        title: const Text(
          "Order Details",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: "Export to PDF",
            onPressed: () async {
              try {
                invoice.customerName ??= _customer?.name ?? "Unknown";
                final File? pdfFile = await generateInvoicePdf(
                  invoice,
                  items: _items,
                );
                if (pdfFile != null) {
                  await shareOrPrintPdf(pdfFile);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("PDF generation cancelled")),
                  );
                }
              } catch (e) {
                debugPrint("❌ Error generating invoice PDF: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to generate PDF: $e")),
                );
              }
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header Card ---
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Invoice #${invoice.id}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text("Customer: ${_customer?.name ?? 'Unknown'}"),
                      Text("Date: ${invoice.date}"),
                    ],
                  ),
                ),
              ),

              // --- Totals Card ---
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Invoice Summary",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow("Total", invoice.total),
                      _buildSummaryRow("Discount", invoice.discount),
                      _buildSummaryRow("Paid", invoice.paid),
                      _buildSummaryRow(
                        "Pending",
                        invoice.pending,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ),

              // --- Items Section ---
              const Text(
                "Items",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              ..._items.map((item) {
                final qty = item['qty'] ?? 0;
                final price = item['price'] ?? 0.0;
                final total = qty * price;

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      item['product_name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text("Qty: $qty × ${price.toStringAsFixed(2)}"),
                    trailing: Text(
                      total.toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 40),
              Center(
                child: Text(
                  "Thank you for your business!",
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

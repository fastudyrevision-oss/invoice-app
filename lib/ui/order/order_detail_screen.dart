import 'package:flutter/material.dart';
import 'pdf_export_helper.dart'; // adjust path if needed
import 'dart:io';
import '../../models/invoice.dart';
import '../../models/customer.dart';
import '../../dao/customer_dao.dart';
import '../../db/database_helper.dart';
import '../../utils/date_helper.dart';

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
    final isPaid = invoice.pending <= 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    "Order #${invoice.displayId ?? invoice.id.substring(0, 5)}${invoice.invoiceNo != null && invoice.invoiceNo!.isNotEmpty ? " (Inv: ${invoice.invoiceNo})" : ""}",
                    maxLines: 1,
                  ),
                );
              },
            ),
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isPaid
                      ? [Colors.blueGrey.shade800, Colors.blueGrey.shade600]
                      : [Colors.orange.shade700, Colors.orange.shade500],
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPaid ? Icons.check_circle : Icons.pending,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPaid ? "Paid" : "Pending",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              final qty = item['qty'] ?? 0;
              final price = item['price'] ?? 0.0;
              final total = qty * price;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.blueGrey.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withValues(alpha: 0.1),
                      spreadRadius: 1,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.blueGrey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blueGrey.shade600,
                              Colors.blueGrey.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shopping_cart,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${item['product_name'] ?? "Unknown Product"}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _buildItemChip(
                                  "Qty: $qty",
                                  Colors.purple,
                                  Icons.inventory,
                                ),
                                _buildItemChip(
                                  "Rs ${price.toStringAsFixed(0)}",
                                  Colors.green,
                                  Icons.attach_money,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.indigo.shade600,
                              Colors.indigo.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Rs ${total.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.grey.shade50],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.3),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Customer Info
                if (_customer != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          _customer!.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Metrics Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBottomMetric(
                      "Total",
                      "Rs ${invoice.total.toStringAsFixed(0)}",
                      Colors.blue,
                      Icons.receipt,
                    ),
                    _buildBottomMetric(
                      "Paid",
                      "Rs ${invoice.paid.toStringAsFixed(0)}",
                      Colors.green,
                      Icons.check_circle,
                    ),
                    _buildBottomMetric(
                      "Pending",
                      "Rs ${invoice.pending.toStringAsFixed(0)}",
                      invoice.pending > 0 ? Colors.red : Colors.green,
                      Icons.pending_actions,
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                // Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Date: ${DateHelper.formatIso(invoice.date)}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Action Buttons (Consolidated)
                OverflowBar(
                  alignment: MainAxisAlignment.spaceEvenly,
                  overflowAlignment: OverflowBarAlignment.center,
                  overflowSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _handlePrint('thermal'),
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text(
                        "Thermal",
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _handlePrint('pdf'),
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text("PDF", style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _handlePrint('print'),
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text(
                        "Print",
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Thank you for your business!",
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Wrapper to use existing popup logic or similar
  Future<void> _handlePrint(String value) async {
    try {
      final invoice = widget.invoice;
      invoice.customerName ??= _customer?.name ?? "Unknown";

      if (value == 'pdf') {
        final File? pdfFile = await generateInvoicePdf(invoice, items: _items);
        if (pdfFile != null) {
          await shareOrPrintPdf(pdfFile);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("PDF generation cancelled")),
          );
        }
      } else if (value == 'thermal') {
        final success = await printSilentThermalReceipt(invoice, items: _items);
        if (!success || !mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Sending to thermal printer...")),
        );
      } else if (value == 'print') {
        final File? pdfFile = await generateInvoicePdf(invoice, items: _items);
        if (pdfFile != null) {
          await printPdfFile(pdfFile);
        }
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  Widget _buildItemChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomMetric(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/invoice.dart';
import '../../models/purchase.dart';

/// 🧾 Reusable Receipt Widget for Thermal Printing
/// Designed to be rendered to image and sent to ESC/POS printers
/// Paper width: 80mm (standard thermal printer width)
class ThermalReceiptWidget extends StatelessWidget {
  final String title; // "INVOICE" or "PURCHASE RECEIPT"
  final String? companyName;
  final String? address;
  final String? phone;
  final String? customerOrSupplierName;
  final String? invoiceNumber;
  final String? date;
  final List<ReceiptItem> items;
  final double discount;
  final double subtotal;
  final double total;
  final double? paid;
  final double? pending;
  final String? footerText;
  final String? urduFooter;

  const ThermalReceiptWidget({
    super.key,
    required this.title,
    this.companyName,
    this.address,
    this.phone,
    this.customerOrSupplierName,
    this.invoiceNumber,
    this.date,
    required this.items,
    this.discount = 0.0,
    required this.subtotal,
    required this.total,
    this.paid,
    this.pending,
    this.footerText,
    this.urduFooter,
  });

  @override
  Widget build(BuildContext context) {
    // Fixed width for 80mm thermal paper (approx 384px @ 96dpi or 320px @ 80dpi)
    // We use 384 pixels for good quality on most screens
    return Container(
      width: 384, // 80mm @ 96dpi
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 🏢 Company Header
          if (companyName != null) ...[
            Text(
              companyName!.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (address != null)
            Text(
              address!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontFamily: 'Roboto'),
            ),
          if (phone != null)
            Text(
              phone!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontFamily: 'Roboto'),
            ),

          const SizedBox(height: 12),
          _buildDivider(),
          const SizedBox(height: 12),

          // 📄 Receipt Type & Date
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 8),

          // Invoice Details
          _buildDetailRow('Invoice:', invoiceNumber ?? 'N/A'),
          const SizedBox(height: 4),
          _buildDetailRow(
            'Date:',
            date ?? DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now()),
          ),
          const SizedBox(height: 4),
          _buildDetailRow(
            'Customer/Supplier:',
            customerOrSupplierName ?? 'N/A',
          ),

          const SizedBox(height: 12),
          _buildDivider(),
          const SizedBox(height: 8),

          // 📦 Items Table
          if (items.isNotEmpty) ...[
            _buildItemsTable(),
            const SizedBox(height: 8),
            _buildDivider(),
            const SizedBox(height: 8),
          ],

          // 💰 Totals Section
          _buildTotalRow('Subtotal:', subtotal),
          if (discount > 0) _buildTotalRow('Discount:', -discount),
          const SizedBox(height: 4),
          _buildDivider(),
          const SizedBox(height: 4),
          if (paid != null) _buildTotalRow('Paid:', paid!, isBold: true),
          if (pending != null)
            _buildTotalRow('Pending:', pending!, isBold: true),
          const SizedBox(height: 8),
          _buildTotalRow('TOTAL:', total, isBold: true, fontSize: 14),

          const SizedBox(height: 12),
          _buildDivider(),
          const SizedBox(height: 8),

          // 🙏 Footer
          if (footerText != null)
            Text(
              footerText!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),

          // Urdu Footer (if available)
          if (urduFooter != null) ...[
            const SizedBox(height: 4),
            Text(
              urduFooter!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'SchFont', // Scheherazade for Urdu
              ),
            ),
          ],

          const SizedBox(height: 8),
          Text(
            'Thank You!',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 2, color: Colors.black, width: double.infinity);
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontFamily: 'Roboto')),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 10, fontFamily: 'Roboto'),
            // Removed maxLines to allow proper wrapping for long customer/supplier names
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(
    String label,
    double value, {
    bool isBold = false,
    double fontSize = 11,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'Roboto',
          ),
        ),
        Text(
          'Rs ${value.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }

  Widget _buildItemsTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: const [
            Expanded(
              flex: 3,
              child: Text(
                'Item',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Qty',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Price',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Total',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: Colors.grey),
        const SizedBox(height: 4),

        // Items
        ...items.map((item) => _buildItemRow(item)),
      ],
    );
  }

  Widget _buildItemRow(ReceiptItem item) {
    final itemTotal = item.quantity * item.price;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                item.name,
                style: const TextStyle(fontSize: 9, fontFamily: 'Roboto'),
                // Removed maxLines to allow proper wrapping for long product names
              ),
            ),
            Expanded(
              child: Text(
                item.quantity.toStringAsFixed(0),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 9, fontFamily: 'Roboto'),
              ),
            ),
            Expanded(
              child: Text(
                item.price.toStringAsFixed(0),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 9, fontFamily: 'Roboto'),
              ),
            ),
            Expanded(
              child: Text(
                itemTotal.toStringAsFixed(0),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 9, fontFamily: 'Roboto'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
      ],
    );
  }
}

/// 📦 Model for receipt items
class ReceiptItem {
  final String name;
  final double quantity;
  final double price;

  ReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  double get total => quantity * price;
}

/// 🏗️ Factory methods for creating receipts from Invoice/Purchase models
class ReceiptFactory {
  /// Create a receipt from an Invoice (Order)
  static ThermalReceiptWidget fromInvoice(
    Invoice invoice, {
    List<ReceiptItem>? items,
  }) {
    return ThermalReceiptWidget(
      title: 'INVOICE',
      companyName: 'MIAN TRADERS',
      address: 'Sargodha',
      phone: '+92 345 4297128',
      customerOrSupplierName: invoice.customerName,
      invoiceNumber: invoice.id.toString(),
      date: invoice.date,
      items: items ?? [],
      discount: invoice.discount,
      subtotal: invoice.total - invoice.discount,
      total: invoice.total,
      paid: invoice.total - invoice.pending,
      pending: invoice.pending,
      footerText: 'Thank You!',
      urduFooter: 'میاں ٹریڈرز',
    );
  }

  /// Create a receipt from a Purchase (Supply)
  static ThermalReceiptWidget fromPurchase(
    Purchase purchase, {
    List<ReceiptItem>? items,
    String? supplierName,
  }) {
    return ThermalReceiptWidget(
      title: 'PURCHASE RECEIPT',
      companyName: 'MIAN TRADERS',
      address: 'Sargodha',
      phone: '+92 345 4297128',
      customerOrSupplierName: supplierName,
      invoiceNumber: purchase.invoiceNo,
      date: purchase.date,
      items: items ?? [],
      discount: 0,
      subtotal: purchase.total,
      total: purchase.total,
      paid: purchase.paid,
      pending: purchase.pending,
      footerText: 'Thank You!',
      urduFooter: 'میاں ٹریڈرز',
    );
  }
}

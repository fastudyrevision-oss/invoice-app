import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/product.dart';

class ProductExportService {
  /// Export product list to beautiful PDF with multi-page support
  Future<void> exportToPDF(List<Product> products) async {
    if (products.isEmpty) {
      print('⚠️ No products to export.');
      return;
    }

    final pdf = pw.Document();
    final now = DateTime.now();

    // Calculate summary statistics
    final totalStockValue = products.fold<double>(
      0,
      (sum, p) => sum + (p.quantity * p.sellPrice),
    );
    final lowStockCount = products
        .where((p) => p.quantity <= p.minStock)
        .length;
    final totalQuantity = products.fold<int>(0, (sum, p) => sum + p.quantity);

    // Group products into pages (25 per page for wider table)
    const itemsPerPage = 25;
    final totalPages = (products.length / itemsPerPage).ceil();

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage > products.length)
          ? products.length
          : startIndex + itemsPerPage;
      final pageProducts = products.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape, // Landscape for more columns
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            // ═══════════════════════════════════════
            // 🎨 BEAUTIFUL HEADER
            // ═══════════════════════════════════════
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(
                  colors: [PdfColors.green700, PdfColors.green900],
                ),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Product Inventory Report',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Page ${pageIndex + 1} of $totalPages',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Generated: ${_formatDateTime(now)}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Total Products: ${products.length}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // ═══════════════════════════════════════
            // 📊 SUMMARY CARDS (Only on first page)
            // ═══════════════════════════════════════
            if (pageIndex == 0) ...[
              pw.Row(
                children: [
                  _buildSummaryCard(
                    'Total Stock Value',
                    'Rs ${totalStockValue.toStringAsFixed(2)}',
                    PdfColors.green700,
                  ),
                  pw.SizedBox(width: 10),
                  _buildSummaryCard(
                    'Total Quantity',
                    '$totalQuantity units',
                    PdfColors.blue700,
                  ),
                  pw.SizedBox(width: 10),
                  _buildSummaryCard(
                    'Low Stock Items',
                    '$lowStockCount products',
                    PdfColors.red700,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // ═══════════════════════════════════════
            // 📋 BEAUTIFUL DATA TABLE
            // ═══════════════════════════════════════
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.6), // #
                1: const pw.FlexColumnWidth(3), // Name
                2: const pw.FlexColumnWidth(2), // Category
                3: const pw.FlexColumnWidth(1.5), // Qty
                4: const pw.FlexColumnWidth(1.5), // Cost
                5: const pw.FlexColumnWidth(1.5), // Sell
                6: const pw.FlexColumnWidth(1.5), // Profit
                7: const pw.FlexColumnWidth(1.5), // Reorder
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.green50),
                  children: [
                    _buildHeaderCell('#'),
                    _buildHeaderCell('Product'),
                    _buildHeaderCell('Category'),
                    _buildHeaderCell('Qty'),
                    _buildHeaderCell('Cost'),
                    _buildHeaderCell('Sell'),
                    _buildHeaderCell('Profit/U'),
                    _buildHeaderCell('Reorder'),
                  ],
                ),
                // Data Rows
                ...pageProducts.asMap().entries.map((entry) {
                  final index = startIndex + entry.key;
                  final product = entry.value;
                  final isEven = index % 2 == 0;
                  final isLowStock = product.quantity <= product.minStock;
                  final profit = product.sellPrice - product.costPrice;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isLowStock
                          ? PdfColors.red50
                          : (isEven ? PdfColors.white : PdfColors.grey50),
                    ),
                    children: [
                      _buildDataCell((index + 1).toString(), fontSize: 8),
                      _buildDataCell(
                        product.name,
                        bold: isLowStock,
                        fontSize: 8,
                      ),
                      _buildDataCell(
                        product.categoryId.toString(),
                        fontSize: 8,
                      ),
                      _buildDataCell(
                        product.quantity.toString(),
                        bold: isLowStock,
                        color: isLowStock ? PdfColors.red900 : null,
                        fontSize: 8,
                      ),
                      _buildDataCell(
                        product.costPrice.toStringAsFixed(2),
                        fontSize: 8,
                      ),
                      _buildDataCell(
                        product.sellPrice.toStringAsFixed(2),
                        fontSize: 8,
                      ),
                      _buildDataCell(
                        profit.toStringAsFixed(2),
                        color: profit > 0
                            ? PdfColors.green900
                            : PdfColors.red900,
                        fontSize: 8,
                      ),
                      _buildDataCell(
                        product.minStock.toString(),
                        fontSize: 8,
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 16),

            // ═══════════════════════════════════════
            // 📌 FOOTER (Only on last page)
            // ═══════════════════════════════════════
            if (pageIndex == totalPages - 1) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                  color: PdfColors.grey50,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Report Summary',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Total Products: ${products.length} | Total Stock Value: Rs ${totalStockValue.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                    pw.Text(
                      'Prepared via میاں ٹریڈرز',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    // ═══════════════════════════════════════
    // 🖨️ SHARE PDF
    // ═══════════════════════════════════════
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Product_Report_${_formatDate(now)}.pdf',
    );

    print(
      '✅ Product Report PDF exported successfully (${products.length} records, $totalPages pages).',
    );
  }

  // ═══════════════════════════════════════
  // 🎨 HELPER WIDGETS
  // ═══════════════════════════════════════

  pw.Widget _buildSummaryCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: color.shade(0.1),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: color, width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.green900,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildDataCell(
    String text, {
    bool bold = false,
    PdfColor? color,
    double fontSize = 9,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // ═══════════════════════════════════════
  // 🛠️ UTILITY FUNCTIONS
  // ═══════════════════════════════════════

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

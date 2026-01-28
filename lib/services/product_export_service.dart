import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../models/product.dart';
import '../utils/unified_print_helper.dart';
import '../utils/pdf_font_helper.dart';
import '../services/logger_service.dart';

class ProductExportService {
  /// Print product list directly
  Future<void> printProductList(
    List<Product> products, {
    String? categoryName,
    String? supplierName,
    bool lowStockOnly = false,
  }) async {
    logger.info(
      'ProductExport',
      'Printing Product Report',
      context: {'count': products.length, 'lowStock': lowStockOnly},
    );
    final pdfBytes = await _generatePdf(
      products,
      categoryName: categoryName,
      supplierName: supplierName,
      lowStockOnly: lowStockOnly,
    );

    await UnifiedPrintHelper.printPdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Product_Report_${_formatDate(DateTime.now())}.pdf',
    );
  }

  /// Save product list PDF to file
  Future<File?> saveProductListPdf(
    List<Product> products, {
    String? categoryName,
    String? supplierName,
    bool lowStockOnly = false,
  }) async {
    logger.info(
      'ProductExport',
      'Saving Product Report PDF',
      context: {'count': products.length},
    );
    final pdfBytes = await _generatePdf(
      products,
      categoryName: categoryName,
      supplierName: supplierName,
      lowStockOnly: lowStockOnly,
    );

    return await UnifiedPrintHelper.savePdfBytes(
      pdfBytes: pdfBytes,
      suggestedName: 'Product_Report_${_formatDate(DateTime.now())}.pdf',
      dialogTitle: 'Save Product Report',
    );
  }

  /// Export product list to beautiful PDF with multi-page support
  Future<void> exportToPDF(
    List<Product> products, {
    String? categoryName,
    String? supplierName,
    bool lowStockOnly = false,
  }) async {
    logger.info(
      'ProductExport',
      'Exporting Product Report',
      context: {'count': products.length},
    );
    final pdfBytes = await _generatePdf(
      products,
      categoryName: categoryName,
      supplierName: supplierName,
      lowStockOnly: lowStockOnly,
    );

    await UnifiedPrintHelper.sharePdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Product_Report_${_formatDate(DateTime.now())}.pdf',
    );

    logger.info(
      'ProductExport',
      'Product Report PDF exported successfully',
      context: {'count': products.length},
    );
  }

  Future<Uint8List> _generatePdf(
    List<Product> products, {
    String? categoryName,
    String? supplierName,
    bool lowStockOnly = false,
  }) async {
    if (products.isEmpty) {
      return Uint8List(0);
    }

    final pdf = pw.Document();
    final now = DateTime.now();

    // Load fonts
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    // Calculate summary statistics
    final totalStockValue = products.fold<double>(
      0,
      (sum, p) => sum + (p.quantity * p.sellPrice),
    );
    final lowStockCount = products
        .where((p) => p.quantity <= p.minStock)
        .length;
    final totalQuantity = products.fold<int>(0, (sum, p) => sum + p.quantity);

    // Build filter summary
    final List<String> activeFilters = [];
    if (categoryName != null) activeFilters.add('Category: $categoryName');
    if (supplierName != null) activeFilters.add('Supplier: $supplierName');
    if (lowStockOnly) activeFilters.add('Low Stock Only');

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
                          font: boldFont,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Page ${pageIndex + 1} of $totalPages',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.white,
                          font: regularFont,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Generated: ${_formatDateTime(now)}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white,
                          font: regularFont,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Total Products: ${products.length}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          font: boldFont,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // Active Filters Section (only on first page)
            if (pageIndex == 0 && activeFilters.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.green200),
                ),
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      'Filters: ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green900,
                        fontSize: 10,
                        font: boldFont,
                      ),
                    ),
                    pw.Text(
                      activeFilters.join(', '),
                      style: pw.TextStyle(
                        color: PdfColors.green900,
                        fontSize: 10,
                        font: regularFont,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
            ],

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
                    regularFont,
                    boldFont,
                  ),
                  pw.SizedBox(width: 10),
                  _buildSummaryCard(
                    'Total Quantity',
                    '$totalQuantity units',
                    PdfColors.blue700,
                    regularFont,
                    boldFont,
                  ),
                  pw.SizedBox(width: 10),
                  _buildSummaryCard(
                    'Low Stock Items',
                    '$lowStockCount products',
                    PdfColors.red700,
                    regularFont,
                    boldFont,
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
                    _buildHeaderCell('#', boldFont),
                    _buildHeaderCell('Product', boldFont),
                    _buildHeaderCell('Category', boldFont),
                    _buildHeaderCell('Qty', boldFont),
                    _buildHeaderCell('Cost', boldFont),
                    _buildHeaderCell('Sell', boldFont),
                    _buildHeaderCell('Profit/U', boldFont),
                    _buildHeaderCell('Reorder', boldFont),
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
                      _buildDataCell(
                        (index + 1).toString(),
                        font: regularFont,
                        fontSize: 8,
                      ),
                      _buildDataCell(
                        product.name,
                        bold: isLowStock,
                        fontSize: 8,
                        font: isLowStock ? boldFont : regularFont,
                      ),
                      _buildDataCell(
                        product.categoryId.toString(),
                        fontSize: 8,
                        font: regularFont,
                      ),
                      _buildDataCell(
                        product.quantity.toString(),
                        bold: isLowStock,
                        color: isLowStock ? PdfColors.red900 : null,
                        fontSize: 8,
                        font: isLowStock ? boldFont : regularFont,
                      ),
                      _buildDataCell(
                        product.costPrice.toStringAsFixed(2),
                        fontSize: 8,
                        font: regularFont,
                      ),
                      _buildDataCell(
                        product.sellPrice.toStringAsFixed(2),
                        fontSize: 8,
                        font: regularFont,
                      ),
                      _buildDataCell(
                        profit.toStringAsFixed(2),
                        color: profit > 0
                            ? PdfColors.green900
                            : PdfColors.red900,
                        fontSize: 8,
                        font: regularFont,
                      ),
                      _buildDataCell(
                        product.minStock.toString(),
                        fontSize: 8,
                        font: regularFont,
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
                            font: boldFont,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Total Products: ${products.length} | Total Stock Value: Rs ${totalStockValue.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 9, font: regularFont),
                        ),
                      ],
                    ),
                    pw.Text(
                      'Prepared via میاں ٹریڈرز',
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                        font: regularFont,
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

    return await pdf.save();
  }

  // ═══════════════════════════════════════
  // 🎨 HELPER WIDGETS
  // ═══════════════════════════════════════

  pw.Widget _buildSummaryCard(
    String label,
    String value,
    PdfColor color,
    pw.Font regular,
    pw.Font bold,
  ) {
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
                font: bold,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: color,
                font: bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildHeaderCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.green900,
          font: font,
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
    required pw.Font font,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
          font: font,
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

import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../models/purchase.dart';
import '../utils/unified_print_helper.dart';
import '../utils/pdf_font_helper.dart';
import '../services/logger_service.dart';

class PurchaseExportService {
  /// Print purchase list directly
  Future<void> printPurchaseList(
    List<Purchase> purchases, {
    String? supplierName,
  }) async {
    logger.info(
      'PurchaseExport',
      'Printing Purchase Report',
      context: {'count': purchases.length, 'supplier': supplierName},
    );
    final pdfBytes = await _generatePdf(purchases, supplierName: supplierName);

    await UnifiedPrintHelper.printPdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Purchase_Report_${_formatDateFile(DateTime.now())}.pdf',
    );
  }

  /// Save purchase list PDF to file
  Future<File?> savePurchaseListPdf(
    List<Purchase> purchases, {
    String? supplierName,
  }) async {
    final pdfBytes = await _generatePdf(purchases, supplierName: supplierName);

    return await UnifiedPrintHelper.savePdfBytes(
      pdfBytes: pdfBytes,
      suggestedName: 'Purchase_Report_${_formatDateFile(DateTime.now())}.pdf',
      dialogTitle: 'Save Purchase Report',
    );
  }

  /// Export purchase list to beautiful PDF with multi-page support
  Future<void> exportToPDF(
    List<Purchase> purchases, {
    String? supplierName,
  }) async {
    final pdfBytes = await _generatePdf(purchases, supplierName: supplierName);

    await UnifiedPrintHelper.sharePdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Purchase_Report_${_formatDateFile(DateTime.now())}.pdf',
    );

    logger.info(
      'PurchaseExport',
      'Purchase Report PDF exported successfully',
      context: {'count': purchases.length},
    );
  }

  Future<Uint8List> _generatePdf(
    List<Purchase> purchases, {
    String? supplierName,
  }) async {
    if (purchases.isEmpty) {
      return Uint8List(0);
    }

    final pdf = pw.Document();
    final now = DateTime.now();

    // Load fonts
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    // Calculate summary statistics
    final totalAmount = purchases.fold<double>(0, (sum, p) => sum + p.total);
    final totalPaid = purchases.fold<double>(0, (sum, p) => sum + p.paid);
    final totalPending = purchases.fold<double>(0, (sum, p) => sum + p.pending);

    // Group purchases into pages (30 per page)
    const itemsPerPage = 30;
    final totalPages = (purchases.length / itemsPerPage).ceil();

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage > purchases.length)
          ? purchases.length
          : startIndex + itemsPerPage;
      final pagePurchases = purchases.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            // ═══════════════════════════════════════
            // 🎨 BEAUTIFUL HEADER
            // ═══════════════════════════════════════
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(
                  colors: [PdfColors.teal700, PdfColors.teal900],
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
                        'Purchase Report',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          font: boldFont,
                        ),
                      ),
                      if (supplierName != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Supplier: $supplierName',
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.white,
                            font: regularFont,
                          ),
                        ),
                      ],
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Page ${pageIndex + 1} of $totalPages',
                        style: pw.TextStyle(
                          fontSize: 12,
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
                          fontSize: 10,
                          color: PdfColors.white,
                          font: regularFont,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Total Records: ${purchases.length}',
                        style: pw.TextStyle(
                          fontSize: 11,
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

            pw.SizedBox(height: 20),

            // ═══════════════════════════════════════
            // 📊 SUMMARY CARDS (Only on first page)
            // ═══════════════════════════════════════
            if (pageIndex == 0) ...[
              pw.Row(
                children: [
                  _buildSummaryCard(
                    'Total Purchases',
                    'Rs ${totalAmount.toStringAsFixed(2)}',
                    PdfColors.teal700,
                    regularFont,
                    boldFont,
                  ),
                  pw.SizedBox(width: 12),
                  _buildSummaryCard(
                    'Total Paid',
                    'Rs ${totalPaid.toStringAsFixed(2)}',
                    PdfColors.green700,
                    regularFont,
                    boldFont,
                  ),
                  pw.SizedBox(width: 12),
                  _buildSummaryCard(
                    'Total Pending',
                    'Rs ${totalPending.toStringAsFixed(2)}',
                    PdfColors.orange700,
                    regularFont,
                    boldFont,
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
            ],

            // ═══════════════════════════════════════
            // 📋 BEAUTIFUL DATA TABLE
            // ═══════════════════════════════════════
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.8), // #
                1: const pw.FlexColumnWidth(2), // Date
                2: const pw.FlexColumnWidth(2.5), // Invoice
                3: const pw.FlexColumnWidth(3), // Supplier
                4: const pw.FlexColumnWidth(2), // Total
                5: const pw.FlexColumnWidth(2), // Paid
                6: const pw.FlexColumnWidth(2), // Pending
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                  children: [
                    _buildHeaderCell('#', boldFont),
                    _buildHeaderCell('Date', boldFont),
                    _buildHeaderCell('Invoice #', boldFont),
                    _buildHeaderCell('Supplier', boldFont),
                    _buildHeaderCell('Total', boldFont),
                    _buildHeaderCell('Paid', boldFont),
                    _buildHeaderCell('Pending', boldFont),
                  ],
                ),
                // Data Rows
                ...pagePurchases.asMap().entries.map((entry) {
                  final index = startIndex + entry.key;
                  final purchase = entry.value;
                  final isEven = index % 2 == 0;
                  final hasPending = purchase.pending > 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: [
                      _buildDataCell((index + 1).toString(), font: regularFont),
                      _buildDataCell(
                        _formatDate(DateTime.parse(purchase.createdAt)),
                        font: regularFont,
                      ),
                      _buildDataCell(purchase.invoiceNo, font: regularFont),
                      _buildDataCell(purchase.supplierId, font: regularFont),
                      _buildDataCell(
                        purchase.total.toStringAsFixed(2),
                        bold: true,
                        font: boldFont,
                      ),
                      _buildDataCell(
                        purchase.paid.toStringAsFixed(2),
                        color: PdfColors.green700,
                        font: regularFont,
                      ),
                      _buildDataCell(
                        purchase.pending.toStringAsFixed(2),
                        bold: hasPending,
                        color: hasPending ? PdfColors.orange700 : null,
                        font: hasPending ? boldFont : regularFont,
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 20),

            // ═══════════════════════════════════════
            // 📌 FOOTER (Only on last page)
            // ═══════════════════════════════════════
            if (pageIndex == totalPages - 1) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
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
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            font: boldFont,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Total Records: ${purchases.length}',
                          style: pw.TextStyle(fontSize: 10, font: regularFont),
                        ),
                        pw.Text(
                          'Total Amount: Rs ${totalAmount.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 10, font: regularFont),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Prepared via میاں ٹریڈرز',
                          textDirection: pw.TextDirection.rtl,
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                            font: regularFont,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _formatDateTime(now),
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                            font: regularFont,
                          ),
                        ),
                      ],
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
        padding: const pw.EdgeInsets.all(12),
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
                fontSize: 10,
                color: color,
                fontWeight: pw.FontWeight.bold,
                font: bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
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
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.teal900,
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
    required pw.Font font,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
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

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatDateFile(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

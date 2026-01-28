import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../models/expiring_batch_detail.dart';
import '../utils/unified_print_helper.dart';
import '../utils/pdf_font_helper.dart';
import '../services/logger_service.dart';

class ExpiringExportService {
  /// Print expiring products report directly
  Future<void> printExpiringProducts(List<ExpiringBatchDetail> batches) async {
    logger.info(
      'ExpiringExport',
      'Printing Expiring Products Report',
      context: {'count': batches.length},
    );
    final pdfBytes = await _generatePdf(batches);

    await UnifiedPrintHelper.printPdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Expiring_Report_${_formatDate(DateTime.now())}.pdf',
    );
  }

  /// Save expiring products report PDF to file
  Future<File?> saveExpiringProductsPdf(
    List<ExpiringBatchDetail> batches,
  ) async {
    logger.info(
      'ExpiringExport',
      'Saving Expiring Products Report PDF',
      context: {'count': batches.length},
    );
    final pdfBytes = await _generatePdf(batches);

    return await UnifiedPrintHelper.savePdfBytes(
      pdfBytes: pdfBytes,
      suggestedName: 'Expiring_Report_${_formatDate(DateTime.now())}.pdf',
      dialogTitle: 'Save Expiring Products Report',
    );
  }

  /// Export expiring products report to PDF
  Future<void> exportToPDF(
    List<ExpiringBatchDetail> batches, {
    bool includePrice =
        false, // Not available in model currently, but keeping structure
  }) async {
    logger.info(
      'ExpiringExport',
      'Exporting Expiring Products Report',
      context: {'count': batches.length},
    );
    final pdfBytes = await _generatePdf(batches);

    await UnifiedPrintHelper.sharePdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Expiring_Report_${_formatDate(DateTime.now())}.pdf',
    );
  }

  Future<Uint8List> _generatePdf(List<ExpiringBatchDetail> batches) async {
    if (batches.isEmpty) {
      return Uint8List(0);
    }

    final pdf = pw.Document();
    final now = DateTime.now();

    // Load fonts
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    // Normalize 'now' to today's midnight for fair date comparison
    final today = DateTime(now.year, now.month, now.day);

    final totalItems = batches.fold<int>(0, (sum, b) => sum + b.qty);

    // Consistent Expiry Logic:
    // Expired: Expiry Date is strictly before Today (Yesterday or older).
    // Urgent: Expiry Date is Today or within next 30 days.

    final expiredCount = batches.where((b) {
      final expiry = DateTime(
        b.expiryDate.year,
        b.expiryDate.month,
        b.expiryDate.day,
      );
      return expiry.isBefore(today);
    }).length;

    final expiringSoonCount = batches.where((b) {
      final expiry = DateTime(
        b.expiryDate.year,
        b.expiryDate.month,
        b.expiryDate.day,
      );
      final diff = expiry.difference(today).inDays;
      // 0 = Today, 30 = 30 days from now.
      // Ensure we don't count already expired items as "expiring soon" if they are clearly expired.
      // logic: is not expired AND diff <= 30
      return !expiry.isBefore(today) && diff <= 30;
    }).length;

    // ═══════════════════════════════════════
    // 🧱 COLUMN SETUP
    // ═══════════════════════════════════════
    final columns = <String>[
      '#',
      'Product',
      'Batch',
      'Supplier',
      'Quantity',
      'Expiry Date',
      'Days Left',
    ];

    // ═══════════════════════════════════════
    // 📄 MULTI-PAGE SUPPORT
    // ═══════════════════════════════════════
    const itemsPerPage = 20;
    final totalPages = (batches.length / itemsPerPage).ceil();

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage > batches.length)
          ? batches.length
          : startIndex + itemsPerPage;
      final pageBatches = batches.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            // HEADER
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(
                  colors: [PdfColors.red700, PdfColors.red900],
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
                        'Expiring Products Report',
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
                        'Total Batches: ${batches.length}',
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

            // SUMMARY CARDS (Page 0)
            if (pageIndex == 0) ...[
              pw.Row(
                children: [
                  _buildSummaryCard(
                    'Total Quantity',
                    '$totalItems units',
                    PdfColors.blue700,
                    regularFont,
                    boldFont,
                  ),
                  pw.SizedBox(width: 10),
                  _buildSummaryCard(
                    'Already Expired',
                    '$expiredCount batches',
                    PdfColors.red700,
                    regularFont,
                    boldFont,
                  ),
                  pw.SizedBox(width: 10),
                  _buildSummaryCard(
                    'Expiring < 30 Days',
                    '$expiringSoonCount batches',
                    PdfColors.orange700,
                    regularFont,
                    boldFont,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // TABLE
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5), // #
                1: const pw.FlexColumnWidth(2.5), // Product
                2: const pw.FlexColumnWidth(1.5), // Batch
                3: const pw.FlexColumnWidth(2.0), // Supplier
                4: const pw.FlexColumnWidth(1.0), // Qty
                5: const pw.FlexColumnWidth(1.5), // Expiry
                6: const pw.FlexColumnWidth(1.5), // Days Left
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.red50),
                  children: columns
                      .map((col) => _buildHeaderCell(col, boldFont))
                      .toList(),
                ),
                // Data
                ...pageBatches.asMap().entries.map((entry) {
                  final index = startIndex + entry.key;
                  final b = entry.value;
                  final isEven = index % 2 == 0;

                  // Normalize dates for consistency with summary
                  final today = DateTime(now.year, now.month, now.day);
                  final expiry = DateTime(
                    b.expiryDate.year,
                    b.expiryDate.month,
                    b.expiryDate.day,
                  );

                  final diff = expiry.difference(today).inDays;
                  final isExpired = expiry.isBefore(today);
                  final isUrgent = !isExpired && diff <= 30;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isExpired
                          ? PdfColors.red50
                          : isUrgent
                          ? PdfColors.orange50
                          : (isEven ? PdfColors.white : PdfColors.grey50),
                    ),
                    children: [
                      _buildDataCell((index + 1).toString(), font: regularFont),
                      _buildDataCell(b.productName, bold: true, font: boldFont),
                      _buildDataCell(b.batchNo, font: regularFont),
                      _buildDataCell(b.supplierName ?? '-', font: regularFont),
                      _buildDataCell(b.qty.toString(), font: regularFont),
                      _buildDataCell(
                        _formatDate(b.expiryDate),
                        font: regularFont,
                      ),
                      _buildDataCell(
                        isExpired ? "Expired (${-diff}d ago)" : "$diff days",
                        color: isExpired
                            ? PdfColors.red900
                            : (isUrgent
                                  ? PdfColors.orange900
                                  : PdfColors.green900),
                        bold: isExpired || isUrgent,
                        font: (isExpired || isUrgent) ? boldFont : regularFont,
                      ),
                    ],
                  );
                }),
              ],
            ),

            // FOOTER (Last Page)
            if (pageIndex == totalPages - 1) ...[
              pw.SizedBox(height: 16),
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
                    pw.Text(
                      'Report ends.',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                        font: regularFont,
                      ),
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

  // ════════ HELPER WIDGETS ════════

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
          color: PdfColors.red900,
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

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

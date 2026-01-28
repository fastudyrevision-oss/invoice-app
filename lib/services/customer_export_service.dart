import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../models/customer.dart';
import '../utils/unified_print_helper.dart';
import '../utils/pdf_font_helper.dart';
import '../services/logger_service.dart';

class CustomerExportService {
  /// Print customer report directly
  Future<void> printCustomerReport(List<Customer> customers) async {
    logger.info(
      'CustomerExport',
      'Printing Customer Report',
      context: {'count': customers.length},
    );
    final pdfBytes = await _generatePdf(customers);

    await UnifiedPrintHelper.printPdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Customer_Report_${_formatDate(DateTime.now())}.pdf',
    );
  }

  /// Save customer report PDF to file
  Future<File?> saveCustomerReportPdf(List<Customer> customers) async {
    logger.info(
      'CustomerExport',
      'Saving Customer Report PDF',
      context: {'count': customers.length},
    );
    final pdfBytes = await _generatePdf(customers);

    return await UnifiedPrintHelper.savePdfBytes(
      pdfBytes: pdfBytes,
      suggestedName: 'Customer_Report_${_formatDate(DateTime.now())}.pdf',
      dialogTitle: 'Save Customer Report',
    );
  }

  /// Export customer list to beautiful PDF with multi-page support
  Future<void> exportToPDF(List<Customer> customers) async {
    logger.info(
      'CustomerExport',
      'Exporting Customer Report',
      context: {'count': customers.length},
    );
    final pdfBytes = await _generatePdf(customers);

    await UnifiedPrintHelper.sharePdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Customer_Report_${_formatDate(DateTime.now())}.pdf',
    );

    logger.info(
      'CustomerExport',
      'Customer Report PDF exported successfully',
      context: {'count': customers.length},
    );
  }

  Future<Uint8List> _generatePdf(List<Customer> customers) async {
    if (customers.isEmpty) {
      return Uint8List(0);
    }

    final pdf = pw.Document();
    final now = DateTime.now();

    // Load fonts
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    // Calculate summary statistics
    final totalPending = customers.fold<double>(
      0,
      (sum, c) => sum + c.pendingAmount,
    );
    final avgPending = totalPending / customers.length;
    final customersWithPending = customers
        .where((c) => c.pendingAmount > 0)
        .length;

    // Group customers into pages (30 per page for readability)
    const itemsPerPage = 30;
    final totalPages = (customers.length / itemsPerPage).ceil();

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage > customers.length)
          ? customers.length
          : startIndex + itemsPerPage;
      final pageCustomers = customers.sublist(startIndex, endIndex);

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
                  colors: [PdfColors.blue700, PdfColors.blue900],
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
                        'Customer Report',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          font: boldFont,
                        ),
                      ),
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
                        'Total Customers: ${customers.length}',
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
                    'Total Pending',
                    'Rs ${totalPending.toStringAsFixed(2)}',
                    PdfColors.orange700,
                    regularFont,
                    boldFont,
                  ),
                  pw.SizedBox(width: 12),
                  _buildSummaryCard(
                    'Average Pending',
                    'Rs ${avgPending.toStringAsFixed(2)}',
                    PdfColors.blue700,
                    regularFont,
                    boldFont,
                  ),
                  pw.SizedBox(width: 12),
                  _buildSummaryCard(
                    'With Pending',
                    '$customersWithPending customers',
                    PdfColors.red700,
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
                1: const pw.FlexColumnWidth(3), // Name
                2: const pw.FlexColumnWidth(2.5), // Phone
                3: const pw.FlexColumnWidth(3.5), // Address
                4: const pw.FlexColumnWidth(2), // Pending
                5: const pw.FlexColumnWidth(2), // Credit Limit
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    _buildHeaderCell('#', boldFont),
                    _buildHeaderCell('Customer Name', boldFont),
                    _buildHeaderCell('Phone', boldFont),
                    _buildHeaderCell('Address', boldFont),
                    _buildHeaderCell('Pending (Rs)', boldFont),
                    _buildHeaderCell('Credit Limit', boldFont),
                  ],
                ),
                // Data Rows
                ...pageCustomers.asMap().entries.map((entry) {
                  final index = startIndex + entry.key;
                  final customer = entry.value;
                  final isEven = index % 2 == 0;
                  final hasPending = customer.pendingAmount > 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: hasPending
                          ? PdfColors.red50
                          : (isEven ? PdfColors.white : PdfColors.grey50),
                    ),
                    children: [
                      _buildDataCell((index + 1).toString(), font: regularFont),
                      _buildDataCell(
                        customer.name,
                        bold: hasPending,
                        font: hasPending ? boldFont : regularFont,
                      ),
                      _buildDataCell(customer.phone, font: regularFont),
                      _buildDataCell(
                        customer.address ?? '-',
                        font: regularFont,
                      ),
                      _buildDataCell(
                        customer.pendingAmount.toStringAsFixed(2),
                        bold: hasPending,
                        color: hasPending ? PdfColors.red900 : null,
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
                          'Total Records: ${customers.length}',
                          style: pw.TextStyle(fontSize: 10, font: regularFont),
                        ),
                        pw.Text(
                          'Total Pending Amount: Rs ${totalPending.toStringAsFixed(2)}',
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
          color: PdfColors.blue900,
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

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

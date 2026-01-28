import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../models/supplier.dart';
import '../utils/unified_print_helper.dart';
import '../utils/pdf_font_helper.dart';
import '../services/logger_service.dart';

class SupplierExportService {
  /// Print supplier list directly
  Future<void> printSupplierList(
    List<Supplier> suppliers, {
    String? searchKeyword,
    String? companyName,
    bool? pendingFilter,
    double? minCredit,
    double? maxCredit,
    double? minPending,
    double? maxPending,
    bool showDeleted = false,
  }) async {
    logger.info(
      'SupplierExport',
      'Printing Supplier Report',
      context: {'count': suppliers.length},
    );
    final pdfBytes = await _generatePdf(
      suppliers,
      searchKeyword: searchKeyword,
      companyName: companyName,
      pendingFilter: pendingFilter,
      minCredit: minCredit,
      maxCredit: maxCredit,
      minPending: minPending,
      maxPending: maxPending,
      showDeleted: showDeleted,
    );

    final filterSuffix = pendingFilter == true
        ? '_Pending'
        : pendingFilter == false
        ? '_Paid'
        : '';

    await UnifiedPrintHelper.printPdfBytes(
      pdfBytes: pdfBytes,
      filename:
          'Supplier_Report${filterSuffix}_${_formatDate(DateTime.now())}.pdf',
    );
  }

  /// Save supplier list PDF to file
  Future<File?> saveSupplierListPdf(
    List<Supplier> suppliers, {
    String? searchKeyword,
    String? companyName,
    bool? pendingFilter,
    double? minCredit,
    double? maxCredit,
    double? minPending,
    double? maxPending,
    bool showDeleted = false,
  }) async {
    logger.info(
      'SupplierExport',
      'Saving Supplier Report PDF',
      context: {'count': suppliers.length},
    );
    final pdfBytes = await _generatePdf(
      suppliers,
      searchKeyword: searchKeyword,
      companyName: companyName,
      pendingFilter: pendingFilter,
      minCredit: minCredit,
      maxCredit: maxCredit,
      minPending: minPending,
      maxPending: maxPending,
      showDeleted: showDeleted,
    );

    final filterSuffix = pendingFilter == true
        ? '_Pending'
        : pendingFilter == false
        ? '_Paid'
        : '';

    return await UnifiedPrintHelper.savePdfBytes(
      pdfBytes: pdfBytes,
      suggestedName:
          'Supplier_Report${filterSuffix}_${_formatDate(DateTime.now())}.pdf',
      dialogTitle: 'Save Supplier Report',
    );
  }

  /// Export supplier list to beautiful PDF with multi-page support and filter metadata
  Future<void> exportToPDF(
    List<Supplier> suppliers, {
    String? searchKeyword,
    String? companyName,
    bool? pendingFilter, // null=all, true=pending, false=paid
    double? minCredit,
    double? maxCredit,
    double? minPending,
    double? maxPending,
    bool showDeleted = false,
  }) async {
    logger.info(
      'SupplierExport',
      'Exporting Supplier Report',
      context: {'count': suppliers.length},
    );
    final pdfBytes = await _generatePdf(
      suppliers,
      searchKeyword: searchKeyword,
      companyName: companyName,
      pendingFilter: pendingFilter,
      minCredit: minCredit,
      maxCredit: maxCredit,
      minPending: minPending,
      maxPending: maxPending,
      showDeleted: showDeleted,
    );

    final filterSuffix = pendingFilter == true
        ? '_Pending'
        : pendingFilter == false
        ? '_Paid'
        : '';

    await UnifiedPrintHelper.sharePdfBytes(
      pdfBytes: pdfBytes,
      filename:
          'Supplier_Report${filterSuffix}_${_formatDate(DateTime.now())}.pdf',
    );

    logger.info(
      'SupplierExport',
      'Supplier Report PDF exported successfully',
      context: {'count': suppliers.length},
    );
  }

  Future<Uint8List> _generatePdf(
    List<Supplier> suppliers, {
    String? searchKeyword,
    String? companyName,
    bool? pendingFilter,
    double? minCredit,
    double? maxCredit,
    double? minPending,
    double? maxPending,
    bool showDeleted = false,
  }) async {
    if (suppliers.isEmpty) {
      return Uint8List(0);
    }

    final pdf = pw.Document();
    final now = DateTime.now();

    // Load fonts
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    // Build filter summary
    final List<String> activeFilters = [];
    if (searchKeyword != null && searchKeyword.isNotEmpty) {
      activeFilters.add('Search: "$searchKeyword"');
    }
    if (companyName != null && companyName != 'All Companies') {
      activeFilters.add('Company: $companyName');
    }
    if (pendingFilter != null) {
      activeFilters.add(
        'Payment Status: ${pendingFilter ? "Pending Only" : "Paid Only"}',
      );
    }
    if (minCredit != null || maxCredit != null) {
      final min = minCredit?.toStringAsFixed(0) ?? '0';
      final max = maxCredit?.toStringAsFixed(0) ?? '∞';
      activeFilters.add('Credit Limit: Rs $min - Rs $max');
    }
    if (minPending != null || maxPending != null) {
      final min = minPending?.toStringAsFixed(0) ?? '0';
      final max = maxPending?.toStringAsFixed(0) ?? '∞';
      activeFilters.add('Pending Amount: Rs $min - Rs $max');
    }
    if (showDeleted) {
      activeFilters.add('Including Deleted Records');
    }

    // Calculate summary statistics
    final totalPending = suppliers.fold<double>(
      0,
      (sum, s) => sum + s.pendingAmount,
    );
    final avgPending = totalPending / suppliers.length;
    final suppliersWithPending = suppliers
        .where((s) => s.pendingAmount > 0)
        .length;

    // Group suppliers into pages (30 per page for readability)
    const itemsPerPage = 30;
    final totalPages = (suppliers.length / itemsPerPage).ceil();

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage > suppliers.length)
          ? suppliers.length
          : startIndex + itemsPerPage;
      final pageSuppliers = suppliers.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(
                  colors: [PdfColors.purple700, PdfColors.purple900],
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
                        activeFilters.isEmpty
                            ? 'Supplier Report'
                            : 'Filtered Supplier Report',
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
                        'Total Suppliers: ${suppliers.length}',
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

            // Active Filters Section (only on first page)
            if (pageIndex == 0 && activeFilters.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.purple50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.purple200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Active Filters',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.purple900,
                        font: boldFont,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    ...activeFilters.map(
                      (filter) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: 4,
                              height: 4,
                              decoration: const pw.BoxDecoration(
                                color: PdfColors.purple700,
                                shape: pw.BoxShape.circle,
                              ),
                            ),
                            pw.SizedBox(width: 6),
                            pw.Text(
                              filter,
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.purple900,
                                font: regularFont,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // Summary Cards (Only on first page)
            if (pageIndex == 0) ...[
              pw.Row(
                children: [
                  _buildSummaryCard(
                    'Total Pending',
                    'Rs ${totalPending.toStringAsFixed(2)}',
                    PdfColors.deepOrange700,
                    regularFont,
                    boldFont,
                  ),
                  pw.SizedBox(width: 12),
                  _buildSummaryCard(
                    'Average Pending',
                    'Rs ${avgPending.toStringAsFixed(2)}',
                    PdfColors.purple700,
                    regularFont,
                    boldFont,
                  ),
                  pw.SizedBox(width: 12),
                  _buildSummaryCard(
                    'With Pending',
                    '$suppliersWithPending suppliers',
                    PdfColors.red700,
                    regularFont,
                    boldFont,
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
            ],

            // Data Table
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.8), // #
                1: const pw.FlexColumnWidth(3), // Name
                2: const pw.FlexColumnWidth(2.5), // Phone
                3: const pw.FlexColumnWidth(3), // Company
                4: const pw.FlexColumnWidth(2), // Pending
                5: const pw.FlexColumnWidth(2), // Credit Limit
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.purple50),
                  children: [
                    _buildHeaderCell('#', boldFont),
                    _buildHeaderCell('Supplier Name', boldFont),
                    _buildHeaderCell('Phone', boldFont),
                    _buildHeaderCell('Company', boldFont),
                    _buildHeaderCell('Pending (Rs)', boldFont),
                    _buildHeaderCell('Credit Limit', boldFont),
                  ],
                ),
                // Data Rows
                ...pageSuppliers.asMap().entries.map((entry) {
                  final index = startIndex + entry.key;
                  final supplier = entry.value;
                  final isEven = index % 2 == 0;
                  final hasPending = supplier.pendingAmount > 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: hasPending
                          ? PdfColors.deepOrange50
                          : (isEven ? PdfColors.white : PdfColors.grey50),
                    ),
                    children: [
                      _buildDataCell((index + 1).toString(), font: regularFont),
                      _buildDataCell(
                        supplier.name,
                        bold: hasPending,
                        font: hasPending ? boldFont : regularFont,
                      ),
                      _buildDataCell(supplier.phone ?? '-', font: regularFont),
                      _buildDataCell(
                        supplier.companyId.toString(),
                        font: regularFont,
                      ),
                      _buildDataCell(
                        supplier.pendingAmount.toStringAsFixed(2),
                        bold: hasPending,
                        color: hasPending ? PdfColors.deepOrange900 : null,
                        font: hasPending ? boldFont : regularFont,
                      ),
                      _buildDataCell(
                        supplier.creditLimit.toStringAsFixed(2),
                        font: regularFont,
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 20),

            // Footer (Only on last page)
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
                          'Total Records: ${suppliers.length}',
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
          color: PdfColors.purple900,
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

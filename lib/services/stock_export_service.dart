import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import 'package:share_plus/share_plus.dart';
import '../models/stock_report_model.dart';
import '../utils/unified_print_helper.dart';
import '../utils/pdf_font_helper.dart';
import '../services/logger_service.dart';

class StockExportService {
  /// Print stock report directly
  Future<void> printStockReport(
    List<StockReport> reports, {
    bool includePrice = true,
    bool showExpiry = false,
    bool detailedView = false,
  }) async {
    logger.info(
      'StockExport',
      'Printing Stock Report',
      context: {'items': reports.length},
    );
    final pdfBytes = await _generatePdf(
      reports,
      includePrice: includePrice,
      showExpiry: showExpiry,
      detailedView: detailedView,
    );

    await UnifiedPrintHelper.printPdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Stock_Report_${_formatDate(DateTime.now())}.pdf',
    );
  }

  /// Save stock report PDF to file
  Future<File?> saveStockReportPdf(
    List<StockReport> reports, {
    bool includePrice = true,
    bool showExpiry = false,
    bool detailedView = false,
  }) async {
    final pdfBytes = await _generatePdf(
      reports,
      includePrice: includePrice,
      showExpiry: showExpiry,
      detailedView: detailedView,
    );

    return await UnifiedPrintHelper.savePdfBytes(
      pdfBytes: pdfBytes,
      suggestedName: 'Stock_Report_${_formatDate(DateTime.now())}.pdf',
      dialogTitle: 'Save Stock Report',
    );
  }

  /// Export stock report to PDF with beautiful modern design
  Future<void> exportToPDF(
    List<StockReport> reports, {
    bool includePrice = true,
    bool showExpiry = false,
    bool detailedView = false,
  }) async {
    final pdfBytes = await _generatePdf(
      reports,
      includePrice: includePrice,
      showExpiry: showExpiry,
      detailedView: detailedView,
    );

    await UnifiedPrintHelper.sharePdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Stock_Report_${_formatDate(DateTime.now())}.pdf',
    );

    logger.info(
      'StockExport',
      'Stock Report PDF exported successfully',
      context: {'count': reports.length},
    );
  }

  Future<Uint8List> _generatePdf(
    List<StockReport> reports, {
    required bool includePrice,
    required bool showExpiry,
    required bool detailedView,
  }) async {
    if (reports.isEmpty) {
      return Uint8List(0);
    }

    final pdf = pw.Document();
    final now = DateTime.now();

    // Load fonts
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    // ═══════════════════════════════════════
    // 📊 CALCULATE SUMMARY STATISTICS
    // ═══════════════════════════════════════
    final totalCost = reports.fold<double>(
      0,
      (sum, r) => sum + (r.costPrice * r.remainingQty),
    );
    final totalSell = reports.fold<double>(
      0,
      (sum, r) => sum + r.totalSellValue,
    );
    final totalProfit = reports.fold<double>(
      0,
      (sum, r) => sum + r.profitValue,
    );
    final lowStockCount = reports
        .where(
          (r) =>
              r.reorderLevel != null &&
              r.reorderLevel! > 0 &&
              r.remainingQty <= r.reorderLevel!,
        )
        .length;

    // ═══════════════════════════════════════
    // 🧱 DYNAMIC COLUMN SETUP
    // ═══════════════════════════════════════
    final columns = <String>[
      '#',
      'Product',
      'Batch',
      'Purchased',
      'Sold',
      'Remaining',
      if (showExpiry) 'Supplier',
      if (showExpiry) 'Company',
      if (showExpiry) 'Expiry',
      if (includePrice) 'Cost',
      if (includePrice) 'Sell',
      if (detailedView) 'Profit/U',
      if (detailedView) 'Total Profit',
      if (includePrice) 'Total Value',
      if (detailedView) 'Reorder',
    ];

    // ═══════════════════════════════════════
    // 📄 MULTI-PAGE SUPPORT (20 items per page)
    // ═══════════════════════════════════════
    const itemsPerPage = 20;
    final totalPages = (reports.length / itemsPerPage).ceil();

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage > reports.length)
          ? reports.length
          : startIndex + itemsPerPage;
      final pageReports = reports.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            // ═══════════════════════════════════════
            // 🎨 BEAUTIFUL HEADER
            // ═══════════════════════════════════════
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
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
                        'Stock Report',
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
                        'Total Items: ${reports.length}',
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

            // ═══════════════════════════════════════
            // 📊 SUMMARY CARDS (Only on first page)
            // ═══════════════════════════════════════
            if (pageIndex == 0) ...[
              pw.Row(
                children: [
                  _buildSummaryCard(
                    'Total Cost Value',
                    'Rs ${totalCost.toStringAsFixed(2)}',
                    PdfColors.blue700,
                    regularFont,
                    boldFont,
                  ),
                  pw.SizedBox(width: 10),
                  _buildSummaryCard(
                    'Total Sell Value',
                    'Rs ${totalSell.toStringAsFixed(2)}',
                    PdfColors.green700,
                    regularFont,
                    boldFont,
                  ),
                  pw.SizedBox(width: 10),
                  _buildSummaryCard(
                    'Total Profit',
                    'Rs ${totalProfit.toStringAsFixed(2)}',
                    PdfColors.orange700,
                    regularFont,
                    boldFont,
                  ),
                  pw.SizedBox(width: 10),
                  _buildSummaryCard(
                    'Low Stock Items',
                    '$lowStockCount items',
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
              columnWidths: _buildColumnWidths(columns.length),
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                  children: columns
                      .map((col) => _buildHeaderCell(col, boldFont))
                      .toList(),
                ),
                // Data Rows
                ...pageReports.asMap().entries.map((entry) {
                  final index = startIndex + entry.key;
                  final r = entry.value;
                  final isEven = index % 2 == 0;
                  final isLowStock =
                      r.reorderLevel != null &&
                      r.reorderLevel! > 0 &&
                      r.remainingQty <= r.reorderLevel!;

                  final cells = <pw.Widget>[
                    _buildDataCell(
                      (index + 1).toString(),
                      fontSize: 8,
                      font: regularFont,
                    ),
                    _buildDataCell(
                      r.productName,
                      bold: isLowStock,
                      fontSize: 8,
                      font: isLowStock ? boldFont : regularFont,
                    ),
                    _buildDataCell(
                      r.batchNo ?? '-',
                      fontSize: 8,
                      font: regularFont,
                    ),
                    _buildDataCell(
                      r.purchasedQty.toString(),
                      fontSize: 8,
                      font: regularFont,
                    ),
                    _buildDataCell(
                      r.soldQty.toString(),
                      fontSize: 8,
                      font: regularFont,
                    ),
                    _buildDataCell(
                      r.remainingQty.toString(),
                      bold: isLowStock,
                      color: isLowStock ? PdfColors.red900 : null,
                      fontSize: 8,
                      font: isLowStock ? boldFont : regularFont,
                    ),
                    if (showExpiry)
                      _buildDataCell(
                        r.supplierName ?? '-',
                        fontSize: 8,
                        font: regularFont,
                      ),
                    if (showExpiry)
                      _buildDataCell(
                        r.companyName ?? '-',
                        fontSize: 8,
                        font: regularFont,
                      ),
                    if (showExpiry)
                      _buildDataCell(
                        r.expiryDate != null
                            ? r.expiryDate!
                                  .toLocal()
                                  .toString()
                                  .split(' ')
                                  .first
                            : '-',
                        fontSize: 8,
                        font: regularFont,
                      ),
                    if (includePrice)
                      _buildDataCell(
                        r.costPrice.toStringAsFixed(2),
                        fontSize: 8,
                        font: regularFont,
                      ),
                    if (includePrice)
                      _buildDataCell(
                        r.sellPrice.toStringAsFixed(2),
                        fontSize: 8,
                        font: regularFont,
                      ),
                    if (detailedView)
                      _buildDataCell(
                        r.profitPerUnit.toStringAsFixed(2),
                        color: r.profitPerUnit > 0
                            ? PdfColors.green900
                            : PdfColors.red900,
                        fontSize: 8,
                        font: regularFont,
                      ),
                    if (detailedView)
                      _buildDataCell(
                        r.profitValue.toStringAsFixed(2),
                        fontSize: 8,
                        font: regularFont,
                      ),
                    if (includePrice)
                      _buildDataCell(
                        r.totalSellValue.toStringAsFixed(2),
                        fontSize: 8,
                        font: regularFont,
                      ),
                    if (detailedView)
                      _buildDataCell(
                        r.reorderLevel?.toString() ?? '-',
                        fontSize: 8,
                        font: regularFont,
                      ),
                  ];

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isLowStock
                          ? PdfColors.red50
                          : (isEven ? PdfColors.white : PdfColors.grey50),
                    ),
                    children: cells,
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
                          'Total Items: ${reports.length} | Total Stock Value: Rs ${totalSell.toStringAsFixed(2)} | Low Stock: $lowStockCount',
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

  Map<int, pw.TableColumnWidth> _buildColumnWidths(int columnCount) {
    // Dynamic column widths based on number of columns
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(0.5), // #
      1: const pw.FlexColumnWidth(2.5), // Product
      2: const pw.FlexColumnWidth(1.5), // Batch
    };

    // All other columns get equal width
    for (int i = 3; i < columnCount; i++) {
      widths[i] = const pw.FlexColumnWidth(1.2);
    }

    return widths;
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

  Future<void> exportToExcel(
    List<StockReport> reports, {
    bool includePrice = true,
    bool showExpiry = false,
    bool detailedView = false,
  }) async {
    if (reports.isEmpty) {
      logger.warning('StockExport', 'No data to export to Excel');
      return;
    }

    // Create Excel workbook
    final excel = Excel.createExcel();
    final sheet = excel['Stock Report'];

    // Define headers
    final headers = <String>[
      'Product',
      'Purchased',
      'Sold',
      'Remaining',
      if (showExpiry) 'Supplier',
      if (showExpiry) 'Expiry',
      if (includePrice) 'Cost',
      if (includePrice) 'Sell',
      if (detailedView) 'Profit/Unit',
      if (detailedView) 'Total Profit',
      if (includePrice) 'Total Value',
      if (detailedView) 'Reorder Level',
    ];

    // Add header row
    sheet.appendRow(headers);

    // Add data rows
    for (final r in reports) {
      final row = [
        r.productName,
        r.purchasedQty,
        r.soldQty,
        r.remainingQty,
        if (showExpiry) (r.supplierName ?? '-'),
        if (showExpiry)
          (r.expiryDate != null
              ? "${r.expiryDate!.toLocal()}".split(' ')[0]
              : '-'),
        if (includePrice) r.costPrice,
        if (includePrice) r.sellPrice,
        if (detailedView) r.profitPerUnit,
        if (detailedView) r.profitValue,
        if (includePrice) r.totalSellValue,
        if (detailedView) (r.reorderLevel ?? '-'),
      ];

      sheet.appendRow(row);
    }

    // Optional: Add a summary row at the end
    final totalQty = reports.fold<int>(0, (sum, r) => sum + r.remainingQty);
    final totalValue = includePrice
        ? reports.fold<double>(0, (sum, r) => sum + r.totalSellValue)
        : 0.0;

    sheet.appendRow([]);
    sheet.appendRow([
      'TOTALS',
      '',
      '',
      totalQty,
      if (showExpiry) '',
      if (showExpiry) '',
      if (includePrice) '',
      if (includePrice) '',
      if (detailedView) '',
      if (detailedView) '',
      if (includePrice) totalValue.toStringAsFixed(2),
      if (detailedView) '',
    ]);

    // Save file
    final output = await getTemporaryDirectory();
    final fileName =
        'stock_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final filePath = '${output.path}/$fileName';
    final fileBytes = excel.encode();
    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    logger.info(
      'StockExport',
      'Excel exported successfully',
      context: {'path': filePath},
    );

    // Platform-aware: Android/iOS uses share, Desktop opens file
    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile: Share the file
      await Share.shareXFiles([XFile(filePath)], subject: fileName);
    } else {
      // Desktop: Open file directly
      await OpenFile.open(filePath);
    }
  }

  /// Print directly to POS (placeholder for future)
  Future<void> printPOS(List<StockReport> reports) async {
    logger.info(
      'StockExport',
      'Printing to POS (Placeholder)',
      context: {'items': reports.length},
    );
  }
}

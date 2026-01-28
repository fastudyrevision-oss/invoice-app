import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../models/expense.dart';
import '../utils/unified_print_helper.dart';
import '../utils/pdf_font_helper.dart';
import '../services/logger_service.dart';

class ExpenseExportService {
  /// Print expense report directly
  Future<void> printExpenseReport(List<Expense> expenses) async {
    logger.info(
      'ExpenseExport',
      'Printing Expense Report',
      context: {'count': expenses.length},
    );
    final pdfBytes = await _generatePdf(expenses);

    await UnifiedPrintHelper.printPdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Expense_Report_${_formatDateFile(DateTime.now())}.pdf',
    );
  }

  /// Save expense report PDF to file
  Future<File?> saveExpenseReportPdf(List<Expense> expenses) async {
    logger.info(
      'ExpenseExport',
      'Saving Expense Report PDF',
      context: {'count': expenses.length},
    );
    final pdfBytes = await _generatePdf(expenses);

    return await UnifiedPrintHelper.savePdfBytes(
      pdfBytes: pdfBytes,
      suggestedName: 'Expense_Report_${_formatDateFile(DateTime.now())}.pdf',
      dialogTitle: 'Save Expense Report',
    );
  }

  /// Export expense list to beautiful PDF with multi-page support
  Future<void> exportToPDF(List<Expense> expenses) async {
    logger.info(
      'ExpenseExport',
      'Exporting Expense Report',
      context: {'count': expenses.length},
    );
    final pdfBytes = await _generatePdf(expenses);

    await UnifiedPrintHelper.sharePdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Expense_Report_${_formatDateFile(DateTime.now())}.pdf',
    );

    logger.info(
      'ExpenseExport',
      'Expense Report PDF exported successfully',
      context: {'count': expenses.length},
    );
  }

  Future<Uint8List> _generatePdf(List<Expense> expenses) async {
    if (expenses.isEmpty) {
      return Uint8List(0);
    }

    final pdf = pw.Document();
    final now = DateTime.now();

    // Load fonts
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    // Calculate summary statistics
    final totalAmount = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final avgAmount = totalAmount / expenses.length;

    // Group by category
    final categoryTotals = <String, double>{};
    for (final expense in expenses) {
      final category = expense.category;
      categoryTotals[category] =
          (categoryTotals[category] ?? 0) + expense.amount;
    }

    // Group expenses into pages (30 per page)
    const itemsPerPage = 30;
    final totalPages = (expenses.length / itemsPerPage).ceil();

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage > expenses.length)
          ? expenses.length
          : startIndex + itemsPerPage;
      final pageExpenses = expenses.sublist(startIndex, endIndex);

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
                        'Expense Report',
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
                        'Total Expenses: ${expenses.length}',
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
                    'Total Amount',
                    'Rs ${totalAmount.toStringAsFixed(2)}',
                    PdfColors.red700,
                    regularFont,
                    boldFont,
                  ),
                  pw.SizedBox(width: 12),
                  _buildSummaryCard(
                    'Average Expense',
                    'Rs ${avgAmount.toStringAsFixed(2)}',
                    PdfColors.orange700,
                    regularFont,
                    boldFont,
                  ),
                  pw.SizedBox(width: 12),
                  _buildSummaryCard(
                    'Categories',
                    '${categoryTotals.length} types',
                    PdfColors.blue700,
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
                2: const pw.FlexColumnWidth(4), // Description
                3: const pw.FlexColumnWidth(2), // Category
                4: const pw.FlexColumnWidth(2), // Amount
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.red50),
                  children: [
                    _buildHeaderCell('#', boldFont),
                    _buildHeaderCell('Date', boldFont),
                    _buildHeaderCell('Description', boldFont),
                    _buildHeaderCell('Category', boldFont),
                    _buildHeaderCell('Amount (Rs)', boldFont),
                  ],
                ),
                // Data Rows
                ...pageExpenses.asMap().entries.map((entry) {
                  final index = startIndex + entry.key;
                  final expense = entry.value;
                  final isEven = index % 2 == 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: [
                      _buildDataCell((index + 1).toString(), font: regularFont),
                      _buildDataCell(
                        _formatDate(DateTime.parse(expense.date)),
                        font: regularFont,
                      ),
                      _buildDataCell(expense.description, font: regularFont),
                      _buildDataCell(expense.category, font: regularFont),
                      _buildDataCell(
                        expense.amount.toStringAsFixed(2),
                        bold: true,
                        color: PdfColors.red900,
                        font: boldFont,
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
              // Category Breakdown
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                  color: PdfColors.grey50,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Category Breakdown',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        font: boldFont,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    ...categoryTotals.entries.map((entry) {
                      final percentage = (entry.value / totalAmount) * 100;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              '${entry.key}:',
                              style: pw.TextStyle(
                                fontSize: 10,
                                font: regularFont,
                              ),
                            ),
                            pw.Text(
                              'Rs ${entry.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                font: boldFont,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
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
                          'Total Records: ${expenses.length}',
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
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatDateFile(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

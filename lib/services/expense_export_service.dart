import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/expense.dart';
import '../utils/pdf_font_helper.dart';

class ExpenseExportService {
  /// Export expense list to beautiful PDF with multi-page support
  Future<void> exportToPDF(List<Expense> expenses) async {
    if (expenses.isEmpty) {
      print('⚠️ No expenses to export.');
      return;
    }

    final pdf = pw.Document();
    final now = DateTime.now();

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
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Page ${pageIndex + 1} of $totalPages',
                        style: const pw.TextStyle(
                          fontSize: 12,
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
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Total Expenses: ${expenses.length}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
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
                  ),
                  pw.SizedBox(width: 12),
                  _buildSummaryCard(
                    'Average Expense',
                    'Rs ${avgAmount.toStringAsFixed(2)}',
                    PdfColors.orange700,
                  ),
                  pw.SizedBox(width: 12),
                  _buildSummaryCard(
                    'Categories',
                    '${categoryTotals.length} types',
                    PdfColors.blue700,
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
                    _buildHeaderCell('#'),
                    _buildHeaderCell('Date'),
                    _buildHeaderCell('Description'),
                    _buildHeaderCell('Category'),
                    _buildHeaderCell('Amount (Rs)'),
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
                      _buildDataCell((index + 1).toString()),
                      _buildDataCell(_formatDate(DateTime.parse(expense.date))),
                      _buildDataCell(expense.description),
                      _buildDataCell(expense.category),
                      _buildDataCell(
                        expense.amount.toStringAsFixed(2),
                        bold: true,
                        color: PdfColors.red900,
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
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              'Rs ${entry.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
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
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Total Records: ${expenses.length}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          'Total Amount: Rs ${totalAmount.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Prepared via میاں ٹریڈرز',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _formatDateTime(now),
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
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

    // ═══════════════════════════════════════
    // 🖨️ SHARE PDF
    // ═══════════════════════════════════════
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Expense_Report_${_formatDateFile(now)}.pdf',
    );

    print(
      '✅ Expense Report PDF exported successfully (${expenses.length} records, $totalPages pages).',
    );
  }

  // ═══════════════════════════════════════
  // 🎨 HELPER WIDGETS
  // ═══════════════════════════════════════

  pw.Widget _buildSummaryCard(String label, String value, PdfColor color) {
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
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
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
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.red900,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildDataCell(String text, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
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
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatDateFile(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

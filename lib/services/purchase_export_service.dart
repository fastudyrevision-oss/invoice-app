import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/purchase.dart'; // Assuming this is the model, will verify import

class PurchaseExportService {
  /// Export purchase list to beautiful PDF with multi-page support
  Future<void> exportToPDF(List<Purchase> purchases) async {
    if (purchases.isEmpty) {
      print('⚠️ No purchases to export.');
      return;
    }

    final pdf = pw.Document();
    final now = DateTime.now();

    // Calculate summary statistics
    final totalAmount = purchases.fold<double>(
      0,
      (sum, p) => sum + (p.total ?? 0),
    );
    final totalPaid = purchases.fold<double>(
      0,
      (sum, p) => sum + (p.paid ?? 0),
    );
    final totalPending = purchases.fold<double>(
      0,
      (sum, p) => sum + (p.pending ?? 0),
    );

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
                        'Total Records: ${purchases.length}',
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
                    'Total Purchases',
                    'Rs ${totalAmount.toStringAsFixed(2)}',
                    PdfColors.teal700,
                  ),
                  pw.SizedBox(width: 12),
                  _buildSummaryCard(
                    'Total Paid',
                    'Rs ${totalPaid.toStringAsFixed(2)}',
                    PdfColors.green700,
                  ),
                  pw.SizedBox(width: 12),
                  _buildSummaryCard(
                    'Total Pending',
                    'Rs ${totalPending.toStringAsFixed(2)}',
                    PdfColors.orange700,
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
                    _buildHeaderCell('#'),
                    _buildHeaderCell('Date'),
                    _buildHeaderCell('Invoice #'),
                    _buildHeaderCell('Supplier'),
                    _buildHeaderCell('Total'),
                    _buildHeaderCell('Paid'),
                    _buildHeaderCell('Pending'),
                  ],
                ),
                // Data Rows
                ...pagePurchases.asMap().entries.map((entry) {
                  final index = startIndex + entry.key;
                  final purchase = entry.value;
                  final isEven = index % 2 == 0;
                  final hasPending = (purchase.pending ?? 0) > 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: [
                      _buildDataCell((index + 1).toString()),
                      _buildDataCell(
                        _formatDate(DateTime.parse(purchase.createdAt)),
                      ),
                      _buildDataCell(purchase.invoiceNo ?? '-'),
                      _buildDataCell(purchase.supplierId ?? '-'),
                      _buildDataCell(
                        (purchase.total ?? 0).toStringAsFixed(2),
                        bold: true,
                      ),
                      _buildDataCell(
                        (purchase.paid ?? 0).toStringAsFixed(2),
                        color: PdfColors.green700,
                      ),
                      _buildDataCell(
                        (purchase.pending ?? 0).toStringAsFixed(2),
                        bold: hasPending,
                        color: hasPending ? PdfColors.orange700 : null,
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
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Total Records: ${purchases.length}',
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
                          'Prepared via Invoice App',
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
      filename: 'Purchase_Report_${_formatDateFile(now)}.pdf',
    );

    print(
      '✅ Purchase Report PDF exported successfully (${purchases.length} records, $totalPages pages).',
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
          color: PdfColors.teal900,
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

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatDateFile(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

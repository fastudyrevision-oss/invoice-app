import '../dao/stock_report_dao.dart';
import '../models/stock_report_model.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class StockExportService {
  final StockDao _dao = StockDao();

  /// Export stock report to PDF with dynamic columns & multipage support
  Future<void> exportToPDF(
    List<StockReport> reports, {
    bool includePrice = true,
    bool showExpiry = false,
    bool showSupplier = false,
  }) async {
    if (reports.isEmpty) {
      print('No data to export');
      return;
    }

    final pdf = pw.Document();
    final date = DateTime.now();

    // --- Dynamic headers ---
    final headers = <String>['Product', 'Purchased', 'Sold', 'Remaining'];

    if (includePrice) {
      headers.addAll(['Cost', 'Value']);
    }
    if (showSupplier) headers.add('Supplier');
    if (showExpiry) headers.add('Expiry');

    // --- Dynamic data ---
    final data = reports.map((r) {
      final row = <String>[
        r.productName,
        r.purchasedQty.toString(),
        r.soldQty.toString(),
        r.remainingQty.toString(),
      ];

      if (includePrice) {
        row.add(r.costPrice.toStringAsFixed(2));
        row.add(r.totalValue.toStringAsFixed(2));
      }
      if (showSupplier) {
        row.add(r.supplierName ?? '-');
      }
      if (showExpiry) {
        row.add(r.expiryDate?.toString().split(' ').first ?? '-');
      }

      return row;
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          // --- HEADER ---
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Stock Report',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('Generated on: ${date.toLocal()}'),
              pw.SizedBox(height: 20),
            ],
          ),

          // --- TABLE ---
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey700),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerHeight: 25,
            cellHeight: 20,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
            },
            headers: headers,
            data: data,
          ),

          pw.SizedBox(height: 20),

          // --- SUMMARY ---
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Total items: ${reports.length}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // --- PREVIEW OR SAVE PDF ---
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );

    print('PDF exported successfully!');
  }

  /// Export stock report to Excel
  Future<void> exportToExcel(List<StockReport> reports) async {
    // TODO: Implement Excel export logic
    print('Exporting ${reports.length} items to Excel...');
  }

  /// Print via POS
  Future<void> printPOS(List<StockReport> reports) async {
    // TODO: Implement POS printing logic
    print('Printing ${reports.length} items to POS printer...');
  }
}

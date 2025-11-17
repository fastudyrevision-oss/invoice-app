import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:printing/printing.dart';
import '../models/stock_report_model.dart';

class StockExportService {
  /// Export stock report to PDF with full dynamic columns.
  Future<void> exportToPDF(
    List<StockReport> reports, {
    bool includePrice = true,
    bool showExpiry = false,
    bool detailedView = false,
  }) async {
    if (reports.isEmpty) {
      print('⚠️ No data to export.');
      return;
    }

    final pdf = pw.Document();
    final now = DateTime.now();

    // ─────────────────────────────
    // 🧱 1. Dynamic Table Headers
    // ─────────────────────────────
    final headers = <String>[
      'Product',
      'Batch',
      'Purchased',
      'Sold',
      'Remaining',
    ];

    if (showExpiry) {
      headers.addAll(['Supplier','Company', 'Expiry']);
    }

    if (includePrice) {
      headers.addAll(['Cost', 'Sell']);
    }

    if (detailedView) {
      headers.addAll([
        'Profit/Unit',
        'Total Profit',
        'Reorder',
      ]);
    }

    if (includePrice) {
      headers.add('Total Value');
    }

    // ─────────────────────────────
    // 📊 2. Dynamic Table Data
    // ─────────────────────────────
    final data = reports.map((r) {
      final row = <String>[
        r.productName,
        r.batchNo ?? '-',
        r.purchasedQty.toString(),
        r.soldQty.toString(),
        r.remainingQty.toString(),
      ];

      if (showExpiry) {
        row.add(r.supplierName ?? '-');
        row.add(r.companyName ?? '-');
        row.add(r.expiryDate != null
            ? r.expiryDate!.toLocal().toString().split(' ').first
            : '-');
      }

      if (includePrice) {
        row.add(r.costPrice.toStringAsFixed(2));
        row.add(r.sellPrice.toStringAsFixed(2));
      }

      if (detailedView) {
        row.add(r.profitPerUnit.toStringAsFixed(2));
        row.add(r.profitValue.toStringAsFixed(2));
        row.add(r.reorderLevel?.toString() ?? '-');
      }

      if (includePrice) {
        row.add(r.totalSellValue.toStringAsFixed(2));
      }

      return row;
    }).toList();

    // ─────────────────────────────
    // 🧾 3. Page & Layout Setup
    // ─────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          // HEADER
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '📦 Stock Report',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Generated: ${now.toLocal().toString().split(".").first}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          ),

          // TABLE
          pw.Table.fromTextArray(
            headers: headers,
            data: data,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey700),
            cellAlignment: pw.Alignment.center,
            headerAlignment: pw.Alignment.center,
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
            },
          ),

          pw.SizedBox(height: 20),

          // SUMMARY FOOTER
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(width: 0.3, color: PdfColors.grey700)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Total Items: ${reports.length}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Prepared via Invoice App',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // ─────────────────────────────
    // 🖨️ 4. Print or Preview
    // ─────────────────────────────
        final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Stock_Report_${DateTime.now().toIso8601String().split('T').first}.pdf',
    );

    print('✅ Stock Report PDF exported successfully.');
  }

   Future<void> exportToExcel(
    List<StockReport> reports, {
    bool includePrice = true,
    bool showExpiry = false,
    bool detailedView = false,
  }) async {
    if (reports.isEmpty) {
      print("⚠️ No data to export!");
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
    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    print("✅ Excel exported to $filePath");
    await OpenFile.open(filePath);
  }


  /// Print directly to POS (placeholder for future)
  Future<void> printPOS(List<StockReport> reports) async {
    print('🖨️ Printing ${reports.length} items to POS printer...');
  }
}

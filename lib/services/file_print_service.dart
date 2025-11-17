import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/stock_report_model.dart';
import 'package:open_file/open_file.dart';

class FilePrintService {
  Future<void> printStockReport(
    List<StockReport> report, {
    bool includePrice = true,
    bool showExpiry = false,
    bool detailedView = false,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Stock Report',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          _buildSummarySection(report, includePrice),
          pw.SizedBox(height: 10),
          _buildStockTable(report, includePrice, showExpiry, detailedView),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/stock_report.pdf');
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  // ------------------- TABLE -------------------
  pw.Widget _buildStockTable(
    List<StockReport> report,
    bool includePrice,
    bool showExpiry,
    bool detailedView,
  ) {
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

    final data = report.map((r) {
      return [
        r.productName,
        r.purchasedQty.toString(),
        r.soldQty.toString(),
        r.remainingQty.toString(),
        if (showExpiry) (r.supplierName ?? '-'),
        if (showExpiry)
          (r.expiryDate != null
              ? "${r.expiryDate!.toLocal()}".split(' ')[0]
              : '-'),
        if (includePrice) r.costPrice.toStringAsFixed(2),
        if (includePrice) r.sellPrice.toStringAsFixed(2),
        if (detailedView) r.profitPerUnit.toStringAsFixed(2),
        if (detailedView) r.profitValue.toStringAsFixed(2),
        if (includePrice) r.totalSellValue.toStringAsFixed(2),
        if (detailedView) (r.reorderLevel?.toString() ?? '-'),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(width: 0.2, color: PdfColors.grey700),
      cellAlignment: pw.Alignment.center,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 10,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
      headerAlignments: {
        for (var i = 0; i < headers.length; i++) i: pw.Alignment.center,
      },
      cellAlignments: {
        for (var i = 0; i < headers.length; i++) i: pw.Alignment.center,
      },
      cellHeight: 25,
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(1),
        6: const pw.FlexColumnWidth(1),
        7: const pw.FlexColumnWidth(1),
        8: const pw.FlexColumnWidth(1),
      },
    );
  }

  // ------------------- SUMMARY -------------------
  pw.Widget _buildSummarySection(List<StockReport> report, bool includePrice) {
    if (report.isEmpty) {
      return pw.Text('No stock data available');
    }

    final totalItems = report.length;
    final totalQty =
        report.fold<int>(0, (sum, item) => sum + item.remainingQty);
    final totalValue = includePrice
        ? report.fold<double>(
            0, (sum, item) => sum + item.totalSellValue)
        : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary',
            style:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 5),
          pw.Text('Total Products: $totalItems'),
          pw.Text('Total Quantity Remaining: $totalQty'),
          if (includePrice)
            pw.Text('Total Stock Value: ${totalValue.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/purchase.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Generate a PDF report with a chart for purchases
Future<File?> generatePurchasePdfWithChart({
  required String title,
  required Uint8List chartBytes,
  required double totalAmount,
  required double avgPurchase,
}) async {
  final pdf = pw.Document();
  final regularFont = await PdfGoogleFonts.notoSansRegular();
  final boldFont = await PdfGoogleFonts.notoSansBold();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 24)),
            pw.SizedBox(height: 16),
            pw.Text(
              'Purchase Report Summary',
              style: pw.TextStyle(font: regularFont, fontSize: 16),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Total Purchase Amount: Rs ${totalAmount.toStringAsFixed(2)}',
              style: pw.TextStyle(font: regularFont, fontSize: 14),
            ),
            pw.Text(
              'Average Purchase: Rs ${avgPurchase.toStringAsFixed(2)}',
              style: pw.TextStyle(font: regularFont, fontSize: 14),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Purchase Trend Chart:',
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(chartBytes),
                height: 220,
                fit: pw.BoxFit.contain,
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 10,
                color: PdfColors.grey,
              ),
            ),
          ],
        );
      },
    ),
  );

  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final suggestedName = 'Purchase_Report_$timestamp.pdf';

  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save Purchase PDF',
    fileName: suggestedName,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );

  if (savePath == null) return null;
  final file = File(savePath);
  await file.writeAsBytes(await pdf.save());
  return file;
}

/// Generate PDF for a single purchase with optional items
Future<File?> generatePurchaseInvoicePdf(
  Purchase purchase, {
  List<Map<String, dynamic>>? items,
}) async {
  final pdf = pw.Document();
  final regularFont = await PdfGoogleFonts.notoSansRegular();
  final boldFont = await PdfGoogleFonts.notoSansBold();

  // Load logo if available
  pw.MemoryImage? logoImage;
  try {
    final logoBytes = await rootBundle.load('assets/logo.png');
    logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  } catch (e) {
    print('⚠️ Logo not found, skipping: $e');
  }

  final date = DateFormat(
    'dd MMM yyyy, hh:mm a',
  ).format(DateTime.tryParse(purchase.date) ?? DateTime.now());

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Mian Traders',
                        style: pw.TextStyle(font: boldFont, fontSize: 22),
                      ),
                      pw.Text(
                        'Kotmomi road ,Bhagtanawala, Sargodha',
                        style: pw.TextStyle(font: regularFont, fontSize: 12),
                      ),
                      pw.Text(
                        'Phone: +92-300-1234567 | info@company.com',
                        style: pw.TextStyle(font: regularFont, fontSize: 12),
                      ),
                    ],
                  ),
                  if (logoImage != null)
                    pw.Container(
                      height: 60,
                      width: 60,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 12),

              pw.Text(
                'Purchase #${purchase.id}',
                style: pw.TextStyle(font: boldFont, fontSize: 18),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Date: $date',
                style: pw.TextStyle(font: regularFont, fontSize: 12),
              ),
              pw.Divider(),
              pw.SizedBox(height: 16),

              pw.Text(
                'Total: ${purchase.total.toStringAsFixed(2)}',
                style: pw.TextStyle(font: regularFont, fontSize: 14),
              ),
              pw.Text(
                'Pending: ${purchase.pending.toStringAsFixed(2)}',
                style: pw.TextStyle(font: regularFont, fontSize: 14),
              ),
              pw.Text(
                'Paid: ${(purchase.total - purchase.pending).toStringAsFixed(2)}',
                style: pw.TextStyle(font: regularFont, fontSize: 14),
              ),

              if (items != null && items.isNotEmpty) ...[
                pw.SizedBox(height: 24),
                pw.Text(
                  'Items',
                  style: pw.TextStyle(font: boldFont, fontSize: 16),
                ),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  border: pw.TableBorder.all(width: 0.5),
                  cellAlignment: pw.Alignment.centerLeft,
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  headerStyle: pw.TextStyle(font: boldFont, fontSize: 12),
                  cellStyle: pw.TextStyle(font: regularFont, fontSize: 10),
                  headers: ['Product', 'Qty', 'Price', 'Total'],
                  data: items.map((item) {
                    final qty = item['qty'] ?? 0;
                    final price = item['price'] ?? 0.0;
                    final total = qty * price;
                    return [
                      item['product_name'] ?? '',
                      qty.toString(),
                      price.toStringAsFixed(2),
                      total.toStringAsFixed(2),
                    ];
                  }).toList(),
                ),
              ],

              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final suggestedName = 'Purchase_${purchase.id}_$timestamp.pdf';

  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save Purchase PDF',
    fileName: suggestedName,
    allowedExtensions: ['pdf'],
  );

  if (savePath == null) return null;
  final file = File(savePath);
  await file.writeAsBytes(await pdf.save());
  return file;
}

/// Print a PDF file
Future<void> printPdfFile(File pdfFile) async {
  if (await pdfFile.exists()) {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => await pdfFile.readAsBytes(),
      name: pdfFile.path.split(Platform.pathSeparator).last,
    );
  } else {
    print("⚠️ PDF file not found: ${pdfFile.path}");
  }
}

/// Share or print directly
Future<void> shareOrPrintPdf(File pdfFile) async {
  if (await pdfFile.exists()) {
    await Printing.sharePdf(
      bytes: await pdfFile.readAsBytes(),
      filename: pdfFile.path.split(Platform.pathSeparator).last,
    );
  } else {
    print("⚠️ PDF file not found: ${pdfFile.path}");
  }
}

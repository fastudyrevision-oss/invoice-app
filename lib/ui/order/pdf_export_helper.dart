import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '/../../models/invoice.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Helper function to create and export a PDF report with a chart image.
Future<File?> generatePdfReportWithChart({
  required String title,
  required Uint8List chartBytes,
  required double totalRevenue,
  required double avgInvoice,
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
              'Revenue Report Summary',
              style: pw.TextStyle(font: regularFont, fontSize: 16),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Total Revenue: Rs ${totalRevenue.toStringAsFixed(2)}',
              style: pw.TextStyle(font: regularFont, fontSize: 14),
            ),
            pw.Text(
              'Average Invoice: Rs ${avgInvoice.toStringAsFixed(2)}',
              style: pw.TextStyle(font: regularFont, fontSize: 14),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Revenue Trend Chart:',
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
            pw.SizedBox(height: 10),

            // 🧩 Chart
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
  final suggestedName = 'Revenue_Report_$timestamp.pdf';

  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save PDF Report',
    fileName: suggestedName,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );

  if (savePath == null) return null;

  final file = File(savePath);
  await file.writeAsBytes(await pdf.save());
  return file;
}

/// ✅ Generate a single invoice PDF (Updated with logo + header + items)
Future<File?> generateInvoicePdf(
  Invoice invoice, {
  List<Map<String, dynamic>>? items,
}) async {
  final pdf = pw.Document();

  final regularFont = await PdfGoogleFonts.notoSansRegular();
  final boldFont = await PdfGoogleFonts.notoSansBold();

  // ✅ Load company logo (optional)
  pw.MemoryImage? logoImage;
  try {
    final logoBytes = await rootBundle.load('assets/logo.png');
    logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  } catch (e) {
    print('⚠️ Logo not found, skipping: $e');
  }

  final date = DateFormat(
    'dd MMM yyyy, hh:mm a',
  ).format(DateTime.tryParse(invoice.date ?? '') ?? DateTime.now());

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 🏢 Company Header
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

              // 🧾 Invoice Info
              pw.Text(
                'Invoice #${invoice.id}',
                style: pw.TextStyle(font: boldFont, fontSize: 18),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Customer: ${invoice.customerName ?? "N/A"}',
                style: pw.TextStyle(font: regularFont, fontSize: 14),
              ),
              pw.Text(
                'Date: $date',
                style: pw.TextStyle(font: regularFont, fontSize: 12),
              ),
              pw.Divider(),
              pw.SizedBox(height: 16),

              // 💰 Totals
              pw.Text(
                'Total: ${invoice.total.toStringAsFixed(2) ?? "0.00"}',
                style: pw.TextStyle(font: regularFont, fontSize: 14),
              ),
              pw.Text(
                'Pending: ${invoice.pending.toStringAsFixed(2) ?? "0.00"}',
                style: pw.TextStyle(font: regularFont, fontSize: 14),
              ),
              pw.Text(
                'Paid: ${(invoice.total - (invoice.pending ?? 0)).toStringAsFixed(2)}',
                style: pw.TextStyle(font: regularFont, fontSize: 14),
              ),

              // 🧾 Items Table
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
                    final qty = (item['qty'] ?? 0);
                    final price = (item['price'] ?? 0.0);
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
  final suggestedName = 'Invoice_${invoice.id}_$timestamp.pdf';

  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save Invoice PDF',
    fileName: suggestedName,
    allowedExtensions: ['pdf'],
  );

  if (savePath == null) return null;

  final file = File(savePath);
  await file.writeAsBytes(await pdf.save());
  return file;
}

/// ✅ Generate PDF for all orders
Future<File?> generateAllOrdersPdf(List<Invoice> orders) async {
  final pdf = pw.Document();
  final regularFont = await PdfGoogleFonts.notoSansRegular();
  final boldFont = await PdfGoogleFonts.notoSansBold();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return [
          pw.Text(
            'All Orders Summary',
            style: pw.TextStyle(font: boldFont, fontSize: 20),
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['#', 'Customer', 'Date', 'Total', 'Pending'],
            headerStyle: pw.TextStyle(font: boldFont, fontSize: 12),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: pw.TextStyle(font: regularFont, fontSize: 10),
            data: orders.map((o) {
              return [
                o.id ?? '',
                o.customerName ?? '',
                DateFormat(
                  'dd MMM yyyy',
                ).format(DateTime.tryParse(o.date) ?? DateTime.now()),
                o.total.toStringAsFixed(2),
                o.pending.toStringAsFixed(2) ?? '0.00',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ];
      },
    ),
  );

  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final suggestedName = 'All_Orders_$timestamp.pdf';

  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save All Orders PDF',
    fileName: suggestedName,
    allowedExtensions: ['pdf'],
  );

  if (savePath == null) return null;

  final file = File(savePath);
  await file.writeAsBytes(await pdf.save());
  return file;
}

/// ✅ Print a PDF file directly to a physical printer
Future<void> printPdfFile(File pdfFile) async {
  if (await pdfFile.exists()) {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => await pdfFile.readAsBytes(),
      name: pdfFile.path.split(Platform.pathSeparator).last,
    );
  } else {
    print("⚠️ PDF file not found for printing: ${pdfFile.path}");
  }
}

/// ✅ Share or print directly
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

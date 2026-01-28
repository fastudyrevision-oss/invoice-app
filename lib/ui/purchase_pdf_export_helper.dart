import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/purchase.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../utils/platform_file_helper.dart';
import '../../utils/pdf_font_helper.dart';
import '../../utils/date_helper.dart';

/// Generate a PDF report with a chart for purchases
Future<File?> generatePurchasePdfWithChart({
  required String title,
  required Uint8List chartBytes,
  required double totalAmount,
  required double avgPurchase,
}) async {
  final pdf = pw.Document();
  // Load fonts from centralized helper (future-safe)
  final fonts = await PdfFontHelper.getBothFonts();
  final regularFont = fonts['regular']!;
  final boldFont = fonts['bold']!;

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

  // Use platform-aware file handling (Android: share, Desktop: file picker)
  final pdfBytes = await pdf.save();
  return await PlatformFileHelper.savePdfFile(
    pdfBytes: pdfBytes,
    suggestedName: suggestedName,
    dialogTitle: 'Save Purchase PDF',
  );
}

/// Generate PDF for a single purchase with optional items
Future<File?> generatePurchaseInvoicePdf(
  Purchase purchase, {
  List<Map<String, dynamic>>? items,
}) async {
  final pdf = pw.Document();
  // Load fonts from centralized helper (future-safe)
  final fonts = await PdfFontHelper.getBothFonts();
  final regularFont = fonts['regular']!;
  final boldFont = fonts['bold']!;

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
                  pw.Directionality(
                    textDirection: pw.TextDirection.ltr,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'MIAN TRADERS',
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

  // Use platform-aware file handling (Android: share, Desktop: file picker)
  final pdfBytes = await pdf.save();
  return await PlatformFileHelper.savePdfFile(
    pdfBytes: pdfBytes,
    suggestedName: suggestedName,
    dialogTitle: 'Save Purchase PDF',
  );
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

/// ✅ Generate thermal printer receipt format (80mm width) for purchases
Future<File?> generateThermalReceipt(
  Purchase purchase, {
  List<Map<String, dynamic>>? items,
  String? supplierName,
}) async {
  final pdf = pw.Document();

  // Load fonts from centralized helper (future-safe)
  final fonts = await PdfFontHelper.getBothFonts();
  final regularFont = fonts['regular']!;
  final boldFont = fonts['bold']!;

  // Use DateHelper to force dd-MM-yyyy format
  final date = DateHelper.formatIso(purchase.date);

  // Thermal receipt: 80mm width (continuous roll)
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat(
        80 * PdfPageFormat.mm,
        5000 * PdfPageFormat.mm, // 5 meters max length (simulates roll)
        marginAll: 5 * PdfPageFormat.mm,
      ),
      build: (context) {
        return [
          // 🏢 Company Header
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Center(
                  child: pw.Text(
                    'میاں ٹریڈرز',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(font: regularFont, fontSize: 14),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'Wholesale and Retail Store',
              style: pw.TextStyle(font: regularFont, fontSize: 9),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'Sargodha',
              style: pw.TextStyle(font: regularFont, fontSize: 9),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Center(
            child: pw.Text(
              '+92 345 4297128',
              style: pw.TextStyle(font: regularFont, fontSize: 9),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 1, color: PdfColors.black),
          pw.SizedBox(height: 8),

          // Supplier & Date
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Supplier:',
                style: pw.TextStyle(font: regularFont, fontSize: 8),
              ),
              pw.Expanded(
                child: pw.Text(
                  supplierName ?? 'N/A',
                  style: pw.TextStyle(font: regularFont, fontSize: 8),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Invoice:',
                style: pw.TextStyle(font: regularFont, fontSize: 8),
              ),
              pw.Text(
                purchase.invoiceNo,
                style: pw.TextStyle(font: regularFont, fontSize: 8),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Date:',
                style: pw.TextStyle(font: regularFont, fontSize: 8),
              ),
              pw.Text(
                date,
                style: pw.TextStyle(font: regularFont, fontSize: 8),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 1, color: PdfColors.black),
          pw.SizedBox(height: 6),

          // Items Table
          if (items != null && items.isNotEmpty) ...[
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(width: 0.5),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 7),
              cellStyle: pw.TextStyle(font: regularFont, fontSize: 7),
              headers: ['Item', 'Qty', 'Price', 'Total'],
              data: items.map((item) {
                final qty = (item['qty'] ?? 0);
                final price = (item['price'] ?? 0.0);
                final total = qty * price;
                return [
                  item['product_name'] ?? '',
                  qty.toString(),
                  price.toStringAsFixed(0),
                  total.toStringAsFixed(0),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 6),
          ],

          pw.Container(height: 1, color: PdfColors.black),
          pw.SizedBox(height: 6),

          // 💰 Totals Table
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.5),
            ),
            child: pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1),
              },
              children: [
                // Sub Total
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Sub Total',
                        style: pw.TextStyle(font: regularFont, fontSize: 8),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        purchase.total.toStringAsFixed(0),
                        style: pw.TextStyle(font: regularFont, fontSize: 8),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                // Paid
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Paid',
                        style: pw.TextStyle(font: regularFont, fontSize: 8),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        purchase.paid.toStringAsFixed(0),
                        style: pw.TextStyle(font: regularFont, fontSize: 8),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                // Pending
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Pending',
                        style: pw.TextStyle(font: regularFont, fontSize: 8),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        purchase.pending.toStringAsFixed(0),
                        style: pw.TextStyle(font: regularFont, fontSize: 8),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                // Total
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Total',
                        style: pw.TextStyle(font: boldFont, fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        purchase.total.toStringAsFixed(0),
                        style: pw.TextStyle(font: boldFont, fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 1, color: PdfColors.black),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'Thank You!',
              style: pw.TextStyle(font: boldFont, fontSize: 9),
            ),
          ),
        ]; // End of children list
      },
    ),
  );

  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final suggestedName = 'Receipt_${purchase.id}_$timestamp.pdf';

  // Use platform-aware file handling
  final pdfBytes = await pdf.save();
  return await PlatformFileHelper.savePdfFile(
    pdfBytes: pdfBytes,
    suggestedName: suggestedName,
    dialogTitle: 'Save Thermal Receipt',
  );
}

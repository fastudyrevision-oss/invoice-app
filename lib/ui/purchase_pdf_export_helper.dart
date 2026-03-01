import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../models/purchase.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../utils/platform_file_helper.dart';
import '../utils/pdf_font_helper.dart';
import '../utils/date_helper.dart';
import 'common/thermal_receipt_helper.dart';
import '../services/printer_settings_service.dart';
import '../services/thermal_printer/thermal_printing_service.dart';
import '../services/logger_service.dart';

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
    // Logo not found, skipping
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
                          'Phone: 0345 4297128 0300 9101050',
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
                'Purchase #${purchase.displayId ?? purchase.invoiceNo}',
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
                pw.TableHelper.fromTextArray(
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
  final displayId = purchase.displayId?.toString() ?? purchase.invoiceNo;
  final suggestedName = 'Purchase_${displayId}_$timestamp.pdf';

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
    // PDF file not found: ${pdfFile.path}
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
    // PDF file not found: ${pdfFile.path}
  }
}

/// ✅ Generate thermal printer receipt format (80mm width) for purchases
Future<File?> generateThermalReceipt(
  Purchase purchase, {
  List<Map<String, dynamic>>? items,
  String? supplierName,
}) async {
  logger.info(
    'PDFHelper',
    'Generating Thermal Receipt for Purchase #${purchase.displayId ?? purchase.invoiceNo}',
  );

  final pdf = pw.Document();

  // Load fonts
  final regularFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
  );
  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
  );

  // Load logo image from assets
  pw.MemoryImage? logoImage;
  try {
    final logoData = await rootBundle.load('assets/printing_logo.png');
    logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
  } catch (e) {
    logger.warning('PDFHelper', 'Could not load printing logo: $e');
  }

  final settingsService = PrinterSettingsService();
  await settingsService.initialize();
  final paperWidthMm = await settingsService.getPaperWidth();
  final double widthPoints = paperWidthMm * 2.8346;

  final date =
      '${DateHelper.formatIso(purchase.date)}, ${DateFormat('hh:mm a').format(DateTime.tryParse(purchase.date) ?? DateTime.now())}';

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(widthPoints, double.infinity),
      margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Logo
            if (logoImage != null)
              pw.Center(
                child: pw.Image(
                  logoImage,
                  width: widthPoints * 0.4,
                  height: widthPoints * 0.4,
                ),
              ),
            if (logoImage != null) pw.SizedBox(height: 4),

            // Company Header
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'میاں ٹریڈرز',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: paperWidthMm < 60 ? 14 : 20,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Whole Sale & Retail Store',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: paperWidthMm < 60 ? 8 : 10,
              ),
            ),
            pw.Text(
              'Kotmomin Road,Bhagtanawala,Sargodha',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: paperWidthMm < 60 ? 6 : 7,
              ),
            ),
            pw.Text(
              '0345 4297128',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: paperWidthMm < 60 ? 8 : 14,
              ),
            ),
            pw.Text(
              '0300 9101050',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: paperWidthMm < 60 ? 8 : 14,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 4),

            // Supplier & Date
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'Supplier: ${supplierName ?? 'N/A'}',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: paperWidthMm < 60 ? 8 : 15,
                ),
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'Date: $date',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: paperWidthMm < 60 ? 8 : 10,
                ),
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'Purchase: #${purchase.displayId ?? purchase.invoiceNo}',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: paperWidthMm < 60 ? 8 : 10,
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 4),

            // Items Table
            if (items != null && items.isNotEmpty) ...[
              pw.Table(
                border: pw.TableBorder.all(width: 0.3),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.0),
                  1: const pw.FlexColumnWidth(0.7),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.8),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(1),
                        child: pw.Text(
                          'Item',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: paperWidthMm < 60 ? 5 : 6,
                          ),
                          softWrap: true,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(1),
                        child: pw.Text(
                          'Qty',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: paperWidthMm < 60 ? 5 : 6,
                          ),
                          textAlign: pw.TextAlign.left,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(1),
                        child: pw.Text(
                          'Price',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: paperWidthMm < 60 ? 5 : 6,
                          ),
                          textAlign: pw.TextAlign.left,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(1),
                        child: pw.Text(
                          'Total',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: paperWidthMm < 60 ? 5 : 6,
                          ),
                          textAlign: pw.TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                  ...items.map((item) {
                    final qty = (item['qty'] ?? 0);
                    final price = (item['price'] ?? 0.0);
                    final total = qty * price;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: pw.Text(
                            item['product_name'] ?? '',
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: paperWidthMm < 60 ? 5 : 6,
                            ),
                            softWrap: true,
                            maxLines: 2,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: pw.Text(
                            qty.toString(),
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: paperWidthMm < 60 ? 5 : 6,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: pw.Text(
                            price.toStringAsFixed(0),
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: paperWidthMm < 60 ? 5 : 6,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: pw.Text(
                            total.toStringAsFixed(0),
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: paperWidthMm < 60 ? 5 : 6,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 4),
            ],

            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 3),

            // Totals
            pw.Container(
              width: widthPoints * 0.9,
              child: pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          'Total',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: paperWidthMm < 60 ? 8 : 9,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          purchase.total.toStringAsFixed(0),
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: paperWidthMm < 60 ? 8 : 9,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          'Paid',
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: paperWidthMm < 60 ? 7 : 8,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          purchase.paid.toStringAsFixed(0),
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: paperWidthMm < 60 ? 7 : 8,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          'Due',
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: paperWidthMm < 60 ? 7 : 8,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          purchase.pending.toStringAsFixed(0),
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: paperWidthMm < 60 ? 7 : 8,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                'Thank You!',
                style: pw.TextStyle(font: boldFont, fontSize: 9),
              ),
            ),
          ],
        );
      },
    ),
  );

  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final displayId = purchase.displayId?.toString() ?? purchase.invoiceNo;
  final suggestedName = 'Purchase_Receipt_${displayId}_$timestamp.pdf';

  final pdfBytes = await pdf.save();
  return await PlatformFileHelper.savePdfFile(
    pdfBytes: pdfBytes,
    suggestedName: suggestedName,
    dialogTitle: 'Save Purchase Thermal Receipt',
  );
}

/// ✅ Silent print a purchase thermal receipt
Future<bool> printSilentPurchaseThermalReceipt(
  Purchase purchase, {
  List<Map<String, dynamic>>? items,
  String? supplierName,
}) async {
  try {
    logger.info(
      'PDFHelper',
      'Silent printing purchase receipt for #${purchase.displayId ?? purchase.invoiceNo}',
    );

    // Get paper width from settings
    final settingsService = PrinterSettingsService();
    await settingsService.initialize();
    final paperWidthMm = await settingsService.getPaperWidth();
    final double widthPoints = paperWidthMm * 2.8346;

    // Load fonts
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
    );

    // Load logo image from assets
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/printing_logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      logger.warning('PDFHelper', 'Could not load printing logo: $e');
    }

    final date =
        '${DateHelper.formatIso(purchase.date)}, ${DateFormat('hh:mm a').format(DateTime.tryParse(purchase.date) ?? DateTime.now())}';

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(widthPoints, double.infinity),
        margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo
              if (logoImage != null)
                pw.Center(
                  child: pw.Image(
                    logoImage,
                    width: widthPoints * 0.4,
                    height: widthPoints * 0.4,
                  ),
                ),
              if (logoImage != null) pw.SizedBox(height: 4),

              // Company Header
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'میاں ٹریڈرز',
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: paperWidthMm < 60 ? 14 : 20,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Whole Sale & Retail Store',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: paperWidthMm < 60 ? 8 : 10,
                ),
              ),
              pw.Text(
                'Kotmomin Road,Bhagtanawala,Sargodha',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: paperWidthMm < 60 ? 6 : 7,
                ),
              ),
              pw.Text(
                '0300 9101050',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: paperWidthMm < 60 ? 8 : 14,
                ),
              ),
              pw.Text(
                '0345 4297128',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: paperWidthMm < 60 ? 8 : 14,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(height: 1, color: PdfColors.black),
              pw.SizedBox(height: 4),

              // Supplier & Date
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Supplier: ${supplierName ?? 'N/A'}',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: paperWidthMm < 60 ? 8 : 15,
                  ),
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Date: $date',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: paperWidthMm < 60 ? 8 : 10,
                  ),
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Purchase: #${purchase.displayId ?? purchase.invoiceNo}',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: paperWidthMm < 60 ? 8 : 10,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(height: 1, color: PdfColors.black),
              pw.SizedBox(height: 4),

              // Items Table
              if (items != null && items.isNotEmpty) ...[
                pw.Table(
                  border: pw.TableBorder.all(width: 0.3),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.0),
                    1: const pw.FlexColumnWidth(0.7),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.8),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: pw.Text(
                            'Item',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: paperWidthMm < 60 ? 5 : 6,
                            ),
                            softWrap: true,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: pw.Text(
                            'Qty',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: paperWidthMm < 60 ? 5 : 6,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: pw.Text(
                            'Price',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: paperWidthMm < 60 ? 5 : 6,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: pw.Text(
                            'Total',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: paperWidthMm < 60 ? 5 : 6,
                            ),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                      ],
                    ),
                    ...items.map((item) {
                      final qty = (item['qty'] ?? 0);
                      final price = (item['price'] ?? 0.0);
                      final total = qty * price;
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(1),
                            child: pw.Text(
                              item['product_name'] ?? '',
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: paperWidthMm < 60 ? 5 : 6,
                              ),
                              softWrap: true,
                              maxLines: 2,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(1),
                            child: pw.Text(
                              qty.toString(),
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: paperWidthMm < 60 ? 5 : 6,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(1),
                            child: pw.Text(
                              price.toStringAsFixed(0),
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: paperWidthMm < 60 ? 5 : 6,
                              ),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(1),
                            child: pw.Text(
                              total.toStringAsFixed(0),
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: paperWidthMm < 60 ? 5 : 6,
                              ),
                              textAlign: pw.TextAlign.left,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 4),
              ],

              pw.Container(height: 1, color: PdfColors.black),
              pw.SizedBox(height: 3),

              // Totals
              pw.Container(
                width: widthPoints * 0.9,
                child: pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            'Total',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: paperWidthMm < 60 ? 8 : 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            purchase.total.toStringAsFixed(0),
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: paperWidthMm < 60 ? 8 : 9,
                            ),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            'Paid',
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: paperWidthMm < 60 ? 7 : 8,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            purchase.paid.toStringAsFixed(0),
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: paperWidthMm < 60 ? 7 : 8,
                            ),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            'Due',
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: paperWidthMm < 60 ? 7 : 8,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            purchase.pending.toStringAsFixed(0),
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: paperWidthMm < 60 ? 7 : 8,
                            ),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Thank You!',
                  style: pw.TextStyle(font: boldFont, fontSize: 9),
                ),
              ),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    return await thermalPrinting.printPdfSilently(
      pdfBytes,
      docName: 'Purchase_${purchase.displayId ?? purchase.invoiceNo}',
    );
  } catch (e, st) {
    logger.error(
      'PDFHelper',
      'Silent purchase print failed',
      error: e,
      stackTrace: st,
    );
    return false;
  }
}

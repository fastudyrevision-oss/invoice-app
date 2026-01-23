import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '/../../models/invoice.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../utils/platform_file_helper.dart';
import '../../utils/pdf_font_helper.dart';

/// Helper function to create and export a PDF report with a chart image.
Future<File?> generatePdfReportWithChart({
  required String title,
  required Uint8List chartBytes,
  required double totalRevenue,
  required double avgInvoice,
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

  // Use platform-aware file handling (Android: share, Desktop: file picker)
  final pdfBytes = await pdf.save();
  return await PlatformFileHelper.savePdfFile(
    pdfBytes: pdfBytes,
    suggestedName: suggestedName,
    dialogTitle: 'Save PDF Report',
  );
}

/// ✅ Generate a single invoice PDF (Updated with logo + header + items)
Future<File?> generateInvoicePdf(
  Invoice invoice, {
  List<Map<String, dynamic>>? items,
}) async {
  final pdf = pw.Document();

  // Load fonts from centralized helper (future-safe)
  final fonts = await PdfFontHelper.getBothFonts();
  final regularFont = fonts['regular']!;
  final boldFont = fonts['bold']!;

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
  ).format(DateTime.tryParse(invoice.date) ?? DateTime.now());

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
                  pw.Directionality(
                    textDirection: pw.TextDirection.rtl,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'MIAN TRADERS',
                          style: pw.TextStyle(font: boldFont, fontSize: 22),
                        ),
                        pw.Text(
                          'Kotmomin road ,Bhagtanawala, Sargodha',
                          style: pw.TextStyle(font: regularFont, fontSize: 12),
                        ),
                        pw.Text(
                          'Phone: +92 345 4297128 | bilalahmadgh@gmail.com',
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

              // 🧾 Invoice Info (Customer & Date only)
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
              
              // 💰 Totals (Moved to bottom)
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Discount:',
                    style: pw.TextStyle(font: regularFont, fontSize: 12),
                  ),
                  pw.Text(
                    'Rs ${invoice.discount.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: regularFont, fontSize: 12),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Paid:',
                    style: pw.TextStyle(font: regularFont, fontSize: 12),
                  ),
                  pw.Text(
                    'Rs ${(invoice.total - invoice.pending).toStringAsFixed(2)}',
                    style: pw.TextStyle(font: regularFont, fontSize: 12),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Pending:',
                    style: pw.TextStyle(font: regularFont, fontSize: 12),
                  ),
                  pw.Text(
                    'Rs ${invoice.pending.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: regularFont, fontSize: 12),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(width: 2, color: PdfColors.black),
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total:',
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                  ),
                  pw.Text(
                    'Rs ${invoice.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
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

  // Use platform-aware file handling (Android: share, Desktop: file picker)
  final pdfBytes = await pdf.save();
  return await PlatformFileHelper.savePdfFile(
    pdfBytes: pdfBytes,
    suggestedName: suggestedName,
    dialogTitle: 'Save Invoice PDF',
  );
}

/// ✅ Generate PDF for all orders with filter support
Future<File?> generateAllOrdersPdf(
  List<Invoice> orders, {
  String? searchQuery,
  bool showPendingOnly = false,
  DateTimeRange? dateRange,
  String? quickFilter,
}) async {
  final pdf = pw.Document();
  
  // Load fonts from centralized helper (future-safe)
  final fonts = await PdfFontHelper.getBothFonts();
  final regularFont = fonts['regular']!;
  final boldFont = fonts['bold']!;

  // Build filter summary
  final List<String> activeFilters = [];
  if (searchQuery != null && searchQuery.isNotEmpty) {
    activeFilters.add('Search: "$searchQuery"');
  }
  if (showPendingOnly) {
    activeFilters.add('Status: Pending Only');
  }
  if (dateRange != null) {
    final start = DateFormat('dd MMM yyyy').format(dateRange.start);
    final end = DateFormat('dd MMM yyyy').format(dateRange.end);
    activeFilters.add('Date Range: $start - $end');
  }
  if (quickFilter != null) {
    final filterName = quickFilter == 'today'
        ? 'Today'
        : quickFilter == 'week'
        ? 'This Week'
        : 'This Month';
    activeFilters.add('Quick Filter: $filterName');
  }

  // Calculate totals
  final totalRevenue = orders.fold<double>(
    0.0,
    (sum, o) => sum + o.total,
  );
  final totalPending = orders.fold<double>(
    0.0,
    (sum, o) => sum + o.pending,
  );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) {
        return [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              gradient: const pw.LinearGradient(
                colors: [PdfColors.blue700, PdfColors.blue900],
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
                      activeFilters.isEmpty
                          ? 'All Orders Report'
                          : 'Filtered Orders Report',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 20,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Total: ${orders.length} orders',
                      style: pw.TextStyle(
                        font: regularFont,
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
                      'Generated: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 10,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      DateFormat('hh:mm a').format(DateTime.now()),
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 10,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // Active Filters Section
          if (activeFilters.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Active Filters',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 12,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  ...activeFilters.map(
                    (filter) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 4,
                            height: 4,
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.blue700,
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Text(
                            filter,
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 10,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // Summary Cards
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.green700),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Total Revenue',
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 10,
                          color: PdfColors.green900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Rs ${totalRevenue.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 14,
                          color: PdfColors.green900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.orange700),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Total Pending',
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 10,
                          color: PdfColors.orange900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Rs ${totalPending.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 14,
                          color: PdfColors.orange900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // Orders Table
          pw.Table.fromTextArray(
            headers: ['#', 'Customer', 'Date', 'Total', 'Pending'],
            headerStyle: pw.TextStyle(font: boldFont, fontSize: 11),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
            cellStyle: pw.TextStyle(font: regularFont, fontSize: 9),
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
            data: orders.asMap().entries.map((entry) {
              final index = entry.key;
              final o = entry.value;
              return [
                (index + 1).toString(),
                o.customerName ?? 'N/A',
                DateFormat(
                  'dd MMM yyyy',
                ).format(DateTime.tryParse(o.date) ?? DateTime.now()),
                'Rs ${o.total.toStringAsFixed(2)}',
                'Rs ${o.pending.toStringAsFixed(2)}',
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 16),

          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Prepared via میاں ٹریڈرز',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ];
      },
    ),
  );

  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final filterSuffix = showPendingOnly ? '_Pending' : '';
  final suggestedName = 'Orders_Report${filterSuffix}_$timestamp.pdf';

  // Use platform-aware file handling (Android: share, Desktop: file picker)
  final pdfBytes = await pdf.save();
  return await PlatformFileHelper.savePdfFile(
    pdfBytes: pdfBytes,
    suggestedName: suggestedName,
    dialogTitle: 'Save Orders Report PDF',
  );
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

/// ✅ Generate thermal printer receipt format (80mm width)
Future<File?> generateThermalReceipt(
  Invoice invoice, {
  List<Map<String, dynamic>>? items,
}) async {
  // ⚠️ Warn if receipt has many items (thermal printer best for 10-20 items)
  if (items != null && items.length > 20) {
    debugPrint('⚠️ Warning: Receipt has ${items.length} items. Consider PDF export for better formatting.');
  }

  final pdf = pw.Document();

  // Load Urdu-supporting font from assets (NotoSansArabic has better text shaping)
  final regularFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
  );
  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
  );

  final date = DateFormat(
    'dd MMM yyyy, hh:mm a',
  ).format(DateTime.tryParse(invoice.date) ?? DateTime.now());

  // Thermal receipt: 80mm width (approx 226 points at 72 DPI)
  pdf.addPage(
    pw.Page(
      pageFormat: const PdfPageFormat(284, double.infinity), // 80mm x custom height
      margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),

      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // 🏢 Company Header
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'MIAN TRADERS',
                    style: pw.TextStyle(font: boldFont, fontSize: 12),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Sargodha',
              style: pw.TextStyle(font: regularFont, fontSize: 7),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              '+92 345 4297128',
              style: pw.TextStyle(font: regularFont, fontSize: 7),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 4),

            // Customer & Date (stacked for narrow width)
            pw.Text(
              'Customer: ${(invoice.customerName ?? 'N/A').length > 18 ? (invoice.customerName ?? 'N/A').substring(0, 18) : invoice.customerName ?? 'N/A'}',
              style: pw.TextStyle(font: regularFont, fontSize: 6),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              'Date: ${date.length > 18 ? date.substring(0, 18) : date}',
              style: pw.TextStyle(font: regularFont, fontSize: 7),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
            pw.SizedBox(height: 4),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 4),

            // Items Table with wrapping support
            if (items != null && items.isNotEmpty) ...[
              pw.Table(
                border: pw.TableBorder.all(width: 0.3),
                columnWidths: {
  0: const pw.FixedColumnWidth(60), // Item
  1: const pw.FixedColumnWidth(30),  // Qty
  2: const pw.FixedColumnWidth(20),  // Price
  3: const pw.FixedColumnWidth(100),  // Total
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
                          style: pw.TextStyle(font: boldFont, fontSize: 6),
                          textAlign: pw.TextAlign.left,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(1),
                        child: pw.Text(
                          'Qty',
                          style: pw.TextStyle(font: boldFont, fontSize: 6),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(1),
                        child: pw.Text(
                          'Price',
                          style: pw.TextStyle(font: boldFont, fontSize: 6),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(1),
                        child: pw.Text(
                          'Total',
                          style: pw.TextStyle(font: boldFont, fontSize: 6),
                          textAlign: pw.TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                  ...items.map((item) {
                    final qty = (item['qty'] ?? 0);
                    final price = (item['price'] ?? 0.0);
                    final total = qty * price;
                    final productName = item['product_name'] ?? '';
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: pw.Text(
                            productName,
                            softWrap: true,
                            maxLines: 2,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(font: regularFont, fontSize: 6),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: pw.Text(
                            qty.toString(),
                            style: pw.TextStyle(font: regularFont, fontSize: 6),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: pw.Text(
                            price.toStringAsFixed(0),
                            style: pw.TextStyle(font: regularFont, fontSize: 6),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: pw.Text(
                            total.toStringAsFixed(0),
                            style: pw.TextStyle(font: regularFont, fontSize: 6),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 4),
            ],

            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 3),

            // 💰 Totals with optimized layout (single line each)
            pw.Text(
              'Disc: Rs   ${invoice.discount.toStringAsFixed(0)}',
              style: pw.TextStyle(font: regularFont, fontSize: 9),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              'Paid: Rs   ${(invoice.total - invoice.pending).toStringAsFixed(0)}',
              style: pw.TextStyle(font: regularFont, fontSize: 9),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              'Due: Rs   ${invoice.pending.toStringAsFixed(0)}',
              style: pw.TextStyle(font: regularFont, fontSize: 9),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
            pw.SizedBox(height: 4),
            pw.Container(height: 1.5, color: PdfColors.black),
            pw.SizedBox(height: 2),
            pw.Text(
              'TOTAL: Rs   ${invoice.total.toStringAsFixed(0)}',
              style: pw.TextStyle(font: boldFont, fontSize: 9),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.Text(
                'Thank You!',
                style: pw.TextStyle(font: boldFont, fontSize: 9),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'میاں ٹریڈرز',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(font: regularFont, fontSize: 8),
              ),
            ),
          ],
        );
      },
    ),
  );

  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final suggestedName = 'Receipt_${invoice.id}_$timestamp.pdf';

  // Use platform-aware file handling
  final pdfBytes = await pdf.save();
  return await PlatformFileHelper.savePdfFile(
    pdfBytes: pdfBytes,
    suggestedName: suggestedName,
    dialogTitle: 'Save Thermal Receipt',
  );
}

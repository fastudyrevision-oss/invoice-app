import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/invoice.dart';
import '../../models/stock_disposal.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../utils/platform_file_helper.dart';
import '../../utils/pdf_font_helper.dart';
import '../../services/logger_service.dart';
import '../../services/printer_settings_service.dart';
import '../../services/thermal_printer/thermal_printing_service.dart';
import '../common/thermal_receipt_helper.dart';
import '../../utils/date_helper.dart';

/// Helper function to create and export a PDF report with a chart image.
Future<File?> generatePdfReportWithChart({
  required String title,
  required Uint8List chartBytes,
  required double totalRevenue,
  required double avgInvoice,
}) async {
  logger.info('PDFHelper', 'Generating Revenue Report with Chart: $title');
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
              'Generated on ${DateHelper.formatDate(DateTime.now())}, ${DateFormat('hh:mm a').format(DateTime.now())}',
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
  final displayId = invoice.displayId?.toString() ?? invoice.invoiceNo;
  logger.info('PDFHelper', 'Generating Invoice PDF for #$displayId');
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
    logger.warning('PDFHelper', 'Logo not found, skipping', error: e);
  }

  final date =
      '${DateHelper.formatIso(invoice.date)}, ${DateFormat('hh:mm a').format(DateTime.tryParse(invoice.date) ?? DateTime.now())}';

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return [
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
                      'Phone: 0345 4297128  03009101050',
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
            'Order #$displayId',
            style: pw.TextStyle(font: boldFont, fontSize: 14),
          ),
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

          // 🧾 Items Table (Chunked to prevent TooManyPagesException)
          if (items != null && items.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            pw.Text('Items', style: pw.TextStyle(font: boldFont, fontSize: 16)),
            pw.SizedBox(height: 8),

            // Loop through items in chunks
            for (var i = 0; i < items.length; i += 20)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(width: 0.5),
                  cellAlignment: pw.Alignment.centerLeft,
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  headerStyle: pw.TextStyle(font: boldFont, fontSize: 12),
                  cellStyle: pw.TextStyle(font: regularFont, fontSize: 10),
                  headers: i == 0
                      ? ['Product', 'Qty', 'Price', 'Total']
                      : [], // Header only on first chunk
                  data: items
                      .sublist(
                        i,
                        (i + 20) > items.length ? items.length : i + 20,
                      )
                      .map((item) {
                        final qty = (item['qty'] ?? 0);
                        final price = (item['price'] ?? 0.0);
                        final total = qty * price;
                        return [
                          item['product_name'] ?? '',
                          qty.toString(),
                          price.toStringAsFixed(2),
                          total.toStringAsFixed(2),
                        ];
                      })
                      .toList(),
                ),
              ),
          ],

          pw.SizedBox(height: 24),

          // 💰 Totals Table
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 250,
                child: pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    // Subtotal
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: pw.Text(
                            'Subtotal',
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: pw.Text(
                            "Rs ${(invoice.total + invoice.discount).toStringAsFixed(2)}",
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 10,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Discount (only if > 0)
                    if (invoice.discount > 0)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: pw.Text(
                              'Discount',
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: pw.Text(
                              "Rs ${invoice.discount.toStringAsFixed(2)}",
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: 10,
                              ),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    // Total
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: pw.Text(
                            'Total',
                            style: pw.TextStyle(font: boldFont, fontSize: 12),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: pw.Text(
                            "Rs ${invoice.total.toStringAsFixed(2)}",
                            style: pw.TextStyle(font: boldFont, fontSize: 12),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Paid
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: pw.Text(
                            'Paid',
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: pw.Text(
                            "Rs ${(invoice.total - invoice.pending).toStringAsFixed(2)}",
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 10,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Due
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: pw.Text(
                            'Due',
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: pw.Text(
                            "Rs ${invoice.pending.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 10,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
        ];
      },
      footer: (context) {
        return pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(color: PdfColors.grey, fontSize: 10),
          ),
        );
      },
    ),
  );

  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final suggestedName = 'Invoice_${displayId}_$timestamp.pdf';

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
  logger.info(
    'PDFHelper',
    'Generating All Orders Report',
    context: {'orders': orders.length},
  );
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
  final totalRevenue = orders.fold<double>(0.0, (sum, o) => sum + o.total);
  final totalPending = orders.fold<double>(0.0, (sum, o) => sum + o.pending);
  final totalPaid = orders.fold<double>(
    0.0,
    (sum, o) => sum + (o.total - o.pending),
  );
  final totalDiscount = orders.fold<double>(0.0, (sum, o) => sum + o.discount);
  final totalSubtotal = totalRevenue + totalDiscount;

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

          // Summary Section as Table
          pw.Text(
            'Financial Summary',
            style: pw.TextStyle(font: boldFont, fontSize: 14),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: 300,
            child: pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
              },
              children: [
                _buildSummaryRow('Total Subtotal', totalSubtotal, regularFont),
                _buildSummaryRow('Total Discount', totalDiscount, regularFont),
                _buildSummaryRow(
                  'Total Revenue (Net)',
                  totalRevenue,
                  boldFont,
                  isBold: true,
                  bgColor: PdfColors.grey200,
                ),
                _buildSummaryRow('Total Paid', totalPaid, regularFont),
                _buildSummaryRow(
                  'Total Pending (Due)',
                  totalPending,
                  regularFont,
                  textColor: PdfColors.red900,
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Orders Table (Single table with auto-pagination)
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Customer', 'Date', 'Total', 'Pending'],
            headerStyle: pw.TextStyle(font: boldFont, fontSize: 11),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
            cellStyle: pw.TextStyle(font: regularFont, fontSize: 9),
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FixedColumnWidth(25), // #
              2: const pw.FixedColumnWidth(70), // Date
              3: const pw.FixedColumnWidth(80), // Total
              4: const pw.FixedColumnWidth(80), // Pending
            },
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
                  textDirection: pw.TextDirection.rtl,
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

// Helper for AllOrders Report Summary Table
pw.TableRow _buildSummaryRow(
  String label,
  double value,
  pw.Font font, {
  bool isBold = false,
  PdfColor? bgColor,
  PdfColor? textColor,
}) {
  return pw.TableRow(
    decoration: bgColor != null ? pw.BoxDecoration(color: bgColor) : null,
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            fontWeight: isBold ? pw.FontWeight.bold : null,
            color: textColor,
          ),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Text(
          "Rs ${value.toStringAsFixed(2)}",
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            fontWeight: isBold ? pw.FontWeight.bold : null,
            color: textColor,
          ),
          textAlign: pw.TextAlign.right,
        ),
      ),
    ],
  );
}

/// ✅ Print a PDF file directly to a physical printer
Future<void> printPdfFile(File pdfFile) async {
  logger.info(
    'PDFHelper',
    'Printing PDF file',
    context: {'path': pdfFile.path},
  );
  if (await pdfFile.exists()) {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => await pdfFile.readAsBytes(),
      name: pdfFile.path.split(Platform.pathSeparator).last,
    );
  } else {
    logger.warning(
      'PDFHelper',
      'PDF file not found for printing',
      context: {'path': pdfFile.path},
    );
  }
}

/// ✅ Share or print directly
Future<void> shareOrPrintPdf(File pdfFile) async {
  logger.info(
    'PDFHelper',
    'Sharing/Printing PDF file',
    context: {'path': pdfFile.path},
  );
  if (await pdfFile.exists()) {
    await Printing.sharePdf(
      bytes: await pdfFile.readAsBytes(),
      filename: pdfFile.path.split(Platform.pathSeparator).last,
    );
  } else {
    logger.warning(
      'PDFHelper',
      'PDF file not found for sharing',
      context: {'path': pdfFile.path},
    );
  }
}

/// ✅ Generate thermal printer receipt format (80mm width)
Future<File?> generateThermalReceipt(
  Invoice invoice, {
  List<Map<String, dynamic>>? items,
}) async {
  logger.info(
    'PDFHelper',
    'Generating Thermal Receipt for #${invoice.displayId ?? invoice.invoiceNo}',
  );
  // ⚠️ Warn if receipt has many items (thermal printer best for 10-20 items)
  if (items != null && items.length > 20) {
    logger.warning(
      'PDFHelper',
      'Receipt has ${items.length} items. Consider PDF export for better formatting.',
      context: {'itemCount': items.length},
    );
  }

  final pdf = pw.Document();

  // Load Urdu-supporting font from assets (NotoSansArabic has better text shaping)
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
      '${DateHelper.formatIso(invoice.date)}, ${DateFormat('hh:mm a').format(DateTime.tryParse(invoice.date) ?? DateTime.now())}';

  // Thermal receipt: 80mm width (approx 226 points at 72 DPI)
  pdf.addPage(
    pw.Page(
      pageFormat: const PdfPageFormat(
        260,
        double.infinity,
      ), // 80mm x custom height
      margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),

      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // 🖼️ Logo
            if (logoImage != null)
              pw.Center(child: pw.Image(logoImage, width: 80, height: 80)),
            if (logoImage != null) pw.SizedBox(height: 4),

            // 🏢 Company Header
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'میاں ٹریڈرز',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(font: regularFont, fontSize: 20),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Whole Sale & Retail Store',
              style: pw.TextStyle(font: regularFont, fontSize: 7),
              textAlign: pw.TextAlign.left,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Sargodha , Bhagtanawala , Kotmomin Road',
              style: pw.TextStyle(font: regularFont, fontSize: 7),
              textAlign: pw.TextAlign.left,
            ),
            pw.Text(
              '0345 4297128',
              style: pw.TextStyle(font: regularFont, fontSize: 7),
              textAlign: pw.TextAlign.left,
            ),
            pw.Text(
              '03009101050',
              style: pw.TextStyle(font: regularFont, fontSize: 7),
              textAlign: pw.TextAlign.left,
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 4),

            // Customer & Date (stacked for narrow width)
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'Customer: ${(invoice.customerName ?? 'N/A').length > 18 ? (invoice.customerName ?? 'N/A').substring(0, 18) : invoice.customerName ?? 'N/A'}',
                textAlign: pw.TextAlign.left,
                textDirection: pw.TextDirection.ltr,
                style: pw.TextStyle(font: regularFont, fontSize: 6),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'Date: ${date.length > 18 ? date.substring(0, 18) : date}',
                textDirection: pw.TextDirection.ltr,
                textAlign: pw.TextAlign.left,
                style: pw.TextStyle(font: regularFont, fontSize: 7),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'Order: #${invoice.displayId ?? invoice.invoiceNo}',
                textDirection: pw.TextDirection.ltr,
                textAlign: pw.TextAlign.left,
                style: pw.TextStyle(font: regularFont, fontSize: 7),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 4),

            // Items Table with wrapping support
            if (items != null && items.isNotEmpty) ...[
              pw.Table(
                border: pw.TableBorder.all(width: 0.3),
                columnWidths: {
                  0: const pw.FixedColumnWidth(80), // Item
                  1: const pw.FixedColumnWidth(30), // Qty
                  2: const pw.FixedColumnWidth(20), // Price
                  3: const pw.FixedColumnWidth(60), // Total
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
                  }),
                ],
              ),
              pw.SizedBox(height: 4),
            ],

            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 3),

            // 💰 Totals Table
            pw.Container(
              width: 200, // Limit width for better centering
              child: pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  // Subtotal
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: pw.Text(
                          'Subtotal',
                          style: pw.TextStyle(font: regularFont, fontSize: 8),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: pw.Text(
                          (invoice.total + invoice.discount).toStringAsFixed(0),
                          style: pw.TextStyle(font: regularFont, fontSize: 8),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Discount (only if > 0)
                  if (invoice.discount > 0)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: pw.Text(
                            'Discount',
                            style: pw.TextStyle(font: regularFont, fontSize: 8),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: pw.Text(
                            invoice.discount.toStringAsFixed(0),
                            style: pw.TextStyle(font: regularFont, fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  // Total
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: pw.Text(
                          'Total',
                          style: pw.TextStyle(font: boldFont, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: pw.Text(
                          invoice.total.toStringAsFixed(0),
                          style: pw.TextStyle(font: boldFont, fontSize: 9),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Paid
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: pw.Text(
                          'Paid',
                          style: pw.TextStyle(font: regularFont, fontSize: 8),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: pw.Text(
                          (invoice.total - invoice.pending).toStringAsFixed(0),
                          style: pw.TextStyle(font: regularFont, fontSize: 8),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Due
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: pw.Text(
                          'Due',
                          style: pw.TextStyle(font: regularFont, fontSize: 8),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: pw.Text(
                          invoice.pending.toStringAsFixed(0),
                          style: pw.TextStyle(font: regularFont, fontSize: 8),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
          ],
        );
      },
    ),
  );

  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final suggestedName =
      'Receipt_${invoice.displayId ?? invoice.invoiceNo}_$timestamp.pdf';

  // Use platform-aware file handling
  final pdfBytes = await pdf.save();
  return await PlatformFileHelper.savePdfFile(
    pdfBytes: pdfBytes,
    suggestedName: suggestedName,
    dialogTitle: 'Save Thermal Receipt',
  );
}

/// ✅ Silent print a thermal receipt (no file save dialog)
/// Returns true on success, false on failure
Future<bool> printSilentThermalReceipt(
  Invoice invoice, {
  List<Map<String, dynamic>>? items,
}) async {
  try {
    logger.info(
      'PDFHelper',
      'Silent printing thermal receipt for #${invoice.displayId ?? invoice.invoiceNo}',
    );

    // Get paper width from settings
    final settingsService = PrinterSettingsService();
    await settingsService.initialize();
    final paperWidthMm = await settingsService.getPaperWidth();

    // Convert mm to points (1mm = 2.8346 points)
    // Common: 58mm ~ 164pt, 80mm ~ 226pt
    final double widthPoints = paperWidthMm * 2.8346;

    // Generate the thermal receipt PDF
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

    final date =
        '${DateHelper.formatIso(invoice.date)}, ${DateFormat('hh:mm a').format(DateTime.tryParse(invoice.date) ?? DateTime.now())}';

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
                    width: widthPoints * 0.4, // 40% of paper width
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

              // Customer & Date
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Customer: ${invoice.customerName ?? 'N/A'}',
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
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Order: #${invoice.displayId ?? invoice.invoiceNo}',
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
                    0: const pw.FlexColumnWidth(2.0), // Product name
                    1: const pw.FlexColumnWidth(0.7), // Qty
                    2: const pw.FlexColumnWidth(1.5), // Price
                    3: const pw.FlexColumnWidth(1.8), // Total
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
                              fontSize: paperWidthMm < 60 ? 5 : 8,
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
                              fontSize: paperWidthMm < 60 ? 5 : 8,
                            ),
                            textAlign: pw.TextAlign.left,
                            softWrap: true,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: pw.Text(
                            'Price',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: paperWidthMm < 60 ? 5 : 8,
                            ),
                            textAlign: pw.TextAlign.left,
                            softWrap: true,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: pw.Text(
                            'Total',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: paperWidthMm < 60 ? 5 : 8,
                            ),
                            textAlign: pw.TextAlign.left,
                            softWrap: true,
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
                                fontSize: paperWidthMm < 60 ? 5 : 9,
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
                                fontSize: paperWidthMm < 60 ? 5 : 8,
                              ),
                              textAlign: pw.TextAlign.center,
                              softWrap: true,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(1),
                            child: pw.Text(
                              price.toStringAsFixed(0),
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: paperWidthMm < 60 ? 5 : 8,
                              ),
                              textAlign: pw.TextAlign.left,
                              softWrap: true,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(1),
                            child: pw.Text(
                              total.toStringAsFixed(0),
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: paperWidthMm < 60 ? 5 : 8,
                              ),
                              textAlign: pw.TextAlign.left,
                              softWrap: true,
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
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            'Total',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: paperWidthMm < 60 ? 8 : 9,
                            ),
                            softWrap: true,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            invoice.total.toStringAsFixed(0),
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: paperWidthMm < 60 ? 8 : 9,
                            ),
                            textAlign: pw.TextAlign.left,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                    if (invoice.discount > 0)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Text(
                              'Discount',
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: paperWidthMm < 60 ? 7 : 8,
                              ),
                              softWrap: true,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Text(
                              invoice.discount.toStringAsFixed(0),
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: paperWidthMm < 60 ? 7 : 8,
                              ),
                              textAlign: pw.TextAlign.left,
                              softWrap: true,
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
                            softWrap: true,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            (invoice.paid).toStringAsFixed(0),
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: paperWidthMm < 60 ? 7 : 8,
                            ),
                            textAlign: pw.TextAlign.left,
                            softWrap: true,
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
                            softWrap: true,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            invoice.pending.toStringAsFixed(0),
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: paperWidthMm < 60 ? 7 : 8,
                            ),
                            textAlign: pw.TextAlign.left,
                            softWrap: true,
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

    // Use centralized thermal printing service for consistent behavior
    final success = await thermalPrinting.printPdfSilently(
      pdfBytes,
      docName: 'Receipt_${invoice.displayId ?? invoice.invoiceNo}',
    );

    if (success) {
      logger.info('PDFHelper', 'Silent thermal print sent successfully');
    } else {
      logger.warning(
        'PDFHelper',
        'Silent thermal print failed or no printer configured',
      );
      // If silent print fails, fall back to layout (shows dialog) so the user can still print
      await Printing.layoutPdf(
        onLayout: (format) => pdfBytes,
        name: 'Receipt_${invoice.displayId ?? invoice.invoiceNo}',
      );
    }
    return true;
  } catch (e, st) {
    logger.error(
      'PDFHelper',
      'Silent thermal print failed',
      error: e,
      stackTrace: st,
    );
    return false;
  }
}

/// ✅ Generate PDF for stock disposal records
Future<File?> generateStockDisposalPdf(dynamic disposal) async {
  logger.info('PDFHelper', 'Generating Stock Disposal PDF for #${disposal.id}');

  final pdf = pw.Document();
  final fonts = await PdfFontHelper.getBothFonts();
  final regularFont = fonts['regular']!;
  final boldFont = fonts['bold']!;

  final date = DateTime.tryParse(disposal.createdAt ?? '') ?? DateTime.now();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.brown100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Stock Disposal Record',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 20,
                      color: PdfColors.brown900,
                    ),
                  ),
                  pw.Text(
                    '#${disposal.id.toString().substring(0, 8)}',
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 14,
                      color: PdfColors.brown700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Product Info
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Product Details',
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Product: ${disposal.productName ?? 'Unknown'}',
                    style: pw.TextStyle(font: regularFont, fontSize: 12),
                  ),
                  pw.Text(
                    'Code: ${disposal.productCode ?? 'N/A'}',
                    style: pw.TextStyle(font: regularFont, fontSize: 12),
                  ),
                  pw.Text(
                    'Batch: ${disposal.batchNo ?? 'N/A'}',
                    style: pw.TextStyle(font: regularFont, fontSize: 12),
                  ),
                  pw.Text(
                    'Quantity: ${disposal.qty}',
                    style: pw.TextStyle(font: regularFont, fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Disposal Info
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Disposal Details',
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Type: ${disposal.disposalType?.toString().toUpperCase() ?? 'N/A'}',
                    style: pw.TextStyle(font: regularFont, fontSize: 12),
                  ),
                  pw.Text(
                    'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(date)}',
                    style: pw.TextStyle(font: regularFont, fontSize: 12),
                  ),
                  pw.Text(
                    'Cost Loss: Rs ${disposal.costLoss?.toStringAsFixed(2) ?? '0.00'}',
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 12,
                      color: PdfColors.red,
                    ),
                  ),
                  if (disposal.notes != null && disposal.notes!.isNotEmpty)
                    pw.Text(
                      'Notes: ${disposal.notes}',
                      style: pw.TextStyle(font: regularFont, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final suggestedName =
      'Disposal_${disposal.id.toString().substring(0, 8)}_$timestamp.pdf';

  final pdfBytes = await pdf.save();
  return await PlatformFileHelper.savePdfFile(
    pdfBytes: pdfBytes,
    suggestedName: suggestedName,
    dialogTitle: 'Save Disposal Record PDF',
  );
}

/// ✅ Generate PDF for purchase records
Future<File?> generatePurchasePdf(
  dynamic purchase,
  List<Map<String, dynamic>> items,
  String supplierName,
) async {
  logger.info(
    'PDFHelper',
    'Generating Purchase PDF for #${purchase.invoiceNo}',
  );

  final pdf = pw.Document();
  final fonts = await PdfFontHelper.getBothFonts();
  final regularFont = fonts['regular']!;
  final boldFont = fonts['bold']!;

  final date = DateTime.tryParse(purchase.date ?? '') ?? DateTime.now();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              gradient: const pw.LinearGradient(
                colors: [PdfColors.green700, PdfColors.green900],
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
                      'Purchase Invoice',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 20,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '#${purchase.invoiceNo}',
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 12,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Supplier Info
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  'Supplier: ',
                  style: pw.TextStyle(font: boldFont, fontSize: 12),
                ),
                pw.Text(
                  supplierName,
                  style: pw.TextStyle(font: regularFont, fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Items Table
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Product', 'Qty', 'Unit Price', 'Total'],
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontSize: 11,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
            cellStyle: pw.TextStyle(font: regularFont, fontSize: 10),
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              2: const pw.FixedColumnWidth(50),
              3: const pw.FixedColumnWidth(80),
              4: const pw.FixedColumnWidth(80),
            },
            data: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final qty = item['qty'] ?? 0;
              final price = item['price'] ?? 0.0;
              final total = qty * price;
              return [
                (index + 1).toString(),
                item['product_name'] ?? 'Unknown',
                qty.toString(),
                'Rs ${price.toStringAsFixed(2)}',
                'Rs ${total.toStringAsFixed(2)}',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 16),

          // Summary
          pw.Container(
            width: 250,
            child: pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Total',
                        style: pw.TextStyle(font: boldFont, fontSize: 12),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Rs ${purchase.total.toStringAsFixed(2)}',
                        style: pw.TextStyle(font: boldFont, fontSize: 12),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Paid',
                        style: pw.TextStyle(font: regularFont, fontSize: 11),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Rs ${purchase.paid.toStringAsFixed(2)}',
                        style: pw.TextStyle(font: regularFont, fontSize: 11),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Pending',
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 11,
                          color: PdfColors.red,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Rs ${purchase.pending.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 11,
                          color: PdfColors.red,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ];
      },
    ),
  );

  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final suggestedName = 'Purchase_${purchase.invoiceNo}_$timestamp.pdf';

  final pdfBytes = await pdf.save();
  return await PlatformFileHelper.savePdfFile(
    pdfBytes: pdfBytes,
    suggestedName: suggestedName,
    dialogTitle: 'Save Purchase PDF',
  );
}

/// ✅ Silent print a stock disposal thermal receipt
/// Returns true on success, false on failure
Future<bool> printSilentStockDisposalThermalReceipt(dynamic disposal) async {
  try {
    logger.info(
      'PDFHelper',
      'Silent printing disposal receipt for #${disposal.id}',
    );

    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    final settingsService = PrinterSettingsService();
    await settingsService.initialize();
    final paperWidthMm = (await settingsService.getPaperWidth()).toDouble();
    final widthPoints = paperWidthMm * ThermalReceiptHelper.mmToPoints;

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(widthPoints, double.infinity),
        margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              ThermalReceiptHelper.buildHeader(
                regularFont: regularFont,
                boldFont: boldFont,
                subHeader: 'Stock Disposal / Return',
              ),
              ThermalReceiptHelper.buildInfoRow(
                'Disposal ID:',
                disposal.id,
                regularFont,
              ),
              ThermalReceiptHelper.buildInfoRow(
                'Type:',
                disposal.disposalType ?? 'N/A',
                regularFont,
              ),
              ThermalReceiptHelper.buildInfoRow(
                'Date:',
                DateHelper.formatIso(disposal.date),
                regularFont,
              ),

              pw.SizedBox(height: 4),
              pw.Container(height: 1, color: PdfColors.black),
              pw.SizedBox(height: 4),

              ThermalReceiptHelper.buildItemsTable(
                data: [
                  [
                    disposal.productName ?? 'Unknown',
                    disposal.qty.toString(),
                    'N/A', // Cost per unit not directly shown in disposal model as a 'price'
                    disposal.costLoss?.toStringAsFixed(0) ?? '0',
                  ],
                ],
                regularFont: regularFont,
                boldFont: boldFont,
                paperWidthMm: paperWidthMm,
              ),

              pw.SizedBox(height: 4),
              pw.Container(height: 1, color: PdfColors.black),
              pw.SizedBox(height: 4),

              ThermalReceiptHelper.buildTotalsTable(
                rows: [
                  ['Cost Loss', disposal.costLoss?.toStringAsFixed(0) ?? '0'],
                  if (disposal is StockDisposal && disposal.refundAmount > 0)
                    ['Refund', disposal.refundAmount.toStringAsFixed(0)],
                ],
                regularFont: regularFont,
                boldFont: boldFont,
                paperWidthMm: paperWidthMm,
              ),
              ThermalReceiptHelper.buildFooter(boldFont),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    return await thermalPrinting.printPdfSilently(
      pdfBytes,
      docName: 'Disposal_${disposal.id}',
    );
  } catch (e, st) {
    logger.error(
      'PDFHelper',
      'Silent disposal print failed',
      error: e,
      stackTrace: st,
    );
    return false;
  }
}

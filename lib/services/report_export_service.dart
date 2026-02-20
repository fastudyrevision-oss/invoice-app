import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart'; // Fix for PdfColors
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
// Import your report models
import 'package:invoice_app/models/reports/supplier_report.dart';
import 'package:invoice_app/models/reports/product_report.dart';
import 'package:invoice_app/models/reports/expense_report.dart';
import 'package:invoice_app/models/reports/expiry_report.dart';
import 'package:invoice_app/models/reports/payment_report.dart';
import 'package:invoice_app/models/reports/combined_payment_entry.dart';
import '../utils/unified_print_helper.dart';
import '../utils/pdf_font_helper.dart';
import '../utils/date_helper.dart';
import '../services/logger_service.dart';

class ReportExportService {
  // Use DateHelper via this getter or directly
  String _formatDate(DateTime dt) => DateHelper.formatDate(dt);

  // =====================================================
  Future<void> exportSupplierReportPdf(List<SupplierReport> reports) async {
    LoggerService.instance.info(
      'ReportExport',
      'Exporting Supplier Report PDF',
      context: {'count': reports.length},
    );
    final pdf = pw.Document();
    // Load fonts
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Supplier', 'Total Purchases', 'Paid', 'Balance'],
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(font: regularFont),
            data: reports
                .map(
                  (r) => [
                    r.supplierName,
                    r.totalPurchases.toStringAsFixed(2),
                    r.totalPaid.toStringAsFixed(2),
                    r.balance.toStringAsFixed(2),
                  ],
                )
                .toList(),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> exportProductReportPdf(List<ProductReport> reports) async {
    LoggerService.instance.info(
      'ReportExport',
      'Exporting Product Report PDF',
      context: {'count': reports.length},
    );
    final pdf = pw.Document();
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Product', 'Qty Purchased', 'Total Spent'],
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(font: regularFont),
            data: reports
                .map(
                  (r) => [
                    r.productName,
                    r.totalQtyPurchased.toStringAsFixed(0),
                    r.totalSpent.toStringAsFixed(2),
                  ],
                )
                .toList(),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> exportExpenseReportPdf(List<ExpenseReport> reports) async {
    LoggerService.instance.info(
      'ReportExport',
      'Exporting Expense Report PDF',
      context: {'count': reports.length},
    );
    final pdf = pw.Document();
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Category', 'Total Spent'],
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(font: regularFont),
            data: reports
                .map((r) => [r.category, r.totalSpent.toStringAsFixed(2)])
                .toList(),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> exportExpiryReportPdf(List<ExpiryReport> reports) async {
    LoggerService.instance.info(
      'ReportExport',
      'Exporting Expiry Report PDF',
      context: {'count': reports.length},
    );
    final pdf = pw.Document();
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Product', 'Batch', 'Expiry Date', 'Qty'],
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(font: regularFont),
            data: reports
                .map(
                  (r) => [
                    r.productName,
                    r.batchNo,
                    _formatDate(r.expiryDate),
                    r.qty.toStringAsFixed(0),
                  ],
                )
                .toList(),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> exportPaymentReportPdf(List<PaymentReport> reports) async {
    LoggerService.instance.info(
      'ReportExport',
      'Exporting Payment Report PDF',
      context: {'count': reports.length},
    );
    final pdf = pw.Document();
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Supplier', 'Reference', 'Debit', 'Credit', 'Date'],
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(font: regularFont),
            data: reports
                .map(
                  (r) => [
                    r.supplierName,
                    r.reference,
                    r.debit.toStringAsFixed(2),
                    r.credit.toStringAsFixed(2),
                    _formatDate(r.date),
                  ],
                )
                .toList(),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> exportCombinedCashFlowPdf(
    List<CombinedPaymentEntry> entries,
  ) async {
    final pdf = pw.Document();
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    // Calculate totals
    double totalIn = 0;
    double totalOut = 0;

    for (var e in entries) {
      totalIn += e.moneyIn;
      totalOut += e.moneyOut;
    }
    final net = totalIn - totalOut;

    pdf.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Cash Flow Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      font: boldFont,
                    ),
                  ),
                  pw.Text(
                    _formatDate(DateTime.now()),
                    style: pw.TextStyle(font: regularFont),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            // Summary Table
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Total Money In', 'Total Money Out', 'Net Cash Flow'],
              headerStyle: pw.TextStyle(
                font: boldFont,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: pw.TextStyle(font: regularFont),
              data: [
                [
                  totalIn.toStringAsFixed(2),
                  totalOut.toStringAsFixed(2),
                  net.toStringAsFixed(2),
                ],
              ],
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
            ),
            pw.SizedBox(height: 20),
            // Detailed Table
            pw.TableHelper.fromTextArray(
              context: context,
              headers: [
                'Date',
                'Type',
                'Name',
                'Reference',
                'Money Out',
                'Money In',
              ],
              headerStyle: pw.TextStyle(
                font: boldFont,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: pw.TextStyle(font: regularFont),
              data: entries
                  .map(
                    (e) => [
                      _formatDate(e.date),
                      e.type.toUpperCase(),
                      e.entityName,
                      e.reference,
                      e.moneyOut > 0 ? e.moneyOut.toStringAsFixed(2) : '-',
                      e.moneyIn > 0 ? e.moneyIn.toStringAsFixed(2) : '-',
                    ],
                  )
                  .toList(),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
            ),
          ];
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // =====================================================
  // -------------------- DIRECT PRINT METHODS -----------
  // =====================================================

  /// Print supplier report directly to printer
  Future<void> printSupplierReport(List<SupplierReport> reports) async {
    final pdfBytes = await _generateSupplierReportPdf(reports);
    await UnifiedPrintHelper.printPdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Supplier_Report_${_formatDate(DateTime.now())}.pdf',
    );
  }

  /// Print product report directly to printer
  Future<void> printProductReport(List<ProductReport> reports) async {
    final pdfBytes = await _generateProductReportPdf(reports);
    await UnifiedPrintHelper.printPdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Product_Report_${_formatDate(DateTime.now())}.pdf',
    );
  }

  /// Print expense report directly to printer
  Future<void> printExpenseReport(List<ExpenseReport> reports) async {
    final pdfBytes = await _generateExpenseReportPdf(reports);
    await UnifiedPrintHelper.printPdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Expense_Report_${_formatDate(DateTime.now())}.pdf',
    );
  }

  /// Print expiry report directly to printer
  Future<void> printExpiryReport(List<ExpiryReport> reports) async {
    final pdfBytes = await _generateExpiryReportPdf(reports);
    await UnifiedPrintHelper.printPdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Expiry_Report_${_formatDate(DateTime.now())}.pdf',
    );
  }

  /// Print payment report directly to printer
  Future<void> printPaymentReport(List<PaymentReport> reports) async {
    final pdfBytes = await _generatePaymentReportPdf(reports);
    await UnifiedPrintHelper.printPdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Payment_Report_${_formatDate(DateTime.now())}.pdf',
    );
  }

  /// Print combined cash flow report directly to printer
  Future<void> printCombinedCashFlowReport(
    List<CombinedPaymentEntry> entries,
  ) async {
    final pdfBytes = await _generateCombinedCashFlowPdf(entries);
    await UnifiedPrintHelper.printPdfBytes(
      pdfBytes: pdfBytes,
      filename: 'Cash_Flow_Report_${_formatDate(DateTime.now())}.pdf',
    );
  }

  // =====================================================
  // -------------------- SAVE PDF METHODS ---------------
  // =====================================================

  /// Save supplier report PDF to file
  Future<File?> saveSupplierReportPdf(List<SupplierReport> reports) async {
    final pdfBytes = await _generateSupplierReportPdf(reports);
    return await UnifiedPrintHelper.savePdfBytes(
      pdfBytes: pdfBytes,
      suggestedName: 'Supplier_Report_${_formatDate(DateTime.now())}.pdf',
      dialogTitle: 'Save Supplier Report',
    );
  }

  /// Save product report PDF to file
  Future<File?> saveProductReportPdf(List<ProductReport> reports) async {
    final pdfBytes = await _generateProductReportPdf(reports);
    return await UnifiedPrintHelper.savePdfBytes(
      pdfBytes: pdfBytes,
      suggestedName: 'Product_Report_${_formatDate(DateTime.now())}.pdf',
      dialogTitle: 'Save Product Report',
    );
  }

  /// Save expense report PDF to file
  Future<File?> saveExpenseReportPdf(List<ExpenseReport> reports) async {
    final pdfBytes = await _generateExpenseReportPdf(reports);
    return await UnifiedPrintHelper.savePdfBytes(
      pdfBytes: pdfBytes,
      suggestedName: 'Expense_Report_${_formatDate(DateTime.now())}.pdf',
      dialogTitle: 'Save Expense Report',
    );
  }

  /// Save expiry report PDF to file
  Future<File?> saveExpiryReportPdf(List<ExpiryReport> reports) async {
    final pdfBytes = await _generateExpiryReportPdf(reports);
    return await UnifiedPrintHelper.savePdfBytes(
      pdfBytes: pdfBytes,
      suggestedName: 'Expiry_Report_${_formatDate(DateTime.now())}.pdf',
      dialogTitle: 'Save Expiry Report',
    );
  }

  /// Save payment report PDF to file
  Future<File?> savePaymentReportPdf(List<PaymentReport> reports) async {
    final pdfBytes = await _generatePaymentReportPdf(reports);
    return await UnifiedPrintHelper.savePdfBytes(
      pdfBytes: pdfBytes,
      suggestedName: 'Payment_Report_${_formatDate(DateTime.now())}.pdf',
      dialogTitle: 'Save Payment Report',
    );
  }

  /// Save combined cash flow report PDF to file
  Future<File?> saveCombinedCashFlowPdf(
    List<CombinedPaymentEntry> entries,
  ) async {
    final pdfBytes = await _generateCombinedCashFlowPdf(entries);
    return await UnifiedPrintHelper.savePdfBytes(
      pdfBytes: pdfBytes,
      suggestedName: 'Cash_Flow_Report_${_formatDate(DateTime.now())}.pdf',
      dialogTitle: 'Save Cash Flow Report',
    );
  }

  // =====================================================
  // -------------------- PRIVATE PDF GENERATORS ---------
  // =====================================================

  /// Generate supplier report PDF bytes
  Future<Uint8List> _generateSupplierReportPdf(
    List<SupplierReport> reports,
  ) async {
    final pdf = pw.Document();
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Supplier', 'Total Purchases', 'Paid', 'Balance'],
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(font: regularFont),
            data: reports
                .map(
                  (r) => [
                    r.supplierName,
                    r.totalPurchases.toStringAsFixed(2),
                    r.totalPaid.toStringAsFixed(2),
                    r.balance.toStringAsFixed(2),
                  ],
                )
                .toList(),
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// Generate product report PDF bytes
  Future<Uint8List> _generateProductReportPdf(
    List<ProductReport> reports,
  ) async {
    final pdf = pw.Document();
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Product', 'Qty Purchased', 'Total Spent'],
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(font: regularFont),
            data: reports
                .map(
                  (r) => [
                    r.productName,
                    r.totalQtyPurchased.toStringAsFixed(0),
                    r.totalSpent.toStringAsFixed(2),
                  ],
                )
                .toList(),
          );
        },
      ),
    );
    return await pdf.save();
  }

  /// Generate expense report PDF bytes
  Future<Uint8List> _generateExpenseReportPdf(
    List<ExpenseReport> reports,
  ) async {
    final pdf = pw.Document();
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Category', 'Total Spent'],
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(font: regularFont),
            data: reports
                .map((r) => [r.category, r.totalSpent.toStringAsFixed(2)])
                .toList(),
          );
        },
      ),
    );
    return await pdf.save();
  }

  /// Generate expiry report PDF bytes
  Future<Uint8List> _generateExpiryReportPdf(List<ExpiryReport> reports) async {
    final pdf = pw.Document();
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Product', 'Batch', 'Expiry Date', 'Qty'],
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(font: regularFont),
            data: reports
                .map(
                  (r) => [
                    r.productName,
                    r.batchNo,
                    _formatDate(r.expiryDate),
                    r.qty.toStringAsFixed(0),
                  ],
                )
                .toList(),
          );
        },
      ),
    );
    return await pdf.save();
  }

  /// Generate payment report PDF bytes
  Future<Uint8List> _generatePaymentReportPdf(
    List<PaymentReport> reports,
  ) async {
    final pdf = pw.Document();
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Supplier', 'Reference', 'Debit', 'Credit', 'Date'],
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(font: regularFont),
            data: reports
                .map(
                  (r) => [
                    r.supplierName,
                    r.reference,
                    r.debit.toStringAsFixed(2),
                    r.credit.toStringAsFixed(2),
                    _formatDate(r.date),
                  ],
                )
                .toList(),
          );
        },
      ),
    );
    return await pdf.save();
  }

  /// Generate combined cash flow report PDF bytes
  Future<Uint8List> _generateCombinedCashFlowPdf(
    List<CombinedPaymentEntry> entries,
  ) async {
    final pdf = pw.Document();
    final fonts = await PdfFontHelper.getBothFonts();
    final regularFont = fonts['regular']!;
    final boldFont = fonts['bold']!;

    // Load Logo
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      LoggerService.instance.warning(
        'ReportExport',
        'Could not load logo for PDF',
        error: e,
      );
    }

    // Calculate totals
    double totalIn = 0;
    double totalOut = 0;

    for (var e in entries) {
      totalIn += e.moneyIn;
      totalOut += e.moneyOut;
    }
    final net = totalIn - totalOut;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            // Header
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(width: 1, color: PdfColors.grey300),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 10),
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 60,
                      height: 60,
                      margin: const pw.EdgeInsets.only(right: 15),
                      child: pw.Image(logoImage),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Urdu Title
                        pw.Text(
                          'میاں ٹریڈرز', // Mian Traders
                          textDirection: pw.TextDirection.rtl,
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Cash Flow Report',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 16,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date: ${_formatDate(DateTime.now())}',
                        style: pw.TextStyle(font: regularFont, fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: net >= 0 ? PdfColors.green50 : PdfColors.red50,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(
                            color: net >= 0 ? PdfColors.green : PdfColors.red,
                            width: 0.5,
                          ),
                        ),
                        child: pw.Text(
                          'Net: ${net.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            font: boldFont,
                            color: net >= 0
                                ? PdfColors.green900
                                : PdfColors.red900,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Summary Table
            pw.Text(
              "Summary",
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
            pw.SizedBox(height: 5),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Total Money In', 'Total Money Out', 'Net Cash Flow'],
              headerStyle: pw.TextStyle(
                font: boldFont,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey700,
              ),
              cellStyle: pw.TextStyle(font: regularFont),
              cellAlignment: pw.Alignment.centerRight, // Right align numbers
              data: [
                [
                  totalIn.toStringAsFixed(2),
                  totalOut.toStringAsFixed(2),
                  net.toStringAsFixed(2),
                ],
              ],
            ),
            pw.SizedBox(height: 20),

            // Detailed Table
            pw.Text(
              "Transactions",
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
            pw.SizedBox(height: 5),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: [
                'Date',
                'Type',
                'Name',
                'Reference',
                'Money Out',
                'Money In',
              ],
              columnWidths: {
                0: const pw.FixedColumnWidth(60), // Date
                1: const pw.FixedColumnWidth(50), // Type
                2: const pw.FlexColumnWidth(2), // Name
                3: const pw.FlexColumnWidth(1.5), // Ref
                4: const pw.FixedColumnWidth(60), // Out
                5: const pw.FixedColumnWidth(60), // In
              },
              headerStyle: pw.TextStyle(
                font: boldFont,
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey700,
              ),
              cellStyle: pw.TextStyle(font: regularFont, fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              data: entries
                  .map(
                    (e) => [
                      _formatDate(e.date),
                      e.type.toUpperCase(),
                      e.entityName,
                      e.reference.length > 20
                          ? '${e.reference.substring(0, 17)}...'
                          : e.reference,
                      e.moneyOut > 0 ? e.moneyOut.toStringAsFixed(2) : '-',
                      e.moneyIn > 0 ? e.moneyIn.toStringAsFixed(2) : '-',
                    ],
                  )
                  .toList(),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
              ),
            ),
          ];
        },
      ),
    );
    return await pdf.save();
  }

  // =====================================================
  // -------------------- CSV EXPORTS --------------------
  // =====================================================

  Future<File> exportSupplierReportCsv(
    List<SupplierReport> reports,
    String path,
  ) async {
    final rows = [
      ['Supplier', 'Total Purchases', 'Paid', 'Balance'],
      ...reports.map(
        (r) => [r.supplierName, r.totalPurchases, r.totalPaid, r.balance],
      ),
    ];
    return _writeCsv(rows, path);
  }

  Future<File> exportProductReportCsv(
    List<ProductReport> reports,
    String path,
  ) async {
    final rows = [
      ['Product', 'Qty Purchased', 'Total Spent'],
      ...reports.map((r) => [r.productName, r.totalQtyPurchased, r.totalSpent]),
    ];
    return _writeCsv(rows, path);
  }

  Future<File> exportExpenseReportCsv(
    List<ExpenseReport> reports,
    String path,
  ) async {
    final rows = [
      ['Category', 'Total Spent'],
      ...reports.map((r) => [r.category, r.totalSpent]),
    ];
    return _writeCsv(rows, path);
  }

  Future<File> exportExpiryReportCsv(
    List<ExpiryReport> reports,
    String path,
  ) async {
    final rows = [
      ['Product', 'Batch', 'Expiry Date', 'Qty'],
      ...reports.map(
        (r) => [r.productName, r.batchNo, _formatDate(r.expiryDate), r.qty],
      ),
    ];
    return _writeCsv(rows, path);
  }

  Future<File> exportPaymentReportCsv(
    List<PaymentReport> reports,
    String path,
  ) async {
    final rows = [
      ['Supplier', 'Reference', 'Debit', 'Credit', 'Date'],
      ...reports.map(
        (r) => [
          r.supplierName,
          r.reference,
          r.debit,
          r.credit,
          _formatDate(r.date),
        ],
      ),
    ];
    return _writeCsv(rows, path);
  }

  // =====================================================
  // -------------------- EXCEL EXPORTS ------------------
  // =====================================================

  Future<File> exportSupplierReportExcel(
    List<SupplierReport> reports,
    String path,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Suppliers'];
    sheet.appendRow(['Supplier', 'Total Purchases', 'Paid', 'Balance']);
    for (final r in reports) {
      sheet.appendRow([
        r.supplierName,
        r.totalPurchases,
        r.totalPaid,
        r.balance,
      ]);
    }
    return _writeExcel(excel, path);
  }

  Future<File> exportProductReportExcel(
    List<ProductReport> reports,
    String path,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Products'];
    sheet.appendRow(['Product', 'Qty Purchased', 'Total Spent']);
    for (final r in reports) {
      sheet.appendRow([r.productName, r.totalQtyPurchased, r.totalSpent]);
    }
    return _writeExcel(excel, path);
  }

  Future<File> exportExpenseReportExcel(
    List<ExpenseReport> reports,
    String path,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Expenses'];
    sheet.appendRow(['Category', 'Total Spent']);
    for (final r in reports) {
      sheet.appendRow([r.category, r.totalSpent]);
    }
    return _writeExcel(excel, path);
  }

  Future<File?> exportExpiryReportExcel(List<ExpiryReport> reports) async {
    //Asking the user where to save the file

    // Ask user where to save the file
    final saveLocation = await getSaveLocation(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
      suggestedName: 'expiry_report.xlsx',
    );

    // User canceled
    if (saveLocation == null) return null;
    final excel = Excel.createExcel();
    final sheet = excel['Expiry'];
    sheet.appendRow(['Product', 'Batch', 'Expiry Date', 'Qty']);
    for (final r in reports) {
      sheet.appendRow([
        r.productName,
        r.batchNo,
        _formatDate(r.expiryDate),
        r.qty,
      ]);
    }
    return _writeExcelToLocation(excel, saveLocation);
  }

  Future<File> exportPaymentReportExcel(
    List<PaymentReport> reports,
    String path,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Payments'];
    sheet.appendRow(['Supplier', 'Reference', 'Debit', 'Credit', 'Date']);
    for (final r in reports) {
      sheet.appendRow([
        r.supplierName,
        r.reference,
        r.debit,
        r.credit,
        _formatDate(r.date),
      ]);
    }
    return _writeExcel(excel, path);
  }

  // =====================================================
  // -------------------- HELPERS ------------------------
  // =====================================================

  Future<File> _writeCsv(List<List<dynamic>> rows, String path) async {
    final csvData = const ListToCsvConverter().convert(rows);
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsString(csvData);
    return file;
  }

  Future<File> _writeExcel(Excel excel, String path) async {
    final file = File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);
    return file;
  }

  // For FileSaveLocation (file_selector dialog)
  Future<File> _writeExcelToLocation(
    Excel excel,
    FileSaveLocation location,
  ) async {
    final file = File(location.path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);
    return file;
  }
}

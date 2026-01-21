import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart'; // Fix for PdfColors
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart' show rootBundle;
// Import your report models
import 'package:invoice_app/models/reports/supplier_report.dart';
import 'package:invoice_app/models/reports/product_report.dart';
import 'package:invoice_app/models/reports/expense_report.dart';
import 'package:invoice_app/models/reports/expiry_report.dart';
import 'package:invoice_app/models/reports/payment_report.dart';
import 'package:invoice_app/models/reports/combined_payment_entry.dart';
import '../utils/pdf_font_helper.dart';

class ReportExportService {
  final _dateFmt = DateFormat('yyyy-MM-dd');

  // =====================================================
  // -------------------- PDF EXPORTS --------------------
  // =====================================================

  Future<void> exportSupplierReportPdf(List<SupplierReport> reports) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Supplier', 'Total Purchases', 'Paid', 'Balance'],
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
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Product', 'Qty Purchased', 'Total Spent'],
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
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Category', 'Total Spent'],
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
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Product', 'Batch', 'Expiry Date', 'Qty'],
            data: reports
                .map(
                  (r) => [
                    r.productName,
                    r.batchNo,
                    _dateFmt.format(r.expiryDate),
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
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.TableHelper.fromTextArray(
            headers: ['Supplier', 'Reference', 'Debit', 'Credit', 'Date'],
            data: reports
                .map(
                  (r) => [
                    r.supplierName,
                    r.reference,
                    r.debit.toStringAsFixed(2),
                    r.credit.toStringAsFixed(2),
                    _dateFmt.format(r.date),
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
                    ),
                  ),
                  pw.Text(_dateFmt.format(DateTime.now())),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            // Summary Table
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Total Money In', 'Total Money Out', 'Net Cash Flow'],
              data: [
                [
                  totalIn.toStringAsFixed(2),
                  totalOut.toStringAsFixed(2),
                  net.toStringAsFixed(2),
                ],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
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
              data: entries
                  .map(
                    (e) => [
                      _dateFmt.format(e.date),
                      e.type.toUpperCase(),
                      e.entityName,
                      e.reference,
                      e.moneyOut > 0 ? e.moneyOut.toStringAsFixed(2) : '-',
                      e.moneyIn > 0 ? e.moneyIn.toStringAsFixed(2) : '-',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
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
        (r) => [r.productName, r.batchNo, _dateFmt.format(r.expiryDate), r.qty],
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
          _dateFmt.format(r.date),
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
        _dateFmt.format(r.expiryDate),
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
        _dateFmt.format(r.date),
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

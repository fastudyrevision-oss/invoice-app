import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../data/models/profit_loss_summary.dart';
import '../data/models/category_profit.dart';
import '../data/models/product_profit.dart';

class ProfitLossPdfService {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'Rs. ',
  );
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  static Future<String?> generateReport({
    required String title,
    required ProfitLossSummary summary,
    List<CategoryProfit>? categories,
    List<ProductProfit>? products,
    required Map<String, bool> sections,
    DateTimeRange? dateRange,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(title, dateRange),
            pw.SizedBox(height: 20),
            if (sections['summary'] ?? true) _buildSummarySection(summary),
            if (sections['expenses'] ?? true)
              _buildExpensesSection(summary.expenseBreakdown),
            if (sections['categories'] ?? false)
              _buildCategoriesSection(categories ?? []),
            if (sections['products'] ?? false)
              _buildProductsSection(products ?? []),
            _buildFooter(),
          ];
        },
      ),
    );

    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'PL_Report_$timestamp.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      return file.path;
    } catch (e) {
      return null;
    }
  }

  static pw.Widget _buildHeader(String title, DateTimeRange? range) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 4),
        if (range != null)
          pw.Text(
            'Period: ${DateFormat('yyyy-MM-dd').format(range.start)} to ${DateFormat('yyyy-MM-dd').format(range.end)}',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
        pw.Text(
          'Generated on: ${_dateFormat.format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.Divider(thickness: 2, color: PdfColors.blue900),
      ],
    );
  }

  static pw.Widget _buildSummarySection(ProfitLossSummary summary) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: 'Financial Summary'),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            children: [
              _buildSummaryRow(
                'Total Sales (Income)',
                summary.totalSales,
                isPositive: true,
              ),
              _buildSummaryRow(
                'Cost of Goods Sold (COGS)',
                summary.totalCostOfGoods,
                isNegative: true,
              ),
              pw.Divider(),
              _buildSummaryRow(
                'Gross Profit',
                summary.grossProfit,
                isBold: true,
              ),
              _buildSummaryRow(
                'Operating Expenses',
                summary.totalExpenses,
                isNegative: true,
              ),
              _buildSummaryRow(
                'Expired Stock Loss (Net)',
                summary.netExpiredLoss,
                isNegative: true,
              ),
              pw.Divider(thickness: 2),
              _buildSummaryRow(
                'NET PROFIT / LOSS',
                summary.netProfit,
                isBold: true,
                color: summary.netProfit >= 0
                    ? PdfColors.green900
                    : PdfColors.red900,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildExpensesSection(Map<String, double> breakdown) {
    if (breakdown.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: 'Expense Breakdown'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Category',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Amount',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
            ...breakdown.entries.map(
              (e) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(e.key),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      _currencyFormat.format(e.value),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildCategoriesSection(List<CategoryProfit> categories) {
    if (categories.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: 'Category Profitability'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Category',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Sales',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Profit',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
            ...categories.map(
              (c) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(c.name),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      _currencyFormat.format(c.totalSales),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      _currencyFormat.format(c.profit),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        color: c.profit >= 0 ? PdfColors.green : PdfColors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildProductsSection(List<ProductProfit> products) {
    if (products.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: 'Product Performance (Top 20)'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Product',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Qty',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Sales',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Profit',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
            ...products
                .take(20)
                .map(
                  (p) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(p.name),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          p.totalSoldQty.toString(),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          _currencyFormat.format(p.totalSales),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          _currencyFormat.format(p.profit),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            color: p.profit >= 0
                                ? PdfColors.green
                                : PdfColors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildSummaryRow(
    String label,
    double value, {
    bool isBold = false,
    bool isPositive = false,
    bool isNegative = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: 12,
            ),
          ),
          pw.Text(
            '${isNegative
                ? "- "
                : isPositive
                ? "+ "
                : ""}${_currencyFormat.format(value.abs())}',
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: 12,
              color:
                  color ??
                  (isNegative
                      ? PdfColors.red
                      : isPositive
                      ? PdfColors.green
                      : null),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Container(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Stock & Invoice Management System - Confidential Report',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ),
      ],
    );
  }
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  DateTimeRange({required this.start, required this.end});
}

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ThermalReceiptHelper {
  static const double mmToPoints = 2.8346;

  /// Standardizes the thermal receipt header (Company Name in Urdu and English)
  static pw.Widget buildHeader({
    required pw.Font regularFont,
    required pw.Font boldFont,
    String? companyNameUrdu = 'میاں ٹریڈرز',
    String? subHeader = 'Wholesale and Retail Store',
    String? address = 'Kotmomi road ,Bhagtanawala, Sargodha',
    String? phone = '+92 345 4297128',
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (companyNameUrdu != null)
          pw.Center(
            child: pw.Text(
              companyNameUrdu,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: regularFont, fontSize: 14),
              textAlign: pw.TextAlign.center,
            ),
          ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            subHeader!,
            style: pw.TextStyle(font: regularFont, fontSize: 9),
            textAlign: pw.TextAlign.center,
          ),
        ),
        if (address != null) ...[
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              address,
              style: pw.TextStyle(font: regularFont, fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
        if (phone != null) ...[
          pw.Center(
            child: pw.Text(
              phone,
              style: pw.TextStyle(font: regularFont, fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
        pw.SizedBox(height: 4),
        pw.Container(height: 0.5, color: PdfColors.black),
        pw.SizedBox(height: 4),
      ],
    );
  }

  /// Builds a standard key-value info row (e.g., Customer: John Doe)
  static pw.Widget buildInfoRow(
    String label,
    String value,
    pw.Font font, {
    double fontSize = 8,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: fontSize),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: font, fontSize: fontSize),
              textAlign: pw.TextAlign.right,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the standard items table with wrapping support
  static pw.Widget buildItemsTable({
    required List<List<String>> data,
    required pw.Font regularFont,
    required pw.Font boldFont,
    double paperWidthMm = 80,
  }) {
    final fontSize = paperWidthMm < 60 ? 5.0 : 6.0;

    return pw.Table(
      border: pw.TableBorder.all(width: 0.3),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5), // Item Name
        1: const pw.FlexColumnWidth(0.8), // Qty
        2: const pw.FlexColumnWidth(1.2), // Price
        3: const pw.FlexColumnWidth(1.5), // Total
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableHeader('Item', boldFont, fontSize, pw.TextAlign.left),
            _buildTableHeader('Qty', boldFont, fontSize, pw.TextAlign.center),
            _buildTableHeader('Price', boldFont, fontSize, pw.TextAlign.right),
            _buildTableHeader('Total', boldFont, fontSize, pw.TextAlign.right),
          ],
        ),
        // Data Rows
        ...data.map((row) {
          return pw.TableRow(
            children: [
              _buildTableCell(row[0], regularFont, fontSize, pw.TextAlign.left),
              _buildTableCell(
                row[1],
                regularFont,
                fontSize,
                pw.TextAlign.center,
              ),
              _buildTableCell(
                row[2],
                regularFont,
                fontSize,
                pw.TextAlign.right,
              ),
              _buildTableCell(
                row[3],
                regularFont,
                fontSize,
                pw.TextAlign.right,
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Builds the totals section (Subtotal, Tax, Discount, Total, etc.)
  static pw.Widget buildTotalsTable({
    required List<List<String>> rows,
    required pw.Font regularFont,
    required pw.Font boldFont,
    double paperWidthMm = 80,
  }) {
    final fontSize = paperWidthMm < 60 ? 5.0 : 6.0;

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 100, // Fixed width for totals section
        child: pw.Table(
          border: pw.TableBorder.all(width: 0.3),
          children: rows.map((row) {
            final isLast = rows.last == row;
            return pw.TableRow(
              decoration: isLast
                  ? const pw.BoxDecoration(color: PdfColors.grey200)
                  : null,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(1),
                  child: pw.Text(
                    row[0],
                    style: pw.TextStyle(
                      font: isLast ? boldFont : regularFont,
                      fontSize: isLast ? fontSize + 1 : fontSize,
                    ),
                    softWrap: true,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(1),
                  child: pw.Text(
                    row[1],
                    style: pw.TextStyle(
                      font: isLast ? boldFont : regularFont,
                      fontSize: isLast ? fontSize + 1 : fontSize,
                    ),
                    textAlign: pw.TextAlign.right,
                    softWrap: true,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Builds the receipt footer
  static pw.Widget buildFooter(pw.Font font) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 4),
        pw.Container(height: 0.5, color: PdfColors.black),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'Thank You!',
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'See You Again',
            style: pw.TextStyle(font: font, fontSize: 7),
          ),
        ),
      ],
    );
  }

  // Private Helper: Table Header Cell
  static pw.Widget _buildTableHeader(
    String text,
    pw.Font font,
    double fontSize,
    pw.TextAlign align,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(1),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: fontSize),
        textAlign: align,
      ),
    );
  }

  // Private Helper: Table Data Cell
  static pw.Widget _buildTableCell(
    String text,
    pw.Font font,
    double fontSize,
    pw.TextAlign align,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(1),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: fontSize),
        textAlign: align,
        softWrap: true,
      ),
    );
  }
}

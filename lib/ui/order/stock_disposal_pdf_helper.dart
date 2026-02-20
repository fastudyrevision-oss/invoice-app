import 'dart:io';
import '../order/pdf_export_helper.dart';
import '../../models/stock_disposal.dart';

/// ♻️ Adapter for Stock Disposal PDF generation
/// Uses the unified engine from pdf_export_helper.dart
class StockDisposalPdfHelper {
  /// Generate A4 PDF for a search/list of disposals (placeholder for bulk report)
  static Future<File?> generateDisposalReport(
    List<StockDisposal> disposals,
  ) async {
    // This could call a specialized report generator in the future
    return null;
  }

  /// Generate PDF for a single disposal
  static Future<File?> generateDisposalPdf(StockDisposal disposal) async {
    return await generateStockDisposalPdf(disposal);
  }

  /// Print thermal receipt for stock disposal
  static Future<bool> printThermalReceipt(StockDisposal disposal) async {
    return await printSilentStockDisposalThermalReceipt(disposal);
  }
}

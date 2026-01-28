import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'platform_file_helper.dart';

/// 🖨️ Unified Print Helper
///
/// Centralized utility for all printing operations to avoid code duplication.
/// Supports:
/// - Direct printing to thermal/network printers
/// - Saving PDFs with file picker
/// - Sharing PDFs
/// - Print dialog (system print)
class UnifiedPrintHelper {
  /// Print PDF bytes directly to printer (opens print dialog)
  ///
  /// Use this for direct printing to configured printers.
  /// Works with USB thermal printers and network printers.
  static Future<void> printPdfBytes({
    required Uint8List pdfBytes,
    required String filename,
  }) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: filename,
      );
    } catch (e) {
      debugPrint('❌ Error printing: $e');
      rethrow;
    }
  }

  /// Save PDF bytes to file using file picker
  ///
  /// Opens a file picker dialog for the user to choose save location.
  /// Returns the saved file or null if user cancelled.
  static Future<File?> savePdfBytes({
    required Uint8List pdfBytes,
    required String suggestedName,
    String? dialogTitle,
  }) async {
    try {
      return await PlatformFileHelper.savePdfFile(
        pdfBytes: pdfBytes,
        suggestedName: suggestedName,
        dialogTitle: dialogTitle ?? 'Save PDF',
      );
    } catch (e) {
      debugPrint('❌ Error saving PDF: $e');
      rethrow;
    }
  }

  /// Share PDF bytes (Android/iOS) or open print dialog (Desktop)
  ///
  /// Platform-aware sharing:
  /// - Mobile: Opens share sheet
  /// - Desktop: Opens print dialog
  static Future<void> sharePdfBytes({
    required Uint8List pdfBytes,
    required String filename,
  }) async {
    try {
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (e) {
      debugPrint('❌ Error sharing PDF: $e');
      rethrow;
    }
  }

  /// Print a PDF file directly
  ///
  /// Reads the file and sends to printer.
  static Future<void> printPdfFile(File pdfFile) async {
    if (await pdfFile.exists()) {
      final bytes = await pdfFile.readAsBytes();
      await printPdfBytes(
        pdfBytes: bytes,
        filename: pdfFile.path.split(Platform.pathSeparator).last,
      );
    } else {
      throw Exception('PDF file not found: ${pdfFile.path}');
    }
  }

  /// Share or print a PDF file
  ///
  /// Reads the file and shares/prints it.
  static Future<void> shareOrPrintPdfFile(File pdfFile) async {
    if (await pdfFile.exists()) {
      final bytes = await pdfFile.readAsBytes();
      await sharePdfBytes(
        pdfBytes: bytes,
        filename: pdfFile.path.split(Platform.pathSeparator).last,
      );
    } else {
      throw Exception('PDF file not found: ${pdfFile.path}');
    }
  }

  /// Show print options dialog
  ///
  /// Displays a dialog with options: Print, Save PDF, Share
  /// Returns the selected action or null if cancelled.
  static Future<PrintAction?> showPrintOptionsDialog(
    BuildContext context, {
    String title = 'Export Options',
  }) async {
    return showDialog<PrintAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print, color: Colors.blue),
              title: const Text('Print'),
              subtitle: const Text('Send directly to printer'),
              onTap: () => Navigator.pop(context, PrintAction.print),
            ),
            ListTile(
              leading: const Icon(Icons.save, color: Colors.green),
              title: const Text('Save PDF'),
              subtitle: const Text('Save to file'),
              onTap: () => Navigator.pop(context, PrintAction.save),
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.orange),
              title: const Text('Share'),
              subtitle: const Text('Share or export'),
              onTap: () => Navigator.pop(context, PrintAction.share),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Execute print action with error handling and user feedback
  ///
  /// Handles the selected print action and shows appropriate feedback.
  static Future<void> executePrintAction({
    required BuildContext context,
    required PrintAction action,
    required Future<Uint8List> Function() generatePdf,
    required String filename,
    String? successMessage,
  }) async {
    try {
      final pdfBytes = await generatePdf();

      switch (action) {
        case PrintAction.print:
          await printPdfBytes(pdfBytes: pdfBytes, filename: filename);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(successMessage ?? '✅ Sent to printer'),
                backgroundColor: Colors.green,
              ),
            );
          }
          break;

        case PrintAction.save:
          final file = await savePdfBytes(
            pdfBytes: pdfBytes,
            suggestedName: filename,
          );
          if (context.mounted && file != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Saved: ${file.path}'),
                backgroundColor: Colors.green,
              ),
            );
          }
          break;

        case PrintAction.share:
          await sharePdfBytes(pdfBytes: pdfBytes, filename: filename);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(successMessage ?? '✅ Shared successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
      rethrow;
    }
  }

  /// Build print action buttons (Print | Save | Share)
  ///
  /// Returns a row of buttons for print/save/share actions.
  /// Use this for consistent UI across all screens.
  static Widget buildPrintActionButtons({
    required VoidCallback onPrint,
    required VoidCallback onSave,
    required VoidCallback onShare,
    bool isCompact = false,
  }) {
    if (isCompact) {
      // Compact version: Icon buttons
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: onPrint,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save PDF',
            onPressed: onSave,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: onShare,
          ),
        ],
      );
    }

    // Full version: Elevated buttons
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: onPrint,
          icon: const Icon(Icons.print),
          label: const Text('Print'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save),
          label: const Text('Save PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton.icon(
          onPressed: onShare,
          icon: const Icon(Icons.share),
          label: const Text('Share'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Print action enum
enum PrintAction { print, save, share }

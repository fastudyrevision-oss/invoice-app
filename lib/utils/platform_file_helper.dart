import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';

/// Platform-aware file handling utility for Android and Desktop compatibility
///
/// This helper ensures file operations work correctly on both Android and Desktop:
/// - Android: Uses temp directories + share dialogs (FilePicker.saveFile not supported)
/// - Desktop: Uses FilePicker.saveFile for traditional save dialogs
class PlatformFileHelper {
  /// Save a PDF file with platform-specific handling
  ///
  /// On Android: Saves to temp directory and opens share dialog
  /// On Desktop: Opens file picker dialog to choose save location
  ///
  /// Returns the File if saved successfully, null if user cancelled
  static Future<File?> savePdfFile({
    required Uint8List pdfBytes,
    required String suggestedName,
    String dialogTitle = 'Save PDF',
  }) async {
    if (kIsWeb) {
      // Web: Use printing package's share functionality
      await Printing.sharePdf(bytes: pdfBytes, filename: suggestedName);
      return null;
    }

    // Check if running on Android
    final isAndroid = !kIsWeb && Platform.isAndroid;

    if (isAndroid) {
      // Android: Save to temp directory and share
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$suggestedName');
      await file.writeAsBytes(pdfBytes);

      // Use share dialog to let user choose where to save
      await Printing.sharePdf(bytes: pdfBytes, filename: suggestedName);

      return file;
    } else {
      // Desktop (Windows/Mac/Linux): Use file picker
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (savePath == null) return null;

      final file = File(savePath);
      await file.writeAsBytes(pdfBytes);
      return file;
    }
  }

  /// Save an Excel file with platform-specific handling
  ///
  /// On Android: Saves to temp directory and opens share dialog
  /// On Desktop: Opens file picker dialog to choose save location
  ///
  /// Returns the File if saved successfully, null if user cancelled
  static Future<File?> saveExcelFile({
    required Excel excel,
    required String suggestedName,
    String dialogTitle = 'Save Excel File',
  }) async {
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file');
    }

    if (kIsWeb) {
      // Web: Download file
      // Note: Would need additional web-specific implementation
      throw UnimplementedError('Excel export not yet supported on web');
    }

    final isAndroid = !kIsWeb && Platform.isAndroid;

    if (isAndroid) {
      // Android: Save to temp directory and share
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$suggestedName');
      await file.writeAsBytes(bytes);

      // Share the file
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: suggestedName));

      return file;
    } else {
      // Desktop: Use file picker
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (savePath == null) return null;

      final file = File(savePath);
      await file.writeAsBytes(bytes);
      return file;
    }
  }

  /// Save a CSV file with platform-specific handling
  static Future<File?> saveCsvFile({
    required String csvContent,
    required String suggestedName,
    String dialogTitle = 'Save CSV File',
  }) async {
    if (kIsWeb) {
      throw UnimplementedError('CSV export not yet supported on web');
    }

    final isAndroid = !kIsWeb && Platform.isAndroid;

    if (isAndroid) {
      // Android: Save to temp directory and share
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$suggestedName');
      await file.writeAsString(csvContent);

      // Share the file
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: suggestedName));

      return file;
    } else {
      // Desktop: Use file picker
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (savePath == null) return null;

      final file = File(savePath);
      await file.writeAsString(csvContent);
      return file;
    }
  }

  /// Save any binary file with platform-specific handling
  static Future<File?> saveFile({
    required Uint8List bytes,
    required String suggestedName,
    required String extension,
    String dialogTitle = 'Save File',
  }) async {
    if (kIsWeb) {
      throw UnimplementedError('File export not yet supported on web');
    }

    final isAndroid = !kIsWeb && Platform.isAndroid;

    if (isAndroid) {
      // Android: Save to temp directory and share
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$suggestedName');
      await file.writeAsBytes(bytes);

      // Share the file
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: suggestedName));

      return file;
    } else {
      // Desktop: Use file picker
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: [extension],
      );

      if (savePath == null) return null;

      final file = File(savePath);
      await file.writeAsBytes(bytes);
      return file;
    }
  }

  /// Share any file using the platform's share dialog
  /// Useful for Android where we want to share files directly
  static Future<void> shareFile({
    required String filePath,
    String? subject,
  }) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(filePath)], subject: subject));
  }

  /// Share PDF bytes directly (useful when file doesn't need to be saved)
  static Future<void> sharePdfBytes({
    required Uint8List pdfBytes,
    required String filename,
  }) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  /// Check if the current platform is Android
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Check if the current platform is Desktop (Windows/Mac/Linux)
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Check if the current platform is iOS
  static bool get isIOS => !kIsWeb && Platform.isIOS;
}

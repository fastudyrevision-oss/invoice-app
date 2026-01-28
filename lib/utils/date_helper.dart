import 'package:intl/intl.dart';

class DateHelper {
  static const String _displayFormat = 'dd-MM-yyyy';

  /// Format DateTime to Display String (dd-MM-yyyy)
  static String formatDate(DateTime date) {
    return DateFormat(_displayFormat).format(date);
  }

  /// Parse Display String (dd-MM-yyyy) back to DateTime
  /// Returns null if format is invalid
  static DateTime? parseDate(String dateStr) {
    try {
      return DateFormat(_displayFormat).parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  /// Format ISO String or mixed format to Display String (dd-MM-yyyy)
  static String formatIso(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "";
    try {
      // 1. Try ISO parse (handles 2026-01-24T... and 2026-09-08)
      final date = DateTime.parse(dateStr);
      return formatDate(date);
    } catch (e) {
      // 2. Try parsing specific formats that might be in DB
      try {
        final date = DateFormat('dd-MM-yyyy').parse(dateStr);
        return formatDate(date);
      } catch (_) {}

      try {
        final date = DateFormat('yyyy-MM-dd').parse(dateStr);
        return formatDate(date);
      } catch (_) {}

      try {
        final date = DateFormat('MM/dd/yyyy').parse(dateStr);
        return formatDate(date);
      } catch (_) {}

      return dateStr; // Return original if all parsing fails
    }
  }

  /// Validate if string matches dd-MM-yyyy
  static bool isValidDate(String dateStr) {
    if (dateStr.isEmpty) return false;
    try {
      DateFormat(_displayFormat).parseStrict(dateStr);
      return true;
    } catch (e) {
      return false;
    }
  }
}

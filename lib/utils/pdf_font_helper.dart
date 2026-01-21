import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

/// 🎨 Centralized PDF Font Helper - Future-safe font management
/// All PDF generation should use fonts from this utility
class PdfFontHelper {
  // Cache fonts to avoid reloading
  static pw.Font? _cachedRegularFont;
  static pw.Font? _cachedBoldFont;

  /// Load Urdu/Arabic-supporting font (Regular weight)
  /// Uses NotoSansArabic which has superior OpenType text shaping
  static Future<pw.Font> getRegularFont() async {
    _cachedRegularFont ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
    );
    return _cachedRegularFont!;
  }

  /// Load Urdu/Arabic-supporting font (Bold weight)
  /// Uses NotoSansArabic which has superior OpenType text shaping
  static Future<pw.Font> getBoldFont() async {
    _cachedBoldFont ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
    );
    return _cachedBoldFont!;
  }

  /// Get both fonts at once (convenient for most use cases)
  static Future<Map<String, pw.Font>> getBothFonts() async {
    return {
      'regular': await getRegularFont(),
      'bold': await getBoldFont(),
    };
  }

  /// Clear cached fonts (use if switching printer configurations)
  static void clearCache() {
    _cachedRegularFont = null;
    _cachedBoldFont = null;
  }
}

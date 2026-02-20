import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import '../services/logger_service.dart';

/// 🎨 Centralized PDF Font Helper - Future-safe font management
/// All PDF generation should use fonts from this utility
class PdfFontHelper {
  // Cache fonts to avoid reloading
  static pw.Font? _cachedRegularFont;
  static pw.Font? _cachedBoldFont;
  static pw.Font? _cachedBoldRobotoFont; // Added
  static pw.Font? _cachedLalezarFont;
  static pw.Font? _cachedJameelNooriFont;

  // Global cache for font families
  static final Map<String, pw.Font> _familyCache = {};

  /// Load Jameel Noori font
  static Future<pw.Font> getJameelNooriFont() async {
    if (_cachedJameelNooriFont == null) {
      logger.info(
        'PdfFontHelper',
        'AUDIT: Loading JameelNoori font from assets',
      );
      final data = await rootBundle.load('assets/fonts/Jameel-Noori.ttf');
      if (data.lengthInBytes == 0) {
        throw StateError('Jameel-Noori font asset is empty');
      }
      _cachedJameelNooriFont = pw.Font.ttf(data);
    }
    return _cachedJameelNooriFont!;
  }

  /// Load Urdu/Arabic-supporting font (Regular weight)
  static Future<pw.Font> getRegularFont() async {
    if (_cachedRegularFont == null) {
      logger.info(
        'PdfFontHelper',
        'AUDIT: Loading NotoSansArabic-Regular font',
      );
      final data = await rootBundle.load(
        'assets/fonts/NotoSansArabic-Regular.ttf',
      );
      if (data.lengthInBytes == 0) {
        throw StateError('NotoSansArabic-Regular font asset is empty');
      }
      _cachedRegularFont = pw.Font.ttf(data);
    }
    return _cachedRegularFont!;
  }

  /// Load Urdu/Arabic-supporting font (Bold weight)
  static Future<pw.Font> getBoldFont() async {
    if (_cachedBoldFont == null) {
      logger.info('PdfFontHelper', 'AUDIT: Loading NotoSansArabic-Bold font');
      final data = await rootBundle.load(
        'assets/fonts/NotoSansArabic-Bold.ttf',
      );
      if (data.lengthInBytes == 0) {
        throw StateError('NotoSansArabic-Bold font asset is empty');
      }
      _cachedBoldFont = pw.Font.ttf(data);
    }
    return _cachedBoldFont!;
  }

  /// Load Roboto-Bold font
  static Future<pw.Font> getBoldRobotoFont() async {
    if (_cachedBoldRobotoFont == null) {
      logger.info('PdfFontHelper', 'AUDIT: Loading Roboto-Bold font');
      final data = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      if (data.lengthInBytes == 0) {
        throw StateError('Roboto-Bold font asset is empty');
      }
      _cachedBoldRobotoFont = pw.Font.ttf(data);
    }
    return _cachedBoldRobotoFont!;
  }

  /// Load Lalezar font for Urdu headings
  static Future<pw.Font> getLalezarFont() async {
    if (_cachedLalezarFont == null) {
      logger.info('PdfFontHelper', 'AUDIT: Loading Lalezar-Regular font');
      final data = await rootBundle.load('assets/fonts/Lalezar-Regular.ttf');
      if (data.lengthInBytes == 0) {
        throw StateError('Lalezar-Regular font asset is empty');
      }
      _cachedLalezarFont = pw.Font.ttf(data);
    }
    return _cachedLalezarFont!;
  }

  /// Get font by family name
  static Future<pw.Font> getFontByFamily(String family) async {
    if (family.isEmpty) family = 'Roboto';
    if (_familyCache.containsKey(family)) return _familyCache[family]!;

    logger.debug('PdfFontHelper', 'AUDIT: Requesting font family: $family');
    pw.Font font;
    switch (family) {
      case 'UrduFont':
      case 'NotoSansArabic':
        font = await getRegularFont();
        break;
      case 'Lalezar':
        font = await getLalezarFont();
        break;
      case 'JameelNoori':
        font = await getJameelNooriFont();
        break;
      case 'Scheherazade':
        final dataS = await rootBundle.load(
          'assets/fonts/SchehrazadeNew-Regular.ttf',
        );
        font = pw.Font.ttf(dataS);
        break;
      case 'Inter':
      case 'Poppins':
      case 'Montserrat':
        // These would need assets, if not found fallback to Roboto
        final dataR = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        font = pw.Font.ttf(dataR);
        break;
      case 'Roboto':
      default:
        final data = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        if (data.lengthInBytes == 0) {
          throw StateError('Roboto-Regular font asset is empty');
        }
        font = pw.Font.ttf(data);
    }
    _familyCache[family] = font;
    return font;
  }

  /// Get bold font by family name
  static Future<pw.Font> getBoldFontByFamily(String family) async {
    if (family.isEmpty) family = 'Roboto';
    final boldKey = '${family}_Bold';
    if (_familyCache.containsKey(boldKey)) return _familyCache[boldKey]!;

    logger.debug(
      'PdfFontHelper',
      'AUDIT: Requesting bold font family: $family',
    );
    pw.Font font;
    switch (family) {
      case 'UrduFont':
      case 'NotoSansArabic':
        font = await getBoldFont();
        break;
      case 'Roboto':
      case 'Inter':
      case 'Poppins':
      case 'Montserrat':
        font = await getBoldRobotoFont();
        break;
      default:
        // Fallback to regular bold if specific one not found
        font = await getBoldFont();
    }
    _familyCache[boldKey] = font;
    return font;
  }

  /// Resolve font from family name and optional custom path
  static Future<pw.Font> resolveFont(String family, String? customPath) async {
    if (customPath != null && customPath.isNotEmpty) {
      return await getCustomFont(customPath);
    }
    return await getFontByFamily(family);
  }

  /// Get both fonts at once (convenient for most use cases)
  static Future<Map<String, pw.Font>> getBothFonts() async {
    return {'regular': await getRegularFont(), 'bold': await getBoldFont()};
  }

  static bool isUrduFamily(String family) {
    if (family.isEmpty) return false;
    final f = family.toLowerCase();
    return f.contains('urdu') ||
        f.contains('arabic') ||
        f.contains('jameel') ||
        f.contains('noori') ||
        f.contains('lalezar') ||
        f.contains('scheherazade') ||
        f.contains('aswad') ||
        f.contains('kafeel') ||
        f.contains('kaffeel') ||
        f.contains('bombay') ||
        f.contains('black') ||
        f.contains('nastaliq') ||
        f.contains('fajer') ||
        f.contains('paskaz') ||
        f.contains('alvi') ||
        f.contains('unibd') ||
        f.contains('unicode') ||
        f.contains('noorehuda');
  }

  /// Load a custom font from a file path or fallback to regular
  static Future<pw.Font> getCustomFont(String? path) async {
    if (path == null || path.isEmpty) return await getRegularFont();
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        logger.info(
          'PdfFontHelper',
          'AUDIT: Loaded custom font from $path | size: ${bytes.lengthInBytes} bytes',
        );
        return pw.Font.ttf(bytes.buffer.asByteData());
      } else {
        logger.warning(
          'PdfFontHelper',
          'AUDIT: Custom font file not found at $path, falling back',
        );
      }
    } catch (e) {
      logger.error(
        'PdfFontHelper',
        'AUDIT: Error loading custom font from $path',
        error: e,
      );
    }
    return await getRegularFont();
  }

  /// Clear cached fonts (use if switching printer configurations)
  static void clearCache() {
    logger.info('PdfFontHelper', 'AUDIT: Clearing font cache');
    _cachedRegularFont = null;
    _cachedBoldFont = null;
    _cachedLalezarFont = null;
    _cachedJameelNooriFont = null;
    _familyCache.clear();
  }
}

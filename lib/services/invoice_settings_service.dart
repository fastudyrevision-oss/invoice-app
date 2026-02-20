import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../models/invoice_settings.dart';
import 'logger_service.dart';
import '../utils/pdf_font_helper.dart';

class InvoiceSettingsService {
  static const String _key = 'invoice_settings';
  static const String _tag = 'InvoiceSettingsService';

  static final InvoiceSettingsService _instance =
      InvoiceSettingsService._internal();
  factory InvoiceSettingsService() => _instance;
  InvoiceSettingsService._internal();

  InvoiceSettings? _cache;

  Future<InvoiceSettings> getSettings() async {
    if (_cache != null) return _cache!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_key);
      if (jsonStr == null) {
        _cache = InvoiceSettings();
      } else {
        try {
          _cache = InvoiceSettings.fromJson(jsonStr);
        } catch (e) {
          // Migration: If old data structure fails, reset to defaults
          logger.warning(
            _tag,
            'Old settings format detected, resetting to defaults',
            error: e,
          );
          _cache = InvoiceSettings();
          await saveSettings(_cache!); // Save new format
        }
      }
    } catch (e) {
      logger.error(_tag, 'Error loading settings', error: e);
      _cache = InvoiceSettings();
    }
    return _cache!;
  }

  /// Clear cached settings (forces reload from storage)
  void clearCache() {
    _cache = null;
    logger.info(_tag, 'Settings cache cleared');
  }

  Future<bool> saveSettings(InvoiceSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_key, settings.toJson());
      if (success) {
        _cache = settings;
        // Clear PDF font cache to ensure fonts are reloaded with new settings
        PdfFontHelper.clearCache();
        logger.info(_tag, 'Settings saved successfully');
      }
      return success;
    } catch (e) {
      logger.error(_tag, 'Error saving settings', error: e);
      return false;
    }
  }

  /// Copies a font file to local app storage and returns the new path
  Future<String?> saveCustomFont(File fontFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fontsDir = Directory(p.join(appDir.path, 'custom_fonts'));
      if (!await fontsDir.exists()) {
        await fontsDir.create(recursive: true);
      }

      final fileName = p.basename(fontFile.path);
      final newPath = p.join(fontsDir.path, fileName);
      await fontFile.copy(newPath);

      logger.info(_tag, 'Custom font saved: $newPath');
      return newPath;
    } catch (e) {
      logger.error(_tag, 'Error saving custom font', error: e);
      return null;
    }
  }

  /// Copies a logo file to local app storage and returns the new path
  Future<String?> saveCustomLogo(File logoFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logoDir = Directory(p.join(appDir.path, 'logos'));
      if (!await logoDir.exists()) {
        await logoDir.create(recursive: true);
      }

      final fileName = p.basename(logoFile.path);
      final newPath = p.join(logoDir.path, fileName);
      await logoFile.copy(newPath);

      logger.info(_tag, 'Custom logo saved: $newPath');
      return newPath;
    } catch (e) {
      logger.error(_tag, 'Error saving custom logo', error: e);
      return null;
    }
  }

  Future<void> resetToDefaults() async {
    _cache = InvoiceSettings();
    await saveSettings(_cache!);
  }
}

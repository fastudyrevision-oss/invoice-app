import 'package:shared_preferences/shared_preferences.dart';
import 'logger_service.dart';

/// 🖨️ Thermal Printer Settings Service
///
/// Manages all printer configuration persistently using SharedPreferences
/// Handles: IP address, port, timeout, print density, paper width, etc.
class PrinterSettingsService {
  static const String _tag = '🖨️ PrinterSettings';

  // SharedPreferences Keys
  static const String _printerAddressKey = 'printer_address';
  static const String _printerPortKey = 'printer_port';
  static const String _printerTimeoutKey = 'printer_timeout_seconds';
  static const String _printerNameKey = 'printer_name';
  static const String _printerDensityKey = 'printer_density';
  static const String _paperWidthKey = 'paper_width_mm';
  static const String _autoPrintTestKey = 'auto_print_test';
  static const String _enableLoggingKey = 'enable_printer_logging';
  static const String _usbPrinterNameKey = 'usb_printer_name';
  static const String _priorityKey = 'printer_priority'; // 'network' or 'usb'

  late SharedPreferences _prefs;
  bool _initialized = false;

  // Printer density levels
  static const Map<int, String> densityLevels = {
    0: 'Light',
    1: 'Normal',
    2: 'Medium',
    3: 'Dark',
  };

  // Paper width options (mm)
  static const List<int> paperWidths = [58, 80, 100];

  // ═══════════════════════════════════════════════════════════════
  // Initialization
  // ═══════════════════════════════════════════════════════════════

  /// Initialize the settings service
  Future<void> initialize() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    logger.info(_tag, 'Initialized');
  }

  /// Ensure initialization before operations
  Future<void> _ensureInitialized() async {
    if (!_initialized) await initialize();
  }

  // ═══════════════════════════════════════════════════════════════
  // Getters
  // ═══════════════════════════════════════════════════════════════

  /// Get saved printer address (IP or hostname)
  Future<String?> getPrinterAddress() async {
    await _ensureInitialized();
    return _prefs.getString(_printerAddressKey);
  }

  /// Get saved printer port
  Future<int> getPrinterPort() async {
    await _ensureInitialized();
    return _prefs.getInt(_printerPortKey) ?? 9100;
  }

  /// Get connection timeout in seconds
  Future<int> getConnectionTimeout() async {
    await _ensureInitialized();
    return _prefs.getInt(_printerTimeoutKey) ?? 5;
  }

  /// Get printer display name
  Future<String?> getPrinterName() async {
    await _ensureInitialized();
    return _prefs.getString(_printerNameKey);
  }

  /// Get print density level (0-3)
  Future<int> getPrintDensity() async {
    await _ensureInitialized();
    return _prefs.getInt(_printerDensityKey) ?? 1;
  }

  /// Get paper width in mm
  Future<int> getPaperWidth() async {
    await _ensureInitialized();
    return _prefs.getInt(_paperWidthKey) ?? 80;
  }

  /// Get auto print test setting
  Future<bool> isAutoPrintTestEnabled() async {
    await _ensureInitialized();
    return _prefs.getBool(_autoPrintTestKey) ?? false;
  }

  /// Get logging enabled setting
  Future<bool> isLoggingEnabled() async {
    await _ensureInitialized();
    return _prefs.getBool(_enableLoggingKey) ?? true;
  }

  /// Get saved USB printer driver name
  Future<String?> getUsbPrinterName() async {
    await _ensureInitialized();
    return _prefs.getString(_usbPrinterNameKey);
  }

  /// Get printer priority ('network' or 'usb')
  Future<String> getPrinterPriority() async {
    await _ensureInitialized();
    return _prefs.getString(_priorityKey) ?? 'network';
  }

  /// Get all settings as a map
  Future<Map<String, dynamic>> getAllSettings() async {
    await _ensureInitialized();
    return {
      'address': await getPrinterAddress(),
      'port': await getPrinterPort(),
      'timeout': await getConnectionTimeout(),
      'name': await getPrinterName(),
      'density': await getPrintDensity(),
      'paperWidth': await getPaperWidth(),
      'autoPrintTest': await isAutoPrintTestEnabled(),
      'enableLogging': await isLoggingEnabled(),
      'usbPrinterName': await getUsbPrinterName(),
      'priority': await getPrinterPriority(),
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // Setters
  // ═══════════════════════════════════════════════════════════════

  /// Save printer address
  Future<bool> setPrinterAddress(String address) async {
    await _ensureInitialized();
    final result = await _prefs.setString(_printerAddressKey, address.trim());
    if (result) {
      logger.info(_tag, 'Printer address saved', context: {'address': address});
    }
    return result;
  }

  /// Save printer port
  Future<bool> setPrinterPort(int port) async {
    await _ensureInitialized();
    if (port < 1 || port > 65535) {
      logger.warning(_tag, 'Invalid port', context: {'port': port});
      return false;
    }
    final result = await _prefs.setInt(_printerPortKey, port);
    if (result) {
      logger.info(_tag, 'Printer port saved', context: {'port': port});
    }
    return result;
  }

  /// Save connection timeout in seconds
  Future<bool> setConnectionTimeout(int seconds) async {
    await _ensureInitialized();
    if (seconds < 1 || seconds > 60) {
      logger.warning(_tag, 'Invalid timeout', context: {'seconds': seconds});
      return false;
    }
    final result = await _prefs.setInt(_printerTimeoutKey, seconds);
    if (result) {
      logger.info(
        _tag,
        'Connection timeout saved',
        context: {'seconds': seconds},
      );
    }
    return result;
  }

  /// Save printer display name
  Future<bool> setPrinterName(String name) async {
    await _ensureInitialized();
    final result = await _prefs.setString(_printerNameKey, name.trim());
    if (result) {
      logger.info(_tag, 'Printer name saved', context: {'name': name});
    }
    return result;
  }

  /// Save USB printer driver name
  Future<bool> setUsbPrinterName(String? name) async {
    await _ensureInitialized();
    if (name == null) {
      return await _prefs.remove(_usbPrinterNameKey);
    }
    final result = await _prefs.setString(_usbPrinterNameKey, name.trim());
    if (result) {
      logger.info(_tag, 'USB Printer name saved', context: {'usbName': name});
    }
    return result;
  }

  /// Save printer priority
  Future<bool> setPrinterPriority(String priority) async {
    await _ensureInitialized();
    if (priority != 'network' && priority != 'usb') return false;

    final result = await _prefs.setString(_priorityKey, priority);
    if (result) {
      logger.info(
        _tag,
        'Printer priority saved',
        context: {'priority': priority},
      );
    }
    return result;
  }

  /// Save print density level
  Future<bool> setPrintDensity(int level) async {
    await _ensureInitialized();
    if (!densityLevels.containsKey(level)) {
      logger.warning(_tag, 'Invalid density level', context: {'level': level});
      return false;
    }
    final result = await _prefs.setInt(_printerDensityKey, level);
    if (result) {
      logger.info(
        _tag,
        'Print density saved',
        context: {'level': densityLevels[level]},
      );
    }
    return result;
  }

  /// Save paper width in mm
  Future<bool> setPaperWidth(int width) async {
    await _ensureInitialized();
    if (!paperWidths.contains(width)) {
      logger.warning(_tag, 'Invalid paper width', context: {'width': width});
      return false;
    }
    final result = await _prefs.setInt(_paperWidthKey, width);
    if (result) {
      logger.info(_tag, 'Paper width saved', context: {'width': width});
    }
    return result;
  }

  /// Save auto print test setting
  Future<bool> setAutoPrintTest(bool enabled) async {
    await _ensureInitialized();
    final result = await _prefs.setBool(_autoPrintTestKey, enabled);
    if (result) {
      logger.info(
        _tag,
        'Auto print test updated',
        context: {'enabled': enabled},
      );
    }
    return result;
  }

  /// Save logging enabled setting
  Future<bool> setLoggingEnabled(bool enabled) async {
    await _ensureInitialized();
    final result = await _prefs.setBool(_enableLoggingKey, enabled);
    if (result) {
      logger.info(
        _tag,
        'Printer logging updated',
        context: {'enabled': enabled},
      );
    }
    return result;
  }

  /// Save all settings at once
  Future<bool> saveAllSettings(Map<String, dynamic> settings) async {
    await _ensureInitialized();

    try {
      if (settings.containsKey('address')) {
        await setPrinterAddress(settings['address']);
      }
      if (settings.containsKey('port')) {
        await setPrinterPort(settings['port']);
      }
      if (settings.containsKey('timeout')) {
        await setConnectionTimeout(settings['timeout']);
      }
      if (settings.containsKey('name')) {
        await setPrinterName(settings['name']);
      }
      if (settings.containsKey('density')) {
        await setPrintDensity(settings['density']);
      }
      if (settings.containsKey('paperWidth')) {
        await setPaperWidth(settings['paperWidth']);
      }
      if (settings.containsKey('autoPrintTest')) {
        await setAutoPrintTest(settings['autoPrintTest']);
      }
      if (settings.containsKey('enableLogging')) {
        await setLoggingEnabled(settings['enableLogging']);
      }
      if (settings.containsKey('usbPrinterName')) {
        await setUsbPrinterName(settings['usbPrinterName']);
      }

      return true;
    } catch (e) {
      logger.error(_tag, 'Error saving settings', error: e);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Utility Methods
  // ═══════════════════════════════════════════════════════════════

  /// Check if printer is configured
  Future<bool> isPrinterConfigured() async {
    final address = await getPrinterAddress();
    return address != null && address.isNotEmpty;
  }

  /// Clear all printer settings
  Future<bool> clearAllSettings() async {
    await _ensureInitialized();
    try {
      await _prefs.remove(_printerAddressKey);
      await _prefs.remove(_printerPortKey);
      await _prefs.remove(_printerTimeoutKey);
      await _prefs.remove(_printerNameKey);
      await _prefs.remove(_printerDensityKey);
      await _prefs.remove(_paperWidthKey);
      await _prefs.remove(_autoPrintTestKey);
      await _prefs.remove(_enableLoggingKey);
      await _prefs.remove(_usbPrinterNameKey);
      logger.info(_tag, 'All settings cleared');
      return true;
    } catch (e) {
      logger.error(_tag, 'Error clearing settings', error: e);
      return false;
    }
  }

  /// Get printer info as formatted string
  Future<String> getPrinterInfoString() async {
    final address = await getPrinterAddress();
    final port = await getPrinterPort();
    final name = await getPrinterName();

    if (address == null) {
      return 'Not configured';
    }

    final displayName = name != null && name.isNotEmpty ? name : 'Printer';
    return '$displayName ($address:$port)';
  }

  /// Validate printer configuration
  Future<Map<String, bool>> validateSettings() async {
    return {
      'hasAddress': await isPrinterConfigured(),
      'portValid': (await getPrinterPort()) > 0,
      'timeoutValid': (await getConnectionTimeout()) > 0,
      'paperWidthValid': paperWidths.contains(await getPaperWidth()),
      'densityValid': densityLevels.containsKey(await getPrintDensity()),
    };
  }
}

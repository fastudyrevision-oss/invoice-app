import 'package:shared_preferences/shared_preferences.dart';

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
    print('$_tag ✅ Initialized');
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
      print('$_tag ✅ Printer address saved: $address');
    }
    return result;
  }

  /// Save printer port
  Future<bool> setPrinterPort(int port) async {
    await _ensureInitialized();
    if (port < 1 || port > 65535) {
      print('$_tag ❌ Invalid port: $port (must be 1-65535)');
      return false;
    }
    final result = await _prefs.setInt(_printerPortKey, port);
    if (result) {
      print('$_tag ✅ Printer port saved: $port');
    }
    return result;
  }

  /// Save connection timeout in seconds
  Future<bool> setConnectionTimeout(int seconds) async {
    await _ensureInitialized();
    if (seconds < 1 || seconds > 60) {
      print('$_tag ❌ Invalid timeout: $seconds (must be 1-60 seconds)');
      return false;
    }
    final result = await _prefs.setInt(_printerTimeoutKey, seconds);
    if (result) {
      print('$_tag ✅ Connection timeout saved: ${seconds}s');
    }
    return result;
  }

  /// Save printer display name
  Future<bool> setPrinterName(String name) async {
    await _ensureInitialized();
    final result = await _prefs.setString(_printerNameKey, name.trim());
    if (result) {
      print('$_tag ✅ Printer name saved: $name');
    }
    return result;
  }

  /// Save print density level
  Future<bool> setPrintDensity(int level) async {
    await _ensureInitialized();
    if (!densityLevels.containsKey(level)) {
      print('$_tag ❌ Invalid density level: $level');
      return false;
    }
    final result = await _prefs.setInt(_printerDensityKey, level);
    if (result) {
      print('$_tag ✅ Print density saved: ${densityLevels[level]}');
    }
    return result;
  }

  /// Save paper width in mm
  Future<bool> setPaperWidth(int width) async {
    await _ensureInitialized();
    if (!paperWidths.contains(width)) {
      print('$_tag ❌ Invalid paper width: $width');
      return false;
    }
    final result = await _prefs.setInt(_paperWidthKey, width);
    if (result) {
      print('$_tag ✅ Paper width saved: ${width}mm');
    }
    return result;
  }

  /// Save auto print test setting
  Future<bool> setAutoPrintTest(bool enabled) async {
    await _ensureInitialized();
    final result = await _prefs.setBool(_autoPrintTestKey, enabled);
    if (result) {
      print('$_tag ✅ Auto print test: ${enabled ? 'enabled' : 'disabled'}');
    }
    return result;
  }

  /// Save logging enabled setting
  Future<bool> setLoggingEnabled(bool enabled) async {
    await _ensureInitialized();
    final result = await _prefs.setBool(_enableLoggingKey, enabled);
    if (result) {
      print('$_tag ✅ Printer logging: ${enabled ? 'enabled' : 'disabled'}');
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
      
      return true;
    } catch (e) {
      print('$_tag ❌ Error saving settings: $e');
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
      print('$_tag ✅ All settings cleared');
      return true;
    } catch (e) {
      print('$_tag ❌ Error clearing settings: $e');
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

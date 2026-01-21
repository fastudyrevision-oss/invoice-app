# 🖨️ Printer Settings Configuration Guide

## Overview

The printer settings system allows you to configure thermal printer connections without hardcoding values. All settings are persisted using SharedPreferences and can be managed through a detailed settings screen.

## Features

✅ **Persistent Storage** - Settings saved locally and auto-loaded on app startup
✅ **Multiple Configuration Options** - IP, port, timeout, density, paper width
✅ **Connection Testing** - Test printer connectivity before use
✅ **Auto-Connection** - Automatically connect to saved printer on app start
✅ **Settings UI** - Beautiful, intuitive settings screen
✅ **Validation** - Real-time validation of all inputs
✅ **Quick Reference** - Built-in help and guidance

## Components

### 1. **PrinterSettingsService** (`lib/services/printer_settings_service.dart`)

Core service for managing printer configuration with SharedPreferences.

#### Key Methods

```dart
// Initialize the service
await settingsService.initialize();

// Get settings
String? address = await settingsService.getPrinterAddress();
int port = await settingsService.getPrinterPort();
int timeout = await settingsService.getConnectionTimeout();
String? name = await settingsService.getPrinterName();
int density = await settingsService.getPrintDensity();
int paperWidth = await settingsService.getPaperWidth();

// Set individual settings
await settingsService.setPrinterAddress('192.168.1.100');
await settingsService.setPrinterPort(9100);
await settingsService.setConnectionTimeout(5);
await settingsService.setPrinterName('Main Floor Printer');
await settingsService.setPrintDensity(1); // 0=Light, 1=Normal, 2=Medium, 3=Dark
await settingsService.setPaperWidth(80); // 58, 80, or 100 mm

// Save all at once
await settingsService.saveAllSettings({
  'address': '192.168.1.100',
  'port': 9100,
  'timeout': 5,
  'name': 'My Printer',
  'density': 1,
  'paperWidth': 80,
  'autoPrintTest': false,
  'enableLogging': true,
});

// Check configuration
bool isPrinterConfigured = await settingsService.isPrinterConfigured();
String info = await settingsService.getPrinterInfoString();

// Clear all settings
await settingsService.clearAllSettings();
```

### 2. **PrinterSettingsScreen** (`lib/ui/settings/printer_settings_screen.dart`)

Beautiful, detailed UI for managing printer settings.

#### Features

- Current configuration display
- Edit all printer settings
- Test connection button
- Print test page button
- Toggle options (auto print test, logging)
- Connection status indicator
- Quick reference guide
- Clear all settings option

#### Usage

```dart
// Open printer settings screen
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const PrinterSettingsScreen(
      thermalPrinting: thermalPrinting,
    ),
  ),
);
```

### 3. **Updated ThermalPrintingService**

The printing service now integrates with settings:

#### Auto-Connection on App Startup

```dart
// In your main app initialization
void initState() {
  super.initState();
  // Auto-connect to saved printer
  thermalPrinting.autoConnectSavedPrinter();
}
```

#### Print with Auto-Settings

```dart
// Print will use saved settings if not provided
await thermalPrinting.printInvoice(
  invoice,
  items: receiptItems,
  context: context,
  // printerAddress and printerPort are optional now
  // They'll use saved settings if not provided
);

// Or explicitly override settings
await thermalPrinting.printInvoice(
  invoice,
  items: receiptItems,
  printerAddress: '192.168.1.100',
  printerPort: 9100,
  context: context,
);
```

## Configuration Storage

Settings are stored in SharedPreferences with these keys:

```
printer_address      → Printer IP or hostname
printer_port         → Port number (default: 9100)
printer_timeout_seconds → Connection timeout (default: 5)
printer_name         → Friendly name for printer
printer_density      → Print density level (0-3)
paper_width_mm       → Paper width in millimeters
auto_print_test      → Enable auto-test after connection
enable_printer_logging → Enable debug logging
```

## Integration Steps

### Step 1: Install SharedPreferences Package

Already included in `pubspec.yaml`:
```yaml
shared_preferences: ^2.x.x
```

### Step 2: Add Settings Button to Main App

✅ Already done in `lib/main_frame.dart`

The printer icon button is in the AppBar actions:
```dart
IconButton(
  icon: const Icon(Icons.print),
  tooltip: "Printer Settings",
  onPressed: _openPrinterSettings,
),
```

### Step 3: Auto-Connect on App Startup

Add this to your main app initialization:

```dart
@override
void initState() {
  super.initState();
  _autoConnectPrinter();
}

Future<void> _autoConnectPrinter() async {
  await thermalPrinting.autoConnectSavedPrinter();
}
```

### Step 4: Use in Print Dialogs

No changes needed! The printing service automatically uses saved settings:

```dart
// From order_list_screen.dart, purchase_frame.dart, etc.
await thermalPrinting.printInvoice(invoice, items: items, context: context);
// Uses saved settings automatically
```

## Usage Examples

### Example 1: Access Settings Directly

```dart
final settingsService = PrinterSettingsService();
await settingsService.initialize();

final address = await settingsService.getPrinterAddress();
final port = await settingsService.getPrinterPort();

if (address != null) {
  print('Configured printer: $address:$port');
}
```

### Example 2: Open Settings Screen

```dart
// In any screen
void _openPrinterSettings() {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const PrinterSettingsScreen(
        thermalPrinting: thermalPrinting,
      ),
    ),
  );
}
```

### Example 3: Test Connection

```dart
final settingsService = PrinterSettingsService();
final address = await settingsService.getPrinterAddress();
final port = await settingsService.getPrinterPort();

if (address != null) {
  final success = await thermalPrinting.connectPrinter(
    address,
    port: port,
    context: context,
  );
  
  if (success) {
    print('✅ Printer is ready!');
  }
}
```

## Density Levels

Choose the appropriate density based on your needs:

| Level | Name | Use Case |
|-------|------|----------|
| 0 | Light | Fast printing, less ink |
| 1 | Normal | Balanced speed and quality (recommended) |
| 2 | Medium | Better quality |
| 3 | Dark | High quality, slower |

## Paper Widths

Standard thermal printer paper sizes:

| Width | Use Case |
|-------|----------|
| 58mm | Small receipts, small printers |
| 80mm | Standard thermal printers (most common) |
| 100mm | Wide format receipts |

## Troubleshooting

### Printer Won't Connect

1. **Check IP Address**: Verify printer IP matches actual device
2. **Check Port**: Default is 9100, but some printers use different ports
3. **Check Network**: Ensure printer is on same network
4. **Increase Timeout**: Set timeout to 10+ seconds for slow networks
5. **Test Connection**: Use "Test Connection" button in settings screen

### Settings Not Persisting

1. **Initialize Service**: Ensure `await settingsService.initialize()` is called
2. **Check SharedPreferences**: Verify SharedPreferences is properly configured
3. **App Permissions**: Ensure app has storage permissions (Android)

### Connection Lost After Restart

- Ensure `autoConnectSavedPrinter()` is called in app initialization
- Check if saved printer is still online
- Test connection in settings screen

## Database Keys Reference

For advanced use, these are the SharedPreferences keys:

```dart
static const String _printerAddressKey = 'printer_address';
static const String _printerPortKey = 'printer_port';
static const String _printerTimeoutKey = 'printer_timeout_seconds';
static const String _printerNameKey = 'printer_name';
static const String _printerDensityKey = 'printer_density';
static const String _paperWidthKey = 'paper_width_mm';
static const String _autoPrintTestKey = 'auto_print_test';
static const String _enableLoggingKey = 'enable_printer_logging';
```

## File Structure

```
lib/
├── services/
│   └── printer_settings_service.dart    ← Settings management
├── ui/
│   └── settings/
│       └── printer_settings_screen.dart ← Settings UI
└── main_frame.dart                      ← Integrated printer button
```

## Benefits Over Hardcoding

❌ **Hardcoded Configuration**
- Cannot change without rebuilding app
- No UI for configuration
- Settings lost on app updates

✅ **Settings Service**
- Change anytime from UI
- Beautiful settings screen
- Settings persist across app updates
- Real-time validation
- Connection testing built-in
- Auto-connection on startup
- Support for multiple printer configurations

## API Reference

### PrinterSettingsService

See [PrinterSettingsService Documentation](../services/printer_settings_service.dart)

### PrinterSettingsScreen

See [PrinterSettingsScreen Documentation](../ui/settings/printer_settings_screen.dart)

## Next Steps

1. ✅ Configure your printer in settings screen
2. ✅ Test connection
3. ✅ Print a test page
4. ✅ Use normally from any print dialog

That's it! No more hardcoding printer settings.

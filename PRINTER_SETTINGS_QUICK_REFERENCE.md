# 🖨️ Printer Settings - Quick Reference

## File Locations

```
lib/services/printer_settings_service.dart          ← Settings service
lib/ui/settings/printer_settings_screen.dart        ← Settings UI
lib/services/thermal_printer/thermal_printing_service.dart  ← Updated printing
lib/main_frame.dart                                 ← Added settings button
pubspec.yaml                                        ← Added dependency
```

## API Quick Reference

### Initialize (Optional - Auto-Initializes)
```dart
final settingsService = PrinterSettingsService();
await settingsService.initialize();
```

### Get Single Setting
```dart
String? address = await settingsService.getPrinterAddress();
int port = await settingsService.getPrinterPort();
int timeout = await settingsService.getConnectionTimeout();
String? name = await settingsService.getPrinterName();
int density = await settingsService.getPrintDensity(); // 0-3
int paperWidth = await settingsService.getPaperWidth(); // 58, 80, 100
bool autoPrintTest = await settingsService.isAutoPrintTestEnabled();
bool logging = await settingsService.isLoggingEnabled();
```

### Set Single Setting
```dart
await settingsService.setPrinterAddress('192.168.1.100');
await settingsService.setPrinterPort(9100);
await settingsService.setConnectionTimeout(5);
await settingsService.setPrinterName('Main Printer');
await settingsService.setPrintDensity(1);
await settingsService.setPaperWidth(80);
await settingsService.setAutoPrintTest(true);
await settingsService.setLoggingEnabled(true);
```

### Get All Settings
```dart
Map<String, dynamic> settings = await settingsService.getAllSettings();
// Returns: {
//   'address': '192.168.1.100',
//   'port': 9100,
//   'timeout': 5,
//   'name': 'My Printer',
//   'density': 1,
//   'paperWidth': 80,
//   'autoPrintTest': false,
//   'enableLogging': true,
// }
```

### Save All Settings at Once
```dart
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
```

### Check Configuration
```dart
bool configured = await settingsService.isPrinterConfigured();
String info = await settingsService.getPrinterInfoString();
// Returns: "My Printer (192.168.1.100:9100)"
```

### Validate Settings
```dart
Map<String, bool> validation = await settingsService.validateSettings();
// Returns: {
//   'hasAddress': true,
//   'portValid': true,
//   'timeoutValid': true,
//   'paperWidthValid': true,
//   'densityValid': true,
// }
```

### Clear All Settings
```dart
await settingsService.clearAllSettings();
```

## Print Methods with Settings

### Print Invoice (Auto-Settings)
```dart
// Will use saved printer if not provided
await thermalPrinting.printInvoice(
  invoice,
  items: receiptItems,
  context: context,
);

// Or override specific settings
await thermalPrinting.printInvoice(
  invoice,
  items: receiptItems,
  printerAddress: '192.168.1.100',
  printerPort: 9100,
  context: context,
);
```

### Print Purchase (Auto-Settings)
```dart
await thermalPrinting.printPurchase(
  purchase,
  items: receiptItems,
  supplierName: 'Supplier Name',
  context: context,
);
```

### Print Custom Receipt (Auto-Settings)
```dart
final receipt = ThermalReceiptWidget(...);
await thermalPrinting.printCustom(receipt, context: context);
```

### Auto-Connect on App Start
```dart
// In main app initState()
@override
void initState() {
  super.initState();
  await thermalPrinting.autoConnectSavedPrinter();
}
```

### Connect with Savings
```dart
// Automatically saves to settings on success
bool success = await thermalPrinting.connectPrinter(
  '192.168.1.100',
  port: 9100,
  context: context,
);
```

## UI Components

### Open Settings Screen
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const PrinterSettingsScreen(
      thermalPrinting: thermalPrinting,
    ),
  ),
);
```

### Constants for UI
```dart
// Density levels
Map<int, String> levels = PrinterSettingsService.densityLevels;
// 0: 'Light', 1: 'Normal', 2: 'Medium', 3: 'Dark'

// Paper widths
List<int> widths = PrinterSettingsService.paperWidths;
// [58, 80, 100]
```

## Common Patterns

### Pattern 1: Check if Printer Configured, Then Print
```dart
final address = await settingsService.getPrinterAddress();
if (address != null && address.isNotEmpty) {
  await thermalPrinting.printInvoice(invoice, items: items, context: context);
} else {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Printer not configured')),
  );
}
```

### Pattern 2: Show Settings if Not Configured
```dart
final configured = await settingsService.isPrinterConfigured();
if (!configured) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const PrinterSettingsScreen(),
    ),
  );
} else {
  // Proceed with printing
}
```

### Pattern 3: Auto-Connect with Fallback to Settings UI
```dart
bool connected = await thermalPrinting.autoConnectSavedPrinter();
if (!connected) {
  // Show settings screen
  final result = await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const PrinterSettingsScreen(),
    ),
  );
  
  if (result == true) {
    // Settings saved, try again
    await thermalPrinting.autoConnectSavedPrinter();
  }
}
```

## Debugging

### Enable Logging
```dart
await settingsService.setLoggingEnabled(true);
```

### Print Debug Info
```dart
final info = await settingsService.getPrinterInfoString();
print('Printer: $info');

final validation = await settingsService.validateSettings();
print('Valid: $validation');
```

### Check Saved Values
```dart
final settings = await settingsService.getAllSettings();
settings.forEach((key, value) {
  print('$key: $value');
});
```

## Test Code

```dart
// Full setup example
Future<void> testPrinterSetup() async {
  final settings = PrinterSettingsService();
  await settings.initialize();
  
  // Save settings
  await settings.saveAllSettings({
    'address': '192.168.1.100',
    'port': 9100,
    'timeout': 5,
    'name': 'Test Printer',
    'density': 1,
    'paperWidth': 80,
  });
  
  // Verify saved
  final address = await settings.getPrinterAddress();
  print('Saved address: $address');
  
  // Test connection
  final success = await thermalPrinting.connectPrinter(address!);
  print('Connection: ${success ? 'OK' : 'FAILED'}');
  
  // Print test page
  if (success) {
    await thermalPrinting.printTestPage();
  }
}
```

## Configuration Locations

All settings stored in SharedPreferences with keys:
```
'printer_address'         → IP address
'printer_port'            → Port number
'printer_timeout_seconds' → Timeout
'printer_name'            → Friendly name
'printer_density'         → Density (0-3)
'paper_width_mm'          → Paper width
'auto_print_test'         → Boolean flag
'enable_printer_logging'  → Boolean flag
```

## Constants Reference

```dart
// Default values
const int DEFAULT_PORT = 9100;
const int DEFAULT_TIMEOUT = 5;
const int DEFAULT_DENSITY = 1;
const int DEFAULT_PAPER_WIDTH = 80;

// Available values
enum Density { light, normal, medium, dark } // 0, 1, 2, 3
enum PaperWidth { small, standard, wide } // 58, 80, 100mm

// Limits
const int MIN_PORT = 1;
const int MAX_PORT = 65535;
const int MIN_TIMEOUT = 1;
const int MAX_TIMEOUT = 60;
```

## Error Handling

```dart
try {
  await settingsService.setPrinterPort(99999); // Invalid
} catch (e) {
  print('Error: $e');
}

// Better: Check return value
bool success = await settingsService.setPrinterPort(9100);
if (!success) {
  print('Failed to save port');
}
```

## Widget Integration

```dart
// In any screen that needs printing
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  Future<void> _printDocument() async {
    // Uses saved settings automatically
    await thermalPrinting.printInvoice(
      invoice,
      items: items,
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Screen')),
      body: Center(
        child: ElevatedButton(
          onPressed: _printDocument,
          child: const Text('Print'),
        ),
      ),
    );
  }
}
```

---

**For complete documentation, see:**
- `PRINTER_SETTINGS_GUIDE.md` - Full guide
- `PRINTER_SETTINGS_IMPLEMENTATION.md` - Implementation details

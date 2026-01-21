// Quick Integration Examples for Thermal Printing
// Add these snippets to your existing screens to enable thermal printing

// ═══════════════════════════════════════════════════════════════════════════
// EXAMPLE 1: Order/Invoice Detail Screen (order_detail_screen.dart)
// ═══════════════════════════════════════════════════════════════════════════

/*
import '../services/thermal_printer/index.dart';

class OrderDetailScreen extends StatefulWidget {
  final Invoice invoice;
  // ...
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice #${widget.invoice.invoiceNo}'),
        actions: [
          IconButton(
            icon: Icon(Icons.receipt_long),
            onPressed: _printThermalReceipt,
            tooltip: 'Print Thermal Receipt',
          ),
        ],
      ),
      body: // ... your content
    );
  }

  Future<void> _printThermalReceipt() async {
    // 1. Prepare receipt items from your data
    final receiptItems = widget.invoice.items.map((item) {
      return ReceiptItem(
        name: item.productName,
        quantity: item.quantity,
        price: item.unitPrice,
      );
    }).toList();

    // 2. Call thermal printing service
    await thermalPrinting.printInvoice(
      widget.invoice,
      items: receiptItems,
      context: context,
    );
  }
}
*/

// ═══════════════════════════════════════════════════════════════════════════
// EXAMPLE 2: Purchase Detail with Thermal Print (purchase_detail_frame.dart)
// ═══════════════════════════════════════════════════════════════════════════

/*
import '../services/thermal_printer/index.dart';

class _PurchaseDetailFrameState extends State<PurchaseDetailFrame> {
  late Future<List<PurchaseItem>> _itemsFuture;

  Future<void> _printThermalReceipt() async {
    // Fetch items from database
    final items = await _itemsFuture;
    
    final receiptItems = items.map((item) {
      return ReceiptItem(
        name: item.productName ?? 'Unknown',
        quantity: item.quantity,
        price: item.unitPrice,
      );
    }).toList();

    await thermalPrinting.printPurchase(
      _purchase,
      items: receiptItems,
      supplierName: _supplier?.name,
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... your existing UI
      body: Column(
        children: [
          // ... existing content
          
          // Add thermal print button
          ElevatedButton.icon(
            onPressed: _printThermalReceipt,
            icon: const Icon(Icons.receipt_long),
            label: const Text('Thermal Receipt'),
          ),
        ],
      ),
    );
  }
}
*/

// ═══════════════════════════════════════════════════════════════════════════
// EXAMPLE 3: List with Long-Press Menu (purchase_frame.dart)
// ═══════════════════════════════════════════════════════════════════════════

/*
import '../services/thermal_printer/index.dart';

class _PurchaseFrameState extends State<PurchaseFrame> {
  void _showPurchaseMenu(Purchase purchase) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            // Thermal Receipt Option
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text("Print Thermal Receipt"),
              onTap: () async {
                Navigator.pop(context);
                
                // Fetch items from database
                final items = await widget.repo.getItemsByPurchaseId(purchase.id);
                final supplier = await widget.repo.getSupplierById(purchase.supplierId);
                
                // Convert to receipt items
                final receiptItems = items.map((item) {
                  return ReceiptItem(
                    name: item.productName ?? 'Unknown',
                    quantity: item.quantity,
                    price: item.unitPrice,
                  );
                }).toList();

                // Print
                await thermalPrinting.printPurchase(
                  purchase,
                  items: receiptItems,
                  supplierName: supplier?.name,
                  context: context,
                );
              },
            ),
            
            // Other options...
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text("Cancel"),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... your list view with items
      body: ListView(
        children: [
          InkWell(
            onLongPress: () => _showPurchaseMenu(purchase),
            child: // ... your list item
          ),
        ],
      ),
    );
  }
}
*/

// ═══════════════════════════════════════════════════════════════════════════
// EXAMPLE 4: Printer Settings Screen
// ═══════════════════════════════════════════════════════════════════════════

/*
import 'package:shared_preferences/shared_preferences.dart';
import '../services/thermal_printer/index.dart';

class PrinterSettingsScreen extends StatefulWidget {
  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  String? _connectedPrinter;

  @override
  void initState() {
    super.initState();
    _loadPrinterConfig();
  }

  Future<void> _loadPrinterConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _connectedPrinter = prefs.getString('printer_address');
    });
  }

  Future<void> _setupPrinter() async {
    final config = await thermalPrinting.showPrinterSetup(context);
    
    if (config != null) {
      // Save configuration
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_address', config['address']);
      await prefs.setInt('printer_port', config['port']);

      // Connect
      final success = await thermalPrinting.connectPrinter(
        config['address'],
        port: config['port'],
        context: context,
      );

      if (success) {
        setState(() {
          _connectedPrinter = '${config['address']}:${config['port']}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Connected Printer'),
            subtitle: Text(
              _connectedPrinter ?? 'Not connected',
              style: TextStyle(
                color: _connectedPrinter != null ? Colors.green : Colors.red,
              ),
            ),
          ),
          ListTile(
            title: const Text('Setup/Change Printer'),
            onTap: _setupPrinter,
          ),
          ListTile(
            title: const Text('Test Print'),
            onTap: () => thermalPrinting.printTestPage(context: context),
          ),
        ],
      ),
    );
  }
}
*/

// ═══════════════════════════════════════════════════════════════════════════
// EXAMPLE 5: Automatic Printer Connection on App Start
// ═══════════════════════════════════════════════════════════════════════════

/*
import 'package:shared_preferences/shared_preferences.dart';
import '../services/thermal_printer/index.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _autoConnectPrinter();
  }

  Future<void> _autoConnectPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString('printer_address');
    final port = prefs.getInt('printer_port') ?? 9100;

    if (address != null) {
      // Try to connect (silently, no dialog)
      await thermalPrinting.connectPrinter(address, port: port);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Invoice App',
      home: const HomePage(),
    );
  }
}
*/

// ═══════════════════════════════════════════════════════════════════════════
// EXAMPLE 6: Custom Receipt Template
// ═══════════════════════════════════════════════════════════════════════════

/*
import '../services/thermal_printer/index.dart';

Future<void> _printCustomReceipt() async {
  // Create custom receipt
  final receipt = ThermalReceiptWidget(
    title: 'DAILY SUMMARY',
    companyName: 'MIAN TRADERS',
    address: 'Sargodha, Pakistan',
    phone: '+92 345 4297128',
    invoiceNumber: 'DAILY-2024-01-20',
    date: DateTime.now().toString(),
    items: [
      ReceiptItem(name: 'Cash Sales', quantity: 50, price: 5000),
      ReceiptItem(name: 'Credit Sales', quantity: 30, price: 3000),
      ReceiptItem(name: 'Returns', quantity: -5, price: -500),
    ],
    subtotal: 250000,
    discount: 0,
    total: 250000,
    paid: 250000,
    pending: 0,
    footerText: 'End of Daily Summary',
    urduFooter: 'روزانہ کا خلاصہ',
  );

  // Print without pre-defined models
  await thermalPrinting.printCustom(
    receipt,
    context: context,
  );
}
*/

// ═══════════════════════════════════════════════════════════════════════════
// KEY POINTS TO REMEMBER:
// ═══════════════════════════════════════════════════════════════════════════

/*
1. IMPORTS:
   import '../services/thermal_printer/index.dart';
   
2. USAGE:
   - Single point of entry: thermalPrinting (global instance)
   - No need to instantiate ThermalPrintingService
   
3. THREE MAIN METHODS:
   - thermalPrinting.printInvoice(invoice, items: [...], context: context)
   - thermalPrinting.printPurchase(purchase, items: [...], context: context)
   - thermalPrinting.printCustom(receipt, context: context)
   
4. CONTEXT IS OPTIONAL:
   - Provide context for dialogs/snackbars
   - If null, still prints but no UI feedback
   
5. PRINTER SETUP:
   - First print will show connection dialog if not connected
   - Or use thermalPrinting.connectPrinter(address) manually
   - Or use thermalPrinting.showPrinterSetup(context) for UI dialog
   
6. RECEIPT ITEMS:
   Must convert your data models to ReceiptItem:
   
   ReceiptItem(
     name: 'Product Name',
     quantity: 5.0,
     price: 100.0,  // Price per unit
   )
   
7. URDU TEXT:
   - Automatically rendered properly by Flutter + SchFont
   - No special encoding needed
   - Works in: companyName, customerOrSupplierName, footerText, urduFooter

8. ERROR HANDLING:
   Boolean return indicates success/failure:
   
   final success = await thermalPrinting.printInvoice(...);
   if (success) {
     // Show success message
   } else {
     // Show error - check connection, printer IP, etc.
   }
*/

// Order/Invoice Integration Example
// Add this to your order_list_screen.dart or order_detail_screen.dart

// ═══════════════════════════════════════════════════════════════════════════
// UPDATE: order_list_screen.dart
// ═══════════════════════════════════════════════════════════════════════════

/*
REPLACE THE EXISTING PDF-BASED THERMAL PRINT WITH THIS:

In the existing _showOrderActions(Invoice invoice) method, replace:

OLD CODE:
────────
ListTile(
  leading: const Icon(Icons.receipt_long),
  title: const Text("Print Thermal Receipt"),
  onTap: () async {
    Navigator.pop(context);
    final file = await generateThermalReceipt(invoice);
    if (file != null) {
      await printPdfFile(file);  // PDF-based printing
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Sending to thermal printer...")),
      );
    }
  },
),

NEW CODE (ESC/POS-based):
────────────────────────
ListTile(
  leading: const Icon(Icons.receipt_long),
  title: const Text("Print Thermal Receipt"),
  onTap: () async {
    Navigator.pop(context);
    
    // Fetch invoice items from database
    final items = await _loadInvoiceItems(invoice.id);
    
    // Convert to ReceiptItems
    final receiptItems = items.map((item) {
      return ReceiptItem(
        name: item.productName ?? 'Unknown',
        quantity: item.quantity,
        price: item.unitPrice,
      );
    }).toList();

    // Print using new ESC/POS service
    await thermalPrinting.printInvoice(
      invoice,
      items: receiptItems,
      context: context,
    );
  },
),

ALSO ADD IMPORT AT TOP:
import '../services/thermal_printer/index.dart';

ALSO ADD HELPER METHOD:
Future<List<InvoiceItem>> _loadInvoiceItems(String invoiceId) async {
  // Load from your repository/database
  return widget.repo.getItemsByInvoiceId(invoiceId);
}
*/

// ═══════════════════════════════════════════════════════════════════════════
// UPDATE: order_detail_screen.dart
// ═══════════════════════════════════════════════════════════════════════════

/*
ADD THERMAL PRINT BUTTON TO ACTIONS:

In the AppBar actions, add:

IconButton(
  icon: const Icon(Icons.receipt_long),
  tooltip: 'Print Thermal Receipt',
  onPressed: _printThermalReceipt,
),

IMPLEMENT THE METHOD:

Future<void> _printThermalReceipt() async {
  // Fetch invoice items
  final items = await _loadInvoiceItems(widget.invoice.id);
  
  // Convert to ReceiptItems
  final receiptItems = items.map((item) {
    return ReceiptItem(
      name: item.productName ?? 'Unknown',
      quantity: item.quantity,
      price: item.unitPrice,
    );
  }).toList();

  // Print
  final success = await thermalPrinting.printInvoice(
    widget.invoice,
    items: receiptItems,
    context: context,
  );

  if (success) {
    print('✅ Receipt printed');
  }
}

HELPER METHOD:

Future<List<InvoiceItem>> _loadInvoiceItems(String invoiceId) async {
  // Load from your repository
  final repo = InvoiceRepository(); // or use widget.repo
  return await repo.getItemsByInvoiceId(invoiceId);
}
*/

// ═══════════════════════════════════════════════════════════════════════════
// WORKING EXAMPLE: Complete Integration in order_list_screen.dart
// ═══════════════════════════════════════════════════════════════════════════

/*
import 'package:flutter/material.dart';
import '../repositories/invoice_repo.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../services/thermal_printer/index.dart';  // NEW IMPORT

class OrderListScreen extends StatefulWidget {
  final InvoiceRepository repo;

  const OrderListScreen({Key? key, required this.repo}) : super(key: key);

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  List<Invoice> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    final invoices = await widget.repo.getAllInvoices();
    setState(() => _invoices = invoices);
  }

  void _showOrderActions(Invoice invoice) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            // ✅ NEW: Thermal Receipt (ESC/POS)
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text("Print Thermal Receipt"),
              onTap: () async {
                Navigator.pop(context);
                
                // Load items
                final items = await widget.repo.getItemsByInvoiceId(invoice.id);
                
                final receiptItems = items.map((item) {
                  return ReceiptItem(
                    name: item.productName ?? 'Unknown',
                    quantity: item.quantity,
                    price: item.unitPrice,
                  );
                }).toList();

                // Print
                await thermalPrinting.printInvoice(
                  invoice,
                  items: receiptItems,
                  context: context,
                );
              },
            ),

            // Other existing options...
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text("Print Invoice"),
              onTap: () async {
                Navigator.pop(context);
                // Your existing PDF print code
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text("Share PDF"),
              onTap: () async {
                Navigator.pop(context);
                // Your existing share code
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.redAccent),
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
      appBar: AppBar(
        title: const Text("Orders"),
      ),
      body: ListView.builder(
        itemCount: _invoices.length,
        itemBuilder: (context, index) {
          final invoice = _invoices[index];
          return ListTile(
            title: Text('Invoice #${invoice.invoiceNo}'),
            subtitle: Text(invoice.customerName ?? 'Unknown'),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showOrderActions(invoice),
            ),
          );
        },
      ),
    );
  }
}
*/

// ═══════════════════════════════════════════════════════════════════════════
// MINIMAL EXAMPLE: Simplest Integration
// ═══════════════════════════════════════════════════════════════════════════

/*
Just need:
1. Import the thermal printer service
2. Call thermalPrinting.printInvoice() or printPurchase()

That's it! Everything else is handled by the service.

Future<void> _quickPrint(Invoice invoice) async {
  // If you have items ready
  final items = [
    ReceiptItem(name: 'Product', quantity: 1, price: 100),
  ];

  // Print
  await thermalPrinting.printInvoice(
    invoice,
    items: items,
    context: context,
  );
  
  // Done! Service handles:
  // - Printer connection dialog (if not connected)
  // - Receipt widget creation
  // - Image generation
  // - ESC/POS command building
  // - Printer communication
  // - Error handling
  // - User feedback
}
*/

// ═══════════════════════════════════════════════════════════════════════════
// KEY DIFFERENCES: PDF vs ESC/POS
// ═══════════════════════════════════════════════════════════════════════════

/*
OLD WAY (PDF-based, still works but has issues):
────────────────────────────────────────────
1. Generate PDF document
2. Save to file
3. Open with platform printer dialog
4. User selects printer
5. Windows driver handles printing
6. Problems:
   - Urdu text may break
   - Slow (PDF generation + file I/O)
   - Requires printer drivers
   - Dialog may be confusing for users

NEW WAY (ESC/POS, recommended):
──────────────────────────────
1. Render Flutter widget (perfect Urdu)
2. Convert to image (100ms)
3. Convert image to ESC/POS bitmap
4. Send directly to printer via network
5. Benefits:
   ✅ Perfect Urdu rendering (HarfBuzz)
   ✅ Fast (no PDF conversion)
   ✅ No printer drivers needed
   ✅ Simple network setup
   ✅ Professional POS quality
   ✅ Automatic paper cut

BACKWARD COMPATIBILITY:
Both methods can coexist! Users can choose:
- "Thermal Receipt" → ESC/POS (recommended, perfect for retail)
- "Print Invoice" → PDF (for regular printers, office use)
*/

// ═══════════════════════════════════════════════════════════════════════════
// COMMON MISTAKES TO AVOID
// ═══════════════════════════════════════════════════════════════════════════

/*
❌ WRONG:
await thermalPrinting.printInvoice(invoice);
// Missing items! Will print empty receipt

✅ CORRECT:
final items = [ReceiptItem(...), ReceiptItem(...)];
await thermalPrinting.printInvoice(invoice, items: items, context: context);

───────────────────────────────────────────────

❌ WRONG:
final items = invoice.items.map((i) => i).toList();  // Wrong type!

✅ CORRECT:
final items = invoice.items.map((i) {
  return ReceiptItem(
    name: i.productName,
    quantity: i.quantity,
    price: i.unitPrice,
  );
}).toList();

───────────────────────────────────────────────

❌ WRONG:
// Try to print without printer connected, no context for dialog
await thermalPrinting.printInvoice(invoice, items: items);

✅ CORRECT:
// Always provide context for UI feedback
await thermalPrinting.printInvoice(
  invoice,
  items: items,
  context: context,  // Required for dialogs
);
*/

// ═══════════════════════════════════════════════════════════════════════════
// HELPFUL DEBUGGING TIPS
// ═══════════════════════════════════════════════════════════════════════════

/*
Check printer connection:
────────────────────────
if (thermalPrinting.isPrinterConnected) {
  print('Printer connected: ${thermalPrinting.connectedPrinter}');
} else {
  print('No printer connected');
}

Manually connect to printer:
───────────────────────────
final success = await thermalPrinting.connectPrinter(
  '192.168.1.100',
  port: 9100,
  context: context,
);
print('Connected: $success');

Test printer:
─────────────
await thermalPrinting.printTestPage(context: context);

See connection dialog:
─────────────────────
await thermalPrinting.showPrinterSetup(context);

Check if print was successful:
──────────────────────────────
final success = await thermalPrinting.printInvoice(
  invoice,
  items: items,
  context: context,
);

if (success) {
  print('✅ Receipt printed');
} else {
  print('❌ Printing failed');
}
*/

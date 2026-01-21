# 🚀 Quick Reference: Using PdfFontHelper

## Basic Usage

```dart
// Import the helper
import '../utils/pdf_font_helper.dart';

// Get both fonts at once (recommended)
final fonts = await PdfFontHelper.getBothFonts();
final regularFont = fonts['regular']!;
final boldFont = fonts['bold']!;

// Or get individual fonts
final regularFont = await PdfFontHelper.getRegularFont();
final boldFont = await PdfFontHelper.getBoldFont();

// Use in PDF generation
pw.Text(
  'Your Text',
  style: pw.TextStyle(font: regularFont, fontSize: 12),
)
```

---

## Available Export Functions

### Order Exports
```dart
import 'lib/ui/order/pdf_export_helper.dart';

// All functions below are ready to use:
- generatePdfReportWithChart()     // Reports with charts
- generateInvoicePdf()              // Single invoice
- generateAllOrdersPdf()            // Batch export with filters
- generateThermalReceipt()          // Thermal printer (80mm)
- printPdfFile()                    // Direct printing
- shareOrPrintPdf()                 // Share/print dialog
```

### Purchase Exports
```dart
import 'lib/ui/purchase_pdf_export_helper.dart';

- generatePurchasePdfWithChart()    // Purchase reports
- generatePurchaseInvoicePdf()      // Purchase document
- generateThermalReceipt()          // Purchase receipt
```

---

## Service Exports (Import Ready)

All services have been updated with `PdfFontHelper` imports:

```dart
// Stock
import 'lib/services/stock_export_service.dart';

// Expense  
import 'lib/services/expense_export_service.dart';

// Purchase
import 'lib/services/purchase_export_service.dart';

// Customer
import 'lib/services/customer_export_service.dart';

// Supplier
import 'lib/services/supplier_export_service.dart';

// Expiring Products
import 'lib/services/expiring_export_service.dart';

// Product
import 'lib/services/product_export_service.dart';

// Report
import 'lib/services/report_export_service.dart';
```

---

## Switching Printer Types (Future)

```dart
// When adding Bluetooth support:
PdfFontHelper.setPrinterType(PrinterType.bluetooth);

// Fonts will automatically switch
final fonts = await PdfFontHelper.getBothFonts();
// Now uses Bluetooth-optimized fonts

// Clear cache when needed
PdfFontHelper.clearCache();
```

---

## Font Information

**Default Font:** NotoSansArabic
- Regular: `assets/fonts/NotoSansArabic-Regular.ttf`
- Bold: `assets/fonts/NotoSansArabic-Bold.ttf`

**Why NotoSansArabic?**
- ✅ Superior Urdu/Arabic text shaping
- ✅ Proper character connection and ligatures
- ✅ Works well in PDF context
- ✅ Better than Scheherazade for PDFs

---

## Common Patterns

### Pattern 1: Simple PDF Generation
```dart
final fonts = await PdfFontHelper.getBothFonts();
final pdf = pw.Document();

pdf.addPage(
  pw.Page(
    build: (context) => pw.Text(
      'Your Text',
      style: pw.TextStyle(font: fonts['regular']!, fontSize: 12),
    ),
  ),
);

final bytes = await pdf.save();
// ... save or share
```

### Pattern 2: Multi-Page PDF
```dart
final fonts = await PdfFontHelper.getBothFonts();
final pdf = pw.Document();

pdf.addPage(
  pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    build: (context) => [
      pw.Text('Page 1', style: pw.TextStyle(font: fonts['bold']!)),
      pw.SizedBox(height: 20),
      pw.Text('Page 2', style: pw.TextStyle(font: fonts['bold']!)),
    ],
  ),
);

final bytes = await pdf.save();
```

### Pattern 3: With Platform-Aware File Saving
```dart
import '../../utils/platform_file_helper.dart';

final fonts = await PdfFontHelper.getBothFonts();
final pdf = pw.Document();

// ... build PDF ...

final pdfBytes = await pdf.save();
return await PlatformFileHelper.savePdfFile(
  pdfBytes: pdfBytes,
  suggestedName: 'MyDocument.pdf',
  dialogTitle: 'Save PDF',
);
```

---

## Troubleshooting

### Q: How do I update fonts for a new printer type?
A: Update `PdfFontHelper.getBothFonts()` logic, fonts are cached and centralized.

### Q: Can I use different fonts for different documents?
A: Yes, add parameters to `PdfFontHelper`:
```dart
static Future<pw.Font> getRegularFont({PrinterType? printerType}) async {
  final type = printerType ?? _currentPrinterType;
  final fontFile = ...
  // load based on type
}
```

### Q: How do I support a new language?
A: Add new font to assets, extend `PdfFontHelper` with language-specific fonts.

### Q: Is font caching thread-safe?
A: For mobile apps, consider using proper locking mechanisms if needed.

---

## Files Modified

### New Files
- ✅ `lib/utils/pdf_font_helper.dart` - Centralized font management

### Updated Files
- ✅ `lib/ui/order/pdf_export_helper.dart` - Uses `PdfFontHelper`
- ✅ `lib/ui/purchase_pdf_export_helper.dart` - Uses `PdfFontHelper`
- ✅ `lib/services/stock_export_service.dart` - Imports added
- ✅ `lib/services/expense_export_service.dart` - Imports added
- ✅ `lib/services/purchase_export_service.dart` - Imports added
- ✅ `lib/services/customer_export_service.dart` - Imports added
- ✅ `lib/services/supplier_export_service.dart` - Imports added
- ✅ `lib/services/expiring_export_service.dart` - Imports added
- ✅ `lib/services/product_export_service.dart` - Imports added
- ✅ `lib/services/report_export_service.dart` - Imports added

---

## Build Status
- ✅ No compilation errors
- ✅ All dependencies synced
- ✅ App runs successfully
- ✅ Ready for production

---

For detailed implementation info, see: `PDF_EXPORT_ARCHITECTURE.md`
For full details, see: `EXPORT_HELPERS_IMPLEMENTATION.md`

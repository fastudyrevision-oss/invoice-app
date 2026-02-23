import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/invoice.dart';
import '../../models/purchase.dart';
import '../../models/stock_disposal.dart';
import '../../db/database_helper.dart';
import '../../dao/invoice_item_dao.dart';
import '../../dao/product_dao.dart';
import '../printer_settings_service.dart';
import '../logger_service.dart';
import '../exception_handler.dart';
import '../error_message_service.dart';
import 'receipt_widget.dart';
import 'receipt_image_generator.dart';
import 'printer_service.dart';
import '../../ui/order/pdf_export_helper.dart';

/// 🎯 High-Level Thermal Printing Facade
///
/// Use this class for all thermal printing operations
/// Handles: Receipt generation → Image conversion → Printer communication
/// Integrates with PrinterSettingsService for persistent configuration
///
/// Example usage:
/// ```dart
/// final service = ThermalPrintingService();
/// await service.printInvoice(invoice, items: receiptItems);
/// ```
class ThermalPrintingService {
  final ThermalPrinterService _printerService = ThermalPrinterService();
  final PrinterSettingsService _settingsService = PrinterSettingsService();

  static const String _tag = '🎯 ThermalPrinting';

  // ═══════════════════════════════════════════════════════════════
  // Main Printing Methods
  // ═══════════════════════════════════════════════════════════════

  /// Print an invoice (order) receipt
  ///
  /// Uses saved printer settings if printerAddress is not provided
  /// Parameters:
  /// - [invoice]: Invoice model
  /// - [items]: Receipt items to print
  /// - [printerAddress]: Printer IP/MAC address (optional, uses saved if not provided)
  /// - [printerPort]: Printer port (optional, uses saved if not provided)
  /// - [context]: BuildContext for showing dialogs/snackbars
  Future<bool> printInvoice(
    Invoice invoice, {
    required List<ReceiptItem> items,
    BuildContext? context,
  }) async {
    try {
      logger.info(_tag, '📄 Printing invoice via PDF engine: ${invoice.id}');

      final mappedItems = items
          .map(
            (e) => {
              'product_name': e.name,
              'qty': e.quantity,
              'price': e.price,
            },
          )
          .toList();

      // Use the PDF export helper's silent print function
      return await printSilentThermalReceiptInternal(
        invoice,
        items: mappedItems,
      );
    } catch (e, st) {
      logger.error(
        _tag,
        'Failed to print invoice via PDF engine',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Print an order by fetching its items from the database
  /// This is a convenience method for "Fast Print" buttons
  Future<bool> printOrder(Invoice invoice, {BuildContext? context}) async {
    try {
      logger.info(_tag, '🚀 Fast Printing Order: ${invoice.id}');

      // Fetch items with product names
      final db = await DatabaseHelper.instance.db;
      final itemDao = InvoiceItemDao(db);
      final productDao = ProductDao(db);

      final invoiceItems = await itemDao.getByInvoiceId(invoice.id);
      final receiptItems = <ReceiptItem>[];

      for (final item in invoiceItems) {
        final product = await productDao.getById(item.productId);
        receiptItems.add(
          ReceiptItem(
            name: product?.name ?? 'Product ${item.productId}',
            quantity: item.qty.toDouble(),
            price: item.price,
          ),
        );
      }

      return await printInvoice(invoice, items: receiptItems, context: context);
    } catch (e, st) {
      logger.error(
        _tag,
        'Failed to fast print order',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Print a purchase receipt
  ///
  /// Uses saved printer settings if printerAddress is not provided
  /// Parameters:
  /// - [purchase]: Purchase model
  /// - [items]: Receipt items to print
  /// - [supplierName]: Name of supplier
  /// - [printerAddress]: Printer IP/MAC address (optional, uses saved if not provided)
  /// - [printerPort]: Printer port (optional, uses saved if not provided)
  /// - [context]: BuildContext for showing dialogs/snackbars
  Future<bool> printPurchase(
    Purchase purchase, {
    required List<ReceiptItem> items,
    required String supplierName,
    BuildContext? context,
  }) async {
    try {
      logger.info(_tag, '📦 Printing purchase via PDF engine: ${purchase.id}');

      final mappedItems = items
          .map(
            (e) => {
              'product_name': e.name,
              'qty': e.quantity,
              'price': e.price,
            },
          )
          .toList();

      return await printSilentPurchaseThermalReceiptInternal(
        purchase,
        mappedItems,
        supplierName,
      );
    } catch (e, st) {
      logger.error(
        _tag,
        'Failed to print purchase via PDF engine',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Print a stock disposal receipt
  Future<bool> printStockDisposal(
    StockDisposal disposal, {
    BuildContext? context,
  }) async {
    try {
      logger.info(
        _tag,
        '♻️ Printing stock disposal via PDF engine: ${disposal.id}',
      );
      return await printSilentStockDisposalThermalReceiptInternal(disposal);
    } catch (e, st) {
      logger.error(
        _tag,
        'Failed to print stock disposal via PDF engine',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Internal: Silent print invoice thermal receipt
  Future<bool> printSilentThermalReceiptInternal(
    Invoice invoice, {
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      logger.info(
        _tag,
        '🖨️ Silent printing thermal receipt for #${invoice.id}',
      );

      // Generate PDF bytes for thermal receipt
      final pdfBytes = await _generateInvoiceThermalPdf(invoice, items);

      // Use the existing silent print method
      return await printPdfSilently(pdfBytes, docName: 'Receipt_${invoice.id}');
    } catch (e, st) {
      logger.error(
        _tag,
        'Silent thermal print failed',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Internal: Silent print purchase thermal receipt
  Future<bool> printSilentPurchaseThermalReceiptInternal(
    Purchase purchase,
    List<Map<String, dynamic>> items,
    String supplierName,
  ) async {
    try {
      logger.info(
        _tag,
        '🖨️ Silent printing purchase receipt for #${purchase.id}',
      );

      // Generate simple purchase PDF for thermal printing
      final pdfBytes = await _generatePurchaseThermalPdf(
        purchase,
        items,
        supplierName,
      );

      return await printPdfSilently(
        pdfBytes,
        docName: 'Purchase_${purchase.invoiceNo}',
      );
    } catch (e, st) {
      logger.error(
        _tag,
        'Silent purchase print failed',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Internal: Silent print stock disposal thermal receipt
  Future<bool> printSilentStockDisposalThermalReceiptInternal(
    StockDisposal disposal,
  ) async {
    try {
      logger.info(
        _tag,
        '🖨️ Silent printing disposal receipt for #${disposal.id}',
      );

      // Generate simple disposal PDF for thermal printing
      final pdfBytes = await _generateDisposalThermalPdf(disposal);

      return await printPdfSilently(
        pdfBytes,
        docName: 'Disposal_${disposal.id}',
      );
    } catch (e, st) {
      logger.error(
        _tag,
        'Silent disposal print failed',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Generate thermal PDF for invoice
  Future<Uint8List> _generateInvoiceThermalPdf(
    Invoice invoice,
    List<Map<String, dynamic>>? items,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Receipt #${invoice.id}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Customer: ${invoice.customerName ?? 'N/A'}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              if (items != null)
                ...items.map(
                  (item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            '${item['product_name']}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Text(
                          '${item['qty']} x ${item['price']}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Rs ${invoice.total.toStringAsFixed(0)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text('Thank You!', style: const pw.TextStyle(fontSize: 10)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate thermal PDF for purchase
  Future<Uint8List> _generatePurchaseThermalPdf(
    Purchase purchase,
    List<Map<String, dynamic>> items,
    String supplierName,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Purchase #${purchase.invoiceNo}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Supplier: $supplierName',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              ...items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${item['product_name']}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Text(
                        '${item['qty']} x ${item['price']}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Rs ${purchase.total.toStringAsFixed(0)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate thermal PDF for disposal
  Future<Uint8List> _generateDisposalThermalPdf(StockDisposal disposal) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Stock Disposal',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Product: ${disposal.productName ?? 'N/A'}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Qty: ${disposal.qty}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Type: ${disposal.disposalType}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Cost Loss:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Rs ${disposal.costLoss.toStringAsFixed(0)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print custom receipt
  ///
  /// Uses saved printer settings if printerAddress is not provided
  Future<bool> printCustom(
    ThermalReceiptWidget receipt, {
    String? printerAddress,
    int? printerPort,
    BuildContext? context,
  }) async {
    try {
      logger.info(_tag, '🎨 Printing custom receipt');
      logger.startPerformanceTimer('print_custom');

      // Use saved settings if not provided
      printerAddress ??= await _settingsService.getPrinterAddress();
      printerPort ??= await _settingsService.getPrinterPort();

      if (printerAddress == null || printerAddress.isEmpty) {
        throw PrinterException(
          message: 'No printer address configured',
          originalError: 'Printer settings not saved',
        );
      }

      logger.debug(_tag, 'Using printer: $printerAddress:$printerPort');

      // Generate image
      logger.debug(_tag, 'Generating custom receipt image...');

      if (context == null) {
        throw PrinterException(
          message: 'Context required for receipt image generation',
        );
      }

      final receiptImage = await ReceiptImageGenerator.generateReceiptImage(
        context,
        receipt,
        pixelRatio: 2.0,
      );

      logger.debug(
        _tag,
        'Custom receipt image generated: ${receiptImage.lengthInBytes} bytes',
      );

      // Print
      final success = await _printWithPrinterSelection(
        receiptImage,
        printerAddress: printerAddress,
        printerPort: printerPort,
        context: (context.mounted) ? context : null,
      );

      logger.endPerformanceTimer('print_custom', tag: _tag);

      if (success) {
        logger.info(_tag, '✅ Custom receipt printed successfully');
      } else {
        logger.warning(_tag, '⚠️ Custom receipt print failed');
      }

      return success;
    } catch (e, st) {
      logger.endPerformanceTimer('print_custom', tag: _tag);
      final exception = ExceptionHandler.handleException(
        e,
        stackTrace: st,
        tag: _tag,
      );
      if (context != null && context.mounted) {
        ErrorMessageService.showError(context, exception);
      }
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Printer Connection & Configuration
  // ═══════════════════════════════════════════════════════════════

  /// Show printer connection setup dialog
  Future<Map<String, dynamic>?> showPrinterSetup(BuildContext context) async {
    return await PrinterConnectionDialog.showConnectionDialog(context);
  }

  /// Connect to printer
  /// Saves the connection details to settings if successful
  Future<bool> connectPrinter(
    String address, {
    int port = 9100,
    BuildContext? context,
  }) async {
    try {
      logger.info(_tag, '🔗 Attempting to connect to printer: $address:$port');
      logger.startPerformanceTimer('printer_connection');

      final success = await _printerService.connectNetwork(address, port: port);

      logger.endPerformanceTimer('printer_connection', tag: _tag);

      if (success) {
        // Save to settings
        await _settingsService.setPrinterAddress(address);
        await _settingsService.setPrinterPort(port);
        logger.info(
          _tag,
          '✅ Successfully connected to printer and saved settings',
        );
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Connected to printer'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return true;
      } else {
        logger.warning(_tag, '❌ Failed to connect to printer: $address:$port');
        throw PrinterException(
          message: 'Could not establish connection',
          printerAddress: address,
          printerPort: port,
        );
      }
    } catch (e, st) {
      logger.endPerformanceTimer('printer_connection', tag: _tag);
      final exception = ExceptionHandler.handleException(
        e,
        stackTrace: st,
        tag: _tag,
        context: {'printerAddress': address, 'printerPort': port},
      );
      if (context != null && context.mounted) {
        ErrorMessageService.showError(context, exception);
      }
      return false;
    }
  }

  /// Disconnect printer
  Future<void> disconnectPrinter() async {
    try {
      logger.info(_tag, '🔌 Disconnecting from printer');
      await _printerService.disconnect();
      logger.info(_tag, '✅ Printer disconnected');
    } catch (e, st) {
      logger.error(
        _tag,
        'Error disconnecting printer',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Check printer connection status
  bool get isPrinterConnected => _printerService.isConnected;

  /// Get currently connected printer
  String? get connectedPrinter {
    if (_printerService.isConnected) {
      return '${_printerService.printerAddress}:${_printerService.printerPort}';
    }
    return null;
  }

  /// Print test page
  Future<bool> printTestPage({BuildContext? context}) async {
    try {
      logger.info(_tag, '🧪 Printing test page');
      logger.startPerformanceTimer('test_print');

      final success = await _printerService.printTest();

      logger.endPerformanceTimer('test_print', tag: _tag);

      if (success) {
        logger.info(_tag, '✅ Test page printed successfully');
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Test page sent to printer'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        logger.warning(_tag, '❌ Failed to print test page');
        throw PrinterException(
          message: 'Printer did not respond to test command',
        );
      }
      return success;
    } catch (e, st) {
      logger.endPerformanceTimer('test_print', tag: _tag);
      final exception = ExceptionHandler.handleException(
        e,
        stackTrace: st,
        tag: _tag,
      );
      if (context != null && context.mounted) {
        ErrorMessageService.showError(context, exception);
      }
      return false;
    }
  }

  /// Auto-connect to saved printer on app startup
  /// Silently attempts to connect without showing dialogs
  /// Call this in your main app initialization
  Future<bool> autoConnectSavedPrinter() async {
    try {
      logger.debug(_tag, 'Attempting to auto-connect to saved printer');

      final address = await _settingsService.getPrinterAddress();
      if (address == null || address.isEmpty) {
        logger.debug(_tag, 'No saved printer configuration found');
        return false;
      }

      final port = await _settingsService.getPrinterPort();
      logger.info(_tag, 'Auto-connecting to saved printer: $address:$port');
      logger.startPerformanceTimer('auto_connect_printer');

      final success = await _printerService.connectNetwork(address, port: port);

      logger.endPerformanceTimer('auto_connect_printer', tag: _tag);

      if (success) {
        logger.info(
          _tag,
          '✅ Successfully auto-connected to printer: $address:$port',
        );
      } else {
        logger.warning(
          _tag,
          '⚠️ Failed to auto-connect to printer at $address:$port',
        );
      }

      return success;
    } catch (e, st) {
      logger.error(_tag, 'Error during auto-connect', error: e, stackTrace: st);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Private Helper Methods
  // ═══════════════════════════════════════════════════════════════

  /// Internal: Print with printer selection if not connected
  Future<bool> _printWithPrinterSelection(
    Uint8List receiptImage, {
    String? printerAddress,
    int printerPort = 9100,
    BuildContext? context,
  }) async {
    try {
      final address = (printerAddress != null && printerAddress.isNotEmpty)
          ? printerAddress
          : null;

      if (address != null) {
        final isIP = ThermalPrinterService.isValidIPAddress(address);

        if (isIP) {
          logger.debug(
            _tag,
            'Connecting to network printer: $printerAddress:$printerPort',
          );
          final connected = await _printerService.connectNetwork(
            address,
            port: printerPort,
          );

          if (connected) {
            // Send to network printer
            return await _printerService.printReceipt(
              receiptImage,
              autoClose: true,
            );
          }
          logger.warning(
            _tag,
            'Network connection failed, falling back to system print',
          );
        }

        // Try USB/System print for names or failed network IPs
        return await _printViaSystem(receiptImage, printerName: address);
      } else if (!_printerService.isConnected) {
        // No printer connected, show setup dialog
        logger.warning(_tag, 'No printer connected, showing setup dialog');

        if (context == null) {
          logger.error(_tag, 'No printer connected and no context for dialog');
          throw PrinterException(
            message: 'No printer configured and cannot show setup dialog',
          );
        }

        final printerConfig = await showPrinterSetup(context);
        if (printerConfig == null) {
          logger.warning(_tag, 'User cancelled printer setup');
          throw PrinterException(message: 'Printer setup cancelled by user');
        }

        logger.debug(_tag, 'Connecting to user-selected printer');

        final connected = await _printerService.connectNetwork(
          printerConfig['address'],
          port: printerConfig['port'],
        );

        if (!connected) {
          logger.error(_tag, 'Failed to connect to user-selected printer');
          throw PrinterException(
            message: 'Failed to connect to selected printer',
            printerAddress: printerConfig['address'],
            printerPort: printerConfig['port'],
          );
        }
      }

      // Send receipt to printer
      logger.debug(
        _tag,
        'Sending receipt to printer (${receiptImage.lengthInBytes} bytes)',
      );
      logger.startPerformanceTimer('send_to_printer');

      final success = await _printerService.printReceipt(
        receiptImage,
        autoClose: true,
      );

      logger.endPerformanceTimer('send_to_printer', tag: _tag);

      if (success) {
        logger.info(_tag, '✅ Receipt sent to printer successfully');
      } else {
        logger.warning(_tag, '⚠️ Receipt send failed');
        throw PrinterException(message: 'Printer did not accept receipt data');
      }

      return success;
    } catch (e, st) {
      logger.error(_tag, 'Error in print sequence', error: e, stackTrace: st);
      if (e is! PrinterException) {
        ExceptionHandler.handleException(e, stackTrace: st, tag: _tag);
      }
      rethrow;
    }
  }

  /// Print via system (USB/Windows) using the printing package
  /// This bypasses the socket-based ESC/POS but still allows silent printing
  Future<bool> _printViaSystem(
    Uint8List receiptImage, {
    String? printerName,
  }) async {
    try {
      logger.info(
        _tag,
        '🖨️ System Print Request: ${printerName ?? "Default (Interactive)"}',
      );

      final pdfBytes = await _generatePdfFromImage(receiptImage);

      if (printerName != null && printerName.isNotEmpty) {
        // Find specific printer for silent printing
        try {
          final printers = await Printing.listPrinters();
          logger.debug(
            _tag,
            'Available system printers: ${printers.map((p) => p.name).join(", ")}',
          );

          final printer = printers.firstWhere(
            (p) => p.name.toLowerCase() == printerName.toLowerCase(),
            orElse: () => printers.firstWhere(
              (p) => p.name.toLowerCase().contains(printerName.toLowerCase()),
              orElse: () => throw Exception('Printer not found'),
            ),
          );

          logger.info(_tag, '✅ Found matching printer: ${printer.name}');
          return await Printing.directPrintPdf(
            printer: printer,
            onLayout: (format) => pdfBytes,
            name: 'Invoice_${DateTime.now().millisecondsSinceEpoch}',
          );
        } catch (e) {
          logger.warning(
            _tag,
            'Silent print failed - Printer "$printerName" not found or error',
            error: e,
          );
        }
      }

      // Fallback to dialog if printer not found or not specified
      logger.info(_tag, 'Falling back to system print dialog');
      return await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Invoice_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      logger.error(_tag, 'System print failed', error: e);
      return false;
    }
  }

  /// 🚀 Print a PDF silently using saved settings
  /// Respects Network/USB priority and avoids all dialogs
  Future<bool> printPdfSilently(Uint8List pdfBytes, {String? docName}) async {
    try {
      final docTitle =
          docName ?? 'Receipt_${DateTime.now().millisecondsSinceEpoch}';
      logger.info(_tag, '🚀 Starting silent PDF print: $docTitle');

      // Get saved settings
      final address = await _settingsService.getPrinterAddress();
      final port = await _settingsService.getPrinterPort();
      final usbName = await _settingsService.getUsbPrinterName();
      final priority = await _settingsService.getPrinterPriority();

      logger.debug(
        _tag,
        'Settings for silent print',
        context: {
          'address': address,
          'port': port,
          'usbName': usbName,
          'priority': priority,
        },
      );

      if (priority == 'network') {
        // 1. Try Network (Silent ESC/POS)
        if (address != null && address.isNotEmpty) {
          logger.debug(_tag, 'Attempting silent network print to $address');
          final success = await _printPdfViaNetwork(pdfBytes, address, port);
          if (success) return true;
          logger.warning(
            _tag,
            'Network silent print failed, falling back to USB if available',
          );
        }

        // 2. Fallback to USB (Silent System Print)
        if (usbName != null && usbName.isNotEmpty) {
          logger.debug(_tag, 'Attempting silent USB fallback to $usbName');
          return await _printPdfViaSystemSilent(pdfBytes, usbName, docTitle);
        }
      } else {
        // 1. Try USB (Silent System Print)
        if (usbName != null && usbName.isNotEmpty) {
          logger.debug(_tag, 'Attempting silent USB print to $usbName');
          final success = await _printPdfViaSystemSilent(
            pdfBytes,
            usbName,
            docTitle,
          );
          if (success) return true;
          logger.warning(
            _tag,
            'USB silent print failed, falling back to network if available',
          );
        }

        // 2. Fallback to Network (Silent ESC/POS)
        if (address != null && address.isNotEmpty) {
          logger.debug(_tag, 'Attempting silent network fallback to $address');
          return await _printPdfViaNetwork(pdfBytes, address, port);
        }
      }

      logger.error(
        _tag,
        'No printer configured or all silent print attempts failed',
      );
      return false;
    } catch (e, st) {
      logger.error(
        _tag,
        '❌ Error in silent PDF print',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Internal: Print PDF to network printer (converts to image → ESC/POS)
  Future<bool> _printPdfViaNetwork(
    Uint8List pdfBytes,
    String address,
    int port,
  ) async {
    try {
      // Rasterize PDF to images (one per page)
      int pageIndex = 0;
      bool allPagesSuccess = true;

      await for (final page in Printing.raster(pdfBytes, dpi: 200)) {
        final imageBytes = await page.toPng();

        final connected = await _printerService.connectNetwork(
          address,
          port: port,
        );
        if (!connected) return false;

        final success = await _printerService.printReceipt(
          imageBytes,
          autoClose: true,
        );

        if (!success) allPagesSuccess = false;
        pageIndex++;
      }

      return pageIndex > 0 && allPagesSuccess;
    } catch (e) {
      logger.error(_tag, 'Network PDF print failed', error: e);
      return false;
    }
  }

  /// Internal: Print PDF to specific USB printer silently
  Future<bool> _printPdfViaSystemSilent(
    Uint8List pdfBytes,
    String printerName,
    String docName,
  ) async {
    try {
      final printers = await Printing.listPrinters();
      final printer = printers.firstWhere(
        (p) => p.name.toLowerCase() == printerName.toLowerCase(),
        orElse: () => printers.firstWhere(
          (p) => p.name.toLowerCase().contains(printerName.toLowerCase()),
          orElse: () {
            logger.warning(
              _tag,
              '⚠️ Printer "$printerName" not found in system list',
            );
            throw Exception('Printer "$printerName" not found');
          },
        ),
      );

      logger.info(_tag, '✅ Selected system printer: ${printer.name}');

      return await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) => pdfBytes,
        name: docName,
      );
    } catch (e) {
      logger.error(
        _tag,
        '❌ System silent print failed for printer "$printerName"',
        error: e,
      );
      return false;
    }
  }

  /// Helper: Convert the receipt image to a PDF for system printing
  Future<Uint8List> _generatePdfFromImage(Uint8List imageBytes) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);
    final paperFormat = await _getPaperFormat();

    pdf.addPage(
      pw.Page(
        pageFormat: paperFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Center(child: pw.Image(image)),
      ),
    );
    return pdf.save();
  }

  /// Helper: Get dynamic paper format based on settings
  Future<PdfPageFormat> _getPaperFormat() async {
    final paperWidthMm = await _settingsService.getPaperWidth();
    // 1mm = 2.8346 points
    return PdfPageFormat(paperWidthMm * 2.8346, double.infinity);
  }
}

/// 🏭 Singleton instance for global access
final thermalPrinting = ThermalPrintingService();

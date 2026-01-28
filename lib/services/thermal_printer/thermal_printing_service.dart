import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../models/invoice.dart';
import '../../models/purchase.dart';
import '../printer_settings_service.dart';
import '../logger_service.dart';
import '../exception_handler.dart';
import '../error_message_service.dart';
import 'receipt_widget.dart';
import 'receipt_image_generator.dart';
import 'printer_service.dart';

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
    String? printerAddress,
    int? printerPort,
    BuildContext? context,
  }) async {
    try {
      logger.info(
        _tag,
        '📄 Printing invoice: ${invoice.id}',
        context: {
          'invoiceId': invoice.id,
          'itemCount': items.length,
          'printer': printerAddress,
        },
      );

      logger.startPerformanceTimer('print_invoice');

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

      // Create receipt widget
      final receipt = ReceiptFactory.fromInvoice(invoice, items: items);

      // Generate image
      logger.debug(_tag, '🖼️  Generating receipt image...');
      final receiptImage = await ReceiptImageGenerator.generateReceiptImage(
        receipt,
        pixelRatio: 2.0,
      );

      logger.debug(
        _tag,
        'Receipt image generated: ${receiptImage.lengthInBytes} bytes',
      );

      // Print
      final success = await _printWithPrinterSelection(
        receiptImage,
        printerAddress: printerAddress,
        printerPort: printerPort,
        context: (context != null && context.mounted) ? context : null,
      );

      logger.endPerformanceTimer('print_invoice', tag: _tag);

      if (success) {
        logger.info(_tag, '✅ Invoice printed successfully');
      } else {
        logger.warning(_tag, '⚠️ Invoice print failed');
      }

      return success;
    } catch (e, st) {
      logger.endPerformanceTimer('print_invoice', tag: _tag);
      final exception = ExceptionHandler.handleException(
        e,
        stackTrace: st,
        tag: _tag,
        context: {'invoiceId': invoice.id},
      );
      if (context != null && context.mounted) {
        ErrorMessageService.showError(context, exception);
      }
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
    String? supplierName,
    String? printerAddress,
    int? printerPort,
    BuildContext? context,
  }) async {
    try {
      logger.info(
        _tag,
        '📦 Printing purchase: ${purchase.id}',
        context: {
          'purchaseId': purchase.id,
          'supplier': supplierName,
          'itemCount': items.length,
        },
      );

      logger.startPerformanceTimer('print_purchase');

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

      // Create receipt widget
      final receipt = ReceiptFactory.fromPurchase(
        purchase,
        items: items,
        supplierName: supplierName,
      );

      // Generate image
      logger.debug(_tag, '🖼️  Generating receipt image...');
      final receiptImage = await ReceiptImageGenerator.generateReceiptImage(
        receipt,
        pixelRatio: 2.0,
      );

      logger.debug(
        _tag,
        'Receipt image generated: ${receiptImage.lengthInBytes} bytes',
      );

      // Print
      final success = await _printWithPrinterSelection(
        receiptImage,
        printerAddress: printerAddress,
        printerPort: printerPort,
        context: (context != null && context.mounted) ? context : null,
      );

      logger.endPerformanceTimer('print_purchase', tag: _tag);

      if (success) {
        logger.info(_tag, '✅ Purchase printed successfully');
      } else {
        logger.warning(_tag, '⚠️ Purchase print failed');
      }

      return success;
    } catch (e, st) {
      logger.endPerformanceTimer('print_purchase', tag: _tag);
      final exception = ExceptionHandler.handleException(
        e,
        stackTrace: st,
        tag: _tag,
        context: {'purchaseId': purchase.id},
      );
      if (context != null && context.mounted) {
        ErrorMessageService.showError(context, exception);
      }
      return false;
    }
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
      final receiptImage = await ReceiptImageGenerator.generateReceiptImage(
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
        context: (context != null && context.mounted) ? context : null,
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
      // If printer address provided, connect and print
      if (printerAddress != null) {
        logger.debug(
          _tag,
          'Connecting to specified printer: $printerAddress:$printerPort',
        );

        final connected = await _printerService.connectNetwork(
          printerAddress,
          port: printerPort,
        );

        if (!connected) {
          logger.warning(
            _tag,
            'Could not connect to printer at $printerAddress:$printerPort',
          );
          throw PrinterException(
            message: 'Could not connect to printer',
            printerAddress: printerAddress,
            printerPort: printerPort,
          );
        }
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
}

/// 🏭 Singleton instance for global access
final thermalPrinting = ThermalPrintingService();

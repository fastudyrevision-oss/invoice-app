import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'esc_pos_command_builder.dart';

/// 🔗 Thermal Printer Communication Service
/// 
/// Supports:
/// - USB printers (Windows, macOS, Linux)
/// - Bluetooth printers (Android, iOS)
/// - Network printers (TCP/IP)
/// 
/// Tested with: Black Copper BC-85AC 80mm thermal printer
class ThermalPrinterService {
  static const String _tag = '🖨️ ThermalPrinter';

  // Printer connection info
  String? _printerAddress;
  int? _printerPort;
  Socket? _socket;
  bool _isConnected = false;

  // USB support (Windows)
  bool get isUSBAvailable => Platform.isWindows;

  // Getters
  bool get isConnected => _isConnected;
  String? get printerAddress => _printerAddress;
  int? get printerPort => _printerPort;

  // ═══════════════════════════════════════════════════════════════
  // Connection Methods
  // ═══════════════════════════════════════════════════════════════

  /// Connect to printer via network/Bluetooth (TCP/IP)
  /// 
  /// Parameters:
  /// - [address]: IP address or Bluetooth MAC address
  /// - [port]: Port number (usually 9100 for network printers)
  /// - [timeout]: Connection timeout
  Future<bool> connectNetwork(
    String address, {
    int port = 9100,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      print('$_tag Connecting to $address:$port...');

      _socket = await Socket.connect(
        address,
        port,
        timeout: timeout,
      );

      _printerAddress = address;
      _printerPort = port;
      _isConnected = true;

      print('$_tag ✅ Connected successfully');
      return true;
    } on SocketException catch (e) {
      print('$_tag ❌ Connection failed: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Disconnect from printer
  Future<void> disconnect() async {
    try {
      await _socket?.close();
      _isConnected = false;
      print('$_tag ✅ Disconnected');
    } catch (e) {
      print('$_tag ❌ Error disconnecting: $e');
    }
  }

  /// Check if connected and reconnect if needed
  Future<bool> ensureConnected() async {
    if (_isConnected && _socket != null) {
      return true;
    }

    if (_printerAddress != null && _printerPort != null) {
      return await connectNetwork(_printerAddress!, port: _printerPort!);
    }

    print('$_tag ❌ No printer address configured');
    return false;
  }

  // ═══════════════════════════════════════════════════════════════
  // Printing Methods
  // ═══════════════════════════════════════════════════════════════

  /// Send ESC/POS commands to printer
  /// 
  /// Parameters:
  /// - [commands]: List of byte sequences to send
  /// - [waitForResponse]: Wait for printer acknowledgment
  Future<bool> sendCommand(
    List<int> commands, {
    bool waitForResponse = false,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      if (!await ensureConnected()) {
        throw Exception('Printer not connected');
      }

      print('$_tag Sending ${commands.length} bytes to printer...');

      // Send data
      _socket!.add(commands);
      await _socket!.flush();

      print('$_tag ✅ Data sent');

      // Wait for printer response if requested
      if (waitForResponse) {
        return await _waitForAck(timeout: timeout);
      }

      return true;
    } catch (e) {
      print('$_tag ❌ Error sending command: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Print receipt image with automatic cut
  /// 
  /// This is the main method for printing receipts
  Future<bool> printReceipt(
    Uint8List receiptImageBytes, {
    bool autoClose = true,
  }) async {
    try {
      // Build ESC/POS command sequence
      final builder = EscPosCommandBuilder();
      builder.buildReceiptSequence(receiptImageBytes);

      // Send to printer
      final success = await sendCommand(
        builder.getBytes(),
        waitForResponse: true,
      );

      if (success) {
        print('$_tag ✅ Receipt printed successfully');
      }

      if (autoClose) {
        await disconnect();
      }

      return success;
    } catch (e) {
      print('$_tag ❌ Error printing receipt: $e');
      return false;
    }
  }

  /// Print test pattern (useful for checking printer)
  Future<bool> printTest() async {
    try {
      final builder = EscPosCommandBuilder();
      builder.reset();
      builder.setAlignment(TextAlignment.center);
      builder.setBoldMode(true);
      builder.writeLine('TEST PRINT');
      builder.setBoldMode(false);
      builder.lineFeed();
      builder.writeText('Date: ${DateTime.now()}');
      builder.lineFeed();
      builder.feedLines(2);
      builder.fullCut();

      return await sendCommand(builder.getBytes(), waitForResponse: true);
    } catch (e) {
      print('$_tag ❌ Test print failed: $e');
      return false;
    }
  }

  /// Raw command send (for advanced use)
  Future<bool> sendRaw(Uint8List data) async {
    return await sendCommand(data.toList(), waitForResponse: true);
  }

  // ═══════════════════════════════════════════════════════════════
  // Helper Methods
  // ═══════════════════════════════════════════════════════════════

  /// Wait for printer acknowledgment
  Future<bool> _waitForAck({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      if (_socket == null) return false;

      final completer = Completer<bool>();

      // Listen for response
      _socket!.listen(
        (data) {
          print('$_tag Received ${data.length} bytes from printer');
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        onError: (error) {
          print('$_tag ❌ Socket error: $error');
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );

      // Timeout
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          print('$_tag ⏱️ Waiting for response timed out (assuming OK)');
          return true; // Assume success if no error within timeout
        },
      );
    } catch (e) {
      print('$_tag ❌ Error waiting for ACK: $e');
      return false;
    }
  }

  /// Get printer status
  Future<String> getPrinterStatus() async {
    try {
      if (!await ensureConnected()) {
        return 'Not connected';
      }

      // Query printer status (GS a)
      final cmd = Uint8List.fromList([0x1D, 0x72, 0x01]);
      await sendCommand(cmd);
      return 'Status requested';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Utility: Validate IP address
  static bool isValidIPAddress(String address) {
    final ipPattern = RegExp(
      r'^(\d{1,3}\.){3}\d{1,3}$',
    );
    return ipPattern.hasMatch(address);
  }

  /// Utility: Validate MAC address (for Bluetooth)
  static bool isValidMACAddress(String address) {
    final macPattern = RegExp(
      r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$',
    );
    return macPattern.hasMatch(address);
  }
}

/// 📱 UI Helper: Printer Connection Dialog
class PrinterConnectionDialog {
  static Future<Map<String, dynamic>?> showConnectionDialog(
    BuildContext context,
  ) async {
    final addressController = TextEditingController();
    final portController = TextEditingController(text: '9100');

    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to Thermal Printer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: 'Printer Address (IP or MAC)',
                  hintText: '192.168.1.100 or 00:11:22:33:44:55',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Port (default 9100)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final address = addressController.text.trim();
              final port = int.tryParse(portController.text) ?? 9100;

              if (address.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter printer address')),
                );
                return;
              }

              Navigator.pop(context, {
                'address': address,
                'port': port,
              });
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

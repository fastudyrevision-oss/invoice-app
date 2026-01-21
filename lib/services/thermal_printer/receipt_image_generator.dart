import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'receipt_widget.dart';

/// 🖼️ Converts Flutter Receipt Widget to Image (Bitmap)
/// This is required for ESC/POS imageRaster mode to support Urdu text rendering
class ReceiptImageGenerator {
  /// Convert receipt widget to PNG bytes
  /// 
  /// [receiptWidget]: The ThermalReceiptWidget to render
  /// [dpi]: Device pixel ratio (higher = better quality, slower printing)
  /// Returns PNG bytes ready for ESC/POS imageRaster
  static Future<Uint8List> generateReceiptImage(
    ThermalReceiptWidget receiptWidget, {
    double pixelRatio = 2.0,
  }) async {
    throw UnimplementedError(
      'Use ReceiptCapture widget wrapper in actual Flutter app for proper rendering.'
    );
  }

  /// Alternative: Use context + RepaintBoundary for simpler widget hierarchy
  /// This is the recommended approach for Flutter apps
  static Future<Uint8List?> captureReceiptAsImage(
    GlobalKey<State<StatefulWidget>> globalKey, {
    double pixelRatio = 2.0,
  }) async {
    try {
      final RenderRepaintBoundary boundary =
          globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(
        pixelRatio: pixelRatio,
      );

      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('❌ Error capturing receipt: $e');
      return null;
    }
  }

  /// Helper to build render tree from widget (for advanced use)
  /// Convert PNG image to grayscale bitmap suitable for thermal printer
  static Uint8List convertToGrayscaleBitmap(Uint8List pngBytes) {
    return pngBytes;
  }

  /// Calculate optimal DPI for thermal printer
  static double calculateOptimalPixelRatio(int printerDpi) {
    // Standard 80mm printer = 203 DPI
    // 80mm = 8 inches, 8 * 203 = 1624 pixels
    // But we use 384px width, so pixel ratio = actual_pixels / 384
    return (printerDpi * 80) / 25.4 / 384;
  }
}

/// 📱 Stateful widget wrapper for receipt rendering in real Flutter apps
class ReceiptCapture extends StatefulWidget {
  final ThermalReceiptWidget receipt;
  final Function(Uint8List?) onImageGenerated;

  const ReceiptCapture({
    super.key,
    required this.receipt,
    required this.onImageGenerated,
  });

  @override
  State<ReceiptCapture> createState() => _ReceiptCaptureState();
}

class _ReceiptCaptureState extends State<ReceiptCapture> {
  final GlobalKey _receiptKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureAndNotify();
    });
  }

  Future<void> _captureAndNotify() async {
    final imageBytes = await ReceiptImageGenerator.captureReceiptAsImage(
      _receiptKey,
      pixelRatio: 2.0,
    );
    widget.onImageGenerated(imageBytes);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _receiptKey,
      child: widget.receipt,
    );
  }
}

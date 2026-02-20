import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

/// 🌉 PdfTextBridge
///
/// A high-fidelity utility that renders Flutter text to images for use in PDFs.
/// This solves the "Noon Ghunna" and other complex Urdu rendering issues by
/// using Flutter's native text engine instead of the PDF library's engine.
class PdfTextBridge {
  static final Map<String, pw.MemoryImage> _cache = {};

  /// Clears the image cache. Use this between different PDF generations if needed.
  static void clearCache() => _cache.clear();

  /// Returns a pre-rendered image for the given text and style if it exists.
  static pw.MemoryImage? getCachedImage(String text, String fontKey) {
    return _cache['$text|$fontKey'];
  }

  /// Renders a string of text into a high-resolution PNG image.
  ///
  /// [text] The string to render.
  /// [fontFamily] The font family to use (must be registered in pubspec.yaml).
  /// [fontSize] The size of the font.
  /// [color] The text color.
  /// [bold] Whether to use bold weight.
  /// [pixelRatio] Higher ratio means sharper images in PDF (default 3.0 for print quality).
  static Future<pw.MemoryImage> renderToImage({
    required String text,
    required String fontFamily,
    double fontSize = 12,
    Color color = Colors.black,
    bool bold = false,
    double pixelRatio = 3.0,
  }) async {
    final cacheKey = '$text|$fontFamily|$fontSize|$bold';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final textStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize * pixelRatio,
      color: color,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.rtl, // Crucial for Urdu
      textAlign: TextAlign.right,
    );

    textPainter.layout();

    // Add some padding to avoid clipping
    final width = textPainter.width + (4 * pixelRatio);
    final height = textPainter.height + (2 * pixelRatio);

    // Draw the text
    textPainter.paint(canvas, Offset(2 * pixelRatio, 1 * pixelRatio));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.ceil(), height.ceil());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw StateError('Failed to encode rendered text to PNG');
    }

    final memoryImage = pw.MemoryImage(byteData.buffer.asUint8List());
    _cache[cacheKey] = memoryImage;

    return memoryImage;
  }

  /// Helper to check if a string contains characters that require Bridge rendering.
  static bool needsBridge(String text) {
    // ں (Noon Ghunna) is the primary trigger, but we can add more if needed
    return text.contains('\u06BA');
  }
}

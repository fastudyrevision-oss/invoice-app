import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'dart:convert';

/// 🖨️ ESC/POS Command Builder for BC-85AC (80mm Thermal Printer)
/// 
/// Generates raw ESC/POS byte sequences for:
/// - Image printing (imageRaster mode)
/// - Text printing
/// - Formatting (bold, centering, etc.)
/// - Paper control (cut, feed)
/// - Printer initialization
/// 
/// Reference: ESC/POS Specification v1.14+

/// Text alignment options for ESC/POS
enum TextAlignment { left, center, right }

class EscPosCommandBuilder {
  final List<int> _buffer = [];

  // ═══════════════════════════════════════════════════════════════
  // ESC/POS Command Codes (BC-85AC compatible)
  // ═══════════════════════════════════════════════════════════════

  static const int ESC = 0x1B; // Escape character
  static const int GS = 0x1D; // Group Separator (for image printing)
  static const int CR = 0x0D; // Carriage Return
  static const int LF = 0x0A; // Line Feed
  static const int NULL_BYTE = 0x00;

  // ═══════════════════════════════════════════════════════════════
  // Initialization & Reset
  // ═══════════════════════════════════════════════════════════════

  /// Initialize printer (reset to defaults)
  void reset() {
    _buffer.addAll([ESC, 0x40]); // ESC @
  }

  /// Set print mode (normal text)
  void setNormalMode() {
    _buffer.addAll([ESC, 0x21, 0x00]); // ESC ! 0
  }

  /// Set bold mode
  void setBoldMode(bool enabled) {
    if (enabled) {
      _buffer.addAll([ESC, 0x45, 0x01]); // ESC E 1 (emphasize on)
    } else {
      _buffer.addAll([ESC, 0x45, 0x00]); // ESC E 0 (emphasize off)
    }
  }

  /// Double height text
  void setDoubleHeight(bool enabled) {
    if (enabled) {
      _buffer.addAll([ESC, 0x21, 0x10]); // ESC ! 10h (double height)
    } else {
      _buffer.addAll([ESC, 0x21, 0x00]); // ESC ! 0 (normal height)
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Text Alignment
  // ═══════════════════════════════════════════════════════════════

  /// Set text alignment (0=left, 1=center, 2=right)
  void setAlignment(TextAlignment alignment) {
    int alignCode = 0x00;
    switch (alignment) {
      case TextAlignment.left:
        alignCode = 0;
        break;
      case TextAlignment.center:
        alignCode = 1;
        break;
      case TextAlignment.right:
        alignCode = 2;
        break;
    }
    _buffer.addAll([ESC, 0x61, alignCode]); // ESC a <alignment>
  }

  // ═══════════════════════════════════════════════════════════════
  // Text Printing (for English only - Urdu uses image mode)
  // ═══════════════════════════════════════════════════════════════

  /// Print ASCII text
  void writeText(String text) {
    _buffer.addAll(utf8.encode(text));
  }

  /// Print text with automatic line break
  void writeLine(String text) {
    writeText(text);
    lineFeed();
  }

  /// Line feed (move to next line)
  void lineFeed({int lines = 1}) {
    for (int i = 0; i < lines; i++) {
      _buffer.add(LF);
    }
  }

  /// Horizontal line (using dashes)
  void writeHorizontalLine({int width = 48, String char = '-'}) {
    writeText(char * width);
    lineFeed();
  }

  // ═══════════════════════════════════════════════════════════════
  // Image Printing (Required for Urdu text with perfect shaping)
  // ═══════════════════════════════════════════════════════════════

  /// Print image using raster/bitmap mode
  /// This is the ONLY way to print Urdu/Arabic with proper text shaping in ESC/POS
  /// 
  /// [imageBytes]: PNG or other image format bytes
  /// [maxWidth]: Maximum print width in pixels (384 for 80mm @ 96dpi)
  void printImage(Uint8List imageBytes, {int maxWidth = 384}) {
    try {
      // Decode PNG image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize if too wide
      if (image.width > maxWidth) {
        image = img.copyResize(
          image,
          width: maxWidth,
          height: (image.height * maxWidth ~/ image.width),
        );
      }

      // Convert to 1-bit (black & white) for thermal printer
      _addRasterImage(image, maxWidth);
    } catch (e) {
      throw Exception('Error printing image: $e');
    }
  }

  /// Internal: Convert image to ESC/POS raster format (GS v 0 mode)
  /// 
  /// ESC/POS Raster Format (GS v 0):
  /// GS v 0 <mode> <xL> <xH> <yL> <yH> <data>
  /// 
  /// Where:
  /// - mode: 0 = normal, 1 = double-width, 2 = double-height, 3 = double both
  /// - x: width in pixels
  /// - y: height in pixels
  /// - data: 1-bit bitmap data (8 pixels per byte, left to right)
  void _addRasterImage(img.Image image, int maxWidth) {
    final width = image.width;
    final height = image.height;

    // Convert to grayscale and then to 1-bit
    final bitmapData = _convertTo1BitBitmap(image);

    // ESC/POS raster command: GS v 0 <mode> <xL> <xH> <yL> <yH> <bitmap>
    // 80mm printer typically supports raster mode 0 (normal)

    // Width and height in bytes (width must be divisible by 8)
    final dataWidth = ((width + 7) ~/ 8);
    final dataHeight = height;

    // Width encoding (little-endian)
    final widthLow = dataWidth & 0xFF;
    final widthHigh = (dataWidth >> 8) & 0xFF;

    // Height encoding (little-endian)
    final heightLow = dataHeight & 0xFF;
    final heightHigh = (dataHeight >> 8) & 0xFF;

    // Build command
    _buffer.addAll([GS, 0x2A, widthLow, widthHigh]); // GS * <width>
    _buffer.addAll([GS, 0x2B, heightLow, heightHigh]); // GS + <height>

    // Add bitmap data
    _buffer.addAll(bitmapData);

    // Add line feed after image
    lineFeed();
  }

  /// Convert RGB image to 1-bit bitmap (black & white)
  /// Returns list of bytes where each bit represents a pixel
  static List<int> _convertTo1BitBitmap(img.Image image) {
    final width = image.width;
    final height = image.height;
    final bitmap = <int>[];

    for (int y = 0; y < height; y++) {
      int currentByte = 0;
      int bitCount = 0;

      for (int x = 0; x < width; x++) {
        // Get pixel and convert to grayscale
        final pixel = image.getPixelSafe(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        // Calculate luminance
        final luminance = (r * 299 + g * 587 + b * 114) ~/ 1000;

        // Convert to binary (threshold at 128)
        final bit = luminance < 128 ? 1 : 0;

        // Accumulate bits (MSB first)
        currentByte = (currentByte << 1) | bit;
        bitCount++;

        if (bitCount == 8) {
          bitmap.add(currentByte);
          currentByte = 0;
          bitCount = 0;
        }
      }

      // Pad last byte if needed
      if (bitCount > 0) {
        currentByte <<= (8 - bitCount);
        bitmap.add(currentByte);
      }
    }

    return bitmap;
  }

  // ═══════════════════════════════════════════════════════════════
  // Paper Control (Cut, Feed)
  // ═══════════════════════════════════════════════════════════════

  /// Feed paper (move down specified lines)
  void feedLines(int lines) {
    _buffer.addAll([ESC, 0x4A, lines]); // ESC J <lines>
  }

  /// Full cut (cut all the way through)
  void fullCut() {
    _buffer.addAll([GS, 0x56, 0x00]); // GS V 0 (full cut)
  }

  /// Partial cut (cut partially, leave small connection)
  void partialCut() {
    _buffer.addAll([GS, 0x56, 0x01]); // GS V 1 (partial cut)
  }

  // ═══════════════════════════════════════════════════════════════
  // Utility Methods
  // ═══════════════════════════════════════════════════════════════

  /// Get all accumulated ESC/POS commands as bytes
  List<int> getBytes() => List<int>.from(_buffer);

  /// Get as Uint8List for sending to printer
  Uint8List toBytes() => Uint8List.fromList(_buffer);

  /// Clear buffer
  void clear() => _buffer.clear();

  /// Get buffer size
  int get length => _buffer.length;

  /// Print complete receipt workflow
  /// 
  /// This is the recommended sequence for thermal printing:
  /// 1. Reset
  /// 2. Print receipt image
  /// 3. Feed lines
  /// 4. Cut paper
  void buildReceiptSequence(Uint8List receiptImageBytes) {
    reset();
    lineFeed();
    printImage(receiptImageBytes, maxWidth: 384);
    feedLines(3);
    fullCut();
  }
}

/// 📋 Helper extension for string repetition
extension StringRepeat on String {
  String operator *(int times) => List.filled(times, this).join();
}

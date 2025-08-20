// Image codec for loading and saving various image formats
import 'dart:io';
import 'dart:typed_data';

import 'bitmap.dart';
import '../errors.dart';
import 'codecs/bmp_codec.dart';
import 'codecs/p3_codec.dart';
import 'codecs/p6_codec.dart';
import 'codecs/png_codec.dart';

/// Base class for image codecs
abstract class ImageCodec {
  /// Decode image from bytes
  Bitmap decode(Uint8List bytes);

  /// Encode image to bytes
  Uint8List encode(Bitmap image);

  /// Check if this codec can handle the given file
  bool canDecode(Uint8List bytes);
}

/// Factory class for loading images
class ImageLoader {
  static final List<ImageCodec> _codecs = [
    PngImageCodec(), // PNG (most common)
    P6ImageCodec(), // P6 binary PPM (preferred)
    P3ImageCodec(), // P3 ASCII PPM
    BmpImageCodec(),
  ];

  /// Load image from file
  static Future<Bitmap> loadFromFile(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    return loadFromBytes(bytes);
  }

  /// Load image from bytes
  static Bitmap loadFromBytes(Uint8List bytes) {
    for (final codec in _codecs) {
      if (codec.canDecode(bytes)) {
        return codec.decode(bytes);
      }
    }
    throw UnsupportedFormatException(
      'unknown',
      'Could not detect image format from data',
    );
  }

  /// Save image to file
  /// For PPM files, use .ppm for P6 (binary) or .p3.ppm for P3 (ASCII)
  static Future<void> saveToFile(Bitmap image, String path) async {
    final extension = path.split('.').last.toLowerCase();
    final filename = path.toLowerCase();

    ImageCodec? codec;
    switch (extension) {
      case 'png':
        codec = PngImageCodec();
        break;
      case 'ppm':
        // Check if explicitly P3 format is requested
        codec = filename.contains('.p3.ppm') ? P3ImageCodec() : P6ImageCodec();
        break;
      case 'bmp':
        codec = BmpImageCodec();
        break;
      default:
        throw UnsupportedFormatException(extension);
    }

    final bytes = codec.encode(image);
    final file = File(path);
    await file.writeAsBytes(bytes);
  }
}

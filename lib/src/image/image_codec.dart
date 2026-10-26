import 'dart:typed_data';

import 'bitmap.dart';
import '../errors.dart';
import 'codecs/bmp_codec.dart';
import 'codecs/p3_codec.dart';
import 'codecs/p6_codec.dart';
import 'codecs/png_codec.dart';
import '../io/file_system.dart';
import '../limits.dart';
import '../result.dart';

/// Base class for image codecs
abstract class ImageCodec {
  /// Decode image from bytes; malformed or unsupported input, or an image
  /// over [limits], is an [Err]
  Result<Bitmap, ErrorDetails> decode(
    Uint8List bytes, {
    Limits limits = const Limits(),
  });

  /// Encode image to bytes
  Uint8List encode(Bitmap image);

  /// Check if this codec can handle the given file
  bool canDecode(Uint8List bytes);

  /// Runs a throwing parser at the decode boundary, converting the
  /// exceptions raised by bad input into an [Err]. Any other exception is a
  /// programming error and propagates.
  static Result<Bitmap, ErrorDetails> guard(Bitmap Function() parse) {
    try {
      return Ok(parse());
    } on RangeError catch (error) {
      return Err(
        ErrorDetails(ErrorKind.truncated, 'Image data ended early', error),
      );
    } on FormatException catch (error) {
      return Err(ErrorDetails(ErrorKind.malformed, error.message, error));
    } on UnsupportedFormatException catch (error) {
      return Err(ErrorDetails(ErrorKind.unsupported, error.message, error));
    } on ResourceLimitException catch (error) {
      return Err(ErrorDetails(ErrorKind.limit, error.message, error));
    }
  }
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
  static Future<Result<Bitmap, ErrorDetails>> loadFromFile(
    String path, {
    required GraphicsFileSystem filesystem,
    Limits limits = const Limits(),
  }) async {
    final Uint8List? bytes;
    try {
      bytes = await filesystem.read(path);
    } on Exception catch (error) {
      return Err(ErrorDetails(ErrorKind.io, 'Cannot read $path', error));
    }
    if (bytes == null) {
      return Err(ErrorDetails(ErrorKind.io, 'File not found at $path'));
    }
    return loadFromBytes(bytes, limits: limits);
  }

  /// Load image from bytes. With a [format] name ('png', 'bmp', 'ppm' or
  /// 'p3' for ASCII PPM, 'p6'), that codec is used; otherwise the format is
  /// detected from the data.
  static Result<Bitmap, ErrorDetails> loadFromBytes(
    Uint8List bytes, {
    String? format,
    Limits limits = const Limits(),
  }) {
    final codec = format == null
        ? _codecs.where((codec) => codec.canDecode(bytes)).firstOrNull
        : switch (format.toLowerCase()) {
            'png' => PngImageCodec(),
            'bmp' => BmpImageCodec(),
            'ppm' || 'p3' => P3ImageCodec(),
            'p6' => P6ImageCodec(),
            _ => null,
          };
    if (codec == null) {
      return Err(
        ErrorDetails(
          ErrorKind.unsupported,
          format == null
              ? 'Could not detect image format from data'
              : 'Unsupported image format: $format',
        ),
      );
    }
    return codec.decode(bytes, limits: limits);
  }

  /// Save image to file
  /// For PPM files, use .ppm for P6 (binary) or .p3.ppm for P3 (ASCII)
  static Future<void> saveToFile(
    Bitmap image,
    String path, {
    required GraphicsFileSystem filesystem,
  }) async {
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
    await filesystem.write(path, bytes);
  }
}

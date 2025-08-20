// BMP image codec (uncompressed 24-bit RGB)
import 'dart:typed_data';

import '../bitmap.dart';
import '../../color/color.dart';
import '../../errors.dart';
import '../image_codec.dart';

class BmpImageCodec extends ImageCodec {
  @override
  bool canDecode(Uint8List bytes) {
    if (bytes.length < 2) return false;
    return bytes[0] == 0x42 && bytes[1] == 0x4D; // "BM"
  }

  @override
  Bitmap decode(Uint8List bytes) {
    final data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);

    // BMP Header
    if (data.getUint16(0, Endian.little) != 0x4D42) {
      // "BM"
      throw FormatException('Not a BMP file');
    }

    final pixelOffset = data.getUint32(10, Endian.little);

    // DIB Header
    // Header size is not used but read for validation
    data.getUint32(14, Endian.little);
    final width = data.getInt32(18, Endian.little);
    final height = data
        .getInt32(22, Endian.little)
        .abs(); // Height can be negative
    final bitsPerPixel = data.getUint16(28, Endian.little);
    final compression = data.getUint32(30, Endian.little);

    if (compression != 0) {
      throw UnsupportedFormatException(
        'BMP',
        'Compressed BMP format not supported',
      );
    }

    final image = Bitmap.empty(width, height);

    // Calculate row padding (rows are aligned to 4-byte boundaries)
    final bytesPerPixel = bitsPerPixel ~/ 8;
    final rowSize = ((width * bytesPerPixel + 3) ~/ 4) * 4;

    // BMP stores pixels bottom-to-top
    for (int y = 0; y < height; y++) {
      final bmpY = height - 1 - y; // Flip Y
      final rowOffset = pixelOffset + bmpY * rowSize;

      for (int x = 0; x < width; x++) {
        final pixelOffset = rowOffset + x * bytesPerPixel;

        int r, g, b, a = 255;

        if (bitsPerPixel == 24) {
          // BGR format
          b = bytes[pixelOffset];
          g = bytes[pixelOffset + 1];
          r = bytes[pixelOffset + 2];
        } else if (bitsPerPixel == 32) {
          // BGRA format
          b = bytes[pixelOffset];
          g = bytes[pixelOffset + 1];
          r = bytes[pixelOffset + 2];
          a = bytes[pixelOffset + 3];
        } else {
          throw UnsupportedFormatException(
            'BMP',
            'Only 24-bit and 32-bit BMP formats are supported',
          );
        }

        image.setPixel(x, y, Color.fromRGBA(r, g, b, a));
      }
    }

    return image;
  }

  @override
  Uint8List encode(Bitmap image) {
    final width = image.width;
    final height = image.height;
    final bytesPerPixel = 3; // 24-bit RGB
    final rowSize = ((width * bytesPerPixel + 3) ~/ 4) * 4; // Align to 4 bytes
    final pixelDataSize = rowSize * height;
    final fileSize = 54 + pixelDataSize; // Header + pixel data

    final bytes = Uint8List(fileSize);
    final data = ByteData.view(bytes.buffer);

    // BMP Header (14 bytes)
    data.setUint16(0, 0x4D42, Endian.little); // "BM"
    data.setUint32(2, fileSize, Endian.little);
    data.setUint32(6, 0, Endian.little); // Reserved
    data.setUint32(10, 54, Endian.little); // Pixel data offset

    // DIB Header (40 bytes)
    data.setUint32(14, 40, Endian.little); // DIB header size
    data.setInt32(18, width, Endian.little);
    data.setInt32(22, height, Endian.little);
    data.setUint16(26, 1, Endian.little); // Planes
    data.setUint16(28, 24, Endian.little); // Bits per pixel
    data.setUint32(30, 0, Endian.little); // No compression
    data.setUint32(34, pixelDataSize, Endian.little);
    data.setInt32(38, 2835, Endian.little); // Horizontal resolution (72 DPI)
    data.setInt32(42, 2835, Endian.little); // Vertical resolution (72 DPI)
    data.setUint32(46, 0, Endian.little); // Colors in palette
    data.setUint32(50, 0, Endian.little); // Important colors

    // Pixel data (bottom-to-top, BGR format)
    var offset = 54;
    for (int y = height - 1; y >= 0; y--) {
      for (int x = 0; x < width; x++) {
        final color = image.getPixel(x, y);
        bytes[offset++] = color.blue;
        bytes[offset++] = color.green;
        bytes[offset++] = color.red;
      }
      // Add padding bytes to align to 4-byte boundary
      final padding = rowSize - (width * bytesPerPixel);
      offset += padding;
    }

    return bytes;
  }
}

import 'dart:typed_data';

import 'package:libgfx/src/color/color.dart';
import 'package:libgfx/src/image/bitmap.dart';
import 'package:libgfx/src/image/codecs/bmp_codec.dart';
import 'package:test/test.dart';

void main() {
  group('BMP Codec', () {
    late BmpImageCodec codec;

    setUp(() {
      codec = BmpImageCodec();
    });

    group('canDecode', () {
      test('returns true for valid BMP header', () {
        final bytes = Uint8List.fromList([0x42, 0x4D, 0x00, 0x00]); // "BM"
        expect(codec.canDecode(bytes), isTrue);
      });

      test('returns false for non-BMP data', () {
        final bytes = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
        ]); // PNG header
        expect(codec.canDecode(bytes), isFalse);
      });

      test('returns false for empty data', () {
        final bytes = Uint8List(0);
        expect(codec.canDecode(bytes), isFalse);
      });

      test('returns false for single byte', () {
        final bytes = Uint8List.fromList([0x42]);
        expect(codec.canDecode(bytes), isFalse);
      });
    });

    group('encode and decode', () {
      test('round-trip small image', () {
        // Create a small test image
        final original = Bitmap.empty(3, 2);
        original.setPixel(0, 0, Color.fromRGBA(255, 0, 0, 255)); // Red
        original.setPixel(1, 0, Color.fromRGBA(0, 255, 0, 255)); // Green
        original.setPixel(2, 0, Color.fromRGBA(0, 0, 255, 255)); // Blue
        original.setPixel(0, 1, Color.fromRGBA(255, 255, 0, 255)); // Yellow
        original.setPixel(1, 1, Color.fromRGBA(255, 0, 255, 255)); // Magenta
        original.setPixel(2, 1, Color.fromRGBA(0, 255, 255, 255)); // Cyan

        // Encode to BMP
        final encoded = codec.encode(original);

        // Verify BMP header
        expect(encoded[0], equals(0x42)); // 'B'
        expect(encoded[1], equals(0x4D)); // 'M'

        // Decode back
        final decoded = codec.decode(encoded);

        // Verify dimensions
        expect(decoded.width, equals(original.width));
        expect(decoded.height, equals(original.height));

        // Verify pixel values
        for (int y = 0; y < original.height; y++) {
          for (int x = 0; x < original.width; x++) {
            final originalColor = original.getPixel(x, y);
            final decodedColor = decoded.getPixel(x, y);
            expect(decodedColor.red, equals(originalColor.red));
            expect(decodedColor.green, equals(originalColor.green));
            expect(decodedColor.blue, equals(originalColor.blue));
            // BMP doesn't store alpha in 24-bit mode, so it's always 255
            expect(decodedColor.alpha, equals(255));
          }
        }
      });

      test('handles single pixel image', () {
        final original = Bitmap.empty(1, 1);
        original.setPixel(0, 0, Color.fromRGBA(128, 64, 192, 255));

        final encoded = codec.encode(original);
        final decoded = codec.decode(encoded);

        expect(decoded.width, equals(1));
        expect(decoded.height, equals(1));

        final color = decoded.getPixel(0, 0);
        expect(color.red, equals(128));
        expect(color.green, equals(64));
        expect(color.blue, equals(192));
      });

      test('handles row padding correctly', () {
        // Width of 5 pixels requires padding (5*3 = 15 bytes, needs 1 byte padding to reach 16)
        final original = Bitmap.empty(5, 2);

        // Set some test colors
        for (int x = 0; x < 5; x++) {
          original.setPixel(x, 0, Color.fromRGBA(x * 50, 0, 0, 255));
          original.setPixel(x, 1, Color.fromRGBA(0, x * 50, 0, 255));
        }

        final encoded = codec.encode(original);
        final decoded = codec.decode(encoded);

        expect(decoded.width, equals(5));
        expect(decoded.height, equals(2));

        // Verify the colors were preserved
        for (int x = 0; x < 5; x++) {
          var color = decoded.getPixel(x, 0);
          expect(color.red, equals(x * 50));
          expect(color.green, equals(0));

          color = decoded.getPixel(x, 1);
          expect(color.red, equals(0));
          expect(color.green, equals(x * 50));
        }
      });

      test('handles larger image', () {
        final original = Bitmap.empty(100, 50);

        // Create a gradient pattern
        for (int y = 0; y < 50; y++) {
          for (int x = 0; x < 100; x++) {
            final r = (x * 255 ~/ 100);
            final g = (y * 255 ~/ 50);
            final b = ((x + y) * 255 ~/ 150);
            original.setPixel(x, y, Color.fromRGBA(r, g, b, 255));
          }
        }

        final encoded = codec.encode(original);
        final decoded = codec.decode(encoded);

        expect(decoded.width, equals(100));
        expect(decoded.height, equals(50));

        // Spot check a few pixels
        var color = decoded.getPixel(0, 0);
        expect(color.red, equals(0));
        expect(color.green, equals(0));

        color = decoded.getPixel(99, 49);
        expect(color.red, equals(252)); // 99 * 255 / 100
        expect(color.green, equals(249)); // 49 * 255 / 50
      });

      test('creates valid BMP file structure', () {
        final image = Bitmap.empty(10, 10);
        final encoded = codec.encode(image);

        final data = ByteData.view(encoded.buffer);

        // Check file header
        expect(data.getUint16(0, Endian.little), equals(0x4D42)); // "BM"

        // Check DIB header
        expect(
          data.getUint32(14, Endian.little),
          equals(40),
        ); // DIB header size
        expect(data.getInt32(18, Endian.little), equals(10)); // Width
        expect(data.getInt32(22, Endian.little), equals(10)); // Height
        expect(data.getUint16(26, Endian.little), equals(1)); // Planes
        expect(data.getUint16(28, Endian.little), equals(24)); // Bits per pixel
        expect(data.getUint32(30, Endian.little), equals(0)); // No compression
      });
    });

    group('error handling', () {
      test('throws on invalid BMP header', () {
        final bytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
        expect(() => codec.decode(bytes), throwsFormatException);
      });

      test('throws on compressed BMP format', () {
        // Create a minimal BMP header with compression set
        final bytes = Uint8List(54);
        final data = ByteData.view(bytes.buffer);

        // Set up valid BMP header
        data.setUint16(0, 0x4D42, Endian.little); // "BM"
        data.setUint32(10, 54, Endian.little); // Pixel offset
        data.setUint32(14, 40, Endian.little); // DIB header size
        data.setInt32(18, 10, Endian.little); // Width
        data.setInt32(22, 10, Endian.little); // Height
        data.setUint16(28, 24, Endian.little); // Bits per pixel
        data.setUint32(30, 1, Endian.little); // RLE compression (unsupported)

        expect(
          () => codec.decode(bytes),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Compressed BMP format not supported'),
            ),
          ),
        );
      });

      test('throws on unsupported bit depth', () {
        // Create a minimal BMP header with 8-bit depth
        final bytes = Uint8List(54);
        final data = ByteData.view(bytes.buffer);

        // Set up valid BMP header
        data.setUint16(0, 0x4D42, Endian.little); // "BM"
        data.setUint32(10, 54, Endian.little); // Pixel offset
        data.setUint32(14, 40, Endian.little); // DIB header size
        data.setInt32(18, 10, Endian.little); // Width
        data.setInt32(22, 10, Endian.little); // Height
        data.setUint16(28, 8, Endian.little); // 8 bits per pixel (unsupported)
        data.setUint32(30, 0, Endian.little); // No compression

        expect(
          () => codec.decode(bytes),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Only 24-bit and 32-bit BMP formats are supported'),
            ),
          ),
        );
      });
    });

    group('32-bit BMP support', () {
      test('decodes 32-bit BMP with alpha', () {
        // Create a minimal 32-bit BMP
        final width = 2;
        final height = 2;
        final bytesPerPixel = 4;
        final rowSize =
            width * bytesPerPixel; // No padding needed for 2x4=8 bytes
        final pixelDataSize = rowSize * height;
        final fileSize = 54 + pixelDataSize;

        final bytes = Uint8List(fileSize);
        final data = ByteData.view(bytes.buffer);

        // BMP Header
        data.setUint16(0, 0x4D42, Endian.little); // "BM"
        data.setUint32(2, fileSize, Endian.little);
        data.setUint32(10, 54, Endian.little); // Pixel data offset

        // DIB Header
        data.setUint32(14, 40, Endian.little); // DIB header size
        data.setInt32(18, width, Endian.little);
        data.setInt32(22, height, Endian.little);
        data.setUint16(26, 1, Endian.little); // Planes
        data.setUint16(28, 32, Endian.little); // 32 bits per pixel
        data.setUint32(30, 0, Endian.little); // No compression

        // Add pixel data (BGRA format, bottom-to-top)
        // Bottom row
        bytes[54] = 255;
        bytes[55] = 0;
        bytes[56] = 0;
        bytes[57] = 128; // Blue, semi-transparent
        bytes[58] = 0;
        bytes[59] = 255;
        bytes[60] = 0;
        bytes[61] = 255; // Green, opaque
        // Top row
        bytes[62] = 0;
        bytes[63] = 0;
        bytes[64] = 255;
        bytes[65] = 64; // Red, mostly transparent
        bytes[66] = 255;
        bytes[67] = 255;
        bytes[68] = 0;
        bytes[69] = 192; // Yellow, mostly opaque

        final decoded = codec.decode(bytes);

        expect(decoded.width, equals(2));
        expect(decoded.height, equals(2));

        // Check colors (remember Y is flipped in BMP)
        var color = decoded.getPixel(0, 0);
        expect(color.red, equals(255));
        expect(color.alpha, equals(64));

        color = decoded.getPixel(1, 0);
        expect(color.red, equals(0));
        expect(color.green, equals(255));
        expect(color.alpha, equals(192));

        color = decoded.getPixel(0, 1);
        expect(color.blue, equals(255));
        expect(color.alpha, equals(128));

        color = decoded.getPixel(1, 1);
        expect(color.green, equals(255));
        expect(color.alpha, equals(255));
      });
    });
  });
}

import 'dart:typed_data';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/image/codecs/p3_codec.dart';
import 'package:libgfx/src/image/codecs/p6_codec.dart';
import 'package:test/test.dart';

void main() {
  group('P3ImageCodec', () {
    test('can encode and decode P3 format', () {
      // Create a small test image
      final bitmap = Bitmap(3, 2);
      bitmap.setPixel(0, 0, Color.fromRGBA(255, 0, 0, 255)); // Red
      bitmap.setPixel(1, 0, Color.fromRGBA(0, 255, 0, 255)); // Green
      bitmap.setPixel(2, 0, Color.fromRGBA(0, 0, 255, 255)); // Blue
      bitmap.setPixel(0, 1, Color.fromRGBA(255, 255, 0, 255)); // Yellow
      bitmap.setPixel(1, 1, Color.fromRGBA(255, 0, 255, 255)); // Magenta
      bitmap.setPixel(2, 1, Color.fromRGBA(0, 255, 255, 255)); // Cyan

      // Encode to P3
      final codec = P3ImageCodec();
      final encoded = codec.encode(bitmap);

      // Check it's ASCII
      final content = String.fromCharCodes(encoded);
      expect(content, startsWith('P3'));
      expect(content, contains('3 2')); // dimensions
      expect(content, contains('255')); // max value
      expect(content, contains('255 0 0')); // red pixel
      expect(content, contains('0 255 0')); // green pixel
      expect(content, contains('0 0 255')); // blue pixel

      // Decode back
      final decoded = codec.decode(encoded);
      expect(decoded.width, 3);
      expect(decoded.height, 2);

      // Check pixels
      expect(decoded.getPixel(0, 0).red, 255);
      expect(decoded.getPixel(0, 0).green, 0);
      expect(decoded.getPixel(0, 0).blue, 0);

      expect(decoded.getPixel(1, 0).red, 0);
      expect(decoded.getPixel(1, 0).green, 255);
      expect(decoded.getPixel(1, 0).blue, 0);

      expect(decoded.getPixel(2, 1).red, 0);
      expect(decoded.getPixel(2, 1).green, 255);
      expect(decoded.getPixel(2, 1).blue, 255);
    });

    test('canDecode correctly identifies P3 format', () {
      final codec = P3ImageCodec();

      // P3 header
      final p3Bytes = Uint8List.fromList('P3\n2 2\n255\n'.codeUnits);
      expect(codec.canDecode(p3Bytes), isTrue);

      // P6 header
      final p6Bytes = Uint8List.fromList([0x50, 0x36]); // "P6"
      expect(codec.canDecode(p6Bytes), isFalse);

      // Invalid
      final invalidBytes = Uint8List.fromList('Hello'.codeUnits);
      expect(codec.canDecode(invalidBytes), isFalse);
    });

    test('P3ImageCodec encode/decode as string', () {
      final bitmap = Bitmap(2, 2);
      bitmap.setPixel(0, 0, Color.fromRGBA(100, 150, 200, 255));
      bitmap.setPixel(1, 0, Color.fromRGBA(50, 100, 150, 255));
      bitmap.setPixel(0, 1, Color.fromRGBA(200, 100, 50, 255));
      bitmap.setPixel(1, 1, Color.fromRGBA(150, 50, 100, 255));

      // Use P3ImageCodec directly
      final codec = P3ImageCodec();
      final encodedBytes = codec.encode(bitmap);
      final encoded = String.fromCharCodes(encodedBytes);
      expect(encoded, startsWith('P3'));
      expect(encoded, contains('2 2'));

      final decoded = codec.decode(Uint8List.fromList(encoded.codeUnits));
      expect(decoded.width, 2);
      expect(decoded.height, 2);
      expect(decoded.getPixel(0, 0).red, 100);
      expect(decoded.getPixel(0, 0).green, 150);
      expect(decoded.getPixel(0, 0).blue, 200);
    });

    test('P3 and P6 codecs produce different formats', () {
      final bitmap = Bitmap(10, 10);
      // Fill with a gradient
      for (int y = 0; y < 10; y++) {
        for (int x = 0; x < 10; x++) {
          final r = (x * 255 / 9).round();
          final g = (y * 255 / 9).round();
          final b = 128;
          bitmap.setPixel(x, y, Color.fromRGBA(r, g, b, 255));
        }
      }

      final p3Codec = P3ImageCodec();
      final p6Codec = P6ImageCodec();

      final p3Bytes = p3Codec.encode(bitmap);
      final p6Bytes = p6Codec.encode(bitmap);

      // P3 should be much larger (ASCII)
      expect(p3Bytes.length, greaterThan(p6Bytes.length * 2));

      // P3 should be readable as text
      final p3Text = String.fromCharCodes(p3Bytes);
      expect(p3Text, startsWith('P3'));
      expect(p3Text, contains('10 10'));

      // P6 should start with P6 magic number
      expect(p6Bytes[0], 0x50); // 'P'
      expect(p6Bytes[1], 0x36); // '6'

      // Both should decode to the same image
      final p3Decoded = p3Codec.decode(p3Bytes);
      final p6Decoded = p6Codec.decode(p6Bytes);

      for (int y = 0; y < 10; y++) {
        for (int x = 0; x < 10; x++) {
          final p3Color = p3Decoded.getPixel(x, y);
          final p6Color = p6Decoded.getPixel(x, y);
          expect(p3Color.red, p6Color.red);
          expect(p3Color.green, p6Color.green);
          expect(p3Color.blue, p6Color.blue);
        }
      }
    });
  });
}

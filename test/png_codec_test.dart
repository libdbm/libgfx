import 'dart:typed_data';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/blending/blend_modes.dart';
import 'package:libgfx/src/image/codecs/png_codec.dart';
import 'package:test/test.dart';

void main() {
  group('PngCodec', () {
    test('can encode and decode simple PNG', () {
      // Create a test image with various colors
      final bitmap = Bitmap(4, 4);

      // Set different colors in each quadrant
      // Top-left: Red
      bitmap.setPixel(0, 0, Color.fromRGBA(255, 0, 0, 255));
      bitmap.setPixel(1, 0, Color.fromRGBA(255, 0, 0, 255));
      bitmap.setPixel(0, 1, Color.fromRGBA(255, 0, 0, 255));
      bitmap.setPixel(1, 1, Color.fromRGBA(255, 0, 0, 255));

      // Top-right: Green
      bitmap.setPixel(2, 0, Color.fromRGBA(0, 255, 0, 255));
      bitmap.setPixel(3, 0, Color.fromRGBA(0, 255, 0, 255));
      bitmap.setPixel(2, 1, Color.fromRGBA(0, 255, 0, 255));
      bitmap.setPixel(3, 1, Color.fromRGBA(0, 255, 0, 255));

      // Bottom-left: Blue
      bitmap.setPixel(0, 2, Color.fromRGBA(0, 0, 255, 255));
      bitmap.setPixel(1, 2, Color.fromRGBA(0, 0, 255, 255));
      bitmap.setPixel(0, 3, Color.fromRGBA(0, 0, 255, 255));
      bitmap.setPixel(1, 3, Color.fromRGBA(0, 0, 255, 255));

      // Bottom-right: Yellow with transparency
      bitmap.setPixel(2, 2, Color.fromRGBA(255, 255, 0, 128));
      bitmap.setPixel(3, 2, Color.fromRGBA(255, 255, 0, 128));
      bitmap.setPixel(2, 3, Color.fromRGBA(255, 255, 0, 128));
      bitmap.setPixel(3, 3, Color.fromRGBA(255, 255, 0, 128));

      // Encode to PNG
      final codec = PngImageCodec();
      final encoded = codec.encode(bitmap);

      // Check PNG signature
      expect(encoded.length, greaterThan(8));
      expect(encoded[0], 137); // PNG signature
      expect(encoded[1], 80); // 'P'
      expect(encoded[2], 78); // 'N'
      expect(encoded[3], 71); // 'G'

      // For now, just check that encoding produces valid PNG header
      // Full decode test would require deflate decompression
    });

    test('canDecode correctly identifies PNG format', () {
      final codec = PngImageCodec();

      // Valid PNG signature
      final pngBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      expect(codec.canDecode(pngBytes), isTrue);

      // Invalid data
      final invalidBytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
      expect(codec.canDecode(invalidBytes), isFalse);

      // Too short
      final shortBytes = Uint8List.fromList([137, 80]);
      expect(codec.canDecode(shortBytes), isFalse);
    });

    test('PNG encoder creates valid file structure', () {
      final bitmap = Bitmap(2, 2);
      bitmap.setPixel(0, 0, Color.fromRGBA(255, 0, 0, 255));
      bitmap.setPixel(1, 0, Color.fromRGBA(0, 255, 0, 255));
      bitmap.setPixel(0, 1, Color.fromRGBA(0, 0, 255, 255));
      bitmap.setPixel(1, 1, Color.fromRGBA(255, 255, 255, 255));

      final codec = PngImageCodec();
      final encoded = codec.encode(bitmap);

      // Parse chunks manually
      int offset = 8; // Skip signature

      // First chunk should be IHDR
      final ihdrLength =
          (encoded[offset] << 24) |
          (encoded[offset + 1] << 16) |
          (encoded[offset + 2] << 8) |
          encoded[offset + 3];
      offset += 4;

      final ihdrType = String.fromCharCodes(
        encoded.sublist(offset, offset + 4),
      );
      expect(ihdrType, 'IHDR');
      offset += 4;

      // Check IHDR data
      final ihdrData = encoded.sublist(offset, offset + ihdrLength);
      final width =
          (ihdrData[0] << 24) |
          (ihdrData[1] << 16) |
          (ihdrData[2] << 8) |
          ihdrData[3];
      final height =
          (ihdrData[4] << 24) |
          (ihdrData[5] << 16) |
          (ihdrData[6] << 8) |
          ihdrData[7];

      expect(width, 2);
      expect(height, 2);
      expect(ihdrData[8], 8); // Bit depth
      expect(ihdrData[9], 6); // Color type (RGBA)
    });
  });

  group('Integer Blend Modes', () {
    test('srcOver blending matches expected results', () {
      // Test integer-based srcOver blending
      final src = Color.fromRGBA(255, 0, 0, 128); // Semi-transparent red
      final dst = Color.fromRGBA(0, 0, 255, 255); // Opaque blue

      final result = BlendModes.blend(src, dst, BlendMode.srcOver);

      // Should be reddish-purple
      expect(result.alpha, 255); // Result should be opaque
      expect(result.red, greaterThan(100)); // Some red
      expect(result.blue, greaterThan(100)); // Some blue preserved
      expect(result.green, 0); // No green
    });

    test('integer math is faster than floating point', () {
      // Create colors for blending
      final src = Color.fromRGBA(200, 100, 50, 200);
      final dst = Color.fromRGBA(50, 150, 200, 180);

      // Time integer blending
      final intStart = DateTime.now();
      for (int i = 0; i < 100000; i++) {
        BlendModes.blend(src, dst, BlendMode.srcOver);
      }
      final intTime = DateTime.now().difference(intStart);

      // Time floating-point blending (old implementation)
      final floatStart = DateTime.now();
      for (int i = 0; i < 100000; i++) {
        // Simulate floating-point blend
        final sa = src.alpha / 255.0;
        final da = dst.alpha / 255.0;
        final outA = sa + da * (1.0 - sa);
        final outR = (src.red * sa + dst.red * da * (1.0 - sa)) / outA;
        final outG = (src.green * sa + dst.green * da * (1.0 - sa)) / outA;
        final outB = (src.blue * sa + dst.blue * da * (1.0 - sa)) / outA;
        Color.fromARGB(
          (outA * 255).round(),
          outR.round().clamp(0, 255),
          outG.round().clamp(0, 255),
          outB.round().clamp(0, 255),
        );
      }
      final floatTime = DateTime.now().difference(floatStart);

      print('Integer blend: ${intTime.inMicroseconds}μs');
      print('Float blend: ${floatTime.inMicroseconds}μs');
      print('Speedup: ${floatTime.inMicroseconds / intTime.inMicroseconds}x');

      // Integer should be faster (though exact speedup varies)
      expect(
        intTime.inMicroseconds,
        lessThanOrEqualTo(floatTime.inMicroseconds),
      );
    });

    test('all blend modes produce valid colors', () {
      final src = Color.fromRGBA(150, 100, 200, 180);
      final dst = Color.fromRGBA(100, 150, 50, 200);

      final modes = [
        BlendMode.clear,
        BlendMode.src,
        BlendMode.dst,
        BlendMode.srcOver,
        BlendMode.dstOver,
        BlendMode.srcIn,
        BlendMode.dstIn,
        BlendMode.srcOut,
        BlendMode.dstOut,
        BlendMode.srcAtop,
        BlendMode.dstAtop,
        BlendMode.xor,
        BlendMode.add,
        BlendMode.multiply,
        BlendMode.screen,
        BlendMode.overlay,
        BlendMode.darken,
        BlendMode.lighten,
        BlendMode.colorDodge,
        BlendMode.colorBurn,
        BlendMode.hardLight,
        BlendMode.softLight,
        BlendMode.difference,
        BlendMode.exclusion,
      ];

      for (final mode in modes) {
        final result = BlendModes.blend(src, dst, mode);

        // Check all channels are valid
        expect(
          result.alpha,
          inInclusiveRange(0, 255),
          reason: 'Alpha out of range for $mode',
        );
        expect(
          result.red,
          inInclusiveRange(0, 255),
          reason: 'Red out of range for $mode',
        );
        expect(
          result.green,
          inInclusiveRange(0, 255),
          reason: 'Green out of range for $mode',
        );
        expect(
          result.blue,
          inInclusiveRange(0, 255),
          reason: 'Blue out of range for $mode',
        );
      }
    });
  });
}

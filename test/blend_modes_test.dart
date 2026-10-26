import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/blending/blend_modes.dart';
import 'package:test/test.dart';

void main() {
  group('BlendModes', () {
    group('Porter-Duff Compositing Modes', () {
      test('clear mode returns transparent', () {
        final src = Color.fromARGB(255, 255, 0, 0); // Red
        final dst = Color.fromARGB(255, 0, 255, 0); // Green

        final result = BlendModes.blend(src, dst, BlendMode.clear);

        expect(result.value, equals(0x00000000));
        expect(result.alpha, equals(0));
      });

      test('src mode returns source color', () {
        final src = Color.fromARGB(255, 255, 0, 0);
        final dst = Color.fromARGB(255, 0, 255, 0);

        final result = BlendModes.blend(src, dst, BlendMode.src);

        expect(result, equals(src));
      });

      test('dst mode returns destination color', () {
        final src = Color.fromARGB(255, 255, 0, 0);
        final dst = Color.fromARGB(255, 0, 255, 0);

        final result = BlendModes.blend(src, dst, BlendMode.dst);

        expect(result, equals(dst));
      });

      test('srcOver blends source over destination', () {
        final src = Color.fromARGB(128, 255, 0, 0); // 50% red
        final dst = Color.fromARGB(255, 0, 255, 0); // Green

        final result = BlendModes.blend(src, dst, BlendMode.srcOver);

        // Should blend red over green
        expect(result.alpha, equals(255));
        expect(result.red, greaterThan(120)); // Mixed towards red
        expect(result.green, greaterThan(120)); // Some green remains
        expect(result.blue, equals(0));
      });

      test('dstOver blends destination over source', () {
        final src = Color.fromARGB(128, 255, 0, 0); // 50% red
        final dst = Color.fromARGB(255, 0, 255, 0); // Green

        final result = BlendModes.blend(src, dst, BlendMode.dstOver);

        // Green should be on top
        expect(result.alpha, equals(255));
        expect(result.green, equals(255));
        expect(result.red, equals(0));
      });

      test('srcIn shows source inside destination alpha', () {
        final src = Color.fromARGB(255, 255, 0, 0); // Red
        final dst = Color.fromARGB(128, 0, 255, 0); // 50% green

        final result = BlendModes.blend(src, dst, BlendMode.srcIn);

        // Source color with destination alpha
        expect(result.alpha, equals(128));
        expect(result.red, equals(255));
        expect(result.green, equals(0));
        expect(result.blue, equals(0));
      });

      test('dstIn shows destination inside source alpha', () {
        final src = Color.fromARGB(128, 255, 0, 0); // 50% red
        final dst = Color.fromARGB(255, 0, 255, 0); // Green

        final result = BlendModes.blend(src, dst, BlendMode.dstIn);

        // Destination color with source alpha
        expect(result.alpha, equals(128));
        expect(result.red, equals(0));
        expect(result.green, equals(255));
        expect(result.blue, equals(0));
      });

      test('srcOut shows source outside destination', () {
        final src = Color.fromARGB(255, 255, 0, 0); // Red
        final dst = Color.fromARGB(128, 0, 255, 0); // 50% green

        final result = BlendModes.blend(src, dst, BlendMode.srcOut);

        // Source with inverted destination alpha
        expect(result.alpha, equals(127)); // 255 * (1 - 0.5)
        expect(result.red, equals(255));
        expect(result.green, equals(0));
      });

      test('dstOut shows destination outside source', () {
        final src = Color.fromARGB(128, 255, 0, 0); // 50% red
        final dst = Color.fromARGB(255, 0, 255, 0); // Green

        final result = BlendModes.blend(src, dst, BlendMode.dstOut);

        // Destination with inverted source alpha
        expect(result.alpha, equals(127)); // 255 * (1 - 0.5)
        expect(result.green, equals(255));
        expect(result.red, equals(0));
      });

      test('srcAtop composites source on top using destination alpha', () {
        final src = Color.fromARGB(255, 255, 0, 0); // Red
        final dst = Color.fromARGB(200, 0, 255, 0); // Green with alpha

        final result = BlendModes.blend(src, dst, BlendMode.srcAtop);

        expect(result.alpha, equals(200)); // Destination alpha preserved
        expect(result.red, equals(255));
        expect(result.green, equals(0));
      });

      test('dstAtop composites destination on top using source alpha', () {
        final src = Color.fromARGB(200, 255, 0, 0); // Red with alpha
        final dst = Color.fromARGB(255, 0, 255, 0); // Green

        final result = BlendModes.blend(src, dst, BlendMode.dstAtop);

        expect(result.alpha, equals(200)); // Source alpha preserved
        expect(result.green, equals(255));
        expect(result.red, equals(0));
      });

      test('xor shows non-overlapping parts', () {
        final src = Color.fromARGB(200, 255, 0, 0); // Red with alpha
        final dst = Color.fromARGB(200, 0, 255, 0); // Green with alpha

        final result = BlendModes.blend(src, dst, BlendMode.xor);

        // Should have combined alpha from non-overlapping parts
        expect(result.alpha, greaterThan(0));
        expect(result.alpha, lessThan(255));
      });
    });

    group('Separable Blend Modes', () {
      test('multiply darkens colors', () {
        final src = Color.fromARGB(255, 200, 200, 200); // Light gray
        final dst = Color.fromARGB(255, 100, 100, 100); // Dark gray

        final result = BlendModes.blend(src, dst, BlendMode.multiply);

        // Multiply should darken
        expect(result.red, lessThan(100));
        expect(result.green, lessThan(100));
        expect(result.blue, lessThan(100));
      });

      test('screen lightens colors', () {
        final src = Color.fromARGB(255, 100, 100, 100); // Gray
        final dst = Color.fromARGB(255, 100, 100, 100); // Gray

        final result = BlendModes.blend(src, dst, BlendMode.screen);

        // Screen should lighten
        expect(result.red, greaterThan(100));
        expect(result.green, greaterThan(100));
        expect(result.blue, greaterThan(100));
      });

      test('overlay combines multiply and screen', () {
        final src = Color.fromARGB(255, 200, 200, 200); // Light
        final dst = Color.fromARGB(255, 100, 100, 100); // Dark

        final result = BlendModes.blend(src, dst, BlendMode.overlay);

        // Should be between source and destination
        expect(result.alpha, equals(255));
        expect(result.red, greaterThan(0));
        expect(result.red, lessThan(255));
      });

      test('darken selects darker color', () {
        final src = Color.fromARGB(255, 200, 100, 150);
        final dst = Color.fromARGB(255, 100, 200, 150);

        final result = BlendModes.blend(src, dst, BlendMode.darken);

        // Should pick minimum of each channel
        expect(result.red, equals(100));
        expect(result.green, equals(100));
        expect(result.blue, closeTo(150, 1));
      });

      test('lighten selects lighter color', () {
        final src = Color.fromARGB(255, 200, 100, 150);
        final dst = Color.fromARGB(255, 100, 200, 150);

        final result = BlendModes.blend(src, dst, BlendMode.lighten);

        // Should pick maximum of each channel
        expect(result.red, closeTo(200, 1));
        expect(result.green, closeTo(200, 1));
        expect(result.blue, closeTo(150, 1));
      });

      test('colorDodge lightens based on source', () {
        final src = Color.fromARGB(255, 128, 128, 128); // Mid gray
        final dst = Color.fromARGB(255, 64, 64, 64); // Dark gray

        final result = BlendModes.blend(src, dst, BlendMode.colorDodge);

        // Should lighten destination
        expect(result.red, greaterThan(64));
        expect(result.green, greaterThan(64));
        expect(result.blue, greaterThan(64));
      });

      test('colorBurn darkens based on source', () {
        final src = Color.fromARGB(255, 128, 128, 128); // Mid gray
        final dst = Color.fromARGB(255, 192, 192, 192); // Light gray

        final result = BlendModes.blend(src, dst, BlendMode.colorBurn);

        // Should darken destination
        expect(result.red, lessThan(192));
        expect(result.green, lessThan(192));
        expect(result.blue, lessThan(192));
      });

      test('hardLight is like overlay with src/dst swapped', () {
        final src = Color.fromARGB(255, 200, 200, 200);
        final dst = Color.fromARGB(255, 100, 100, 100);

        final hardLightResult = BlendModes.blend(src, dst, BlendMode.hardLight);
        final overlaySwapped = BlendModes.blend(dst, src, BlendMode.overlay);

        // Results should be similar (not exact due to rounding)
        expect(hardLightResult.red, closeTo(overlaySwapped.red, 2));
        expect(hardLightResult.green, closeTo(overlaySwapped.green, 2));
        expect(hardLightResult.blue, closeTo(overlaySwapped.blue, 2));
      });

      test('softLight creates soft contrast', () {
        final src = Color.fromARGB(255, 192, 192, 192); // Light
        final dst = Color.fromARGB(255, 64, 64, 64); // Dark

        final result = BlendModes.blend(src, dst, BlendMode.softLight);

        // W3C compositing-1 soft-light: 192 over 64 gives 96
        expect(result.alpha, equals(255));
        expect(result.red, closeTo(96, 1));
      });

      test('softLight matches the W3C formula in both branches', () {
        // (source, backdrop, expected) computed from the W3C definition
        const cases = [
          (255, 128, 181),
          (255, 32, 88),
          (200, 200, 215),
          (64, 128, 96),
          (0, 128, 64),
          (128, 128, 128),
          (255, 0, 0),
          (255, 255, 255),
          (0, 0, 0),
        ];
        for (final (source, backdrop, expected) in cases) {
          expect(
            BlendModes.softLightFunc(source, backdrop),
            closeTo(expected, 1),
            reason: 'softLight($source, $backdrop)',
          );
        }
      });

      test('difference shows absolute difference', () {
        final src = Color.fromARGB(255, 200, 100, 50);
        final dst = Color.fromARGB(255, 100, 200, 150);

        final result = BlendModes.blend(src, dst, BlendMode.difference);

        // Should be absolute difference
        expect(result.red, equals(100)); // |200-100|
        expect(result.green, equals(100)); // |100-200|
        expect(result.blue, equals(100)); // |50-150|
      });

      test('exclusion creates lower contrast difference', () {
        final src = Color.fromARGB(255, 255, 0, 0); // Red
        final dst = Color.fromARGB(255, 0, 255, 0); // Green

        final result = BlendModes.blend(src, dst, BlendMode.exclusion);

        // Should create exclusion effect
        expect(result.red, greaterThan(0));
        expect(result.green, greaterThan(0));
        expect(result.blue, equals(0));
      });

      test('add mode adds colors (with clamping)', () {
        final src = Color.fromARGB(255, 200, 200, 200);
        final dst = Color.fromARGB(255, 100, 100, 100);

        final result = BlendModes.blend(src, dst, BlendMode.add);

        // Should add colors (clamped to 255)
        expect(result.red, equals(255)); // 200+100 = 300, clamped to 255
        expect(result.green, equals(255));
        expect(result.blue, equals(255));
      });
    });

    group('Edge Cases', () {
      test('blending with transparent source returns destination', () {
        final src = Color.fromARGB(0, 255, 0, 0); // Transparent
        final dst = Color.fromARGB(255, 0, 255, 0); // Green

        // Most modes should return destination when source is transparent
        expect(BlendModes.blend(src, dst, BlendMode.srcOver), equals(dst));
        expect(BlendModes.blend(src, dst, BlendMode.multiply), equals(dst));
        expect(BlendModes.blend(src, dst, BlendMode.screen), equals(dst));
      });

      test(
        'blending with transparent destination returns source for srcOver',
        () {
          final src = Color.fromARGB(255, 255, 0, 0); // Red
          final dst = Color.fromARGB(0, 0, 255, 0); // Transparent

          final result = BlendModes.blend(src, dst, BlendMode.srcOver);
          expect(result, equals(src));
        },
      );

      test('an opaque source over any destination is the source', () {
        // Source alpha 255 leaves nothing of the destination: out = src
        final src = Color.fromARGB(255, 200, 100, 7);
        for (final alpha in [0, 1, 128, 254, 255]) {
          for (final channel in [0, 99, 255]) {
            final dst = Color.fromARGB(alpha, channel, 255 - channel, 50);
            expect(
              BlendModes.blend(src, dst, BlendMode.srcOver).value,
              equals(src.value),
              reason: 'alpha $alpha, channel $channel',
            );
          }
        }
      });

      test('blending two semi-transparent colors', () {
        final src = Color.fromARGB(128, 255, 0, 0); // 50% red
        final dst = Color.fromARGB(128, 0, 255, 0); // 50% green

        final result = BlendModes.blend(src, dst, BlendMode.srcOver);

        // Should combine alphas properly
        expect(result.alpha, greaterThan(128));
        expect(result.alpha, lessThanOrEqualTo(255));
      });

      test('all modes handle fully opaque colors', () {
        final src = Color.fromARGB(255, 255, 0, 0);
        final dst = Color.fromARGB(255, 0, 255, 0);

        // Test that all modes produce valid results
        for (final mode in BlendMode.values) {
          final result = BlendModes.blend(src, dst, mode);

          expect(result.alpha, greaterThanOrEqualTo(0));
          expect(result.alpha, lessThanOrEqualTo(255));
          expect(result.red, greaterThanOrEqualTo(0));
          expect(result.red, lessThanOrEqualTo(255));
          expect(result.green, greaterThanOrEqualTo(0));
          expect(result.green, lessThanOrEqualTo(255));
          expect(result.blue, greaterThanOrEqualTo(0));
          expect(result.blue, lessThanOrEqualTo(255));
        }
      });
    });

    group('Partial coverage', () {
      const red = Color(0xFFFF0000);
      const blue = Color(0xFF0000FF);

      Color cover(final BlendMode mode, final Color source) {
        final bitmap = Bitmap(1, 1)..clear(red);
        bitmap.shade(0, 1, 0, 64, source, Matrix2D.identity(), mode);
        return bitmap.pixel(0, 0);
      }

      test('clear at coverage 64 removes only a quarter of the pixel', () {
        final result = cover(BlendMode.clear, blue);

        expect(result.alpha, closeTo(191, 1));
        expect(result.red, closeTo(255, 1));
      });

      test('src at coverage 64 replaces only a quarter of the pixel', () {
        final result = cover(BlendMode.src, blue);

        expect(result.alpha, equals(255));
        expect(result.red, closeTo(191, 1));
        expect(result.blue, closeTo(64, 1));
      });

      test('srcOver at coverage 64 matches source alpha scaling', () {
        final result = cover(BlendMode.srcOver, blue);

        expect(result.alpha, equals(255));
        expect(result.red, closeTo(191, 1));
        expect(result.blue, closeTo(64, 1));
      });
    });

    group('Pixel storage', () {
      Color draw(final Color background) {
        final engine = GraphicsEngine(1, 1)
          ..clear(background)
          ..fillStyle = const Color(0x80FF0000)
          ..fillRect(0, 0, 1, 1);
        return engine.pixel(0, 0);
      }

      test('pixels are stored as straight, not premultiplied, ARGB', () {
        // Half-transparent red over nothing keeps full-intensity red; a
        // premultiplied store would hold red 128
        final pixel = draw(const Color(0x00000000));
        expect(pixel.alpha, closeTo(128, 1));
        expect(pixel.red, closeTo(255, 1));
        expect([pixel.green, pixel.blue], equals([0, 0]));
      });

      test('compositing weights colours by alpha', () {
        // Half-transparent red over opaque green mixes them evenly
        final pixel = draw(const Color(0xFF00FF00));
        expect(pixel.alpha, equals(255));
        expect(pixel.red, closeTo(128, 1));
        expect(pixel.green, closeTo(127, 1));
      });
    });

    group('Global alpha', () {
      Color draw(final BlendMode mode) {
        final engine = GraphicsEngine(1, 1)
          ..clear(const Color(0xFFFF0000))
          ..globalAlpha = 0.5
          ..globalCompositeOperation = mode
          ..fillStyle = const Color(0xFF0000FF)
          ..fillRect(0, 0, 1, 1);
        return engine.pixel(0, 0);
      }

      test('clear ignores global alpha and clears the pixel', () {
        expect(draw(BlendMode.clear).alpha, equals(0));
      });

      test('src replaces the pixel with the half-transparent source', () {
        final result = draw(BlendMode.src);

        expect(result.alpha, closeTo(128, 1));
        expect(result.blue, equals(255));
        expect(result.red, equals(0));
      });

      test('srcOver blends the half-transparent source over the pixel', () {
        final result = draw(BlendMode.srcOver);

        expect(result.alpha, equals(255));
        expect(result.red, closeTo(127, 1));
        expect(result.blue, closeTo(128, 1));
      });
    });
  });
}

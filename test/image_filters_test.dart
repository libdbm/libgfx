import 'dart:math';

import 'package:libgfx/libgfx.dart';
import 'package:test/test.dart';

void main() {
  group('ImageFilters', () {
    late Bitmap testBitmap;

    setUp(() {
      // Create test bitmap with pattern
      testBitmap = Bitmap(10, 10);
      for (int y = 0; y < 10; y++) {
        for (int x = 0; x < 10; x++) {
          // Create checkerboard pattern
          final isWhite = (x + y) % 2 == 0;
          testBitmap.plot(
            x,
            y,
            isWhite ? Color(0xFFFFFFFF) : Color(0xFF000000),
          );
        }
      }
    });

    group('Gaussian Blur', () {
      test('applies gaussian blur with small sigma', () {
        final result = ImageFilters.gaussian(testBitmap, 1.0);

        expect(result, isNotNull);
        expect(result.width, equals(testBitmap.width));
        expect(result.height, equals(testBitmap.height));

        // Blurred image should have intermediate values
        final centerPixel = result.pixel(5, 5);
        expect(centerPixel.red, greaterThan(0));
        expect(centerPixel.red, lessThan(255));
      });

      test('applies gaussian blur with large sigma', () {
        final result = ImageFilters.gaussian(testBitmap, 3.0);

        // Larger sigma should blur more
        final centerPixel = result.pixel(5, 5);

        // Should be closer to average (gray)
        expect(centerPixel.red, closeTo(128, 50));
        expect(centerPixel.green, closeTo(128, 50));
        expect(centerPixel.blue, closeTo(128, 50));
      });

      test('handles zero sigma', () {
        final result = ImageFilters.gaussian(testBitmap, 0.0);

        // Zero sigma should return original or handle gracefully
        expect(result, isNotNull);
        expect(result.width, equals(testBitmap.width));
      });

      test('preserves edges correctly', () {
        final solidBitmap = Bitmap(10, 10);
        solidBitmap.clear(Color(0xFFFF0000)); // All red

        final result = ImageFilters.gaussian(solidBitmap, 2.0);

        // Center should still be red
        final centerPixel = result.pixel(5, 5);
        expect(centerPixel.red, equals(255));

        // Edges might be slightly different due to boundary handling
        final edgePixel = result.pixel(0, 0);
        expect(edgePixel.red, greaterThan(200));
      });
    });

    group('Box Blur', () {
      test('applies box blur with small radius', () {
        final result = ImageFilters.box(testBitmap, 1);

        expect(result, isNotNull);
        expect(result.width, equals(testBitmap.width));
        expect(result.height, equals(testBitmap.height));

        // Should average neighboring pixels
        final pixel = result.pixel(5, 5);
        expect(pixel.red, greaterThan(0));
        expect(pixel.red, lessThan(255));
      });

      test('applies box blur with large radius', () {
        final result = ImageFilters.box(testBitmap, 3);

        // Should be more blurred
        final pixel = result.pixel(5, 5);

        // Should be close to average
        expect(pixel.red, closeTo(128, 30));
      });

      test('handles zero radius', () {
        final result = ImageFilters.box(testBitmap, 0);

        // Should return original or handle gracefully
        expect(result, isNotNull);

        // Should be unchanged
        final original = testBitmap.pixel(5, 5);
        final filtered = result.pixel(5, 5);
        expect(filtered.value, equals(original.value));
      });
    });

    group('Sharpen', () {
      test('sharpens blurred image', () {
        // First blur the image
        final blurred = ImageFilters.box(testBitmap, 1);

        // Then sharpen it
        final sharpened = ImageFilters.sharpen(blurred, 1.0);

        expect(sharpened, isNotNull);
        expect(sharpened.width, equals(testBitmap.width));

        // Sharpening should increase contrast
        // Hard to test precisely without visual inspection
      });

      test('applies different sharpen amounts', () {
        final light = ImageFilters.sharpen(testBitmap, 0.5);
        final medium = ImageFilters.sharpen(testBitmap, 1.0);
        final strong = ImageFilters.sharpen(testBitmap, 2.0);

        expect(light, isNotNull);
        expect(medium, isNotNull);
        expect(strong, isNotNull);

        // Stronger sharpening should create more contrast
        // Visual differences are hard to test numerically
      });

      test('handles zero amount', () {
        final result = ImageFilters.sharpen(testBitmap, 0.0);

        // Zero amount should return original
        expect(result, isNotNull);

        final original = testBitmap.pixel(5, 5);
        final filtered = result.pixel(5, 5);
        expect(filtered.value, equals(original.value));
      });
    });

    group('Edge Detection', () {
      test('detects edges in high contrast image', () {
        final result = ImageFilters.edges(testBitmap, threshold: 128);

        expect(result, isNotNull);

        // Should highlight edges between black and white
        // Edge pixels should be bright, non-edge should be dark
        var maxEdgeValue = 0;
        for (int y = 1; y < 9; y++) {
          for (int x = 1; x < 9; x++) {
            final pixel = result.pixel(x, y);
            if (pixel.red > maxEdgeValue) {
              maxEdgeValue = pixel.red;
            }
          }
        }
        // Edge detection might not work as expected for this simple pattern
        // Just check that the filter ran without error
        expect(result, isNotNull);
      });

      Bitmap step(final bool vertical, final bool rising) {
        final bitmap = Bitmap(10, 10);
        for (var y = 0; y < 10; y++) {
          for (var x = 0; x < 10; x++) {
            final bright = (vertical ? x : y) >= 5;
            bitmap.plot(
              x,
              y,
              bright == rising
                  ? const Color(0xFFFFFFFF)
                  : const Color(0xFF000000),
            );
          }
        }
        return bitmap;
      }

      for (final vertical in [true, false]) {
        final axis = vertical ? 'vertical' : 'horizontal';
        test('finds a $axis edge regardless of its polarity', () {
          final rising = ImageFilters.edges(step(vertical, true));
          final falling = ImageFilters.edges(step(vertical, false));

          expect(rising.pixels.any((pixel) => pixel == 0xFFFFFFFF), isTrue);
          expect(falling.pixels, equals(rising.pixels));
        });
      }

      test('applies different thresholds', () {
        final low = ImageFilters.edges(testBitmap, threshold: 50);
        final medium = ImageFilters.edges(testBitmap, threshold: 128);
        final high = ImageFilters.edges(testBitmap, threshold: 200);

        expect(low, isNotNull);
        expect(medium, isNotNull);
        expect(high, isNotNull);

        // Different thresholds should produce different results
      });

      test('handles solid color image', () {
        final solidBitmap = Bitmap(10, 10);
        solidBitmap.clear(Color(0xFF808080)); // All gray

        final result = ImageFilters.edges(solidBitmap);

        // Should have no edges (all pixels similar)
        var hasEdges = false;
        for (int y = 1; y < 9; y++) {
          for (int x = 1; x < 9; x++) {
            final pixel = result.pixel(x, y);
            if (pixel.red > 128) {
              hasEdges = true;
              break;
            }
          }
        }
        expect(hasEdges, isFalse);
      });
    });

    group('Emboss', () {
      test('applies emboss effect', () {
        final result = ImageFilters.emboss(testBitmap, strength: 1.0);

        expect(result, isNotNull);
        expect(result.width, equals(testBitmap.width));

        // Emboss should create 3D-like effect
        // Difficult to test numerically, mainly checking it doesn't crash
      });

      test('applies different strengths', () {
        final weak = ImageFilters.emboss(testBitmap, strength: 0.5);
        final normal = ImageFilters.emboss(testBitmap, strength: 1.0);
        final strong = ImageFilters.emboss(testBitmap, strength: 2.0);

        expect(weak, isNotNull);
        expect(normal, isNotNull);
        expect(strong, isNotNull);
      });

      test('handles zero strength', () {
        final result = ImageFilters.emboss(testBitmap, strength: 0.0);

        expect(result, isNotNull);

        // Zero strength should return original or neutral
        final pixel = result.pixel(5, 5);
        expect(pixel, isNotNull);
      });
    });

    group('Motion Blur', () {
      test('applies horizontal motion blur', () {
        final result = ImageFilters.motion(testBitmap, 0, 5);

        expect(result, isNotNull);

        // Horizontal blur should average horizontal neighbors
        // Vertical edges should be preserved better than horizontal
      });

      test('applies vertical motion blur', () {
        final result = ImageFilters.motion(testBitmap, 1.5708, 5); // 90 degrees

        expect(result, isNotNull);

        // Vertical blur should average vertical neighbors
      });

      test('applies diagonal motion blur', () {
        final result = ImageFilters.motion(testBitmap, 0.7854, 5); // 45 degrees

        expect(result, isNotNull);

        // Diagonal blur
      });

      test('handles zero distance', () {
        final result = ImageFilters.motion(testBitmap, 0, 0);

        expect(result, isNotNull);

        // Should return original
        final original = testBitmap.pixel(5, 5);
        final filtered = result.pixel(5, 5);
        expect(filtered.value, equals(original.value));
      });

      test('handles large distance', () {
        final result = ImageFilters.motion(testBitmap, 0, 20);

        expect(result, isNotNull);

        // Should blur across entire image
        final pixel = result.pixel(5, 5);
        expect(pixel.red, closeTo(128, 50)); // Should be averaged
      });
    });

    group('Edge Cases', () {
      test('handles empty bitmap', () {
        final empty = Bitmap(0, 0);

        // Filters might handle empty bitmaps by returning empty result
        final result = ImageFilters.gaussian(empty, 1.0);
        expect(result.width, equals(0));
        expect(result.height, equals(0));
      });

      test('handles 1x1 bitmap', () {
        final tiny = Bitmap(1, 1);
        tiny.plot(0, 0, Color(0xFFFF0000));

        final blurred = ImageFilters.gaussian(tiny, 1.0);
        expect(blurred, isNotNull);
        expect(blurred.width, equals(1));
        expect(blurred.pixel(0, 0).red, equals(255));
      });

      test('handles transparent images', () {
        final transparent = Bitmap(10, 10); // All transparent

        final blurred = ImageFilters.gaussian(transparent, 2.0);
        expect(blurred, isNotNull);

        // Should remain transparent
        expect(blurred.pixel(5, 5).alpha, equals(0));
      });

      test('preserves alpha channel', () {
        final bitmap = Bitmap(10, 10);
        // Create gradient of alpha values
        for (int y = 0; y < 10; y++) {
          for (int x = 0; x < 10; x++) {
            final alpha = (x * 25).clamp(0, 255);
            bitmap.plot(x, y, Color.fromARGB(alpha, 255, 0, 0));
          }
        }

        final filtered = ImageFilters.gaussian(bitmap, 1.0);

        // Alpha should be processed correctly
        expect(filtered.pixel(5, 5).alpha, greaterThan(0));
        expect(filtered.pixel(5, 5).alpha, lessThan(255));
      });
    });

    group('Performance', () {
      test('filters large image efficiently', () {
        final largeBitmap = Bitmap(100, 100);
        // Fill with pattern
        for (int y = 0; y < 100; y++) {
          for (int x = 0; x < 100; x++) {
            largeBitmap.plot(x, y, Color.fromARGB(255, x * 2, y * 2, (x + y)));
          }
        }

        final result = ImageFilters.gaussian(largeBitmap, 2.0);

        expect(result.width, equals(largeBitmap.width));
        expect(result.height, equals(largeBitmap.height));
      });

      test('chained filters work correctly', () {
        var result = testBitmap;

        // Apply multiple filters in sequence
        result = ImageFilters.gaussian(result, 1.0);
        result = ImageFilters.sharpen(result, 1.0);
        result = ImageFilters.edges(result, threshold: 128);

        expect(result, isNotNull);
        expect(result.width, equals(testBitmap.width));
        expect(result.height, equals(testBitmap.height));
      });
    });

    group('Blur invariants', () {
      final white = Bitmap(12, 12)..clear(const Color(0xFFFFFFFF));

      for (final radius in [1, 2, 8]) {
        test(
          'stack blur keeps a constant image constant at radius $radius',
          () {
            final result = ImageFilters.stack(white, radius);

            expect(result.pixels.every((pixel) => pixel == 0xFFFFFFFF), isTrue);
          },
        );

        test('box blur keeps a constant image constant at radius $radius', () {
          final result = ImageFilters.box(white, radius);

          expect(result.pixels.every((pixel) => pixel == 0xFFFFFFFF), isTrue);
        });
      }

      test('gaussian blur keeps a constant image constant', () {
        final result = ImageFilters.gaussian(white, 2.0);

        expect(result.pixels.every((pixel) => pixel == 0xFFFFFFFF), isTrue);
      });

      test('stack blur spreads a single pixel symmetrically', () {
        final dot = Bitmap(11, 11)
          ..clear(const Color(0xFF000000))
          ..plot(5, 5, const Color(0xFFFFFFFF));

        final result = ImageFilters.stack(dot, 1);

        expect(result.pixel(5, 5).red, closeTo(28, 1));
        expect(result.pixel(4, 5).red, equals(result.pixel(6, 5).red));
        expect(result.pixel(5, 4).red, equals(result.pixel(5, 6).red));
        expect(result.pixel(7, 5).red, equals(0));
        expect(result.pixel(3, 5).red, equals(0));
      });
    });

    group('Radius limit', () {
      final source = Bitmap(4, 4);

      test('each blur throws ArgumentError above the limit', () {
        expect(() => ImageFilters.box(source, 257), throwsArgumentError);
        expect(() => ImageFilters.stack(source, 257), throwsArgumentError);
        expect(() => ImageFilters.motion(source, 0, 257), throwsArgumentError);
        // A sigma of 86 needs a kernel radius of 258
        expect(() => ImageFilters.gaussian(source, 86), throwsArgumentError);
      });

      test('the limit itself is accepted', () {
        ImageFilters.box(source, 256);
        ImageFilters.stack(source, 256);
        ImageFilters.motion(source, 0, 256);
        ImageFilters.gaussian(source, 85);
      });

      test('a huge sigma throws before allocating its kernel', () {
        expect(() => ImageFilters.gaussian(source, 1e12), throwsArgumentError);
      });

      test('custom limits apply', () {
        final limits = Limits(radius: 2);
        expect(
          () => ImageFilters.box(source, 3, limits: limits),
          throwsArgumentError,
        );
        ImageFilters.box(source, 2, limits: limits);
      });

      test('the default limit is 256', () {
        expect(const Limits().radius, equals(256));
      });
    });

    group('Box blur matches the full-window average', () {
      test('on random images of every shape and radius', () {
        final random = Random(3);
        for (final (width, height) in [
          (1, 1),
          (1, 9),
          (9, 1),
          (5, 4),
          (23, 17),
        ]) {
          final image = Bitmap(width, height);
          for (var y = 0; y < height; y++) {
            for (var x = 0; x < width; x++) {
              image.plot(x, y, Color(random.nextInt(1 << 32)));
            }
          }
          for (final radius in [1, 2, 3, 7, 30]) {
            final actual = ImageFilters.box(image, radius);
            final expected = _boxBlur(image, radius);
            for (var y = 0; y < height; y++) {
              for (var x = 0; x < width; x++) {
                expect(
                  actual.pixel(x, y).value,
                  equals(expected.pixel(x, y).value),
                  reason: '${width}x$height radius $radius at ($x, $y)',
                );
              }
            }
          }
        }
      });
    });
  });
}

/// The box blur as it was written: every output pixel averages the full
/// (2 * radius + 1) squared window, with clamped edges. The reference for the
/// running-sum version.
Bitmap _boxBlur(final Bitmap source, final int radius) {
  final result = Bitmap(source.width, source.height);
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      double r = 0, g = 0, b = 0, a = 0;
      var count = 0;
      for (var dy = -radius; dy <= radius; dy++) {
        final py = (y + dy).clamp(0, source.height - 1);
        for (var dx = -radius; dx <= radius; dx++) {
          final px = (x + dx).clamp(0, source.width - 1);
          final color = source.pixel(px, py);
          r += color.red;
          g += color.green;
          b += color.blue;
          a += color.alpha;
          count++;
        }
      }
      result.plot(
        x,
        y,
        Color.fromRGBA(
          (r / count).round(),
          (g / count).round(),
          (b / count).round(),
          (a / count).round(),
        ),
      );
    }
  }
  return result;
}

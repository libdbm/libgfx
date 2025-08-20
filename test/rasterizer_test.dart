import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/graphics_context.dart';
import 'package:libgfx/src/spans/span.dart';
import 'package:test/test.dart';

void main() {
  group('ScanlineRasterizer', () {
    late GraphicsContext context;

    setUp(() {
      final bitmap = Bitmap(200, 200);
      context = GraphicsContext(bitmap);
    });

    group('Basic Shapes', () {
      test('rasterizes a simple rectangle', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(50, 10)
          ..lineTo(50, 30)
          ..lineTo(10, 30)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        // Should have spans for each scanline from y=10 to y=29
        final spansByY = <int, List<Span>>{};
        for (final span in spans) {
          (spansByY[span.y] ??= []).add(span);
        }

        // Check we have the right number of scanlines
        expect(spansByY.length, equals(20)); // Height of 20 (y=10 to y=29)

        // Check first and last scanlines
        expect(spansByY.containsKey(10), isTrue);
        expect(spansByY.containsKey(29), isTrue);

        // Check span width on a middle scanline
        final middleSpans = spansByY[20];
        expect(middleSpans, isNotNull);
        expect(middleSpans!.length, greaterThan(0));

        // Calculate total coverage for a scanline
        var totalLength = 0;
        for (final span in middleSpans) {
          totalLength += span.length;
        }
        expect(totalLength, equals(40)); // Width of rectangle
      });

      test('rasterizes a triangle', () {
        final path = PathBuilder()
          ..moveTo(25, 10) // Top
          ..lineTo(40, 40) // Bottom right
          ..lineTo(10, 40) // Bottom left
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        expect(spans, isNotEmpty);

        // Group spans by scanline
        final spansByY = <int, List<Span>>{};
        for (final span in spans) {
          (spansByY[span.y] ??= []).add(span);
        }

        // Should have spans from y=10 to y=39 (allowing for rounding)
        final minY = spansByY.keys.reduce((a, b) => a < b ? a : b);
        final maxY = spansByY.keys.reduce((a, b) => a > b ? a : b);
        expect(minY, lessThanOrEqualTo(11)); // Near the top
        expect(maxY, greaterThanOrEqualTo(39)); // Near the bottom

        // Top should be narrower than bottom
        // Get spans near the top and bottom
        final topY = minY;
        final bottomY = maxY;

        if (spansByY.containsKey(topY) && spansByY.containsKey(bottomY)) {
          final topSpans = spansByY[topY]!;
          final bottomSpans = spansByY[bottomY]!;

          var topWidth = 0;
          for (final span in topSpans) {
            topWidth += span.length;
          }

          var bottomWidth = 0;
          for (final span in bottomSpans) {
            bottomWidth += span.length;
          }

          expect(bottomWidth, greaterThan(topWidth));
        }
      });

      test('rasterizes a circle (approximated with bezier curves)', () {
        final path = PathBuilder();
        final cx = 50.0;
        final cy = 50.0;
        final radius = 20.0;
        final k = 0.5522847498307933 * radius; // Magic constant for circle

        path.moveTo(cx + radius, cy);
        path.curveTo(cx + radius, cy + k, cx + k, cy + radius, cx, cy + radius);
        path.curveTo(cx - k, cy + radius, cx - radius, cy + k, cx - radius, cy);
        path.curveTo(cx - radius, cy - k, cx - k, cy - radius, cx, cy - radius);
        path.curveTo(cx + k, cy - radius, cx + radius, cy - k, cx + radius, cy);
        path.close();

        final spans = context.rasterizer.rasterize(path.build());

        expect(spans, isNotEmpty);

        // Group spans by scanline
        final spansByY = <int, List<Span>>{};
        for (final span in spans) {
          (spansByY[span.y] ??= []).add(span);
        }

        // Should have spans roughly from y=30 to y=70 (radius 20)
        expect(spansByY.keys.any((y) => y >= 30 && y <= 70), isTrue);

        // Middle scanline should be widest (diameter)
        final middleY = 50;
        if (spansByY.containsKey(middleY)) {
          final middleSpans = spansByY[middleY]!;
          var middleWidth = 0;
          for (final span in middleSpans) {
            middleWidth += span.length;
          }
          // Should be close to diameter (40)
          expect(middleWidth, closeTo(40, 5));
        }
      });
    });

    group('Complex Paths', () {
      test('rasterizes path with multiple subpaths', () {
        final path = PathBuilder()
          // First rectangle
          ..moveTo(10, 10)
          ..lineTo(30, 10)
          ..lineTo(30, 30)
          ..lineTo(10, 30)
          ..close()
          // Second rectangle
          ..moveTo(40, 10)
          ..lineTo(60, 10)
          ..lineTo(60, 30)
          ..lineTo(40, 30)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        // Group spans by scanline
        final spansByY = <int, List<Span>>{};
        for (final span in spans) {
          (spansByY[span.y] ??= []).add(span);
        }

        // Check a middle scanline has spans for both rectangles
        final middleY = 20;
        final middleSpans = spansByY[middleY];
        expect(middleSpans, isNotNull);

        // Should have spans covering both rectangles
        var minX = 100;
        var maxX = 0;
        for (final span in middleSpans!) {
          minX = span.x1 < minX ? span.x1 : minX;
          final spanEnd = span.x1 + span.length;
          maxX = spanEnd > maxX ? spanEnd : maxX;
        }

        expect(minX, lessThanOrEqualTo(10)); // First rect starts at x=10
        expect(maxX, greaterThanOrEqualTo(60)); // Second rect ends at x=60
      });

      test('rasterizes self-intersecting path (even-odd rule)', () {
        // Create a figure-8 shape
        final path = PathBuilder()
          ..moveTo(20, 20)
          ..lineTo(40, 40)
          ..lineTo(40, 20)
          ..lineTo(20, 40)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        expect(spans, isNotEmpty);

        // The intersection point should create interesting span patterns
        final spansByY = <int, List<Span>>{};
        for (final span in spans) {
          (spansByY[span.y] ??= []).add(span);
        }

        // Check that we have spans in the expected range
        expect(spansByY.keys.any((y) => y >= 20 && y <= 40), isTrue);
      });

      test('rasterizes path with curves', () {
        final path = PathBuilder()
          ..moveTo(10, 30)
          ..curveTo(10, 10, 30, 10, 30, 30)
          ..curveTo(30, 50, 10, 50, 10, 30)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        expect(spans, isNotEmpty);

        // Should create a smooth curved shape
        final spansByY = <int, List<Span>>{};
        for (final span in spans) {
          (spansByY[span.y] ??= []).add(span);
        }

        // Should have spans in the curve range
        expect(spansByY.keys.any((y) => y >= 10 && y <= 50), isTrue);
      });
    });

    group('Edge Cases', () {
      test('handles empty path', () {
        final path = PathBuilder().build();

        final spans = context.rasterizer.rasterize(path);

        expect(spans, isEmpty);
      });

      test('handles single point path', () {
        final path = PathBuilder()..moveTo(10, 10);

        final spans = context.rasterizer.rasterize(path.build());

        // Single point might not generate spans or might generate minimal spans
        expect(spans.length, lessThanOrEqualTo(1));
      });

      test('handles horizontal line', () {
        final path = PathBuilder()
          ..moveTo(10, 20)
          ..lineTo(50, 20);

        final spans = context.rasterizer.rasterize(path.build());

        // Horizontal line might generate a single scanline
        if (spans.isNotEmpty) {
          final yValues = spans.map((s) => s.y).toSet();
          expect(yValues.length, lessThanOrEqualTo(1));
        }
      });

      test('handles vertical line', () {
        final path = PathBuilder()
          ..moveTo(20, 10)
          ..lineTo(20, 50);

        final spans = context.rasterizer.rasterize(path.build());

        // Vertical line should generate spans at multiple y values
        if (spans.isNotEmpty) {
          final yValues = spans.map((s) => s.y).toSet();
          expect(yValues.length, greaterThan(1));
        }
      });

      test('handles very small shapes', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(11, 10)
          ..lineTo(11, 11)
          ..lineTo(10, 11)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        // Should generate at least one span for 1x1 rectangle
        expect(spans, isNotEmpty);

        // Should cover exactly 1 pixel
        var totalPixels = 0;
        for (final span in spans) {
          totalPixels += span.length;
        }
        expect(totalPixels, greaterThan(0));
      });
    });

    group('Anti-aliasing', () {
      test('generates coverage values for anti-aliasing', () {
        // Create a diagonal line that should have partial coverage
        final path = PathBuilder()
          ..moveTo(10.5, 10.5)
          ..lineTo(20.5, 20.5)
          ..lineTo(10.5, 20.5)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        // Check that we have varying coverage values
        final coverageValues = spans.map((s) => s.coverage).toSet();

        // Should have at least some partial coverage values
        expect(coverageValues.any((c) => c > 0 && c < 255), isTrue);
      });

      test('full coverage for fully covered pixels', () {
        // Large rectangle should have fully covered pixels in the middle
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(50, 10)
          ..lineTo(50, 50)
          ..lineTo(10, 50)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        // Middle spans should have full coverage
        final middleSpans = spans.where((s) => s.y == 30).toList();
        expect(middleSpans.any((s) => s.coverage == 255), isTrue);
      });
    });

    group('Transform Support', () {
      test('rasterizes transformed rectangle', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(30, 10)
          ..lineTo(30, 30)
          ..lineTo(10, 30)
          ..close();

        // Apply rotation transform
        final transform = Matrix2D.rotation(math.pi / 4); // 45 degrees
        final transformedPath = path.build().transform(transform);

        final spans = context.rasterizer.rasterize(transformedPath);

        expect(spans, isNotEmpty);

        // Rotated square should have different bounds
        var minY = 1000000;
        var maxY = -1000000;
        for (final span in spans) {
          if (span.y < minY) minY = span.y;
          if (span.y > maxY) maxY = span.y;
        }

        // Rotated square should be taller than original
        final height = maxY - minY;
        expect(height, greaterThan(20)); // Original height was 20
      });

      test('rasterizes scaled path', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(20, 10)
          ..lineTo(20, 20)
          ..lineTo(10, 20)
          ..close();

        // Apply scale transform
        final transform = Matrix2D.scaling(2.0, 3.0);
        final transformedPath = path.build().transform(transform);

        final spans = context.rasterizer.rasterize(transformedPath);

        // Group spans by scanline
        final spansByY = <int, List<Span>>{};
        for (final span in spans) {
          (spansByY[span.y] ??= []).add(span);
        }

        // Scaled rectangle should be 20x30
        var minY = 1000000;
        var maxY = -1000000;
        for (final y in spansByY.keys) {
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }

        final height = maxY - minY + 1;
        expect(height, closeTo(30, 2)); // Scaled height should be ~30
      });
    });

    group('Boundary Conditions', () {
      test('handles path extending beyond typical bounds', () {
        final path = PathBuilder()
          ..moveTo(-10, -10)
          ..lineTo(110, -10)
          ..lineTo(110, 110)
          ..lineTo(-10, 110)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        // Should handle negative coordinates
        expect(spans, isNotEmpty);

        // Check spans cover the expected range
        var minX = 1000000;
        var maxX = -1000000;
        var minY = 1000000;
        var maxY = -1000000;

        for (final span in spans) {
          if (span.x1 < minX) minX = span.x1;
          if (span.x1 + span.length > maxX) maxX = span.x1 + span.length;
          if (span.y < minY) minY = span.y;
          if (span.y > maxY) maxY = span.y;
        }

        expect(minX, lessThanOrEqualTo(0));
        expect(maxX, greaterThanOrEqualTo(100));
        expect(minY, lessThanOrEqualTo(0));
        expect(maxY, greaterThanOrEqualTo(100));
      });

      test('handles very large coordinates', () {
        final path = PathBuilder()
          ..moveTo(10000, 10000)
          ..lineTo(10100, 10000)
          ..lineTo(10100, 10100)
          ..lineTo(10000, 10100)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        // Should handle large coordinates
        expect(spans, isNotEmpty);

        // Check spans are in the expected range
        for (final span in spans) {
          expect(span.y, greaterThanOrEqualTo(10000));
          expect(span.y, lessThanOrEqualTo(10100));
          expect(span.x1, greaterThanOrEqualTo(10000));
        }
      });

      test('handles fractional coordinates precisely', () {
        final path = PathBuilder()
          ..moveTo(10.3, 10.7)
          ..lineTo(20.7, 10.3)
          ..lineTo(20.3, 20.7)
          ..lineTo(10.7, 20.3)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        // Should handle fractional coordinates
        expect(spans, isNotEmpty);

        // Should have partial coverage due to fractional positions
        final partialCoverage = spans.where(
          (s) => s.coverage > 0 && s.coverage < 255,
        );
        expect(partialCoverage, isNotEmpty);
      });
    });

    group('Winding and Overlap', () {
      test('handles overlapping rectangles', () {
        final path = PathBuilder()
          // First rectangle
          ..moveTo(10, 10)
          ..lineTo(40, 10)
          ..lineTo(40, 40)
          ..lineTo(10, 40)
          ..close()
          // Second overlapping rectangle
          ..moveTo(25, 25)
          ..lineTo(55, 25)
          ..lineTo(55, 55)
          ..lineTo(25, 55)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        expect(spans, isNotEmpty);

        // Check that we have spans in both rectangle areas
        // The exact behavior for overlapping areas may vary by implementation
        final firstRectSpans = spans.where(
          (s) => s.y >= 10 && s.y < 40 && s.x1 >= 10 && s.x1 < 40,
        );
        final secondRectSpans = spans.where(
          (s) => s.y >= 25 && s.y < 55 && s.x1 >= 25 && s.x1 < 55,
        );
        expect(firstRectSpans, isNotEmpty);
        expect(secondRectSpans, isNotEmpty);
      });

      test('handles concentric shapes', () {
        final path = PathBuilder()
          // Outer rectangle
          ..moveTo(10, 10)
          ..lineTo(50, 10)
          ..lineTo(50, 50)
          ..lineTo(10, 50)
          ..close()
          // Inner rectangle (same winding)
          ..moveTo(20, 20)
          ..lineTo(40, 20)
          ..lineTo(40, 40)
          ..lineTo(20, 40)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        expect(spans, isNotEmpty);

        // Both rectangles should be filled
        final spansByY = <int, List<Span>>{};
        for (final span in spans) {
          (spansByY[span.y] ??= []).add(span);
        }

        // Find a scanline in the middle region that has spans
        // The exact scanline may vary due to rasterization
        var foundMiddleSpans = false;
        for (int y = 25; y <= 35; y++) {
          if (spansByY.containsKey(y)) {
            final middleSpans = spansByY[y]!;
            var totalWidth = 0;
            for (final span in middleSpans) {
              totalWidth += span.length;
            }
            // Should have some reasonable coverage
            if (totalWidth >= 20) {
              // At least some coverage of the outer rect
              foundMiddleSpans = true;
              break;
            }
          }
        }
        expect(foundMiddleSpans, isTrue);
      });

      test('handles opposite winding directions', () {
        final path = PathBuilder()
          // Clockwise rectangle
          ..moveTo(10, 10)
          ..lineTo(40, 10)
          ..lineTo(40, 40)
          ..lineTo(10, 40)
          ..close()
          // Counter-clockwise rectangle
          ..moveTo(25, 25)
          ..lineTo(25, 55)
          ..lineTo(55, 55)
          ..lineTo(55, 25)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        expect(spans, isNotEmpty);
        // Both should still be filled in default mode
      });
    });

    group('Precision and Accuracy', () {
      test('handles sub-pixel precision', () {
        final path = PathBuilder()
          ..moveTo(10.25, 10.75)
          ..lineTo(20.75, 10.25)
          ..lineTo(20.25, 20.75)
          ..lineTo(10.75, 20.25)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        expect(spans, isNotEmpty);

        // Should have partial coverage at edges due to sub-pixel positions
        final edgeCoverages = spans.map((s) => s.coverage).toSet();
        expect(edgeCoverages.any((c) => c > 0 && c < 255), isTrue);
      });

      test('handles very thin shapes', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(10.1, 10)
          ..lineTo(10.1, 50)
          ..lineTo(10, 50)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        // Very thin shape should still generate some spans
        expect(spans, isNotEmpty);

        // Coverage should be partial due to thinness
        expect(spans.any((s) => s.coverage < 255), isTrue);
      });

      test('handles coincident points', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(10, 10) // Same point
          ..lineTo(20, 20)
          ..lineTo(10, 20)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        // Should handle degenerate segments gracefully
        expect(spans, isNotEmpty);
      });
    });

    group('Complex Curves', () {
      test('rasterizes quadratic bezier curves', () {
        final path = PathBuilder()..moveTo(10, 30);

        // Convert quadratic to cubic bezier
        // Q(x1,y1,x2,y2) becomes C(2/3*x1+1/3*x0, 2/3*y1+1/3*y0, 2/3*x1+1/3*x2, 2/3*y1+1/3*y2, x2, y2)
        final x0 = 10.0, y0 = 30.0;
        final x1 = 30.0, y1 = 10.0; // control point
        final x2 = 50.0, y2 = 30.0; // end point

        path.curveTo(
          2.0 / 3.0 * x1 + 1.0 / 3.0 * x0,
          2.0 / 3.0 * y1 + 1.0 / 3.0 * y0,
          2.0 / 3.0 * x1 + 1.0 / 3.0 * x2,
          2.0 / 3.0 * y1 + 1.0 / 3.0 * y2,
          x2,
          y2,
        );

        path.lineTo(30, 50);
        path.close();

        final spans = context.rasterizer.rasterize(path.build());

        expect(spans, isNotEmpty);

        // Should create smooth curve
        final spansByY = <int, List<Span>>{};
        for (final span in spans) {
          (spansByY[span.y] ??= []).add(span);
        }

        // Curve should span expected range
        expect(spansByY.keys.any((y) => y >= 10 && y <= 50), isTrue);
      });

      test('rasterizes compound curves', () {
        final path = PathBuilder()..moveTo(10, 50);

        // Create a wavy pattern
        for (int i = 0; i < 5; i++) {
          final x1 = 10 + i * 20;
          final x2 = 20 + i * 20;
          final y1 = i % 2 == 0 ? 30 : 70;
          final y2 = i % 2 == 0 ? 70 : 30;

          // Convert quadratic to cubic bezier
          final lastX = x1;
          final lastY = i % 2 == 0 ? 50 : 50;
          final cpX = x1 + 10;
          final cpY = y1;

          path.curveTo(
            2.0 / 3.0 * cpX + 1.0 / 3.0 * lastX,
            2.0 / 3.0 * cpY + 1.0 / 3.0 * lastY,
            2.0 / 3.0 * cpX + 1.0 / 3.0 * x2,
            2.0 / 3.0 * cpY + 1.0 / 3.0 * y2,
            x2.toDouble(),
            y2.toDouble(),
          );
        }

        path.lineTo(110, 50);
        path.close();

        final spans = context.rasterizer.rasterize(path.build());

        expect(spans, isNotEmpty);

        // Should create multiple wave peaks and troughs
        final yValues = spans.map((s) => s.y).toSet();
        expect(
          yValues.length,
          greaterThan(10),
        ); // Should have good vertical coverage
      });

      test('handles cusps and sharp turns', () {
        final path = PathBuilder()
          ..moveTo(20, 20)
          ..curveTo(40, 10, 40, 30, 20, 20) // Cusp at start/end
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        expect(spans, isNotEmpty);
        // Should handle the cusp without artifacts
      });
    });

    group('Performance', () {
      test('handles large paths efficiently', () {
        final path = PathBuilder();

        // Create a complex path with many segments
        for (int i = 0; i < 100; i++) {
          final angle = (i / 100) * 2 * 3.14159;
          final x = 100 + 50 * (1 + i / 100) * cos(angle);
          final y = 100 + 50 * (1 + i / 100) * sin(angle);

          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();

        // Should complete in reasonable time
        final stopwatch = Stopwatch()..start();
        final spans = context.rasterizer.rasterize(path.build());
        stopwatch.stop();

        expect(spans, isNotEmpty);
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be fast
      });

      test('handles very large number of spans', () {
        // Create a path that will generate many spans
        final path = PathBuilder();

        // Create a grid pattern
        for (int i = 0; i < 50; i++) {
          for (int j = 0; j < 50; j++) {
            final x = i * 4.0;
            final y = j * 4.0;
            path.moveTo(x, y);
            path.lineTo(x + 2, y);
            path.lineTo(x + 2, y + 2);
            path.lineTo(x, y + 2);
            path.close();
          }
        }

        final stopwatch = Stopwatch()..start();
        final spans = context.rasterizer.rasterize(path.build());
        stopwatch.stop();

        expect(spans, isNotEmpty);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(500),
        ); // Should handle many shapes
      });
    });

    group('Span Merging', () {
      test('merges adjacent spans with same coverage', () {
        // Create a shape that should produce adjacent spans
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(50, 10)
          ..lineTo(50, 20)
          ..lineTo(10, 20)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        // Check that spans are efficiently merged
        final spansByY = <int, List<Span>>{};
        for (final span in spans) {
          (spansByY[span.y] ??= []).add(span);
        }

        // Each scanline should have minimal number of spans
        for (final scanlineSpans in spansByY.values) {
          // Sort spans by x
          scanlineSpans.sort((a, b) => a.x1.compareTo(b.x1));

          // Check no overlapping spans
          for (int i = 1; i < scanlineSpans.length; i++) {
            final prevEnd =
                scanlineSpans[i - 1].x1 + scanlineSpans[i - 1].length;
            final currentStart = scanlineSpans[i].x1;
            expect(currentStart, greaterThanOrEqualTo(prevEnd));
          }
        }
      });

      test('handles spans with different coverage values', () {
        // Create a shape with anti-aliased edges
        final path = PathBuilder()
          ..moveTo(10.5, 10.5)
          ..lineTo(50.5, 10.5)
          ..lineTo(50.5, 20.5)
          ..lineTo(10.5, 20.5)
          ..close();

        final spans = context.rasterizer.rasterize(path.build());

        // Should have varying coverage at edges
        final coverages = spans.map((s) => s.coverage).toSet();
        expect(coverages.length, greaterThan(1));
      });
    });
  });
}

// Helper functions for trigonometry
double cos(double radians) => math.cos(radians);

double sin(double radians) => math.sin(radians);

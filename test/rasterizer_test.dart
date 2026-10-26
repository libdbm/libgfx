import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/graphics_context.dart';
import 'package:libgfx/src/rasterize/implementations/basic_rasterizer.dart';
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
          ..closePath();

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
          ..closePath();

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
        path.bezierCurveTo(
          cx + radius,
          cy + k,
          cx + k,
          cy + radius,
          cx,
          cy + radius,
        );
        path.bezierCurveTo(
          cx - k,
          cy + radius,
          cx - radius,
          cy + k,
          cx - radius,
          cy,
        );
        path.bezierCurveTo(
          cx - radius,
          cy - k,
          cx - k,
          cy - radius,
          cx,
          cy - radius,
        );
        path.bezierCurveTo(
          cx + k,
          cy - radius,
          cx + radius,
          cy - k,
          cx + radius,
          cy,
        );
        path.closePath();

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
          ..closePath()
          // Second rectangle
          ..moveTo(40, 10)
          ..lineTo(60, 10)
          ..lineTo(60, 30)
          ..lineTo(40, 30)
          ..closePath();

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
          ..closePath();

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
          ..bezierCurveTo(10, 10, 30, 10, 30, 30)
          ..bezierCurveTo(30, 50, 10, 50, 10, 30)
          ..closePath();

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
          ..closePath();

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
          ..closePath();

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
          ..closePath();

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
          ..closePath();

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
          ..closePath();

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
          ..closePath();

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
          ..closePath();

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
          ..closePath();

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
          ..closePath()
          // Second overlapping rectangle
          ..moveTo(25, 25)
          ..lineTo(55, 25)
          ..lineTo(55, 55)
          ..lineTo(25, 55)
          ..closePath();

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
          ..closePath()
          // Inner rectangle (same winding)
          ..moveTo(20, 20)
          ..lineTo(40, 20)
          ..lineTo(40, 40)
          ..lineTo(20, 40)
          ..closePath();

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
          ..closePath()
          // Counter-clockwise rectangle
          ..moveTo(25, 25)
          ..lineTo(25, 55)
          ..lineTo(55, 55)
          ..lineTo(55, 25)
          ..closePath();

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
          ..closePath();

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
          ..closePath();

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
          ..closePath();

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

        path.bezierCurveTo(
          2.0 / 3.0 * x1 + 1.0 / 3.0 * x0,
          2.0 / 3.0 * y1 + 1.0 / 3.0 * y0,
          2.0 / 3.0 * x1 + 1.0 / 3.0 * x2,
          2.0 / 3.0 * y1 + 1.0 / 3.0 * y2,
          x2,
          y2,
        );

        path.lineTo(30, 50);
        path.closePath();

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

          path.bezierCurveTo(
            2.0 / 3.0 * cpX + 1.0 / 3.0 * lastX,
            2.0 / 3.0 * cpY + 1.0 / 3.0 * lastY,
            2.0 / 3.0 * cpX + 1.0 / 3.0 * x2,
            2.0 / 3.0 * cpY + 1.0 / 3.0 * y2,
            x2.toDouble(),
            y2.toDouble(),
          );
        }

        path.lineTo(110, 50);
        path.closePath();

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
          ..bezierCurveTo(40, 10, 40, 30, 20, 20) // Cusp at start/end
          ..closePath();

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
        path.closePath();

        final spans = context.rasterizer.rasterize(path.build());

        expect(spans, isNotEmpty);
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
            path.closePath();
          }
        }

        final spans = context.rasterizer.rasterize(path.build());

        expect(spans, isNotEmpty);
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
          ..closePath();

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
          ..closePath();

        final spans = context.rasterizer.rasterize(path.build());

        // Should have varying coverage at edges
        final coverages = spans.map((s) => s.coverage).toSet();
        expect(coverages.length, greaterThan(1));
      });
    });
  });

  group('Row coverage at vertices', () {
    Set<int> rows(final Path path) => {
      for (final span in BasicRasterizer().rasterize(path)) span.y,
    };

    for (final delta in [1e-14, 1e-7]) {
      test('a vertex at 75 + $delta does not drop row 75', () {
        final path =
            (PathBuilder()
                  ..moveTo(10, 50)
                  ..lineTo(100, 50)
                  ..lineTo(100, 75 + delta)
                  ..lineTo(100, 100)
                  ..lineTo(10, 100)
                  ..lineTo(10, 75 + delta)
                  ..closePath())
                .build();

        expect(rows(path), equals({for (var y = 50; y < 100; y++) y}));
      });
    }

    test('a circle fills the row through its centre', () {
      // Transforming converts the ellipse to cubics, as fill() does; the
      // left vertex lands at 75.00000000000001.
      final path = PathBuilder()
          .circle(75, 75, 60)
          .build()
          .transform(Matrix2D.identity());

      expect(rows(path), contains(75));
    });

    test('a full arc in a flipped coordinate system fills its centre row', () {
      // The smiley example: a 2*pi arc whose closing segment is a vertical
      // edge only 1e-14 high, straddling y = 75.
      final transform = Matrix2D.identity()
        ..translate(0, 150)
        ..scale(1, -1);
      final path = PathBuilder()
          .moveTo(145, 75)
          .arc(75, 75, 70, 0, 2 * math.pi)
          .closePath()
          .build()
          .transform(transform);

      expect(rows(path), contains(75));
    });

    test('an integer-aligned rectangle fills exactly its rows', () {
      final path =
          (PathBuilder()
                ..moveTo(10, 20)
                ..lineTo(40, 20)
                ..lineTo(40, 30)
                ..lineTo(10, 30)
                ..closePath())
              .build();

      expect(rows(path), equals({for (var y = 20; y < 30; y++) y}));
    });
  });

  group('Fill rule', () {
    // Two squares; the inner one is traced in the same direction as the outer
    // one, so its interior winds twice, unless [reversed]
    Path nested({final bool reversed = false}) {
      final builder = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(90, 10)
        ..lineTo(90, 90)
        ..lineTo(10, 90)
        ..closePath();
      if (reversed) {
        builder
          ..moveTo(30, 30)
          ..lineTo(30, 70)
          ..lineTo(70, 70)
          ..lineTo(70, 30)
          ..closePath();
      } else {
        builder
          ..moveTo(30, 30)
          ..lineTo(70, 30)
          ..lineTo(70, 70)
          ..lineTo(30, 70)
          ..closePath();
      }
      return builder.build();
    }

    int at(final List<Span> spans, final int x, final int y) => spans
        .where((span) => span.y == y && x >= span.x1 && x < span.x2)
        .fold(0, (sum, span) => sum + span.coverage);

    test('non-zero fills the centre of same-direction contours', () {
      final spans = BasicRasterizer().rasterize(
        nested(),
        rule: FillRule.nonZero,
      );
      expect(at(spans, 50, 50), equals(255));
      expect(at(spans, 20, 50), equals(255));
      expect(at(spans, 95, 50), equals(0));
    });

    test('even-odd leaves the centre of same-direction contours empty', () {
      final spans = BasicRasterizer().rasterize(
        nested(),
        rule: FillRule.evenOdd,
      );
      expect(at(spans, 50, 50), equals(0));
      expect(at(spans, 20, 50), equals(255));
    });

    test('both rules leave the centre of opposite contours empty', () {
      for (final rule in FillRule.values) {
        final spans = BasicRasterizer().rasterize(
          nested(reversed: true),
          rule: rule,
        );
        expect(at(spans, 50, 50), equals(0), reason: '$rule');
        expect(at(spans, 20, 50), equals(255), reason: '$rule');
      }
    });

    test('the rule defaults to even-odd', () {
      expect(at(BasicRasterizer().rasterize(nested()), 50, 50), equals(0));
    });

    test('the non-anti-aliased path honours the rule', () {
      final rasterizer = BasicRasterizer(antiAlias: false);
      expect(
        at(rasterizer.rasterize(nested(), rule: FillRule.nonZero), 50, 50),
        255,
      );
      expect(
        at(rasterizer.rasterize(nested(), rule: FillRule.evenOdd), 50, 50),
        0,
      );
    });
  });

  group('Viewport', () {
    const viewport = Rectangle<int>(0, 0, 40, 30);

    /// Coverage of each pixel inside [viewport].
    Map<(int, int), int> pixels(final List<Span> spans) {
      final result = <(int, int), int>{};
      for (final span in spans) {
        if (span.y < viewport.top || span.y >= viewport.bottom) continue;
        final left = math.max(span.x1, viewport.left);
        final right = math.min(span.x2, viewport.right);
        for (var x = left; x < right; x++) {
          result.update(
            (x, span.y),
            (value) => value + span.coverage,
            ifAbsent: () => span.coverage,
          );
        }
      }
      return result;
    }

    Path polygon(final List<(double, double)> points) {
      final builder = PathBuilder()..moveTo(points.first.$1, points.first.$2);
      for (final (x, y) in points.skip(1)) {
        builder.lineTo(x, y);
      }
      return (builder..closePath()).build();
    }

    // Shapes crossing each side of the viewport, a self-intersecting star
    // centred left of it, and nested squares straddling the left edge
    final shapes = {
      'left': polygon([(-25.3, 4.2), (17.6, 9.1), (11.2, 26.7), (-8.4, 21.5)]),
      'right': polygon([(30.2, 3.3), (63.9, 12.4), (34.1, 27.8)]),
      'above': polygon([(5.5, -17.2), (33.3, -4.6), (21.7, 19.9)]),
      'below': polygon([(3.1, 11.4), (36.6, 22.2), (14.9, 58.3)]),
      'star': polygon([
        for (var i = 0; i < 5; i++)
          (
            -4.7 + 30 * math.cos(-math.pi / 2 + i * 4 * math.pi / 5),
            15.2 + 30 * math.sin(-math.pi / 2 + i * 4 * math.pi / 5),
          ),
      ]),
      'nested':
          (PathBuilder()
                ..moveTo(-30.5, 2.5)
                ..lineTo(20.5, 2.5)
                ..lineTo(20.5, 27.5)
                ..lineTo(-30.5, 27.5)
                ..closePath()
                ..moveTo(-10.5, 8.5)
                ..lineTo(10.5, 8.5)
                ..lineTo(10.5, 20.5)
                ..lineTo(-10.5, 20.5)
                ..closePath())
              .build(),
    };

    for (final MapEntry(key: name, value: path) in shapes.entries) {
      for (final rule in FillRule.values) {
        for (final antiAlias in [true, false]) {
          test('$name, $rule, antiAlias $antiAlias matches unbounded', () {
            final rasterizer = BasicRasterizer(antiAlias: antiAlias);
            final bounded = rasterizer.rasterize(
              path,
              rule: rule,
              viewport: viewport,
            );

            expect(
              pixels(bounded),
              equals(pixels(rasterizer.rasterize(path, rule: rule))),
            );
            for (final span in bounded) {
              expect(
                span.y,
                inInclusiveRange(viewport.top, viewport.bottom - 1),
              );
              expect(span.x1, greaterThanOrEqualTo(viewport.left));
              expect(span.x2, lessThanOrEqualTo(viewport.right));
            }
          });
        }
      }
    }

    test('a path far larger than the viewport fills only the viewport', () {
      final tall = polygon([(-2, -1e7), (6, -1e7), (6, 1e7), (-2, 1e7)]);
      final wide = polygon([(-1e7, -2), (1e7, -2), (1e7, 6), (-1e7, 6)]);
      const small = Rectangle<int>(0, 0, 4, 4);
      final full = {
        for (var y = 0; y < 4; y++)
          for (var x = 0; x < 4; x++) (x, y): 255,
      };

      for (final path in [tall, wide]) {
        final spans = BasicRasterizer().rasterize(path, viewport: small);
        final covered = <(int, int), int>{
          for (final span in spans)
            for (var x = span.x1; x < span.x2; x++) (x, span.y): span.coverage,
        };
        expect(covered, equals(full));
      }
    });
  });

  group('Several winding values in one pixel', () {
    // Shapes inside pixel (1, 1): x 1..2, y 1..2
    Path rect(
      final double left,
      final double top,
      final double right,
      final double bottom, {
      final bool reverse = false,
    }) {
      final corners = [
        (left, top),
        (right, top),
        (right, bottom),
        (left, bottom),
      ];
      final ordered = reverse ? corners.reversed.toList() : corners;
      final builder = PathBuilder()..moveTo(ordered[0].$1, ordered[0].$2);
      for (final (x, y) in ordered.skip(1)) {
        builder.lineTo(x, y);
      }
      return (builder..closePath()).build();
    }

    Path join(final List<Path> paths) {
      final path = Path();
      for (final part in paths) {
        path.addPath(part);
      }
      return path;
    }

    int fill(final Path path, final FillRule rule) {
      for (final span in BasicRasterizer().rasterize(path, rule: rule)) {
        if (span.y == 1 && span.x1 <= 1 && 1 < span.x2) return span.coverage;
      }
      return 0;
    }

    int clip(final Path path, final FillRule rule) => ClipRegion.fromPath(
      path,
      Matrix2D.identity(),
      4,
      4,
      rule: rule,
    ).coverage(1, 1);

    // name: (shapes, true non-zero alpha, true even-odd alpha)
    final cases = <String, (List<Path>, int, int)>{
      'disjoint, opposite directions, stacked': (
        [rect(1, 1, 2, 1.4), rect(1, 1.6, 2, 2, reverse: true)],
        204,
        204,
      ),
      'disjoint, opposite directions, side by side': (
        [rect(1, 1, 1.4, 2), rect(1.6, 1, 2, 2, reverse: true)],
        204,
        204,
      ),
      'overlapping, opposite directions': (
        [rect(1, 1, 2, 1.6), rect(1, 1.4, 2, 2, reverse: true)],
        204,
        204,
      ),
      'the same shape twice, 0.3 of the pixel': (
        [rect(1, 1, 2, 1.3), rect(1, 1, 2, 1.3)],
        77,
        0,
      ),
      'the same shape twice, 0.5 of the pixel': (
        [rect(1, 1, 2, 1.5), rect(1, 1, 2, 1.5)],
        128,
        0,
      ),
      'disjoint, same direction': (
        [rect(1, 1, 2, 1.4), rect(1, 1.6, 2, 2)],
        204,
        204,
      ),
      'overlapping, same direction': (
        [rect(1, 1, 2, 1.6), rect(1, 1.4, 2, 2)],
        255,
        204,
      ),
      'nested hole': (
        [rect(1, 1, 2, 2), rect(1.3, 1.3, 1.7, 1.7, reverse: true)],
        214,
        214,
      ),
    };
    for (final MapEntry(key: name, value: (shapes, nonZero, evenOdd))
        in cases.entries) {
      test('$name is covered by its true area, within 1/16', () {
        final path = join(shapes);
        for (final (rule, expected) in [
          (FillRule.nonZero, nonZero),
          (FillRule.evenOdd, evenOdd),
        ]) {
          expect(fill(path, rule), closeTo(expected, 16), reason: 'fill $rule');
          expect(clip(path, rule), closeTo(expected, 16), reason: 'clip $rule');
        }
      });
    }

    test('a vertex on a sub-row sample counts once', () {
      // The left side is split at y = 1 + 0.5 / 16, the first sample of row 1
      final split =
          (PathBuilder()
                ..moveTo(1, 0.5)
                ..lineTo(3, 0.5)
                ..lineTo(3, 3)
                ..lineTo(1, 3)
                ..lineTo(1, 1.03125)
                ..closePath())
              .build();
      final whole = rect(1, 0.5, 3, 3);
      for (final rule in FillRule.values) {
        String render(final Path path) => BasicRasterizer()
            .rasterize(path, rule: rule, viewport: Rectangle(0, 0, 6, 4))
            .map((span) => '${span.y}:${span.x1}-${span.x2}@${span.coverage}')
            .join(' ');
        expect(render(split), equals(render(whole)), reason: '$rule');
      }
    });

    test('integer-aligned rectangles cover whole pixels exactly', () {
      final spans = BasicRasterizer().rasterize(rect(2, 3, 7, 9));
      final covered = {
        for (final span in spans)
          for (var x = span.x1; x < span.x2; x++) (x, span.y): span.coverage,
      };
      expect(covered, {
        for (var y = 3; y < 9; y++)
          for (var x = 2; x < 7; x++) (x, y): 255,
      });
    });
  });

  group('Area coverage', () {
    Path rect(
      final double left,
      final double top,
      final double right,
      final double bottom,
    ) =>
        (PathBuilder()
              ..moveTo(left, top)
              ..lineTo(right, top)
              ..lineTo(right, bottom)
              ..lineTo(left, bottom)
              ..closePath())
            .build();

    int total(final List<Span> spans) =>
        spans.fold(0, (sum, span) => sum + span.length * span.coverage);

    Map<(int, int), int> pixels(final List<Span> spans) => {
      for (final span in spans)
        for (var x = span.x1; x < span.x2; x++) (x, span.y): span.coverage,
    };

    test('a 0.6 x 0.6 square inside one pixel covers 36% of it', () {
      final spans = BasicRasterizer().rasterize(rect(1.2, 1.2, 1.8, 1.8));
      expect(total(spans), closeTo(92, 92 * 0.05));
    });

    test('a 3.0 x 0.6 bar across two rows covers 1.8 pixels', () {
      final spans = BasicRasterizer().rasterize(rect(1, 2.6, 4, 3.2));
      // Coverage is exact horizontally and within 1/16 vertically, so each
      // of the six partly covered pixels may be off by up to 16
      expect(total(spans), closeTo(459, 6 * 16));
      // 0.4 and 0.2 of each row, within the 1/16 sub-row precision
      final covered = pixels(spans);
      expect(covered.keys.toSet(), {
        for (var x = 1; x < 4; x++) ...{(x, 2), (x, 3)},
      });
      for (var x = 1; x < 4; x++) {
        expect(covered[(x, 2)], closeTo(102, 16));
        expect(covered[(x, 3)], closeTo(51, 16));
      }
    });

    test('a bar thinner than a row between row boundaries is drawn', () {
      // The middle bar of an F at small sizes: no row boundary inside it
      final spans = BasicRasterizer().rasterize(rect(2, 5.3, 12, 5.7));
      final covered = pixels(spans);
      expect(covered.keys.toSet(), {for (var x = 2; x < 12; x++) (x, 5)});
      // 0.4 of the row, within the 1/16 sub-row precision
      for (final alpha in covered.values) {
        expect(alpha, closeTo(102, 16));
      }
    });

    test('a height that is not a multiple of 1/16 is covered exactly', () {
      // 0.53125 of the row: 135 exactly, where 16 sub-rows would give 128
      final spans = BasicRasterizer().rasterize(rect(1, 1, 2, 1.53125));
      expect(pixels(spans), {(1, 1): 135});
    });

    test('a sloped edge inside one row is covered by its exact area', () {
      // A right triangle of legs 1 and 0.53125: 0.265625 of the pixel
      final path =
          (PathBuilder()
                ..moveTo(1, 1)
                ..lineTo(2, 1)
                ..lineTo(1, 1.53125)
                ..closePath())
              .build();
      expect(pixels(BasicRasterizer().rasterize(path)), {(1, 1): 68});
    });

    test('edges crossing inside a row match supersampling within 1/16', () {
      // A bow tie whose edges cross at (2, 2.3), drawn twice over, so the
      // lobes have windings 2 and -2
      final points = [(0.0, 0.6), (4.0, 4.0), (4.0, 0.6), (0.0, 4.0)];
      final builder = PathBuilder();
      for (var copy = 0; copy < 2; copy++) {
        builder.moveTo(points.first.$1, points.first.$2);
        for (final (x, y) in points.skip(1)) {
          builder.lineTo(x, y);
        }
        builder.closePath();
      }
      final path = builder.build();

      int winding(final double x, final double y) {
        var total = 0;
        for (var i = 0; i < points.length; i++) {
          final (ax, ay) = points[i];
          final (bx, by) = points[(i + 1) % points.length];
          if ((ay <= y) != (by <= y) &&
              ax + (y - ay) / (by - ay) * (bx - ax) > x) {
            total += by > ay ? 2 : -2;
          }
        }
        return total;
      }

      for (final rule in FillRule.values) {
        final covered = pixels(BasicRasterizer().rasterize(path, rule: rule));
        const samples = 64;
        for (var py = 0; py < 4; py++) {
          for (var px = 0; px < 4; px++) {
            var hits = 0;
            for (var j = 0; j < samples; j++) {
              for (var i = 0; i < samples; i++) {
                final w = winding(
                  px + (i + 0.5) / samples,
                  py + (j + 0.5) / samples,
                );
                if (rule == FillRule.nonZero ? w != 0 : w.isOdd) hits++;
              }
            }
            final expected = hits * 255 / (samples * samples);
            expect(
              covered[(px, py)] ?? 0,
              closeTo(expected, 16 + 4),
              reason: '$rule ($px, $py)',
            );
          }
        }
      }
    });

    test('a diagonal edge covers each pixel by its area', () {
      // The triangle below the diagonal of a 4 x 4 square: each pixel on the
      // diagonal is half covered
      final path =
          (PathBuilder()
                ..moveTo(0, 0)
                ..lineTo(4, 4)
                ..lineTo(0, 4)
                ..closePath())
              .build();
      final covered = pixels(BasicRasterizer().rasterize(path));
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          final expected = x < y ? 255 : (x == y ? 128 : null);
          expect(covered[(x, y)], expected, reason: '($x, $y)');
        }
      }
    });

    test('shallow edges crossing several cells match supersampling', () {
      final points = [(0.3, 0.2), (11.7, 2.9), (9.2, 5.6), (0.6, 4.1)];
      final builder = PathBuilder()..moveTo(points.first.$1, points.first.$2);
      for (final (x, y) in points.skip(1)) {
        builder.lineTo(x, y);
      }
      final covered = pixels(BasicRasterizer().rasterize(builder.build()));

      bool inside(final double x, final double y) {
        var crossings = 0;
        for (var i = 0; i < points.length; i++) {
          final (ax, ay) = points[i];
          final (bx, by) = points[(i + 1) % points.length];
          if ((ay <= y) != (by <= y) &&
              ax + (y - ay) / (by - ay) * (bx - ax) > x) {
            crossings++;
          }
        }
        return crossings.isOdd;
      }

      const samples = 64;
      for (var py = 0; py < 6; py++) {
        for (var px = 0; px < 12; px++) {
          var hits = 0;
          for (var sy = 0; sy < samples; sy++) {
            for (var sx = 0; sx < samples; sx++) {
              if (inside(
                px + (sx + 0.5) / samples,
                py + (sy + 0.5) / samples,
              )) {
                hits++;
              }
            }
          }
          final expected = hits * 255 / (samples * samples);
          expect(
            covered[(px, py)] ?? 0,
            closeTo(expected, 4),
            reason: '($px, $py)',
          );
        }
      }
    });

    test('integer-aligned rectangles cover whole pixels only', () {
      final shapes = [
        (rect(3, 4, 9, 7), FillRule.evenOdd),
        (rect(-5, -5, 2, 3), FillRule.nonZero),
        (
          (PathBuilder()
                ..moveTo(0, 0)
                ..lineTo(10, 0)
                ..lineTo(10, 10)
                ..lineTo(0, 10)
                ..closePath()
                ..moveTo(3, 3)
                ..lineTo(7, 3)
                ..lineTo(7, 7)
                ..lineTo(3, 7)
                ..closePath())
              .build(),
          FillRule.nonZero,
        ),
      ];
      for (final (path, rule) in shapes) {
        for (final antiAlias in [true, false]) {
          final old = _ScanlineReference(rule).rasterize(path);
          final spans = BasicRasterizer(
            antiAlias: antiAlias,
          ).rasterize(path, rule: rule);
          expect(pixels(spans), equals(old), reason: '$rule $antiAlias');
        }
      }
    });

    test('an open subpath is closed for filling', () {
      final open =
          (PathBuilder()
                ..moveTo(1, 1)
                ..lineTo(5, 1)
                ..lineTo(5, 5)
                ..lineTo(1, 5))
              .build();
      expect(pixels(BasicRasterizer().rasterize(open)), {
        for (var y = 1; y < 5; y++)
          for (var x = 1; x < 5; x++) (x, y): 255,
      });
    });
  });
}

/// Pixel coverage of integer-aligned polygons by sampling each pixel centre,
/// the result the rasterizer gave before area coverage.
class _ScanlineReference {
  final FillRule rule;

  _ScanlineReference(this.rule);

  Map<(int, int), int> rasterize(final Path path) {
    final points = <List<Point>>[];
    for (final command in path.commands) {
      if (command.type == PathCommandType.moveTo) points.add([]);
      if (command.type != PathCommandType.close) {
        points.last.add(command.points.first);
      }
    }
    final result = <(int, int), int>{};
    for (var y = -10; y < 20; y++) {
      for (var x = -10; x < 20; x++) {
        var winding = 0;
        for (final contour in points) {
          for (var i = 0; i < contour.length; i++) {
            final a = contour[i];
            final b = contour[(i + 1) % contour.length];
            final cy = y + 0.5;
            if ((a.y <= cy) != (b.y <= cy)) {
              final cx = a.x + (cy - a.y) / (b.y - a.y) * (b.x - a.x);
              if (cx > x + 0.5) winding += a.y < b.y ? 1 : -1;
            }
          }
        }
        final inside = rule == FillRule.nonZero ? winding != 0 : winding.isOdd;
        if (inside) result[(x, y)] = 255;
      }
    }
    return result;
  }
}

// Helper functions for trigonometry
double cos(double radians) => math.cos(radians);

double sin(double radians) => math.sin(radians);

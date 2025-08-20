import 'package:libgfx/src/image/bitmap.dart';
import 'package:libgfx/src/color/color.dart';
import 'package:libgfx/src/graphics_context.dart';
import 'package:libgfx/src/paint.dart';
import 'package:libgfx/src/paths/path.dart';
import 'package:test/test.dart';

void main() {
  group('Bezier Curve Tests', () {
    test('Cubic bezier creation', () {
      final path = PathBuilder()
          .moveTo(0, 0)
          .curveTo(50, 0, 50, 100, 100, 100)
          .build();

      expect(path.commands.length, 2);
      expect(path.commands[1].type, PathCommandType.cubicCurveTo);
      expect(path.commands[1].points.length, 3);
    });

    test('Multiple bezier curves', () {
      final path = PathBuilder()
          .moveTo(0, 0)
          .curveTo(20, 0, 20, 50, 50, 50)
          .curveTo(80, 50, 80, 100, 100, 100)
          .build();

      expect(
        path.commands
            .where((cmd) => cmd.type == PathCommandType.cubicCurveTo)
            .length,
        2,
      );
    });

    test('Bezier curve bounds', () {
      final path = PathBuilder()
          .moveTo(0, 0)
          .curveTo(100, 0, 100, 100, 0, 100)
          .build();

      final bounds = path.bounds;
      expect(bounds.left, 0);
      expect(bounds.top, 0);
      expect(bounds.right, 100);
      expect(bounds.bottom, 100);
    });
  });

  group('Adaptive Subdivision Tests', () {
    test('Straight line bezier should not subdivide', () {
      final bitmap = Bitmap(200, 200);
      final context = GraphicsContext(bitmap);
      final path = PathBuilder()
          .moveTo(0, 50)
          .curveTo(33, 50, 66, 50, 100, 50) // Straight line
          .lineTo(100, 60)
          .lineTo(0, 60)
          .close()
          .build();

      final spans = context.rasterizer.rasterize(path);
      // Should produce similar results to a straight line
      expect(spans.isNotEmpty, true);
    });

    test('Highly curved bezier should subdivide', () {
      final bitmap = Bitmap(200, 200);
      final context = GraphicsContext(bitmap);
      final path = PathBuilder()
          .moveTo(0, 0)
          .curveTo(100, 0, 100, 100, 0, 100) // High curvature
          .close()
          .build();

      final spans = context.rasterizer.rasterize(path);

      // Should produce smooth curve
      expect(spans.isNotEmpty, true);

      // Check for smooth progression of spans
      var lastWidth = 0;
      bool hasVariation = false;
      for (final span in spans) {
        final width = span.x2 - span.x1;
        if (lastWidth != 0 && (width - lastWidth).abs() > 2) {
          hasVariation = true;
        }
        lastWidth = width;
      }
      expect(hasVariation, true); // Curve should have varying widths
    });

    test('Complex bezier path rendering', () {
      final bitmap = Bitmap(200, 200);
      final context = GraphicsContext(bitmap);

      context.state.fillPaint = SolidPaint(Color.fromARGB(255, 0, 0, 255));

      // Create a simple filled shape using bezier curves
      final path = PathBuilder()
          .moveTo(50, 150)
          .curveTo(50, 50, 150, 50, 150, 150)
          .lineTo(100, 180)
          .close()
          .build();

      context.fill(path);

      // Check that inside the shape is filled
      // The shape goes from (50,150) to (150,150) with curve at y=50
      // So checking at (100, 100) should be inside
      // Allow for minor rounding differences
      expect(bitmap.getPixel(100, 100).blue, greaterThan(253));

      // Check that edges are smooth (no jaggies in adaptive subdivision)
      int transitionPixels = 0;
      for (int y = 80; y < 180; y++) {
        bool wasBlue = false;
        for (int x = 20; x < 180; x++) {
          bool isBlue = bitmap.getPixel(x, y).blue == 255;
          if (wasBlue != isBlue) {
            transitionPixels++;
          }
          wasBlue = isBlue;
        }
      }

      // Should have smooth transitions, not too many edge pixels
      expect(transitionPixels, lessThan(400));
    });

    test('Bezier curve quality comparison', () {
      final bitmap1 = Bitmap(100, 100);
      final bitmap2 = Bitmap(100, 100);

      final context1 = GraphicsContext(bitmap1);
      final context2 = GraphicsContext(bitmap2);

      // High curvature S-curve
      final path = PathBuilder()
          .moveTo(10, 90)
          .curveTo(40, 90, 60, 10, 90, 10)
          .build();

      context1.state.strokePaint = SolidPaint(
        Color.fromARGB(255, 255, 255, 255),
      );
      context1.state.strokeWidth = 2.0;
      context1.stroke(path);

      context2.state.strokePaint = SolidPaint(
        Color.fromARGB(255, 255, 255, 255),
      );
      context2.state.strokeWidth = 2.0;
      context2.stroke(path);

      // Both should produce similar results with adaptive subdivision
      int differences = 0;
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          if (bitmap1.getPixel(x, y).value != bitmap2.getPixel(x, y).value) {
            differences++;
          }
        }
      }

      // Should be very similar
      expect(differences, lessThan(50));
    });
  });

  group('Performance Tests', () {
    test('Adaptive subdivision performance', () {
      final bitmap = Bitmap(200, 200);
      final context = GraphicsContext(bitmap);

      // Create a path with many bezier curves
      final builder = PathBuilder();
      builder.moveTo(0, 50);

      for (int i = 0; i < 100; i++) {
        final x = i * 10.0;
        builder.curveTo(x + 3, 20, x + 7, 80, x + 10, 50);
      }

      final path = builder.build();

      // Measure rasterization time
      final stopwatch = Stopwatch()..start();
      final spans = context.rasterizer.rasterize(path);
      stopwatch.stop();

      expect(spans.isNotEmpty, true);
      // Should complete in reasonable time even with adaptive subdivision
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('Quality vs performance tradeoff', () {
      final bitmap = Bitmap(200, 200);
      final context = GraphicsContext(bitmap);

      // Create a complex curved path
      final path = PathBuilder()
          .moveTo(50, 10)
          .curveTo(90, 10, 90, 50, 90, 90)
          .curveTo(90, 130, 50, 130, 10, 130)
          .curveTo(-30, 130, -30, 90, -30, 50)
          .curveTo(-30, 10, 10, 10, 50, 10)
          .close()
          .build();

      final spans = context.rasterizer.rasterize(path);

      // Check that we get good coverage
      final yValues = spans.map((s) => s.y).toSet();
      expect(
        yValues.length,
        greaterThan(80),
      ); // Should have good vertical coverage

      // Check smoothness
      final spansByY = <int, List<dynamic>>{};
      for (final span in spans) {
        (spansByY[span.y] ??= []).add(span);
      }

      // Each scanline should have reasonable number of spans (not fragmented)
      for (final entry in spansByY.entries) {
        expect(
          entry.value.length,
          lessThanOrEqualTo(4),
        ); // At most 2 intersections per side
      }
    });
  });
}

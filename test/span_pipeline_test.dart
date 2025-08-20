import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/graphics_context.dart';
import 'package:libgfx/src/spans/span.dart';
import 'package:libgfx/src/spans/span_clipper.dart';
import 'package:libgfx/src/spans/span_merger.dart';
import 'package:libgfx/src/spans/span_optimizer.dart';
import 'package:libgfx/src/spans/span_pipeline.dart';
import 'package:test/test.dart';

void main() {
  group('SpanPipeline', () {
    late Bitmap bitmap;
    late SpanPipeline pipeline;
    late GraphicsContext context;

    setUp(() {
      bitmap = Bitmap(100, 100);
      pipeline = SpanPipeline.createStandard(bitmap);
      context = GraphicsContext(bitmap);
    });

    test('ViewportClipper clips spans outside bounds', () {
      final clipper = SpanClipper(100, 100);

      final spans = [
        Span(10, 20, 30), // Inside
        Span(150, 10, 20), // Outside Y
        Span(50, -10, 30), // Partially outside X (left)
        Span(50, 90, 30), // Partially outside X (right)
      ];

      final clipped = clipper.process(spans);

      expect(clipped.length, 3);
      expect(clipped[0].y, 10);
      expect(clipped[1].x, 0);
      expect(clipped[1].length, 20);
      expect(clipped[2].x, 90);
      expect(clipped[2].length, 10);
    });

    test('SpanMerger merges overlapping spans', () {
      final merger = SpanMerger();

      final spans = [
        Span(10, 20, 30), // 20-50
        Span(10, 40, 30), // 40-70 (overlaps)
        Span(10, 80, 20), // 80-100 (separate)
        Span(20, 10, 20), // Different scanline
      ];

      final merged = merger.process(spans);

      expect(merged.length, 3);
      // First two spans on line 10 should be merged
      expect(merged.where((s) => s.y == 10).length, 2);
      expect(merged.where((s) => s.y == 20).length, 1);
    });

    test('SpanOptimizer combines adjacent full-coverage spans', () {
      final optimizer = SpanOptimizer();

      final spans = [
        Span(10, 20, 10, 255), // Full coverage
        Span(10, 30, 10, 255), // Adjacent, full coverage
        Span(10, 40, 10, 128), // Adjacent, partial coverage
        Span(10, 50, 10, 255), // Non-adjacent, full coverage
      ];

      final optimized = optimizer.process(spans);

      expect(optimized.length, 3);
      // First two should be combined
      expect(optimized[0].x, 20);
      expect(optimized[0].length, 20);
      expect(optimized[0].coverage, 255);
    });

    test('Pipeline processes spans through all stages', () {
      // Create a simple rectangle
      final path = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(50, 10)
        ..lineTo(50, 50)
        ..lineTo(10, 50)
        ..close();

      final spans = context.rasterizer.rasterize(path.build());
      final processed = pipeline.process(spans);

      // Spans should be clipped, merged, and optimized
      expect(processed, isNotEmpty);

      // All spans should be within bounds
      for (final span in processed) {
        expect(span.y, greaterThanOrEqualTo(0));
        expect(span.y, lessThan(100));
        expect(span.x, greaterThanOrEqualTo(0));
        expect(span.x2, lessThanOrEqualTo(100));
      }
    });

    test('Pipeline renders spans to bitmap', () {
      final path = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(30, 10)
        ..lineTo(30, 30)
        ..lineTo(10, 30)
        ..close();

      final spans = context.rasterizer.rasterize(path.build());
      final processed = pipeline.process(spans);

      final paint = SolidPaint(Color.fromRGBA(255, 0, 0, 255));
      final transform = Matrix2D.identity();

      pipeline.render(processed, paint, transform, BlendMode.srcOver);

      // Check that pixels were rendered
      // Note: Y-flip means graphics y=10 -> bitmap y=89
      final bitmapY = 89;
      final pixel = bitmap.getPixel(15, bitmapY);
      expect(pixel.red, 255);
      expect(pixel.green, 0);
      expect(pixel.blue, 0);
    });
  });
}

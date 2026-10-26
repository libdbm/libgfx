import 'dart:math';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/graphics_context.dart';
import 'package:libgfx/src/spans/span.dart';
import 'package:libgfx/src/spans/span_clipper.dart';
import 'package:libgfx/src/spans/span_merger.dart';
import 'package:libgfx/src/spans/span_optimizer.dart';
import 'package:libgfx/src/spans/span_pipeline.dart';
import 'package:libgfx/src/spans/span_processor.dart';
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
        ..closePath();

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
        ..closePath();

      final spans = context.rasterizer.rasterize(path.build());
      final processed = pipeline.process(spans);

      final paint = Color.fromRGBA(255, 0, 0, 255);
      final transform = Matrix2D.identity();

      pipeline.render(processed, paint, transform, BlendMode.srcOver);

      // Check that pixels were rendered
      // Note: Y-flip means graphics y=10 -> bitmap y=89
      final bitmapY = 89;
      final pixel = bitmap.pixel(15, bitmapY);
      expect(pixel.red, 255);
      expect(pixel.green, 0);
      expect(pixel.blue, 0);
    });

    test('Pipeline runs processors on sorted, non-overlapping spans', () {
      final counter = _CountingProcessor();
      final custom = SpanPipeline(bitmap)..addProcessor(counter);

      custom.process([Span(0, 0, 5), Span(1, 0, 5)]);

      expect(counter.calls, equals(1));
    });

    test('Pipeline clips sorted, non-overlapping spans to the bitmap', () {
      final processed = pipeline.process([Span(0, -10, 100), Span(150, 0, 2)]);

      expect(processed, isNotEmpty);
      for (final span in processed) {
        expect(span.y, inInclusiveRange(0, 99));
        expect(span.x, greaterThanOrEqualTo(0));
        expect(span.x2, lessThanOrEqualTo(100));
      }
    });
  });

  group('Span merging', () {
    String describe(final List<Span> spans) => spans
        .map((span) => '${span.x}+${span.length}@${span.coverage}')
        .join(' ');

    test('matches the boundary-by-span merge on random overlapping spans', () {
      final random = Random(5);
      for (var trial = 0; trial < 2000; trial++) {
        final count = 2 + random.nextInt(14);
        final spans = [
          for (var i = 0; i < count; i++)
            Span(
              7,
              random.nextInt(40),
              // Some empty spans, and many partial coverages
              random.nextInt(6) == 0 ? 0 : 1 + random.nextInt(20),
              random.nextInt(4) == 0 ? 255 : random.nextInt(256),
            ),
        ];
        // The merger is given spans sorted by x, as the pipeline does
        if (trial.isEven) spans.sort((a, b) => a.x.compareTo(b.x));
        expect(
          describe(SpanMerger.mergeScanlineSpans(spans, 7)),
          equals(describe(_merge(spans, 7))),
          reason: 'trial $trial: ${describe(spans)}',
        );
      }
    });

    test('a long chain of overlapping spans merges into one run', () {
      final spans = [for (var i = 0; i < 20000; i++) Span(0, i, 3, 100)];
      final merged = SpanMerger.mergeScanlineSpans(spans, 0);
      expect(merged.first.x, equals(0));
      expect(merged.last.x2, equals(20002));
    });
  });
}

/// Counts how often the pipeline invokes it.
class _CountingProcessor implements SpanProcessor {
  int calls = 0;

  @override
  List<Span> process(List<Span> spans) {
    calls++;
    return spans;
  }
}

/// The merge as it was written: for each pair of adjacent boundaries,
/// composite every span covering the left boundary. The reference for the
/// sweep.
List<Span> _merge(final List<Span> lineSpans, final int y) {
  if (lineSpans.isEmpty) return [];
  if (lineSpans.length == 1) return lineSpans;
  var overlaps = false;
  for (var i = 0; i < lineSpans.length - 1; i++) {
    if (lineSpans[i].x2 > lineSpans[i + 1].x1) {
      overlaps = true;
      break;
    }
  }
  if (!overlaps) return lineSpans;
  final boundaries = <int>{
    for (final span in lineSpans) ...[span.x1, span.x2],
  }.toList()..sort();
  final merged = <Span>[];
  for (var i = 0; i < boundaries.length - 1; i++) {
    final x1 = boundaries[i];
    final x2 = boundaries[i + 1];
    var combined = 0.0;
    for (final span in lineSpans) {
      if (x1 >= span.x1 && x1 < span.x2) {
        final alpha = span.coverage / 255.0;
        combined = alpha + combined * (1.0 - alpha);
      }
    }
    if (combined > 0.0) {
      final coverage = (combined * 255).round().clamp(0, 255);
      if (merged.isNotEmpty &&
          merged.last.x2 == x1 &&
          merged.last.coverage == coverage) {
        final previous = merged.removeLast();
        merged.add(Span(y, previous.x1, x2 - previous.x1, coverage));
      } else {
        merged.add(Span(y, x1, x2 - x1, coverage));
      }
    }
  }
  return merged;
}

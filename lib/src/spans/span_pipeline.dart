import '../image/bitmap.dart';
import '../graphics_state.dart';
import '../matrix.dart';
import '../paint.dart';
import 'span.dart';

import 'span_processor.dart';
import 'span_merger.dart';
import 'span_optimizer.dart';
import 'span_clipper.dart';

/// The main span-based rendering pipeline
class SpanPipeline {
  final List<SpanProcessor> processors = [];
  final Bitmap targetBitmap;

  SpanPipeline(this.targetBitmap);

  /// Add a processor to the pipeline
  void addProcessor(SpanProcessor processor) {
    processors.add(processor);
  }

  /// Process spans through the pipeline
  List<Span> process(List<Span> spans) {
    // Fast path: skip processing if spans are simple and non-overlapping
    if (_canSkipProcessing(spans)) {
      return spans;
    }

    var processedSpans = spans;

    for (final processor in processors) {
      processedSpans = processor.process(processedSpans);
    }

    return processedSpans;
  }

  /// Check if spans are simple enough to skip pipeline processing
  bool _canSkipProcessing(List<Span> spans) {
    if (spans.isEmpty || processors.isEmpty) return true;
    if (spans.length > 500) return false; // Too many to check quickly

    // Check if spans are non-overlapping and properly ordered
    int prevY = -1;
    int prevX2 = -1;

    for (final span in spans) {
      if (span.y < prevY) return false; // Not sorted by Y
      if (span.y == prevY && span.x1 < prevX2) return false; // Overlapping

      prevY = span.y;
      prevX2 = span.y == prevY ? span.x2 : -1;
    }

    return true;
  }

  /// Render spans to the bitmap
  void render(
    List<Span> spans,
    Paint paint,
    Matrix2D inverseTransform,
    BlendMode blendMode, {
    double globalAlpha = 1.0,
  }) {
    for (final span in spans) {
      // Apply Y-flip here: graphics Y -> bitmap Y
      final bitmapY = targetBitmap.height - 1 - span.y;
      if (bitmapY >= 0 && bitmapY < targetBitmap.height) {
        // Apply global alpha to coverage
        final adjustedCoverage = (span.coverage * globalAlpha).round().clamp(
          0,
          255,
        );

        // Use anti-aliased drawing if coverage is less than full
        if (adjustedCoverage < 255) {
          targetBitmap.drawAntiAliasedSpan(
            span.x,
            span.length,
            bitmapY,
            adjustedCoverage,
            paint,
            inverseTransform,
            blendMode,
          );
        } else if (globalAlpha < 1.0) {
          // Even for full coverage spans, apply alpha if less than 1
          targetBitmap.drawAntiAliasedSpan(
            span.x,
            span.length,
            bitmapY,
            (255 * globalAlpha).round(),
            paint,
            inverseTransform,
            blendMode,
          );
        } else {
          targetBitmap.drawHorizontalSpan(
            span.x1,
            span.x2,
            bitmapY,
            paint,
            inverseTransform,
            blendMode,
          );
        }
      }
    }
  }

  /// Create a standard pipeline with common processors
  static SpanPipeline createStandard(Bitmap bitmap) {
    final pipeline = SpanPipeline(bitmap);
    pipeline.addProcessor(SpanClipper(bitmap.width, bitmap.height));
    pipeline.addProcessor(SpanMerger());
    pipeline.addProcessor(SpanOptimizer());
    return pipeline;
  }
}

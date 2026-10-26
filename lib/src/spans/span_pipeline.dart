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
    var result = spans;

    for (final processor in processors) {
      result = processor.process(result);
    }

    return result;
  }

  /// Render spans to the bitmap
  void render(
    List<Span> spans,
    Paint paint,
    final Matrix2D inverse,
    final BlendMode mode, {
    double globalAlpha = 1.0,
  }) {
    // The bitmap samples paints at integer bitmap coordinates; map them to
    // the graphics-space centre of the pixel, undoing the Y-flip, so paints
    // are evaluated where the pixel actually is.
    final sampling =
        inverse * Matrix2D(1, 0, 0, -1, 0.5, targetBitmap.height - 0.5);
    for (final span in spans) {
      // Apply Y-flip here: graphics Y -> bitmap Y
      final row = targetBitmap.height - 1 - span.y;
      if (row >= 0 && row < targetBitmap.height) {
        // Global alpha scales the source; coverage masks the result
        if (span.coverage < 255 || globalAlpha < 1.0) {
          targetBitmap.shade(
            span.x,
            span.length,
            row,
            span.coverage,
            paint,
            sampling,
            mode,
            alpha: globalAlpha,
          );
        } else {
          targetBitmap.span(span.x1, span.x2, row, paint, sampling, mode);
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

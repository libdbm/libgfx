import 'dart:math' as math;

import 'span.dart';
import 'span_processor.dart';

/// Clips spans to viewport bounds
class SpanClipper extends SpanProcessor {
  final int width;
  final int height;

  SpanClipper(this.width, this.height);

  @override
  List<Span> process(List<Span> spans) {
    final result = <Span>[];

    for (final span in spans) {
      final clipped = _clip(span, 0, width, 0, height);
      if (clipped != null) {
        result.add(clipped);
      }
    }

    return result;
  }

  /// Clip a span to viewport bounds
  Span? _clip(Span span, int minX, int maxX, int minY, int maxY) {
    // Check if span is outside viewport vertically
    if (span.y < minY || span.y >= maxY) return null;

    // Clip horizontally
    final x1 = math.max(span.x1, minX);
    final x2 = math.min(span.x2, maxX);

    if (x1 >= x2) return null;

    return Span(span.y, x1, x2 - x1, span.coverage);
  }
}

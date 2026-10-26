import 'span.dart';
import 'span_processor.dart';
import 'span_utils.dart';

/// Optimizes spans by combining adjacent spans with same coverage
class SpanOptimizer extends SpanProcessor {
  @override
  List<Span> process(List<Span> spans) {
    return SpanUtils.processByScanline(spans, (y, line) {
      if (line.isEmpty) return [];
      if (line.length == 1) return line;

      final optimized = <Span>[];
      Span? current;

      for (final span in line) {
        if (current == null) {
          current = span;
        } else if (current.x2 == span.x1 && current.coverage == span.coverage) {
          // Adjacent spans with same coverage - combine them
          current = Span(
            y,
            current.x1,
            current.length + span.length,
            current.coverage,
          );
        } else {
          // Can't combine - output current and start new
          optimized.add(current);
          current = span;
        }
      }

      // Add the last span
      if (current != null) {
        optimized.add(current);
      }

      return optimized;
    });
  }
}

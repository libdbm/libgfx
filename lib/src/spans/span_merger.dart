import 'span.dart';
import 'span_utils.dart';

import 'span_processor.dart';

/// Merges overlapping spans on the same scanline using interval-based approach
/// Handles anti-aliasing coverage properly
class SpanMerger extends SpanProcessor {
  @override
  List<Span> process(List<Span> spans) {
    return SpanUtils.processByScanline(spans, (y, line) {
      return mergeScanlineSpans(line, y);
    });
  }

  /// Merge spans on a single scanline using interval-based approach
  /// This is the core merging algorithm that handles overlapping spans with proper coverage compositing
  static List<Span> mergeScanlineSpans(final List<Span> spans, int y) {
    if (spans.isEmpty) return [];
    if (spans.length == 1) return spans;

    // Quick check for non-overlapping spans (common case for simple shapes)
    bool overlaps = false;
    for (int i = 0; i < spans.length - 1; i++) {
      if (spans[i].x2 > spans[i + 1].x1) {
        overlaps = true;
        break;
      }
    }
    if (!overlaps) return spans;

    // Sweep the boundaries left to right, keeping the spans that cover the
    // current segment. Each segment composites its spans in input order, so
    // the result rounds exactly as compositing every span would
    final boundaries = <int>{
      for (final span in spans) ...[span.x1, span.x2],
    }.toList()..sort();
    final alphas = [for (final span in spans) span.coverage / 255.0];
    // Spans that cover at least one pixel, by start and by end
    final covering = [
      for (int i = 0; i < spans.length; i++)
        if (spans[i].x1 < spans[i].x2) i,
    ];
    final starts = [...covering]
      ..sort((a, b) => spans[a].x1.compareTo(spans[b].x1));
    final ends = [...covering]
      ..sort((a, b) => spans[a].x2.compareTo(spans[b].x2));
    final active = <int>[]; // input indices, ascending
    int next = 0; // next span in starts
    int done = 0; // next span in ends

    final merged = <Span>[];
    for (int i = 0; i < boundaries.length - 1; i++) {
      final x1 = boundaries[i];
      final x2 = boundaries[i + 1];
      while (done < ends.length && spans[ends[done]].x2 <= x1) {
        active.remove(ends[done++]);
      }
      while (next < starts.length && spans[starts[next]].x1 <= x1) {
        final index = starts[next++];
        active.insert(_position(active, index), index);
      }

      // Composite using "over" operator: result = src + dst * (1 - src)
      double combined = 0.0;
      for (final index in active) {
        final alpha = alphas[index];
        combined = alpha + combined * (1.0 - alpha);
      }

      // Create span if there's coverage
      if (combined > 0.0) {
        final coverage = (combined * 255).round().clamp(0, 255);

        // Try to extend the previous span if coverage matches
        if (merged.isNotEmpty &&
            merged.last.x2 == x1 &&
            merged.last.coverage == coverage) {
          // Extend the previous span
          final previous = merged.removeLast();
          merged.add(Span(y, previous.x1, (x2 - previous.x1), coverage));
        } else {
          // Create new span
          merged.add(Span(y, x1, x2 - x1, coverage));
        }
      }
    }

    return merged;
  }

  /// Where [index] belongs in the ascending list [active].
  static int _position(List<int> active, int index) {
    int low = 0;
    int high = active.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (active[middle] < index) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }
}

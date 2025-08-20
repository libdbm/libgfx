import 'span.dart';
import 'span_utils.dart';

import 'span_processor.dart';

/// Helper class for interval-based coverage tracking
class _CoverageInterval {
  final int start;
  final int end;
  final double alpha;

  _CoverageInterval(this.start, this.end, this.alpha);

  bool contains(int x) => x >= start && x < end;
}

/// Merges overlapping spans on the same scanline using interval-based approach
/// Handles anti-aliasing coverage properly
class SpanMerger extends SpanProcessor {
  @override
  List<Span> process(List<Span> spans) {
    return SpanUtils.processByScanline(spans, (y, lineSpans) {
      return mergeScanlineSpans(lineSpans, y);
    });
  }

  /// Merge spans on a single scanline using interval-based approach
  /// This is the core merging algorithm that handles overlapping spans with proper coverage compositing
  static List<Span> mergeScanlineSpans(List<Span> lineSpans, int y) {
    if (lineSpans.isEmpty) return [];
    if (lineSpans.length == 1) return lineSpans;

    // Use interval-based merging for efficiency
    final merged = <Span>[];
    final intervals = <_CoverageInterval>[];

    // Create intervals from spans with coverage events
    for (final span in lineSpans) {
      intervals.add(_CoverageInterval(span.x1, span.x2, span.coverage / 255.0));
    }

    // Find all unique x coordinates (interval boundaries)
    final boundaries = <int>{};
    for (final interval in intervals) {
      boundaries.add(interval.start);
      boundaries.add(interval.end);
    }
    final sortedBoundaries = boundaries.toList()..sort();

    // Process each interval between boundaries
    for (int i = 0; i < sortedBoundaries.length - 1; i++) {
      final x1 = sortedBoundaries[i];
      final x2 = sortedBoundaries[i + 1];

      // Calculate combined coverage for this interval
      double combinedAlpha = 0.0;
      for (final interval in intervals) {
        if (interval.contains(x1)) {
          // Composite using "over" operator: result = src + dst * (1 - src)
          combinedAlpha =
              interval.alpha + combinedAlpha * (1.0 - interval.alpha);
        }
      }

      // Create span if there's coverage
      if (combinedAlpha > 0.0) {
        final coverage = (combinedAlpha * 255).round().clamp(0, 255);

        // Try to extend the previous span if coverage matches
        if (merged.isNotEmpty &&
            merged.last.x2 == x1 &&
            merged.last.coverage == coverage) {
          // Extend the previous span
          final prev = merged.removeLast();
          merged.add(Span(y, prev.x1, (x2 - prev.x1), coverage));
        } else {
          // Create new span
          merged.add(Span(y, x1, x2 - x1, coverage));
        }
      }
    }

    return merged;
  }

  /// Merge two individual spans (simplified merge for two spans)
  /// Returns a list of spans since merging may result in multiple non-contiguous spans
  static List<Span> mergeSpans(Span span1, Span span2) {
    assert(span1.y == span2.y, 'Can only merge spans on the same scanline');

    // If spans don't overlap, return both
    if (span1.x2 <= span2.x1 || span2.x2 <= span1.x1) {
      return span1.x1 < span2.x1 ? [span1, span2] : [span2, span1];
    }

    // Use the full merge algorithm for overlapping spans
    return mergeScanlineSpans([span1, span2], span1.y);
  }
}

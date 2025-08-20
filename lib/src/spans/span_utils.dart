import 'span.dart';

/// Utilities for rendering operations including color and span manipulation
class SpanUtils {
  // Prevent instantiation
  SpanUtils._();

  /// Process spans by scanline
  static List<Span> processByScanline(
    List<Span> spans,
    List<Span> Function(int y, List<Span> lineSpans) processor,
  ) {
    final grouped = groupByScanline(spans);
    final result = <Span>[];

    for (final entry in grouped.entries) {
      result.addAll(processor(entry.key, entry.value));
    }

    return result;
  }

  /// Group spans by their Y coordinate (scanline)
  static Map<int, List<Span>> groupByScanline(List<Span> spans) {
    final groups = <int, List<Span>>{};

    for (final span in spans) {
      groups.putIfAbsent(span.y, () => []).add(span);
    }

    // Sort spans within each scanline by X coordinate
    for (final line in groups.values) {
      line.sort((a, b) => a.x1.compareTo(b.x1));
    }

    return groups;
  }
}

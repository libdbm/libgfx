import 'package:libgfx/src/spans/span.dart';
import 'package:libgfx/src/spans/span_merger.dart';

/// Times merging a chain of overlapping spans on one scanline. The cost
/// should grow roughly linearly with the number of spans. Run with
/// `dart run benchmark/span_merge.dart`.
void main() {
  for (final count in [2000, 4000, 8000, 16000]) {
    final spans = [for (var i = 0; i < count; i++) Span(0, i, 3, 100)];
    // Warm up, then time the median of a few runs
    SpanMerger.mergeScanlineSpans(spans, 0);
    final times = <int>[];
    for (var run = 0; run < 5; run++) {
      final watch = Stopwatch()..start();
      SpanMerger.mergeScanlineSpans(spans, 0);
      times.add(watch.elapsedMicroseconds);
    }
    times.sort();
    print(
      '${'$count spans'.padRight(12)} '
      '${(times[2] / 1000).toStringAsFixed(2).padLeft(9)} ms',
    );
  }
}

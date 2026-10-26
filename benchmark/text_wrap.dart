import 'dart:io';

import 'package:libgfx/libgfx.dart';

/// Times wrapping one long paragraph that fits on a single line. The cost
/// should grow linearly with the number of words: doubling the words should
/// roughly double the time. Run with `dart run benchmark/text_wrap.dart`.
void main() {
  final font =
      (TTFFont.fromBytes(
                File('test/fixtures/fonts/DejaVuSans.ttf').readAsBytesSync(),
              )
              as Ok<TTFFont, ErrorDetails>)
          .value;
  final engine = TextEngine(font: font, fontSize: 12);
  const vocabulary = [
    'the', 'quick', 'brown', 'fox', 'jumps', 'over', 'lazy', 'dog', //
    'Typography', 'Wave', 'AVATAR', 'kerning', 'layout', 'engine', 'path',
  ];

  for (final count in [1000, 2000, 4000]) {
    final text = [
      for (var i = 0; i < count; i++) vocabulary[i % vocabulary.length],
    ].join(' ');
    // Warm up, then time the median of a few runs
    engine.wrap(text, 1e9);
    final times = <int>[];
    for (var run = 0; run < 5; run++) {
      engine.purge();
      final watch = Stopwatch()..start();
      final lines = engine.wrap(text, 1e9);
      times.add(watch.elapsedMicroseconds);
      if (lines.length != 1) throw StateError('expected one line');
    }
    times.sort();
    print(
      '${'$count words'.padRight(12)} '
      '${(times[2] / 1000).toStringAsFixed(2).padLeft(8)} ms',
    );
  }
}

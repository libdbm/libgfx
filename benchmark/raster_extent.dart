import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/graphics_context.dart';
import 'package:libgfx/src/rasterize/implementations/basic_rasterizer.dart';

/// Times filling paths whose extent is far larger than the bitmap. The work
/// should depend on the bitmap size, not the path size: expect well under
/// 10 ms per fill. Run with `dart run benchmark/raster_extent.dart`.
void main() {
  final tall = _rectangle(0, -5e6, 4, 5e6);
  final wide = _rectangle(-5e6, 0, 5e6, 4);
  final context = GraphicsContext(Bitmap(4, 4));

  _measure('fill 4 x 1e7 on 4x4', () => context.fill(tall));
  _measure('fill 1e7 x 4 on 4x4', () => context.fill(wide));

  // For comparison: the same tall path without a viewport, timed once
  final watch = Stopwatch()..start();
  BasicRasterizer().rasterize(tall);
  print(
    '${'rasterize 4 x 1e7, no viewport'.padRight(36)} '
    '${(watch.elapsedMicroseconds / 1000).toStringAsFixed(2).padLeft(9)} ms',
  );
}

Path _rectangle(
  final double left,
  final double top,
  final double right,
  final double bottom,
) =>
    (PathBuilder()
          ..moveTo(left, top)
          ..lineTo(right, top)
          ..lineTo(right, bottom)
          ..lineTo(left, bottom)
          ..closePath())
        .build();

/// Runs [body] a few times to warm up, then [runs] times, and prints the
/// median wall-clock time.
void _measure(final String name, final void Function() body) {
  const warmup = 3;
  const runs = 20;
  for (var i = 0; i < warmup; i++) {
    body();
  }
  final times = <int>[];
  for (var i = 0; i < runs; i++) {
    final watch = Stopwatch()..start();
    body();
    times.add(watch.elapsedMicroseconds);
  }
  times.sort();
  final median = times[runs ~/ 2] / 1000;
  print('${name.padRight(36)} ${median.toStringAsFixed(2).padLeft(9)} ms');
}

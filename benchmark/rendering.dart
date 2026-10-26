import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/graphics_state.dart';
import 'package:libgfx/src/rasterize/implementations/basic_rasterizer.dart';
import 'package:libgfx/src/utils/dasher.dart';
import 'package:libgfx/src/utils/stroker.dart';

/// Times the rendering operations whose unit tests previously carried
/// timing assertions. Run with `dart run benchmark/rendering.dart` and
/// compare the medians before and after a change.
void main() {
  final rasterizer = BasicRasterizer();
  final star = _star(1000);
  final grid = _grid(50);
  final wave = _wave(100);
  final zigzag = _zigzag(5000, 0.1);

  _measure('rasterize star (1000 vertices)', () => rasterizer.rasterize(star));
  _measure('rasterize grid (2500 squares)', () => rasterizer.rasterize(grid));
  _measure('rasterize wave (100 cubics)', () => rasterizer.rasterize(wave));

  _measure(
    'clip from star 200x200',
    () => ClipRegion.fromPath(star, Matrix2D.identity(), 200, 200),
  );

  final stroker = Stroker();
  final thin = GraphicsState(transform: Matrix2D.identity(), strokeWidth: 1.0);
  final thick = GraphicsState(
    transform: Matrix2D.identity(),
    strokeWidth: 10.0,
  );
  _measure('stroke zigzag (5000 segments)', () => stroker.stroke(zigzag, thin));
  _measure('stroke wave (100 cubics)', () => stroker.stroke(wave, thick));

  final dasher = Dasher();
  final dashed = _zigzag(100, 10.0);
  _measure('dash zigzag (100 segments)', () => dasher.dash(dashed, [5, 3]));

  final image = _gradient(100, 100);
  _measure('gaussian blur 100x100 sigma 2', () {
    ImageFilters.gaussian(image, 2.0);
  });
  for (final radius in [3, 8]) {
    _measure('box blur 100x100 radius $radius', () {
      ImageFilters.box(image, radius);
    });
  }
}

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

Path _star(final int vertices) {
  final builder = PathBuilder();
  for (var i = 0; i < vertices; i++) {
    final angle = i * 2 * math.pi / vertices;
    final radius = i.isEven ? 90.0 : 40.0;
    final x = 100 + radius * math.cos(angle);
    final y = 100 + radius * math.sin(angle);
    if (i == 0) {
      builder.moveTo(x, y);
    } else {
      builder.lineTo(x, y);
    }
  }
  builder.closePath();
  return builder.build();
}

Path _grid(final int size) {
  final builder = PathBuilder();
  for (var i = 0; i < size; i++) {
    for (var j = 0; j < size; j++) {
      final x = i * 4.0;
      final y = j * 4.0;
      builder
        ..moveTo(x, y)
        ..lineTo(x + 2, y)
        ..lineTo(x + 2, y + 2)
        ..lineTo(x, y + 2)
        ..closePath();
    }
  }
  return builder.build();
}

Path _wave(final int curves) {
  final builder = PathBuilder()..moveTo(0, 50);
  for (var i = 0; i < curves; i++) {
    final x = i * 10.0;
    builder.bezierCurveTo(x + 3, 20, x + 7, 80, x + 10, 50);
  }
  return builder.build();
}

Path _zigzag(final int segments, final double step) {
  final builder = PathBuilder()..moveTo(0, 0);
  for (var i = 1; i <= segments; i++) {
    builder.lineTo(i * step, (i % 2) * 10.0);
  }
  return builder.build();
}

Bitmap _gradient(final int width, final int height) {
  final bitmap = Bitmap(width, height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      bitmap.plot(x, y, Color.fromARGB(255, x * 2, y * 2, x + y));
    }
  }
  return bitmap;
}

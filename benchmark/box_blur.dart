import 'package:libgfx/libgfx.dart';

/// Times box blur at increasing radii on the same image. The cost should not
/// depend on the radius: expect roughly the same time on every line. Run with
/// `dart run benchmark/box_blur.dart`.
void main() {
  final image = Bitmap(256, 256);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.plot(x, y, Color.fromRGBA(x, y, (x * y) & 0xFF, 255));
    }
  }

  for (final radius in [1, 4, 16, 64]) {
    // Warm up, then time the median of a few runs
    ImageFilters.box(image, radius);
    final times = <int>[];
    for (var run = 0; run < 5; run++) {
      final watch = Stopwatch()..start();
      ImageFilters.box(image, radius);
      times.add(watch.elapsedMicroseconds);
    }
    times.sort();
    print(
      '${'radius $radius'.padRight(12)} '
      '${(times[2] / 1000).toStringAsFixed(2).padLeft(9)} ms',
    );
  }
}

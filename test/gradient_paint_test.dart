import 'dart:math';

import 'package:libgfx/libgfx.dart';
import 'package:test/test.dart';

void main() {
  group('GradientPaint', () {
    const black = Color(0xFF000000);
    const red = Color(0xFFFF0000);
    const green = Color(0xFF00FF00);
    const blue = Color(0xFF0000FF);

    LinearGradient line() => LinearGradient(
      start: Point(0, 0),
      end: Point(10, 0),
      stops: [ColorStop(0.0, black)],
      spread: GradientSpread.reflect,
    );

    test('addColorStop returns a new gradient with ordered, clamped stops', () {
      final original = line();
      final gradient = original
          .addColorStop(1.5, blue)
          .addColorStop(0.5, green);

      expect(gradient.stops.map((stop) => stop.offset), equals([0, 0.5, 1]));
      expect(original.stops, hasLength(1));
      expect(gradient.end.x, equals(10));
      expect(gradient.spread, equals(GradientSpread.reflect));
    });

    test('the constructor orders and clamps stops', () {
      final gradient = LinearGradient(
        start: Point(0, 0),
        end: Point(10, 0),
        stops: [
          ColorStop(0.75, red),
          ColorStop(-0.5, green),
          ColorStop(double.nan, blue),
        ],
      );
      expect(gradient.stops.map((stop) => stop.offset), equals([0, 0, 0.75]));
    });

    test('each gradient type keeps its geometry', () {
      final radial = RadialGradient(
        center: Point(5, 6),
        radius: 7,
        focal: Point(1, 2),
        stops: [],
      ).addColorStop(1, red);
      expect([
        radial.center.x,
        radial.radius,
        radial.focal!.y,
      ], equals([5, 7, 2]));
      expect(radial.stops, hasLength(1));

      final conical = ConicalGradient(
        center: Point(3, 4),
        startAngle: 0.5,
        stops: [],
        spread: GradientSpread.repeat,
      ).addColorStop(0, red);
      expect([conical.center.y, conical.startAngle], equals([4, 0.5]));
      expect(conical.spread, equals(GradientSpread.repeat));
      expect(conical.stops, hasLength(1));
    });

    test('stops cannot be modified', () {
      final gradient = line();
      expect(
        () => gradient.stops.add(ColorStop(1, red)),
        throwsUnsupportedError,
      );
      expect(() => gradient.stops.clear(), throwsUnsupportedError);
    });

    test('the constructor copies the stops it is given', () {
      final stops = [ColorStop(0, red), ColorStop(1, blue)];
      final gradient = LinearGradient(
        start: Point(0, 0),
        end: Point(10, 0),
        stops: stops,
      );
      stops[0] = ColorStop(0, green);
      stops.add(ColorStop(0.5, black));
      expect(gradient.stops, hasLength(2));
      expect(gradient.stops.first.color.value, equals(red.value));
    });

    test('stops at the same offset keep their order', () {
      // More than 32 stops, where an unstable sort would reorder them
      final stops = [
        for (var i = 0; i < 40; i++) ColorStop(i.isEven ? 0.5 : 0.25, Color(i)),
      ];
      final gradient = LinearGradient(
        start: Point(0, 0),
        end: Point(10, 0),
        stops: stops,
      );
      final colors = gradient.stops.map((stop) => stop.color.value).toList();
      expect(
        colors,
        equals([
          for (var i = 1; i < 40; i += 2) i,
          for (var i = 0; i < 40; i += 2) i,
        ]),
      );
    });
  });

  group('Gradient orientation', () {
    const red = Color(0xFFFF0000);
    const blue = Color(0xFF0000FF);
    const size = 10;

    // Graphics space is Y-up: graphics row y is bitmap row size - 1 - y.
    Color at(final GraphicsEngine engine, final int x, final int y) =>
        engine.pixel(x, size - 1 - y);

    LinearGradient vertical() => LinearGradient(
      start: Point(0, 0),
      end: Point(0, size.toDouble()),
      stops: [ColorStop(0.0, red), ColorStop(1.0, blue)],
    );

    test('linear gradient is sampled in graphics coordinates', () {
      final engine = GraphicsEngine(size, size)
        ..fillStyle = vertical()
        ..fillRect(0, 0, size.toDouble(), size.toDouble());

      expect(at(engine, 5, 0).red, greaterThan(at(engine, 5, 0).blue));
      expect(at(engine, 5, 9).blue, greaterThan(at(engine, 5, 9).red));
    });

    test('linear gradient is oriented on the anti-aliased path', () {
      final engine = GraphicsEngine(size, size)
        ..globalAlpha = 0.5
        ..fillStyle = vertical()
        ..fillRect(0, 0, size.toDouble(), size.toDouble());

      expect(at(engine, 5, 0).red, greaterThan(at(engine, 5, 0).blue));
      expect(at(engine, 5, 9).blue, greaterThan(at(engine, 5, 9).red));
    });

    test('radial gradient is sampled in graphics coordinates', () {
      final engine = GraphicsEngine(size, size)
        ..fillStyle = RadialGradient(
          center: Point(5, 2),
          radius: 3,
          stops: [ColorStop(0.0, red), ColorStop(1.0, blue)],
        )
        ..fillRect(0, 0, size.toDouble(), size.toDouble());

      expect(at(engine, 5, 2).red, greaterThan(at(engine, 5, 2).blue));
      expect(at(engine, 5, 8).value, equals(blue.value));
    });

    void expectMirrored(final Color first, final Color last) {
      expect(first.red, closeTo(last.blue, 1));
      expect(first.blue, closeTo(last.red, 1));
      expect(first.value, isNot(equals(red.value)));
      expect(last.value, isNot(equals(blue.value)));
    }

    LinearGradient horizontal() => LinearGradient(
      start: Point(0, 0),
      end: Point(size.toDouble(), 0),
      stops: [ColorStop(0.0, red), ColorStop(1.0, blue)],
    );

    test('horizontal gradient is sampled at pixel centres', () {
      final engine = GraphicsEngine(size, size)
        ..fillStyle = horizontal()
        ..fillRect(0, 0, size.toDouble(), size.toDouble());

      expectMirrored(at(engine, 0, 5), at(engine, 9, 5));
    });

    test('vertical gradient is sampled at pixel centres', () {
      final engine = GraphicsEngine(size, size)
        ..fillStyle = vertical()
        ..fillRect(0, 0, size.toDouble(), size.toDouble());

      expectMirrored(at(engine, 5, 0), at(engine, 5, 9));
    });

    test('anti-aliased path samples at pixel centres', () {
      final engine = GraphicsEngine(size, size)
        ..globalAlpha = 0.5
        ..fillStyle = horizontal()
        ..fillRect(0, 0, size.toDouble(), size.toDouble());

      expectMirrored(at(engine, 0, 5), at(engine, 9, 5));
    });
  });

  group('Stop lookup', () {
    test('matches a scan of every stop pair', () {
      final random = Random(11);
      for (var trial = 0; trial < 300; trial++) {
        final count = random.nextInt(12);
        final stops = [
          for (var i = 0; i < count; i++)
            // A coarse grid makes repeated offsets (hard stops) common
            ColorStop(random.nextInt(9) / 8, Color(random.nextInt(1 << 32))),
        ];
        final gradient = LinearGradient(
          start: Point(0, 0),
          end: Point(1, 0),
          stops: stops,
        );
        final positions = [
          double.nan,
          double.infinity,
          double.negativeInfinity,
          -0.5,
          1.5,
          for (var i = 0; i <= 8; i++) i / 8,
          for (var i = 0; i < 20; i++) random.nextDouble(),
        ];
        for (final t in positions) {
          expect(
            gradient.lookup(t).value,
            equals(_scan(gradient.stops, t).value),
            reason: 'trial $trial, t $t',
          );
        }
      }
    });
  });
}

/// The colour lookup as it was written, scanning every pair of stops; the
/// reference for the binary search.
Color _scan(final List<ColorStop> stops, final double t) {
  if (stops.isEmpty) return const Color(0x00000000);
  if (t <= stops.first.offset) return stops.first.color;
  if (t >= stops.last.offset) return stops.last.color;
  for (var i = 0; i < stops.length - 1; i++) {
    if (t >= stops[i].offset && t <= stops[i + 1].offset) {
      final s1 = stops[i];
      final s2 = stops[i + 1];
      final local = (t - s1.offset) / (s2.offset - s1.offset);
      return ColorUtils.lerp(s1.color, s2.color, local);
    }
  }
  return stops.last.color;
}

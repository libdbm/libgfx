import 'dart:math';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/paths/path.dart' show EllipseCommand;
import 'package:test/test.dart';

void main() {
  Path parse(final String data) =>
      SVGPath.parse('<path d="$data"/>').single.path;

  // Same command types with the same points
  void expectSame(final Path actual, final Path expected) {
    expect(
      actual.commands.map((command) => command.type),
      equals(expected.commands.map((command) => command.type)),
    );
    for (var i = 0; i < expected.commands.length; i++) {
      final points = actual.commands[i].points;
      final wanted = expected.commands[i].points;
      expect(points, hasLength(wanted.length));
      for (var j = 0; j < wanted.length; j++) {
        expect(points[j].x, closeTo(wanted[j].x, 1e-9), reason: 'command $i');
        expect(points[j].y, closeTo(wanted[j].y, 1e-9), reason: 'command $i');
      }
    }
  }

  group('SVG quadratic curves', () {
    test('Q and q draw a quadratic curve', () {
      final expected =
          (PathBuilder()
                ..moveTo(10, 10)
                ..quadraticCurveTo(20, 30, 40, 10))
              .build();
      expectSame(parse('M10 10 Q20 30 40 10'), expected);
      expectSame(parse('M10 10 q10 20 30 0'), expected);
    });

    test('repeated coordinates draw further curves', () {
      expectSame(
        parse('M0 0 Q10 20 30 0 40 -20 60 0'),
        (PathBuilder()
              ..moveTo(0, 0)
              ..quadraticCurveTo(10, 20, 30, 0)
              ..quadraticCurveTo(40, -20, 60, 0))
            .build(),
      );
    });

    test('T and t reflect the previous control point', () {
      final expected =
          (PathBuilder()
                ..moveTo(0, 0)
                ..quadraticCurveTo(10, 20, 30, 0)
                ..quadraticCurveTo(50, -20, 60, 0)
                ..quadraticCurveTo(70, 20, 90, 0))
              .build();
      expectSame(parse('M0 0 Q10 20 30 0 T60 0 90 0'), expected);
      expectSame(parse('M0 0 Q10 20 30 0 t30 0 30 0'), expected);
    });

    test('T after anything but a quadratic curve uses the current point', () {
      expectSame(
        parse('M0 0 L10 0 T20 0'),
        (PathBuilder()
              ..moveTo(0, 0)
              ..lineTo(10, 0)
              ..quadraticCurveTo(10, 0, 20, 0))
            .build(),
      );
      expectSame(
        parse('M0 0 C0 10 20 10 20 0 T40 0'),
        (PathBuilder()
              ..moveTo(0, 0)
              ..bezierCurveTo(0, 10, 20, 10, 20, 0)
              ..quadraticCurveTo(20, 0, 40, 0))
            .build(),
      );
    });
  });

  group('SVG arcs', () {
    EllipseCommand arc(final Path path) =>
        path.commands.whereType<EllipseCommand>().single;

    // The point of [arc] at [angle], on its rotated ellipse
    (double, double) at(final EllipseCommand arc, final double angle) => (
      arc.centerX +
          arc.radiusX * cos(angle) * cos(arc.rotation) -
          arc.radiusY * sin(angle) * sin(arc.rotation),
      arc.centerY +
          arc.radiusX * cos(angle) * sin(arc.rotation) +
          arc.radiusY * sin(angle) * cos(arc.rotation),
    );

    void expectJoins(
      final EllipseCommand arc,
      final (double, double) from,
      final (double, double) to,
    ) {
      final start = at(arc, arc.startAngle);
      final end = at(arc, arc.endAngle);
      expect(start.$1, closeTo(from.$1, 1e-9));
      expect(start.$2, closeTo(from.$2, 1e-9));
      expect(end.$1, closeTo(to.$1, 1e-9));
      expect(end.$2, closeTo(to.$2, 1e-9));
    }

    test('a half circle runs in increasing angle when sweep is 1', () {
      final half = arc(parse('M0 0 A10 10 0 0 1 20 0'));
      expect([half.centerX, half.centerY], equals([10, 0]));
      expect([half.radiusX, half.radiusY], equals([10, 10]));
      expect(half.endAngle - half.startAngle, closeTo(pi, 1e-9));
      expectJoins(half, (0, 0), (20, 0));

      final other = arc(parse('M0 0 A10 10 0 0 0 20 0'));
      expect(other.endAngle - other.startAngle, closeTo(-pi, 1e-9));
      expectJoins(other, (0, 0), (20, 0));
    });

    test('a rotated ellipse arc joins its end points', () {
      final rotated = arc(parse('M0 0 A20 10 90 0 1 0 40'));
      expect(rotated.rotation, closeTo(pi / 2, 1e-12));
      expect(rotated.centerX, closeTo(0, 1e-9));
      expect(rotated.centerY, closeTo(20, 1e-9));
      expectJoins(rotated, (0, 0), (0, 40));

      final tilted = arc(parse('M10 10 a30 15 30 1 0 25 5'));
      expectJoins(tilted, (10, 10), (35, 15));
    });

    test('the flags choose the larger arc and the direction', () {
      for (final (large, sweep) in [(0, 0), (0, 1), (1, 0), (1, 1)]) {
        final chosen = arc(parse('M0 0 A10 10 0 $large $sweep 10 10'));
        final turn = chosen.endAngle - chosen.startAngle;
        final reason = 'large $large, sweep $sweep';
        expect(turn.abs() > pi, equals(large == 1), reason: reason);
        expect(turn > 0, equals(sweep == 1), reason: reason);
        expectJoins(chosen, (0, 0), (10, 10));
      }
    });

    test('flags may be written without separators', () {
      expectSame(
        parse('M0 0 a10 10 0 0110 0'),
        parse('M0 0 a10 10 0 0 1 10 0'),
      );
      expectSame(
        parse('M0 0 a10,10,0,1,0,10,0 a10 10 0 1110.5 0'),
        parse('M0 0 a10 10 0 1 0 10 0 a10 10 0 1 1 10.5 0'),
      );
    });

    test('a zero radius draws a line', () {
      expectSame(
        parse('M0 0 A0 10 0 0 1 20 0'),
        (PathBuilder()
              ..moveTo(0, 0)
              ..lineTo(20, 0))
            .build(),
      );
    });

    test('radii too small to reach are scaled up', () {
      final scaled = arc(parse('M0 0 A1 2 0 0 1 20 0'));
      expect(scaled.radiusX / scaled.radiusY, closeTo(0.5, 1e-9));
      expectJoins(scaled, (0, 0), (20, 0));
    });

    test('an arc too flat for an ellipse still reaches its end', () {
      // Turns about 0.0005 radians, under what PathBuilder.ellipse draws
      final path = parse('M0 0 A100000 100000 0 0 1 50 0');
      expect(path.commands.last.points.last.x, closeTo(50, 1e-6));
      expect(path.commands.last.points.last.y, closeTo(0, 1e-6));
    });

    test('an arc to its own start draws nothing', () {
      expect(parse('M5 5 A10 10 0 0 1 5 5').commands, hasLength(1));
    });

    test('the current point moves to the end of the arc', () {
      final path = parse('M0 0 A10 10 0 0 1 20 0 l5 0');
      expect(path.commands.last.points.single.x, closeTo(25, 1e-9));
      expect(path.commands.last.points.single.y, closeTo(0, 1e-9));
    });
  });
}

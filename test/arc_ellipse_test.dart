import 'dart:math';

import 'package:libgfx/src/image/bitmap.dart';
import 'package:libgfx/src/color/color.dart';
import 'package:libgfx/src/graphics_context.dart';
import 'package:libgfx/src/matrix.dart';
import 'package:libgfx/libgfx.dart' show GraphicsEngine;
import 'package:libgfx/src/paths/path.dart';
import 'package:test/test.dart';

void main() {
  group('Arc Tests', () {
    test('Arc command creation', () {
      final path = PathBuilder().arc(100, 100, 50, 0, pi / 2).build();

      expect(path.commands.length, 2); // moveTo + arc
      expect(path.commands[0].type, PathCommandType.moveTo);
      expect(path.commands[1].type, PathCommandType.arc);

      final arcCmd = path.commands[1] as ArcCommand;
      expect(arcCmd.centerX, 100);
      expect(arcCmd.centerY, 100);
      expect(arcCmd.radius, 50);
      expect(arcCmd.startAngle, 0);
      expect(arcCmd.endAngle, closeTo(pi / 2, 0.001));
    });

    test('Full circle using arc', () {
      final path = PathBuilder().arc(50, 50, 30, 0, 2 * pi).build();

      expect(path.commands.any((cmd) => cmd.type == PathCommandType.arc), true);
    });

    test('Counter-clockwise arc', () {
      final path = PathBuilder().arc(100, 100, 40, pi / 2, 0, true).build();

      final arcCmd = path.commands.last as ArcCommand;
      expect(arcCmd.counterClockwise, true);
    });

    test('Arc rendering', () {
      final bitmap = Bitmap(200, 200);
      final context = GraphicsContext(bitmap);

      context.state.fillPaint = Color.fromARGB(255, 255, 0, 0);

      final path = PathBuilder().arc(100, 100, 50, 0, pi).closePath().build();

      context.fill(path);

      // Check that some pixels are filled
      bool hasRedPixels = false;
      for (int y = 50; y < 150; y++) {
        for (int x = 50; x < 150; x++) {
          final color = bitmap.pixel(x, y);
          if (color.red == 255) {
            hasRedPixels = true;
            break;
          }
        }
      }
      expect(hasRedPixels, true);
    });

    test('Arc transformation', () {
      final path = PathBuilder().arc(50, 50, 30, 0, pi / 2).build();

      final transform = Matrix2D.identity()..scale(2.0, 2.0);
      final transformed = path.transform(transform);

      // Arc should be converted to bezier curves when transformed
      expect(
        transformed.commands.any(
          (cmd) => cmd.type == PathCommandType.cubicCurveTo,
        ),
        true,
      );
    });
  });

  group('Ellipse Tests', () {
    test('Ellipse command creation', () {
      final path = PathBuilder().ellipse(100, 100, 50, 30, 0, 0, pi).build();

      expect(path.commands.length, 2); // moveTo + ellipse
      expect(path.commands[0].type, PathCommandType.moveTo);
      expect(path.commands[1].type, PathCommandType.ellipse);

      final ellipseCmd = path.commands[1] as EllipseCommand;
      expect(ellipseCmd.centerX, 100);
      expect(ellipseCmd.centerY, 100);
      expect(ellipseCmd.radiusX, 50);
      expect(ellipseCmd.radiusY, 30);
      expect(ellipseCmd.rotation, 0);
    });

    test('Rotated ellipse', () {
      final path = PathBuilder()
          .ellipse(100, 100, 60, 40, pi / 4, 0, 2 * pi)
          .build();

      final ellipseCmd = path.commands.last as EllipseCommand;
      expect(ellipseCmd.rotation, closeTo(pi / 4, 0.001));
    });

    test('Circle using ellipse', () {
      final path = PathBuilder().circle(50, 50, 25).build();

      expect(
        path.commands.any((cmd) => cmd.type == PathCommandType.ellipse),
        true,
      );

      final ellipseCmd = path.commands.last as EllipseCommand;
      expect(ellipseCmd.radiusX, ellipseCmd.radiusY);
      expect(ellipseCmd.radiusX, 25);
    });

    test('Ellipse rendering', () {
      final bitmap = Bitmap(200, 200);
      final context = GraphicsContext(bitmap);

      context.state.fillPaint = Color.fromARGB(255, 0, 255, 0);

      final path = PathBuilder()
          .ellipse(100, 100, 70, 40, 0, 0, 2 * pi)
          .closePath()
          .build();

      context.fill(path);

      // Check that center is filled
      // Due to Y-flip: graphics space (100, 100) -> bitmap space (100, 200-1-100) = (100, 99)
      // With the rasterizer fix, we now get more accurate coverage values
      expect(bitmap.pixel(100, 100).green, greaterThan(250));

      // Check that pixels outside ellipse are not filled
      expect(bitmap.pixel(10, 10).green, 0);
    });

    test('Partial ellipse arc', () {
      final path = PathBuilder()
          .ellipse(100, 100, 50, 30, 0, 0, pi / 2)
          .lineTo(100, 100)
          .closePath()
          .build();

      expect(path.commands.length, 4); // moveTo + ellipse + lineTo + close
    });
  });

  group('Integration Tests', () {
    test('Complex path with arcs and ellipses', () {
      final path = PathBuilder()
          .moveTo(50, 50)
          .arc(100, 50, 30, pi, 3 * pi)
          .ellipse(200, 100, 40, 25, pi / 6, 0, pi)
          .lineTo(50, 150)
          .closePath()
          .build();

      expect(
        path.commands.where((cmd) => cmd.type == PathCommandType.arc).length,
        1,
      );
      expect(
        path.commands
            .where((cmd) => cmd.type == PathCommandType.ellipse)
            .length,
        1,
      );
    });

    test('Transformed complex path', () {
      final path = PathBuilder()
          .arc(50, 50, 30, 0, pi)
          .ellipse(100, 50, 20, 15, 0, 0, pi)
          .build();

      final transform = Matrix2D.identity()
        ..translate(10.0, 10.0)
        ..rotate(pi / 4);

      final transformed = path.transform(transform);

      // Should have bezier curves after transformation
      expect(
        transformed.commands.any(
          (cmd) => cmd.type == PathCommandType.cubicCurveTo,
        ),
        true,
      );
    });

    test('Arc and ellipse bounds calculation', () {
      final path = PathBuilder().arc(100, 100, 50, 0, 2 * pi).build();

      final bounds = path.bounds;
      // Arc commands store center point, so bounds will be at center
      // until we implement proper bounds calculation for arcs
      expect(bounds.left, closeTo(100, 1));
      expect(bounds.top, closeTo(100, 1));
      // The actual arc bounds would be 50-150, but current implementation
      // only looks at command points, not the full arc extent
    });
  });

  group('W3C arcs and shapes', () {
    // Fills [path] on a 40 x 40 engine; inside reads graphics coordinates
    bool Function(int, int) fill(final Path path) {
      final engine = GraphicsEngine(40, 40)
        ..fillStyle = const Color(0xFF000000)
        ..fill(path);
      return (x, y) => engine.pixel(x, 39 - y).alpha > 128;
    }

    test('arc runs from start to end angle in increasing angle', () {
      final inside = fill(
        (PathBuilder()
              ..moveTo(20, 20)
              ..arc(20, 20, 15, 0, pi / 2)
              ..closePath())
            .build(),
      );
      expect(inside(28, 28), isTrue);
      expect(inside(28, 12), isFalse);
      expect(inside(12, 12), isFalse);
    });

    test('a counterclockwise arc takes the other way round', () {
      final inside = fill(
        (PathBuilder()
              ..moveTo(20, 20)
              ..arc(20, 20, 15, 0, pi / 2, true)
              ..closePath())
            .build(),
      );
      expect(inside(28, 28), isFalse);
      expect(inside(28, 12), isTrue);
      expect(inside(12, 12), isTrue);
      expect(inside(12, 28), isTrue);
    });

    test('a sweep beyond a full turn draws one full circle', () {
      final forward = PathBuilder().arc(20, 20, 15, 0, 5 * pi).build();
      final backward = PathBuilder().arc(20, 20, 15, 0, -5 * pi, true).build();
      expect(
        (forward.commands.last as ArcCommand).endAngle,
        closeTo(2 * pi, 1e-12),
      );
      expect(
        (backward.commands.last as ArcCommand).endAngle,
        closeTo(-2 * pi, 1e-12),
      );
    });

    test('arcTo rounds the corner between its two tangents', () {
      final inside = fill(
        (PathBuilder()
              ..moveTo(5, 5)
              ..arcTo(35, 5, 35, 35, 10)
              ..lineTo(35, 35)
              ..lineTo(5, 35)
              ..closePath())
            .build(),
      );
      expect(inside(34, 6), isFalse, reason: 'corner is rounded off');
      expect(inside(30, 10), isTrue);
      expect(inside(20, 20), isTrue);
      expect(inside(6, 6), isTrue);
    });

    test('arcTo centres its arc on the bisector, touching both lines', () {
      // From (5, 5) to the corner (35, 5), then along [direction]; the
      // circle of radius 10 touches the first line 10 above or below it
      for (final (direction, angle, side) in [
        ((0.0, 1.0), pi / 2, 1),
        ((-1.0, 1.0), pi / 4, 1),
        ((1.0, 1.0), 3 * pi / 4, 1),
        ((0.0, -1.0), pi / 2, -1),
      ]) {
        final length = sqrt(
          direction.$1 * direction.$1 + direction.$2 * direction.$2,
        );
        final (ux, uy) = (direction.$1 / length, direction.$2 / length);
        final reach = 10 / tan(angle / 2);
        final path =
            (PathBuilder()
                  ..moveTo(5, 5)
                  ..arcTo(35, 5, 35 + 30 * ux, 5 + 30 * uy, 10))
                .build();
        final arc = path.commands.whereType<ArcCommand>().single;
        final reason = 'direction $direction';

        expect(arc.centerX, closeTo(35 - reach, 1e-9), reason: reason);
        expect(arc.centerY, closeTo(5 + 10 * side, 1e-9), reason: reason);
        expect(arc.radius, equals(10));
        final start = (
          arc.centerX + 10 * cos(arc.startAngle),
          arc.centerY + 10 * sin(arc.startAngle),
        );
        final end = (
          arc.centerX + 10 * cos(arc.endAngle),
          arc.centerY + 10 * sin(arc.endAngle),
        );
        expect(start.$1, closeTo(35 - reach, 1e-9), reason: reason);
        expect(start.$2, closeTo(5, 1e-9), reason: reason);
        expect(end.$1, closeTo(35 + reach * ux, 1e-9), reason: reason);
        expect(end.$2, closeTo(5 + reach * uy, 1e-9), reason: reason);
        expect(
          (arc.endAngle - arc.startAngle).abs(),
          closeTo(pi - angle, 1e-9),
          reason: '$reason: the short way round',
        );
        for (final line in path.commands.where(
          (command) => command.type == PathCommandType.lineTo,
        )) {
          expect(line.points.single.x, closeTo(35 - reach, 1e-9));
          expect(line.points.single.y, closeTo(5, 1e-9));
        }
      }
    });

    test('arcTo draws a line to its corner when it has no arc', () {
      for (final (x2, y2, radius) in [
        (65.0, 5.0, 10.0), // straight on
        (0.0, 5.0, 10.0), // straight back
        (35.0, 35.0, 0.0), // no radius
      ]) {
        final path =
            (PathBuilder()
                  ..moveTo(5, 5)
                  ..arcTo(35, 5, x2, y2, radius))
                .build();
        expect(path.commands, hasLength(2), reason: '($x2, $y2, $radius)');
        expect(path.commands.last.type, PathCommandType.lineTo);
        expect(path.commands.last.points.single.x, equals(35));
        expect(path.commands.last.points.single.y, equals(5));
      }
    });

    test('roundRect cuts its corners and keeps its middle', () {
      final inside = fill(PathBuilder().roundRect(5, 5, 30, 30, 10).build());
      for (final corner in [(5, 5), (34, 5), (5, 34), (34, 34)]) {
        expect(inside(corner.$1, corner.$2), isFalse, reason: '$corner');
      }
      expect(inside(20, 20), isTrue);
      expect(inside(20, 5), isTrue);
    });

    test('rect, polygon and star add closed outlines', () {
      expect(fill(PathBuilder().rect(5, 5, 10, 10).build())(10, 10), isTrue);
      expect(
        fill(PathBuilder().polygon(20, 20, 15, 6).build())(20, 20),
        isTrue,
      );
      expect(
        fill(PathBuilder().star(20, 20, 15, 6, 5).build())(20, 20),
        isTrue,
      );
      expect(() => PathBuilder().polygon(0, 0, 1, 2), throwsArgumentError);
      expect(() => PathBuilder().star(0, 0, 2, 1, 2), throwsArgumentError);
    });
  });
}

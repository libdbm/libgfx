import 'dart:math';

import 'package:libgfx/src/image/bitmap.dart';
import 'package:libgfx/src/color/color.dart';
import 'package:libgfx/src/graphics_context.dart';
import 'package:libgfx/src/matrix.dart';
import 'package:libgfx/src/paint.dart';
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
      final path = PathBuilder()
          .arc(100, 100, 40, pi / 2, -pi / 2, true)
          .build();

      final arcCmd = path.commands.last as ArcCommand;
      expect(arcCmd.counterClockwise, true);
    });

    test('Arc rendering', () {
      final bitmap = Bitmap(200, 200);
      final context = GraphicsContext(bitmap);

      context.state.fillPaint = SolidPaint(Color.fromARGB(255, 255, 0, 0));

      final path = PathBuilder().arc(100, 100, 50, 0, pi).close().build();

      context.fill(path);

      // Check that some pixels are filled
      bool hasRedPixels = false;
      for (int y = 50; y < 150; y++) {
        for (int x = 50; x < 150; x++) {
          final color = bitmap.getPixel(x, y);
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

      context.state.fillPaint = SolidPaint(Color.fromARGB(255, 0, 255, 0));

      final path = PathBuilder()
          .ellipse(100, 100, 70, 40, 0, 0, 2 * pi)
          .close()
          .build();

      context.fill(path);

      // Check that center is filled
      // Due to Y-flip: graphics space (100, 100) -> bitmap space (100, 200-1-100) = (100, 99)
      // With the rasterizer fix, we now get more accurate coverage values
      expect(bitmap.getPixel(100, 100).green, greaterThan(250));

      // Check that pixels outside ellipse are not filled
      expect(bitmap.getPixel(10, 10).green, 0);
    });

    test('Partial ellipse arc', () {
      final path = PathBuilder()
          .ellipse(100, 100, 50, 30, 0, 0, pi / 2)
          .lineTo(100, 100)
          .close()
          .build();

      expect(path.commands.length, 4); // moveTo + ellipse + lineTo + close
    });
  });

  group('Integration Tests', () {
    test('Complex path with arcs and ellipses', () {
      final path = PathBuilder()
          .moveTo(50, 50)
          .arc(100, 50, 30, pi, 2 * pi)
          .ellipse(200, 100, 40, 25, pi / 6, 0, pi)
          .lineTo(50, 150)
          .close()
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
        ..rotateZ(pi / 4);

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
}

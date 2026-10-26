import 'package:libgfx/libgfx.dart';
import 'package:test/test.dart';

void main() {
  group('Path', () {
    test('empty path has no commands', () {
      final path = Path();
      expect(path.commands, isEmpty);
    });

    test('moveTo creates move command', () {
      final builder = PathBuilder();
      builder.moveTo(10.0, 20.0);
      final path = builder.build();

      expect(path.commands.length, equals(1));
      expect(path.commands[0].type, equals(PathCommandType.moveTo));
      expect(path.commands[0].points.length, equals(1));
      expect(path.commands[0].points[0].x, equals(10.0));
      expect(path.commands[0].points[0].y, equals(20.0));
    });

    test('lineTo creates line command', () {
      final builder = PathBuilder();
      builder.moveTo(0.0, 0.0);
      builder.lineTo(100.0, 50.0);
      final path = builder.build();

      expect(path.commands.length, equals(2));
      expect(path.commands[1].type, equals(PathCommandType.lineTo));
      expect(path.commands[1].points[0].x, equals(100.0));
      expect(path.commands[1].points[0].y, equals(50.0));
    });

    test('bezierCurveTo creates cubic curve command', () {
      final builder = PathBuilder();
      builder.moveTo(0.0, 0.0);
      builder.bezierCurveTo(10.0, 10.0, 20.0, 20.0, 30.0, 30.0);
      final path = builder.build();

      expect(path.commands.length, equals(2));
      expect(path.commands[1].type, equals(PathCommandType.cubicCurveTo));
      expect(path.commands[1].points.length, equals(3));
      expect(path.commands[1].points[0].x, equals(10.0));
      expect(path.commands[1].points[0].y, equals(10.0));
      expect(path.commands[1].points[1].x, equals(20.0));
      expect(path.commands[1].points[1].y, equals(20.0));
      expect(path.commands[1].points[2].x, equals(30.0));
      expect(path.commands[1].points[2].y, equals(30.0));
    });

    test('close creates close command', () {
      final builder = PathBuilder();
      builder.moveTo(0.0, 0.0);
      builder.lineTo(100.0, 0.0);
      builder.lineTo(100.0, 100.0);
      builder.closePath();
      final path = builder.build();

      expect(path.commands.length, equals(4));
      expect(path.commands[3].type, equals(PathCommandType.close));
    });

    test('path bounds calculation', () {
      final builder = PathBuilder();
      builder.moveTo(10.0, 20.0);
      builder.lineTo(100.0, 20.0);
      builder.lineTo(100.0, 80.0);
      builder.lineTo(10.0, 80.0);
      builder.closePath();
      final path = builder.build();

      final bounds = path.bounds;
      expect(bounds.left, equals(10.0));
      expect(bounds.top, equals(20.0));
      expect(bounds.right, equals(100.0));
      expect(bounds.bottom, equals(80.0));
    });

    test('path bounds with curves', () {
      final builder = PathBuilder();
      builder.moveTo(0.0, 0.0);
      builder.bezierCurveTo(50.0, -50.0, 150.0, 50.0, 200.0, 0.0);
      final path = builder.build();

      final bounds = path.bounds;
      // Bounds should include control points
      expect(bounds.left, equals(0.0));
      expect(bounds.top, equals(-50.0));
      expect(bounds.right, equals(200.0));
      expect(bounds.bottom, equals(50.0));
    });

    test('path transformation', () {
      final builder = PathBuilder();
      builder.moveTo(10.0, 20.0);
      builder.lineTo(30.0, 40.0);
      final path = builder.build();

      final matrix = Matrix2D.identity();
      matrix.translate(100.0, 200.0);
      matrix.scale(2.0, 3.0);

      final transformed = path.transform(matrix);

      expect(transformed.commands.length, equals(2));
      expect(transformed.commands[0].points[0].x, equals(120.0));
      expect(transformed.commands[0].points[0].y, equals(260.0));
      expect(transformed.commands[1].points[0].x, equals(160.0));
      expect(transformed.commands[1].points[0].y, equals(320.0));
    });

    test('path clone creates independent copy', () {
      final builder = PathBuilder();
      builder.moveTo(10.0, 20.0);
      builder.lineTo(30.0, 40.0);
      final original = builder.build();

      final copy = original.clone();

      // Original should have 2 commands
      expect(original.commands.length, equals(2));
      expect(copy.commands.length, equals(2));
    });
  });

  group('PathBuilder', () {
    test('creates empty path when not used', () {
      final builder = PathBuilder();
      final path = builder.build();

      expect(path.commands, isEmpty);
    });

    test('builds simple rectangle', () {
      final builder = PathBuilder();
      builder
        ..moveTo(0.0, 0.0)
        ..lineTo(100.0, 0.0)
        ..lineTo(100.0, 50.0)
        ..lineTo(0.0, 50.0)
        ..closePath();

      final path = builder.build();
      expect(path.commands.length, equals(5));
      expect(path.commands[0].type, equals(PathCommandType.moveTo));
      expect(path.commands[1].type, equals(PathCommandType.lineTo));
      expect(path.commands[2].type, equals(PathCommandType.lineTo));
      expect(path.commands[3].type, equals(PathCommandType.lineTo));
      expect(path.commands[4].type, equals(PathCommandType.close));
    });

    test('rectangle path creation', () {
      final builder = PathBuilder();
      builder.moveTo(10.0, 20.0);
      builder.lineTo(110.0, 20.0);
      builder.lineTo(110.0, 70.0);
      builder.lineTo(10.0, 70.0);
      builder.closePath();

      final path = builder.build();
      expect(path.commands.length, equals(5));

      // Check the rectangle corners
      expect(path.commands[0].points[0].x, equals(10.0));
      expect(path.commands[0].points[0].y, equals(20.0));
      expect(path.commands[1].points[0].x, equals(110.0));
      expect(path.commands[1].points[0].y, equals(20.0));
      expect(path.commands[2].points[0].x, equals(110.0));
      expect(path.commands[2].points[0].y, equals(70.0));
      expect(path.commands[3].points[0].x, equals(10.0));
      expect(path.commands[3].points[0].y, equals(70.0));
    });

    test('bezierCurveTo creates cubic curve', () {
      final builder = PathBuilder();
      builder
        ..moveTo(0.0, 0.0)
        ..bezierCurveTo(20.0, 40.0, 80.0, 40.0, 100.0, 0.0);

      final path = builder.build();
      expect(path.commands.length, equals(2));
      expect(path.commands[1].type, equals(PathCommandType.cubicCurveTo));

      // Check control points
      final cp1 = path.commands[1].points[0];
      final cp2 = path.commands[1].points[1];
      final end = path.commands[1].points[2];

      expect(cp1.x, equals(20.0));
      expect(cp1.y, equals(40.0));
      expect(cp2.x, equals(80.0));
      expect(cp2.y, equals(40.0));
      expect(end.x, equals(100.0));
      expect(end.y, equals(0.0));
    });

    test('multiple subpaths', () {
      final builder = PathBuilder();

      // First subpath - triangle
      builder
        ..moveTo(0.0, 0.0)
        ..lineTo(50.0, 100.0)
        ..lineTo(100.0, 0.0)
        ..closePath();

      // Second subpath - square
      builder
        ..moveTo(150.0, 0.0)
        ..lineTo(250.0, 0.0)
        ..lineTo(250.0, 100.0)
        ..lineTo(150.0, 100.0)
        ..closePath();

      final path = builder.build();
      expect(path.commands.length, equals(9)); // 4 for triangle + 5 for square

      // Count moveTo commands to verify we have 2 subpaths
      final moveCount = path.commands
          .where((cmd) => cmd.type == PathCommandType.moveTo)
          .length;
      expect(moveCount, equals(2));
    });

    test('builder can be reused after build', () {
      final builder = PathBuilder();

      builder
        ..moveTo(0.0, 0.0)
        ..lineTo(100.0, 100.0);

      final path1 = builder.build();
      expect(path1.commands.length, equals(2));

      // Create a new builder for the second path
      final builder2 = PathBuilder();
      builder2
        ..moveTo(0.0, 0.0)
        ..lineTo(100.0, 100.0)
        ..lineTo(200.0, 0.0);

      final path2 = builder2.build();
      expect(path2.commands.length, equals(3));

      // Original path should not be affected
      expect(path1.commands.length, equals(2));
    });

    test('implicit moveTo for closed paths', () {
      final builder = PathBuilder();

      // Draw without explicit moveTo
      builder
        ..lineTo(100.0, 0.0)
        ..lineTo(100.0, 100.0)
        ..closePath();

      final path = builder.build();

      // Should have implicit moveTo at current position
      expect(path.commands[0].type, equals(PathCommandType.moveTo));
      // lineTo without moveTo creates moveTo at destination
      expect(path.commands[0].points[0].x, equals(100.0));
      expect(path.commands[0].points[0].y, equals(0.0));
    });
  });

  group('Rectangle', () {
    test('rect from LTRB', () {
      final rect = Rectangle.fromLTRB(10.0, 20.0, 110.0, 70.0);

      expect(rect.left, equals(10.0));
      expect(rect.top, equals(20.0));
      expect(rect.right, equals(110.0));
      expect(rect.bottom, equals(70.0));
    });
  });

  group('Immutable path internals', () {
    Path square() =>
        (PathBuilder()
              ..moveTo(0, 0)
              ..lineTo(10, 0)
              ..lineTo(10, 10)
              ..closePath())
            .build();

    test('commands cannot be modified', () {
      final path = square();
      final line = PathCommand(PathCommandType.lineTo, [const Point(50, 50)]);
      expect(() => path.commands.add(line), throwsUnsupportedError);
      expect(() => path.commands[0] = line, throwsUnsupportedError);
      expect(() => path.commands.clear(), throwsUnsupportedError);
    });

    test('points cannot be modified', () {
      final points = square().commands[1].points;
      expect(() => points.add(const Point(1, 1)), throwsUnsupportedError);
      expect(() => points[0] = const Point(1, 1), throwsUnsupportedError);
    });

    test('a command copies the points it is given', () {
      final points = [const Point(1, 2)];
      final command = PathCommand(PathCommandType.lineTo, points);
      points[0] = const Point(99, 99);
      points.add(const Point(5, 5));
      expect(command.points, hasLength(1));
      expect(command.points[0].x, equals(1));
    });

    test('points are constant values', () {
      const point = Point(3, 4);
      expect([point.x, point.y], equals([3, 4]));
    });

    test('an empty path has zero bounds', () {
      final bounds = Path().bounds;
      expect([
        bounds.left,
        bounds.top,
        bounds.width,
        bounds.height,
      ], equals([0, 0, 0, 0]));
    });

    test('bounds follow every public way of adding commands', () {
      final path = square();
      expect(path.bounds.right, equals(10));
      path.add(PathCommand(PathCommandType.lineTo, [const Point(30, -5)]));
      expect([path.bounds.right, path.bounds.top], equals([30, -5]));
      path.addPath(
        (PathBuilder()
              ..moveTo(-7, 0)
              ..lineTo(0, 40))
            .build(),
      );
      expect([path.bounds.left, path.bounds.bottom], equals([-7, 40]));
    });

    test('a clone and its original change independently', () {
      final original = square();
      expect(original.bounds.right, equals(10));
      final copy = original.clone();
      copy.add(PathCommand(PathCommandType.lineTo, [const Point(100, 100)]));
      expect(original.commands, hasLength(4));
      expect(original.bounds.right, equals(10));
      expect(copy.bounds.right, equals(100));
    });
  });
}

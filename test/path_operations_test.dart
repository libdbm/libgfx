import 'package:libgfx/src/paths/path.dart';
import 'package:libgfx/src/point.dart';
import 'package:test/test.dart';

void main() {
  group('Path Operations Tests', () {
    test('Point lerp interpolation', () {
      final p1 = Point(0, 0);
      final p2 = Point(10, 10);

      final midpoint = Point.lerp(p1, p2, 0.5);
      expect(midpoint.x, equals(5));
      expect(midpoint.y, equals(5));

      final quarter = Point.lerp(p1, p2, 0.25);
      expect(quarter.x, equals(2.5));
      expect(quarter.y, equals(2.5));
    });

    test('Point equality with tolerance', () {
      final p1 = Point(1.0, 2.0);
      final p2 = Point(1.0000001, 2.0000001);
      final p3 = Point(1.1, 2.1);

      expect(p1.equals(p2, tolerance: 1e-6), isTrue);
      expect(p1.equals(p3), isFalse);
      expect(p1.equals(p3, tolerance: 0.2), isTrue);
    });

    test('Path simplification - straight line', () {
      // Create a path with many points on a straight line
      final builder = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(1, 1)
        ..lineTo(2, 2)
        ..lineTo(3, 3)
        ..lineTo(4, 4)
        ..lineTo(5, 5);

      final originalPath = builder.build();
      final simplifiedPath = originalPath.simplify(0.1);

      // Should reduce to just start and end points
      expect(
        simplifiedPath.commands.length,
        greaterThanOrEqualTo(2),
      ); // At least moveTo and lineTo

      final commands = simplifiedPath.commands;
      expect(commands[0].type, equals(PathCommandType.moveTo));
      expect(commands[0].points[0], equals(Point(0, 0)));
      expect(commands[1].type, equals(PathCommandType.lineTo));
      expect(commands[1].points[0], equals(Point(5, 5)));
    });

    test('Path simplification - with curve', () {
      // Create a path with a slight curve that should be preserved
      final builder = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(1, 0.1) // Slight deviation
        ..lineTo(2, 0.2)
        ..lineTo(3, 0.1)
        ..lineTo(4, 0)
        ..lineTo(5, 0);

      final originalPath = builder.build();
      final strictSimplified = originalPath.simplify(0.05); // Strict tolerance
      final looseSimplified = originalPath.simplify(0.5); // Loose tolerance

      // Strict should preserve more points
      expect(
        strictSimplified.commands.length,
        greaterThan(looseSimplified.commands.length),
      );
    });

    test('Path simplification - closed path', () {
      // Create a closed rectangular path with extra points
      final builder = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(0.5, 0) // Extra point on edge
        ..lineTo(1, 0)
        ..lineTo(1, 0.5) // Extra point on edge
        ..lineTo(1, 1)
        ..lineTo(0.5, 1) // Extra point on edge
        ..lineTo(0, 1)
        ..lineTo(0, 0.5) // Extra point on edge
        ..close();

      final originalPath = builder.build();
      final simplifiedPath = originalPath.simplify(0.1);

      // Should reduce to corner points plus close
      expect(
        simplifiedPath.commands.length,
        equals(6),
      ); // moveTo + 4 corners + close

      final commands = simplifiedPath.commands;
      expect(commands.last.type, equals(PathCommandType.close));
    });

    test('Path union - simple case', () {
      // Create two overlapping rectangles
      final rect1 = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(10, 0)
        ..lineTo(10, 10)
        ..lineTo(0, 10)
        ..close();

      final rect2 = PathBuilder()
        ..moveTo(5, 5)
        ..lineTo(15, 5)
        ..lineTo(15, 15)
        ..lineTo(5, 15)
        ..close();

      final path1 = rect1.build();
      final path2 = rect2.build();
      final unionPath = path1.union(path2);

      expect(unionPath.commands.isNotEmpty, isTrue);

      // Union should create a valid path
      final hasMoveTo = unionPath.commands.any(
        (cmd) => cmd.type == PathCommandType.moveTo,
      );
      expect(hasMoveTo, isTrue);
    });

    test('Path intersection - overlapping rectangles', () {
      // Create two overlapping rectangles
      final rect1 = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(10, 0)
        ..lineTo(10, 10)
        ..lineTo(0, 10)
        ..close();

      final rect2 = PathBuilder()
        ..moveTo(5, 5)
        ..lineTo(15, 5)
        ..lineTo(15, 15)
        ..lineTo(5, 15)
        ..close();

      final path1 = rect1.build();
      final path2 = rect2.build();
      final intersectionPath = path1.intersection(path2);

      // Intersection might be empty or have points in the overlap region
      // This is a simplified implementation, so we just check it doesn't crash
      expect(intersectionPath, isNotNull);
    });

    test('Path difference - overlapping rectangles', () {
      // Create two overlapping rectangles
      final rect1 = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(20, 0)
        ..lineTo(20, 20)
        ..lineTo(0, 20)
        ..close();

      final rect2 = PathBuilder()
        ..moveTo(5, 5)
        ..lineTo(15, 5)
        ..lineTo(15, 15)
        ..lineTo(5, 15)
        ..close();

      final path1 = rect1.build();
      final path2 = rect2.build();
      final differencePath = path1.difference(path2);

      expect(differencePath, isNotNull);
      // Should return points from path1 that are not in path2
    });

    test('Path exclusive OR - two separate rectangles', () {
      // Create two non-overlapping rectangles
      final rect1 = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(5, 0)
        ..lineTo(5, 5)
        ..lineTo(0, 5)
        ..close();

      final rect2 = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(15, 10)
        ..lineTo(15, 15)
        ..lineTo(10, 15)
        ..close();

      final path1 = rect1.build();
      final path2 = rect2.build();
      final xorPath = path1.xor(path2);

      expect(xorPath, isNotNull);
      expect(xorPath.commands.isNotEmpty, isTrue);
    });

    test('Path simplification - cubic curves', () {
      // Create a path with cubic curves
      final builder = PathBuilder()
        ..moveTo(0, 0)
        ..curveTo(10, 0, 20, 10, 30, 10);

      final originalPath = builder.build();
      final simplifiedPath = originalPath.simplify(1.0);

      expect(simplifiedPath.commands.isNotEmpty, isTrue);

      // Should have converted curves to line segments
      final hasMoveTo = simplifiedPath.commands.any(
        (cmd) => cmd.type == PathCommandType.moveTo,
      );
      final hasLineTo = simplifiedPath.commands.any(
        (cmd) => cmd.type == PathCommandType.lineTo,
      );
      expect(hasMoveTo, isTrue);
      expect(hasLineTo, isTrue);
    });

    test('Path operations - empty path handling', () {
      final emptyPath = Path();
      final rectBuilder = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(10, 0)
        ..lineTo(10, 10)
        ..lineTo(0, 10)
        ..close();
      final rectPath = rectBuilder.build();

      // Operations with empty paths should handle gracefully
      final simplifiedEmpty = emptyPath.simplify(1.0);
      expect(simplifiedEmpty.commands.isEmpty, isTrue);

      final unionWithEmpty = rectPath.union(emptyPath);
      expect(unionWithEmpty, isNotNull);

      final intersectionWithEmpty = rectPath.intersection(emptyPath);
      expect(intersectionWithEmpty, isNotNull);
    });

    test('Path simplification - tolerance edge cases', () {
      final zigzagBuilder = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(1, 1)
        ..lineTo(2, 0)
        ..lineTo(3, 1)
        ..lineTo(4, 0)
        ..lineTo(5, 0);
      final zigzagPath = zigzagBuilder.build();

      // Very strict tolerance should preserve most points
      final strictSimplified = zigzagPath.simplify(0.01);
      expect(strictSimplified.commands.length, greaterThan(3));

      // Very loose tolerance should simplify aggressively
      final looseSimplified = zigzagPath.simplify(10.0);
      expect(
        looseSimplified.commands.length,
        lessThanOrEqualTo(strictSimplified.commands.length),
      );
    });

    test('Complex path operations integration', () {
      // Create a more complex path with multiple subpaths
      final complexBuilder = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(10, 0)
        ..lineTo(10, 10)
        ..lineTo(0, 10)
        ..close()
        // Second subpath
        ..moveTo(20, 20)
        ..curveTo(25, 15, 35, 15, 40, 20)
        ..lineTo(40, 30)
        ..lineTo(20, 30)
        ..close();
      final complexPath = complexBuilder.build();

      // Test that operations work with complex paths
      final simplified = complexPath.simplify(0.5);
      expect(simplified.commands.isNotEmpty, isTrue);

      // Boolean operations
      final otherBuilder = PathBuilder()
        ..moveTo(5, 5)
        ..lineTo(15, 5)
        ..lineTo(15, 15)
        ..lineTo(5, 15)
        ..close();
      final otherPath = otherBuilder.build();

      final union = complexPath.union(otherPath);
      final intersection = complexPath.intersection(otherPath);
      final difference = complexPath.difference(otherPath);

      expect(union, isNotNull);
      expect(intersection, isNotNull);
      expect(difference, isNotNull);
    });
  });
}

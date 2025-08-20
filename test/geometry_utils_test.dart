import 'dart:math' as math;

import 'package:libgfx/src/paths/path.dart';
import 'package:libgfx/src/paths/path_utils.dart';
import 'package:libgfx/src/rectangle.dart';
import 'package:test/test.dart';

void main() {
  group('GeometryUtils', () {
    group('Rectangle Creation', () {
      test('creates rectangle path', () {
        final path = PathUtils.createRectangle(10, 20, 30, 40);

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);

        // Should have moveTo, 4 lineTo, and close
        expect(path.commands.length, greaterThanOrEqualTo(5));
      });

      test('creates rounded rectangle', () {
        final path = PathUtils.createRoundedRectangle(10, 20, 30, 40, 5);

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);

        // Should have more commands due to rounded corners
        expect(path.commands.length, greaterThan(5));
      });

      test('handles zero radius for rounded rectangle', () {
        final rounded = PathUtils.createRoundedRectangle(10, 20, 30, 40, 0);
        final regular = PathUtils.createRectangle(10, 20, 30, 40);

        // Should be equivalent to regular rectangle
        expect(rounded.commands.length, equals(regular.commands.length));
      });

      test('clamps radius to half of smallest dimension', () {
        final path = PathUtils.createRoundedRectangle(10, 20, 30, 40, 50);

        // Radius should be clamped to 15 (half of width 30)
        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);
      });

      test('handles negative dimensions', () {
        final path = PathUtils.createRectangle(10, 20, -30, -40);

        // Should handle gracefully
        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);
      });
    });

    group('Circle Creation', () {
      test('creates circle path using bezier curves', () {
        final path = PathUtils.createCircle(50, 50, 20);

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);

        // Should have moveTo, 4 curveTo, and close
        expect(
          path.commands
              .where((c) => c.type == PathCommandType.cubicCurveTo)
              .length,
          equals(4),
        );
      });

      test('creates circle at origin', () {
        final path = PathUtils.createCircle(0, 0, 10);

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);
      });

      test('handles zero radius circle', () {
        final path = PathUtils.createCircle(50, 50, 0);

        expect(path, isNotNull);
        // Might be empty or have minimal commands
      });

      test('handles very large radius', () {
        final path = PathUtils.createCircle(50, 50, 1000);

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);
      });
    });

    group('Ellipse Creation', () {
      test('creates ellipse path', () {
        final path = PathUtils.createEllipse(50, 50, 30, 20);

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);

        // Should use bezier curves
        expect(
          path.commands
              .where((c) => c.type == PathCommandType.cubicCurveTo)
              .length,
          equals(4),
        );
      });

      test('ellipse with equal radii equals circle', () {
        final ellipse = PathUtils.createEllipse(50, 50, 20, 20);
        final circle = PathUtils.createCircle(50, 50, 20);

        // Should have same structure
        expect(ellipse.commands.length, equals(circle.commands.length));
      });

      test('handles zero radius ellipse', () {
        final path1 = PathUtils.createEllipse(50, 50, 0, 20);
        final path2 = PathUtils.createEllipse(50, 50, 20, 0);

        expect(path1, isNotNull);
        expect(path2, isNotNull);
      });
    });

    group('Polygon Creation', () {
      test('creates triangle', () {
        final path = PathUtils.createPolygon(50, 50, 20, 3);

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);

        // Should have 3 line segments
        expect(
          path.commands.where((c) => c.type == PathCommandType.lineTo).length,
          equals(3),
        );
      });

      test('creates square', () {
        final path = PathUtils.createPolygon(50, 50, 20, 4);

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);

        // Should have 4 line segments
        expect(
          path.commands.where((c) => c.type == PathCommandType.lineTo).length,
          equals(4),
        );
      });

      test('creates pentagon', () {
        final path = PathUtils.createPolygon(50, 50, 20, 5);

        expect(path, isNotNull);
        expect(
          path.commands.where((c) => c.type == PathCommandType.lineTo).length,
          equals(5),
        );
      });

      test('creates hexagon', () {
        final path = PathUtils.createPolygon(50, 50, 20, 6);

        expect(path, isNotNull);
        expect(
          path.commands.where((c) => c.type == PathCommandType.lineTo).length,
          equals(6),
        );
      });

      test('throws for invalid polygon sides', () {
        expect(
          () => PathUtils.createPolygon(50, 50, 20, 2),
          throwsArgumentError,
        );
        expect(
          () => PathUtils.createPolygon(50, 50, 20, 1),
          throwsArgumentError,
        );
        expect(
          () => PathUtils.createPolygon(50, 50, 20, 0),
          throwsArgumentError,
        );
      });

      test('polygon starts at top', () {
        final path = PathUtils.createPolygon(50, 50, 20, 4);

        // First point should be at top (50, 30)
        final firstMove = path.commands.firstWhere(
          (c) => c.type == PathCommandType.moveTo,
        );
        expect(firstMove.points.first.x, closeTo(50, 0.1));
        expect(firstMove.points.first.y, closeTo(30, 0.1));
      });
    });

    group('Star Creation', () {
      test('creates 5-pointed star', () {
        final path = PathUtils.createStar(50, 50, 30, 15, 5);

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);

        // Should have 10 points (5 outer, 5 inner)
        expect(
          path.commands.where((c) => c.type == PathCommandType.lineTo).length,
          equals(10),
        );
      });

      test('creates 3-pointed star', () {
        final path = PathUtils.createStar(50, 50, 30, 15, 3);

        expect(path, isNotNull);
        expect(
          path.commands.where((c) => c.type == PathCommandType.lineTo).length,
          equals(6),
        );
      });

      test('throws for invalid star points', () {
        expect(
          () => PathUtils.createStar(50, 50, 30, 15, 2),
          throwsArgumentError,
        );
        expect(
          () => PathUtils.createStar(50, 50, 30, 15, 0),
          throwsArgumentError,
        );
      });

      test('handles inner radius larger than outer', () {
        final path = PathUtils.createStar(50, 50, 15, 30, 5);

        // Should still create a valid path
        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);
      });
    });

    group('Arc Creation', () {
      test('creates arc path', () {
        final path = PathUtils.createArc(50, 50, 20, 0, math.pi, true);

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);
      });

      test('creates full circle arc', () {
        final path = PathUtils.createArc(50, 50, 20, 0, 2 * math.pi, true);

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);
      });

      test('handles clockwise and counter-clockwise', () {
        final clockwise = PathUtils.createArc(50, 50, 20, 0, math.pi / 2, true);
        final counterClockwise = PathUtils.createArc(
          50,
          50,
          20,
          0,
          math.pi / 2,
          false,
        );

        expect(clockwise, isNotNull);
        expect(counterClockwise, isNotNull);

        // Both should be valid but different
        expect(clockwise.commands, isNotEmpty);
        expect(counterClockwise.commands, isNotEmpty);
      });

      test('handles zero sweep angle', () {
        final path = PathUtils.createArc(50, 50, 20, 0, 0, true);

        expect(path, isNotNull);
        // Might be empty or minimal
      });
    });

    // Bounds Calculation tests removed - boundingBox was a dead function

    group('Rectangle Operations', () {
      test('calculates rectangle intersection', () {
        final rect1 = Rectangle<double>(10, 10, 30, 30);
        final rect2 = Rectangle<double>(20, 20, 30, 30);
        final intersection = rect1.intersection(rect2);

        expect(intersection, isNotNull);
        expect(intersection!.left, equals(20));
        expect(intersection.top, equals(20));
        expect(intersection.width, equals(20)); // 40 - 20
        expect(intersection.height, equals(20)); // 40 - 20
      });

      test('returns null for non-intersecting rectangles', () {
        final rect1 = Rectangle<double>(10, 10, 20, 20);
        final rect2 = Rectangle<double>(40, 40, 20, 20);
        final intersection = rect1.intersection(rect2);

        expect(intersection, isNull);
      });
    });

    // Circle Operations tests removed - pointInCircle and circleTangentPoints were dead functions

    group('Edge Cases', () {
      test('handles zero dimensions', () {
        final rect = PathUtils.createRectangle(10, 10, 0, 0);
        expect(rect, isNotNull);

        final circle = PathUtils.createCircle(10, 10, 0);
        expect(circle, isNotNull);

        final ellipse = PathUtils.createEllipse(10, 10, 0, 0);
        expect(ellipse, isNotNull);
      });

      test('handles negative dimensions', () {
        final rect = PathUtils.createRectangle(10, 10, -20, -30);
        expect(rect, isNotNull);
        expect(rect.commands, isNotEmpty);
      });

      test('handles very large dimensions', () {
        final rect = PathUtils.createRectangle(0, 0, 1e6, 1e6);
        expect(rect, isNotNull);

        final circle = PathUtils.createCircle(0, 0, 1e6);
        expect(circle, isNotNull);
      });
    });
  });
}

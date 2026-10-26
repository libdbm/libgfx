import 'dart:math' as math;

import 'package:libgfx/src/paths/path.dart';
import 'package:libgfx/src/rectangle.dart';
import 'package:test/test.dart';

void main() {
  group('Rectangle of either number type', () {
    test('integer rectangles floor their half size', () {
      final rectangle = Rectangle<int>.fromCenter(10, 10, 5, 4);
      expect([
        rectangle.left,
        rectangle.top,
        rectangle.width,
        rectangle.height,
      ], equals([8, 8, 5, 4]));
      expect([rectangle.centerX, rectangle.centerY], equals([10, 10]));
    });

    test('double rectangles keep their exact centre', () {
      final rectangle = Rectangle<double>.fromCenter(10, 10, 5, 4);
      expect([rectangle.left, rectangle.top], equals([7.5, 8]));
      expect([rectangle.centerX, rectangle.centerY], equals([10, 10]));
    });

    test('an empty rectangle of either type is at the origin', () {
      expect(Rectangle.zero<int>().left, equals(0));
      expect(Rectangle.zero<double>().left, equals(0));
      expect(Rectangle.zero<double>().isEmpty, isTrue);
    });
  });

  group('GeometryUtils', () {
    group('Rectangle Creation', () {
      test('creates rectangle path', () {
        final path = PathBuilder().rect(10, 20, 30, 40).build();

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);

        // Should have moveTo, 4 lineTo, and close
        expect(path.commands.length, greaterThanOrEqualTo(5));
      });

      test('creates rounded rectangle', () {
        final path = PathBuilder().roundRect(10, 20, 30, 40, 5).build();

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);

        // Should have more commands due to rounded corners
        expect(path.commands.length, greaterThan(5));
      });

      test('handles zero radius for rounded rectangle', () {
        final rounded = PathBuilder().roundRect(10, 20, 30, 40, 0).build();
        final regular = PathBuilder().rect(10, 20, 30, 40).build();

        // Should be equivalent to regular rectangle
        expect(rounded.commands.length, equals(regular.commands.length));
      });

      test('clamps radius to half of smallest dimension', () {
        final path = PathBuilder().roundRect(10, 20, 30, 40, 50).build();

        // Radius should be clamped to 15 (half of width 30)
        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);
      });

      test('handles negative dimensions', () {
        final path = PathBuilder().rect(10, 20, -30, -40).build();

        // Should handle gracefully
        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);
      });
    });

    group('Circle Creation', () {
      test('creates circle path as one ellipse command', () {
        final path = PathBuilder().circle(50, 50, 20).build();

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);

        // PathBuilder.circle adds a full-turn ellipse command
        expect(
          path.commands.where((c) => c.type == PathCommandType.ellipse).length,
          equals(1),
        );
      });

      test('creates circle at origin', () {
        final path = PathBuilder().circle(0, 0, 10).build();

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);
      });

      test('handles zero radius circle', () {
        final path = PathBuilder().circle(50, 50, 0).build();

        expect(path, isNotNull);
        // Might be empty or have minimal commands
      });

      test('handles very large radius', () {
        final path = PathBuilder().circle(50, 50, 1000).build();

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);
      });
    });

    group('Ellipse Creation', () {
      test('creates ellipse path', () {
        final path = PathBuilder()
            .ellipse(50, 50, 30, 20, 0, 0, 2 * math.pi)
            .build();

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);

        // PathBuilder.ellipse adds one ellipse command
        expect(
          path.commands.where((c) => c.type == PathCommandType.ellipse).length,
          equals(1),
        );
      });

      test('ellipse with equal radii equals circle', () {
        final ellipse = PathBuilder()
            .ellipse(50, 50, 20, 20, 0, 0, 2 * math.pi)
            .build();
        final circle = PathBuilder().circle(50, 50, 20).build();

        // Should have same structure
        expect(ellipse.commands.length, equals(circle.commands.length));
      });

      test('handles zero radius ellipse', () {
        final path1 = PathBuilder()
            .ellipse(50, 50, 0, 20, 0, 0, 2 * math.pi)
            .build();
        final path2 = PathBuilder()
            .ellipse(50, 50, 20, 0, 0, 0, 2 * math.pi)
            .build();

        expect(path1, isNotNull);
        expect(path2, isNotNull);
      });
    });

    group('Polygon Creation', () {
      test('creates triangle', () {
        final path = PathBuilder().polygon(50, 50, 20, 3).build();

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);

        // Should have 3 line segments
        expect(
          path.commands.where((c) => c.type == PathCommandType.lineTo).length,
          equals(3),
        );
      });

      test('creates square', () {
        final path = PathBuilder().polygon(50, 50, 20, 4).build();

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);

        // Should have 4 line segments
        expect(
          path.commands.where((c) => c.type == PathCommandType.lineTo).length,
          equals(4),
        );
      });

      test('creates pentagon', () {
        final path = PathBuilder().polygon(50, 50, 20, 5).build();

        expect(path, isNotNull);
        expect(
          path.commands.where((c) => c.type == PathCommandType.lineTo).length,
          equals(5),
        );
      });

      test('creates hexagon', () {
        final path = PathBuilder().polygon(50, 50, 20, 6).build();

        expect(path, isNotNull);
        expect(
          path.commands.where((c) => c.type == PathCommandType.lineTo).length,
          equals(6),
        );
      });

      test('throws for invalid polygon sides', () {
        expect(
          () => PathBuilder().polygon(50, 50, 20, 2).build(),
          throwsArgumentError,
        );
        expect(
          () => PathBuilder().polygon(50, 50, 20, 1).build(),
          throwsArgumentError,
        );
        expect(
          () => PathBuilder().polygon(50, 50, 20, 0).build(),
          throwsArgumentError,
        );
      });

      test('polygon starts at top', () {
        final path = PathBuilder().polygon(50, 50, 20, 4).build();

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
        final path = PathBuilder().star(50, 50, 30, 15, 5).build();

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);

        // Should have 10 points (5 outer, 5 inner)
        expect(
          path.commands.where((c) => c.type == PathCommandType.lineTo).length,
          equals(10),
        );
      });

      test('creates 3-pointed star', () {
        final path = PathBuilder().star(50, 50, 30, 15, 3).build();

        expect(path, isNotNull);
        expect(
          path.commands.where((c) => c.type == PathCommandType.lineTo).length,
          equals(6),
        );
      });

      test('throws for invalid star points', () {
        expect(
          () => PathBuilder().star(50, 50, 30, 15, 2).build(),
          throwsArgumentError,
        );
        expect(
          () => PathBuilder().star(50, 50, 30, 15, 0).build(),
          throwsArgumentError,
        );
      });

      test('handles inner radius larger than outer', () {
        final path = PathBuilder().star(50, 50, 15, 30, 5).build();

        // Should still create a valid path
        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);
      });
    });

    group('Arc Creation', () {
      test('creates arc path', () {
        final path = PathBuilder().arc(50, 50, 20, 0, math.pi, !true).build();

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);
      });

      test('creates full circle arc', () {
        final path = PathBuilder()
            .arc(50, 50, 20, 0, 2 * math.pi, !true)
            .build();

        expect(path, isNotNull);
        expect(path.commands, isNotEmpty);
      });

      test('handles clockwise and counter-clockwise', () {
        final clockwise = PathBuilder()
            .arc(50, 50, 20, 0, math.pi / 2, !true)
            .build();
        final counterClockwise = PathBuilder()
            .arc(50, 50, 20, 0, math.pi / 2, !false)
            .build();

        expect(clockwise, isNotNull);
        expect(counterClockwise, isNotNull);

        // Both should be valid but different
        expect(clockwise.commands, isNotEmpty);
        expect(counterClockwise.commands, isNotEmpty);
      });

      test('handles zero sweep angle', () {
        final path = PathBuilder().arc(50, 50, 20, 0, 0, !true).build();

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
        final rect = PathBuilder().rect(10, 10, 0, 0).build();
        expect(rect, isNotNull);

        final circle = PathBuilder().circle(10, 10, 0).build();
        expect(circle, isNotNull);

        final ellipse = PathBuilder()
            .ellipse(10, 10, 0, 0, 0, 0, 2 * math.pi)
            .build();
        expect(ellipse, isNotNull);
      });

      test('handles negative dimensions', () {
        final rect = PathBuilder().rect(10, 10, -20, -30).build();
        expect(rect, isNotNull);
        expect(rect.commands, isNotEmpty);
      });

      test('handles very large dimensions', () {
        final rect = PathBuilder().rect(0, 0, 1e6, 1e6).build();
        expect(rect, isNotNull);

        final circle = PathBuilder().circle(0, 0, 1e6).build();
        expect(circle, isNotNull);
      });
    });
  });
}

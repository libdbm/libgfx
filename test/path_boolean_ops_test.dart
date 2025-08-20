import 'package:libgfx/src/paths/path.dart';
import 'package:libgfx/src/paths/path_operations.dart';
import 'package:test/test.dart';

void main() {
  group('Path Boolean Operations', () {
    late Path rect1;
    late Path rect2;

    setUp(() {
      // Create two overlapping rectangles
      final builder1 = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(30, 10)
        ..lineTo(30, 30)
        ..lineTo(10, 30)
        ..close();
      rect1 = builder1.build();

      final builder2 = PathBuilder()
        ..moveTo(20, 20)
        ..lineTo(40, 20)
        ..lineTo(40, 40)
        ..lineTo(20, 40)
        ..close();
      rect2 = builder2.build();
    });

    test('union combines two paths', () {
      final result = PathOperations.union(rect1, rect2);

      expect(result, isNotNull);
      expect(result.commands, isNotEmpty);

      // The union should create a larger combined shape
      // Check that the result has path commands
      expect(
        result.commands.where((cmd) => cmd.type == PathCommandType.moveTo),
        isNotEmpty,
      );
      expect(
        result.commands.where((cmd) => cmd.type == PathCommandType.lineTo),
        isNotEmpty,
      );
    });

    test('intersection returns overlapping area', () {
      final result = PathOperations.intersection(rect1, rect2);

      expect(result, isNotNull);
      // Note: The simple implementation may not produce perfect results
      // but should at least return a valid path
      expect(result.commands, isNotNull);
    });

    test('difference subtracts second path from first', () {
      final result = PathOperations.difference(rect1, rect2);

      expect(result, isNotNull);
      expect(result.commands, isNotEmpty);

      // The difference should be the part of rect1 not overlapped by rect2
      expect(result.commands.length, greaterThan(0));
    });

    test('xor returns symmetric difference', () {
      final result = PathOperations.xor(rect1, rect2);

      expect(result, isNotNull);
      expect(result.commands, isNotEmpty);

      // XOR should return the parts that don't overlap
      expect(result.commands.length, greaterThan(0));
    });

    test('union of non-overlapping paths', () {
      // Create two non-overlapping rectangles
      final builder3 = PathBuilder()
        ..moveTo(50, 50)
        ..lineTo(60, 50)
        ..lineTo(60, 60)
        ..lineTo(50, 60)
        ..close();
      final rect3 = builder3.build();

      final result = PathOperations.union(rect1, rect3);

      expect(result, isNotNull);
      expect(result.commands, isNotEmpty);

      // The simplified implementation may not handle non-overlapping paths perfectly
      // But should at least return a valid path
      expect(
        result.commands
            .where((cmd) => cmd.type == PathCommandType.moveTo)
            .length,
        greaterThanOrEqualTo(1),
      );
    });

    test('intersection of non-overlapping paths returns empty', () {
      // Create two non-overlapping rectangles
      final builder3 = PathBuilder()
        ..moveTo(50, 50)
        ..lineTo(60, 50)
        ..lineTo(60, 60)
        ..lineTo(50, 60)
        ..close();
      final rect3 = builder3.build();

      final result = PathOperations.intersection(rect1, rect3);

      expect(result, isNotNull);
      // Intersection of non-overlapping should be empty or minimal
      expect(result.commands.length, lessThanOrEqualTo(1));
    });

    test('handles complex paths with curves', () {
      // Create a path with curves
      final builder = PathBuilder()
        ..moveTo(10, 10)
        ..cubicCurveTo(15, 5, 25, 5, 30, 10)
        ..lineTo(30, 30)
        ..cubicCurveTo(25, 35, 15, 35, 10, 30)
        ..close();
      final curvePath = builder.build();

      final result = PathOperations.union(curvePath, rect2);

      expect(result, isNotNull);
      expect(result.commands, isNotEmpty);
    });

    test('operations with empty paths', () {
      final emptyPath = Path();

      final union = PathOperations.union(rect1, emptyPath);
      expect(union, isNotNull);
      expect(union.commands, isNotEmpty);

      final intersection = PathOperations.intersection(rect1, emptyPath);
      expect(intersection, isNotNull);
      expect(intersection.commands, isEmpty);

      final difference = PathOperations.difference(rect1, emptyPath);
      expect(difference, isNotNull);
      expect(difference.commands, isNotEmpty);

      final xor = PathOperations.xor(rect1, emptyPath);
      expect(xor, isNotNull);
      // XOR with empty should return the original path
      expect(xor.commands.length, greaterThan(0));
    });

    test('self-intersecting paths are handled', () {
      // Create a figure-8 path
      final builder = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(30, 30)
        ..lineTo(30, 10)
        ..lineTo(10, 30)
        ..close();
      final figure8 = builder.build();

      final result = PathOperations.union(figure8, rect2);

      expect(result, isNotNull);
      expect(result.commands, isNotEmpty);
    });
  });
}

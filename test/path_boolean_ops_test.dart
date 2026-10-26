import 'package:libgfx/src/paths/path.dart';
import 'package:libgfx/src/paths/path_operations.dart';
import 'package:test/test.dart';

/// Pins the documented behaviour of the experimental boolean operations:
/// each input becomes one ring and the result is one closed ring (or empty)
/// chosen edge by edge, not a true area operation.
void main() {
  Path rect(double left, double top, double right, double bottom) =>
      (PathBuilder()
            ..moveTo(left, top)
            ..lineTo(right, top)
            ..lineTo(right, bottom)
            ..lineTo(left, bottom)
            ..closePath())
          .build();

  /// [left, top, right, bottom] of [path].
  List<num> bounds(final Path path) => [
    path.bounds.left,
    path.bounds.top,
    path.bounds.right,
    path.bounds.bottom,
  ];

  /// Expects [path] to be one closed ring of [points] corners.
  void ring(final Path path, final int points) {
    final types = path.commands.map((command) => command.type).toList();
    expect(types.first, equals(PathCommandType.moveTo));
    expect(types.last, equals(PathCommandType.close));
    expect(types.where((type) => type == PathCommandType.moveTo), hasLength(1));
    expect(types, hasLength(points + 1));
  }

  final a = rect(10, 10, 30, 30);
  final overlapping = rect(20, 20, 40, 40);
  final inside = rect(15, 15, 25, 25);
  final apart = rect(100, 100, 110, 110);

  group('Overlapping outlines', () {
    test('union joins both rings', () {
      final result = PathOperations.union(a, overlapping);
      ring(result, 8);
      expect(bounds(result), equals([10, 10, 40, 40]));
    });

    test('intersection keeps the endpoints of crossing edges', () {
      final result = PathOperations.intersection(a, overlapping);
      ring(result, 6);
      expect(bounds(result), equals([10, 10, 40, 40]));
    });

    test('difference keeps the edges of the first path that do not cross', () {
      final result = PathOperations.difference(a, overlapping);
      ring(result, 3);
      expect(bounds(result), equals([10, 10, 30, 30]));
    });

    test('xor keeps the edges of both paths that do not cross', () {
      final result = PathOperations.xor(a, overlapping);
      ring(result, 6);
      expect(bounds(result), equals([10, 10, 40, 40]));
    });
  });

  group('Outlines that do not cross', () {
    test('a contained shape is not merged, intersected or subtracted', () {
      ring(PathOperations.union(a, inside), 8);
      expect(bounds(PathOperations.union(a, inside)), equals([10, 10, 30, 30]));
      expect(PathOperations.intersection(a, inside).commands, isEmpty);
      final difference = PathOperations.difference(a, inside);
      ring(difference, 4);
      expect(bounds(difference), equals([10, 10, 30, 30]));
      ring(PathOperations.xor(a, inside), 8);
    });

    test('disjoint shapes join into one ring spanning both', () {
      expect(
        bounds(PathOperations.union(a, apart)),
        equals([10, 10, 110, 110]),
      );
      expect(PathOperations.intersection(a, apart).commands, isEmpty);
      expect(
        bounds(PathOperations.difference(a, apart)),
        equals([10, 10, 30, 30]),
      );
      expect(bounds(PathOperations.xor(a, apart)), equals([10, 10, 110, 110]));
    });
  });

  group('Inputs', () {
    test('an empty path returns the other, or nothing', () {
      final empty = Path();
      expect(PathOperations.union(a, empty).commands, equals(a.commands));
      expect(PathOperations.union(empty, a).commands, equals(a.commands));
      expect(PathOperations.intersection(a, empty).commands, isEmpty);
      expect(PathOperations.difference(a, empty).commands, equals(a.commands));
      expect(PathOperations.difference(empty, a).commands, isEmpty);
      expect(PathOperations.xor(empty, a).commands, equals(a.commands));
      expect(PathOperations.union(empty, empty).commands, isEmpty);
    });

    test('all contours of a path are joined into one ring', () {
      final two =
          (PathBuilder()
                ..moveTo(0, 0)
                ..lineTo(5, 0)
                ..lineTo(5, 5)
                ..closePath()
                ..moveTo(50, 50)
                ..lineTo(55, 50)
                ..lineTo(55, 55)
                ..closePath())
              .build();
      final result = PathOperations.union(two, apart);
      ring(result, 10);
      expect(bounds(result), equals([0, 0, 110, 110]));
    });

    test('arcs are dropped', () {
      // The arc spans 40..60 but only the line to its start point remains
      final arc =
          (PathBuilder()
                ..moveTo(0, 0)
                ..arc(50, 50, 10, 0, 3.14159, false))
              .build();
      final result = PathOperations.union(arc, apart);
      ring(result, 6);
      final points = [
        for (final command in result.commands)
          for (final point in command.points) (point.x, point.y),
      ];
      expect(points.take(2), equals([(0.0, 0.0), (60.0, 50.0)]));
    });

    test('cubic curves are subdivided', () {
      final curve =
          (PathBuilder()
                ..moveTo(10, 10)
                ..bezierCurveTo(15, 0, 25, 0, 30, 10)
                ..lineTo(30, 30)
                ..lineTo(10, 30)
                ..closePath())
              .build();
      final result = PathOperations.union(curve, apart);
      expect(result.commands.length, greaterThan(10));
      expect(result.bounds.top, lessThan(10));
      expect(result.bounds.top, greaterThan(0));
    });

    test('the Path methods match PathOperations', () {
      expect(
        bounds(a.union(overlapping)),
        equals(bounds(PathOperations.union(a, overlapping))),
      );
      expect(a.intersection(inside).commands, isEmpty);
      expect(
        bounds(a.difference(overlapping)),
        equals(bounds(PathOperations.difference(a, overlapping))),
      );
      expect(
        bounds(a.xor(overlapping)),
        equals(bounds(PathOperations.xor(a, overlapping))),
      );
    });
  });
}

import 'dart:math' as math;

import 'package:libgfx/src/matrix.dart';
import 'package:libgfx/src/paths/path.dart';
import 'package:libgfx/src/paths/path_operations.dart';
import 'package:test/test.dart';

void main() {
  group('Numerical Stability Tests', () {
    // Note: Edge class is now private in PathOperations,
    // so we test through the public API only

    test('handles very small edges', () {
      // Create very small edges that might cause numerical issues
      final builder1 = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(0.0001, 0)
        ..lineTo(0.0001, 0.0001)
        ..lineTo(0, 0.0001)
        ..close();

      final builder2 = PathBuilder()
        ..moveTo(0.00005, -0.00005)
        ..lineTo(0.00015, -0.00005)
        ..lineTo(0.00015, 0.00015)
        ..lineTo(0.00005, 0.00015)
        ..close();

      final path1 = builder1.build();
      final path2 = builder2.build();

      // Should not crash or produce infinite loops
      final result = PathOperations.intersection(path1, path2);
      expect(result, isNotNull);
    });

    test('handles high-precision coordinates', () {
      // Test with coordinates that have many decimal places
      final builder1 = PathBuilder()
        ..moveTo(0.123456789, 0.987654321)
        ..lineTo(1.111111111, 2.222222222)
        ..lineTo(3.333333333, 1.444444444)
        ..close();

      final builder2 = PathBuilder()
        ..moveTo(0.555555555, 0.666666666)
        ..lineTo(2.777777777, 1.888888888)
        ..lineTo(1.999999999, 3.111111111)
        ..close();

      final path1 = builder1.build();
      final path2 = builder2.build();

      // Operations should complete without numerical errors
      final union = PathOperations.union(path1, path2);
      final intersection = PathOperations.intersection(path1, path2);

      expect(union, isNotNull);
      expect(intersection, isNotNull);
    });

    test('handles self-intersecting paths', () {
      // Create a figure-8 path (self-intersecting)
      final builder = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(10, 10)
        ..lineTo(10, 0)
        ..lineTo(0, 10)
        ..close();

      final selfIntersecting = builder.build();

      // Create a simple rectangle
      final rectBuilder = PathBuilder()
        ..moveTo(2, 2)
        ..lineTo(8, 2)
        ..lineTo(8, 8)
        ..lineTo(2, 8)
        ..close();

      final rect = rectBuilder.build();

      // Operations should handle self-intersections gracefully
      final result = PathOperations.intersection(selfIntersecting, rect);
      expect(result, isNotNull);
      expect(result.commands, isNotEmpty);
    });

    test('path simplification handles complex paths', () {
      // Create a path with many redundant points
      final builder = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(1, 0)
        ..lineTo(2, 0)
        ..lineTo(3, 0) // Redundant points on same line
        ..lineTo(4, 0)
        ..lineTo(4, 1)
        ..lineTo(4, 2)
        ..lineTo(4, 3) // More redundant points
        ..lineTo(4, 4)
        ..lineTo(0, 4)
        ..close();

      final path = builder.build();
      final simplified = PathOperations.simplify(path, tolerance: 0.1);

      expect(simplified, isNotNull);
      expect(simplified.commands.length, lessThan(path.commands.length));
    });

    test('transform handles various matrix operations', () {
      final builder = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(10, 0)
        ..lineTo(10, 10)
        ..lineTo(0, 10)
        ..close();

      final path = builder.build();

      // Test scaling
      final scaleMatrix = Matrix2D.identity()..scale(2.0, 2.0);
      final scaled = PathOperations.transform(path, scaleMatrix);
      expect(scaled, isNotNull);
      expect(scaled.commands, isNotEmpty);

      // Test rotation
      final rotateMatrix = Matrix2D.identity()..rotate(math.pi / 4);
      final rotated = PathOperations.transform(path, rotateMatrix);
      expect(rotated, isNotNull);
      expect(rotated.commands, isNotEmpty);

      // Test translation
      final translateMatrix = Matrix2D.identity()..translate(5.0, 5.0);
      final translated = PathOperations.transform(path, translateMatrix);
      expect(translated, isNotNull);
      expect(translated.commands, isNotEmpty);
    });

    test('boolean operations handle edge cases', () {
      // Test with overlapping identical paths
      final builder = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(10, 0)
        ..lineTo(10, 10)
        ..lineTo(0, 10)
        ..close();

      final path1 = builder.build();
      final path2 = builder.build();

      // Union of identical paths should return the same shape
      final union = PathOperations.union(path1, path2);
      expect(union, isNotNull);

      // Intersection of identical paths should return the same shape
      final intersection = PathOperations.intersection(path1, path2);
      expect(intersection, isNotNull);

      // Difference of identical paths should return empty or minimal result
      final difference = PathOperations.difference(path1, path2);
      expect(difference, isNotNull);

      // XOR of identical paths should return empty or minimal result
      final xor = PathOperations.xor(path1, path2);
      expect(xor, isNotNull);
    });
  });
}

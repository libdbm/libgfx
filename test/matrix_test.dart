import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';
import 'package:test/test.dart';

void main() {
  group('Matrix2D', () {
    test('identity matrix creation', () {
      final matrix = Matrix2D.identity();

      // Check matrix components
      expect(matrix.a, equals(1.0));
      expect(matrix.b, equals(0.0));
      expect(matrix.c, equals(0.0));
      expect(matrix.d, equals(1.0));
      expect(matrix.tx, equals(0.0));
      expect(matrix.ty, equals(0.0));

      // Test with a point transformation - identity should not change the point
      final point = Point(10.0, 20.0);
      final transformed = matrix.transform(point);

      expect(transformed.x, equals(10.0));
      expect(transformed.y, equals(20.0));
    });

    test('translation', () {
      final matrix = Matrix2D.identity();
      matrix.translate(10.0, 20.0);

      final point = Point(5.0, 5.0);
      final transformed = matrix.transform(point);

      expect(transformed.x, equals(15.0));
      expect(transformed.y, equals(25.0));
    });

    test('multiple translations', () {
      final matrix = Matrix2D.identity();
      matrix.translate(10.0, 20.0);
      matrix.translate(5.0, 10.0);

      final point = Point(0.0, 0.0);
      final transformed = matrix.transform(point);

      expect(transformed.x, equals(15.0));
      expect(transformed.y, equals(30.0));
    });

    test('scaling', () {
      final matrix = Matrix2D.identity();
      matrix.scale(2.0, 3.0);

      final point = Point(10.0, 20.0);
      final transformed = matrix.transform(point);

      expect(transformed.x, equals(20.0));
      expect(transformed.y, equals(60.0));
    });

    test('uniform 2D scaling', () {
      final matrix = Matrix2D.identity();
      matrix.scale(2.5);

      final point = Point(10.0, 20.0);
      final transformed = matrix.transform(point);

      expect(transformed.x, equals(25.0));
      expect(transformed.y, equals(50.0));
    });

    test('non-uniform 2D scaling', () {
      final matrix = Matrix2D.identity();
      matrix.scale(2.0, 3.0);

      final point = Point(5.0, 10.0);
      final transformed = matrix.transform(point);

      expect(transformed.x, equals(10.0));
      expect(transformed.y, equals(30.0));
    });

    test('rotation', () {
      final matrix = Matrix2D.identity();
      final angle = math.pi / 2; // 90 degrees
      matrix.rotate(angle);

      final point = Point(10.0, 0.0);
      final transformed = matrix.transform(point);

      // 90 degree rotation should map (10, 0) to (0, 10)
      expect(transformed.x, closeTo(0.0, 1e-10));
      expect(transformed.y, closeTo(10.0, 1e-10));
    });

    test('point transformation', () {
      final matrix = Matrix2D.identity();
      matrix.translate(10.0, 20.0);
      matrix.scale(2.0, 3.0);

      final point = Point(5.0, 10.0);
      final transformed = matrix.transform(point);

      // Expected: scale first (5*2=10, 10*3=30), then translate (10+10=20, 30+20=50)
      expect(transformed.x, equals(20.0));
      expect(transformed.y, equals(50.0));
    });

    test('matrix multiplication', () {
      final a = Matrix2D.identity();
      a.translate(10.0, 20.0);

      final b = Matrix2D.identity();
      b.scale(2.0, 3.0);

      final result = a * b;

      // Test the combined transformation
      final point = Point(5.0, 5.0);
      final transformed = result.transform(point);

      // Should scale then translate: (5*2+10=20, 5*3+20=35)
      expect(transformed.x, equals(20.0));
      expect(transformed.y, equals(35.0));
    });

    test('matrix inversion', () {
      final matrix = Matrix2D.identity();
      matrix.translate(10.0, 20.0);
      matrix.scale(2.0, 3.0);

      matrix.invert();

      // Inverse should undo the transformations
      final point = Point(20.0, 50.0);
      final inverted = matrix.transform(point);

      // Should get back close to (5, 10)
      expect(inverted.x, closeTo(5.0, 1e-10));
      expect(inverted.y, closeTo(10.0, 1e-10));
    });

    test('clone creates independent copy', () {
      final original = Matrix2D.identity();
      original.translate(10.0, 20.0);

      final copy = original.clone();
      copy.scale(2.0, 2.0);

      // Test that original is not affected by changes to copy
      final point = Point(5.0, 5.0);
      final originalTransformed = original.transform(point);
      final copyTransformed = copy.transform(point);

      // Original: just translation
      expect(originalTransformed.x, equals(15.0));
      expect(originalTransformed.y, equals(25.0));

      // Copy: translation then scale
      expect(copyTransformed.x, equals(20.0));
      expect(copyTransformed.y, equals(30.0));
    });

    test('combined transformations', () {
      final matrix = Matrix2D.identity();

      // Apply transformations in order: translate, rotate, scale
      matrix.translate(100.0, 100.0);
      matrix.rotate(math.pi / 2); // 90 degrees
      matrix.scale(2.0, 2.0);

      // Transform a point
      final point = Point(10.0, 0.0);
      final transformed = matrix.transform(point);

      // Expected: scale (20, 0), rotate (0, 20), translate (100, 120)
      expect(transformed.x, closeTo(100.0, 1e-10));
      expect(transformed.y, closeTo(120.0, 1e-10));
    });

    test('matrix copy constructor', () {
      final original = Matrix2D.identity();
      original.translate(5.0, 10.0);
      original.rotate(math.pi / 6);

      final copy = Matrix2D.copy(original);

      // Both should transform points the same way
      final point = Point(1.0, 0.0);
      final originalTransformed = original.transform(point);
      final copyTransformed = copy.transform(point);

      expect(copyTransformed.x, equals(originalTransformed.x));
      expect(copyTransformed.y, equals(originalTransformed.y));
    });

    test('determinant calculation', () {
      final matrix = Matrix2D.identity();
      expect(matrix.determinant, equals(1.0));

      matrix.scale(2.0, 3.0);
      expect(matrix.determinant, equals(6.0));

      // Negative determinant (flipped)
      matrix.scale(-1.0, 1.0);
      expect(matrix.determinant, equals(-6.0));
    });

    test('isIdentity check', () {
      final matrix = Matrix2D.identity();
      expect(matrix.isIdentity, isTrue);

      matrix.translate(0.00000000001, 0.0);
      expect(matrix.isIdentity, isTrue); // Within tolerance

      matrix.translate(1.0, 0.0);
      expect(matrix.isIdentity, isFalse);
    });

    test('inverse method returns new matrix', () {
      final matrix = Matrix2D.identity();
      matrix.translate(10.0, 20.0);
      matrix.scale(2.0, 3.0);

      final inverse = matrix.inverse();

      // Original should not be modified
      expect(matrix.tx, equals(10.0));
      expect(matrix.ty, equals(20.0));

      // Inverse should undo the transformations
      final point = Point(20.0, 50.0);
      final inverted = inverse.transform(point);

      expect(inverted.x, closeTo(5.0, 1e-10));
      expect(inverted.y, closeTo(10.0, 1e-10));
    });

    test('shear transformation', () {
      final matrix = Matrix2D.identity();
      matrix.shear(0.5, 0.0); // Shear in X direction

      final point = Point(0.0, 10.0);
      final transformed = matrix.transform(point);

      // Shear should offset X based on Y value
      expect(transformed.x, equals(5.0)); // 0 + 0.5 * 10
      expect(transformed.y, equals(10.0));
    });

    test('transformVector ignores translation', () {
      final matrix = Matrix2D.identity();
      matrix.translate(100.0, 200.0);
      matrix.scale(2.0, 3.0);

      final vector = Point(10.0, 20.0);
      final transformed = matrix.transformVector(vector);

      // Should only apply scale, not translation
      expect(transformed.x, equals(20.0));
      expect(transformed.y, equals(60.0));
    });

    test('setTransform method', () {
      final matrix = Matrix2D.identity();
      matrix.setTransform(50.0, 100.0, math.pi / 4, 2.0, 3.0);

      // Check translation components
      expect(matrix.tx, equals(50.0));
      expect(matrix.ty, equals(100.0));

      // Transform a point to verify the combined transformation
      final point = Point(1.0, 0.0);
      final transformed = matrix.transform(point);

      // Should apply scale, rotation, then translation
      final expectedX = 50.0 + 2.0 * math.cos(math.pi / 4);
      final expectedY = 100.0 + 2.0 * math.sin(math.pi / 4);

      expect(transformed.x, closeTo(expectedX, 1e-10));
      expect(transformed.y, closeTo(expectedY, 1e-10));
    });

    test('matrix equality', () {
      final m1 = Matrix2D.identity();
      final m2 = Matrix2D.identity();

      expect(m1 == m2, isTrue);

      m1.translate(10.0, 20.0);
      expect(m1 == m2, isFalse);

      m2.translate(10.0, 20.0);
      expect(m1 == m2, isTrue);
    });

    test('non-invertible matrix', () {
      final matrix = Matrix2D(1.0, 0.0, 1.0, 0.0, 0.0, 0.0); // Determinant = 0
      expect(matrix.isInvertible, isFalse);

      final success = matrix.invert();
      expect(success, isFalse);

      // Matrix should be set to identity when not invertible (for numerical stability)
      expect(matrix.a, equals(1.0));
      expect(matrix.b, equals(0.0));
      expect(matrix.c, equals(0.0));
      expect(matrix.d, equals(1.0));
      expect(matrix.tx, equals(0.0));
      expect(matrix.ty, equals(0.0));
    });
  });
}

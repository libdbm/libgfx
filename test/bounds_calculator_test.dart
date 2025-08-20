import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/clipping/bounds_calculator.dart';
import 'package:test/test.dart';

void main() {
  group('BoundsCalculator', () {
    group('Cubic Bezier Extrema', () {
      test('calculates extrema for U-shaped curve', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..cubicCurveTo(100, 0, 100, 100, 0, 100);

        final bounds = BoundsCalculator.boundsOf(
          path.build(),
          Matrix2D.identity(),
        );

        // The curve should bulge to the right, creating an extrema at x=75
        expect(bounds.left, equals(0.0));
        expect(bounds.right, equals(75.0));
        expect(bounds.top, equals(0.0));
        expect(bounds.bottom, equals(100.0));
      });

      test('calculates extrema for S-shaped curve', () {
        final path = PathBuilder()
          ..moveTo(0, 50)
          ..cubicCurveTo(50, 0, 50, 100, 100, 50);

        final bounds = BoundsCalculator.boundsOf(
          path.build(),
          Matrix2D.identity(),
        );

        // S-curve should have y extrema beyond the control points
        expect(bounds.left, equals(0.0));
        expect(bounds.right, equals(100.0));
        expect(bounds.top, closeTo(35.566, 0.001));
        expect(bounds.bottom, closeTo(64.434, 0.001));
      });

      test('handles degenerate cubic (straight line)', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..cubicCurveTo(33, 0, 66, 0, 100, 0);

        final bounds = BoundsCalculator.boundsOf(
          path.build(),
          Matrix2D.identity(),
        );

        expect(bounds.left, equals(0.0));
        expect(bounds.right, equals(100.0));
        expect(bounds.top, equals(0.0));
        expect(bounds.bottom, equals(0.0));
        expect(bounds.height, equals(0.0));
      });

      test('applies transform to extrema points', () {
        final transform = Matrix2D.identity();
        transform.translate(10, 20);
        transform.scale(2, 2);

        final path = PathBuilder()
          ..moveTo(0, 0)
          ..cubicCurveTo(30, -30, 60, 30, 90, 0);

        final bounds = BoundsCalculator.boundsOf(path.build(), transform);

        // Transform should affect all bounds
        expect(bounds.left, equals(10.0)); // 0 * 2 + 10
        expect(bounds.right, equals(190.0)); // 90 * 2 + 10
        expect(bounds.top, lessThan(20.0)); // Has negative extrema
        expect(bounds.bottom, greaterThan(20.0)); // Has positive extrema
      });

      test('handles multiple connected curves', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..cubicCurveTo(50, -50, 100, -50, 150, 0)
          ..cubicCurveTo(200, 50, 250, 50, 300, 0);

        final bounds = BoundsCalculator.boundsOf(
          path.build(),
          Matrix2D.identity(),
        );

        expect(bounds.left, equals(0.0));
        expect(bounds.right, equals(300.0));
        expect(bounds.top, equals(-37.5)); // Extrema of first curve
        expect(bounds.bottom, equals(37.5)); // Extrema of second curve
      });

      test('handles curve with no extrema in range', () {
        // A curve where the extrema would be outside [0,1] parameter range
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..cubicCurveTo(10, 10, 20, 20, 30, 30);

        final bounds = BoundsCalculator.boundsOf(
          path.build(),
          Matrix2D.identity(),
        );

        // Should just use endpoints since no extrema in valid range
        expect(bounds.left, equals(0.0));
        expect(bounds.right, equals(30.0));
        expect(bounds.top, equals(0.0));
        expect(bounds.bottom, equals(30.0));
      });

      test('handles empty path', () {
        final path = PathBuilder().build();

        final bounds = BoundsCalculator.boundsOf(path, Matrix2D.identity());

        expect(bounds.left, equals(0.0));
        expect(bounds.right, equals(0.0));
        expect(bounds.top, equals(0.0));
        expect(bounds.bottom, equals(0.0));
        expect(bounds.width, equals(0.0));
        expect(bounds.height, equals(0.0));
      });
    });

    group('Arc bounds', () {
      test('calculates bounds for full circle', () {
        // Use dart:math pi for accurate value
        const pi = 3.141592653589793;
        final path = PathBuilder()..arc(50, 50, 25, 0, 2 * pi);

        final bounds = BoundsCalculator.boundsOf(
          path.build(),
          Matrix2D.identity(),
        );

        // A full circle centered at (50,50) with radius 25
        expect(bounds.left, closeTo(25.0, 0.1));
        expect(bounds.right, closeTo(75.0, 0.1));
        expect(bounds.top, closeTo(25.0, 0.1));
        expect(bounds.bottom, closeTo(75.0, 0.1));
      });

      test('calculates bounds for quarter arc', () {
        const pi = 3.141592653589793;
        final path = PathBuilder()..arc(100, 100, 50, 0, pi / 2);

        final bounds = BoundsCalculator.boundsOf(
          path.build(),
          Matrix2D.identity(),
        );

        // Quarter arc from 0 to π/2 should include right and top extrema
        expect(bounds.left, closeTo(100.0, 0.1));
        expect(bounds.right, closeTo(150.0, 0.1));
        expect(bounds.top, closeTo(100.0, 0.1));
        expect(bounds.bottom, closeTo(150.0, 0.1));
      });
    });
  });
}

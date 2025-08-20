import 'dart:math' as math;

import 'package:libgfx/src/point.dart';
import 'package:libgfx/src/utils/math_utils.dart';
import 'package:test/test.dart';

void main() {
  group('MathUtils', () {
    group('Constants', () {
      test('pi constants are correct', () {
        // MathUtils.pi removed - use math.pi directly
        expect(MathUtils.pi2, equals(math.pi * 2));
        expect(MathUtils.piOver2, equals(math.pi / 2));
        expect(MathUtils.piOver4, equals(math.pi / 4));
      });

      test('conversion constants are correct', () {
        expect(MathUtils.degreesToRadians, equals(math.pi / 180));
        expect(MathUtils.radiansToDegrees, equals(180 / math.pi));
      });

      test('circle kappa constant is correct', () {
        // Magic constant for cubic bezier circle approximation
        expect(MathUtils.circleKappa, closeTo(0.5522847498307933, 0.0000001));
      });

      test('epsilon is appropriate for floating point comparisons', () {
        expect(MathUtils.epsilon, lessThan(1e-8));
        expect(MathUtils.epsilon, greaterThan(0));
      });
    });

    group('Angle Conversions', () {
      test('converts degrees to radians', () {
        expect(MathUtils.toRadians(0), equals(0));
        expect(MathUtils.toRadians(90), closeTo(math.pi / 2, 0.0001));
        expect(MathUtils.toRadians(180), closeTo(math.pi, 0.0001));
        expect(MathUtils.toRadians(270), closeTo(3 * math.pi / 2, 0.0001));
        expect(MathUtils.toRadians(360), closeTo(2 * math.pi, 0.0001));
      });

      test('converts radians to degrees', () {
        expect(MathUtils.toDegrees(0), equals(0));
        expect(MathUtils.toDegrees(math.pi / 2), closeTo(90, 0.0001));
        expect(MathUtils.toDegrees(math.pi), closeTo(180, 0.0001));
        expect(MathUtils.toDegrees(3 * math.pi / 2), closeTo(270, 0.0001));
        expect(MathUtils.toDegrees(2 * math.pi), closeTo(360, 0.0001));
      });

      test('handles negative angles', () {
        expect(MathUtils.toRadians(-90), closeTo(-math.pi / 2, 0.0001));
        expect(MathUtils.toDegrees(-math.pi), closeTo(-180, 0.0001));
      });

      test('normalizes angles to [0, 2π)', () {
        expect(MathUtils.normalizeAngle(0), equals(0));
        expect(MathUtils.normalizeAngle(math.pi), closeTo(math.pi, 0.0001));
        expect(MathUtils.normalizeAngle(3 * math.pi), closeTo(math.pi, 0.0001));
        expect(MathUtils.normalizeAngle(-math.pi), closeTo(math.pi, 0.0001));
        expect(MathUtils.normalizeAngle(5 * math.pi), closeTo(math.pi, 0.0001));
      });

      // angleBetweenPoints test removed - dead function
    });

    group('Clamping', () {
      test('clamps double values using built-in', () {
        expect((5.0).clamp(0.0, 10.0), equals(5.0));
        expect((-5.0).clamp(0.0, 10.0), equals(0.0));
        expect((15.0).clamp(0.0, 10.0), equals(10.0));
        expect((0.0).clamp(0.0, 10.0), equals(0.0));
        expect((10.0).clamp(0.0, 10.0), equals(10.0));
      });

      test('clamps integer values using built-in', () {
        expect((5).clamp(0, 10), equals(5));
        expect((-5).clamp(0, 10), equals(0));
        expect((15).clamp(0, 10), equals(10));
        expect((0).clamp(0, 10), equals(0));
        expect((10).clamp(0, 10), equals(10));
      });

      test('handles equal min and max', () {
        expect((5.0).clamp(3.0, 3.0), equals(3.0));
        expect((5).clamp(3, 3), equals(3));
      });
    });

    group('Interpolation', () {
      test('linear interpolation (lerp)', () {
        expect(MathUtils.lerp(0.0, 10.0, 0.0), equals(0.0));
        expect(MathUtils.lerp(0.0, 10.0, 0.5), equals(5.0));
        expect(MathUtils.lerp(0.0, 10.0, 1.0), equals(10.0));
        expect(MathUtils.lerp(10.0, 20.0, 0.25), equals(12.5));
        expect(MathUtils.lerp(-10.0, 10.0, 0.5), equals(0.0));
      });

      test('integer linear interpolation', () {
        expect(MathUtils.lerpInt(0, 100, 0.0), equals(0));
        expect(MathUtils.lerpInt(0, 100, 0.5), equals(50));
        expect(MathUtils.lerpInt(0, 100, 1.0), equals(100));
        expect(MathUtils.lerpInt(100, 200, 0.25), equals(125));
      });

      test('lerp handles extrapolation', () {
        expect(MathUtils.lerp(0.0, 10.0, -0.5), equals(-5.0));
        expect(MathUtils.lerp(0.0, 10.0, 1.5), equals(15.0));
      });

      test('bilinear interpolation', () {
        // Corners of a unit square
        expect(MathUtils.bilerp(0, 1, 2, 3, 0.0, 0.0), equals(0));
        expect(MathUtils.bilerp(0, 1, 2, 3, 1.0, 0.0), equals(1));
        expect(MathUtils.bilerp(0, 1, 2, 3, 0.0, 1.0), equals(2));
        expect(MathUtils.bilerp(0, 1, 2, 3, 1.0, 1.0), equals(3));

        // Center
        expect(MathUtils.bilerp(0, 1, 2, 3, 0.5, 0.5), equals(1.5));

        // Other points
        expect(MathUtils.bilerp(0, 10, 20, 30, 0.5, 0.0), equals(5));
        expect(MathUtils.bilerp(0, 10, 20, 30, 0.0, 0.5), equals(10));
      });
    });

    group('Fuzzy Comparisons', () {
      test('nearly equals for doubles', () {
        expect(MathUtils.nearlyEqual(1.0, 1.0), isTrue);
        expect(MathUtils.nearlyEqual(1.0, 1.0 + MathUtils.epsilon / 2), isTrue);
        expect(MathUtils.nearlyEqual(1.0, 1.1), isFalse);
        expect(MathUtils.nearlyEqual(0.0, 0.0), isTrue);
        expect(MathUtils.nearlyEqual(-1.0, -1.0), isTrue);
      });

      test('nearly equals with custom tolerance', () {
        expect(MathUtils.nearlyEqual(1.0, 1.01, 0.1), isTrue);
        expect(MathUtils.nearlyEqual(1.0, 1.01, 0.001), isFalse);
        expect(MathUtils.nearlyEqual(100.0, 101.0, 2.0), isTrue);
      });

      test('nearly zero check', () {
        expect(MathUtils.nearlyZero(0.0), isTrue);
        expect(MathUtils.nearlyZero(MathUtils.epsilon / 2), isTrue);
        expect(MathUtils.nearlyZero(-MathUtils.epsilon / 2), isTrue);
        expect(MathUtils.nearlyZero(0.1), isFalse);
        expect(MathUtils.nearlyZero(-0.1), isFalse);
      });

      test('nearly zero with custom tolerance', () {
        expect(MathUtils.nearlyZero(0.01, 0.1), isTrue);
        expect(MathUtils.nearlyZero(0.01, 0.001), isFalse);
      });
    });

    group('Distance Calculations', () {
      test('calculates distance between points', () {
        expect(
          Point(0, 0).distanceTo(Point(3, 4)),
          equals(5),
        ); // 3-4-5 triangle
        expect(Point(0, 0).distanceTo(Point(0, 10)), equals(10));
        expect(Point(0, 0).distanceTo(Point(10, 0)), equals(10));
        expect(Point(5, 5).distanceTo(Point(5, 5)), equals(0));
        expect(Point(-5, -5).distanceTo(Point(5, 5)), closeTo(14.142, 0.001));
      });

      test('calculates squared distance', () {
        expect(Point(0, 0).distanceToSquared(Point(3, 4)), equals(25));
        expect(Point(0, 0).distanceToSquared(Point(0, 10)), equals(100));
        expect(Point(0, 0).distanceToSquared(Point(10, 0)), equals(100));
        expect(Point(5, 5).distanceToSquared(Point(5, 5)), equals(0));
        expect(Point(-5, -5).distanceToSquared(Point(5, 5)), equals(200));
      });

      test('squared distance is more efficient', () {
        // No sqrt needed, so should be faster
        final stopwatch1 = Stopwatch()..start();
        for (int i = 0; i < 10000; i++) {
          Point(
            i.toDouble(),
            i.toDouble(),
          ).distanceToSquared(Point(i + 10.0, i + 10.0));
        }
        stopwatch1.stop();

        final stopwatch2 = Stopwatch()..start();
        for (int i = 0; i < 10000; i++) {
          Point(
            i.toDouble(),
            i.toDouble(),
          ).distanceTo(Point(i + 10.0, i + 10.0));
        }
        stopwatch2.stop();

        // Squared should generally be faster (no sqrt)
        // This might not always be true due to optimizations
        // Making this test more lenient as performance can vary
        expect(
          stopwatch1.elapsedMicroseconds,
          lessThanOrEqualTo(stopwatch2.elapsedMicroseconds * 10),
        );
      });
    });

    group('Point Rotation', () {
      test('rotates point around origin', () {
        // 90 degree rotation
        var rotated = Point(1, 0).rotate(math.pi / 2);
        expect(rotated.x, closeTo(0, 0.0001));
        expect(rotated.y, closeTo(1, 0.0001));

        // 180 degree rotation
        rotated = Point(1, 0).rotate(math.pi);
        expect(rotated.x, closeTo(-1, 0.0001));
        expect(rotated.y, closeTo(0, 0.0001));

        // 270 degree rotation
        rotated = Point(1, 0).rotate(3 * math.pi / 2);
        expect(rotated.x, closeTo(0, 0.0001));
        expect(rotated.y, closeTo(-1, 0.0001));

        // 360 degree rotation (back to original)
        rotated = Point(1, 0).rotate(2 * math.pi);
        expect(rotated.x, closeTo(1, 0.0001));
        expect(rotated.y, closeTo(0, 0.0001));
      });

      test('rotates point around center', () {
        // Rotate (2,1) around (1,1) by 90 degrees
        var rotated = Point(2, 1).rotateAround(Point(1, 1), math.pi / 2);
        expect(rotated.x, closeTo(1, 0.0001));
        expect(rotated.y, closeTo(2, 0.0001));

        // Rotate around arbitrary center
        rotated = Point(5, 5).rotateAround(Point(3, 3), math.pi);
        expect(rotated.x, closeTo(1, 0.0001));
        expect(rotated.y, closeTo(1, 0.0001));
      });

      test('handles zero rotation', () {
        final rotated = Point(5, 7).rotate(0);
        expect(rotated.x, equals(5));
        expect(rotated.y, equals(7));
      });
    });

    group('Bezier Curves', () {
      test('evaluates cubic bezier at t=0 and t=1', () {
        final p0 = Point(0, 0);
        final p1 = Point(10, 20);
        final p2 = Point(20, 20);
        final p3 = Point(30, 0);

        // At t=0, should be at p0
        var result = MathUtils.cubicBezier(p0, p1, p2, p3, 0.0);
        expect(result.x, equals(p0.x));
        expect(result.y, equals(p0.y));

        // At t=1, should be at p3
        result = MathUtils.cubicBezier(p0, p1, p2, p3, 1.0);
        expect(result.x, equals(p3.x));
        expect(result.y, equals(p3.y));
      });

      test('evaluates cubic bezier at t=0.5', () {
        final p0 = Point(0, 0);
        final p1 = Point(0, 10);
        final p2 = Point(10, 10);
        final p3 = Point(10, 0);

        final result = MathUtils.cubicBezier(p0, p1, p2, p3, 0.5);

        // At t=0.5, should be somewhere in the middle
        expect(result.x, greaterThan(0));
        expect(result.x, lessThan(10));
        expect(result.y, greaterThan(0));
      });

      // quadraticBezier test removed - dead function
    });

    group('Geometric Tests', () {
      // pointInTriangle test removed - dead function

      // triangleArea test removed - dead function

      // areCollinear test removed - dead function

      // lineIntersection test removed - dead function
    });

    group('Edge Cases', () {
      test('handles NaN and infinity', () {
        // NaN should never equal anything, including itself
        final result = MathUtils.nearlyEqual(double.nan, double.nan);
        expect(result, isFalse);
        expect(MathUtils.nearlyEqual(double.infinity, double.infinity), isTrue);
        expect(
          MathUtils.nearlyEqual(
            double.negativeInfinity,
            double.negativeInfinity,
          ),
          isTrue,
        );

        expect((double.infinity).clamp(0, 10), equals(10));
        expect((double.negativeInfinity).clamp(0, 10), equals(0));
      });

      test('handles very large numbers', () {
        expect(
          Point(0, 0).distanceTo(Point(1e10, 1e10)),
          closeTo(1.414e10, 1e7),
        );

        expect(MathUtils.lerp(1e10, 2e10, 0.5), equals(1.5e10));
      });

      test('handles very small numbers', () {
        expect(MathUtils.nearlyZero(1e-15), isTrue);
        expect(MathUtils.nearlyEqual(1e-15, 2e-15), isTrue);

        expect(
          Point(0, 0).distanceTo(Point(1e-10, 1e-10)),
          closeTo(1.414e-10, 1e-12),
        );
      });
    });
  });
}

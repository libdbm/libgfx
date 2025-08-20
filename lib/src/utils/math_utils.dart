import 'dart:math' as math;
import '../point.dart';

/// Common mathematical utilities for graphics operations
class MathUtils {
  // Prevent instantiation
  MathUtils._();

  /// Common mathematical constants
  static const double pi2 = math.pi * 2; // 2π
  static const double piOver2 = math.pi / 2; // π/2
  static const double piOver4 = math.pi / 4; // π/4
  static const double degreesToRadians = math.pi / 180;
  static const double radiansToDegrees = 180 / math.pi;

  /// Standard epsilon for floating point comparisons and parallel line detection
  static const double epsilon = 1e-10;

  /// Epsilon for geometric calculations (points, vectors, intersections)
  static const double geometricEpsilon = 1e-9;

  /// Tolerance for curve tessellation and approximation
  static const double curveTolerance = 0.01;

  /// Tolerance for rasterization precision and pixel-level operations
  static const double rasterTolerance = 0.001;

  /// Magic constant for cubic bezier circle approximation
  /// This is (4/3) * tan(pi/8) = 4(sqrt(2) - 1)/3
  static const double circleKappa = 0.5522847498307933;

  static int mul255(int a, int b) {
    final product = a * b;
    return (product + (product >> 8) + 0x80) >> 8;
  }

  /// Convert degrees to radians
  static double toRadians(double degrees) => degrees * degreesToRadians;

  /// Convert radians to degrees
  static double toDegrees(double radians) => radians * radiansToDegrees;

  /// Normalize an angle to [0, 2π)
  static double normalizeAngle(double angle) {
    angle = angle % pi2;
    if (angle < 0) angle += pi2;
    return angle;
  }

  /// Linear interpolation
  static double lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  /// Fast integer linear interpolation using fixed-point math
  static int lerpInt(int a, int b, double t) {
    final fixed_t = (t * 256).round().clamp(0, 256);
    return a + ((b - a) * fixed_t >> 8);
  }

  /// Bilinear interpolation
  static double bilerp(
    double v00,
    double v10,
    double v01,
    double v11,
    double fx,
    double fy,
  ) {
    final v0 = lerp(v00, v10, fx);
    final v1 = lerp(v01, v11, fx);
    return lerp(v0, v1, fy);
  }

  /// Bilinear interpolation for integer values (0-255 range)
  static int bilerpInt(
    int v00,
    int v10,
    int v01,
    int v11,
    double fx,
    double fy,
  ) {
    final v0 = lerpInt(v00, v10, fx);
    final v1 = lerpInt(v01, v11, fx);
    return lerpInt(v0, v1, fy);
  }

  /// Check if two doubles are approximately equal with smart tolerance
  static bool nearlyEqual(double a, double b, [double epsilon = epsilon]) {
    if (a == b) return true; // Handles infinity cases

    final diff = (a - b).abs();

    // Handle special cases
    if (!a.isFinite || !b.isFinite) {
      return a == b;
    }

    // Use relative tolerance for large numbers
    final absA = a.abs();
    final absB = b.abs();
    final largest = absA > absB ? absA : absB;

    if (largest > 1.0) {
      // Relative comparison for large numbers
      return diff <= epsilon * largest;
    } else {
      // Absolute comparison for small numbers
      return diff <= epsilon;
    }
  }

  /// Check if a double is approximately zero
  static bool nearlyZero(double value, [double epsilon = epsilon]) {
    return value.abs() <= epsilon;
  }

  /// Calculate cubic bezier point at parameter t
  static Point cubicBezier(Point p0, Point p1, Point p2, Point p3, double t) {
    final mt = 1 - t;
    final mt2 = mt * mt;
    final mt3 = mt2 * mt;
    final t2 = t * t;
    final t3 = t2 * t;

    return Point(
      mt3 * p0.x + 3 * mt2 * t * p1.x + 3 * mt * t2 * p2.x + t3 * p3.x,
      mt3 * p0.y + 3 * mt2 * t * p1.y + 3 * mt * t2 * p2.y + t3 * p3.y,
    );
  }

  /// Calculate a point on a circle at the given angle
  /// @param centerX The x-coordinate of the circle center
  /// @param centerY The y-coordinate of the circle center
  /// @param radius The radius of the circle
  /// @param angle The angle in radians
  /// @return A point on the circle at the given angle
  static Point circlePoint(
    double centerX,
    double centerY,
    double radius,
    double angle,
  ) {
    return Point(
      centerX + radius * math.cos(angle),
      centerY + radius * math.sin(angle),
    );
  }

  /// Calculate a point on an ellipse at the given angle
  /// @param centerX The x-coordinate of the ellipse center
  /// @param centerY The y-coordinate of the ellipse center
  /// @param radiusX The horizontal radius of the ellipse
  /// @param radiusY The vertical radius of the ellipse
  /// @param rotation The rotation angle of the ellipse in radians
  /// @param angle The parametric angle in radians
  /// @return A point on the ellipse at the given angle
  static Point ellipsePoint(
    double centerX,
    double centerY,
    double radiusX,
    double radiusY,
    double rotation,
    double angle,
  ) {
    final cosAngle = math.cos(angle);
    final sinAngle = math.sin(angle);
    final cosRotation = math.cos(rotation);
    final sinRotation = math.sin(rotation);

    return Point(
      centerX +
          radiusX * cosAngle * cosRotation -
          radiusY * sinAngle * sinRotation,
      centerY +
          radiusX * cosAngle * sinRotation +
          radiusY * sinAngle * cosRotation,
    );
  }
}

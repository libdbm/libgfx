import 'dart:math';
import 'utils/math_utils.dart';

/// A class representing a 2D vector or point.
class Point {
  double x;
  double y;

  Point(this.x, this.y);

  /// A vector with both components set to zero.
  static Point get zero => Point(0, 0);

  /// The squared length of the vector. Faster than `length`.
  double get length2 => x * x + y * y;

  /// The length (magnitude) of the vector.
  double get length => sqrt(length2);

  /// Returns a new vector with the same direction but a length of 1.
  Point normalized() {
    final l = length;
    if (l == 0) return Point.zero;
    return Point(x / l, y / l);
  }

  /// Calculates the dot product with another vector.
  double dot(Point other) {
    return x * other.x + y * other.y;
  }

  /// Calculates the 2D cross product (z-component of 3D cross product).
  /// Returns positive for counter-clockwise rotation, negative for clockwise.
  double cross(Point other) {
    return x * other.y - y * other.x;
  }

  /// Linear interpolation between two points
  static Point lerp(Point a, Point b, double t) {
    return Point(MathUtils.lerp(a.x, b.x, t), MathUtils.lerp(a.y, b.y, t));
  }

  /// Calculate the midpoint between two points
  static Point midpoint(Point a, Point b) {
    return Point((a.x + b.x) / 2, (a.y + b.y) / 2);
  }

  /// Calculate the distance to another point
  double distanceTo(Point other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Calculate the squared distance to another point (faster than distanceTo)
  double distanceToSquared(Point other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return dx * dx + dy * dy;
  }

  /// Rotate this point around the origin by the given angle (in radians)
  Point rotate(double angle) {
    final cosAngle = cos(angle);
    final sinAngle = sin(angle);
    return Point(x * cosAngle - y * sinAngle, x * sinAngle + y * cosAngle);
  }

  /// Rotate this point around another point by the given angle (in radians)
  Point rotateAround(Point center, double angle) {
    final translated = this - center;
    final rotated = translated.rotate(angle);
    return rotated + center;
  }

  /// Check if two points are equal within a tolerance
  bool equals(Point other, {double tolerance = 1e-9}) {
    return (x - other.x).abs() < tolerance && (y - other.y).abs() < tolerance;
  }

  // Operator overloads for vector math
  Point operator +(Point other) => Point(x + other.x, y + other.y);

  Point operator -(Point other) => Point(x - other.x, y - other.y);

  Point operator *(double scale) => Point(x * scale, y * scale);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Point && x == other.x && y == other.y;
  }

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Point($x, $y)';
}

import 'dart:math' as math;

import '../paths/path.dart';
import '../point.dart';
import 'curve_utils.dart';
import 'math_utils.dart';

/// Utility class for common geometric calculations and path creation
class GeometryUtils {
  // Prevent instantiation
  GeometryUtils._();

  /// Find the closest point on a line segment to a given point
  static Point closestPointOnSegment(
    Point point,
    Point segStart,
    Point segEnd,
  ) {
    final v = segEnd - segStart;
    final w = point - segStart;

    final c1 = w.dot(v);
    if (c1 <= 0) return segStart;

    final c2 = v.dot(v);
    if (c1 >= c2) return segEnd;

    final t = c1 / c2;
    return segStart + v * t;
  }

  /// Calculate the distance from a point to a line segment
  static double distanceToSegment(Point point, Point segStart, Point segEnd) {
    final closest = closestPointOnSegment(point, segStart, segEnd);
    return point.distanceTo(closest);
  }

  /// Get normal vector (perpendicular) to a given vector
  static Point getNormal(Point vector) {
    return Point(-vector.y, vector.x);
  }

  /// Get extrema angles for an elliptical arc
  /// Returns angles that need to be checked for bounds calculation
  static List<double> getEllipseExtremaAngles(
    double startAngle,
    double endAngle,
    double rotation,
    bool counterClockwise,
  ) {
    final angles = <double>[];

    // Add start and end angles
    angles.add(startAngle);
    angles.add(endAngle);

    // Add rotated extrema (0°, 90°, 180°, 270° adjusted for rotation)
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2 - rotation;
      if (angleInArc(angle, startAngle, endAngle, counterClockwise)) {
        angles.add(angle);
      }
    }

    return angles;
  }

  /// Get extrema angles for a circular arc
  /// Returns angles that need to be checked for bounds calculation
  static List<double> getArcExtremaAngles(
    double startAngle,
    double endAngle,
    bool counterClockwise,
  ) {
    final angles = <double>[];

    // Add start and end angles
    angles.add(startAngle);
    angles.add(endAngle);

    // Check if extrema (0°, 90°, 180°, 270°) are within the arc
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      if (angleInArc(angle, startAngle, endAngle, counterClockwise)) {
        angles.add(angle);
      }
    }

    return angles;
  }

  /// Check if an angle is within an arc
  static bool angleInArc(
    double angle,
    double startAngle,
    double endAngle,
    bool counterClockwise,
  ) {
    // Special case: full circle
    if ((endAngle - startAngle).abs() >= 2 * math.pi - 0.0001) {
      return true; // All angles are in a full circle
    }

    // Normalize angles to [0, 2π)
    angle = MathUtils.normalizeAngle(angle);
    startAngle = MathUtils.normalizeAngle(startAngle);
    endAngle = MathUtils.normalizeAngle(endAngle);

    if (counterClockwise) {
      if (startAngle <= endAngle) {
        return angle >= startAngle && angle <= endAngle;
      } else {
        return angle >= startAngle || angle <= endAngle;
      }
    } else {
      if (startAngle >= endAngle) {
        return angle <= startAngle && angle >= endAngle;
      } else {
        return angle >= startAngle && angle <= endAngle;
      }
    }
  }

  /// Flatten a cubic Bezier curve to a list of points
  /// Used by both Dasher and Stroker for path processing
  static List<Point> flattenCubicBezier(
    Point p0,
    Point p1,
    Point p2,
    Point p3, {
    double? tolerance,
    int? steps,
    int maxDepth = 16,
  }) {
    if (steps != null) {
      // Fixed steps mode (used by Dasher)
      return CurveUtils.flattenCubicBezierFixed(p0, p1, p2, p3, steps: steps);
    } else {
      // Adaptive mode (used by Stroker)
      return CurveUtils.flattenCubicBezier(
        p0,
        p1,
        p2,
        p3,
        tolerance: tolerance ?? MathUtils.curveTolerance,
        maxDepth: maxDepth,
      );
    }
  }

  /// Flatten an arc command to a list of points
  /// Used by both Dasher and Stroker for path processing
  static List<Point> flattenArc(
    Point currentPos,
    ArcCommand arc, {
    double tolerance = 0.1,
  }) {
    return CurveUtils.tessellateArcCommand(
      currentPos,
      arc,
      tolerance: tolerance,
    );
  }

  /// Flatten an ellipse command to a list of points
  /// Used by both Dasher and Stroker for path processing
  static List<Point> flattenEllipse(
    Point currentPos,
    EllipseCommand ellipse, {
    double tolerance = 0.1,
  }) {
    return CurveUtils.tessellateEllipseCommand(
      currentPos,
      ellipse,
      tolerance: tolerance,
    );
  }
}

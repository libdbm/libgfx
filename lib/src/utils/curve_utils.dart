import 'dart:math' as math;

import '../paths/path.dart';
import '../point.dart';
import 'math_utils.dart';

/// Unified curve utilities for bezier curves, arcs, and curve operations
class CurveUtils {
  // Prevent instantiation
  CurveUtils._();

  /// Default tessellation parameters
  static const double defaultTolerance = 0.1;
  static const int defaultMaxDepth = 16;
  static const int defaultMinSteps = 8;
  static const int defaultMaxSteps = 256;

  /// Flatten cubic Bezier to line segments with adaptive subdivision
  static List<Point> _adaptive(
    Point p0,
    Point p1,
    Point p2,
    Point p3, {
    double tolerance = defaultTolerance,
    int maxDepth = defaultMaxDepth,
  }) {
    final points = <Point>[];
    points.add(p0); // Add the start point
    _subdivide(p0, p1, p2, p3, 0, points, tolerance, maxDepth);
    return points;
  }

  /// Flatten cubic Bezier with fixed steps (simpler but less adaptive)
  static List<Point> flattenCubicBezierFixed(
    Point p0,
    Point p1,
    Point p2,
    Point p3, {
    int steps = 30,
  }) {
    final points = <Point>[p0];
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      points.add(MathUtils.cubicBezier(p0, p1, p2, p3, t));
    }
    return points;
  }

  /// Recursive subdivision for cubic Bezier curves with numerical stability
  static void _subdivide(
    Point p0,
    Point p1,
    Point p2,
    Point p3,
    int depth,
    List<Point> output,
    double tolerance,
    int maxDepth,
  ) {
    // Safety check: prevent infinite recursion
    if (depth >= maxDepth) {
      // Add the end point of this segment
      output.add(p3);
      return;
    }

    // Additional safety: check for degenerate curve (all points very close)
    final extent = [
      (p1 - p0).length,
      (p2 - p1).length,
      (p3 - p2).length,
      (p3 - p0).length,
    ].reduce(math.max);

    // If curve is essentially a point, stop subdividing
    if (extent < tolerance * 0.001) {
      output.add(p3);
      return;
    }

    // Check if curve is flat enough using perpendicular distance
    final d1 = _distance(p1, p0, p3);
    final d2 = _distance(p2, p0, p3);

    // Use fixed tolerance to prevent artifacts from adaptive scaling
    if (d1 <= tolerance && d2 <= tolerance) {
      // Curve is flat enough, add the end point
      output.add(p3);
      return;
    }

    // De Casteljau subdivision at t=0.5 with numerical stability
    final p01 = Point.midpoint(p0, p1);
    final p12 = Point.midpoint(p1, p2);
    final p23 = Point.midpoint(p2, p3);
    final p012 = Point.midpoint(p01, p12);
    final p123 = Point.midpoint(p12, p23);
    final p0123 = Point.midpoint(p012, p123);

    // Check for numerical convergence issues
    if ((p0123 - p0).length < tolerance * 0.01 &&
        (p0123 - p3).length < tolerance * 0.01) {
      // Curve has collapsed to nearly a single point
      output.add(p3);
      return;
    }

    // Recursively subdivide - the midpoint will be added by the first subdivision
    _subdivide(p0, p01, p012, p0123, depth + 1, output, tolerance, maxDepth);
    _subdivide(p0123, p123, p23, p3, depth + 1, output, tolerance, maxDepth);
  }

  /// Tessellate an arc into line segments
  static List<Point> _arc(
    double centerX,
    double centerY,
    double radius,
    double startAngle,
    double endAngle, {
    double tolerance = defaultTolerance,
    int? minSteps,
    int? maxSteps,
    bool counterClockwise = false,
  }) {
    final points = <Point>[];

    // Calculate sweep angle
    var sweep = endAngle - startAngle;
    if (counterClockwise && sweep > 0) {
      sweep -= 2 * math.pi;
    } else if (!counterClockwise && sweep < 0) {
      sweep += 2 * math.pi;
    }

    // Adaptive step calculation based on radius and tolerance
    final limit = radius > tolerance
        ? 2 * math.acos(1 - tolerance / radius)
        : math.pi / 4;
    var steps = math.max(2, (sweep.abs() / limit).ceil());

    if (minSteps != null || maxSteps != null) {
      steps = steps.clamp(
        minSteps ?? defaultMinSteps,
        maxSteps ?? defaultMaxSteps,
      );
    }

    final step = sweep / steps;

    for (int i = 0; i <= steps; i++) {
      final angle = startAngle + i * step;
      final point = MathUtils.circlePoint(centerX, centerY, radius, angle);
      final x = point.x;
      final y = point.y;
      points.add(Point(x, y));
    }

    return points;
  }

  /// Tessellate an ellipse into line segments
  static List<Point> _ellipse(
    double centerX,
    double centerY,
    double radiusX,
    double radiusY,
    double rotation,
    double startAngle,
    double endAngle, {
    double tolerance = defaultTolerance,
    int? minSteps,
    int? maxSteps,
    bool counterClockwise = false,
  }) {
    final points = <Point>[];

    // Calculate sweep angle
    var sweep = endAngle - startAngle;
    if (counterClockwise && sweep > 0) {
      sweep -= 2 * math.pi;
    } else if (!counterClockwise && sweep < 0) {
      sweep += 2 * math.pi;
    }

    // Adaptive step calculation based on average radius
    final mean = (radiusX + radiusY) / 2;
    final limit = mean > tolerance
        ? 2 * math.acos(1 - tolerance / mean)
        : math.pi / 4;
    var steps = math.max(2, (sweep.abs() / limit).ceil());

    if (minSteps != null || maxSteps != null) {
      steps = steps.clamp(
        minSteps ?? defaultMinSteps,
        maxSteps ?? defaultMaxSteps,
      );
    }

    final step = sweep / steps;
    final cos = math.cos(rotation);
    final sin = math.sin(rotation);

    for (int i = 0; i <= steps; i++) {
      final angle = startAngle + i * step;
      final cosAngle = math.cos(angle);
      final sinAngle = math.sin(angle);

      // Ellipse point before rotation
      final ex = radiusX * cosAngle;
      final ey = radiusY * sinAngle;

      // Apply rotation and translation
      final x = centerX + ex * cos - ey * sin;
      final y = centerY + ex * sin + ey * cos;
      points.add(Point(x, y));
    }

    return points;
  }

  /// Tessellate an arc from PathCommand
  static List<Point> tessellateArcCommand(
    final Point start,
    ArcCommand arc, {
    double tolerance = defaultTolerance,
  }) {
    final points = <Point>[start];

    // Connect from start to first point on arc if needed
    final angle = arc.startAngle;
    final first = MathUtils.circlePoint(
      arc.centerX,
      arc.centerY,
      arc.radius,
      angle,
    );
    final firstX = first.x;
    final firstY = first.y;

    if ((start.x - firstX).abs() > 0.001 || (start.y - firstY).abs() > 0.001) {
      points.add(Point(firstX, firstY));
    }

    // Tessellate the arc itself
    final tessellated = _arc(
      arc.centerX,
      arc.centerY,
      arc.radius,
      arc.startAngle,
      arc.endAngle,
      tolerance: tolerance,
    );

    // Skip the first point if it's the same as what we already added
    final duplicate =
        tessellated.isNotEmpty &&
        (points.last - tessellated.first).length < 0.001;
    points.addAll(duplicate ? tessellated.skip(1) : tessellated);

    return points;
  }

  /// Tessellate an ellipse from PathCommand
  static List<Point> tessellateEllipseCommand(
    final Point start,
    EllipseCommand ellipse, {
    double tolerance = defaultTolerance,
  }) {
    final points = <Point>[start];

    // Calculate the starting point of the ellipse
    final first = MathUtils.ellipsePoint(
      ellipse.centerX,
      ellipse.centerY,
      ellipse.radiusX,
      ellipse.radiusY,
      ellipse.rotation,
      ellipse.startAngle,
    );
    final firstX = first.x;
    final firstY = first.y;

    // Connect from start to first point on ellipse if needed
    if ((start.x - firstX).abs() > 0.001 || (start.y - firstY).abs() > 0.001) {
      points.add(Point(firstX, firstY));
    }

    // Tessellate the ellipse itself
    final tessellated = _ellipse(
      ellipse.centerX,
      ellipse.centerY,
      ellipse.radiusX,
      ellipse.radiusY,
      ellipse.rotation,
      ellipse.startAngle,
      ellipse.endAngle,
      tolerance: tolerance,
    );

    // Skip the first point if it's the same as what we already added
    final duplicate =
        tessellated.isNotEmpty &&
        (points.last - tessellated.first).length < 0.001;
    points.addAll(duplicate ? tessellated.skip(1) : tessellated);

    return points;
  }

  /// Calculate perpendicular distance from point to line segment
  static double _distance(Point point, final Point start, final Point end) {
    return distanceToSegment(point, start, end);
  }

  /// Find the closest point on a line segment to a given point
  static Point closestPointOnSegment(
    Point point,
    final Point start,
    final Point end,
  ) {
    final v = end - start;
    final w = point - start;

    final c1 = w.dot(v);
    if (c1 <= 0) return start;

    final c2 = v.dot(v);
    if (c1 >= c2) return end;

    final t = c1 / c2;
    return start + v * t;
  }

  /// Calculate the distance from a point to a line segment
  static double distanceToSegment(
    Point point,
    final Point start,
    final Point end,
  ) {
    final closest = closestPointOnSegment(point, start, end);
    return point.distance(closest);
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
      return flattenCubicBezierFixed(p0, p1, p2, p3, steps: steps);
    } else {
      // Adaptive mode (used by Stroker)
      return _adaptive(
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
    final Point current,
    ArcCommand arc, {
    double tolerance = 0.1,
  }) {
    return tessellateArcCommand(current, arc, tolerance: tolerance);
  }

  /// Flatten an ellipse command to a list of points
  /// Used by both Dasher and Stroker for path processing
  static List<Point> flattenEllipse(
    final Point current,
    EllipseCommand ellipse, {
    double tolerance = 0.1,
  }) {
    return tessellateEllipseCommand(current, ellipse, tolerance: tolerance);
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
}

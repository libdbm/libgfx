import 'dart:math' as math;

import '../paths/path.dart';
import '../point.dart';
import 'geometry_utils.dart';
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
  static List<Point> flattenCubicBezier(
    Point p0,
    Point p1,
    Point p2,
    Point p3, {
    double tolerance = defaultTolerance,
    int maxDepth = defaultMaxDepth,
  }) {
    final points = <Point>[];
    points.add(p0); // Add the start point
    _subdivideCubicBezier(
      p0,
      p1,
      p2,
      p3,
      0,
      points,
      tolerance,
      maxDepth,
      false,
    );
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
  static void _subdivideCubicBezier(
    Point p0,
    Point p1,
    Point p2,
    Point p3,
    int depth,
    List<Point> output,
    double tolerance,
    int maxDepth,
    bool isFirstCall,
  ) {
    // Safety check: prevent infinite recursion
    if (depth >= maxDepth) {
      // Add the end point of this segment
      output.add(p3);
      return;
    }

    // Additional safety: check for degenerate curve (all points very close)
    final maxDist = [
      (p1 - p0).length,
      (p2 - p1).length,
      (p3 - p2).length,
      (p3 - p0).length,
    ].reduce(math.max);

    // If curve is essentially a point, stop subdividing
    if (maxDist < tolerance * 0.001) {
      output.add(p3);
      return;
    }

    // Check if curve is flat enough using perpendicular distance
    final d1 = _pointToLineDistance(p1, p0, p3);
    final d2 = _pointToLineDistance(p2, p0, p3);

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
    _subdivideCubicBezier(
      p0,
      p01,
      p012,
      p0123,
      depth + 1,
      output,
      tolerance,
      maxDepth,
      false,
    );
    _subdivideCubicBezier(
      p0123,
      p123,
      p23,
      p3,
      depth + 1,
      output,
      tolerance,
      maxDepth,
      false,
    );
  }

  /// Tessellate an arc into line segments
  static List<Point> _tessellateArc(
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
    var sweepAngle = endAngle - startAngle;
    if (counterClockwise && sweepAngle > 0) {
      sweepAngle -= 2 * math.pi;
    } else if (!counterClockwise && sweepAngle < 0) {
      sweepAngle += 2 * math.pi;
    }

    // Adaptive step calculation based on radius and tolerance
    final errorAngle = radius > tolerance
        ? 2 * math.acos(1 - tolerance / radius)
        : math.pi / 4;
    var steps = math.max(2, (sweepAngle.abs() / errorAngle).ceil());

    if (minSteps != null || maxSteps != null) {
      steps = steps.clamp(
        minSteps ?? defaultMinSteps,
        maxSteps ?? defaultMaxSteps,
      );
    }

    final angleStep = sweepAngle / steps;

    for (int i = 0; i <= steps; i++) {
      final angle = startAngle + i * angleStep;
      final point = MathUtils.circlePoint(centerX, centerY, radius, angle);
      final x = point.x;
      final y = point.y;
      points.add(Point(x, y));
    }

    return points;
  }

  /// Tessellate an ellipse into line segments
  static List<Point> _tessellateEllipse(
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
    var sweepAngle = endAngle - startAngle;
    if (counterClockwise && sweepAngle > 0) {
      sweepAngle -= 2 * math.pi;
    } else if (!counterClockwise && sweepAngle < 0) {
      sweepAngle += 2 * math.pi;
    }

    // Adaptive step calculation based on average radius
    final avgRadius = (radiusX + radiusY) / 2;
    final errorAngle = avgRadius > tolerance
        ? 2 * math.acos(1 - tolerance / avgRadius)
        : math.pi / 4;
    var steps = math.max(2, (sweepAngle.abs() / errorAngle).ceil());

    if (minSteps != null || maxSteps != null) {
      steps = steps.clamp(
        minSteps ?? defaultMinSteps,
        maxSteps ?? defaultMaxSteps,
      );
    }

    final angleStep = sweepAngle / steps;
    final cosRot = math.cos(rotation);
    final sinRot = math.sin(rotation);

    for (int i = 0; i <= steps; i++) {
      final angle = startAngle + i * angleStep;
      final cosAngle = math.cos(angle);
      final sinAngle = math.sin(angle);

      // Ellipse point before rotation
      final ex = radiusX * cosAngle;
      final ey = radiusY * sinAngle;

      // Apply rotation and translation
      final x = centerX + ex * cosRot - ey * sinRot;
      final y = centerY + ex * sinRot + ey * cosRot;
      points.add(Point(x, y));
    }

    return points;
  }

  /// Tessellate an arc from PathCommand
  static List<Point> tessellateArcCommand(
    Point startPoint,
    ArcCommand arc, {
    double tolerance = defaultTolerance,
  }) {
    final points = <Point>[startPoint];

    // Connect from startPoint to first point on arc if needed
    final firstAngle = arc.startAngle;
    final firstPoint = MathUtils.circlePoint(
      arc.centerX,
      arc.centerY,
      arc.radius,
      firstAngle,
    );
    final firstX = firstPoint.x;
    final firstY = firstPoint.y;

    if ((startPoint.x - firstX).abs() > 0.001 ||
        (startPoint.y - firstY).abs() > 0.001) {
      points.add(Point(firstX, firstY));
    }

    // Tessellate the arc itself
    final arcPoints = _tessellateArc(
      arc.centerX,
      arc.centerY,
      arc.radius,
      arc.startAngle,
      arc.endAngle,
      tolerance: tolerance,
    );

    // Skip the first point if it's the same as what we already added
    final skipFirst =
        arcPoints.isNotEmpty && (points.last - arcPoints.first).length < 0.001;
    points.addAll(skipFirst ? arcPoints.skip(1) : arcPoints);

    return points;
  }

  /// Tessellate an ellipse from PathCommand
  static List<Point> tessellateEllipseCommand(
    Point startPoint,
    EllipseCommand ellipse, {
    double tolerance = defaultTolerance,
  }) {
    final points = <Point>[startPoint];

    // Calculate the starting point of the ellipse
    final ellipseStartPoint = MathUtils.ellipsePoint(
      ellipse.centerX,
      ellipse.centerY,
      ellipse.radiusX,
      ellipse.radiusY,
      ellipse.rotation,
      ellipse.startAngle,
    );
    final ellipseStartX = ellipseStartPoint.x;
    final ellipseStartY = ellipseStartPoint.y;

    // Connect from startPoint to first point on ellipse if needed
    if ((startPoint.x - ellipseStartX).abs() > 0.001 ||
        (startPoint.y - ellipseStartY).abs() > 0.001) {
      points.add(Point(ellipseStartX, ellipseStartY));
    }

    // Tessellate the ellipse itself
    final ellipsePoints = _tessellateEllipse(
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
    final skipFirst =
        ellipsePoints.isNotEmpty &&
        (points.last - ellipsePoints.first).length < 0.001;
    points.addAll(skipFirst ? ellipsePoints.skip(1) : ellipsePoints);

    return points;
  }

  /// Calculate perpendicular distance from point to line
  static double _pointToLineDistance(
    Point point,
    Point lineStart,
    Point lineEnd,
  ) {
    // Delegate to GeometryUtils for consistent distance calculation
    return GeometryUtils.distanceToSegment(point, lineStart, lineEnd);
  }
}

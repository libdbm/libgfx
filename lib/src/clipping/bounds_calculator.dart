import 'dart:math' as math;

import '../matrix.dart';
import '../paths/path.dart';
import '../point.dart';
import '../rectangle.dart';
import '../utils/math_utils.dart';
import '../utils/geometry_utils.dart';

/// Helper class to track bounds
class _BoundsTracker {
  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = double.negativeInfinity;
  double maxY = double.negativeInfinity;

  void updateWithPoint(Point p) {
    minX = math.min(minX, p.x);
    minY = math.min(minY, p.y);
    maxX = math.max(maxX, p.x);
    maxY = math.max(maxY, p.y);
  }

  Rectangle<double> getBounds() {
    if (minX == double.infinity) {
      return Rectangle(0, 0, 0, 0);
    }
    return Rectangle(minX, minY, maxX - minX, maxY - minY);
  }
}

/// Calculates bounds for paths with various transformations
class BoundsCalculator {
  /// Calculate exact bounds of a transformed path
  static Rectangle<double> boundsOf(Path path, Matrix2D transform) {
    if (path.commands.isEmpty) {
      return Rectangle(0, 0, 0, 0);
    }

    final tracker = _BoundsTracker();
    Point? currentPoint;

    for (final cmd in path.commands) {
      currentPoint = _processCommand(cmd, transform, tracker, currentPoint);
    }

    return tracker.getBounds();
  }

  static Point? _processCommand(
    PathCommand cmd,
    Matrix2D transform,
    _BoundsTracker tracker,
    Point? currentPoint,
  ) {
    switch (cmd.type) {
      case PathCommandType.moveTo:
      case PathCommandType.lineTo:
        final point = cmd.points.first;
        tracker.updateWithPoint(transform.transform(point));
        return point;

      case PathCommandType.cubicCurveTo:
        return _processCubicCurve(cmd, transform, tracker, currentPoint);

      case PathCommandType.arc:
        _processArc(cmd as ArcCommand, transform, tracker);
        // Arc commands update the current point to the end of the arc
        final endAngle = cmd.endAngle;
        return MathUtils.circlePoint(
          cmd.centerX,
          cmd.centerY,
          cmd.radius,
          endAngle,
        );

      case PathCommandType.ellipse:
        _processEllipse(cmd as EllipseCommand, transform, tracker);
        // Ellipse commands update the current point to the end of the ellipse
        final endAngle = cmd.endAngle;
        return MathUtils.ellipsePoint(
          cmd.centerX,
          cmd.centerY,
          cmd.radiusX,
          cmd.radiusY,
          cmd.rotation,
          endAngle,
        );

      case PathCommandType.close:
        // Close doesn't change the current point
        return currentPoint;
    }
  }

  static Point _processCubicCurve(
    PathCommand cmd,
    Matrix2D transform,
    _BoundsTracker tracker,
    Point? currentPoint,
  ) {
    if (cmd.points.length < 3) {
      // Invalid cubic curve
      return currentPoint ?? Point(0, 0);
    }

    final p0 = currentPoint ?? Point(0, 0);
    final p1 = cmd.points[0]; // First control point
    final p2 = cmd.points[1]; // Second control point
    final p3 = cmd.points[2]; // End point

    // Include end points
    tracker.updateWithPoint(transform.transform(p0));
    tracker.updateWithPoint(transform.transform(p3));

    // Calculate and include extrema points
    _updateWithCubicExtrema(p0, p1, p2, p3, transform, tracker);

    return p3;
  }

  static void _processArc(
    ArcCommand arc,
    Matrix2D transform,
    _BoundsTracker tracker,
  ) {
    final angles = GeometryUtils.getArcExtremaAngles(
      arc.startAngle,
      arc.endAngle,
      arc.counterClockwise,
    );

    for (final angle in angles) {
      final point = MathUtils.circlePoint(
        arc.centerX,
        arc.centerY,
        arc.radius,
        angle,
      );
      tracker.updateWithPoint(transform.transform(point));
    }
  }

  static void _processEllipse(
    EllipseCommand ellipse,
    Matrix2D transform,
    _BoundsTracker tracker,
  ) {
    final angles = GeometryUtils.getEllipseExtremaAngles(
      ellipse.startAngle,
      ellipse.endAngle,
      ellipse.rotation,
      ellipse.counterClockwise,
    );

    for (final angle in angles) {
      final point = MathUtils.ellipsePoint(
        ellipse.centerX,
        ellipse.centerY,
        ellipse.radiusX,
        ellipse.radiusY,
        ellipse.rotation,
        angle,
      );
      tracker.updateWithPoint(transform.transform(point));
    }
  }

  /// Calculate extrema points for cubic Bezier curves
  static void _updateWithCubicExtrema(
    Point p0,
    Point p1,
    Point p2,
    Point p3,
    Matrix2D transform,
    _BoundsTracker tracker,
  ) {
    // For a cubic Bezier curve defined by points p0, p1, p2, p3:
    // B(t) = (1-t)³p0 + 3(1-t)²t·p1 + 3(1-t)t²·p2 + t³p3
    //
    // The derivative is:
    // B'(t) = 3(1-t)²(p1-p0) + 6(1-t)t(p2-p1) + 3t²(p3-p2)
    //
    // Setting B'(t) = 0 and solving for t gives us the extrema.
    // This simplifies to: at² + bt + c = 0 for each dimension (x and y)

    // Calculate extrema for X dimension
    final xExtrema = _findCubicExtremaT(p0.x, p1.x, p2.x, p3.x);

    // Calculate extrema for Y dimension
    final yExtrema = _findCubicExtremaT(p0.y, p1.y, p2.y, p3.y);

    // Evaluate the curve at each extrema point
    final allT = [...xExtrema, ...yExtrema];
    for (final t in allT) {
      if (t > 0 && t < 1) {
        final point = MathUtils.cubicBezier(p0, p1, p2, p3, t);
        tracker.updateWithPoint(transform.transform(point));
      }
    }
  }

  /// Find t values where the cubic Bezier curve has extrema in one dimension
  static List<double> _findCubicExtremaT(
    double v0,
    double v1,
    double v2,
    double v3,
  ) {
    // Coefficients for the derivative quadratic equation
    // B'(t) = 3(1-t)²(v1-v0) + 6(1-t)t(v2-v1) + 3t²(v3-v2)
    // Expanding and collecting terms: at² + bt + c = 0

    final a = -v0 + 3 * v1 - 3 * v2 + v3;
    final b = 2 * (v0 - 2 * v1 + v2);
    final c = -v0 + v1;

    final extrema = <double>[];

    // Check if it's actually a quadratic (a != 0)
    if (a.abs() < 1e-10) {
      // Linear case: bt + c = 0
      if (b.abs() > 1e-10) {
        final t = -c / b;
        if (t > 0 && t < 1) {
          extrema.add(t);
        }
      }
    } else {
      // Quadratic case: at² + bt + c = 0
      final discriminant = b * b - 4 * a * c;
      if (discriminant >= 0) {
        final sqrtDiscriminant = math.sqrt(discriminant);
        final t1 = (-b + sqrtDiscriminant) / (2 * a);
        final t2 = (-b - sqrtDiscriminant) / (2 * a);

        if (t1 > 0 && t1 < 1) {
          extrema.add(t1);
        }
        if (t2 > 0 && t2 < 1 && (t2 - t1).abs() > 1e-10) {
          extrema.add(t2);
        }
      }
    }

    return extrema;
  }
}

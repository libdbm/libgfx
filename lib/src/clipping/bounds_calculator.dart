import 'dart:math' as math;

import '../matrix.dart';
import '../paths/path.dart';
import '../point.dart';
import '../rectangle.dart';
import '../utils/curve_utils.dart';
import '../utils/math_utils.dart';

/// Helper class to track bounds
class _Tracker {
  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = double.negativeInfinity;
  double maxY = double.negativeInfinity;

  void update(Point p) {
    minX = math.min(minX, p.x);
    minY = math.min(minY, p.y);
    maxX = math.max(maxX, p.x);
    maxY = math.max(maxY, p.y);
  }

  Rectangle<double> bounds() {
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

    final tracker = _Tracker();
    Point? current;

    for (final command in path.commands) {
      current = _process(command, transform, tracker, current);
    }

    return tracker.bounds();
  }

  static Point? _process(
    final PathCommand command,
    Matrix2D transform,
    _Tracker tracker,
    final Point? current,
  ) {
    switch (command.type) {
      case PathCommandType.moveTo:
      case PathCommandType.lineTo:
        final point = command.points.first;
        tracker.update(transform.transform(point));
        return point;

      case PathCommandType.cubicCurveTo:
        return _cubic(command, transform, tracker, current);

      case PathCommandType.arc:
        _arc(command as ArcCommand, transform, tracker);
        // Arc commands update the current point to the end of the arc
        final endAngle = command.endAngle;
        return MathUtils.circlePoint(
          command.centerX,
          command.centerY,
          command.radius,
          endAngle,
        );

      case PathCommandType.ellipse:
        _ellipse(command as EllipseCommand, transform, tracker);
        // Ellipse commands update the current point to the end of the ellipse
        final endAngle = command.endAngle;
        return MathUtils.ellipsePoint(
          command.centerX,
          command.centerY,
          command.radiusX,
          command.radiusY,
          command.rotation,
          endAngle,
        );

      case PathCommandType.close:
        // Close doesn't change the current point
        return current;
    }
  }

  static Point _cubic(
    final PathCommand command,
    Matrix2D transform,
    _Tracker tracker,
    final Point? current,
  ) {
    if (command.points.length < 3) {
      // Invalid cubic curve
      return current ?? Point(0, 0);
    }

    final p0 = current ?? Point(0, 0);
    final p1 = command.points[0]; // First control point
    final p2 = command.points[1]; // Second control point
    final p3 = command.points[2]; // End point

    // Include end points
    tracker.update(transform.transform(p0));
    tracker.update(transform.transform(p3));

    // Calculate and include extrema points
    _extrema(p0, p1, p2, p3, transform, tracker);

    return p3;
  }

  static void _arc(ArcCommand arc, Matrix2D transform, _Tracker tracker) {
    final angles = CurveUtils.getArcExtremaAngles(
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
      tracker.update(transform.transform(point));
    }
  }

  static void _ellipse(
    EllipseCommand ellipse,
    Matrix2D transform,
    _Tracker tracker,
  ) {
    final angles = CurveUtils.getEllipseExtremaAngles(
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
      tracker.update(transform.transform(point));
    }
  }

  /// Calculate extrema points for cubic Bezier curves
  static void _extrema(
    Point p0,
    Point p1,
    Point p2,
    Point p3,
    Matrix2D transform,
    _Tracker tracker,
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
    final xExtrema = _solve(p0.x, p1.x, p2.x, p3.x);

    // Calculate extrema for Y dimension
    final yExtrema = _solve(p0.y, p1.y, p2.y, p3.y);

    // Evaluate the curve at each extrema point
    final roots = [...xExtrema, ...yExtrema];
    for (final t in roots) {
      if (t > 0 && t < 1) {
        final point = MathUtils.cubicBezier(p0, p1, p2, p3, t);
        tracker.update(transform.transform(point));
      }
    }
  }

  /// Find t values where the cubic Bezier curve has extrema in one dimension
  static List<double> _solve(double v0, double v1, double v2, double v3) {
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
        final root = math.sqrt(discriminant);
        final t1 = (-b + root) / (2 * a);
        final t2 = (-b - root) / (2 * a);

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

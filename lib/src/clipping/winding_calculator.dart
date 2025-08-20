import '../paths/path.dart';
import '../point.dart';
import '../utils/math_utils.dart';

/// Calculates winding numbers for point-in-path tests
class WindingCalculator {
  /// Calculate winding number for a point relative to a path
  static int calculateWindingNumber(Point testPoint, Path path) {
    int winding = 0;
    Point? lastPoint;
    Point? firstPoint;

    for (final cmd in path.commands) {
      switch (cmd.type) {
        case PathCommandType.moveTo:
          firstPoint = cmd.points.first;
          lastPoint = firstPoint;
          break;

        case PathCommandType.lineTo:
          if (lastPoint != null) {
            winding += _windingContribution(
              lastPoint,
              cmd.points.first,
              testPoint,
            );
            lastPoint = cmd.points.first;
          }
          break;

        case PathCommandType.cubicCurveTo:
          if (lastPoint != null && cmd.points.length >= 3) {
            // Approximate cubic curve with line segments
            const int segments = 16;
            for (int i = 0; i < segments; i++) {
              final t1 = i / segments;
              final t2 = (i + 1) / segments;
              final p1 = MathUtils.cubicBezier(
                lastPoint,
                cmd.points[0],
                cmd.points[1],
                cmd.points[2],
                t1,
              );
              final p2 = MathUtils.cubicBezier(
                lastPoint,
                cmd.points[0],
                cmd.points[1],
                cmd.points[2],
                t2,
              );
              winding += _windingContribution(p1, p2, testPoint);
            }
            lastPoint = cmd.points[2];
          }
          break;

        case PathCommandType.arc:
          if (lastPoint != null) {
            final arc = cmd as ArcCommand;
            winding += _arcWindingContribution(arc, lastPoint, testPoint);

            // Update last point to arc end
            lastPoint = MathUtils.circlePoint(
              arc.centerX,
              arc.centerY,
              arc.radius,
              arc.endAngle,
            );
          }
          break;

        case PathCommandType.ellipse:
          if (lastPoint != null) {
            final ellipse = cmd as EllipseCommand;
            winding += _ellipseWindingContribution(
              ellipse,
              lastPoint,
              testPoint,
            );

            // Update last point to ellipse end
            lastPoint = MathUtils.ellipsePoint(
              ellipse.centerX,
              ellipse.centerY,
              ellipse.radiusX,
              ellipse.radiusY,
              ellipse.rotation,
              ellipse.endAngle,
            );
          }
          break;

        case PathCommandType.close:
          if (lastPoint != null && firstPoint != null) {
            winding += _windingContribution(lastPoint, firstPoint, testPoint);
            lastPoint = firstPoint;
          }
          break;
      }
    }

    return winding;
  }

  /// Calculate the winding contribution of a line segment
  static int _windingContribution(Point p1, Point p2, Point test) {
    // Check if the segment crosses the ray from test point to the right
    if (p1.y <= test.y) {
      if (p2.y > test.y) {
        // Upward crossing
        if (_isLeft(p1, p2, test) > 0) {
          return 1;
        }
      }
    } else {
      if (p2.y <= test.y) {
        // Downward crossing
        if (_isLeft(p1, p2, test) < 0) {
          return -1;
        }
      }
    }
    return 0;
  }

  /// Test if point is left/on/right of an infinite line
  /// Returns: >0 for left, 0 for on, <0 for right
  static double _isLeft(Point p0, Point p1, Point p2) {
    return ((p1.x - p0.x) * (p2.y - p0.y) - (p2.x - p0.x) * (p1.y - p0.y));
  }

  /// Calculate winding contribution for an arc
  static int _arcWindingContribution(
    ArcCommand arc,
    Point lastPoint,
    Point test,
  ) {
    // Approximate arc with line segments
    const int segments = 16;
    int winding = 0;
    Point prevPoint = lastPoint;

    for (int i = 1; i <= segments; i++) {
      final t = i / segments;
      final angle = arc.startAngle + t * (arc.endAngle - arc.startAngle);
      final point = MathUtils.circlePoint(
        arc.centerX,
        arc.centerY,
        arc.radius,
        angle,
      );
      winding += _windingContribution(prevPoint, point, test);
      prevPoint = point;
    }

    return winding;
  }

  /// Calculate winding contribution for an ellipse
  static int _ellipseWindingContribution(
    EllipseCommand ellipse,
    Point lastPoint,
    Point test,
  ) {
    // Approximate ellipse with line segments
    const int segments = 16;
    int winding = 0;
    Point prevPoint = lastPoint;

    for (int i = 1; i <= segments; i++) {
      final t = i / segments;
      final angle =
          ellipse.startAngle + t * (ellipse.endAngle - ellipse.startAngle);
      final point = MathUtils.ellipsePoint(
        ellipse.centerX,
        ellipse.centerY,
        ellipse.radiusX,
        ellipse.radiusY,
        ellipse.rotation,
        angle,
      );
      winding += _windingContribution(prevPoint, point, test);
      prevPoint = point;
    }

    return winding;
  }
}

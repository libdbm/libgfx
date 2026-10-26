import '../paths/path.dart';
import '../point.dart';
import '../utils/math_utils.dart';

/// Calculates winding numbers for point-in-path tests
class WindingCalculator {
  /// Calculate winding number for a point relative to a path
  static int calculateWindingNumber(final Point point, Path path) {
    int winding = 0;
    Point? last;
    Point? first;

    for (final command in path.commands) {
      switch (command.type) {
        case PathCommandType.moveTo:
          first = command.points.first;
          last = first;
          break;

        case PathCommandType.lineTo:
          if (last != null) {
            winding += _contribution(last, command.points.first, point);
            last = command.points.first;
          }
          break;

        case PathCommandType.cubicCurveTo:
          if (last != null && command.points.length >= 3) {
            // Approximate cubic curve with line segments
            const int segments = 16;
            for (int i = 0; i < segments; i++) {
              final t1 = i / segments;
              final t2 = (i + 1) / segments;
              final p1 = MathUtils.cubicBezier(
                last,
                command.points[0],
                command.points[1],
                command.points[2],
                t1,
              );
              final p2 = MathUtils.cubicBezier(
                last,
                command.points[0],
                command.points[1],
                command.points[2],
                t2,
              );
              winding += _contribution(p1, p2, point);
            }
            last = command.points[2];
          }
          break;

        case PathCommandType.arc:
          if (last != null) {
            final arc = command as ArcCommand;
            winding += _arc(arc, last, point);

            // Update last point to arc end
            last = MathUtils.circlePoint(
              arc.centerX,
              arc.centerY,
              arc.radius,
              arc.endAngle,
            );
          }
          break;

        case PathCommandType.ellipse:
          if (last != null) {
            final ellipse = command as EllipseCommand;
            winding += _ellipse(ellipse, last, point);

            // Update last point to ellipse end
            last = MathUtils.ellipsePoint(
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
          if (last != null && first != null) {
            winding += _contribution(last, first, point);
            last = first;
          }
          break;
      }
    }

    return winding;
  }

  /// Calculate the winding contribution of a line segment
  static int _contribution(Point p1, Point p2, Point test) {
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
  static int _arc(ArcCommand arc, final Point start, Point test) {
    // Approximate arc with line segments
    const int segments = 16;
    int winding = 0;
    Point previous = start;

    for (int i = 1; i <= segments; i++) {
      final t = i / segments;
      final angle = arc.startAngle + t * (arc.endAngle - arc.startAngle);
      final point = MathUtils.circlePoint(
        arc.centerX,
        arc.centerY,
        arc.radius,
        angle,
      );
      winding += _contribution(previous, point, test);
      previous = point;
    }

    return winding;
  }

  /// Calculate winding contribution for an ellipse
  static int _ellipse(EllipseCommand ellipse, final Point start, Point test) {
    // Approximate ellipse with line segments
    const int segments = 16;
    int winding = 0;
    Point previous = start;

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
      winding += _contribution(previous, point, test);
      previous = point;
    }

    return winding;
  }
}

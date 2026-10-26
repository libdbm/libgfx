import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../graphics_state.dart';
import '../matrix.dart';
import '../point.dart';
import '../utils/curve_utils.dart';
import '../utils/math_utils.dart';
import '../utils/stroker.dart';
import 'path.dart';

/// Numerical constants for robust geometric operations
class _NumericalConstants {
  /// Minimum segments for curve approximation
  static const int minCurveSegments = 4;

  /// Maximum segments for curve approximation
  static const int maxCurveSegments = 64;
}

/// Edge classification for boolean operations
const int _subject = 0;
const int _clip = 1;

/// Boolean operation types
enum _Operation { union, intersection, difference, xor }

/// Edge record for boolean operations
class _Edge {
  final Point start;
  final Point end;
  final int type;
  final bool entering;

  _Edge(this.start, this.end, this.type, this.entering);

  double get minY => math.min(start.y, end.y);
  double get maxY => math.max(start.y, end.y);
  double get minX => math.min(start.x, end.x);
  double get maxX => math.max(start.x, end.x);

  /// Check if this edge intersects with another
  Point? intersects(_Edge other) {
    final x1 = start.x, y1 = start.y;
    final x2 = end.x, y2 = end.y;
    final x3 = other.start.x, y3 = other.start.y;
    final x4 = other.end.x, y4 = other.end.y;

    // Direction vectors
    final dx1 = x2 - x1;
    final dy1 = y2 - y1;
    final dx2 = x4 - x3;
    final dy2 = y4 - y3;

    // Calculate the denominator
    final denominator = dx1 * dy2 - dy1 * dx2;

    // Check for parallel lines
    if (denominator.abs() < MathUtils.epsilon) {
      return null;
    }

    // Calculate intersection parameters
    final t1 = ((x3 - x1) * dy2 - (y3 - y1) * dx2) / denominator;
    final t2 = ((x3 - x1) * dy1 - (y3 - y1) * dx1) / denominator;

    // Check if intersection is within both segments
    if (t1 >= 0 && t1 <= 1 && t2 >= 0 && t2 <= 1) {
      return Point(x1 + t1 * dx1, y1 + t1 * dy1);
    }

    return null;
  }
}

/// Path operations class combining boolean operations, simplification, and transformation
class PathOperations {
  /// Transform a path using the given matrix
  static Path transform(Path path, Matrix2D matrix) {
    final result = Path();

    for (final command in path.commands) {
      if (command is ArcCommand) {
        // Transform arc center (converting to bezier curves handles the transformation)
        // because scaling may turn circles into ellipses
        _arc(result, command, matrix);
      } else if (command is EllipseCommand) {
        // Convert ellipse to bezier curves for transformation
        _ellipse(result, command, matrix);
      } else {
        final points = command.points.map((p) => matrix.transform(p)).toList();
        result.add(PathCommand(command.type, points));
      }
    }

    return result;
  }

  static void _arc(final Path target, ArcCommand arc, Matrix2D matrix) {
    // Convert arc to bezier curves for transformation
    final sweep = arc.endAngle - arc.startAngle;
    final span = sweep.abs();
    final segments = (span / (math.pi / 2)).ceil();
    if (segments == 0) return;

    final step = sweep / segments;
    final factor = (4 / 3) * math.tan(step / 4);

    double angle = arc.startAngle;
    final start = MathUtils.circlePoint(
      arc.centerX,
      arc.centerY,
      arc.radius,
      angle,
    );
    double x = start.x;
    double y = start.y;

    // Transform and add the initial move to point
    if (target.commands.isEmpty) {
      target.add(
        PathCommand(PathCommandType.moveTo, [matrix.transform(Point(x, y))]),
      );
    }

    for (int i = 0; i < segments; i++) {
      final previous = angle;
      angle += step;

      // Calculate tangent points
      final tx0 = -arc.radius * math.sin(previous);
      final ty0 = arc.radius * math.cos(previous);
      final tx1 = -arc.radius * math.sin(angle);
      final ty1 = arc.radius * math.cos(angle);

      // Calculate control points
      final cp1x = x + factor * tx0;
      final cp1y = y + factor * ty0;

      final next = MathUtils.circlePoint(
        arc.centerX,
        arc.centerY,
        arc.radius,
        angle,
      );
      x = next.x;
      y = next.y;

      final cp2x = x - factor * tx1;
      final cp2y = y - factor * ty1;

      // Transform and add the cubic curve
      final p1 = matrix.transform(Point(cp1x, cp1y));
      final p2 = matrix.transform(Point(cp2x, cp2y));
      final p3 = matrix.transform(Point(x, y));

      target.add(PathCommand(PathCommandType.cubicCurveTo, [p1, p2, p3]));
    }
  }

  static void _ellipse(
    final Path target,
    EllipseCommand ellipse,
    Matrix2D matrix,
  ) {
    // Convert ellipse to bezier curves
    final sweep = ellipse.endAngle - ellipse.startAngle;
    final span = sweep.abs();
    final segments = (span / (math.pi / 2)).ceil();
    if (segments == 0) return;

    final step = sweep / segments;
    final factor = (4 / 3) * math.tan(step / 4);

    // Create rotation matrix for the ellipse
    final cos = math.cos(ellipse.rotation);
    final sin = math.sin(ellipse.rotation);

    double angle = ellipse.startAngle;

    // Calculate initial point on unrotated ellipse
    double ellipseX = ellipse.radiusX * math.cos(angle);
    double ellipseY = ellipse.radiusY * math.sin(angle);

    // Apply rotation
    double x = ellipse.centerX + ellipseX * cos - ellipseY * sin;
    double y = ellipse.centerY + ellipseX * sin + ellipseY * cos;

    // Transform and add the initial move to point
    if (target.commands.isEmpty) {
      target.add(
        PathCommand(PathCommandType.moveTo, [matrix.transform(Point(x, y))]),
      );
    }

    for (int i = 0; i < segments; i++) {
      final previous = angle;
      angle += step;

      // Calculate tangent points on the ellipse
      final tx0 = -ellipse.radiusX * math.sin(previous);
      final ty0 = ellipse.radiusY * math.cos(previous);
      final tx1 = -ellipse.radiusX * math.sin(angle);
      final ty1 = ellipse.radiusY * math.cos(angle);

      // Apply rotation to tangent vectors
      final rx0 = tx0 * cos - ty0 * sin;
      final ry0 = tx0 * sin + ty0 * cos;
      final rx1 = tx1 * cos - ty1 * sin;
      final ry1 = tx1 * sin + ty1 * cos;

      // Calculate control points
      final cp1x = x + factor * rx0;
      final cp1y = y + factor * ry0;

      // Calculate new position on unrotated ellipse
      ellipseX = ellipse.radiusX * math.cos(angle);
      ellipseY = ellipse.radiusY * math.sin(angle);

      // Apply rotation
      x = ellipse.centerX + ellipseX * cos - ellipseY * sin;
      y = ellipse.centerY + ellipseX * sin + ellipseY * cos;

      final cp2x = x - factor * rx1;
      final cp2y = y - factor * ry1;

      // Transform and add the cubic curve
      final p1 = matrix.transform(Point(cp1x, cp1y));
      final p2 = matrix.transform(Point(cp2x, cp2y));
      final p3 = matrix.transform(Point(x, y));

      target.add(PathCommand(PathCommandType.cubicCurveTo, [p1, p2, p3]));
    }
  }

  /// Simplify a path by removing redundant points using Douglas-Peucker algorithm
  static Path simplify(Path path, {double tolerance = 0.1}) {
    if (path.commands.isEmpty) return Path();

    final simplified = Path();
    final points = <Point>[];
    Point? last;

    // Collect all points from the path in order
    for (final command in path.commands) {
      if (command.type == PathCommandType.moveTo && command.points.isNotEmpty) {
        // Process any collected line points first
        if (points.isNotEmpty) {
          final reduced = _douglasPeucker(points, tolerance);
          _append(simplified, reduced);
          points.clear();
        }
        points.add(command.points[0]);
        last = command.points[0];
      } else if (command.type == PathCommandType.lineTo &&
          command.points.isNotEmpty) {
        points.add(command.points[0]);
        last = command.points[0];
      } else if (command.type == PathCommandType.cubicCurveTo &&
          command.points.length >= 3) {
        // Flatten cubic curve to line segments
        if (last != null) {
          final flattened = CurveUtils.flattenCubicBezier(
            last,
            command.points[0], // control point 1
            command.points[1], // control point 2
            command.points[2], // end point
            tolerance: tolerance,
          );
          // Add flattened points (skip first as it's the current point)
          for (int i = 1; i < flattened.length; i++) {
            points.add(flattened[i]);
          }
          last = command.points[2];
        }
      } else {
        // Process any collected line points and then add this command
        if (points.isNotEmpty) {
          final reduced = _douglasPeucker(points, tolerance);
          _append(simplified, reduced);
          points.clear();
        }
        // Add the command as-is
        simplified.add(command);
        if (command.points.isNotEmpty) {
          last = command.points.last;
        }
      }
    }

    // Process any remaining line points
    if (points.isNotEmpty) {
      final reduced = _douglasPeucker(points, tolerance);
      _append(simplified, reduced);
    }

    return simplified;
  }

  /// Douglas-Peucker algorithm implementation. Works on index ranges with
  /// a flag per kept point; a stack of ranges replaces recursion, so a long
  /// path cannot overflow the call stack.
  static List<Point> _douglasPeucker(List<Point> points, double tolerance) {
    if (points.length <= 2) {
      return points;
    }

    final keep = List.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;
    final ranges = [(0, points.length - 1)];

    while (ranges.isNotEmpty) {
      final (first, last) = ranges.removeLast();

      // Find the point with the maximum distance from the line segment
      double maximum = 0;
      int index = 0;
      for (int i = first + 1; i < last; i++) {
        final distance = _distance(points[i], points[first], points[last]);
        if (distance > maximum) {
          maximum = distance;
          index = i;
        }
      }

      // Keep it and simplify both sides, or drop everything in between
      if (maximum > tolerance) {
        keep[index] = true;
        ranges
          ..add((first, index))
          ..add((index, last));
      }
    }

    return [
      for (int i = 0; i < points.length; i++)
        if (keep[i]) points[i],
    ];
  }

  /// Calculate perpendicular distance from point to line segment
  static double _distance(Point point, final Point start, final Point end) {
    return CurveUtils.distanceToSegment(point, start, end);
  }

  /// Add simplified points to the path
  static void _append(Path path, List<Point> points) {
    if (points.isEmpty) return;

    bool fresh =
        path.commands.isEmpty ||
        path.commands.last.type == PathCommandType.close;

    for (int i = 0; i < points.length; i++) {
      if (i == 0 && fresh) {
        path.add(PathCommand(PathCommandType.moveTo, [points[i]]));
      } else if (i > 0) {
        path.add(PathCommand(PathCommandType.lineTo, [points[i]]));
      }
    }
  }

  /// Experimental: joins the outlines of [first] and [second] into one ring,
  /// the points of [first] followed by those of [second]. This is not an area
  /// union: overlapping or contained shapes are not merged. If either path
  /// is empty, the other is returned.
  ///
  /// Each path is flattened into a single ring: the points of all its
  /// contours are joined in order, cubic curves are subdivided, and arc and
  /// ellipse commands are dropped. The result is one closed ring, or empty.
  @experimental
  static Path union(Path first, Path second) {
    return _combine(first, second, _Operation.union);
  }

  /// Experimental: a ring through the endpoints of every edge of either
  /// path that crosses an edge of the other. This is not the area
  /// intersection: it is empty when the outlines do not cross, including
  /// when one shape lies inside the other, and empty if either path is
  /// empty.
  ///
  /// Each path is flattened into a single ring: the points of all its
  /// contours are joined in order, cubic curves are subdivided, and arc and
  /// ellipse commands are dropped. The result is one closed ring, or empty.
  @experimental
  static Path intersection(Path first, Path second) {
    return _combine(first, second, _Operation.intersection);
  }

  /// Experimental: a ring through the edges of [first] that do not cross
  /// [second]. [second]'s area is never subtracted: when the outlines do not
  /// cross, [first] is returned whole, even if [second] lies inside it.
  /// Empty if [first] is empty; [first] if [second] is empty.
  ///
  /// Each path is flattened into a single ring: the points of all its
  /// contours are joined in order, cubic curves are subdivided, and arc and
  /// ellipse commands are dropped. The result is one closed ring, or empty.
  @experimental
  static Path difference(Path first, Path second) {
    return _combine(first, second, _Operation.difference);
  }

  /// Experimental: a ring through the edges of either path that do not
  /// cross the other. When the outlines do not cross this is the same as
  /// [union]. If either path is empty, the other is returned.
  ///
  /// Each path is flattened into a single ring: the points of all its
  /// contours are joined in order, cubic curves are subdivided, and arc and
  /// ellipse commands are dropped. The result is one closed ring, or empty.
  @experimental
  static Path xor(Path first, Path second) {
    return _combine(first, second, _Operation.xor);
  }

  /// Main boolean operation implementation
  static Path _combine(Path first, Path second, final _Operation operation) {
    // Tessellate paths to polygons
    final polygon1 = _polygon(first);
    final polygon2 = _polygon(second);

    if (polygon1.isEmpty && polygon2.isEmpty) return Path();
    if (polygon1.isEmpty) {
      return (operation == _Operation.union || operation == _Operation.xor)
          ? second.clone()
          : Path();
    }
    if (polygon2.isEmpty) {
      return (operation == _Operation.union ||
              operation == _Operation.difference ||
              operation == _Operation.xor)
          ? first.clone()
          : Path();
    }

    // Build edge lists
    final edges = <_Edge>[];

    // Add subject edges
    for (int i = 0; i < polygon1.length; i++) {
      final next = (i + 1) % polygon1.length;
      edges.add(_Edge(polygon1[i], polygon1[next], _subject, true));
    }

    // Add clip edges
    for (int i = 0; i < polygon2.length; i++) {
      final next = (i + 1) % polygon2.length;
      edges.add(_Edge(polygon2[i], polygon2[next], _clip, true));
    }

    // Find all intersections
    final intersections = _intersections(edges);

    // Build result path based on operation
    return _build(edges, intersections, operation);
  }

  /// Tessellate a path to a polygon (list of points)
  static List<Point> _polygon(Path path) {
    final points = <Point>[];
    Point? last;

    for (final command in path.commands) {
      if (command.type == PathCommandType.moveTo && command.points.isNotEmpty) {
        points.add(command.points[0]);
        last = command.points[0];
      } else if (command.type == PathCommandType.lineTo &&
          command.points.isNotEmpty) {
        points.add(command.points[0]);
        last = command.points[0];
      } else if (command.type == PathCommandType.cubicCurveTo &&
          command.points.length >= 3) {
        // Tessellate cubic curve
        if (last != null) {
          final tessellated = _tessellate(
            last,
            command.points[0],
            command.points[1],
            command.points[2],
          );
          // Skip first point as it's already in the list
          for (int i = 1; i < tessellated.length; i++) {
            points.add(tessellated[i]);
          }
          last = command.points[2];
        }
      }
    }

    return points;
  }

  /// Tessellate a cubic Bezier curve
  static List<Point> _tessellate(Point p0, Point p1, Point p2, Point p3) {
    // Estimate number of segments needed
    final hull = p0.distance(p1) + p1.distance(p2) + p2.distance(p3);
    final chord = p0.distance(p3);

    if (hull == 0) return [p0, p3];

    final segments = math.max(
      _NumericalConstants.minCurveSegments,
      math.min(
        _NumericalConstants.maxCurveSegments,
        (hull / math.max(chord, 1.0) * 8).round(),
      ),
    );

    final points = <Point>[p0];

    for (int i = 1; i <= segments; i++) {
      final t = i / segments;
      final t2 = t * t;
      final t3 = t2 * t;
      final mt = 1 - t;
      final mt2 = mt * mt;
      final mt3 = mt2 * mt;

      final x =
          mt3 * p0.x + 3 * mt2 * t * p1.x + 3 * mt * t2 * p2.x + t3 * p3.x;
      final y =
          mt3 * p0.y + 3 * mt2 * t * p1.y + 3 * mt * t2 * p2.y + t3 * p3.y;

      points.add(Point(x, y));
    }

    return points;
  }

  /// Find all intersections between edges
  static Map<_Edge, List<Point>> _intersections(List<_Edge> edges) {
    final intersections = <_Edge, List<Point>>{};

    for (int i = 0; i < edges.length; i++) {
      for (int j = i + 1; j < edges.length; j++) {
        if (edges[i].type != edges[j].type) {
          final intersection = edges[i].intersects(edges[j]);
          if (intersection != null) {
            intersections.putIfAbsent(edges[i], () => []).add(intersection);
            intersections.putIfAbsent(edges[j], () => []).add(intersection);
          }
        }
      }
    }

    return intersections;
  }

  /// Build result path from edges and intersections
  static Path _build(
    List<_Edge> edges,
    Map<_Edge, List<Point>> intersections,
    final _Operation operation,
  ) {
    // This is a simplified implementation
    // A full implementation would require a sweep line algorithm
    // For now, return a simple union approximation

    final builder = PathBuilder();
    final visited = <Point>{};

    for (final edge in edges) {
      bool include = false;

      switch (operation) {
        case _Operation.union:
          include = true;
          break;
        case _Operation.intersection:
          include = intersections.containsKey(edge);
          break;
        case _Operation.difference:
          include = edge.type == _subject && !intersections.containsKey(edge);
          break;
        case _Operation.xor:
          include = !intersections.containsKey(edge);
          break;
      }

      if (include) {
        if (!visited.contains(edge.start)) {
          if (visited.isEmpty) {
            builder.moveTo(edge.start.x, edge.start.y);
          } else {
            builder.lineTo(edge.start.x, edge.start.y);
          }
          visited.add(edge.start);
        }
        if (!visited.contains(edge.end)) {
          builder.lineTo(edge.end.x, edge.end.y);
          visited.add(edge.end);
        }
      }
    }

    if (visited.isNotEmpty) {
      builder.closePath();
    }

    return builder.build();
  }

  /// Experimental: the outline of [path] stroked with width
  /// `2 * distance.abs()` (butt caps, miter joins), so it covers [distance]
  /// on both sides of the path. The sign of [distance] is ignored: there are
  /// no separate inside or outside offsets, and self-intersections are not
  /// removed.
  @experimental
  static Path offset(Path path, double distance) {
    // For now, this is a simplified implementation that uses the stroker.
    // A more complete implementation would handle self-intersections.
    final stroker = Stroker();
    final state = GraphicsState()..strokeWidth = distance.abs() * 2;
    final stroked = stroker.stroke(path, state);

    // This is a hack. A real implementation would be much more complex.
    // We are taking the result of the stroker and hoping it's what we want.
    // This will not work correctly for inside offsets or complex shapes.
    return stroked;
  }
}

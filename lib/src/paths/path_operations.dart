import 'dart:math' as math;

import '../matrix.dart';
import 'path.dart';
import '../point.dart';
import '../utils/curve_utils.dart';
import '../utils/geometry_utils.dart';
import '../utils/math_utils.dart';

/// Numerical constants for robust geometric operations
class _NumericalConstants {
  /// Minimum segments for curve approximation
  static const int minCurveSegments = 4;

  /// Maximum segments for curve approximation
  static const int maxCurveSegments = 64;
}

/// Edge classification for boolean operations
const int _EDGE_SUBJECT = 0;
const int _EDGE_CLIP = 1;

/// Boolean operation types
enum _BooleanOp { union, intersection, difference, xor }

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

  /// Get X coordinate at given Y
  double xAtY(double y) {
    final dy = end.y - start.y;
    if (dy.abs() < MathUtils.epsilon) {
      return start.x; // Horizontal edge
    }
    final t = (y - start.y) / dy;
    final clampedT = t.clamp(0.0, 1.0);
    return start.x + clampedT * (end.x - start.x);
  }

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
    final denom = dx1 * dy2 - dy1 * dx2;

    // Check for parallel lines
    if (denom.abs() < MathUtils.epsilon) {
      return null;
    }

    // Calculate intersection parameters
    final t1 = ((x3 - x1) * dy2 - (y3 - y1) * dx2) / denom;
    final t2 = ((x3 - x1) * dy1 - (y3 - y1) * dx1) / denom;

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
    final newPath = Path();

    for (final cmd in path.commands) {
      if (cmd is ArcCommand) {
        // Transform arc center (converting to bezier curves handles the transformation)
        // because scaling may turn circles into ellipses
        _addArcAsBezierCurves(newPath, cmd, matrix);
      } else if (cmd is EllipseCommand) {
        // Convert ellipse to bezier curves for transformation
        _addEllipseAsBezierCurves(newPath, cmd, matrix);
      } else {
        final transformedPoints = cmd.points
            .map((p) => matrix.transform(p))
            .toList();
        newPath.addCommand(PathCommand(cmd.type, transformedPoints));
      }
    }

    return newPath;
  }

  static void _addArcAsBezierCurves(
    Path targetPath,
    ArcCommand arc,
    Matrix2D matrix,
  ) {
    // Convert arc to bezier curves for transformation
    final sweepAngle = arc.endAngle - arc.startAngle;
    final absAngle = sweepAngle.abs();
    final segments = (absAngle / (math.pi / 2)).ceil();
    if (segments == 0) return;

    final angleStep = sweepAngle / segments;
    final tangentFactor = (4 / 3) * math.tan(angleStep / 4);

    double currentAngle = arc.startAngle;
    final currentPoint = MathUtils.circlePoint(
      arc.centerX,
      arc.centerY,
      arc.radius,
      currentAngle,
    );
    double currentX = currentPoint.x;
    double currentY = currentPoint.y;

    // Transform and add the initial move to point
    if (targetPath.commands.isEmpty) {
      targetPath.addCommand(
        PathCommand(PathCommandType.moveTo, [
          matrix.transform(Point(currentX, currentY)),
        ]),
      );
    }

    for (int i = 0; i < segments; i++) {
      final prevAngle = currentAngle;
      currentAngle += angleStep;

      // Calculate tangent points
      final prevTanX = -arc.radius * math.sin(prevAngle);
      final prevTanY = arc.radius * math.cos(prevAngle);
      final currTanX = -arc.radius * math.sin(currentAngle);
      final currTanY = arc.radius * math.cos(currentAngle);

      // Calculate control points
      final cp1x = currentX + tangentFactor * prevTanX;
      final cp1y = currentY + tangentFactor * prevTanY;

      final newPoint = MathUtils.circlePoint(
        arc.centerX,
        arc.centerY,
        arc.radius,
        currentAngle,
      );
      currentX = newPoint.x;
      currentY = newPoint.y;

      final cp2x = currentX - tangentFactor * currTanX;
      final cp2y = currentY - tangentFactor * currTanY;

      // Transform and add the cubic curve
      final p1 = matrix.transform(Point(cp1x, cp1y));
      final p2 = matrix.transform(Point(cp2x, cp2y));
      final p3 = matrix.transform(Point(currentX, currentY));

      targetPath.addCommand(
        PathCommand(PathCommandType.cubicCurveTo, [p1, p2, p3]),
      );
    }
  }

  static void _addEllipseAsBezierCurves(
    Path targetPath,
    EllipseCommand ellipse,
    Matrix2D matrix,
  ) {
    // Convert ellipse to bezier curves
    final sweepAngle = ellipse.endAngle - ellipse.startAngle;
    final absAngle = sweepAngle.abs();
    final segments = (absAngle / (math.pi / 2)).ceil();
    if (segments == 0) return;

    final angleStep = sweepAngle / segments;
    final tangentFactor = (4 / 3) * math.tan(angleStep / 4);

    // Create rotation matrix for the ellipse
    final cos = math.cos(ellipse.rotation);
    final sin = math.sin(ellipse.rotation);

    double currentAngle = ellipse.startAngle;

    // Calculate initial point on unrotated ellipse
    double ellipseX = ellipse.radiusX * math.cos(currentAngle);
    double ellipseY = ellipse.radiusY * math.sin(currentAngle);

    // Apply rotation
    double currentX = ellipse.centerX + ellipseX * cos - ellipseY * sin;
    double currentY = ellipse.centerY + ellipseX * sin + ellipseY * cos;

    // Transform and add the initial move to point
    if (targetPath.commands.isEmpty) {
      targetPath.addCommand(
        PathCommand(PathCommandType.moveTo, [
          matrix.transform(Point(currentX, currentY)),
        ]),
      );
    }

    for (int i = 0; i < segments; i++) {
      final prevAngle = currentAngle;
      currentAngle += angleStep;

      // Calculate tangent points on the ellipse
      final prevTanX = -ellipse.radiusX * math.sin(prevAngle);
      final prevTanY = ellipse.radiusY * math.cos(prevAngle);
      final currTanX = -ellipse.radiusX * math.sin(currentAngle);
      final currTanY = ellipse.radiusY * math.cos(currentAngle);

      // Apply rotation to tangent vectors
      final rotPrevTanX = prevTanX * cos - prevTanY * sin;
      final rotPrevTanY = prevTanX * sin + prevTanY * cos;
      final rotCurrTanX = currTanX * cos - currTanY * sin;
      final rotCurrTanY = currTanX * sin + currTanY * cos;

      // Calculate control points
      final cp1x = currentX + tangentFactor * rotPrevTanX;
      final cp1y = currentY + tangentFactor * rotPrevTanY;

      // Calculate new position on unrotated ellipse
      ellipseX = ellipse.radiusX * math.cos(currentAngle);
      ellipseY = ellipse.radiusY * math.sin(currentAngle);

      // Apply rotation
      currentX = ellipse.centerX + ellipseX * cos - ellipseY * sin;
      currentY = ellipse.centerY + ellipseX * sin + ellipseY * cos;

      final cp2x = currentX - tangentFactor * rotCurrTanX;
      final cp2y = currentY - tangentFactor * rotCurrTanY;

      // Transform and add the cubic curve
      final p1 = matrix.transform(Point(cp1x, cp1y));
      final p2 = matrix.transform(Point(cp2x, cp2y));
      final p3 = matrix.transform(Point(currentX, currentY));

      targetPath.addCommand(
        PathCommand(PathCommandType.cubicCurveTo, [p1, p2, p3]),
      );
    }
  }

  /// Simplify a path by removing redundant points using Douglas-Peucker algorithm
  static Path simplify(Path path, {double tolerance = 0.1}) {
    if (path.commands.isEmpty) return Path();

    final simplified = Path();
    final linePoints = <Point>[];
    Point? lastPoint;

    // Collect all points from the path in order
    for (final cmd in path.commands) {
      if (cmd.type == PathCommandType.moveTo && cmd.points.isNotEmpty) {
        // Process any collected line points first
        if (linePoints.isNotEmpty) {
          final simplifiedPoints = _douglasPeucker(linePoints, tolerance);
          _addSimplifiedPoints(simplified, simplifiedPoints);
          linePoints.clear();
        }
        linePoints.add(cmd.points[0]);
        lastPoint = cmd.points[0];
      } else if (cmd.type == PathCommandType.lineTo && cmd.points.isNotEmpty) {
        linePoints.add(cmd.points[0]);
        lastPoint = cmd.points[0];
      } else if (cmd.type == PathCommandType.cubicCurveTo &&
          cmd.points.length >= 3) {
        // Flatten cubic curve to line segments
        if (lastPoint != null) {
          final flattened = CurveUtils.flattenCubicBezier(
            lastPoint,
            cmd.points[0], // control point 1
            cmd.points[1], // control point 2
            cmd.points[2], // end point
            tolerance: tolerance,
          );
          // Add flattened points (skip first as it's the current point)
          for (int i = 1; i < flattened.length; i++) {
            linePoints.add(flattened[i]);
          }
          lastPoint = cmd.points[2];
        }
      } else {
        // Process any collected line points and then add this command
        if (linePoints.isNotEmpty) {
          final simplifiedPoints = _douglasPeucker(linePoints, tolerance);
          _addSimplifiedPoints(simplified, simplifiedPoints);
          linePoints.clear();
        }
        // Add the command as-is
        simplified.addCommand(cmd);
        if (cmd.points.isNotEmpty) {
          lastPoint = cmd.points.last;
        }
      }
    }

    // Process any remaining line points
    if (linePoints.isNotEmpty) {
      final simplifiedPoints = _douglasPeucker(linePoints, tolerance);
      _addSimplifiedPoints(simplified, simplifiedPoints);
    }

    return simplified;
  }

  /// Douglas-Peucker algorithm implementation
  static List<Point> _douglasPeucker(List<Point> points, double tolerance) {
    if (points.length <= 2) {
      return points;
    }

    // Find the point with the maximum distance from the line segment
    double maxDistance = 0;
    int maxIndex = 0;

    final first = points.first;
    final last = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final distance = _perpendicularDistance(points[i], first, last);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    // If max distance is greater than tolerance, recursively simplify
    if (maxDistance > tolerance) {
      // Recursive call
      final left = _douglasPeucker(points.sublist(0, maxIndex + 1), tolerance);
      final right = _douglasPeucker(points.sublist(maxIndex), tolerance);

      // Build the result list
      final result = <Point>[];
      result.addAll(left.sublist(0, left.length - 1));
      result.addAll(right);
      return result;
    } else {
      // All points between can be removed
      return [first, last];
    }
  }

  /// Calculate perpendicular distance from point to line segment
  static double _perpendicularDistance(
    Point point,
    Point lineStart,
    Point lineEnd,
  ) {
    // Delegate to GeometryUtils for consistent distance calculation
    return GeometryUtils.distanceToSegment(point, lineStart, lineEnd);
  }

  /// Add simplified points to the path
  static void _addSimplifiedPoints(Path path, List<Point> points) {
    if (points.isEmpty) return;

    bool needsMoveTo =
        path.commands.isEmpty ||
        path.commands.last.type == PathCommandType.close;

    for (int i = 0; i < points.length; i++) {
      if (i == 0 && needsMoveTo) {
        path.addCommand(PathCommand(PathCommandType.moveTo, [points[i]]));
      } else if (i > 0) {
        path.addCommand(PathCommand(PathCommandType.lineTo, [points[i]]));
      }
    }
  }

  /// Compute the union of two paths
  static Path union(Path path1, Path path2) {
    return _booleanOperation(path1, path2, _BooleanOp.union);
  }

  /// Compute the intersection of two paths
  static Path intersection(Path path1, Path path2) {
    return _booleanOperation(path1, path2, _BooleanOp.intersection);
  }

  /// Compute the difference of two paths (path1 - path2)
  static Path difference(Path path1, Path path2) {
    return _booleanOperation(path1, path2, _BooleanOp.difference);
  }

  /// Compute the exclusive OR (XOR) of two paths
  static Path xor(Path path1, Path path2) {
    return _booleanOperation(path1, path2, _BooleanOp.xor);
  }

  /// Main boolean operation implementation
  static Path _booleanOperation(Path path1, Path path2, _BooleanOp op) {
    // Tessellate paths to polygons
    final poly1 = _tessellatePathToPolygon(path1);
    final poly2 = _tessellatePathToPolygon(path2);

    if (poly1.isEmpty && poly2.isEmpty) return Path();
    if (poly1.isEmpty) {
      return (op == _BooleanOp.union || op == _BooleanOp.xor)
          ? path2.clone()
          : Path();
    }
    if (poly2.isEmpty) {
      return (op == _BooleanOp.union ||
              op == _BooleanOp.difference ||
              op == _BooleanOp.xor)
          ? path1.clone()
          : Path();
    }

    // Build edge lists
    final edges = <_Edge>[];

    // Add subject edges
    for (int i = 0; i < poly1.length; i++) {
      final next = (i + 1) % poly1.length;
      edges.add(_Edge(poly1[i], poly1[next], _EDGE_SUBJECT, true));
    }

    // Add clip edges
    for (int i = 0; i < poly2.length; i++) {
      final next = (i + 1) % poly2.length;
      edges.add(_Edge(poly2[i], poly2[next], _EDGE_CLIP, true));
    }

    // Find all intersections
    final intersections = _findIntersections(edges);

    // Build result path based on operation
    return _buildResultPath(edges, intersections, op);
  }

  /// Tessellate a path to a polygon (list of points)
  static List<Point> _tessellatePathToPolygon(Path path) {
    final points = <Point>[];
    Point? lastPoint;

    for (final cmd in path.commands) {
      if (cmd.type == PathCommandType.moveTo && cmd.points.isNotEmpty) {
        points.add(cmd.points[0]);
        lastPoint = cmd.points[0];
      } else if (cmd.type == PathCommandType.lineTo && cmd.points.isNotEmpty) {
        points.add(cmd.points[0]);
        lastPoint = cmd.points[0];
      } else if (cmd.type == PathCommandType.cubicCurveTo &&
          cmd.points.length >= 3) {
        // Tessellate cubic curve
        if (lastPoint != null) {
          final tessellated = _tessellateCubicBezier(
            lastPoint,
            cmd.points[0],
            cmd.points[1],
            cmd.points[2],
          );
          // Skip first point as it's already in the list
          for (int i = 1; i < tessellated.length; i++) {
            points.add(tessellated[i]);
          }
          lastPoint = cmd.points[2];
        }
      }
    }

    return points;
  }

  /// Tessellate a cubic Bezier curve
  static List<Point> _tessellateCubicBezier(
    Point p0,
    Point p1,
    Point p2,
    Point p3,
  ) {
    // Estimate number of segments needed
    final d1 = p0.distanceTo(p1) + p1.distanceTo(p2) + p2.distanceTo(p3);
    final d2 = p0.distanceTo(p3);

    if (d1 == 0) return [p0, p3];

    final segments = math.max(
      _NumericalConstants.minCurveSegments,
      math.min(
        _NumericalConstants.maxCurveSegments,
        (d1 / math.max(d2, 1.0) * 8).round(),
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
  static Map<_Edge, List<Point>> _findIntersections(List<_Edge> edges) {
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
  static Path _buildResultPath(
    List<_Edge> edges,
    Map<_Edge, List<Point>> intersections,
    _BooleanOp op,
  ) {
    // This is a simplified implementation
    // A full implementation would require a sweep line algorithm
    // For now, return a simple union approximation

    final builder = PathBuilder();
    final processedPoints = <Point>{};

    for (final edge in edges) {
      bool includeEdge = false;

      switch (op) {
        case _BooleanOp.union:
          includeEdge = true;
          break;
        case _BooleanOp.intersection:
          includeEdge = intersections.containsKey(edge);
          break;
        case _BooleanOp.difference:
          includeEdge =
              edge.type == _EDGE_SUBJECT && !intersections.containsKey(edge);
          break;
        case _BooleanOp.xor:
          includeEdge = !intersections.containsKey(edge);
          break;
      }

      if (includeEdge) {
        if (!processedPoints.contains(edge.start)) {
          if (processedPoints.isEmpty) {
            builder.moveTo(edge.start.x, edge.start.y);
          } else {
            builder.lineTo(edge.start.x, edge.start.y);
          }
          processedPoints.add(edge.start);
        }
        if (!processedPoints.contains(edge.end)) {
          builder.lineTo(edge.end.x, edge.end.y);
          processedPoints.add(edge.end);
        }
      }
    }

    if (processedPoints.isNotEmpty) {
      builder.close();
    }

    return builder.build();
  }
}

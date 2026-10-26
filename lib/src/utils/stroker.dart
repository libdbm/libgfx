import 'dart:math';

import '../graphics_state.dart';
import '../paths/path.dart';
import '../point.dart';
import 'curve_utils.dart';
import 'math_utils.dart';

/// Helper class to store join calculation data
class _Join {
  final Point incoming;
  final Point outgoing;
  final Point normalIn;
  final Point normalOut;
  final double turn;
  final bool isLeftTurn;

  _Join(
    this.incoming,
    this.outgoing,
    this.normalIn,
    this.normalOut,
    this.turn,
    this.isLeftTurn,
  );
}

/// Helper class to store miter calculation data
class _Miter {
  final double length;
  final bool exceeds;

  _Miter(this.length, this.exceeds);
}

/// Enhanced stroker with better numerical stability and professional-grade features
class Stroker {
  // Constants for numerical stability
  static const double smallAngle = pi / 16; // ~11.25 degrees
  static const double minMiterLimit = 1.0;
  static const double maxMiterLimit = 50.0;

  Path stroke(final Path path, GraphicsState state) {
    final builder = PathBuilder();
    final flattened = _flatten(path);

    for (final points in flattened) {
      if (points.length < 2) continue;
      _subpath(builder, points, state);
    }
    return builder.build();
  }

  void _subpath(PathBuilder builder, List<Point> points, GraphicsState state) {
    if (points.length < 2) return;

    final closed = _closed(points);
    final halfWidth = state.strokeWidth / 2.0;

    if (halfWidth <= MathUtils.geometricEpsilon) {
      // Degenerate case: very thin stroke, just draw the path itself
      builder.moveTo(points.first.x, points.first.y);
      for (int i = 1; i < points.length; i++) {
        builder.lineTo(points[i].x, points[i].y);
      }
      return;
    }

    final left = <Point>[];
    final right = <Point>[];

    // Process each vertex with improved join handling
    for (int i = 0; i < points.length; i++) {
      final previous = _previous(points, i, closed);
      final current = points[i];
      final next = _next(points, i, closed);

      _join(state, current, previous, next, halfWidth, left, right);
    }

    if (right.isEmpty || left.isEmpty) return;

    // Build the stroke outline
    _outline(builder, right, left, points, state, halfWidth, closed);
  }

  Point? _previous(List<Point> points, int index, final bool closed) {
    if (index > 0) return points[index - 1];
    if (closed && points.length > 2) {
      return points[points.length - 2]; // Skip duplicate last point
    }
    return null;
  }

  Point? _next(List<Point> points, int index, final bool closed) {
    if (index < points.length - 1) return points[index + 1];
    if (closed && points.length > 2) {
      return points[1]; // Skip duplicate first point
    }
    return null;
  }

  bool _closed(List<Point> points) {
    if (points.length < 3) return false;
    return (points.first - points.last).length2 <
        MathUtils.geometricEpsilon * MathUtils.geometricEpsilon;
  }

  void _join(
    GraphicsState state,
    Point p,
    final Point? previous,
    final Point? next,
    double halfWidth,
    List<Point> left,
    List<Point> right,
  ) {
    if (_endpoint(p, previous, next, halfWidth, left, right)) {
      return;
    }

    final join = _analyze(p, previous!, next!);
    if (join == null) return; // Skip degenerate cases

    if (_straight(join, p, halfWidth, left, right)) {
      return;
    }

    _apply(state, p, join, halfWidth, left, right);
  }

  bool _endpoint(
    Point p,
    final Point? previous,
    final Point? next,
    double halfWidth,
    List<Point> left,
    List<Point> right,
  ) {
    if (previous == null || next == null) {
      final direction = (next ?? p) - (previous ?? p);
      if (direction.length2 <
          MathUtils.geometricEpsilon * MathUtils.geometricEpsilon) {
        return true; // Skip degenerate point
      }

      final normal = _normal(direction).normalized() * halfWidth;
      right.add(p + normal);
      left.add(p - normal);
      return true;
    }
    return false;
  }

  _Join? _analyze(Point p, final Point previous, final Point next) {
    final incoming = (p - previous).normalized();
    final outgoing = (next - p).normalized();

    // Check for degenerate cases
    if (incoming.length2 <
            MathUtils.geometricEpsilon * MathUtils.geometricEpsilon ||
        outgoing.length2 <
            MathUtils.geometricEpsilon * MathUtils.geometricEpsilon) {
      return null; // Skip degenerate segments
    }

    final normalIn = _normal(incoming);
    final normalOut = _normal(outgoing);

    // Calculate turn direction and angle
    final cross = incoming.cross(outgoing);
    final dot = incoming.dot(outgoing);
    final turn = atan2(cross.abs(), dot);
    final isLeftTurn = cross > 0;

    return _Join(incoming, outgoing, normalIn, normalOut, turn, isLeftTurn);
  }

  bool _straight(
    final _Join join,
    Point p,
    double halfWidth,
    List<Point> left,
    List<Point> right,
  ) {
    if (join.turn < smallAngle) {
      right.add(p + join.normalIn * halfWidth);
      left.add(p - join.normalIn * halfWidth);
      return true;
    }
    return false;
  }

  void _apply(
    GraphicsState state,
    Point p,
    final _Join join,
    double halfWidth,
    List<Point> left,
    List<Point> right,
  ) {
    final miter = _extent(join, halfWidth, state.miterLimit);

    switch (state.lineJoin) {
      case LineJoin.miter:
        if (miter.exceeds) {
          _bevel(
            p,
            join.normalIn,
            join.normalOut,
            halfWidth,
            left,
            right,
            join.isLeftTurn,
          );
        } else {
          _miter(
            p,
            join.incoming,
            join.outgoing,
            join.normalIn,
            join.normalOut,
            halfWidth,
            left,
            right,
            join.isLeftTurn,
          );
        }
        break;

      case LineJoin.round:
        _round(
          p,
          join.incoming,
          join.outgoing,
          join.normalIn,
          join.normalOut,
          halfWidth,
          left,
          right,
          join.isLeftTurn,
          join.turn,
        );
        break;

      case LineJoin.bevel:
        _bevel(
          p,
          join.normalIn,
          join.normalOut,
          halfWidth,
          left,
          right,
          join.isLeftTurn,
        );
        break;
    }
  }

  _Miter _extent(final _Join join, double halfWidth, final double limit) {
    final theta = join.turn / 2;
    final length = halfWidth / sin(theta);
    final clamped = _clamp(limit);
    final exceeds = length > clamped * halfWidth;

    return _Miter(length, exceeds);
  }

  void _miter(
    Point p,
    final Point incoming,
    final Point outgoing,
    final Point normalIn,
    final Point normalOut,
    double halfWidth,
    List<Point> left,
    List<Point> right,
    bool isLeftTurn,
  ) {
    // Calculate miter vector using angle bisector
    final bisector = (incoming + outgoing).normalized();
    final normal = _normal(bisector);

    // Calculate miter length more robustly
    final denominator = normal.dot(normalOut);

    if (denominator.abs() < MathUtils.geometricEpsilon) {
      // Fallback to bevel for degenerate cases
      _bevel(p, normalIn, normalOut, halfWidth, left, right, isLeftTurn);
      return;
    }

    final length = halfWidth / denominator.abs();
    final tip = normal * (isLeftTurn ? -length : length);

    if (isLeftTurn) {
      left.add(p + tip);
      right.add(p + normalIn * halfWidth);
      right.add(p + normalOut * halfWidth);
    } else {
      right.add(p + tip);
      left.add(p - normalIn * halfWidth);
      left.add(p - normalOut * halfWidth);
    }
  }

  void _bevel(
    Point p,
    final Point normalIn,
    final Point normalOut,
    double halfWidth,
    List<Point> left,
    List<Point> right,
    bool isLeftTurn,
  ) {
    if (isLeftTurn) {
      // On the left side, add two points for the bevel
      left.add(p - normalIn * halfWidth);
      left.add(p - normalOut * halfWidth);
      // On the right side, the join point
      right.add(p + normalIn * halfWidth);
      right.add(p + normalOut * halfWidth);
    } else {
      // On the right side, add two points for the bevel
      right.add(p + normalIn * halfWidth);
      right.add(p + normalOut * halfWidth);
      // On the left side, the join point
      left.add(p - normalIn * halfWidth);
      left.add(p - normalOut * halfWidth);
    }
  }

  void _round(
    Point p,
    final Point incoming,
    final Point outgoing,
    final Point normalIn,
    final Point normalOut,
    double halfWidth,
    List<Point> left,
    List<Point> right,
    bool isLeftTurn,
    final double turn,
  ) {
    // Calculate number of arc segments based on angle
    final steps = max(2, (turn * halfWidth / 2).ceil());

    final startAngle = atan2(normalIn.y, normalIn.x);
    final endAngle = atan2(normalOut.y, normalOut.x);

    // Calculate angle difference based on turn direction
    var sweep = endAngle - startAngle;
    if (isLeftTurn) {
      // For left turn, we want a positive angle
      if (sweep < 0) sweep += 2 * pi;
    } else {
      // For right turn, we want a negative angle
      if (sweep > 0) sweep -= 2 * pi;
    }

    if (isLeftTurn) {
      // Add arc points on the outer (left) side
      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final angle = startAngle + sweep * t;
        final offset = Point(cos(angle), sin(angle)) * halfWidth;
        left.add(p - offset); // Negative because left side
      }
      // Straight connection on the right
      right.add(p + normalIn * halfWidth);
      right.add(p + normalOut * halfWidth);
    } else {
      // Add arc points on the outer (right) side
      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final angle = startAngle + sweep * t;
        final offset = Point(cos(angle), sin(angle)) * halfWidth;
        right.add(p + offset);
      }
      // Straight connection on the left
      left.add(p - normalIn * halfWidth);
      left.add(p - normalOut * halfWidth);
    }
  }

  void _outline(
    PathBuilder builder,
    final List<Point> right,
    final List<Point> left,
    final List<Point> points,
    GraphicsState state,
    double halfWidth,
    final bool closed,
  ) {
    if (right.isEmpty) return;

    // For square caps, we need to modify the contours to include the cap extensions
    List<Point> rightEdge = List.from(right);
    List<Point> leftEdge = List.from(left);

    if (!closed && state.lineCap == LineCap.square && points.length >= 2) {
      // Calculate cap extensions
      final startDirection = (points.first - points[1]).normalized();
      final endDirection = (points.last - points[points.length - 2])
          .normalized();
      final extension = halfWidth;

      // Extend the contours for square caps
      // Start cap extension
      final startExtension = startDirection * extension;
      rightEdge.insert(0, right.first + startExtension);
      leftEdge.insert(0, left.first + startExtension);

      // End cap extension
      final endExtension = endDirection * extension;
      rightEdge.add(right.last + endExtension);
      leftEdge.add(left.last + endExtension);
    }

    // Build the path
    builder.moveTo(rightEdge.first.x, rightEdge.first.y);
    for (int i = 1; i < rightEdge.length; i++) {
      builder.lineTo(rightEdge[i].x, rightEdge[i].y);
    }

    // Add end cap for round caps only (square is handled by extended contours)
    if (!closed && state.lineCap == LineCap.round && points.length >= 2) {
      _cap(builder, state, points.last, points[points.length - 2], halfWidth);
    }

    // Add left contour in reverse
    for (int i = leftEdge.length - 1; i >= 0; i--) {
      builder.lineTo(leftEdge[i].x, leftEdge[i].y);
    }

    // Add start cap for round caps only (square is handled by extended contours)
    if (!closed && state.lineCap == LineCap.round && points.length >= 2) {
      _cap(builder, state, points.first, points[1], halfWidth);
    }

    builder.closePath();
  }

  void _cap(
    PathBuilder builder,
    GraphicsState state,
    final Point end,
    final Point other,
    // For start cap: next point; for end cap: previous point
    double halfWidth,
  ) {
    // Direction should point AWAY from the line for cap extension
    // For start cap: point backwards (away from next point)
    // For end cap: point forwards (away from previous point)
    final direction = (end - other).normalized();
    final normal = _normal(direction);

    switch (state.lineCap) {
      case LineCap.butt:
        // No additional geometry needed
        break;

      case LineCap.square:
        // Square caps are now handled by extending the contours
        break;

      case LineCap.round:
        // Add semicircular arc from the contour the outline has just
        // followed, through the tip, to the other contour. [direction]
        // points out of the line at either end, so the same angles give
        // both caps the winding of the body.
        final startAngle = atan2(normal.y, normal.x);
        final sweep = -pi;

        // Add arc points
        final steps = max(4, (halfWidth).ceil());
        for (int i = 0; i <= steps; i++) {
          final t = i / steps;
          final angle = startAngle + sweep * t;
          final offset = Point(cos(angle), sin(angle)) * halfWidth;
          final point = end + offset;
          builder.lineTo(point.x, point.y);
        }
        break;
    }
  }

  Point _normal(Point vector) {
    return Point(-vector.y, vector.x);
  }

  double _clamp(final double limit) {
    return limit.clamp(minMiterLimit, maxMiterLimit);
  }

  // Enhanced curve flattening with adaptive subdivision
  List<List<Point>> _flatten(Path path) {
    final subpaths = <List<Point>>[];
    if (path.commands.isEmpty) return subpaths;

    List<Point> points = [];
    Point? current;

    for (final command in path.commands) {
      if (command.type == PathCommandType.moveTo) {
        if (points.isNotEmpty) subpaths.add(points);
        current = command.points.first;
        points = [current];
      } else if (current != null) {
        if (command.type == PathCommandType.lineTo) {
          current = command.points.first;
          // Skip zero-length segments
          if ((current - points.last).length2 >
              MathUtils.geometricEpsilon * MathUtils.geometricEpsilon) {
            points.add(current);
          }
        } else if (command.type == PathCommandType.cubicCurveTo) {
          final p1 = command.points[0],
              p2 = command.points[1],
              p3 = command.points[2];
          final flattened = CurveUtils.flattenCubicBezier(
            current,
            p1,
            p2,
            p3,
            tolerance: MathUtils.curveTolerance,
            maxDepth: 16,
          );
          points.addAll(flattened.skip(1));
          current = p3;
        } else if (command.type == PathCommandType.arc &&
            command is ArcCommand) {
          final flattened = CurveUtils.flattenArc(current, command);
          points.addAll(flattened.skip(1));
          current = flattened.last;
        } else if (command.type == PathCommandType.ellipse &&
            command is EllipseCommand) {
          final flattened = CurveUtils.flattenEllipse(current, command);
          points.addAll(flattened.skip(1));
          current = flattened.last;
        } else if (command.type == PathCommandType.close) {
          if (points.length > 1) {
            points.add(points.first); // Ensure closed
          }
        }
      }
    }

    if (points.isNotEmpty) subpaths.add(points);
    return subpaths;
  }
}

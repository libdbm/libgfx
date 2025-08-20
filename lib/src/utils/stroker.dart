import 'dart:math';

import '../graphics_state.dart';
import '../paths/path.dart';
import '../point.dart';
import 'geometry_utils.dart';
import 'math_utils.dart';

/// Helper class to store join calculation data
class _JoinData {
  final Point vIn;
  final Point vOut;
  final Point nIn;
  final Point nOut;
  final double turnAngle;
  final bool isLeftTurn;

  _JoinData(
    this.vIn,
    this.vOut,
    this.nIn,
    this.nOut,
    this.turnAngle,
    this.isLeftTurn,
  );
}

/// Helper class to store miter calculation data
class _MiterData {
  final double length;
  final bool exceedsLimit;

  _MiterData(this.length, this.exceedsLimit);
}

/// Enhanced stroker with better numerical stability and professional-grade features
class Stroker {
  // Constants for numerical stability
  static const double smallAngle = pi / 16; // ~11.25 degrees
  static const double minMiterLimit = 1.0;
  static const double maxMiterLimit = 50.0;

  Path stroke(Path inputPath, GraphicsState state) {
    final builder = PathBuilder();
    final flattenedSubPaths = _flattenPath(inputPath);

    for (final points in flattenedSubPaths) {
      if (points.length < 2) continue;
      _strokeSubPath(builder, points, state);
    }
    return builder.build();
  }

  void _strokeSubPath(
    PathBuilder builder,
    List<Point> points,
    GraphicsState state,
  ) {
    if (points.length < 2) return;

    final isClosed = _isPathClosed(points);
    final halfWidth = state.strokeWidth / 2.0;

    if (halfWidth <= MathUtils.geometricEpsilon) {
      // Degenerate case: very thin stroke, just draw the path itself
      builder.moveTo(points.first.x, points.first.y);
      for (int i = 1; i < points.length; i++) {
        builder.lineTo(points[i].x, points[i].y);
      }
      return;
    }

    final leftContour = <Point>[];
    final rightContour = <Point>[];

    // Process each vertex with improved join handling
    for (int i = 0; i < points.length; i++) {
      final prev = _getPreviousPoint(points, i, isClosed);
      final current = points[i];
      final next = _getNextPoint(points, i, isClosed);

      _addEnhancedJoin(
        state,
        current,
        prev,
        next,
        halfWidth,
        leftContour,
        rightContour,
        isClosed,
      );
    }

    if (rightContour.isEmpty || leftContour.isEmpty) return;

    // Build the stroke outline
    _buildStrokeOutline(
      builder,
      rightContour,
      leftContour,
      points,
      state,
      halfWidth,
      isClosed,
    );
  }

  Point? _getPreviousPoint(List<Point> points, int index, bool isClosed) {
    if (index > 0) return points[index - 1];
    if (isClosed && points.length > 2)
      return points[points.length - 2]; // Skip duplicate last point
    return null;
  }

  Point? _getNextPoint(List<Point> points, int index, bool isClosed) {
    if (index < points.length - 1) return points[index + 1];
    if (isClosed && points.length > 2)
      return points[1]; // Skip duplicate first point
    return null;
  }

  bool _isPathClosed(List<Point> points) {
    if (points.length < 3) return false;
    return (points.first - points.last).length2 <
        MathUtils.geometricEpsilon * MathUtils.geometricEpsilon;
  }

  void _addEnhancedJoin(
    GraphicsState state,
    Point p,
    Point? pPrev,
    Point? pNext,
    double halfWidth,
    List<Point> left,
    List<Point> right,
    bool isClosed,
  ) {
    if (_handleEndpoints(p, pPrev, pNext, halfWidth, left, right)) {
      return;
    }

    final joinData = _calculateJoinData(p, pPrev!, pNext!);
    if (joinData == null) return; // Skip degenerate cases

    if (_handleStraightLine(joinData, p, halfWidth, left, right)) {
      return;
    }

    _applyJoinType(state, p, joinData, halfWidth, left, right);
  }

  bool _handleEndpoints(
    Point p,
    Point? pPrev,
    Point? pNext,
    double halfWidth,
    List<Point> left,
    List<Point> right,
  ) {
    if (pPrev == null || pNext == null) {
      final direction = (pNext ?? p) - (pPrev ?? p);
      if (direction.length2 <
          MathUtils.geometricEpsilon * MathUtils.geometricEpsilon) {
        return true; // Skip degenerate point
      }

      final normal = _getNormal(direction).normalized() * halfWidth;
      right.add(p + normal);
      left.add(p - normal);
      return true;
    }
    return false;
  }

  _JoinData? _calculateJoinData(Point p, Point pPrev, Point pNext) {
    final vIn = (p - pPrev).normalized();
    final vOut = (pNext - p).normalized();

    // Check for degenerate cases
    if (vIn.length2 < MathUtils.geometricEpsilon * MathUtils.geometricEpsilon ||
        vOut.length2 <
            MathUtils.geometricEpsilon * MathUtils.geometricEpsilon) {
      return null; // Skip degenerate segments
    }

    final nIn = _getNormal(vIn);
    final nOut = _getNormal(vOut);

    // Calculate turn direction and angle
    final cross = vIn.cross(vOut);
    final dot = vIn.dot(vOut);
    final turnAngle = atan2(cross.abs(), dot);
    final isLeftTurn = cross > 0;

    return _JoinData(vIn, vOut, nIn, nOut, turnAngle, isLeftTurn);
  }

  bool _handleStraightLine(
    _JoinData joinData,
    Point p,
    double halfWidth,
    List<Point> left,
    List<Point> right,
  ) {
    if (joinData.turnAngle < smallAngle) {
      right.add(p + joinData.nIn * halfWidth);
      left.add(p - joinData.nIn * halfWidth);
      return true;
    }
    return false;
  }

  void _applyJoinType(
    GraphicsState state,
    Point p,
    _JoinData joinData,
    double halfWidth,
    List<Point> left,
    List<Point> right,
  ) {
    final miterData = _calculateMiterData(
      joinData,
      halfWidth,
      state.miterLimit,
    );

    switch (state.lineJoin) {
      case LineJoin.miter:
        if (miterData.exceedsLimit) {
          _addBevelJoin(
            p,
            joinData.nIn,
            joinData.nOut,
            halfWidth,
            left,
            right,
            joinData.isLeftTurn,
          );
        } else {
          _addMiterJoin(
            p,
            joinData.vIn,
            joinData.vOut,
            joinData.nIn,
            joinData.nOut,
            halfWidth,
            left,
            right,
            joinData.isLeftTurn,
          );
        }
        break;

      case LineJoin.round:
        _addRoundJoin(
          p,
          joinData.vIn,
          joinData.vOut,
          joinData.nIn,
          joinData.nOut,
          halfWidth,
          left,
          right,
          joinData.isLeftTurn,
          joinData.turnAngle,
        );
        break;

      case LineJoin.bevel:
        _addBevelJoin(
          p,
          joinData.nIn,
          joinData.nOut,
          halfWidth,
          left,
          right,
          joinData.isLeftTurn,
        );
        break;
    }
  }

  _MiterData _calculateMiterData(
    _JoinData joinData,
    double halfWidth,
    double miterLimit,
  ) {
    final theta = joinData.turnAngle / 2;
    final miterLength = halfWidth / sin(theta);
    final clampedMiterLimit = _clampMiterLimit(miterLimit);
    final exceedsLimit = miterLength > clampedMiterLimit * halfWidth;

    return _MiterData(miterLength, exceedsLimit);
  }

  void _addMiterJoin(
    Point p,
    Point vIn,
    Point vOut,
    Point nIn,
    Point nOut,
    double halfWidth,
    List<Point> left,
    List<Point> right,
    bool isLeftTurn,
  ) {
    // Calculate miter vector using angle bisector
    final bisector = (vIn + vOut).normalized();
    final miterNormal = _getNormal(bisector);

    // Calculate miter length more robustly
    final denominator = miterNormal.dot(nOut);

    if (denominator.abs() < MathUtils.geometricEpsilon) {
      // Fallback to bevel for degenerate cases
      _addBevelJoin(p, nIn, nOut, halfWidth, left, right, isLeftTurn);
      return;
    }

    final miterLength = halfWidth / denominator.abs();
    final miterPoint = miterNormal * (isLeftTurn ? -miterLength : miterLength);

    if (isLeftTurn) {
      left.add(p + miterPoint);
      right.add(p + nIn * halfWidth);
      right.add(p + nOut * halfWidth);
    } else {
      right.add(p + miterPoint);
      left.add(p - nIn * halfWidth);
      left.add(p - nOut * halfWidth);
    }
  }

  void _addBevelJoin(
    Point p,
    Point nIn,
    Point nOut,
    double halfWidth,
    List<Point> left,
    List<Point> right,
    bool isLeftTurn,
  ) {
    if (isLeftTurn) {
      // On the left side, add two points for the bevel
      left.add(p - nIn * halfWidth);
      left.add(p - nOut * halfWidth);
      // On the right side, the join point
      right.add(p + nIn * halfWidth);
      right.add(p + nOut * halfWidth);
    } else {
      // On the right side, add two points for the bevel
      right.add(p + nIn * halfWidth);
      right.add(p + nOut * halfWidth);
      // On the left side, the join point
      left.add(p - nIn * halfWidth);
      left.add(p - nOut * halfWidth);
    }
  }

  void _addRoundJoin(
    Point p,
    Point vIn,
    Point vOut,
    Point nIn,
    Point nOut,
    double halfWidth,
    List<Point> left,
    List<Point> right,
    bool isLeftTurn,
    double turnAngle,
  ) {
    // Calculate number of arc segments based on angle
    final steps = max(2, (turnAngle * halfWidth / 2).ceil());

    final startAngle = atan2(nIn.y, nIn.x);
    final endAngle = atan2(nOut.y, nOut.x);

    // Calculate angle difference based on turn direction
    var angleDiff = endAngle - startAngle;
    if (isLeftTurn) {
      // For left turn, we want a positive angle
      if (angleDiff < 0) angleDiff += 2 * pi;
    } else {
      // For right turn, we want a negative angle
      if (angleDiff > 0) angleDiff -= 2 * pi;
    }

    if (isLeftTurn) {
      // Add arc points on the outer (left) side
      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final angle = startAngle + angleDiff * t;
        final offset = Point(cos(angle), sin(angle)) * halfWidth;
        left.add(p - offset); // Negative because left side
      }
      // Straight connection on the right
      right.add(p + nIn * halfWidth);
      right.add(p + nOut * halfWidth);
    } else {
      // Add arc points on the outer (right) side
      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final angle = startAngle + angleDiff * t;
        final offset = Point(cos(angle), sin(angle)) * halfWidth;
        right.add(p + offset);
      }
      // Straight connection on the left
      left.add(p - nIn * halfWidth);
      left.add(p - nOut * halfWidth);
    }
  }

  void _buildStrokeOutline(
    PathBuilder builder,
    List<Point> rightContour,
    List<Point> leftContour,
    List<Point> originalPoints,
    GraphicsState state,
    double halfWidth,
    bool isClosed,
  ) {
    if (rightContour.isEmpty) return;

    // For square caps, we need to modify the contours to include the cap extensions
    List<Point> modifiedRightContour = List.from(rightContour);
    List<Point> modifiedLeftContour = List.from(leftContour);

    if (!isClosed &&
        state.lineCap == LineCap.square &&
        originalPoints.length >= 2) {
      // Calculate cap extensions
      final startDir = (originalPoints.first - originalPoints[1]).normalized();
      final endDir =
          (originalPoints.last - originalPoints[originalPoints.length - 2])
              .normalized();
      final extension = halfWidth;

      // Extend the contours for square caps
      // Start cap extension
      final startExtension = startDir * extension;
      modifiedRightContour.insert(0, rightContour.first + startExtension);
      modifiedLeftContour.insert(0, leftContour.first + startExtension);

      // End cap extension
      final endExtension = endDir * extension;
      modifiedRightContour.add(rightContour.last + endExtension);
      modifiedLeftContour.add(leftContour.last + endExtension);
    }

    // Build the path
    builder.moveTo(modifiedRightContour.first.x, modifiedRightContour.first.y);
    for (int i = 1; i < modifiedRightContour.length; i++) {
      builder.lineTo(modifiedRightContour[i].x, modifiedRightContour[i].y);
    }

    // Add end cap for round caps only (square is handled by extended contours)
    if (!isClosed &&
        state.lineCap == LineCap.round &&
        originalPoints.length >= 2) {
      _addEnhancedCap(
        builder,
        state,
        originalPoints.last,
        originalPoints[originalPoints.length - 2],
        halfWidth,
        false,
      );
    }

    // Add left contour in reverse
    for (int i = modifiedLeftContour.length - 1; i >= 0; i--) {
      builder.lineTo(modifiedLeftContour[i].x, modifiedLeftContour[i].y);
    }

    // Add start cap for round caps only (square is handled by extended contours)
    if (!isClosed &&
        state.lineCap == LineCap.round &&
        originalPoints.length >= 2) {
      _addEnhancedCap(
        builder,
        state,
        originalPoints.first,
        originalPoints[1],
        halfWidth,
        true,
      );
    }

    builder.close();
  }

  void _addEnhancedCap(
    PathBuilder builder,
    GraphicsState state,
    Point endPoint,
    Point otherPoint,
    // For start cap: next point; for end cap: previous point
    double halfWidth,
    bool isStart,
  ) {
    // Direction should point AWAY from the line for cap extension
    // For start cap: point backwards (away from next point)
    // For end cap: point forwards (away from previous point)
    final direction = (endPoint - otherPoint).normalized();
    final normal = _getNormal(direction);

    switch (state.lineCap) {
      case LineCap.butt:
        // No additional geometry needed
        break;

      case LineCap.square:
        // Square caps are now handled by extending the contours
        break;

      case LineCap.round:
        // Add semicircular arc
        // For end cap: start from right edge, sweep to left edge
        // For start cap: start from left edge, sweep to right edge
        final startAngle = isStart
            ? atan2(-normal.y, -normal.x) // Start from left edge
            : atan2(normal.y, normal.x); // Start from right edge

        // Always sweep by pi radians (180 degrees)
        final sweepAngle = isStart ? pi : -pi;

        // Add arc points
        final steps = max(4, (halfWidth).ceil());
        for (int i = 0; i <= steps; i++) {
          final t = i / steps;
          final angle = startAngle + sweepAngle * t;
          final offset = Point(cos(angle), sin(angle)) * halfWidth;
          final point = endPoint + offset;
          builder.lineTo(point.x, point.y);
        }
        break;
    }
  }

  Point _getNormal(Point vector) {
    return GeometryUtils.getNormal(vector);
  }

  double _clampMiterLimit(double miterLimit) {
    return miterLimit.clamp(minMiterLimit, maxMiterLimit);
  }

  // Enhanced curve flattening with adaptive subdivision
  List<List<Point>> _flattenPath(Path path) {
    final subPaths = <List<Point>>[];
    if (path.commands.isEmpty) return subPaths;

    List<Point> currentPoints = [];
    Point? currentPos;

    for (final cmd in path.commands) {
      if (cmd.type == PathCommandType.moveTo) {
        if (currentPoints.isNotEmpty) subPaths.add(currentPoints);
        currentPos = cmd.points.first;
        currentPoints = [currentPos];
      } else if (currentPos != null) {
        if (cmd.type == PathCommandType.lineTo) {
          currentPos = cmd.points.first;
          // Skip zero-length segments
          if ((currentPos - currentPoints.last).length2 >
              MathUtils.geometricEpsilon * MathUtils.geometricEpsilon) {
            currentPoints.add(currentPos);
          }
        } else if (cmd.type == PathCommandType.cubicCurveTo) {
          final p1 = cmd.points[0], p2 = cmd.points[1], p3 = cmd.points[2];
          final curvePoints = GeometryUtils.flattenCubicBezier(
            currentPos,
            p1,
            p2,
            p3,
            tolerance: MathUtils.curveTolerance,
            maxDepth: 16,
          );
          currentPoints.addAll(curvePoints.skip(1));
          currentPos = p3;
        } else if (cmd.type == PathCommandType.arc && cmd is ArcCommand) {
          final arcPoints = GeometryUtils.flattenArc(currentPos, cmd);
          currentPoints.addAll(arcPoints.skip(1));
          currentPos = arcPoints.last;
        } else if (cmd.type == PathCommandType.ellipse &&
            cmd is EllipseCommand) {
          final ellipsePoints = GeometryUtils.flattenEllipse(currentPos, cmd);
          currentPoints.addAll(ellipsePoints.skip(1));
          currentPos = ellipsePoints.last;
        } else if (cmd.type == PathCommandType.close) {
          if (currentPoints.length > 1) {
            currentPoints.add(currentPoints.first); // Ensure closed
          }
        }
      }
    }

    if (currentPoints.isNotEmpty) subPaths.add(currentPoints);
    return subPaths;
  }
}

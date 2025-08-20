import 'dart:math';

import '../matrix.dart';
import '../utils/math_utils.dart';
import 'path_operations.dart';
import '../point.dart';
import '../rectangle.dart';

// Constants for bezier curve approximation of circular arcs
// KAPPA = (4/3) * tan(π/8) = 4*(sqrt(2)-1)/3 ≈ 0.5522847498
const double kappa = 0.5522847498307933984;

class PathCommand {
  final PathCommandType type;
  final List<Point> points;

  PathCommand(this.type, this.points);
}

class ArcCommand extends PathCommand {
  final double centerX;
  final double centerY;
  final double radius;
  final double startAngle;
  final double endAngle;
  final bool counterClockwise;

  ArcCommand(
    this.centerX,
    this.centerY,
    this.radius,
    this.startAngle,
    this.endAngle,
    this.counterClockwise,
  ) : super(PathCommandType.arc, [Point(centerX, centerY)]);
}

class EllipseCommand extends PathCommand {
  final double centerX;
  final double centerY;
  final double radiusX;
  final double radiusY;
  final double rotation;
  final double startAngle;
  final double endAngle;
  final bool counterClockwise;

  EllipseCommand(
    this.centerX,
    this.centerY,
    this.radiusX,
    this.radiusY,
    this.rotation,
    this.startAngle,
    this.endAngle,
    this.counterClockwise,
  ) : super(PathCommandType.ellipse, [Point(centerX, centerY)]);
}

enum PathCommandType { moveTo, lineTo, cubicCurveTo, arc, ellipse, close }

class Path {
  final List<PathCommand> _commands = [];

  List<PathCommand> get commands => _commands;
  Rectangle? _bounds;

  Rectangle get bounds {
    if (_bounds != null) return _bounds!;
    if (_commands.isEmpty) return _bounds = Rectangle.zero as Rectangle<num>;

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    for (final cmd in _commands) {
      for (final pt in cmd.points) {
        minX = min(minX, pt.x);
        minY = min(minY, pt.y);
        maxX = max(maxX, pt.x);
        maxY = max(maxY, pt.y);
      }
    }
    return _bounds = Rectangle.fromLTRB(minX, minY, maxX, maxY);
  }

  Path clone() {
    final newPath = Path();
    newPath._commands.addAll(_commands);
    return newPath;
  }

  /// Add a command to this path (for internal use by path operations)
  void addCommand(PathCommand command) {
    _commands.add(command);
    _bounds = null; // Invalidate cached bounds
  }

  /// Add all commands from another path to this path
  void addPath(Path other) {
    for (final command in other.commands) {
      _commands.add(command);
    }
    _bounds = null; // Invalidate cached bounds
  }

  /// Transform the path using the given matrix
  Path transform(Matrix2D matrix) {
    return PathOperations.transform(this, matrix);
  }

  // Advanced path operations

  /// Simplify the path using the Ramer-Douglas-Peucker algorithm
  /// Removes redundant points while preserving the overall shape
  Path simplify(double tolerance) {
    return PathOperations.simplify(this, tolerance: tolerance);
  }

  /// Union of this path with another path (this ∪ other)
  Path union(Path other) {
    return PathOperations.union(this, other);
  }

  /// Intersection of this path with another path (this ∩ other)
  Path intersection(Path other) {
    return PathOperations.intersection(this, other);
  }

  /// Difference of this path with another path (this - other)
  Path difference(Path other) {
    return PathOperations.difference(this, other);
  }

  /// Exclusive OR (XOR) of this path with another path (this ⊕ other)
  Path xor(Path other) {
    return PathOperations.xor(this, other);
  }

  /// Alias for xor() to maintain backwards compatibility
  @Deprecated('Use xor() instead')
  Path exclusiveOr(Path other) => xor(other);
}

class PathBuilder {
  final Path _path = Path();
  Point _currentPoint = Point.zero;
  bool _isPathStarted = false;

  PathBuilder moveTo(double x, double y) {
    _currentPoint = Point(x, y);
    _path._commands.add(PathCommand(PathCommandType.moveTo, [_currentPoint]));
    _isPathStarted = true;
    return this; // Return the instance for chaining
  }

  PathBuilder lineTo(double x, double y) {
    if (!_isPathStarted) {
      moveTo(x, y);
    } else {
      _currentPoint = Point(x, y);
      _path._commands.add(PathCommand(PathCommandType.lineTo, [_currentPoint]));
    }
    return this;
  }

  PathBuilder curveTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    if (!_isPathStarted) moveTo(0, 0);
    final p1 = Point(x1, y1);
    final p2 = Point(x2, y2);
    final p3 = Point(x3, y3);
    _path._commands.add(
      PathCommand(PathCommandType.cubicCurveTo, [p1, p2, p3]),
    );
    _currentPoint = p3;
    return this;
  }

  /// Alias for curveTo - adds a cubic Bézier curve to the path
  /// This is the standard naming used in most graphics APIs (Canvas, SVG, etc.)
  PathBuilder cubicCurveTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    return curveTo(x1, y1, x2, y2, x3, y3);
  }

  /// Adds a quadratic Bézier curve to the path
  /// Quadratic curves have a single control point
  /// We convert to cubic internally by using the formula:
  /// CP1 = Start + 2/3 * (Control - Start)
  /// CP2 = End + 2/3 * (Control - End)
  PathBuilder quadraticCurveTo(double x1, double y1, double x2, double y2) {
    if (!_isPathStarted) moveTo(0, 0);

    // Convert quadratic to cubic Bézier
    final startX = _currentPoint.x;
    final startY = _currentPoint.y;

    // Calculate cubic control points from quadratic
    final cp1x = startX + (2.0 / 3.0) * (x1 - startX);
    final cp1y = startY + (2.0 / 3.0) * (y1 - startY);
    final cp2x = x2 + (2.0 / 3.0) * (x1 - x2);
    final cp2y = y2 + (2.0 / 3.0) * (y1 - y2);

    return cubicCurveTo(cp1x, cp1y, cp2x, cp2y, x2, y2);
  }

  PathBuilder arc(
    double centerX,
    double centerY,
    double radius,
    double startAngle,
    double sweepAngle, [
    bool counterClockwise = false,
  ]) {
    if (sweepAngle.abs() < 0.001) return this;

    // Normalize angles
    double endAngle = startAngle + sweepAngle;

    // Move to start point of arc if path not started
    final startPoint = MathUtils.circlePoint(
      centerX,
      centerY,
      radius,
      startAngle,
    );
    final startX = startPoint.x;
    final startY = startPoint.y;
    if (!_isPathStarted) {
      moveTo(startX, startY);
    } else {
      lineTo(startX, startY);
    }

    // Add native arc command
    _path._commands.add(
      ArcCommand(
        centerX,
        centerY,
        radius,
        startAngle,
        endAngle,
        counterClockwise,
      ),
    );

    // Update current point to end of arc
    _currentPoint = MathUtils.circlePoint(centerX, centerY, radius, endAngle);

    return this;
  }

  PathBuilder circle(double centerX, double centerY, double radius) {
    return ellipse(centerX, centerY, radius, radius, 0, 0, 2 * pi, false);
  }

  PathBuilder ellipse(
    double centerX,
    double centerY,
    double radiusX,
    double radiusY,
    double rotation,
    double startAngle,
    double endAngle, [
    bool counterClockwise = false,
  ]) {
    if ((endAngle - startAngle).abs() < 0.001) return this;

    // Calculate start point considering rotation
    final startPoint = MathUtils.ellipsePoint(
      centerX,
      centerY,
      radiusX,
      radiusY,
      rotation,
      startAngle,
    );
    final startX = startPoint.x;
    final startY = startPoint.y;

    if (!_isPathStarted) {
      moveTo(startX, startY);
    } else {
      lineTo(startX, startY);
    }

    // Add native ellipse command
    _path._commands.add(
      EllipseCommand(
        centerX,
        centerY,
        radiusX,
        radiusY,
        rotation,
        startAngle,
        endAngle,
        counterClockwise,
      ),
    );

    // Update current point to end of ellipse
    _currentPoint = MathUtils.ellipsePoint(
      centerX,
      centerY,
      radiusX,
      radiusY,
      rotation,
      endAngle,
    );

    return this;
  }

  PathBuilder close() {
    _path._commands.add(PathCommand(PathCommandType.close, []));
    return this;
  }

  /// Add all commands from another path to this PathBuilder
  PathBuilder addPath(Path other) {
    _path.addPath(other);
    // Update current point if the other path has commands
    if (other.commands.isNotEmpty) {
      final lastCommand = other.commands.last;
      if (lastCommand.points.isNotEmpty) {
        _currentPoint = lastCommand.points.last;
        _isPathStarted = true;
      }
    }
    return this;
  }

  /// Adds an arc to the path from the current point to (x, y)
  /// The arc is tangent to the line from current point to (x1, y1) and from (x1, y1) to (x, y)
  /// This is similar to HTML Canvas arcTo() method
  PathBuilder arcTo(double x1, double y1, double x, double y, double radius) {
    if (!_isPathStarted) {
      moveTo(0, 0);
    }

    if (radius <= 0) {
      return lineTo(x, y);
    }

    final currentX = _currentPoint.x;
    final currentY = _currentPoint.y;

    // If current point equals x1,y1 or x1,y1 equals x,y then just draw line to x,y
    if ((currentX == x1 && currentY == y1) || (x1 == x && y1 == y)) {
      return lineTo(x, y);
    }

    // Calculate vectors from control point to start and end points
    final v1x = currentX - x1;
    final v1y = currentY - y1;
    final v2x = x - x1;
    final v2y = y - y1;

    // Calculate lengths of vectors
    final v1Length = sqrt(v1x * v1x + v1y * v1y);
    final v2Length = sqrt(v2x * v2x + v2y * v2y);

    if (v1Length == 0 || v2Length == 0) {
      return lineTo(x, y);
    }

    // Normalize vectors
    final u1x = v1x / v1Length;
    final u1y = v1y / v1Length;
    final u2x = v2x / v2Length;
    final u2y = v2y / v2Length;

    // Calculate angle between vectors
    final dot = u1x * u2x + u1y * u2y;
    final angle = acos(max(-1, min(1, dot)));

    // If angle is too small (lines are nearly parallel), just draw line
    if (angle < 0.001) {
      return lineTo(x, y);
    }

    // Calculate distance from control point to tangent points
    final distance = radius / tan(angle / 2);

    // Clamp distance to not exceed vector lengths
    final clampedDistance = min(distance, min(v1Length, v2Length));

    // Calculate tangent points
    final t1x = x1 + u1x * clampedDistance;
    final t1y = y1 + u1y * clampedDistance;
    final t2x = x1 + u2x * clampedDistance;
    final t2y = y1 + u2y * clampedDistance;

    // Calculate center of arc
    final perpX = -u1y; // Perpendicular to u1
    final perpY = u1x;
    final centerDistance = radius / sin(angle / 2);
    final centerX = (t1x + t2x) / 2 + perpX * centerDistance;
    final centerY = (t1y + t2y) / 2 + perpY * centerDistance;

    // Calculate start and end angles
    final startAngle = atan2(t1y - centerY, t1x - centerX);
    final endAngle = atan2(t2y - centerY, t2x - centerX);

    // Determine if we should go clockwise or counterclockwise
    // Cross product to determine direction
    final cross = u1x * u2y - u1y * u2x;
    final counterClockwise = cross > 0;

    // Draw line to start of arc if needed
    if (currentX != t1x || currentY != t1y) {
      lineTo(t1x, t1y);
    }

    // Add the arc
    double sweepAngle;
    if (counterClockwise) {
      sweepAngle = endAngle - startAngle;
      if (sweepAngle <= 0) sweepAngle += 2 * pi;
    } else {
      sweepAngle = startAngle - endAngle;
      if (sweepAngle <= 0) sweepAngle += 2 * pi;
      sweepAngle = -sweepAngle;
    }

    arc(centerX, centerY, radius, startAngle, sweepAngle, counterClockwise);

    return this;
  }

  /// The final call in the chain. This returns the completed Path object.
  Path build() {
    _isPathStarted = false;
    return _path;
  }
}

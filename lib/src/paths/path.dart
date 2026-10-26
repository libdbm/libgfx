import 'dart:collection';
import 'dart:math';

import 'package:meta/meta.dart';

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

  /// The command's points, copied on construction and unmodifiable.
  final List<Point> points;

  PathCommand(this.type, List<Point> points)
    : points = List.unmodifiable(points);
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

  /// The commands of this path, read-only. Add commands with [add]
  /// or [addPath], which keep [bounds] current.
  late final List<PathCommand> commands = UnmodifiableListView(_commands);
  Rectangle? _bounds;

  Rectangle get bounds {
    if (_bounds != null) return _bounds!;
    if (_commands.isEmpty) return _bounds = Rectangle.zero();

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    for (final command in _commands) {
      for (final point in command.points) {
        minX = min(minX, point.x);
        minY = min(minY, point.y);
        maxX = max(maxX, point.x);
        maxY = max(maxY, point.y);
      }
    }
    return _bounds = Rectangle.fromLTRB(minX, minY, maxX, maxY);
  }

  /// A copy of this path. Commands are immutable, so sharing them makes the
  /// copy independent: adding to either path leaves the other unchanged.
  Path clone() {
    final copy = Path();
    copy._commands.addAll(_commands);
    return copy;
  }

  /// Add a command to this path (for internal use by path operations)
  void add(PathCommand command) {
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

  /// Experimental: joins this outline and [other] into one ring; not an
  /// area union.
  ///
  /// See [PathOperations.union] for the actual behaviour.
  @experimental
  Path union(Path other) {
    return PathOperations.union(this, other);
  }

  /// Experimental: a ring through the edges where this outline and [other]
  /// cross; not the area intersection.
  ///
  /// See [PathOperations.intersection] for the actual behaviour.
  @experimental
  Path intersection(Path other) {
    return PathOperations.intersection(this, other);
  }

  /// Experimental: a ring through the edges of this path that do not cross
  /// [other]; [other]'s area is not subtracted.
  ///
  /// See [PathOperations.difference] for the actual behaviour.
  @experimental
  Path difference(Path other) {
    return PathOperations.difference(this, other);
  }

  /// Experimental: a ring through the edges of either path that do not
  /// cross the other.
  ///
  /// See [PathOperations.xor] for the actual behaviour.
  @experimental
  Path xor(Path other) {
    return PathOperations.xor(this, other);
  }
}

class PathBuilder {
  final Path _path = Path();
  Point _current = Point.zero;
  bool _started = false;

  PathBuilder moveTo(double x, double y) {
    _current = Point(x, y);
    _path._commands.add(PathCommand(PathCommandType.moveTo, [_current]));
    _started = true;
    return this; // Return the instance for chaining
  }

  PathBuilder lineTo(double x, double y) {
    if (!_started) {
      moveTo(x, y);
    } else {
      _current = Point(x, y);
      _path._commands.add(PathCommand(PathCommandType.lineTo, [_current]));
    }
    return this;
  }

  /// Adds a cubic Bézier curve with control points (cp1x, cp1y) and
  /// (cp2x, cp2y), ending at (x, y)
  PathBuilder bezierCurveTo(
    final double cp1x,
    final double cp1y,
    final double cp2x,
    final double cp2y,
    final double x,
    final double y,
  ) {
    if (!_started) moveTo(0, 0);
    final end = Point(x, y);
    _path._commands.add(
      PathCommand(PathCommandType.cubicCurveTo, [
        Point(cp1x, cp1y),
        Point(cp2x, cp2y),
        end,
      ]),
    );
    _current = end;
    return this;
  }

  /// Adds a quadratic Bézier curve to the path
  /// Quadratic curves have a single control point
  /// We convert to cubic internally by using the formula:
  /// CP1 = Start + 2/3 * (Control - Start)
  /// CP2 = End + 2/3 * (Control - End)
  PathBuilder quadraticCurveTo(
    final double cpx,
    final double cpy,
    final double x,
    final double y,
  ) {
    if (!_started) moveTo(0, 0);

    // Convert quadratic to cubic Bézier
    final startX = _current.x;
    final startY = _current.y;

    return bezierCurveTo(
      startX + (2.0 / 3.0) * (cpx - startX),
      startY + (2.0 / 3.0) * (cpy - startY),
      x + (2.0 / 3.0) * (cpx - x),
      y + (2.0 / 3.0) * (cpy - y),
      x,
      y,
    );
  }

  /// The signed sweep from [start] to [end] under the W3C canvas rules:
  /// positive (increasing angle) unless [counterclockwise], at most one full
  /// turn. Arc commands store `start + sweep` as their end angle, so every
  /// consumer can read the sweep as `end - start`.
  static double _sweep(
    final double start,
    final double end,
    final bool counterclockwise,
  ) {
    final turn = 2 * pi;
    final delta = end - start;
    if (counterclockwise) {
      return -delta >= turn ? -turn : -((-delta) % turn);
    }
    return delta >= turn ? turn : delta % turn;
  }

  /// Adds an arc of the circle at (x, y) from [startAngle] to [endAngle],
  /// in the direction of increasing angle unless [counterclockwise], as
  /// W3C canvas `arc` does. A sweep of a full turn or more draws the whole
  /// circle.
  PathBuilder arc(
    final double x,
    final double y,
    final double radius,
    final double startAngle,
    final double endAngle, [
    final bool counterclockwise = false,
  ]) {
    final end = startAngle + _sweep(startAngle, endAngle, counterclockwise);
    if ((end - startAngle).abs() < 0.001) return this;

    // Move to start point of arc if path not started
    final start = MathUtils.circlePoint(x, y, radius, startAngle);
    if (!_started) {
      moveTo(start.x, start.y);
    } else {
      lineTo(start.x, start.y);
    }

    _path._commands.add(
      ArcCommand(x, y, radius, startAngle, end, counterclockwise),
    );
    _current = MathUtils.circlePoint(x, y, radius, end);
    return this;
  }

  /// Adds a full circle at (x, y)
  PathBuilder circle(final double x, final double y, final double radius) {
    return ellipse(x, y, radius, radius, 0, 0, 2 * pi, false);
  }

  /// Adds an arc of the ellipse at (x, y), rotated by [rotation], from
  /// [startAngle] to [endAngle], as W3C canvas `ellipse` does
  PathBuilder ellipse(
    final double x,
    final double y,
    final double radiusX,
    final double radiusY,
    final double rotation,
    final double startAngle,
    final double endAngle, [
    final bool counterclockwise = false,
  ]) {
    final end = startAngle + _sweep(startAngle, endAngle, counterclockwise);
    if ((end - startAngle).abs() < 0.001) return this;

    final start = MathUtils.ellipsePoint(
      x,
      y,
      radiusX,
      radiusY,
      rotation,
      startAngle,
    );
    if (!_started) {
      moveTo(start.x, start.y);
    } else {
      lineTo(start.x, start.y);
    }

    _path._commands.add(
      EllipseCommand(
        x,
        y,
        radiusX,
        radiusY,
        rotation,
        startAngle,
        end,
        counterclockwise,
      ),
    );
    _current = MathUtils.ellipsePoint(x, y, radiusX, radiusY, rotation, end);
    return this;
  }

  /// Adds a closed rectangle with a corner at (x, y)
  PathBuilder rect(
    final double x,
    final double y,
    final double width,
    final double height,
  ) {
    return moveTo(x, y)
        .lineTo(x + width, y)
        .lineTo(x + width, y + height)
        .lineTo(x, y + height)
        .closePath();
  }

  /// Adds a closed rectangle whose corners are quarter circles of [radius],
  /// clamped to half the smaller side
  PathBuilder roundRect(
    final double x,
    final double y,
    final double width,
    final double height,
    final double radius,
  ) {
    final corner = radius.clamp(0.0, min(width, height) / 2);
    if (corner < 1e-9) return rect(x, y, width, height);

    final quarter = pi / 2;
    return moveTo(x + corner, y)
        .lineTo(x + width - corner, y)
        .arc(x + width - corner, y + corner, corner, -quarter, 0)
        .lineTo(x + width, y + height - corner)
        .arc(x + width - corner, y + height - corner, corner, 0, quarter)
        .lineTo(x + corner, y + height)
        .arc(x + corner, y + height - corner, corner, quarter, pi)
        .lineTo(x, y + corner)
        .arc(x + corner, y + corner, corner, pi, pi + quarter)
        .closePath();
  }

  /// Adds a regular polygon with [sides] corners on the circle at (x, y),
  /// the first one at angle -pi/2. Throws [ArgumentError] below 3 sides.
  PathBuilder polygon(
    final double x,
    final double y,
    final double radius,
    final int sides,
  ) {
    if (sides < 3) {
      throw ArgumentError('Polygon must have at least 3 sides');
    }
    final step = 2 * pi / sides;
    for (int i = 0; i <= sides; i++) {
      final angle = i * step - pi / 2;
      final px = x + radius * cos(angle);
      final py = y + radius * sin(angle);
      i == 0 ? moveTo(px, py) : lineTo(px, py);
    }
    return this;
  }

  /// Adds a star with [points] tips on the circle of [outer] radius and
  /// notches on the circle of [inner] radius, the first tip at angle -pi/2.
  /// Throws [ArgumentError] below 3 points.
  PathBuilder star(
    final double x,
    final double y,
    final double outer,
    final double inner,
    final int points,
  ) {
    if (points < 3) {
      throw ArgumentError('Star must have at least 3 points');
    }
    final step = pi / points;
    for (int i = 0; i <= points * 2; i++) {
      final angle = i * step - pi / 2;
      final radius = i.isEven ? outer : inner;
      final px = x + radius * cos(angle);
      final py = y + radius * sin(angle);
      i == 0 ? moveTo(px, py) : lineTo(px, py);
    }
    return this;
  }

  /// Closes the current subpath with a line back to its start
  PathBuilder closePath() {
    _path._commands.add(PathCommand(PathCommandType.close, []));
    return this;
  }

  /// Add all commands from another path to this PathBuilder
  PathBuilder addPath(Path other) {
    _path.addPath(other);
    // Update current point if the other path has commands
    if (other.commands.isNotEmpty) {
      final last = other.commands.last;
      if (last.points.isNotEmpty) {
        _current = last.points.last;
        _started = true;
      }
    }
    return this;
  }

  /// Adds an arc of [radius] tangent to the line from the current point to
  /// (x1, y1) and to the line from (x1, y1) to (x2, y2), joined to the
  /// current point by a line, as W3C canvas `arcTo` does. When the three
  /// points lie on one line, or [radius] is not positive, adds a line to
  /// (x1, y1) instead.
  PathBuilder arcTo(
    final double x1,
    final double y1,
    final double x2,
    final double y2,
    final double radius,
  ) {
    if (!_started) {
      moveTo(0, 0);
    }

    final x0 = _current.x;
    final y0 = _current.y;
    if (radius <= 0 || (x0 == x1 && y0 == y1) || (x1 == x2 && y1 == y2)) {
      return lineTo(x1, y1);
    }

    // Unit vectors from the corner towards each end
    final length1 = sqrt((x0 - x1) * (x0 - x1) + (y0 - y1) * (y0 - y1));
    final length2 = sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
    final u1x = (x0 - x1) / length1;
    final u1y = (y0 - y1) / length1;
    final u2x = (x2 - x1) / length2;
    final u2y = (y2 - y1) / length2;

    final cross = u1x * u2y - u1y * u2x;
    if (cross.abs() < 1e-12) {
      return lineTo(x1, y1);
    }

    // The circle touches each line at reach from the corner, and its centre
    // lies on the bisector of the corner's angle
    final angle = acos(max(-1, min(1, u1x * u2x + u1y * u2y)));
    final reach = radius / tan(angle / 2);
    final distance = radius / sin(angle / 2);
    final bisector = sqrt(
      (u1x + u2x) * (u1x + u2x) + (u1y + u2y) * (u1y + u2y),
    );
    final x = x1 + (u1x + u2x) / bisector * distance;
    final y = y1 + (u1y + u2y) / bisector * distance;

    final start = atan2(y1 + u1y * reach - y, x1 + u1x * reach - x);
    final end = atan2(y1 + u2y * reach - y, x1 + u2x * reach - x);

    // A left turn has a negative cross product and runs in increasing angle
    return arc(x, y, radius, start, end, cross > 0);
  }

  /// The final call in the chain. This returns the completed Path object.
  Path build() {
    _started = false;
    return _path;
  }
}

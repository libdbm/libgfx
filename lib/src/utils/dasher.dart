import 'dart:math';

import '../limits.dart';
import '../paths/path.dart';
import '../point.dart';
import 'curve_utils.dart';

/// A utility to convert a path into a dashed path by breaking it into segments.
/// Dashing a path into more than [Limits.dashes] dash and gap pieces throws
/// [ArgumentError].
class Dasher {
  Path dash(
    final Path path,
    List<double> pattern, {
    final Limits limits = const Limits(),
  }) {
    if (pattern.isEmpty || pattern.every((length) => length <= 0)) return path;

    final builder = PathBuilder();
    final subpaths = _split(path);

    var budget = limits.dashes;
    for (final commands in subpaths) {
      budget = _subpath(builder, commands, pattern, budget, limits);
    }

    return builder.build();
  }

  /// Dashes one subpath and returns how many of [budget] pieces remain.
  int _subpath(
    PathBuilder builder,
    List<PathCommand> commands,
    List<double> pattern,
    int budget,
    Limits limits,
  ) {
    final points = _flatten(commands);
    if (points.length < 2) return budget;

    var index = 0;
    var progress = 0.0;
    var down = true;

    // Tracks if we need to start a new line segment
    var fresh = true;

    for (int i = 0; i < points.length - 1; i++) {
      var p1 = points[i];
      final p2 = points[i + 1];

      var vector = p2 - p1;
      var length = vector.length;
      if (length < 1e-9) continue;

      final direction = vector * (1.0 / length);

      while (length > 0) {
        if (--budget < 0) {
          throw ArgumentError.value(
            pattern,
            'pattern',
            'Produces more than ${limits.dashes} dashes and gaps',
          );
        }
        final element = pattern[index % pattern.length];
        if (element <= 0) {
          // Skip zero-length pattern segments
          index++;
          continue;
        }

        final rest = element - progress;
        final step = min(length, rest);

        final next = p1 + direction * step;

        if (down) {
          if (fresh) {
            builder.moveTo(p1.x, p1.y);
            fresh = false;
          }
          builder.lineTo(next.x, next.y);
        }

        p1 = next;
        length -= step;
        progress += step;

        // Check if we've completed a pattern element (dash or gap)
        if (progress >= element) {
          progress = 0;
          index++;
          down = !down;
          // If the pen is coming up, the next dash will need a new moveTo
          if (!down) {
            fresh = true;
          }
        }
      }
    }
    return budget;
  }

  /// Flattens an entire subpath into a single list of connected points.
  List<Point> _flatten(List<PathCommand> commands) {
    final points = <Point>[];
    if (commands.isEmpty) return points;

    var current = commands.first.points.first;
    points.add(current);

    for (final command in commands) {
      if (command.type == PathCommandType.moveTo) continue;

      if (command.type == PathCommandType.lineTo) {
        current = command.points.first;
        points.add(current);
      } else if (command.type == PathCommandType.cubicCurveTo) {
        final p1 = command.points[0];
        final p2 = command.points[1];
        final p3 = command.points[2];
        points.addAll(
          CurveUtils.flattenCubicBezier(current, p1, p2, p3, steps: 30).skip(1),
        );
        current = p3;
      } else if (command.type == PathCommandType.arc && command is ArcCommand) {
        final flattened = CurveUtils.flattenArc(
          current,
          command,
          tolerance: 0.2,
        );
        points.addAll(flattened.skip(1));
        current = flattened.last;
      } else if (command.type == PathCommandType.ellipse &&
          command is EllipseCommand) {
        final flattened = CurveUtils.flattenEllipse(
          current,
          command,
          tolerance: 0.2,
        );
        points.addAll(flattened.skip(1));
        current = flattened.last;
      } else if (command.type == PathCommandType.close) {
        points.add(commands.first.points.first);
      }
    }
    return points;
  }

  List<List<PathCommand>> _split(Path path) {
    if (path.commands.isEmpty) return [];
    final subpaths = <List<PathCommand>>[];
    var current = <PathCommand>[];
    for (final command in path.commands) {
      if (command.type == PathCommandType.moveTo) {
        if (current.isNotEmpty) subpaths.add(current);
        current = [command];
      } else {
        current.add(command);
      }
    }
    if (current.isNotEmpty) {
      subpaths.add(current);
    }
    return subpaths.where((subpath) => subpath.isNotEmpty).toList();
  }
}

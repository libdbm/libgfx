import 'dart:math';

import '../paths/path.dart';
import '../point.dart';
import 'geometry_utils.dart';

/// A utility to convert a path into a dashed path by breaking it into segments.
class Dasher {
  Path dash(Path inputPath, List<double> pattern) {
    if (pattern.isEmpty || pattern.every((d) => d <= 0)) return inputPath;

    final builder = PathBuilder();
    final subPaths = _splitPath(inputPath);

    for (final commands in subPaths) {
      _dashSubPath(builder, commands, pattern);
    }

    return builder.build();
  }

  void _dashSubPath(
    PathBuilder builder,
    List<PathCommand> commands,
    List<double> pattern,
  ) {
    final flattenedPoints = _flattenSubPath(commands);
    if (flattenedPoints.length < 2) return;

    var patternIndex = 0;
    var distanceIntoPattern = 0.0;
    var isPenDown = true;

    // NEW STATE: Tracks if we need to start a new line segment
    var needsMoveTo = true;

    for (int i = 0; i < flattenedPoints.length - 1; i++) {
      var p1 = flattenedPoints[i];
      final p2 = flattenedPoints[i + 1];

      var segmentVector = p2 - p1;
      var segmentLength = segmentVector.length;
      if (segmentLength < 1e-9) continue;

      final direction = segmentVector * (1.0 / segmentLength);

      while (segmentLength > 0) {
        final patternLength = pattern[patternIndex % pattern.length];
        if (patternLength <= 0) {
          // Skip zero-length pattern segments
          patternIndex++;
          continue;
        }

        final remainingInPattern = patternLength - distanceIntoPattern;
        final step = min(segmentLength, remainingInPattern);

        final nextPoint = p1 + direction * step;

        if (isPenDown) {
          if (needsMoveTo) {
            builder.moveTo(p1.x, p1.y);
            needsMoveTo = false;
          }
          builder.lineTo(nextPoint.x, nextPoint.y);
        }

        p1 = nextPoint;
        segmentLength -= step;
        distanceIntoPattern += step;

        // Check if we've completed a pattern element (dash or gap)
        if (distanceIntoPattern >= patternLength) {
          distanceIntoPattern = 0;
          patternIndex++;
          isPenDown = !isPenDown;
          // If the pen is coming up, the next dash will need a new moveTo
          if (!isPenDown) {
            needsMoveTo = true;
          }
        }
      }
    }
  }

  /// Flattens an entire subpath into a single list of connected points.
  List<Point> _flattenSubPath(List<PathCommand> commands) {
    final points = <Point>[];
    if (commands.isEmpty) return points;

    var currentPoint = commands.first.points.first;
    points.add(currentPoint);

    for (final cmd in commands) {
      if (cmd.type == PathCommandType.moveTo) continue;

      if (cmd.type == PathCommandType.lineTo) {
        currentPoint = cmd.points.first;
        points.add(currentPoint);
      } else if (cmd.type == PathCommandType.cubicCurveTo) {
        final p1 = cmd.points[0];
        final p2 = cmd.points[1];
        final p3 = cmd.points[2];
        points.addAll(
          GeometryUtils.flattenCubicBezier(
            currentPoint,
            p1,
            p2,
            p3,
            steps: 30,
          ).skip(1),
        );
        currentPoint = p3;
      } else if (cmd.type == PathCommandType.arc && cmd is ArcCommand) {
        final arcPoints = GeometryUtils.flattenArc(
          currentPoint,
          cmd,
          tolerance: 0.2,
        );
        points.addAll(arcPoints.skip(1));
        currentPoint = arcPoints.last;
      } else if (cmd.type == PathCommandType.ellipse && cmd is EllipseCommand) {
        final ellipsePoints = GeometryUtils.flattenEllipse(
          currentPoint,
          cmd,
          tolerance: 0.2,
        );
        points.addAll(ellipsePoints.skip(1));
        currentPoint = ellipsePoints.last;
      } else if (cmd.type == PathCommandType.close) {
        points.add(commands.first.points.first);
      }
    }
    return points;
  }

  List<List<PathCommand>> _splitPath(Path path) {
    if (path.commands.isEmpty) return [];
    final subPaths = <List<PathCommand>>[];
    var currentSubPath = <PathCommand>[];
    for (final cmd in path.commands) {
      if (cmd.type == PathCommandType.moveTo) {
        if (currentSubPath.isNotEmpty) subPaths.add(currentSubPath);
        currentSubPath = [cmd];
      } else {
        currentSubPath.add(cmd);
      }
    }
    if (currentSubPath.isNotEmpty) {
      subPaths.add(currentSubPath);
    }
    return subPaths.where((p) => p.isNotEmpty).toList();
  }
}

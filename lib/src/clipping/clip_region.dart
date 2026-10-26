import 'dart:math' as math;

import '../rasterize/implementations/basic_rasterizer.dart';
import '../rasterize/rasterizer.dart';
import 'bounds_calculator.dart';
import 'winding_calculator.dart';
import '../matrix.dart';
import '../paths/path.dart';
import '../point.dart';
import '../rectangle.dart';
import '../result.dart';
import '../spans/span.dart';
import '../utils/math_utils.dart';

/// Represents a clipping region with support for fill rules and hit testing
class ClipRegion {
  /// Pre-rasterized spans organized by scanline for fast lookup
  final Map<int, List<Span>> rows;

  /// Bounding rectangle of the clip region
  final Rectangle<int> bounds;

  /// Optional path for advanced operations
  final Path? path;

  /// Fill rule for path-based clipping
  final FillRule rule;

  /// Transform applied to the path
  final Matrix2D transform;

  ClipRegion({
    required this.rows,
    required this.bounds,
    this.path,
    this.rule = FillRule.evenOdd,
    Matrix2D? transform,
  }) : transform = transform ?? Matrix2D.identity();

  /// Create a deep copy of this clip region.
  ClipRegion clone() {
    final copy = <int, List<Span>>{};
    for (final entry in rows.entries) {
      copy[entry.key] = entry.value
          .map((span) => Span(span.y, span.x, span.length, span.coverage))
          .toList(growable: false);
    }

    return ClipRegion(
      rows: copy,
      bounds: Rectangle(bounds.left, bounds.top, bounds.width, bounds.height),
      path: path?.clone(),
      rule: rule,
      transform: Matrix2D.copy(transform),
    );
  }

  /// Creates a clip region from a path, rasterized with [rasterizer]
  /// (a [BasicRasterizer] when omitted).
  factory ClipRegion.fromPath(
    Path path,
    Matrix2D transform,
    int width,
    int height, {
    FillRule rule = FillRule.evenOdd,
    Rasterizer? rasterizer,
  }) {
    rasterizer ??= BasicRasterizer();
    final transformed = path.transform(transform);
    final spans = rasterizer.rasterize(
      transformed,
      rule: rule,
      viewport: Rectangle(0, 0, width, height),
    );

    if (spans.isEmpty) {
      return ClipRegion.empty();
    }

    // Organize spans by scanline
    final rows = <int, List<Span>>{};
    int minX = width, maxX = 0;
    int minY = height, maxY = 0;

    for (final span in spans) {
      if (span.y >= 0 && span.y < height) {
        final clipped = _crop(span, width);
        if (clipped != null && clipped.length > 0) {
          (rows[span.y] ??= []).add(clipped);
          minX = math.min(minX, clipped.x1);
          maxX = math.max(maxX, clipped.x1 + clipped.length);
          minY = math.min(minY, clipped.y);
          maxY = math.max(maxY, clipped.y);
        }
      }
    }

    if (rows.isEmpty) {
      return ClipRegion.empty();
    }

    final bounds = Rectangle(minX, minY, maxX - minX, maxY - minY + 1);
    return ClipRegion(
      rows: rows,
      bounds: bounds,
      path: path,
      rule: rule,
      transform: transform,
    );
  }

  /// Creates a rectangular clip region
  factory ClipRegion.fromRect(int x, int y, int width, int height) {
    final rows = <int, List<Span>>{};

    for (int row = y; row < y + height; row++) {
      rows[row] = [Span.from(row, x, x + width)];
    }

    return ClipRegion(rows: rows, bounds: Rectangle(x, y, width, height));
  }

  /// Creates an empty clip region
  factory ClipRegion.empty() {
    return ClipRegion(rows: {}, bounds: Rectangle(0, 0, 0, 0));
  }

  /// Intersects this clip region with another
  ClipRegion intersect(ClipRegion other) {
    if (bounds.intersection(other.bounds) == null) {
      return ClipRegion.empty();
    }

    final result = <int, List<Span>>{};
    int minX = bounds.width, maxX = 0;
    int minY = bounds.height, maxY = 0;

    // Only process scanlines that exist in both regions
    for (final y in rows.keys) {
      if (!other.rows.containsKey(y)) continue;

      final spans1 = rows[y]!;
      final spans2 = other.rows[y]!;
      final intersected = _overlap(spans1, spans2);

      if (intersected.isNotEmpty) {
        result[y] = intersected;
        for (final span in intersected) {
          minX = math.min(minX, span.x1);
          maxX = math.max(maxX, span.x2);
          minY = math.min(minY, span.y);
          maxY = math.max(maxY, span.y);
        }
      }
    }

    if (result.isEmpty) {
      return ClipRegion.empty();
    }

    return ClipRegion(
      rows: result,
      bounds: Rectangle(minX, minY, maxX - minX, maxY - minY + 1),
    );
  }

  /// Intersects spans with this clip region
  List<Span> clip(List<Span> spans) {
    final result = <Span>[];

    for (final span in spans) {
      if (!rows.containsKey(span.y)) continue;

      final clip = rows[span.y]!;
      for (final mask in clip) {
        final x1 = math.max(span.x1, mask.x1);
        final x2 = math.min(span.x2, mask.x2);
        final coverage = MathUtils.mul255(span.coverage, mask.coverage);
        if (x1 < x2 && coverage > 0) {
          result.add(Span(span.y, x1, x2 - x1, coverage));
        }
      }
    }

    return result;
  }

  /// Tests if a point is inside the clip region using pre-rasterized spans
  bool contains(int x, int y) => coverage(x, y) > 0;

  /// Clip coverage (0-255) of the pixel at [x], [y]; 0 outside the region.
  int coverage(int x, int y) {
    if (x < bounds.left ||
        x >= bounds.left + bounds.width ||
        y < bounds.top ||
        y >= bounds.top + bounds.height) {
      return 0;
    }

    final spans = rows[y];
    if (spans == null) {
      return 0;
    }

    for (final span in spans) {
      if (x >= span.x1 && x < span.x2) return span.coverage;
    }

    return 0;
  }

  /// Tests if a point is inside the clip region using the path and fill rule
  bool includes(Point point) {
    // If we have a path, use it for accurate hit testing
    if (path != null) {
      // Quick bounds check
      final box = Rectangle<double>(
        bounds.left.toDouble(),
        bounds.top.toDouble(),
        bounds.width.toDouble(),
        bounds.height.toDouble(),
      );
      if (!_within(point, box)) {
        return false;
      }

      // Transform point to path space; a singular transform has no interior
      final Point local;
      switch (transform.inverse()) {
        case Ok(:final value):
          local = value.transform(point);
        case Err():
          return false;
      }

      // Apply fill rule
      if (rule == FillRule.evenOdd) {
        return _evenOdd(local, path!);
      } else {
        return _nonZero(local, path!);
      }
    }

    // Fall back to span-based testing
    return contains(point.x.round(), point.y.round());
  }

  bool get isEmpty => rows.isEmpty;

  /// Calculate bounds for a path
  Rectangle<double> extent() {
    if (path == null) {
      return Rectangle<double>(
        bounds.left.toDouble(),
        bounds.top.toDouble(),
        bounds.width.toDouble(),
        bounds.height.toDouble(),
      );
    }
    return BoundsCalculator.boundsOf(path!, transform);
  }

  /// Convert to rasterized spans for clipping
  Map<int, List<Span>> rasterize(int width, int height) {
    // If we already have rasterized spans, return them
    if (rows.isNotEmpty) {
      return rows;
    }

    // If we have a path, rasterize it
    if (path != null) {
      final transformed = path!.transform(transform);
      final rasterizer = BasicRasterizer();
      final spans = rasterizer.rasterize(
        transformed,
        rule: rule,
        viewport: Rectangle(0, 0, width, height),
      );

      // Organize spans by scanline and clip to bounds
      final result = <int, List<Span>>{};

      for (final span in spans) {
        if (span.y >= 0 && span.y < height) {
          final clipped = _crop(span, width);
          if (clipped != null && clipped.length > 0) {
            (result[span.y] ??= []).add(clipped);
          }
        }
      }

      return result;
    }

    return {};
  }

  /// Helper method to check if a point is in bounds
  bool _within(Point p, Rectangle<double> bounds) {
    return p.x >= bounds.left &&
        p.x <= bounds.left + bounds.width &&
        p.y >= bounds.top &&
        p.y <= bounds.top + bounds.height;
  }

  /// Test if a point is inside using even-odd rule
  bool _evenOdd(final Point point, Path path) {
    int crossings = 0;
    Point? last;
    Point? start;

    for (final command in path.commands) {
      switch (command.type) {
        case PathCommandType.moveTo:
          last = command.points.first;
          start = last;
          break;

        case PathCommandType.lineTo:
          if (last != null) {
            if (_crosses(last, command.points.first, point)) {
              crossings++;
            }
            last = command.points.first;
          }
          break;

        case PathCommandType.cubicCurveTo:
          if (last != null) {
            // Approximate cubic with lines
            crossings += _cubic(
              last,
              command.points[0],
              command.points[1],
              command.points[2],
              point,
            );
            last = command.points[2];
          }
          break;

        case PathCommandType.arc:
          if (last != null) {
            final arc = command as ArcCommand;
            crossings += _arc(arc, last, point);
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
            crossings += _ellipse(ellipse, last, point);
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
          if (last != null && start != null) {
            if (_crosses(last, start, point)) {
              crossings++;
            }
            last = start;
          }
          break;
      }
    }

    return (crossings % 2) == 1;
  }

  /// Test if a point is inside using non-zero winding rule
  bool _nonZero(final Point point, Path path) {
    final winding = WindingCalculator.calculateWindingNumber(point, path);
    return winding != 0;
  }

  /// Check if a line segment crosses a ray from point going right
  bool _crosses(Point p1, Point p2, final Point point) {
    // Check if line segment is entirely above or below the ray
    if ((p1.y > point.y && p2.y > point.y) ||
        (p1.y <= point.y && p2.y <= point.y)) {
      return false;
    }

    // Calculate X coordinate of intersection
    final t = (point.y - p1.y) / (p2.y - p1.y);
    final x = p1.x + t * (p2.x - p1.x);

    return x > point.x;
  }

  /// Count ray crossings for a cubic curve
  int _cubic(Point p0, Point p1, Point p2, Point p3, final Point point) {
    int crossings = 0;
    const steps = 10;

    for (int i = 1; i <= steps; i++) {
      final t1 = (i - 1) / steps;
      final t2 = i / steps;
      final start = MathUtils.cubicBezier(p0, p1, p2, p3, t1);
      final end = MathUtils.cubicBezier(p0, p1, p2, p3, t2);

      if (_crosses(start, end, point)) {
        crossings++;
      }
    }

    return crossings;
  }

  /// Count ray crossings for an arc
  int _arc(ArcCommand arc, final Point start, final Point point) {
    int crossings = 0;
    const segments = 16;
    Point previous = start;

    for (int i = 1; i <= segments; i++) {
      final t = i / segments;
      final angle = arc.startAngle + t * (arc.endAngle - arc.startAngle);
      final next = MathUtils.circlePoint(
        arc.centerX,
        arc.centerY,
        arc.radius,
        angle,
      );

      if (_crosses(previous, next, point)) {
        crossings++;
      }
      previous = next;
    }

    return crossings;
  }

  /// Count ray crossings for an ellipse
  int _ellipse(EllipseCommand ellipse, final Point start, final Point point) {
    int crossings = 0;
    const segments = 16;
    Point previous = start;

    for (int i = 1; i <= segments; i++) {
      final t = i / segments;
      final angle =
          ellipse.startAngle + t * (ellipse.endAngle - ellipse.startAngle);
      final next = MathUtils.ellipsePoint(
        ellipse.centerX,
        ellipse.centerY,
        ellipse.radiusX,
        ellipse.radiusY,
        ellipse.rotation,
        angle,
      );

      if (_crosses(previous, next, point)) {
        crossings++;
      }
      previous = next;
    }

    return crossings;
  }

  /// Intersects two lists of spans on the same scanline
  List<Span> _overlap(List<Span> spans1, List<Span> spans2) {
    final result = <Span>[];

    int i = 0, j = 0;
    while (i < spans1.length && j < spans2.length) {
      final span1 = spans1[i];
      final span2 = spans2[j];

      final x1 = math.max(span1.x1, span2.x1);
      final x2 = math.min(span1.x2, span2.x2);

      final coverage = MathUtils.mul255(span1.coverage, span2.coverage);
      if (x1 < x2 && coverage > 0) {
        result.add(Span.from(span1.y, x1, x2, coverage));
      }

      // Advance the span that ends first
      if (span1.x2 < span2.x2) {
        i++;
      } else {
        j++;
      }
    }

    return result;
  }

  /// Clip a span to the given width
  static Span? _crop(Span span, int width) {
    final x1 = math.max(0, span.x1);
    final x2 = math.min(width, span.x1 + span.length);

    if (x2 <= x1) return null;

    return Span(span.y, x1, x2 - x1, span.coverage);
  }
}

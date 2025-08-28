import 'dart:math' as math;

import '../rasterize/implementations/basic_rasterizer.dart';
import 'bounds_calculator.dart';
import 'winding_calculator.dart';
import '../matrix.dart';
import '../paths/path.dart';
import '../point.dart';
import '../rectangle.dart';
import '../spans/span.dart';
import '../utils/math_utils.dart';

/// Fill rule for determining interior of a path
enum FillRule {
  /// Even-odd fill rule (alternating)
  evenOdd,

  /// Non-zero winding fill rule
  nonZero,
}

/// Represents a clipping region with support for fill rules and hit testing
class ClipRegion {
  /// Pre-rasterized spans organized by scanline for fast lookup
  final Map<int, List<Span>> spansByY;

  /// Bounding rectangle of the clip region
  final Rectangle<int> bounds;

  /// Optional path for advanced operations
  final Path? path;

  /// Fill rule for path-based clipping
  final FillRule fillRule;

  /// Transform applied to the path
  final Matrix2D transform;

  ClipRegion({
    required this.spansByY,
    required this.bounds,
    this.path,
    this.fillRule = FillRule.evenOdd,
    Matrix2D? transform,
  }) : transform = transform ?? Matrix2D.identity();

  /// Creates a clip region from a path
  factory ClipRegion.fromPath(
    Path path,
    Matrix2D transform,
    int width,
    int height, {
    FillRule fillRule = FillRule.evenOdd,
  }) {
    final rasterizer = BasicRasterizer();
    final transformedPath = path.transform(transform);
    final spans = rasterizer.rasterize(transformedPath);

    if (spans.isEmpty) {
      return ClipRegion.empty();
    }

    // Organize spans by scanline
    final spansByY = <int, List<Span>>{};
    int minX = width, maxX = 0;
    int minY = height, maxY = 0;

    for (final span in spans) {
      if (span.y >= 0 && span.y < height) {
        final clippedSpan = _clipSpanToWidth(span, width);
        if (clippedSpan != null && clippedSpan.length > 0) {
          (spansByY[span.y] ??= []).add(clippedSpan);
          minX = math.min(minX, clippedSpan.x1);
          maxX = math.max(maxX, clippedSpan.x1 + clippedSpan.length);
          minY = math.min(minY, clippedSpan.y);
          maxY = math.max(maxY, clippedSpan.y);
        }
      }
    }

    // Apply fill rule for non-zero winding if needed
    final processedSpans = fillRule == FillRule.nonZero
        ? _applyNonZeroFillRule(spansByY, width, height)
        : spansByY;

    if (processedSpans.isEmpty) {
      return ClipRegion.empty();
    }

    // Recalculate bounds after fill rule processing
    minX = width;
    maxX = 0;
    minY = height;
    maxY = 0;
    for (final entry in processedSpans.entries) {
      for (final span in entry.value) {
        minX = math.min(minX, span.x1);
        maxX = math.max(maxX, span.x1 + span.length);
        minY = math.min(minY, span.y);
        maxY = math.max(maxY, span.y);
      }
    }

    final bounds = Rectangle(minX, minY, maxX - minX, maxY - minY + 1);
    return ClipRegion(
      spansByY: processedSpans,
      bounds: bounds,
      path: path,
      fillRule: fillRule,
      transform: transform,
    );
  }

  /// Creates a rectangular clip region
  factory ClipRegion.fromRect(int x, int y, int width, int height) {
    final spansByY = <int, List<Span>>{};

    for (int sy = y; sy < y + height; sy++) {
      spansByY[sy] = [Span.from(sy, x, x + width)];
    }

    return ClipRegion(
      spansByY: spansByY,
      bounds: Rectangle(x, y, width, height),
    );
  }

  /// Creates an empty clip region
  factory ClipRegion.empty() {
    return ClipRegion(spansByY: {}, bounds: Rectangle(0, 0, 0, 0));
  }

  /// Intersects this clip region with another
  ClipRegion intersect(ClipRegion other) {
    if (bounds.intersection(other.bounds) == null) {
      return ClipRegion.empty();
    }

    final resultSpans = <int, List<Span>>{};
    int minX = bounds.width, maxX = 0;
    int minY = bounds.height, maxY = 0;

    // Only process scanlines that exist in both regions
    for (final y in spansByY.keys) {
      if (!other.spansByY.containsKey(y)) continue;

      final spans1 = spansByY[y]!;
      final spans2 = other.spansByY[y]!;
      final intersected = _intersectSpansOnScanline(spans1, spans2);

      if (intersected.isNotEmpty) {
        resultSpans[y] = intersected;
        for (final span in intersected) {
          minX = math.min(minX, span.x1);
          maxX = math.max(maxX, span.x2);
          minY = math.min(minY, span.y);
          maxY = math.max(maxY, span.y);
        }
      }
    }

    if (resultSpans.isEmpty) {
      return ClipRegion.empty();
    }

    return ClipRegion(
      spansByY: resultSpans,
      bounds: Rectangle(minX, minY, maxX - minX, maxY - minY + 1),
    );
  }

  /// Intersects spans with this clip region
  List<Span> clipSpans(List<Span> spans) {
    final result = <Span>[];

    for (final span in spans) {
      if (!spansByY.containsKey(span.y)) continue;

      final clipSpans = spansByY[span.y]!;
      for (final clipSpan in clipSpans) {
        final x1 = math.max(span.x1, clipSpan.x1);
        final x2 = math.min(span.x2, clipSpan.x2);
        if (x1 < x2) {
          // Preserve coverage from original span when clipping
          result.add(Span(span.y, x1, x2 - x1, span.coverage));
        }
      }
    }

    return result;
  }

  /// Tests if a point is inside the clip region using pre-rasterized spans
  bool contains(int x, int y) {
    if (x < bounds.left ||
        x >= bounds.left + bounds.width ||
        y < bounds.top ||
        y >= bounds.top + bounds.height) {
      return false;
    }

    final spans = spansByY[y];
    if (spans == null) {
      return false;
    }

    for (final span in spans) {
      if (x >= span.x1 && x < span.x2) return true;
    }

    return false;
  }

  /// Tests if a point is inside the clip region using the path and fill rule
  bool containsPoint(Point point) {
    // If we have a path, use it for accurate hit testing
    if (path != null) {
      // Quick bounds check
      final doubleBounds = Rectangle<double>(
        bounds.left.toDouble(),
        bounds.top.toDouble(),
        bounds.width.toDouble(),
        bounds.height.toDouble(),
      );
      if (!_boundsContainsPoint(point, doubleBounds)) {
        return false;
      }

      // Transform point to path space
      final inverseTransform = Matrix2D.copy(transform);
      inverseTransform.invert();
      final localPoint = inverseTransform.transform(point);

      // Apply fill rule
      if (fillRule == FillRule.evenOdd) {
        return _isInsideEvenOdd(localPoint, path!);
      } else {
        return _isInsideNonZero(localPoint, path!);
      }
    }

    // Fall back to span-based testing
    return contains(point.x.round(), point.y.round());
  }

  bool get isEmpty => spansByY.isEmpty;

  /// Calculate bounds for a path
  Rectangle<double> calculatePathBounds() {
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
    if (spansByY.isNotEmpty) {
      return spansByY;
    }

    // If we have a path, rasterize it
    if (path != null) {
      final transformedPath = path!.transform(transform);
      final rasterizer = BasicRasterizer();
      final spans = rasterizer.rasterize(transformedPath);

      // Organize spans by scanline and clip to bounds
      final result = <int, List<Span>>{};

      for (final span in spans) {
        if (span.y >= 0 && span.y < height) {
          final clippedSpan = _clipSpanToWidth(span, width);
          if (clippedSpan != null && clippedSpan.length > 0) {
            (result[span.y] ??= []).add(clippedSpan);
          }
        }
      }

      // Apply fill rule for non-zero winding if needed
      if (fillRule == FillRule.nonZero) {
        return _applyNonZeroFillRule(result, width, height);
      }

      return result;
    }

    return {};
  }

  /// Helper method to check if a point is in bounds
  bool _boundsContainsPoint(Point p, Rectangle<double> bounds) {
    return p.x >= bounds.left &&
        p.x <= bounds.left + bounds.width &&
        p.y >= bounds.top &&
        p.y <= bounds.top + bounds.height;
  }

  /// Test if a point is inside using even-odd rule
  bool _isInsideEvenOdd(Point testPoint, Path path) {
    int crossings = 0;
    Point? lastPoint;
    Point? startPoint;

    for (final cmd in path.commands) {
      switch (cmd.type) {
        case PathCommandType.moveTo:
          lastPoint = cmd.points.first;
          startPoint = lastPoint;
          break;

        case PathCommandType.lineTo:
          if (lastPoint != null) {
            if (_lineIntersectsRay(lastPoint, cmd.points.first, testPoint)) {
              crossings++;
            }
            lastPoint = cmd.points.first;
          }
          break;

        case PathCommandType.cubicCurveTo:
          if (lastPoint != null) {
            // Approximate cubic with lines
            crossings += _cubicCrossingCount(
              lastPoint,
              cmd.points[0],
              cmd.points[1],
              cmd.points[2],
              testPoint,
            );
            lastPoint = cmd.points[2];
          }
          break;

        case PathCommandType.arc:
          if (lastPoint != null) {
            final arc = cmd as ArcCommand;
            crossings += _arcCrossingCount(arc, lastPoint, testPoint);
            // Update last point to arc end
            lastPoint = MathUtils.circlePoint(
              arc.centerX,
              arc.centerY,
              arc.radius,
              arc.endAngle,
            );
          }
          break;

        case PathCommandType.ellipse:
          if (lastPoint != null) {
            final ellipse = cmd as EllipseCommand;
            crossings += _ellipseCrossingCount(ellipse, lastPoint, testPoint);
            lastPoint = MathUtils.ellipsePoint(
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
          if (lastPoint != null && startPoint != null) {
            if (_lineIntersectsRay(lastPoint, startPoint, testPoint)) {
              crossings++;
            }
            lastPoint = startPoint;
          }
          break;
      }
    }

    return (crossings % 2) == 1;
  }

  /// Test if a point is inside using non-zero winding rule
  bool _isInsideNonZero(Point testPoint, Path path) {
    final winding = WindingCalculator.calculateWindingNumber(testPoint, path);
    return winding != 0;
  }

  /// Check if a line segment crosses a ray from point going right
  bool _lineIntersectsRay(Point p1, Point p2, Point testPoint) {
    // Check if line segment is entirely above or below the ray
    if ((p1.y > testPoint.y && p2.y > testPoint.y) ||
        (p1.y <= testPoint.y && p2.y <= testPoint.y)) {
      return false;
    }

    // Calculate X coordinate of intersection
    final t = (testPoint.y - p1.y) / (p2.y - p1.y);
    final intersectionX = p1.x + t * (p2.x - p1.x);

    return intersectionX >= testPoint.x;
  }

  /// Count ray crossings for a cubic curve
  int _cubicCrossingCount(
    Point p0,
    Point p1,
    Point p2,
    Point p3,
    Point testPoint,
  ) {
    int crossings = 0;
    const steps = 10;

    for (int i = 1; i <= steps; i++) {
      final t1 = (i - 1) / steps;
      final t2 = i / steps;
      final pt1 = MathUtils.cubicBezier(p0, p1, p2, p3, t1);
      final pt2 = MathUtils.cubicBezier(p0, p1, p2, p3, t2);

      if (_lineIntersectsRay(pt1, pt2, testPoint)) {
        crossings++;
      }
    }

    return crossings;
  }

  /// Count ray crossings for an arc
  int _arcCrossingCount(ArcCommand arc, Point lastPoint, Point testPoint) {
    int crossings = 0;
    const segments = 16;
    Point prevPoint = lastPoint;

    for (int i = 1; i <= segments; i++) {
      final t = i / segments;
      final angle = arc.startAngle + t * (arc.endAngle - arc.startAngle);
      final point = MathUtils.circlePoint(
        arc.centerX,
        arc.centerY,
        arc.radius,
        angle,
      );

      if (_lineIntersectsRay(prevPoint, point, testPoint)) {
        crossings++;
      }
      prevPoint = point;
    }

    return crossings;
  }

  /// Count ray crossings for an ellipse
  int _ellipseCrossingCount(
    EllipseCommand ellipse,
    Point lastPoint,
    Point testPoint,
  ) {
    int crossings = 0;
    const segments = 16;
    Point prevPoint = lastPoint;

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

      if (_lineIntersectsRay(prevPoint, point, testPoint)) {
        crossings++;
      }
      prevPoint = point;
    }

    return crossings;
  }

  // Methods moved to GeometryUtils:
  // Ellipse point calculations now use MathUtils.ellipsePoint directly

  /// Intersects two lists of spans on the same scanline
  List<Span> _intersectSpansOnScanline(List<Span> spans1, List<Span> spans2) {
    final result = <Span>[];

    int i = 0, j = 0;
    while (i < spans1.length && j < spans2.length) {
      final span1 = spans1[i];
      final span2 = spans2[j];

      final x1 = math.max(span1.x1, span2.x1);
      final x2 = math.min(span1.x2, span2.x2);

      if (x1 < x2) {
        result.add(Span.from(span1.y, x1, x2));
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
  static Span? _clipSpanToWidth(Span span, int width) {
    final x1 = math.max(0, span.x1);
    final x2 = math.min(width, span.x1 + span.length);

    if (x2 <= x1) return null;

    return Span(span.y, x1, x2 - x1, span.coverage);
  }

  /// Apply non-zero winding fill rule to spans
  static Map<int, List<Span>> _applyNonZeroFillRule(
    Map<int, List<Span>> spansByY,
    int width,
    int height,
  ) {
    // For non-zero winding, we need to track winding numbers
    // This is a simplified implementation
    final result = <int, List<Span>>{};

    for (final entry in spansByY.entries) {
      final y = entry.key;
      final spans = entry.value;
      final nonZeroSpans = <Span>[];

      // Sort spans by x coordinate
      spans.sort((a, b) => a.x1.compareTo(b.x1));

      // Merge overlapping spans for non-zero rule
      for (final span in spans) {
        if (nonZeroSpans.isEmpty) {
          nonZeroSpans.add(span);
        } else {
          final last = nonZeroSpans.last;
          if (span.x1 <= last.x1 + last.length) {
            // Merge spans
            final newEnd = math.max(
              last.x1 + last.length,
              span.x1 + span.length,
            );
            nonZeroSpans[nonZeroSpans.length - 1] = Span(
              y,
              last.x1,
              newEnd - last.x1,
              math.max(last.coverage, span.coverage),
            );
          } else {
            nonZeroSpans.add(span);
          }
        }
      }

      if (nonZeroSpans.isNotEmpty) {
        result[y] = nonZeroSpans;
      }
    }

    return result;
  }
}

/// Extension methods for Rectangle
extension RectangleExtensions on Rectangle<double> {
  bool isInside(Point p) {
    return p.x >= left &&
        p.x <= left + width &&
        p.y >= top &&
        p.y <= top + height;
  }
}

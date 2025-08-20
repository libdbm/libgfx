import 'dart:math';
import 'dart:typed_data';

import '../../paths/path.dart';
import '../../point.dart';
import '../rasterizer.dart';
import '../../spans/span.dart';
import '../../utils/curve_utils.dart';
import '../../utils/math_utils.dart';

/// Optimized edge with minimal state
class _Edge {
  final double startX;
  final double slope; // dx/dy
  final int yMin;
  final int yMax;
  double x; // Current x position

  _Edge(Point p1, Point p2)
    : startX = p1.x + (p2.x - p1.x) / (p2.y - p1.y) * (p1.y.ceil() - p1.y),
      slope = (p2.x - p1.x) / (p2.y - p1.y),
      yMin = p1.y.ceil(),
      yMax = (p2.y - 0.00001).ceil() - 1,
      x = p1.x + (p2.x - p1.x) / (p2.y - p1.y) * (p1.y.ceil() - p1.y);
}

/// Basic optimized scanline rasterizer
class BasicRasterizer implements Rasterizer {
  static const int maxAlpha = 255;
  final bool antiAlias;

  BasicRasterizer({this.antiAlias = true});

  @override
  List<Span> rasterize(Path path) {
    if (path.commands.isEmpty) return [];

    // Flatten path to edges
    final edges = _pathToEdges(path);
    if (edges.isEmpty) return [];

    // Sort edges by yMin for efficient processing
    edges.sort((a, b) => a.yMin.compareTo(b.yMin));

    final spans = <Span>[];
    final active = <_Edge>[];
    int index = 0;

    final minY = edges.first.yMin;
    final maxY = edges.map((e) => e.yMax).reduce(max);

    // Main scanline loop
    for (int y = minY; y <= maxY; y++) {
      // Add new edges starting at this scanline
      while (index < edges.length && edges[index].yMin == y) {
        active.add(edges[index++]);
      }

      // Remove edges that ended
      active.removeWhere((e) => y > e.yMax);

      if (active.isEmpty) continue;

      // Sort by X coordinate
      active.sort((a, b) => a.x.compareTo(b.x));

      // Generate spans for this scanline
      if (antiAlias) {
        _generateAntiAliasedSpans(y, active, spans);
      } else {
        _generateSimpleSpans(y, active, spans);
      }

      // Advance edges to next scanline
      for (final edge in active) {
        edge.x += edge.slope;
      }
    }

    return spans;
  }

  List<_Edge> _pathToEdges(Path path) {
    final edges = <_Edge>[];
    Point? start, current;

    for (final cmd in path.commands) {
      switch (cmd.type) {
        case PathCommandType.moveTo:
          current = start = cmd.points.first;
          break;

        case PathCommandType.lineTo:
          if (current != null) {
            _addEdge(edges, current, cmd.points.first);
            current = cmd.points.first;
          }
          break;

        case PathCommandType.cubicCurveTo:
          if (current != null) {
            final points = CurveUtils.flattenCubicBezier(
              current,
              cmd.points[0],
              cmd.points[1],
              cmd.points[2],
              tolerance: MathUtils.curveTolerance,
            );
            for (int i = 1; i < points.length; i++) {
              _addEdge(edges, points[i - 1], points[i]);
            }
            current = cmd.points[2];
          }
          break;

        case PathCommandType.arc:
          final arc = cmd as ArcCommand;
          if (current != null) {
            final points = CurveUtils.tessellateArcCommand(current, arc);
            for (int i = 1; i < points.length; i++) {
              _addEdge(edges, points[i - 1], points[i]);
            }
          }
          current = MathUtils.circlePoint(
            arc.centerX,
            arc.centerY,
            arc.radius,
            arc.endAngle,
          );
          break;

        case PathCommandType.ellipse:
          final ellipse = cmd as EllipseCommand;
          final ellipseStart = MathUtils.ellipsePoint(
            ellipse.centerX,
            ellipse.centerY,
            ellipse.radiusX,
            ellipse.radiusY,
            ellipse.rotation,
            ellipse.startAngle,
          );

          if (current != null &&
              ((current.x - ellipseStart.x).abs() > MathUtils.rasterTolerance ||
                  (current.y - ellipseStart.y).abs() >
                      MathUtils.rasterTolerance)) {
            _addEdge(edges, current, ellipseStart);
          }

          final points = CurveUtils.tessellateEllipseCommand(
            ellipseStart,
            ellipse,
          );
          for (int i = 1; i < points.length; i++) {
            _addEdge(edges, points[i - 1], points[i]);
          }

          current = MathUtils.ellipsePoint(
            ellipse.centerX,
            ellipse.centerY,
            ellipse.radiusX,
            ellipse.radiusY,
            ellipse.rotation,
            ellipse.endAngle,
          );
          break;

        case PathCommandType.close:
          if (current != null && start != null) {
            _addEdge(edges, current, start);
          }
          current = start = null;
          break;
      }
    }

    return edges;
  }

  void _addEdge(List<_Edge> edges, Point p1, Point p2) {
    // Skip horizontal edges
    if ((p1.y - p2.y).abs() < MathUtils.rasterTolerance) return;

    // Ensure p1 is above p2
    if (p1.y > p2.y) {
      final temp = p1;
      p1 = p2;
      p2 = temp;
    }

    final edge = _Edge(p1, p2);
    if (edge.yMin <= edge.yMax) {
      edges.add(edge);
    }
  }

  void _generateSimpleSpans(int y, List<_Edge> edges, List<Span> spans) {
    // Even-odd fill rule: pair up edges
    for (int i = 0; i < edges.length - 1; i += 2) {
      final x1 = edges[i].x.round();
      final x2 = edges[i + 1].x.round();
      if (x2 > x1) {
        spans.add(Span(y, x1, x2 - x1, maxAlpha));
      }
    }
  }

  void _generateAntiAliasedSpans(int y, List<_Edge> edges, List<Span> spans) {
    // Dynamic buffer sizing based on edge bounds
    double minXFloat = double.infinity;
    double maxXFloat = double.negativeInfinity;
    for (final edge in edges) {
      if (edge.x < minXFloat) minXFloat = edge.x;
      if (edge.x > maxXFloat) maxXFloat = edge.x;
    }

    final bufferStart = minXFloat.floor() - 1;
    final bufferEnd = maxXFloat.ceil() + 1;
    final bufferSize = bufferEnd - bufferStart + 1;

    if (bufferSize <= 0) return;

    final coverageBuffer = Float32List(bufferSize);
    int minX = 999999;
    int maxX = -1;

    // Process edge pairs (even-odd fill)
    for (int i = 0; i < edges.length - 1; i += 2) {
      final x1 = edges[i].x;
      final x2 = edges[i + 1].x;

      if (x2 <= x1) continue;

      final startPixel = x1.floor();
      final endPixel = x2.ceil() - 1;

      // Track bounds
      if (startPixel < minX) minX = startPixel;
      if (endPixel > maxX) maxX = endPixel;

      // Accumulate coverage
      for (int px = startPixel; px <= endPixel; px++) {
        final bufferIndex = px - bufferStart;
        if (bufferIndex < 0 || bufferIndex >= coverageBuffer.length) continue;

        final pixelLeft = px.toDouble();
        final pixelRight = (px + 1).toDouble();

        final left = x1 > pixelLeft ? x1 : pixelLeft;
        final right = x2 < pixelRight ? x2 : pixelRight;

        if (right > left) {
          coverageBuffer[bufferIndex] += right - left;
        }
      }
    }

    // Convert coverage buffer to spans
    if (minX <= maxX) {
      int? spanStart;
      int? lastAlpha;

      for (int px = minX; px <= maxX; px++) {
        final bufferIndex = px - bufferStart;
        if (bufferIndex < 0 || bufferIndex >= coverageBuffer.length) continue;

        final coverage = coverageBuffer[bufferIndex];
        if (coverage == 0) {
          // End current span if any
          if (spanStart != null && lastAlpha != null) {
            spans.add(Span(y, spanStart, px - spanStart, lastAlpha));
            spanStart = null;
          }
          continue;
        }

        final alpha = (coverage.clamp(0.0, 1.0) * maxAlpha).round();

        if (spanStart == null) {
          // Start new span
          spanStart = px;
          lastAlpha = alpha;
        } else if (alpha != lastAlpha) {
          // End current span and start new one
          spans.add(Span(y, spanStart, px - spanStart, lastAlpha!));
          spanStart = px;
          lastAlpha = alpha;
        }
      }

      // Add final span
      if (spanStart != null && lastAlpha != null) {
        spans.add(Span(y, spanStart, maxX + 1 - spanStart, lastAlpha));
      }
    }
  }
}

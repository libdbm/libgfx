import 'dart:math';
import 'dart:typed_data';

import '../../paths/path.dart';
import '../../point.dart';
import '../../rectangle.dart';
import '../rasterizer.dart';
import '../../spans/span.dart';
import '../../utils/curve_utils.dart';
import '../../utils/math_utils.dart';

/// A flattened path segment, stored top to bottom
class _Edge {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final int direction; // +1 if the path runs down this edge, -1 if up

  /// Change in x per unit of y
  final double slope;

  /// Where the edge crosses the current sub-row, or its nearest end
  double x = 0;

  /// Where the edge crosses the top and bottom of the current band, or its
  /// nearest end
  double top = 0;
  double bottom = 0;

  _Edge(this.x1, this.y1, this.x2, this.y2, this.direction)
    : slope = (x2 - x1) / (y2 - y1);
}

/// Scanline rasterizer. Each pixel row is split into bands at the edge ends
/// inside it; where no two edges cross within a band, the fill rule is
/// applied to the winding of each gap between edges and inside gaps add
/// their exact area. A row where edges cross, or with more bands than [rows],
/// is instead sampled at [rows] sub-rows: on each, the fill rule is applied
/// to the winding between consecutive crossings and each inside run adds its
/// exact horizontal extent. Coverage is therefore exact, or exact
/// horizontally and within 1/[rows] vertically, whatever windings meet
/// inside a pixel.
class BasicRasterizer implements Rasterizer {
  static const int maxAlpha = 255;

  /// Sub-rows sampled per pixel row
  static const int rows = 16;
  final bool antiAlias;

  BasicRasterizer({this.antiAlias = true});

  @override
  List<Span> rasterize(
    Path path, {
    FillRule rule = FillRule.evenOdd,
    Rectangle<int>? viewport,
  }) {
    if (path.commands.isEmpty) return [];

    // Flatten path to edges
    final edges = _flatten(path);
    if (edges.isEmpty) return [];

    // Cells run from [origin] to [limit]; outside a viewport, from the
    // path's own extent
    var origin = edges.map((edge) => min(edge.x1, edge.x2)).reduce(min).floor();
    var limit = edges.map((edge) => max(edge.x1, edge.x2)).reduce(max).ceil();
    var top = edges.map((edge) => edge.y1).reduce(min).floor();
    var bottom = edges.map((edge) => edge.y2).reduce(max).ceil();
    if (viewport != null) {
      origin = viewport.left;
      limit = viewport.right;
      top = max(top, viewport.top);
      bottom = min(bottom, viewport.bottom);
    }
    if (limit <= origin || bottom <= top) return [];

    edges.sort((a, b) => a.y1.compareTo(b.y1));

    final spans = <Span>[];
    final active = <_Edge>[];
    final visible = limit - origin;
    final left = origin.toDouble();
    final right = visible.toDouble();
    final nonZero = rule == FillRule.nonZero;
    const weight = 1 / rows;
    // Changes in coverage along the row; a running sum gives each pixel's
    // coverage
    final cells = Float64List(visible + 2);
    final band = <_Edge>[];
    final events = <double>[];
    var index = 0;

    for (var y = top; y < bottom; y++) {
      while (index < edges.length && edges[index].y1 < y + 1) {
        active.add(edges[index++]);
      }
      active.removeWhere((edge) => edge.y2 <= y);
      if (active.isEmpty) continue;

      final range = _bands(
        active,
        y,
        cells,
        left,
        right,
        nonZero,
        band,
        events,
      );
      if (range != null) {
        if (range.$2 >= range.$1) {
          _sweep(cells, origin, visible, range.$1, range.$2, y, spans);
        }
        continue;
      }

      var first = cells.length;
      var last = -1;
      for (var row = 0; row < rows; row++) {
        final sample = y + (row + 0.5) / rows;
        for (final edge in active) {
          final at = sample < edge.y1
              ? edge.y1
              : sample > edge.y2
              ? edge.y2
              : sample;
          edge.x = edge.x1 + edge.slope * (at - edge.y1);
        }
        _sort(active);

        // Crossings are half-open in y, so a shared vertex counts once;
        // crossings left of a viewport still change the winding
        var winding = 0;
        var from = 0.0;
        for (final edge in active) {
          if (sample < edge.y1 || sample >= edge.y2) continue;
          if (nonZero ? winding != 0 : winding.isOdd) {
            // The run in cell coordinates, inside the visible cells
            var a = from - left;
            var b = edge.x - left;
            if (a < 0) a = 0;
            if (b > right) b = right;
            if (a < b) {
              _run(cells, a, b, weight);
              final start = a.floor();
              final end = b.floor() + 1;
              if (start < first) first = start;
              if (end > last) last = end;
            }
          }
          winding += edge.direction;
          from = edge.x;
        }
      }
      if (last < first) continue;
      _sweep(cells, origin, visible, first, last, y, spans);
    }

    return spans;
  }

  /// Exact coverage of row [y] when no two edges cross inside it. The row is
  /// split into bands at the edge ends inside it; within a band the edge
  /// order, and so the winding of each gap, is fixed, and each edge between
  /// an inside gap and an outside one adds the exact area to its right.
  /// Returns the range of cells touched, or null, with [cells] untouched, if
  /// edges cross or the row has more bands than [rows].
  static (int, int)? _bands(
    List<_Edge> active,
    int y,
    Float64List cells,
    double left,
    double right,
    bool nonZero,
    List<_Edge> band,
    List<double> events,
  ) {
    events
      ..clear()
      ..add(y.toDouble());
    for (var i = 0; i < active.length; i++) {
      final edge = active[i];
      if (edge.y1 > y && edge.y1 < y + 1) events.add(edge.y1);
      if (edge.y2 > y && edge.y2 < y + 1) events.add(edge.y2);
    }
    // Each band visits every active edge, so sub-rows are cheaper past
    // [rows] bands
    if (events.length > rows) return null;
    events
      ..add(y + 1.0)
      ..sort();
    var first = cells.length;
    var last = -1;
    for (var k = 1; k < events.length; k++) {
      final t = events[k - 1];
      final u = events[k];
      if (u <= t) continue;
      // Sorting every active edge, clamped to its ends, keeps the list
      // nearly sorted from band to band
      for (var i = 0; i < active.length; i++) {
        final edge = active[i];
        final a = t < edge.y1 ? edge.y1 : (t > edge.y2 ? edge.y2 : t);
        final b = u < edge.y1 ? edge.y1 : (u > edge.y2 ? edge.y2 : u);
        edge.top = edge.x1 + edge.slope * (a - edge.y1);
        edge.bottom = edge.x1 + edge.slope * (b - edge.y1);
        edge.x = 0.5 * (edge.top + edge.bottom);
      }
      _sort(active);
      band.clear();
      for (var i = 0; i < active.length; i++) {
        final edge = active[i];
        if (edge.y1 <= t && edge.y2 >= u) band.add(edge);
      }
      for (var i = 1; i < band.length; i++) {
        if (band[i - 1].top > band[i].top + 1e-9 ||
            band[i - 1].bottom > band[i].bottom + 1e-9) {
          // Edges cross: undo and let the caller sample
          if (last >= first) cells.fillRange(first, last + 1, 0);
          return null;
        }
      }
      var winding = 0;
      var inside = false;
      for (var i = 0; i < band.length; i++) {
        final edge = band[i];
        winding += edge.direction;
        final now = nonZero ? winding != 0 : winding.isOdd;
        if (now != inside) {
          final a = edge.top - left;
          final b = edge.bottom - left;
          _segment(cells, right, a, b, now ? u - t : t - u);
          // _segment moves parts outside the cells to the nearest side
          final low = min(a, b).clamp(0.0, right).floor();
          final high = max(a, b).clamp(0.0, right).floor() + 1;
          if (low < first) first = low;
          if (high > last) last = high;
          inside = now;
        }
      }
    }
    return (first, last);
  }

  /// Adds the area right of the segment from [x0] to [x1], in cells, times
  /// [height] to [cells]. Parts outside the cells move to the nearest side:
  /// the area right of a part left of them still counts, and a part right of
  /// them covers nothing visible.
  static void _segment(
    Float64List cells,
    double right,
    double x0,
    double x1,
    double height,
  ) {
    if (x0 >= 0 && x1 >= 0 && x0 <= right && x1 <= right) {
      _accumulate(cells, x0, x1, height);
      return;
    }
    // Split points as fractions of the segment, in order along it
    final cuts = <double>[0];
    for (final side in [0.0, right]) {
      if ((x0 < side) != (x1 < side)) cuts.add((side - x0) / (x1 - x0));
    }
    cuts
      ..add(1)
      ..sort();
    for (var i = 1; i < cuts.length; i++) {
      _accumulate(
        cells,
        (x0 + (x1 - x0) * cuts[i - 1]).clamp(0.0, right),
        (x0 + (x1 - x0) * cuts[i]).clamp(0.0, right),
        height * (cuts[i] - cuts[i - 1]),
      );
    }
  }

  /// Exact signed-area accumulation of one segment within a row, in cell
  /// coordinates, after font-rs. Each cell receives the change in coverage
  /// from its left neighbour, so a running sum along the row gives each
  /// pixel's signed coverage.
  static void _accumulate(
    Float64List cells,
    double x0,
    double x1,
    double height,
  ) {
    final low = min(x0, x1);
    final high = max(x0, x1);
    final start = low.floor();
    final end = high.ceil();
    if (end <= start + 1) {
      // Within one cell: split by the segment's mean position
      final mean = 0.5 * (x0 + x1) - start;
      cells[start] += height * (1 - mean);
      cells[start + 1] += height * mean;
      return;
    }
    final scale = 1 / (high - low);
    final first = low - start;
    final head = 0.5 * scale * (1 - first) * (1 - first);
    final last = high - end + 1;
    final tail = 0.5 * scale * last * last;
    cells[start] += height * head;
    if (end == start + 2) {
      cells[start + 1] += height * (1 - head - tail);
    } else {
      final second = scale * (1.5 - first);
      cells[start + 1] += height * (second - head);
      for (var x = start + 2; x < end - 1; x++) {
        cells[x] += height * scale;
      }
      final before = second + (end - start - 3) * scale;
      cells[end - 1] += height * (1 - before - tail);
    }
    cells[end] += height * tail;
  }

  /// Insertion sort by crossing; the order changes little from one sub-row
  /// to the next, so this is close to linear
  static void _sort(List<_Edge> edges) {
    for (var i = 1; i < edges.length; i++) {
      final edge = edges[i];
      var j = i - 1;
      while (j >= 0 && edges[j].x > edge.x) {
        edges[j + 1] = edges[j];
        j--;
      }
      edges[j + 1] = edge;
    }
  }

  List<_Edge> _flatten(Path path) {
    final edges = <_Edge>[];
    Point? start, current;

    for (final command in path.commands) {
      switch (command.type) {
        case PathCommandType.moveTo:
          _close(edges, current, start);
          current = start = command.points.first;
          break;

        case PathCommandType.lineTo:
          if (current != null) {
            _add(edges, current, command.points.first);
            current = command.points.first;
          }
          break;

        case PathCommandType.cubicCurveTo:
          if (current != null) {
            final points = CurveUtils.flattenCubicBezier(
              current,
              command.points[0],
              command.points[1],
              command.points[2],
              tolerance: MathUtils.curveTolerance,
            );
            for (int i = 1; i < points.length; i++) {
              _add(edges, points[i - 1], points[i]);
            }
            current = command.points[2];
          }
          break;

        case PathCommandType.arc:
          final arc = command as ArcCommand;
          if (current != null) {
            final points = CurveUtils.tessellateArcCommand(current, arc);
            for (int i = 1; i < points.length; i++) {
              _add(edges, points[i - 1], points[i]);
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
          final ellipse = command as EllipseCommand;
          final begin = MathUtils.ellipsePoint(
            ellipse.centerX,
            ellipse.centerY,
            ellipse.radiusX,
            ellipse.radiusY,
            ellipse.rotation,
            ellipse.startAngle,
          );

          if (current != null &&
              ((current.x - begin.x).abs() > MathUtils.rasterTolerance ||
                  (current.y - begin.y).abs() > MathUtils.rasterTolerance)) {
            _add(edges, current, begin);
          }

          start ??= begin;
          final points = CurveUtils.tessellateEllipseCommand(begin, ellipse);
          for (int i = 1; i < points.length; i++) {
            _add(edges, points[i - 1], points[i]);
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
          _close(edges, current, start);
          current = start = null;
          break;
      }
    }

    // Filling closes every subpath
    _close(edges, current, start);
    return edges;
  }

  void _close(List<_Edge> edges, Point? current, Point? start) {
    if (current != null && start != null) {
      _add(edges, current, start);
    }
  }

  void _add(List<_Edge> edges, final Point from, final Point to) {
    // A horizontal edge encloses no area
    if (from.y == to.y) return;

    if (from.y < to.y) {
      edges.add(_Edge(from.x, from.y, to.x, to.y, 1));
    } else {
      edges.add(_Edge(to.x, to.y, from.x, from.y, -1));
    }
  }

  /// Adds coverage [weight] over the run from [a] to [b] (with a < b), in
  /// cell coordinates, to [cells], which hold changes in coverage: partial
  /// cells at the ends get their covered fraction. Changes cells from
  /// floor(a) to floor(b) + 1.
  static void _run(Float64List cells, double a, double b, double weight) {
    final start = a.floor();
    final end = b.floor();
    final head = (start + 1 - a) * weight;
    final tail = (b - end) * weight;
    if (start == end) {
      cells[start] += (b - a) * weight;
      cells[start + 1] -= (b - a) * weight;
      return;
    }
    cells[start] += head;
    cells[start + 1] += weight - head;
    cells[end] += tail - weight;
    cells[end + 1] -= tail;
  }

  /// Turns the coverage changes in [cells] from [first] to [last] into spans
  /// for row [y], and clears them.
  void _sweep(
    Float64List cells,
    int origin,
    int visible,
    int first,
    int last,
    int y,
    List<Span> spans,
  ) {
    var sum = 0.0;
    var start = first;
    var previous = 0;
    for (var i = first; i <= last; i++) {
      sum += cells[i];
      cells[i] = 0;
      if (i >= visible) continue;
      final alpha = _alpha(sum);
      if (alpha != previous) {
        if (previous != 0) {
          spans.add(Span(y, origin + start, i - start, previous));
        }
        start = i;
        previous = alpha;
      }
    }
    // Coverage is zero past the last changed cell
    if (previous != 0) {
      spans.add(
        Span(y, origin + start, min(last + 1, visible) - start, previous),
      );
    }
  }

  /// Alpha for a pixel with [coverage] between 0 and 1
  int _alpha(double coverage) {
    final clamped = coverage.clamp(0.0, 1.0);
    if (!antiAlias) return clamped >= 0.5 ? maxAlpha : 0;
    return (clamped * maxAlpha).round();
  }
}

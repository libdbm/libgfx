import 'dart:math' as math;

import 'image/bitmap.dart';
import 'color/color.dart';
import 'color/color_utils.dart';
import 'matrix.dart';
import 'point.dart';
import 'result.dart';
import 'utils/math_utils.dart';

enum GradientSpread {
  pad, // Default - clamp to edge colors
  reflect, // Mirror the gradient
  repeat, // Tile the gradient
}

/// Represents a color stop in a gradient with position (offset) and color
class ColorStop {
  final double offset;
  final Color color;

  ColorStop(this.offset, this.color);
}

/// Abstract base class for all paint types; a [Color] paints itself
/// everywhere, gradients and patterns vary with position
abstract class Paint {
  /// The color at [point], given the inverse of the current transform
  Color sample(Point point, Matrix2D inverse);
}

/// Base class for gradient paints with shared functionality. Gradients are
/// immutable: [addColorStop] returns a new gradient.
abstract class GradientPaint extends Paint {
  /// The color stops, sorted by offset, with offsets clamped to 0..1 (a
  /// non-finite offset becomes 0). Stops at the same offset keep their order.
  final List<ColorStop> stops;
  final GradientSpread spread;

  GradientPaint({
    required List<ColorStop> stops,
    this.spread = GradientSpread.pad,
  }) : stops = _normalize(stops);

  /// A copy of this gradient with a stop at [offset] added, as W3C canvas
  /// `addColorStop` adds one in place.
  GradientPaint addColorStop(final double offset, final Color color) =>
      _with([...stops, ColorStop(offset, color)]);

  /// A copy of this gradient with [stops] in place of its own.
  GradientPaint _with(final List<ColorStop> stops);

  static List<ColorStop> _normalize(final Iterable<ColorStop> stops) {
    final clamped = [
      for (final stop in stops)
        ColorStop(
          stop.offset.isFinite ? stop.offset.clamp(0.0, 1.0) : 0.0,
          stop.color,
        ),
    ];
    // List.sort is not stable, so break ties by position
    final order = List.generate(clamped.length, (index) => index)
      ..sort((a, b) {
        final compared = clamped[a].offset.compareTo(clamped[b].offset);
        return compared != 0 ? compared : a.compareTo(b);
      });
    return List.unmodifiable([for (final index in order) clamped[index]]);
  }

  /// Apply spread method to gradient parameter
  double wrap(double t) {
    switch (spread) {
      case GradientSpread.pad:
        return t.clamp(0.0, 1.0);

      case GradientSpread.reflect:
        // Mirror the gradient back and forth
        if (t < 0 || t > 1) {
          final cycles = t.abs().floor();
          final fraction = t.abs() - cycles;
          // Odd cycles are reflected
          return cycles % 2 == 0 ? fraction : 1.0 - fraction;
        }
        return t;

      case GradientSpread.repeat:
        // Tile the gradient, ensuring positive result
        return (t % 1.0 + 1.0) % 1.0;
    }
  }

  /// Get interpolated color at normalized offset
  Color lookup(double t) {
    if (stops.isEmpty) return const Color(0x00000000);
    if (t <= stops.first.offset) return stops.first.color;
    if (t >= stops.last.offset) return stops.last.color;

    // A NaN t matches no stop
    if (t.isNaN) return stops.last.color;

    // Binary search for the first stop at or after t; t lies strictly
    // after the stop before it, so the pair never has equal offsets
    int low = 1;
    int high = stops.length - 1;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (stops[middle].offset >= t) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    final before = stops[low - 1];
    final after = stops[low];
    final fraction = (t - before.offset) / (after.offset - before.offset);
    return ColorUtils.lerp(before.color, after.color, fraction);
  }
}

class LinearGradient extends GradientPaint {
  final Point start;
  final Point end;

  // Cached gradient vector components
  late final double _dx;
  late final double _dy;
  late final double _lengthSquared;

  LinearGradient({
    required this.start,
    required this.end,
    required List<ColorStop> stops,
    GradientSpread spread = GradientSpread.pad,
  }) : super(stops: stops, spread: spread) {
    _dx = end.x - start.x;
    _dy = end.y - start.y;
    _lengthSquared = _dx * _dx + _dy * _dy;
  }

  @override
  LinearGradient addColorStop(final double offset, final Color color) =>
      _with([...stops, ColorStop(offset, color)]);

  @override
  LinearGradient _with(final List<ColorStop> stops) =>
      LinearGradient(start: start, end: end, stops: stops, spread: spread);

  @override
  Color sample(Point point, Matrix2D inverse) {
    // Inline transform: point -> user space
    final ux = inverse.a * point.x + inverse.c * point.y + inverse.tx;
    final uy = inverse.b * point.x + inverse.d * point.y + inverse.ty;

    // Inline dot product and projection
    final dx = ux - start.x;
    final dy = uy - start.y;
    double t = (dx * _dx + dy * _dy) / _lengthSquared;

    t = wrap(t);
    return lookup(t);
  }

  /// Get gradient parameter t at specific coordinates (for incremental sampling)
  double offset(double x, double y, Matrix2D inverse) {
    final ux = inverse.a * x + inverse.c * y + inverse.tx;
    final uy = inverse.b * x + inverse.d * y + inverse.ty;
    final dx = ux - start.x;
    final dy = uy - start.y;
    return (dx * _dx + dy * _dy) / _lengthSquared;
  }

  /// Get delta of t when moving one pixel to the right (for scanline rendering)
  double step(Matrix2D inverse) {
    // When x increases by 1, user space changes by (inverse.a, inverse.b)
    return (inverse.a * _dx + inverse.b * _dy) / _lengthSquared;
  }
}

class RadialGradient extends GradientPaint {
  final Point center;
  final double radius;
  final Point? focal; // Optional focal point for non-centered gradients

  late final double _originX;
  late final double _originY;

  RadialGradient({
    required this.center,
    required this.radius,
    required List<ColorStop> stops,
    GradientSpread spread = GradientSpread.pad,
    this.focal,
  }) : super(stops: stops, spread: spread) {
    final origin = focal ?? center;
    _originX = origin.x;
    _originY = origin.y;
  }

  @override
  RadialGradient addColorStop(final double offset, final Color color) =>
      _with([...stops, ColorStop(offset, color)]);

  @override
  RadialGradient _with(final List<ColorStop> stops) => RadialGradient(
    center: center,
    radius: radius,
    stops: stops,
    spread: spread,
    focal: focal,
  );

  @override
  Color sample(Point point, Matrix2D inverse) {
    // Inline transform
    final ux = inverse.a * point.x + inverse.c * point.y + inverse.tx;
    final uy = inverse.b * point.x + inverse.d * point.y + inverse.ty;

    // Inline distance calculation
    final dx = ux - _originX;
    final dy = uy - _originY;
    final distance = math.sqrt(dx * dx + dy * dy);
    double t = distance / radius;

    t = wrap(t);
    return lookup(t);
  }
}

/// Conical/Sweep gradient - creates an angular gradient around a center point
class ConicalGradient extends GradientPaint {
  final Point center;
  final double startAngle; // Starting angle in radians

  ConicalGradient({
    required this.center,
    this.startAngle = 0.0,
    required List<ColorStop> stops,
    GradientSpread spread = GradientSpread.pad,
  }) : super(stops: stops, spread: spread);

  @override
  ConicalGradient addColorStop(final double offset, final Color color) =>
      _with([...stops, ColorStop(offset, color)]);

  @override
  ConicalGradient _with(final List<ColorStop> stops) => ConicalGradient(
    center: center,
    startAngle: startAngle,
    stops: stops,
    spread: spread,
  );

  @override
  Color sample(Point point, Matrix2D inverse) {
    // Inline transform
    final ux = inverse.a * point.x + inverse.c * point.y + inverse.tx;
    final uy = inverse.b * point.x + inverse.d * point.y + inverse.ty;

    // Calculate angle from center
    final dx = ux - center.x;
    final dy = uy - center.y;

    if (dx == 0 && dy == 0) {
      return stops.isNotEmpty ? stops.first.color : const Color(0x00000000);
    }

    // Calculate angle and normalize
    double angle = math.atan2(dy, dx) - startAngle;
    angle = MathUtils.normalizeAngle(angle);

    double t = angle / (2 * math.pi);
    t = wrap(t);
    return lookup(t);
  }
}

/// Pattern repeat modes
enum PatternRepeat {
  repeat, // Repeat in both X and Y (default)
  repeatX, // Repeat only in X
  repeatY, // Repeat only in Y
  noRepeat, // No repetition
}

/// Enhanced pattern paint that supports Bitmap and advanced features
class PatternPaint extends Paint {
  final Bitmap _pattern;
  final Matrix2D _transform;
  final PatternRepeat repeat;
  final double opacity;

  /// Null when [transform] is singular; the pattern then paints nothing.
  late final Matrix2D? _inverse;

  /// [pattern] and [transform] are copied, so later changes to them do not
  /// affect this paint.
  PatternPaint({
    required Bitmap pattern,
    Matrix2D? transform,
    this.repeat = PatternRepeat.repeat,
    this.opacity = 1.0,
  }) : _pattern = pattern.clone(),
       _transform = transform?.clone() ?? Matrix2D.identity() {
    _inverse = switch (_transform.inverse()) {
      Ok(:final value) => value,
      Err() => null,
    };
  }

  /// A copy of the pattern bitmap.
  Bitmap get pattern => _pattern.clone();

  /// A copy of the pattern transform.
  Matrix2D get transform => _transform.clone();

  @override
  Color sample(Point point, Matrix2D inverse) {
    // 1. Convert the device-space pixel `point` back to user-space.
    final user = inverse.transform(point);

    // 2. Transform the user-space point into the pattern's local space.
    final local = _inverse;
    if (local == null) return Color.transparent;
    final mapped = local.transform(user);

    // 3. Get pattern coordinates based on repeat mode
    double x = mapped.x;
    double y = mapped.y;

    switch (repeat) {
      case PatternRepeat.repeat:
        // Wrap both X and Y
        x = (x % _pattern.width + _pattern.width) % _pattern.width;
        y = (y % _pattern.height + _pattern.height) % _pattern.height;
        break;

      case PatternRepeat.repeatX:
        // Wrap X, clamp Y
        x = (x % _pattern.width + _pattern.width) % _pattern.width;
        if (y < 0 || y >= _pattern.height) {
          return Color.transparent;
        }
        break;

      case PatternRepeat.repeatY:
        // Wrap Y, clamp X
        y = (y % _pattern.height + _pattern.height) % _pattern.height;
        if (x < 0 || x >= _pattern.width) {
          return Color.transparent;
        }
        break;

      case PatternRepeat.noRepeat:
        // Clamp both
        if (x < 0 || x >= _pattern.width || y < 0 || y >= _pattern.height) {
          return Color.transparent;
        }
        break;
    }

    // 4. Sample the pattern with bilinear interpolation for smooth results
    final color = _bilinear(x, y);

    // 5. Apply opacity if needed
    if (opacity < 1.0) {
      final alpha = (color.alpha * opacity).round().clamp(0, 255);
      return Color.fromRGBA(color.red, color.green, color.blue, alpha);
    }

    return color;
  }

  Color _bilinear(double x, double y) {
    // Use bilinear interpolation for smooth pattern sampling; texel i has its
    // centre at i + 0.5, so interpolate between centres
    final u = x - 0.5;
    final v = y - 0.5;
    final left = u.floor();
    final top = v.floor();
    final fx = u - left;
    final fy = v - top;

    final x0 = left.clamp(0, _pattern.width - 1);
    final x1 = (left + 1).clamp(0, _pattern.width - 1);
    final y0 = top.clamp(0, _pattern.height - 1);
    final y1 = (top + 1).clamp(0, _pattern.height - 1);

    final c00 = _pattern.pixel(x0, y0);
    final c10 = _pattern.pixel(x1, y0);
    final c01 = _pattern.pixel(x0, y1);
    final c11 = _pattern.pixel(x1, y1);

    // Bilinear interpolation
    return ColorUtils.bilerp(c00, c10, c01, c11, fx, fy);
  }
}

import 'dart:math' as math;

import 'image/bitmap.dart';
import 'color/color.dart';
import 'color/color_utils.dart';
import 'matrix.dart';
import 'point.dart';
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

/// Abstract base class for all paint types (solid colors, gradients, patterns)
abstract class Paint {
  Color getColorAt(Point point, Matrix2D inverseTransform);
}

/// Solid color paint that applies a uniform color to all pixels
class SolidPaint extends Paint {
  final Color color;

  SolidPaint(this.color);

  @override
  Color getColorAt(Point point, Matrix2D inverseTransform) => color;
}

/// Base class for gradient paints with shared functionality
abstract class GradientPaint extends Paint {
  final List<ColorStop> stops;
  final GradientSpread spread;

  GradientPaint({required this.stops, this.spread = GradientSpread.pad}) {
    stops.sort((a, b) => a.offset.compareTo(b.offset));
  }

  /// Apply spread method to gradient parameter
  double applySpread(double t) {
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
  Color getColorAtOffset(double t) {
    if (stops.isEmpty) return const Color(0x00000000);
    if (t <= stops.first.offset) return stops.first.color;
    if (t >= stops.last.offset) return stops.last.color;

    for (int i = 0; i < stops.length - 1; i++) {
      if (t >= stops[i].offset && t <= stops[i + 1].offset) {
        final s1 = stops[i];
        final s2 = stops[i + 1];
        final localT = (t - s1.offset) / (s2.offset - s1.offset);
        return ColorUtils.lerpRgb(s1.color, s2.color, localT);
      }
    }
    return stops.last.color;
  }
}

class LinearGradient extends GradientPaint {
  final Point startPoint;
  final Point endPoint;

  LinearGradient({
    required this.startPoint,
    required this.endPoint,
    required List<ColorStop> stops,
    GradientSpread spread = GradientSpread.pad,
  }) : super(stops: stops, spread: spread);

  @override
  Color getColorAt(Point point, Matrix2D inverseTransform) {
    final userPoint = inverseTransform.transform(point);
    final gradientVector = endPoint - startPoint;
    final pointVector = userPoint - startPoint;
    double t = (pointVector.dot(gradientVector)) / gradientVector.length2;

    // Apply spread method and get color
    t = applySpread(t);
    return getColorAtOffset(t);
  }
}

class RadialGradient extends GradientPaint {
  final Point center;
  final double radius;
  final Point? focal; // Optional focal point for non-centered gradients

  RadialGradient({
    required this.center,
    required this.radius,
    required List<ColorStop> stops,
    GradientSpread spread = GradientSpread.pad,
    this.focal,
  }) : super(stops: stops, spread: spread);

  @override
  Color getColorAt(Point point, Matrix2D inverseTransform) {
    final userPoint = inverseTransform.transform(point);

    // Use focal point if provided, otherwise use center
    final gradientOrigin = focal ?? center;
    final distance = (userPoint - gradientOrigin).length;
    double t = distance / radius;

    // Apply spread method and get color
    t = applySpread(t);
    return getColorAtOffset(t);
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
  Color getColorAt(Point point, Matrix2D inverseTransform) {
    final userPoint = inverseTransform.transform(point);

    // Calculate angle from center
    final dx = userPoint.x - center.x;
    final dy = userPoint.y - center.y;

    if (dx == 0 && dy == 0) {
      // At the center point, use first color
      return stops.isNotEmpty ? stops.first.color : const Color(0x00000000);
    }

    // Calculate angle and normalize to [0, 1]
    double angle = math.atan2(dy, dx) - startAngle;
    // Normalize to [0, 2π]
    angle = MathUtils.normalizeAngle(angle);

    // Convert to [0, 1] range
    double t = angle / (2 * math.pi);

    // Apply spread method and get color
    t = applySpread(t);
    return getColorAtOffset(t);
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
  final Bitmap pattern;
  final Matrix2D transform;
  final PatternRepeat repeat;
  final double opacity;
  late final Matrix2D _inverseTransform;

  PatternPaint({
    required this.pattern,
    Matrix2D? transform,
    this.repeat = PatternRepeat.repeat,
    this.opacity = 1.0,
  }) : transform = transform ?? Matrix2D.identity() {
    _inverseTransform = Matrix2D.copy(this.transform)..invert();
  }

  @override
  Color getColorAt(Point point, Matrix2D inverseTransform) {
    // 1. Convert the device-space pixel `point` back to user-space.
    final userPoint = inverseTransform.transform(point);

    // 2. Transform the user-space point into the pattern's local space.
    final patternPoint = _inverseTransform.transform(userPoint);

    // 3. Get pattern coordinates based on repeat mode
    double x = patternPoint.x;
    double y = patternPoint.y;

    switch (repeat) {
      case PatternRepeat.repeat:
        // Wrap both X and Y
        x = (x % pattern.width + pattern.width) % pattern.width;
        y = (y % pattern.height + pattern.height) % pattern.height;
        break;

      case PatternRepeat.repeatX:
        // Wrap X, clamp Y
        x = (x % pattern.width + pattern.width) % pattern.width;
        if (y < 0 || y >= pattern.height) {
          return Color.transparent;
        }
        break;

      case PatternRepeat.repeatY:
        // Wrap Y, clamp X
        y = (y % pattern.height + pattern.height) % pattern.height;
        if (x < 0 || x >= pattern.width) {
          return Color.transparent;
        }
        break;

      case PatternRepeat.noRepeat:
        // Clamp both
        if (x < 0 || x >= pattern.width || y < 0 || y >= pattern.height) {
          return Color.transparent;
        }
        break;
    }

    // 4. Sample the pattern with bilinear interpolation for smooth results
    final color = _samplePattern(x, y);

    // 5. Apply opacity if needed
    if (opacity < 1.0) {
      final alpha = (color.alpha * opacity).round().clamp(0, 255);
      return Color.fromRGBA(color.red, color.green, color.blue, alpha);
    }

    return color;
  }

  Color _samplePattern(double x, double y) {
    // Use bilinear interpolation for smooth pattern sampling
    final x0 = x.floor().clamp(0, pattern.width - 1);
    final x1 = (x0 + 1).clamp(0, pattern.width - 1);
    final y0 = y.floor().clamp(0, pattern.height - 1);
    final y1 = (y0 + 1).clamp(0, pattern.height - 1);

    final fx = x - x0;
    final fy = y - y0;

    final c00 = pattern.getPixel(x0, y0);
    final c10 = pattern.getPixel(x1, y0);
    final c01 = pattern.getPixel(x0, y1);
    final c11 = pattern.getPixel(x1, y1);

    // Bilinear interpolation
    return ColorUtils.bilerpColor(c00, c10, c01, c11, fx, fy);
  }
}

// Utilities for colors
import 'dart:math' as math;

import 'color.dart';
import '../utils/math_utils.dart';

/// HSL color representation
class HSLColor {
  final double hue; // 0-360
  final double saturation; // 0-1
  final double lightness; // 0-1
  final double alpha; // 0-1

  const HSLColor(this.hue, this.saturation, this.lightness, [this.alpha = 1.0]);

  /// The same color in RGB
  Color get color {
    final h = hue / 360;
    final s = saturation;
    final l = lightness;

    if (s == 0) {
      // Achromatic
      final gray = (l * 255).round();
      return Color.fromRGBA(gray, gray, gray, (alpha * 255).round());
    }

    double channel(double p, double q, double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;

    final r = channel(p, q, h + 1 / 3);
    final g = channel(p, q, h);
    final b = channel(p, q, h - 1 / 3);

    return Color.fromRGBA(
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
      (alpha * 255).round(),
    );
  }
}

class ColorUtils {
  // Prevent instantiation
  ColorUtils._();

  /// Premultiply alpha channel using optimized integer math
  static Color premultiply(Color color) {
    if (color.alpha == 255) return color;
    if (color.alpha == 0) return Color.transparent;

    final a = color.alpha;
    return Color.fromRGBA(
      MathUtils.mul255(color.red, a),
      MathUtils.mul255(color.green, a),
      MathUtils.mul255(color.blue, a),
      a,
    );
  }

  /// Unpremultiply from raw RGBA values (for blend operations)
  static Color unpremultiply(int r, int g, int b, int a) {
    if (a == 0) return Color.transparent;
    if (a == 255) return Color.fromRGBA(r, g, b, a);

    final inverse = (255 * 255) ~/ a;
    return Color.fromRGBA(
      math.min(255, (r * inverse + 127) >> 8),
      math.min(255, (g * inverse + 127) >> 8),
      math.min(255, (b * inverse + 127) >> 8),
      a,
    );
  }

  /// Convert color to grayscale using luminance
  static Color grayscale(Color color) {
    // Using standard luminance weights
    final gray = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue)
        .round();
    return Color.fromRGBA(gray, gray, gray, color.alpha);
  }

  /// Adjust color brightness (-1.0 to 1.0)
  static Color brighten(Color color, double factor) {
    factor = factor.clamp(-1.0, 1.0);

    if (factor == 0) return color;

    int adjust(int channel) {
      if (factor > 0) {
        return (channel + (255 - channel) * factor).round().clamp(0, 255);
      } else {
        return (channel * (1 + factor)).round().clamp(0, 255);
      }
    }

    return Color.fromRGBA(
      adjust(color.red),
      adjust(color.green),
      adjust(color.blue),
      color.alpha,
    );
  }

  /// Set alpha channel of a color
  static Color opacity(Color color, int alpha) {
    return Color.fromRGBA(
      color.red,
      color.green,
      color.blue,
      alpha.clamp(0, 255),
    );
  }

  /// Linearly interpolates between two colors in RGB space
  static Color lerp(Color a, Color b, double t) {
    t = t.clamp(0.0, 1.0);
    return Color.fromARGB(
      MathUtils.lerp(a.alpha.toDouble(), b.alpha.toDouble(), t).round(),
      MathUtils.lerp(a.red.toDouble(), b.red.toDouble(), t).round(),
      MathUtils.lerp(a.green.toDouble(), b.green.toDouble(), t).round(),
      MathUtils.lerp(a.blue.toDouble(), b.blue.toDouble(), t).round(),
    );
  }

  /// Bilinear interpolation between four colors
  /// Takes the four corner colors (c00, c10, c01, c11) and interpolation factors (fx, fy)
  /// and returns the interpolated color
  static Color bilerp(
    Color c00,
    Color c10,
    Color c01,
    Color c11,
    double fx,
    double fy,
  ) {
    final r = MathUtils.bilerpInt(c00.red, c10.red, c01.red, c11.red, fx, fy);
    final g = MathUtils.bilerpInt(
      c00.green,
      c10.green,
      c01.green,
      c11.green,
      fx,
      fy,
    );
    final b = MathUtils.bilerpInt(
      c00.blue,
      c10.blue,
      c01.blue,
      c11.blue,
      fx,
      fy,
    );
    final a = MathUtils.bilerpInt(
      c00.alpha,
      c10.alpha,
      c01.alpha,
      c11.alpha,
      fx,
      fy,
    );
    return Color.fromRGBA(r, g, b, a);
  }
}

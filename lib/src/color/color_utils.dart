// Utilities for colors
import 'dart:math' as math;

import 'color.dart';
import '../utils/math_utils.dart';

/// HSL color representation
/// Used primarily by examples and tests for color generation
/// Not part of the public API
class HSLColor {
  final double hue; // 0-360
  final double saturation; // 0-1
  final double lightness; // 0-1
  final double alpha; // 0-1

  const HSLColor(this.hue, this.saturation, this.lightness, [this.alpha = 1.0]);
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

  /// Unpremultiply alpha channel using optimized integer math
  static Color unpremultiply(Color color) {
    if (color.alpha == 0) return Color.transparent;
    if (color.alpha == 255) return color;

    return unpremultiplyRGBA(color.red, color.green, color.blue, color.alpha);
  }

  /// Unpremultiply from raw RGBA values (for blend operations)
  static Color unpremultiplyRGBA(int r, int g, int b, int a) {
    if (a == 0) return Color.transparent;
    if (a == 255) return Color.fromRGBA(r, g, b, a);

    final invA = (255 * 255) ~/ a;
    return Color.fromRGBA(
      math.min(255, (r * invA + 127) >> 8),
      math.min(255, (g * invA + 127) >> 8),
      math.min(255, (b * invA + 127) >> 8),
      a,
    );
  }

  /// Convert color to grayscale using luminance
  static Color toGrayscale(Color color) {
    // Using standard luminance weights
    final gray = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue)
        .round();
    return Color.fromRGBA(gray, gray, gray, color.alpha);
  }

  /// Adjust color brightness (-1.0 to 1.0)
  static Color adjustBrightness(Color color, double factor) {
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

  /// Adjust color saturation (0.0 = grayscale, 1.0 = normal, >1.0 = oversaturated)
  static Color adjustSaturation(Color color, double factor) {
    factor = math.max(0, factor);

    final gray = toGrayscale(color);
    if (factor == 0) return gray;
    if (factor == 1) return color;

    int mix(int colorChannel, int grayChannel) {
      return ((1 - factor) * grayChannel + factor * colorChannel).round().clamp(
        0,
        255,
      );
    }

    return Color.fromRGBA(
      mix(color.red, gray.red),
      mix(color.green, gray.green),
      mix(color.blue, gray.blue),
      color.alpha,
    );
  }

  /// Mix two colors with a ratio (0.0 = color1, 1.0 = color2)
  static Color mixColors(Color color1, Color color2, double ratio) {
    ratio = ratio.clamp(0.0, 1.0);

    if (ratio == 0) return color1;
    if (ratio == 1) return color2;

    final invRatio = 1 - ratio;

    return Color.fromRGBA(
      (color1.red * invRatio + color2.red * ratio).round(),
      (color1.green * invRatio + color2.green * ratio).round(),
      (color1.blue * invRatio + color2.blue * ratio).round(),
      (color1.alpha * invRatio + color2.alpha * ratio).round(),
    );
  }

  /// Create color gradient between two colors
  static List<Color> createGradient(Color start, Color end, int steps) {
    if (steps <= 0) return [];
    if (steps == 1) return [start];
    if (steps == 2) return [start, end];

    final colors = <Color>[];
    for (int i = 0; i < steps; i++) {
      final t = i / (steps - 1);
      colors.add(lerpRgb(start, end, t));
    }
    return colors;
  }

  /// Convert RGB to HSL
  /// Used primarily by examples and tests for color generation
  static HSLColor rgbToHsl(Color color) {
    final r = color.red / 255.0;
    final g = color.green / 255.0;
    final b = color.blue / 255.0;

    final max = math.max(math.max(r, g), b);
    final min = math.min(math.min(r, g), b);
    final delta = max - min;

    // Lightness
    final l = (max + min) / 2;

    if (delta == 0) {
      // Achromatic
      return HSLColor(0, 0, l, color.alpha / 255.0);
    }

    // Saturation
    final s = l > 0.5 ? delta / (2 - max - min) : delta / (max + min);

    // Hue
    double h;
    if (max == r) {
      h = ((g - b) / delta + (g < b ? 6 : 0)) / 6;
    } else if (max == g) {
      h = ((b - r) / delta + 2) / 6;
    } else {
      h = ((r - g) / delta + 4) / 6;
    }

    return HSLColor(h * 360, s, l, color.alpha / 255.0);
  }

  /// Set alpha channel of a color
  static Color withAlpha(Color color, int alpha) {
    return Color.fromRGBA(
      color.red,
      color.green,
      color.blue,
      alpha.clamp(0, 255),
    );
  }

  /// Parse a hex color string (e.g., "#FF0000" or "#FF0000FF")
  /// Supports both RGB and RGBA formats
  static Color parseHexColor(String hexString) {
    if (!hexString.startsWith('#')) {
      throw ArgumentError('Hex color must start with #');
    }

    if (hexString.length != 7 && hexString.length != 9) {
      throw ArgumentError('Hex color must be #RRGGBB or #RRGGBBAA format');
    }

    return Color.fromRGBA(
      int.parse(hexString.substring(1, 3), radix: 16),
      int.parse(hexString.substring(3, 5), radix: 16),
      int.parse(hexString.substring(5, 7), radix: 16),
      hexString.length > 7
          ? int.parse(hexString.substring(7, 9), radix: 16)
          : 255,
    );
  }

  /// Linearly interpolates between two colors in RGB space
  static Color lerpRgb(Color a, Color b, double t) {
    t = t.clamp(0.0, 1.0);
    return Color.fromARGB(
      MathUtils.lerp(a.alpha.toDouble(), b.alpha.toDouble(), t).round(),
      MathUtils.lerp(a.red.toDouble(), b.red.toDouble(), t).round(),
      MathUtils.lerp(a.green.toDouble(), b.green.toDouble(), t).round(),
      MathUtils.lerp(a.blue.toDouble(), b.blue.toDouble(), t).round(),
    );
  }

  /// Alpha blend two colors (Porter-Duff over operation)
  static Color alphaBlend(Color source, Color destination) {
    if (source.alpha == 0) return destination;
    if (source.alpha == 255) return source;
    if (destination.alpha == 0) return source;

    final srcA = source.alpha / 255.0;
    final dstA = destination.alpha / 255.0;
    final outA = srcA + dstA * (1 - srcA);

    if (outA == 0) return Color.transparent;

    final outR =
        (source.red * srcA + destination.red * dstA * (1 - srcA)) / outA;
    final outG =
        (source.green * srcA + destination.green * dstA * (1 - srcA)) / outA;
    final outB =
        (source.blue * srcA + destination.blue * dstA * (1 - srcA)) / outA;

    return Color.fromRGBA(
      outR.round().clamp(0, 255),
      outG.round().clamp(0, 255),
      outB.round().clamp(0, 255),
      (outA * 255).round().clamp(0, 255),
    );
  }

  /// Bilinear interpolation between four colors
  /// Takes the four corner colors (c00, c10, c01, c11) and interpolation factors (fx, fy)
  /// and returns the interpolated color
  static Color bilerpColor(
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

  /// Convert HSL to RGB
  /// Used primarily by examples and tests for color generation
  static Color hslToRgb(HSLColor hsl) {
    final h = hsl.hue / 360;
    final s = hsl.saturation;
    final l = hsl.lightness;

    if (s == 0) {
      // Achromatic
      final gray = (l * 255).round();
      return Color.fromRGBA(gray, gray, gray, (hsl.alpha * 255).round());
    }

    double hue2rgb(double p, double q, double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;

    final r = hue2rgb(p, q, h + 1 / 3);
    final g = hue2rgb(p, q, h);
    final b = hue2rgb(p, q, h - 1 / 3);

    return Color.fromRGBA(
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
      (hsl.alpha * 255).round(),
    );
  }
}

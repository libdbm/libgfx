import 'dart:math' as math;

import '../color/color.dart';
import '../color/color_utils.dart';
import '../graphics_state.dart';
import '../utils/math_utils.dart';

/// Blend modes implementation combining separable and Porter-Duff modes
/// This class provides fast integer-based blending operations for all blend modes
class BlendModes {
  static int _interpolate(int a, int b, int alpha) {
    return a + MathUtils.mul255(b - a, alpha);
  }

  /// Main blend function that applies the specified blend mode
  static Color blend(Color source, Color destination, BlendMode mode) {
    switch (mode) {
      // Porter-Duff compositing modes
      case BlendMode.clear:
        return clear(source, destination);
      case BlendMode.src:
        return source;
      case BlendMode.dst:
        return destination;
      case BlendMode.srcOver:
        return srcOver(source, destination);
      case BlendMode.dstOver:
        return dstOver(source, destination);
      case BlendMode.srcIn:
        return srcIn(source, destination);
      case BlendMode.dstIn:
        return dstIn(source, destination);
      case BlendMode.srcOut:
        return srcOut(source, destination);
      case BlendMode.dstOut:
        return dstOut(source, destination);
      case BlendMode.srcAtop:
        return srcAtop(source, destination);
      case BlendMode.dstAtop:
        return dstAtop(source, destination);
      case BlendMode.xor:
        return xorMode(source, destination);

      // Separable blend modes
      case BlendMode.add:
        return add(source, destination);
      case BlendMode.multiply:
        return multiply(source, destination);
      case BlendMode.screen:
        return screen(source, destination);
      case BlendMode.overlay:
        return overlay(source, destination);
      case BlendMode.darken:
        return darken(source, destination);
      case BlendMode.lighten:
        return lighten(source, destination);
      case BlendMode.colorDodge:
        return colorDodge(source, destination);
      case BlendMode.colorBurn:
        return colorBurn(source, destination);
      case BlendMode.hardLight:
        return hardLight(source, destination);
      case BlendMode.softLight:
        return softLight(source, destination);
      case BlendMode.difference:
        return difference(source, destination);
      case BlendMode.exclusion:
        return exclusion(source, destination);
    }
  }

  static Color clear(Color source, Color destination) {
    return const Color(0x00000000);
  }

  static Color srcOver(Color source, Color destination) {
    final sa = source.alpha;
    if (sa == 0) return destination;
    if (sa == 255) return source;

    final da = destination.alpha;
    final inverseSa = 255 - sa;

    // alpha = sa + da * (1 - sa)
    final alpha = sa + MathUtils.mul255(da, inverseSa);
    if (alpha == 0) return const Color(0x00000000);

    // Premultiply colors
    final src = ColorUtils.premultiply(source);
    final dst = ColorUtils.premultiply(destination);

    // Composite: src + dst * (1 - sa)
    final red = src.r + MathUtils.mul255(dst.r, inverseSa);
    final green = src.g + MathUtils.mul255(dst.g, inverseSa);
    final blue = src.b + MathUtils.mul255(dst.b, inverseSa);

    return ColorUtils.unpremultiply(red, green, blue, alpha);
  }

  static Color dstOver(Color source, Color destination) {
    final da = destination.alpha;
    if (da == 255) return destination;
    if (da == 0) return source;

    final sa = source.alpha;
    final inverseDa = 255 - da;

    // alpha = da + sa * (1 - da)
    final alpha = da + MathUtils.mul255(sa, inverseDa);
    if (alpha == 0) return const Color(0x00000000);

    // Premultiply colors
    final src = ColorUtils.premultiply(source);
    final dst = ColorUtils.premultiply(destination);

    // Composite: dst + src * (1 - da)
    final red = dst.r + MathUtils.mul255(src.r, inverseDa);
    final green = dst.g + MathUtils.mul255(src.g, inverseDa);
    final blue = dst.b + MathUtils.mul255(src.b, inverseDa);

    return ColorUtils.unpremultiply(red, green, blue, alpha);
  }

  static Color srcIn(Color source, Color destination) {
    final alpha = MathUtils.mul255(source.alpha, destination.alpha);
    return Color.fromARGB(alpha, source.red, source.green, source.blue);
  }

  static Color dstIn(Color source, Color destination) {
    final alpha = MathUtils.mul255(destination.alpha, source.alpha);
    return Color.fromARGB(
      alpha,
      destination.red,
      destination.green,
      destination.blue,
    );
  }

  static Color srcOut(Color source, Color destination) {
    final alpha = MathUtils.mul255(source.alpha, 255 - destination.alpha);
    return Color.fromARGB(alpha, source.red, source.green, source.blue);
  }

  static Color dstOut(Color source, Color destination) {
    final alpha = MathUtils.mul255(destination.alpha, 255 - source.alpha);
    return Color.fromARGB(
      alpha,
      destination.red,
      destination.green,
      destination.blue,
    );
  }

  static Color srcAtop(Color source, Color destination) {
    final sa = source.alpha;
    final da = destination.alpha;

    if (da == 0) return const Color(0x00000000);

    final red = _interpolate(destination.red, source.red, sa);
    final green = _interpolate(destination.green, source.green, sa);
    final blue = _interpolate(destination.blue, source.blue, sa);

    return Color.fromARGB(da, red, green, blue);
  }

  static Color dstAtop(Color source, Color destination) {
    final sa = source.alpha;
    final da = destination.alpha;

    if (sa == 0) return const Color(0x00000000);

    final red = _interpolate(source.red, destination.red, da);
    final green = _interpolate(source.green, destination.green, da);
    final blue = _interpolate(source.blue, destination.blue, da);

    return Color.fromARGB(sa, red, green, blue);
  }

  static Color xorMode(Color source, Color destination) {
    final sa = source.alpha;
    final da = destination.alpha;
    final inverseSa = 255 - sa;
    final inverseDa = 255 - da;

    // alpha = sa * (1 - da) + da * (1 - sa)
    final alpha =
        MathUtils.mul255(sa, inverseDa) + MathUtils.mul255(da, inverseSa);
    if (alpha == 0) return const Color(0x00000000);

    // Premultiply colors
    final src = ColorUtils.premultiply(source);
    final dst = ColorUtils.premultiply(destination);

    // Composite: src * (1 - da) + dst * (1 - sa)
    final red =
        MathUtils.mul255(src.r, inverseDa) + MathUtils.mul255(dst.r, inverseSa);
    final green =
        MathUtils.mul255(src.g, inverseDa) + MathUtils.mul255(dst.g, inverseSa);
    final blue =
        MathUtils.mul255(src.b, inverseDa) + MathUtils.mul255(dst.b, inverseSa);

    return ColorUtils.unpremultiply(red, green, blue, alpha);
  }

  /// Generic separable blend mode application
  static Color applySeparableBlend(
    Color source,
    Color destination,
    final int Function(int, int) operation,
  ) {
    final sa = source.alpha;
    final da = destination.alpha;

    if (sa == 0) return destination;
    if (da == 0) return source;

    // Calculate output alpha
    final inverseSa = 255 - sa;
    final alpha = sa + MathUtils.mul255(da, inverseSa);

    if (alpha == 0) return const Color(0x00000000);

    final red = _channel(source.red, destination.red, sa, da, alpha, operation);
    final green = _channel(
      source.green,
      destination.green,
      sa,
      da,
      alpha,
      operation,
    );
    final blue = _channel(
      source.blue,
      destination.blue,
      sa,
      da,
      alpha,
      operation,
    );

    return Color.fromARGB(alpha, red, green, blue);
  }

  static int _channel(
    int sc,
    int dc,
    int sa,
    int da,
    final int alpha,
    final int Function(int, int) operation,
  ) {
    final inverseSa = 255 - sa;
    final inverseDa = 255 - da;

    // Apply blend function
    final blended = operation(sc, dc);

    // Composite with alpha
    final result =
        MathUtils.mul255(MathUtils.mul255(blended, sa), da) +
        MathUtils.mul255(MathUtils.mul255(sc, sa), inverseDa) +
        MathUtils.mul255(MathUtils.mul255(dc, da), inverseSa);

    // Unpremultiply
    final inverse = (255 * 255) ~/ alpha;
    return ((result * inverse + 127) >> 8).clamp(0, 255);
  }

  static int multiplyFunc(int s, int d) => MathUtils.mul255(s, d);

  static int screenFunc(int s, int d) =>
      255 - MathUtils.mul255(255 - s, 255 - d);

  static int overlayFunc(int s, int d) {
    if (d < 128) {
      return MathUtils.mul255(s, d << 1);
    } else {
      return 255 - MathUtils.mul255(255 - s, (255 - d) << 1);
    }
  }

  static int hardLightFunc(int s, int d) {
    if (s < 128) {
      return MathUtils.mul255(d, s << 1);
    } else {
      return 255 - MathUtils.mul255(255 - d, (255 - s) << 1);
    }
  }

  /// Soft light as defined by W3C Compositing and Blending Level 1, computed
  /// on normalized channels.
  static int softLightFunc(int s, int d) {
    final source = s / 255;
    final backdrop = d / 255;
    final double result;
    if (source <= 0.5) {
      result = backdrop - (1 - 2 * source) * backdrop * (1 - backdrop);
    } else {
      final lift = backdrop <= 0.25
          ? ((16 * backdrop - 12) * backdrop + 4) * backdrop
          : math.sqrt(backdrop);
      result = backdrop + (2 * source - 1) * (lift - backdrop);
    }
    return (result * 255).round().clamp(0, 255);
  }

  static int colorDodgeFunc(int s, int d) {
    if (s == 255) return 255;
    final result = (d * 255) ~/ (255 - s);
    return result.clamp(0, 255);
  }

  static int colorBurnFunc(int s, int d) {
    if (s == 0) return 0;
    final result = 255 - ((255 - d) * 255) ~/ s;
    return result.clamp(0, 255);
  }

  static int darkenFunc(int s, int d) => math.min(s, d);

  static int lightenFunc(int s, int d) => math.max(s, d);

  static int differenceFunc(int s, int d) => (s - d).abs();

  static int exclusionFunc(int s, int d) => s + d - MathUtils.mul255(s, d << 1);

  static Color multiply(Color source, Color destination) {
    return applySeparableBlend(source, destination, multiplyFunc);
  }

  static Color screen(Color source, Color destination) {
    return applySeparableBlend(source, destination, screenFunc);
  }

  static Color overlay(Color source, Color destination) {
    return applySeparableBlend(source, destination, overlayFunc);
  }

  static Color hardLight(Color source, Color destination) {
    return applySeparableBlend(source, destination, hardLightFunc);
  }

  static Color softLight(Color source, Color destination) {
    return applySeparableBlend(source, destination, softLightFunc);
  }

  static Color colorDodge(Color source, Color destination) {
    return applySeparableBlend(source, destination, colorDodgeFunc);
  }

  static Color colorBurn(Color source, Color destination) {
    return applySeparableBlend(source, destination, colorBurnFunc);
  }

  static Color darken(Color source, Color destination) {
    return applySeparableBlend(source, destination, darkenFunc);
  }

  static Color lighten(Color source, Color destination) {
    return applySeparableBlend(source, destination, lightenFunc);
  }

  static Color difference(Color source, Color destination) {
    return applySeparableBlend(source, destination, differenceFunc);
  }

  static Color exclusion(Color source, Color destination) {
    return applySeparableBlend(source, destination, exclusionFunc);
  }

  static Color add(Color source, Color destination) {
    final sa = source.alpha;
    final da = destination.alpha;
    final inverseSa = 255 - sa;

    final alpha = math.min(255, sa + MathUtils.mul255(da, inverseSa));

    if (alpha == 0) return const Color(0x00000000);

    final red = math.min(255, source.red + destination.red);
    final green = math.min(255, source.green + destination.green);
    final blue = math.min(255, source.blue + destination.blue);

    return Color.fromARGB(alpha, red, green, blue);
  }
}

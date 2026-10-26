import 'dart:math' as math;
import 'dart:typed_data';

import '../color/color_utils.dart';

import '../blending/blend_modes.dart';
import '../color/color.dart';
import '../errors.dart';
import '../graphics_state.dart';
import '../limits.dart';
import '../matrix.dart';
import '../paint.dart';
import '../point.dart';
import '../utils/math_utils.dart';

/// Simple bitmap class for both rendering and image manipulation.
/// Combines low-level rendering operations with high-level image transformations.
class Bitmap {
  final int width;
  final int height;
  late Uint32List _pixels;

  /// Create a bitmap with specified dimensions. Negative dimensions, or more
  /// pixels than the default [Limits.pixels], are programming errors and
  /// throw [ArgumentError] before anything is allocated.
  Bitmap(this.width, this.height) {
    if (width < 0 || height < 0) {
      throw ArgumentError(
        'Bitmap dimensions must not be negative: '
        '${width}x$height',
      );
    }
    if (width * height > const Limits().pixels) {
      throw ArgumentError(
        'Bitmap of ${width}x$height exceeds '
        '${const Limits().pixels} pixels',
      );
    }
    _pixels = Uint32List(width * height);
  }

  /// Create a bitmap from existing pixel data
  factory Bitmap.fromPixels(int width, int height, Uint32List pixels) {
    if (pixels.length != width * height) {
      throw ConfigurationException(
        'Pixel buffer size mismatch: expected ${width * height}, got ${pixels.length}',
      );
    }
    final bitmap = Bitmap(width, height);
    bitmap._pixels = Uint32List.fromList(pixels);
    return bitmap;
  }

  /// Create an empty bitmap with specified dimensions
  factory Bitmap.empty(int width, int height) {
    return Bitmap(width, height);
  }

  /// Access to raw pixel data
  Uint32List get pixels => _pixels;

  /// Create a deep copy of this bitmap
  Bitmap clone() {
    return Bitmap.fromPixels(width, height, Uint32List.fromList(_pixels));
  }

  /// Set a pixel value using raw color value
  void plot(final int x, final int y, final Color color) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      _pixels[y * width + x] = color.value;
    }
  }

  /// Blend a pixel with the existing color using the specified blend mode;
  /// partial [coverage] (0-255) masks the blended result, as for spans
  void blend(
    int x,
    int y,
    Color color,
    final BlendMode mode, [
    final int coverage = 255,
  ]) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return;
    }

    final destination = Color(_pixels[y * width + x]);
    final blended = _blend(color, destination, mode);
    _pixels[y * width + x] = _cover(destination, blended, coverage).value;
  }

  /// Get pixel as Color object
  Color pixel(final int x, final int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return Color.transparent;
    }
    return Color(_pixels[y * width + x]);
  }

  /// Clear the bitmap with a solid color
  void clear(Color color) {
    _pixels.fillRange(0, _pixels.length, color.value);
  }

  /// Draw a horizontal span for rasterization
  void span(
    int x1,
    int x2,
    int y,
    Paint paint,
    Matrix2D inverse,
    BlendMode mode,
  ) {
    final start = math.max(0, x1);
    final end = math.min(width, x2);
    final offset = y * width;

    // Fast path for solid paint with srcOver
    if (paint is Color && mode == BlendMode.srcOver) {
      final color = paint;
      if (color.alpha == 255) {
        // Fully opaque - direct copy
        final value = color.value;
        for (int x = start; x < end; x++) {
          _pixels[offset + x] = value;
        }
      } else if (color.alpha > 0) {
        // Semi-transparent - blend once
        for (int x = start; x < end; x++) {
          final destination = Color(_pixels[offset + x]);
          final blended = BlendModes.srcOver(color, destination);
          _pixels[offset + x] = blended.value;
        }
      }
      return;
    }

    // Optimized path for LinearGradient
    if (paint is LinearGradient) {
      final gradient = paint;
      final row = y.toDouble();
      var t = gradient.offset(start.toDouble(), row, inverse);
      final step = gradient.step(inverse);

      for (int x = start; x < end; x++) {
        final wrapped = gradient.wrap(t);
        final source = gradient.lookup(wrapped);
        final destination = Color(_pixels[offset + x]);
        final result = _blend(source, destination, mode);
        _pixels[offset + x] = result.value;
        t += step;
      }
      return;
    }

    // Slow path for other gradients and patterns
    for (int x = start; x < end; x++) {
      final source = paint.sample(Point(x.toDouble(), y.toDouble()), inverse);
      final destination = Color(_pixels[offset + x]);
      final result = _blend(source, destination, mode);
      _pixels[offset + x] = result.value;
    }
  }

  /// Draw a horizontal span with coverage for anti-aliasing. [alpha] scales
  /// the source before blending; [coverage] masks the blended result.
  void shade(
    int x,
    int length,
    int y,
    int coverage,
    Paint paint,
    Matrix2D inverse,
    BlendMode mode, {
    double alpha = 1.0,
  }) {
    if (y < 0 || y >= height) return;
    if (coverage <= 0) return;

    final start = math.max(0, x);
    final end = math.min(width, x + length);
    if (start >= end) return;

    final offset = y * width;
    final fraction = coverage / 255.0;

    // Fast path for solid paint with srcOver
    if (paint is Color && mode == BlendMode.srcOver) {
      final base = paint;
      final covered = Color.fromARGB(
        (base.alpha * fraction * alpha).round(),
        base.red,
        base.green,
        base.blue,
      );

      for (int column = start; column < end; column++) {
        final destination = Color(_pixels[offset + column]);
        final blended = BlendModes.srcOver(covered, destination);
        _pixels[offset + column] = blended.value;
      }
      return;
    }

    // Slow path for gradients, patterns and other blend modes: [alpha]
    // scales the source, coverage masks the blended result
    for (int column = start; column < end; column++) {
      final sampled = paint.sample(
        Point(column.toDouble(), y.toDouble()),
        inverse,
      );
      final source = alpha < 1.0
          ? ColorUtils.opacity(sampled, (sampled.alpha * alpha).round())
          : sampled;

      final destination = Color(_pixels[offset + column]);
      final result = _cover(
        destination,
        _blend(source, destination, mode),
        coverage,
      );
      _pixels[offset + column] = result.value;
    }
  }

  /// Moves [destination] towards [blended] by [coverage] (0-255), interpolating in
  /// premultiplied space, so partial coverage masks the result of every blend
  /// mode rather than only scaling the source alpha.
  static Color _cover(final Color destination, Color blended, int coverage) {
    if (coverage >= 255) return blended;
    final from = ColorUtils.premultiply(destination);
    final to = ColorUtils.premultiply(blended);
    int mix(int start, int end) =>
        start + ((end - start) * coverage / 255).round();
    return ColorUtils.unpremultiply(
      mix(from.red, to.red),
      mix(from.green, to.green),
      mix(from.blue, to.blue),
      mix(from.alpha, to.alpha),
    );
  }

  Color _blend(Color source, final Color destination, BlendMode mode) {
    return BlendModes.blend(source, destination, mode);
  }

  /// Optimized rectangle fill for solid colors
  void fill(int x, int y, int columns, int rows, Color color, BlendMode mode) {
    // Clip to bitmap bounds
    if (x >= width || y >= height || x + columns <= 0 || y + rows <= 0) return;

    final x1 = math.max(0, x);
    final y1 = math.max(0, y);
    final x2 = math.min(width, x + columns);
    final y2 = math.min(height, y + rows);

    if (x1 >= x2 || y1 >= y2) return;

    final count = x2 - x1;

    // Fast path for opaque srcOver - direct write
    if (mode == BlendMode.srcOver && color.alpha == 255) {
      final value = color.value;
      for (int row = y1; row < y2; row++) {
        final offset = row * width + x1;
        for (int column = 0; column < count; column++) {
          _pixels[offset + column] = value;
        }
      }
      return;
    }

    // Semi-transparent or other blend modes
    for (int row = y1; row < y2; row++) {
      final offset = row * width + x1;
      for (int column = 0; column < count; column++) {
        final index = offset + column;
        final destination = Color(_pixels[index]);
        final blended = _blend(color, destination, mode);
        _pixels[index] = blended.value;
      }
    }
  }

  // ===== High-level image manipulation operations =====

  /// Scale bitmap using bilinear interpolation
  Bitmap scale(int columns, int rows) {
    if (columns == width && rows == height) {
      return this;
    }

    final result = Bitmap.empty(columns, rows);
    final xRatio = width / columns;
    final yRatio = height / rows;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < columns; x++) {
        final sourceX = x * xRatio;
        final sourceY = y * yRatio;

        // Bilinear interpolation
        final x0 = sourceX.floor();
        final x1 = (x0 + 1).clamp(0, width - 1);
        final y0 = sourceY.floor();
        final y1 = (y0 + 1).clamp(0, height - 1);

        final fx = sourceX - x0;
        final fy = sourceY - y0;

        final c00 = pixel(x0, y0);
        final c10 = pixel(x1, y0);
        final c01 = pixel(x0, y1);
        final c11 = pixel(x1, y1);

        // Interpolate colors using integer math
        final r = MathUtils.lerpInt(
          MathUtils.lerpInt(c00.red, c10.red, fx),
          MathUtils.lerpInt(c01.red, c11.red, fx),
          fy,
        );
        final g = MathUtils.lerpInt(
          MathUtils.lerpInt(c00.green, c10.green, fx),
          MathUtils.lerpInt(c01.green, c11.green, fx),
          fy,
        );
        final b = MathUtils.lerpInt(
          MathUtils.lerpInt(c00.blue, c10.blue, fx),
          MathUtils.lerpInt(c01.blue, c11.blue, fx),
          fy,
        );
        final a = MathUtils.lerpInt(
          MathUtils.lerpInt(c00.alpha, c10.alpha, fx),
          MathUtils.lerpInt(c01.alpha, c11.alpha, fx),
          fy,
        );

        result.plot(x, y, Color.fromRGBA(r, g, b, a));
      }
    }

    return result;
  }

  /// Crop a region from the bitmap
  Bitmap crop(int x, int y, int columns, int rows) {
    final result = Bitmap.empty(columns, rows);

    for (int dy = 0; dy < rows; dy++) {
      for (int dx = 0; dx < columns; dx++) {
        result.plot(dx, dy, pixel(x + dx, y + dy));
      }
    }

    return result;
  }

  /// Flip bitmap horizontally
  Bitmap mirror() {
    final result = Bitmap.empty(width, height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        result.plot(width - 1 - x, y, pixel(x, y));
      }
    }

    return result;
  }

  /// Flip bitmap vertically
  Bitmap flip() {
    final result = Bitmap.empty(width, height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        result.plot(x, height - 1 - y, pixel(x, y));
      }
    }

    return result;
  }

  /// Rotate bitmap by 90 degrees clockwise
  Bitmap rotate90() {
    final result = Bitmap.empty(height, width);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        result.plot(height - 1 - y, x, pixel(x, y));
      }
    }

    return result;
  }

  /// Apply opacity to all pixels
  Bitmap fade(double opacity) {
    final result = Bitmap.empty(width, height);
    final alpha = (opacity * 255).clamp(0, 255);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final color = pixel(x, y);
        final faded = (color.alpha * alpha ~/ 255);
        result.plot(x, y, ColorUtils.opacity(color, faded));
      }
    }

    return result;
  }

  /// Rotate bitmap by 180 degrees
  Bitmap rotate180() {
    final result = Bitmap.empty(width, height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        result.plot(width - 1 - x, height - 1 - y, pixel(x, y));
      }
    }

    return result;
  }

  /// Rotate bitmap by 270 degrees clockwise (90 degrees counter-clockwise)
  Bitmap rotate270() {
    final result = Bitmap.empty(height, width);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        result.plot(y, width - 1 - x, pixel(x, y));
      }
    }

    return result;
  }

  /// Rotate bitmap by arbitrary angle (in radians) with optional background color
  Bitmap rotate(
    final double angle, [
    final Color background = Color.transparent,
  ]) {
    // Calculate bounding box for rotated image
    final cos = math.cos(angle).abs();
    final sin = math.sin(angle).abs();
    final newWidth = (width * cos + height * sin).ceil();
    final newHeight = (width * sin + height * cos).ceil();

    final result = Bitmap.empty(newWidth, newHeight);

    // Fill with background color
    for (int i = 0; i < result._pixels.length; i++) {
      result._pixels[i] = background.value;
    }

    // Center points
    final centerX = width / 2.0;
    final centerY = height / 2.0;
    final newCenterX = newWidth / 2.0;
    final newCenterY = newHeight / 2.0;

    // Rotation matrix (inverse for sampling)
    final cosine = math.cos(-angle);
    final sine = math.sin(-angle);

    for (int y = 0; y < newHeight; y++) {
      for (int x = 0; x < newWidth; x++) {
        // Translate to center
        final dx = x - newCenterX;
        final dy = y - newCenterY;

        // Apply inverse rotation
        final sourceX = dx * cosine - dy * sine + centerX;
        final sourceY = dx * sine + dy * cosine + centerY;

        // Bilinear interpolation for smooth rotation
        if (sourceX >= 0 &&
            sourceX < width - 1 &&
            sourceY >= 0 &&
            sourceY < height - 1) {
          final x0 = sourceX.floor();
          final y0 = sourceY.floor();
          final x1 = x0 + 1;
          final y1 = y0 + 1;

          final fx = sourceX - x0;
          final fy = sourceY - y0;

          final c00 = pixel(x0, y0);
          final c10 = pixel(x1, y0);
          final c01 = pixel(x0, y1);
          final c11 = pixel(x1, y1);

          // Bilinear interpolation
          final interpolated = ColorUtils.bilerp(c00, c10, c01, c11, fx, fy);
          result.plot(x, y, interpolated);
        } else if (sourceX >= 0 &&
            sourceX < width &&
            sourceY >= 0 &&
            sourceY < height) {
          // Edge case: use nearest neighbor
          result.plot(x, y, pixel(sourceX.round(), sourceY.round()));
        }
      }
    }

    return result;
  }
}

// Type alias for compatibility with existing code that uses Image
typedef Image = Bitmap;

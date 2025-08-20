import 'dart:math' as math;
import 'dart:typed_data';

import '../color/color_utils.dart';

import '../blending/blend_modes.dart';
import '../color/color.dart';
import '../errors.dart';
import '../graphics_state.dart';
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

  /// Create a bitmap with specified dimensions
  Bitmap(this.width, this.height) {
    // Let Uint32List throw RangeError for negative dimensions naturally
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
  void setPixel(int x, int y, Color color) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      _pixels[y * width + x] = color.value;
    }
  }

  /// Blend a pixel with the existing color using the specified blend mode
  void blendPixel(int x, int y, Color color, BlendMode blendMode) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return;
    }

    final dstColor = Color(_pixels[y * width + x]);
    final blended = _blend(color, dstColor, blendMode);
    _pixels[y * width + x] = blended.value;
  }

  /// Get pixel as Color object
  Color getPixel(int x, int y) {
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
  void drawHorizontalSpan(
    int x1,
    int x2,
    int y,
    Paint paint,
    Matrix2D inverseTransform,
    BlendMode blendMode,
  ) {
    final startX = math.max(0, x1);
    final endX = math.min(width, x2);
    final int yOffset = y * width;

    for (int x = startX; x < endX; x++) {
      final sourceColor = paint.getColorAt(
        Point(x.toDouble(), y.toDouble()),
        inverseTransform,
      );
      final destColor = Color(_pixels[yOffset + x]);
      final finalColor = _blend(sourceColor, destColor, blendMode);
      _pixels[yOffset + x] = finalColor.value;
    }
  }

  /// Draw a horizontal span with coverage for anti-aliasing
  void drawAntiAliasedSpan(
    int x,
    int length,
    int y,
    int coverage,
    Paint paint,
    Matrix2D inverseTransform,
    BlendMode blendMode,
  ) {
    if (y < 0 || y >= height) return;
    if (coverage <= 0) return;

    final startX = math.max(0, x);
    final endX = math.min(width, x + length);
    if (startX >= endX) return;

    final int yOffset = y * width;
    final coverageNorm = coverage / 255.0;

    for (int px = startX; px < endX; px++) {
      final sourceColor = paint.getColorAt(
        Point(px.toDouble(), y.toDouble()),
        inverseTransform,
      );

      // Apply coverage to source alpha
      final coveredColor = Color.fromARGB(
        (sourceColor.alpha * coverageNorm).round(),
        sourceColor.red,
        sourceColor.green,
        sourceColor.blue,
      );

      final destColor = Color(_pixels[yOffset + px]);
      final finalColor = _blend(coveredColor, destColor, blendMode);
      _pixels[yOffset + px] = finalColor.value;
    }
  }

  Color _blend(Color source, Color dest, BlendMode mode) {
    return BlendModes.blend(source, dest, mode);
  }

  // ===== High-level image manipulation operations =====

  /// Scale bitmap using bilinear interpolation
  Bitmap scale(int newWidth, int newHeight) {
    if (newWidth == width && newHeight == height) {
      return this;
    }

    final result = Bitmap.empty(newWidth, newHeight);
    final xRatio = width / newWidth;
    final yRatio = height / newHeight;

    for (int y = 0; y < newHeight; y++) {
      for (int x = 0; x < newWidth; x++) {
        final srcX = x * xRatio;
        final srcY = y * yRatio;

        // Bilinear interpolation
        final x0 = srcX.floor();
        final x1 = (x0 + 1).clamp(0, width - 1);
        final y0 = srcY.floor();
        final y1 = (y0 + 1).clamp(0, height - 1);

        final fx = srcX - x0;
        final fy = srcY - y0;

        final c00 = getPixel(x0, y0);
        final c10 = getPixel(x1, y0);
        final c01 = getPixel(x0, y1);
        final c11 = getPixel(x1, y1);

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

        result.setPixel(x, y, Color.fromRGBA(r, g, b, a));
      }
    }

    return result;
  }

  /// Crop a region from the bitmap
  Bitmap crop(int x, int y, int cropWidth, int cropHeight) {
    final result = Bitmap.empty(cropWidth, cropHeight);

    for (int dy = 0; dy < cropHeight; dy++) {
      for (int dx = 0; dx < cropWidth; dx++) {
        result.setPixel(dx, dy, getPixel(x + dx, y + dy));
      }
    }

    return result;
  }

  /// Flip bitmap horizontally
  Bitmap flipHorizontal() {
    final result = Bitmap.empty(width, height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        result.setPixel(width - 1 - x, y, getPixel(x, y));
      }
    }

    return result;
  }

  /// Flip bitmap vertically
  Bitmap flipVertical() {
    final result = Bitmap.empty(width, height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        result.setPixel(x, height - 1 - y, getPixel(x, y));
      }
    }

    return result;
  }

  /// Rotate bitmap by 90 degrees clockwise
  Bitmap rotate90() {
    final result = Bitmap.empty(height, width);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        result.setPixel(height - 1 - y, x, getPixel(x, y));
      }
    }

    return result;
  }

  /// Apply opacity to all pixels
  Bitmap withOpacity(double opacity) {
    final result = Bitmap.empty(width, height);
    final alpha = (opacity * 255).clamp(0, 255);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final color = getPixel(x, y);
        final newAlpha = (color.alpha * alpha ~/ 255);
        result.setPixel(x, y, ColorUtils.withAlpha(color, newAlpha));
      }
    }

    return result;
  }

  /// Rotate bitmap by 180 degrees
  Bitmap rotate180() {
    final result = Bitmap.empty(width, height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        result.setPixel(width - 1 - x, height - 1 - y, getPixel(x, y));
      }
    }

    return result;
  }

  /// Rotate bitmap by 270 degrees clockwise (90 degrees counter-clockwise)
  Bitmap rotate270() {
    final result = Bitmap.empty(height, width);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        result.setPixel(y, width - 1 - x, getPixel(x, y));
      }
    }

    return result;
  }

  /// Rotate bitmap by arbitrary angle (in radians) with optional background color
  Bitmap rotateAngle(double angleRadians, [Color? backgroundColor]) {
    backgroundColor ??= const Color(0x00000000); // Transparent by default

    // Calculate bounding box for rotated image
    final cos = math.cos(angleRadians).abs();
    final sin = math.sin(angleRadians).abs();
    final newWidth = (width * cos + height * sin).ceil();
    final newHeight = (width * sin + height * cos).ceil();

    final result = Bitmap.empty(newWidth, newHeight);

    // Fill with background color
    for (int i = 0; i < result._pixels.length; i++) {
      result._pixels[i] = backgroundColor.value;
    }

    // Center points
    final centerX = width / 2.0;
    final centerY = height / 2.0;
    final newCenterX = newWidth / 2.0;
    final newCenterY = newHeight / 2.0;

    // Rotation matrix (inverse for sampling)
    final cosAngle = math.cos(-angleRadians);
    final sinAngle = math.sin(-angleRadians);

    for (int y = 0; y < newHeight; y++) {
      for (int x = 0; x < newWidth; x++) {
        // Translate to center
        final dx = x - newCenterX;
        final dy = y - newCenterY;

        // Apply inverse rotation
        final srcX = dx * cosAngle - dy * sinAngle + centerX;
        final srcY = dx * sinAngle + dy * cosAngle + centerY;

        // Bilinear interpolation for smooth rotation
        if (srcX >= 0 && srcX < width - 1 && srcY >= 0 && srcY < height - 1) {
          final x0 = srcX.floor();
          final y0 = srcY.floor();
          final x1 = x0 + 1;
          final y1 = y0 + 1;

          final fx = srcX - x0;
          final fy = srcY - y0;

          final c00 = getPixel(x0, y0);
          final c10 = getPixel(x1, y0);
          final c01 = getPixel(x0, y1);
          final c11 = getPixel(x1, y1);

          // Bilinear interpolation
          final interpolatedColor = ColorUtils.bilerpColor(
            c00,
            c10,
            c01,
            c11,
            fx,
            fy,
          );
          result.setPixel(x, y, interpolatedColor);
        } else if (srcX >= 0 && srcX < width && srcY >= 0 && srcY < height) {
          // Edge case: use nearest neighbor
          result.setPixel(x, y, getPixel(srcX.round(), srcY.round()));
        }
      }
    }

    return result;
  }
}

// Type alias for compatibility with existing code that uses Image
typedef Image = Bitmap;

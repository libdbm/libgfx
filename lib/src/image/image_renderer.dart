import 'dart:math' as math;

import 'bitmap.dart';
import '../color/color.dart';
import '../color/color_utils.dart';
import '../graphics_state.dart';
import '../blending/blend_modes.dart';
import '../matrix.dart';
import '../point.dart';
import '../rectangle.dart';

/// Image filtering modes
enum ImageFilter {
  nearest, // Nearest neighbor (fast, pixelated)
  bilinear, // Bilinear interpolation (smooth)
  bicubic, // Bicubic interpolation (smoother, slower)
}

/// Image rendering with advanced features
class ImageRenderer {
  /// Render an image to a bitmap with transformation
  static void renderImage(
    Bitmap target,
    Bitmap source,
    Matrix2D transform,
    GraphicsState state, {
    ImageFilter filter = ImageFilter.bilinear,
    double opacity = 1.0,
    Rectangle<double>? sourceRect,
  }) {
    // Calculate inverse transform for sampling
    final inverseTransform = Matrix2D.copy(transform)..invert();

    // Calculate bounding box of transformed image
    final rect =
        sourceRect ??
        Rectangle<double>(
          0,
          0,
          source.width.toDouble(),
          source.height.toDouble(),
        );

    final rectLeft = rect.left.toDouble();
    final rectTop = rect.top.toDouble();
    final rectRight = rect.right.toDouble();
    final rectBottom = rect.bottom.toDouble();

    final corners = [
      Point(rectLeft, rectTop),
      Point(rectRight, rectTop),
      Point(rectRight, rectBottom),
      Point(rectLeft, rectBottom),
    ];

    final transformedCorners = corners
        .map((p) => transform.transform(p))
        .toList();

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final corner in transformedCorners) {
      minX = math.min(minX, corner.x);
      minY = math.min(minY, corner.y);
      maxX = math.max(maxX, corner.x);
      maxY = math.max(maxY, corner.y);
    }

    const edgePadding = 0.5;
    minX -= edgePadding;
    minY -= edgePadding;
    maxX += edgePadding;
    maxY += edgePadding;

    // Clamp to target bounds
    final startX = minX.floor().clamp(0, target.width - 1);
    final startY = minY.floor().clamp(0, target.height - 1);
    final endX = maxX.ceil().clamp(0, target.width - 1);
    final endY = maxY.ceil().clamp(0, target.height - 1);

    if (startX > endX || startY > endY) {
      return;
    }

    final clipRegion = state.clipRegion;
    final graphicsHeight = target.height;

    // Precompute inverse matrix components for the hot loop.
    final invA = inverseTransform.a;
    final invB = inverseTransform.b;
    final invC = inverseTransform.c;
    final invD = inverseTransform.d;
    final invTx = inverseTransform.tx;
    final invTy = inverseTransform.ty;

    // Render pixels
    for (int y = startY; y <= endY; y++) {
      final clipY = clipRegion != null ? graphicsHeight - 1 - y : 0;
      if (clipRegion != null && !clipRegion.spansByY.containsKey(clipY)) {
        continue;
      }

      final inputY = y + 0.5;
      final baseX = invC * inputY + invTx;
      final baseY = invD * inputY + invTy;
      final stepX = invA;
      final stepY = invB;
      var srcX = invA * (startX + 0.5) + baseX;
      var srcY = invB * (startX + 0.5) + baseY;

      for (int x = startX; x <= endX; x++) {
        if (clipRegion != null && !clipRegion.contains(x, clipY)) {
          srcX += stepX;
          srcY += stepY;
          continue;
        }

        var sampleX = srcX;
        if (sampleX < rectLeft) {
          sampleX = rectLeft;
        } else if (sampleX > rectRight - 1e-6) {
          sampleX = rectRight - 1e-6;
        }

        var sampleY = srcY;
        if (sampleY < rectTop) {
          sampleY = rectTop;
        } else if (sampleY > rectBottom - 1e-6) {
          sampleY = rectBottom - 1e-6;
        }

        // Sample source image
        var fetchX = sampleX;
        var fetchY = sampleY;
        if (filter == ImageFilter.nearest) {
          final biasY = invD == 0 ? 0.0 : (invD > 0 ? 1e-6 : -1e-6);
          fetchY -= biasY;

          if (fetchY < rectTop) {
            fetchY = rectTop;
          } else if (fetchY > rectBottom - 1e-6) {
            fetchY = rectBottom - 1e-6;
          }
        }

        final sampledColor = _sampleImage(source, fetchX, fetchY, filter);

        if (sampledColor.alpha > 0) {
          // Apply opacity
          final finalAlpha = (sampledColor.alpha * opacity).round().clamp(
            0,
            255,
          );
          final color = Color.fromRGBA(
            sampledColor.red,
            sampledColor.green,
            sampledColor.blue,
            finalAlpha,
          );

          // Blend with target using current blend mode
          _blendPixel(target, x, y, color, state.blendMode);
        }

        srcX += stepX;
        srcY += stepY;
      }
    }
  }

  /// Sample image with different filtering modes
  static Color _sampleImage(
    Bitmap image,
    double x,
    double y,
    ImageFilter filter,
  ) {
    switch (filter) {
      case ImageFilter.nearest:
        return _nearestSample(image, x, y);
      case ImageFilter.bilinear:
        return _bilinearSample(image, x, y);
      case ImageFilter.bicubic:
        return _bicubicSample(image, x, y);
    }
  }

  /// Nearest neighbor sampling
  static Color _nearestSample(Bitmap image, double x, double y) {
    int clampIndex(int value, int min, int max) {
      if (value < min) return min;
      if (value > max) return max;
      return value;
    }

    if (!x.isFinite || !y.isFinite) {
      return Color.transparent;
    }

    final ix = clampIndex((x - 0.5).round(), 0, image.width - 1);
    final iy = clampIndex(y.round(), 0, image.height - 1);
    return image.getPixel(ix, iy);
  }

  /// Bilinear interpolation sampling
  static Color _bilinearSample(Bitmap image, double x, double y) {
    if (x < 0 || x >= image.width || y < 0 || y >= image.height) {
      return Color.transparent;
    }

    final x0 = x.floor().clamp(0, image.width - 1);
    final x1 = (x0 + 1).clamp(0, image.width - 1);
    final y0 = y.floor().clamp(0, image.height - 1);
    final y1 = (y0 + 1).clamp(0, image.height - 1);

    final fx = x - x0;
    final fy = y - y0;

    final c00 = image.getPixel(x0, y0);
    final c10 = image.getPixel(x1, y0);
    final c01 = image.getPixel(x0, y1);
    final c11 = image.getPixel(x1, y1);

    // Bilinear interpolation
    return ColorUtils.bilerpColor(c00, c10, c01, c11, fx, fy);
  }

  /// Bicubic interpolation sampling
  static Color _bicubicSample(Bitmap image, double x, double y) {
    if (x < 0 || x >= image.width || y < 0 || y >= image.height) {
      return Color.transparent;
    }

    final ix = x.floor();
    final iy = y.floor();
    final fx = x - ix;
    final fy = y - iy;

    // Get 4x4 neighborhood
    final colors = <List<Color>>[];
    for (int j = -1; j <= 2; j++) {
      final row = <Color>[];
      for (int i = -1; i <= 2; i++) {
        final sx = (ix + i).clamp(0, image.width - 1);
        final sy = (iy + j).clamp(0, image.height - 1);
        row.add(image.getPixel(sx, sy));
      }
      colors.add(row);
    }

    // Cubic interpolation
    double cubic(double p0, double p1, double p2, double p3, double t) {
      final a = -0.5 * p0 + 1.5 * p1 - 1.5 * p2 + 0.5 * p3;
      final b = p0 - 2.5 * p1 + 2.0 * p2 - 0.5 * p3;
      final c = -0.5 * p0 + 0.5 * p2;
      final d = p1;
      return a * t * t * t + b * t * t + c * t + d;
    }

    // Interpolate each color channel
    final r = List.generate(
      4,
      (j) => cubic(
        colors[j][0].red.toDouble(),
        colors[j][1].red.toDouble(),
        colors[j][2].red.toDouble(),
        colors[j][3].red.toDouble(),
        fx,
      ),
    );
    final g = List.generate(
      4,
      (j) => cubic(
        colors[j][0].green.toDouble(),
        colors[j][1].green.toDouble(),
        colors[j][2].green.toDouble(),
        colors[j][3].green.toDouble(),
        fx,
      ),
    );
    final b = List.generate(
      4,
      (j) => cubic(
        colors[j][0].blue.toDouble(),
        colors[j][1].blue.toDouble(),
        colors[j][2].blue.toDouble(),
        colors[j][3].blue.toDouble(),
        fx,
      ),
    );
    final a = List.generate(
      4,
      (j) => cubic(
        colors[j][0].alpha.toDouble(),
        colors[j][1].alpha.toDouble(),
        colors[j][2].alpha.toDouble(),
        colors[j][3].alpha.toDouble(),
        fx,
      ),
    );

    return Color.clamped(
      cubic(r[0], r[1], r[2], r[3], fy),
      cubic(g[0], g[1], g[2], g[3], fy),
      cubic(b[0], b[1], b[2], b[3], fy),
      cubic(a[0], a[1], a[2], a[3], fy),
    );
  }

  /// Blend pixel with target
  static void _blendPixel(
    Bitmap target,
    int x,
    int y,
    Color srcColor,
    BlendMode mode,
  ) {
    if (x < 0 || x >= target.width || y < 0 || y >= target.height) {
      return;
    }

    final dstColor = Color(target.pixels[y * target.width + x]);
    final blended = BlendModes.blend(srcColor, dstColor, mode);
    target.pixels[y * target.width + x] = blended.value;
  }

  /// Render tiled image (for pattern fills)
  static void renderTiledImage(
    Bitmap target,
    Bitmap source,
    Matrix2D transform,
    GraphicsState state, {
    ImageFilter filter = ImageFilter.bilinear,
    double opacity = 1.0,
  }) {
    // Calculate inverse transform for sampling
    final inverseTransform = Matrix2D.copy(transform)..invert();

    // Render all pixels in target
    for (int y = 0; y < target.height; y++) {
      for (int x = 0; x < target.width; x++) {
        // Transform pixel back to source coordinates
        final srcPoint = inverseTransform.transform(
          Point(x.toDouble(), y.toDouble()),
        );

        // Wrap coordinates for tiling
        final wrappedX =
            (srcPoint.x % source.width + source.width) % source.width;
        final wrappedY =
            (srcPoint.y % source.height + source.height) % source.height;

        // Sample source image
        final sampledColor = _sampleImage(source, wrappedX, wrappedY, filter);

        if (sampledColor.alpha > 0) {
          // Apply opacity
          final finalAlpha = (sampledColor.alpha * opacity).round().clamp(
            0,
            255,
          );
          final color = Color.fromRGBA(
            sampledColor.red,
            sampledColor.green,
            sampledColor.blue,
            finalAlpha,
          );

          // Blend with target
          _blendPixel(target, x, y, color, state.blendMode);
        }
      }
    }
  }
}

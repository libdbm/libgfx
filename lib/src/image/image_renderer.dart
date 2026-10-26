import 'dart:math' as math;

import 'bitmap.dart';
import '../color/color.dart';
import '../color/color_utils.dart';
import '../graphics_state.dart';
import '../matrix.dart';
import '../point.dart';
import '../rectangle.dart';
import '../result.dart';

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
    // Calculate inverse transform for sampling; a singular transform
    // collapses the image, so nothing is painted
    final Matrix2D inverse;
    switch (transform.inverse()) {
      case Ok(:final value):
        inverse = value;
      case Err():
        return;
    }

    // Calculate bounding box of transformed image
    final bounds =
        sourceRect ??
        Rectangle<double>(
          0,
          0,
          source.width.toDouble(),
          source.height.toDouble(),
        );

    final left = bounds.left.toDouble();
    final top = bounds.top.toDouble();
    final right = bounds.right.toDouble();
    final bottom = bounds.bottom.toDouble();

    final corners = [
      Point(left, top),
      Point(right, top),
      Point(right, bottom),
      Point(left, bottom),
    ];

    final transformed = corners
        .map((point) => transform.transform(point))
        .toList();

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final corner in transformed) {
      minX = math.min(minX, corner.x);
      minY = math.min(minY, corner.y);
      maxX = math.max(maxX, corner.x);
      maxY = math.max(maxY, corner.y);
    }

    const padding = 0.5;
    minX -= padding;
    minY -= padding;
    maxX += padding;
    maxY += padding;

    // Clamp to target bounds
    final startX = minX.floor().clamp(0, target.width - 1);
    final startY = minY.floor().clamp(0, target.height - 1);
    final endX = maxX.ceil().clamp(0, target.width - 1);
    final endY = maxY.ceil().clamp(0, target.height - 1);

    if (startX > endX || startY > endY) {
      return;
    }

    final region = state.clipRegion;
    final height = target.height;

    // Precompute inverse matrix components for the hot loop.
    final a = inverse.a;
    final b = inverse.b;
    final c = inverse.c;
    final d = inverse.d;
    final tx = inverse.tx;
    final ty = inverse.ty;

    // Render pixels
    for (int y = startY; y <= endY; y++) {
      final row = region != null ? height - 1 - y : 0;
      if (region != null && !region.rows.containsKey(row)) {
        continue;
      }

      final center = y + 0.5;
      final baseX = c * center + tx;
      final baseY = d * center + ty;
      final stepX = a;
      final stepY = b;
      var sourceX = a * (startX + 0.5) + baseX;
      var sourceY = b * (startX + 0.5) + baseY;

      for (int x = startX; x <= endX; x++) {
        // Skip pixels clipped out or whose centre maps outside the source
        final clip = region == null ? 255 : region.coverage(x, row);
        if (clip == 0 ||
            sourceX < left ||
            sourceX >= right ||
            sourceY < top ||
            sourceY >= bottom) {
          sourceX += stepX;
          sourceY += stepY;
          continue;
        }

        var sampleX = sourceX;
        if (sampleX < left) {
          sampleX = left;
        } else if (sampleX > right - 1e-6) {
          sampleX = right - 1e-6;
        }

        var sampleY = sourceY;
        if (sampleY < top) {
          sampleY = top;
        } else if (sampleY > bottom - 1e-6) {
          sampleY = bottom - 1e-6;
        }

        // Sample source image
        var fetchX = sampleX;
        var fetchY = sampleY;
        if (filter == ImageFilter.nearest) {
          final bias = d == 0 ? 0.0 : (d > 0 ? 1e-6 : -1e-6);
          fetchY -= bias;

          if (fetchY < top) {
            fetchY = top;
          } else if (fetchY > bottom - 1e-6) {
            fetchY = bottom - 1e-6;
          }
        }

        final sampled = _sample(source, fetchX, fetchY, filter);

        // Image opacity and global alpha scale the source; clip coverage
        // masks the blended result. Transparent pixels are blended too, since
        // modes such as src and srcIn clear the destination under them
        final alpha = (sampled.alpha * opacity * state.globalAlpha)
            .round()
            .clamp(0, 255);
        final color = Color.fromRGBA(
          sampled.red,
          sampled.green,
          sampled.blue,
          alpha,
        );

        target.blend(x, y, color, state.blendMode, clip);

        sourceX += stepX;
        sourceY += stepY;
      }
    }
  }

  /// Sample image with different filtering modes
  static Color _sample(Bitmap image, double x, double y, ImageFilter filter) {
    switch (filter) {
      case ImageFilter.nearest:
        return _nearest(image, x, y);
      case ImageFilter.bilinear:
        return _bilinear(image, x, y);
      case ImageFilter.bicubic:
        return _bicubic(image, x, y);
    }
  }

  /// Nearest neighbor sampling
  static Color _nearest(Bitmap image, double x, double y) {
    int clamp(int value, int min, int max) {
      if (value < min) return min;
      if (value > max) return max;
      return value;
    }

    if (!x.isFinite || !y.isFinite) {
      return Color.transparent;
    }

    final column = clamp((x - 0.5).round(), 0, image.width - 1);
    final row = clamp((y - 0.5).round(), 0, image.height - 1);
    return image.pixel(column, row);
  }

  /// Bilinear interpolation sampling
  static Color _bilinear(Bitmap image, double x, double y) {
    if (x < 0 || x >= image.width || y < 0 || y >= image.height) {
      return Color.transparent;
    }

    // Pixel i has its centre at i + 0.5; interpolate between centres
    final u = x - 0.5;
    final v = y - 0.5;
    final left = u.floor();
    final top = v.floor();
    final fx = u - left;
    final fy = v - top;

    // Neighbours past an edge repeat the edge pixel
    final width = image.width;
    final x0 = left < 0 ? 0 : left;
    final x1 = left + 1 < width ? left + 1 : width - 1;
    final y0 = (top < 0 ? 0 : top) * width;
    final y1 = (top + 1 < image.height ? top + 1 : image.height - 1) * width;

    final pixels = image.pixels;
    final c00 = Color(pixels[y0 + x0]);
    final c10 = Color(pixels[y0 + x1]);
    final c01 = Color(pixels[y1 + x0]);
    final c11 = Color(pixels[y1 + x1]);

    // Bilinear interpolation
    return ColorUtils.bilerp(c00, c10, c01, c11, fx, fy);
  }

  /// Bicubic interpolation sampling
  static Color _bicubic(Bitmap image, double x, double y) {
    if (x < 0 || x >= image.width || y < 0 || y >= image.height) {
      return Color.transparent;
    }

    // Pixel i has its centre at i + 0.5; interpolate between centres
    final left = (x - 0.5).floor();
    final top = (y - 0.5).floor();
    final fx = x - 0.5 - left;
    final fy = y - 0.5 - top;

    // Get 4x4 neighborhood
    final colors = <List<Color>>[];
    for (int j = -1; j <= 2; j++) {
      final row = <Color>[];
      for (int i = -1; i <= 2; i++) {
        final sx = (left + i).clamp(0, image.width - 1);
        final sy = (top + j).clamp(0, image.height - 1);
        row.add(image.pixel(sx, sy));
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
}

import 'dart:math' as math;
import 'dart:typed_data';

import '../limits.dart';
import 'bitmap.dart';
import '../color/color.dart';

/// Image filter types
enum FilterType { gaussian, box, sharpen, edges, emboss, motion }

/// Image filtering utilities
class ImageFilters {
  /// Apply Gaussian blur to a bitmap
  static Bitmap gaussian(
    Bitmap source,
    double sigma, {
    final Limits limits = const Limits(),
  }) {
    if (sigma <= 0) return source.clone();

    // Calculate kernel size (3 sigma on each side)
    final radius = (sigma * 3).ceil();
    _require(radius, limits);
    final size = radius * 2 + 1;

    // Generate Gaussian kernel
    final kernel = _kernel(size, sigma);

    // Apply separable convolution (horizontal then vertical)
    final horizontal = _convolve1D(source, kernel, true); // Horizontal pass
    return _convolve1D(horizontal, kernel, false); // Vertical pass
  }

  /// Apply box blur (fast approximation of Gaussian blur)
  static Bitmap box(
    Bitmap source,
    int radius, {
    final Limits limits = const Limits(),
  }) {
    if (radius <= 0) return source.clone();
    _require(radius, limits);

    final width = source.width;
    final height = source.height;
    final size = 2 * radius + 1;

    // Horizontal pass: for each pixel and channel, the sum over its row
    // window, kept as a running sum with clamped edges
    final rows = Int32List(width * height * 4);
    final row = Int32List(width * 4);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final color = source.pixel(x, y);
        row[x * 4] = color.red;
        row[x * 4 + 1] = color.green;
        row[x * 4 + 2] = color.blue;
        row[x * 4 + 3] = color.alpha;
      }
      for (int c = 0; c < 4; c++) {
        int sum = 0;
        for (int dx = -radius; dx <= radius; dx++) {
          sum += row[dx.clamp(0, width - 1) * 4 + c];
        }
        for (int x = 0; x < width; x++) {
          rows[(y * width + x) * 4 + c] = sum;
          final add = (x + radius + 1).clamp(0, width - 1);
          final remove = (x - radius).clamp(0, width - 1);
          sum += row[add * 4 + c] - row[remove * 4 + c];
        }
      }
    }

    // Vertical pass over the row sums gives the full window sum, which is
    // divided once, as averaging the whole window would
    final result = Bitmap(width, height);
    final count = size * size;
    final sums = Int32List(4);
    for (int x = 0; x < width; x++) {
      for (int c = 0; c < 4; c++) {
        int sum = 0;
        for (int dy = -radius; dy <= radius; dy++) {
          sum += rows[(dy.clamp(0, height - 1) * width + x) * 4 + c];
        }
        sums[c] = sum;
      }
      for (int y = 0; y < height; y++) {
        result.plot(
          x,
          y,
          Color.fromRGBA(
            (sums[0] / count).round(),
            (sums[1] / count).round(),
            (sums[2] / count).round(),
            (sums[3] / count).round(),
          ),
        );
        final add = (y + radius + 1).clamp(0, height - 1);
        final remove = (y - radius).clamp(0, height - 1);
        for (int c = 0; c < 4; c++) {
          sums[c] +=
              rows[(add * width + x) * 4 + c] -
              rows[(remove * width + x) * 4 + c];
        }
      }
    }

    return result;
  }

  /// Apply sharpening filter
  static Bitmap sharpen(Bitmap source, double amount) {
    // Sharpening kernel
    final kernel = [
      [0.0, -amount, 0.0],
      [-amount, 1 + 4 * amount, -amount],
      [0.0, -amount, 0.0],
    ];

    return _convolve2D(source, kernel);
  }

  /// Apply edge detection filter (Sobel operator)
  static Bitmap edges(Bitmap source, {double threshold = 128}) {
    // Sobel X kernel
    final sobelX = [
      [-1.0, 0.0, 1.0],
      [-2.0, 0.0, 2.0],
      [-1.0, 0.0, 1.0],
    ];

    // Sobel Y kernel
    final sobelY = [
      [-1.0, -2.0, -1.0],
      [0.0, 0.0, 0.0],
      [1.0, 2.0, 1.0],
    ];

    final result = Bitmap(source.width, source.height);

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        // Signed gradients, so falling edges are not clamped away
        final gx = _gradient(source, sobelX, x, y);
        final gy = _gradient(source, sobelY, x, y);

        // Calculate gradient magnitude
        final magnitude = math.sqrt(gx * gx + gy * gy).clamp(0, 255).round();

        // Apply threshold
        final value = magnitude > threshold ? 255 : 0;

        result.plot(x, y, Color.fromRGBA(value, value, value, 255));
      }
    }

    return result;
  }

  /// Apply emboss filter
  static Bitmap emboss(Bitmap source, {double strength = 1.0}) {
    final kernel = [
      [-2.0 * strength, -1.0 * strength, 0.0],
      [-1.0 * strength, 1.0, 1.0 * strength],
      [0.0, 1.0 * strength, 2.0 * strength],
    ];

    return _convolve2D(source, kernel);
  }

  /// Apply motion blur filter
  static Bitmap motion(
    Bitmap source,
    double angle,
    int distance, {
    final Limits limits = const Limits(),
  }) {
    if (distance <= 0) return source.clone();
    _require(distance, limits);

    final result = Bitmap(source.width, source.height);
    final dx = math.cos(angle);
    final dy = math.sin(angle);

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        double r = 0, g = 0, b = 0, a = 0;
        int count = 0;

        for (int i = -distance; i <= distance; i++) {
          final column = (x + dx * i).round().clamp(0, source.width - 1);
          final row = (y + dy * i).round().clamp(0, source.height - 1);
          final color = source.pixel(column, row);

          r += color.red;
          g += color.green;
          b += color.blue;
          a += color.alpha;
          count++;
        }

        result.plot(
          x,
          y,
          Color.fromRGBA(
            (r / count).round(),
            (g / count).round(),
            (b / count).round(),
            (a / count).round(),
          ),
        );
      }
    }

    return result;
  }

  /// Throws [ArgumentError] if [radius] exceeds [Limits.radius].
  static void _require(final int radius, final Limits limits) {
    if (radius > limits.radius) {
      throw ArgumentError.value(
        radius,
        'radius',
        'Exceeds the limit of ${limits.radius} pixels',
      );
    }
  }

  /// Apply custom convolution kernel
  static Bitmap convolve(Bitmap source, List<List<double>> kernel) {
    return _convolve2D(source, kernel);
  }

  /// Generate Gaussian kernel
  static Float32List _kernel(int size, double sigma) {
    final kernel = Float32List(size);
    final center = size ~/ 2;
    double sum = 0;

    for (int i = 0; i < size; i++) {
      final x = i - center;
      kernel[i] = math.exp(-(x * x) / (2 * sigma * sigma));
      sum += kernel[i];
    }

    // Normalize
    for (int i = 0; i < size; i++) {
      kernel[i] /= sum;
    }

    return kernel;
  }

  /// 1D convolution (for separable filters)
  static Bitmap _convolve1D(
    Bitmap source,
    Float32List kernel,
    bool horizontal,
  ) {
    final result = Bitmap(source.width, source.height);
    final radius = kernel.length ~/ 2;

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        double r = 0, g = 0, b = 0, a = 0;

        for (int i = 0; i < kernel.length; i++) {
          final offset = i - radius;
          int column, row;

          if (horizontal) {
            column = (x + offset).clamp(0, source.width - 1);
            row = y;
          } else {
            column = x;
            row = (y + offset).clamp(0, source.height - 1);
          }

          final color = source.pixel(column, row);
          final weight = kernel[i];

          r += color.red * weight;
          g += color.green * weight;
          b += color.blue * weight;
          a += color.alpha * weight;
        }

        result.plot(
          x,
          y,
          Color.fromRGBA(
            r.round().clamp(0, 255),
            g.round().clamp(0, 255),
            b.round().clamp(0, 255),
            a.round().clamp(0, 255),
          ),
        );
      }
    }

    return result;
  }

  /// 2D convolution
  /// Signed response of a 3x3 [kernel] on the red channel at [x], [y],
  /// with edge pixels repeated beyond the bitmap.
  static double _gradient(
    Bitmap source,
    List<List<double>> kernel,
    int x,
    int y,
  ) {
    var sum = 0.0;
    for (int ky = 0; ky < 3; ky++) {
      for (int kx = 0; kx < 3; kx++) {
        final column = (x + kx - 1).clamp(0, source.width - 1);
        final row = (y + ky - 1).clamp(0, source.height - 1);
        sum += source.pixel(column, row).red * kernel[ky][kx];
      }
    }
    return sum;
  }

  static Bitmap _convolve2D(Bitmap source, List<List<double>> kernel) {
    final result = Bitmap(source.width, source.height);
    final rows = kernel.length;
    final columns = kernel[0].length;
    final radiusY = rows ~/ 2;
    final radiusX = columns ~/ 2;

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        double r = 0, g = 0, b = 0, a = 0;

        for (int ky = 0; ky < rows; ky++) {
          for (int kx = 0; kx < columns; kx++) {
            final column = (x + kx - radiusX).clamp(0, source.width - 1);
            final row = (y + ky - radiusY).clamp(0, source.height - 1);

            final color = source.pixel(column, row);
            final weight = kernel[ky][kx];

            r += color.red * weight;
            g += color.green * weight;
            b += color.blue * weight;
            a += color.alpha * weight;
          }
        }

        result.plot(
          x,
          y,
          Color.fromRGBA(
            r.round().clamp(0, 255),
            g.round().clamp(0, 255),
            b.round().clamp(0, 255),
            a.round().clamp(0, 255),
          ),
        );
      }
    }

    return result;
  }

  /// Optimized stack blur algorithm (faster than Gaussian)
  static Bitmap stack(
    Bitmap source,
    int radius, {
    final Limits limits = const Limits(),
  }) {
    if (radius < 1) return source.clone();
    _require(radius, limits);

    final width = source.width;
    final height = source.height;
    final result = source.clone();

    // Each window holds divisor pixels; average with rounding.
    final divisor = radius + radius + 1;
    int mean(int sum) => (sum + (divisor >> 1)) ~/ divisor;

    // Process horizontally
    for (int y = 0; y < height; y++) {
      int red = 0, green = 0, blue = 0, alpha = 0;

      // Initialize with left edge
      for (int i = -radius; i <= radius; i++) {
        final x = i.clamp(0, width - 1);
        final color = source.pixel(x, y);
        red += color.red;
        green += color.green;
        blue += color.blue;
        alpha += color.alpha;
      }

      for (int x = 0; x < width; x++) {
        result.plot(
          x,
          y,
          Color.fromRGBA(mean(red), mean(green), mean(blue), mean(alpha)),
        );

        // Update sliding window
        final remove = (x - radius).clamp(0, width - 1);
        final add = (x + radius + 1).clamp(0, width - 1);

        final removed = source.pixel(remove, y);
        final added = source.pixel(add, y);

        red = red - removed.red + added.red;
        green = green - removed.green + added.green;
        blue = blue - removed.blue + added.blue;
        alpha = alpha - removed.alpha + added.alpha;
      }
    }

    // Process vertically (on result of horizontal pass)
    final horizontal = result.clone();
    for (int x = 0; x < width; x++) {
      int red = 0, green = 0, blue = 0, alpha = 0;

      // Initialize with top edge
      for (int i = -radius; i <= radius; i++) {
        final y = i.clamp(0, height - 1);
        final color = horizontal.pixel(x, y);
        red += color.red;
        green += color.green;
        blue += color.blue;
        alpha += color.alpha;
      }

      for (int y = 0; y < height; y++) {
        result.plot(
          x,
          y,
          Color.fromRGBA(mean(red), mean(green), mean(blue), mean(alpha)),
        );

        // Update sliding window
        final remove = (y - radius).clamp(0, height - 1);
        final add = (y + radius + 1).clamp(0, height - 1);

        final removed = horizontal.pixel(x, remove);
        final added = horizontal.pixel(x, add);

        red = red - removed.red + added.red;
        green = green - removed.green + added.green;
        blue = blue - removed.blue + added.blue;
        alpha = alpha - removed.alpha + added.alpha;
      }
    }

    return result;
  }
}

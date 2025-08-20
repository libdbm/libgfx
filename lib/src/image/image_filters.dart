import 'dart:math' as math;
import 'dart:typed_data';

import 'bitmap.dart';
import '../color/color.dart';

/// Image filter types
enum FilterType {
  gaussianBlur,
  boxBlur,
  sharpen,
  edgeDetect,
  emboss,
  motionBlur,
}

/// Image filtering utilities
class ImageFilters {
  /// Apply Gaussian blur to a bitmap
  static Bitmap gaussianBlur(Bitmap source, double sigma) {
    if (sigma <= 0) return source.clone();

    // Calculate kernel size (3 sigma on each side)
    final kernelRadius = (sigma * 3).ceil();
    final kernelSize = kernelRadius * 2 + 1;

    // Generate Gaussian kernel
    final kernel = _generateGaussianKernel(kernelSize, sigma);

    // Apply separable convolution (horizontal then vertical)
    final temp = _convolve1D(source, kernel, true); // Horizontal pass
    return _convolve1D(temp, kernel, false); // Vertical pass
  }

  /// Apply box blur (fast approximation of Gaussian blur)
  static Bitmap boxBlur(Bitmap source, int radius) {
    if (radius <= 0) return source.clone();

    final result = Bitmap(source.width, source.height);
    // Weight calculation is not used as we're using a count-based average

    // Optimized box blur using sliding window
    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        double r = 0, g = 0, b = 0, a = 0;
        int count = 0;

        for (int dy = -radius; dy <= radius; dy++) {
          final py = (y + dy).clamp(0, source.height - 1);
          for (int dx = -radius; dx <= radius; dx++) {
            final px = (x + dx).clamp(0, source.width - 1);
            final color = source.getPixel(px, py);

            r += color.red;
            g += color.green;
            b += color.blue;
            a += color.alpha;
            count++;
          }
        }

        result.setPixel(
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
  static Bitmap edgeDetect(Bitmap source, {double threshold = 128}) {
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

    final gradX = _convolve2D(source, sobelX);
    final gradY = _convolve2D(source, sobelY);

    final result = Bitmap(source.width, source.height);

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final gx = gradX.getPixel(x, y);
        final gy = gradY.getPixel(x, y);

        // Calculate gradient magnitude
        final magnitude = math
            .sqrt(gx.red * gx.red + gy.red * gy.red)
            .clamp(0, 255)
            .round();

        // Apply threshold
        final value = magnitude > threshold ? 255 : 0;

        result.setPixel(x, y, Color.fromRGBA(value, value, value, 255));
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
  static Bitmap motionBlur(Bitmap source, double angle, int distance) {
    if (distance <= 0) return source.clone();

    final result = Bitmap(source.width, source.height);
    final dx = math.cos(angle);
    final dy = math.sin(angle);

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        double r = 0, g = 0, b = 0, a = 0;
        int count = 0;

        for (int i = -distance; i <= distance; i++) {
          final px = (x + dx * i).round().clamp(0, source.width - 1);
          final py = (y + dy * i).round().clamp(0, source.height - 1);
          final color = source.getPixel(px, py);

          r += color.red;
          g += color.green;
          b += color.blue;
          a += color.alpha;
          count++;
        }

        result.setPixel(
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

  /// Apply custom convolution kernel
  static Bitmap customFilter(Bitmap source, List<List<double>> kernel) {
    return _convolve2D(source, kernel);
  }

  /// Generate Gaussian kernel
  static Float32List _generateGaussianKernel(int size, double sigma) {
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
          int px, py;

          if (horizontal) {
            px = (x + offset).clamp(0, source.width - 1);
            py = y;
          } else {
            px = x;
            py = (y + offset).clamp(0, source.height - 1);
          }

          final color = source.getPixel(px, py);
          final weight = kernel[i];

          r += color.red * weight;
          g += color.green * weight;
          b += color.blue * weight;
          a += color.alpha * weight;
        }

        result.setPixel(
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
  static Bitmap _convolve2D(Bitmap source, List<List<double>> kernel) {
    final result = Bitmap(source.width, source.height);
    final kernelHeight = kernel.length;
    final kernelWidth = kernel[0].length;
    final radiusY = kernelHeight ~/ 2;
    final radiusX = kernelWidth ~/ 2;

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        double r = 0, g = 0, b = 0, a = 0;

        for (int ky = 0; ky < kernelHeight; ky++) {
          for (int kx = 0; kx < kernelWidth; kx++) {
            final px = (x + kx - radiusX).clamp(0, source.width - 1);
            final py = (y + ky - radiusY).clamp(0, source.height - 1);

            final color = source.getPixel(px, py);
            final weight = kernel[ky][kx];

            r += color.red * weight;
            g += color.green * weight;
            b += color.blue * weight;
            a += color.alpha * weight;
          }
        }

        result.setPixel(
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
  static Bitmap stackBlur(Bitmap source, int radius) {
    if (radius < 1) return source.clone();

    final w = source.width;
    final h = source.height;
    final result = source.clone();

    final div = radius + radius + 1;
    final divSum = (div + 1) >> 1;
    final mulSum = divSum * divSum;
    final mulTable = Uint8List(256 * mulSum);

    for (int i = 0; i < 256 * mulSum; i++) {
      mulTable[i] = (i ~/ mulSum);
    }

    // Process horizontally
    for (int y = 0; y < h; y++) {
      int sumR = 0, sumG = 0, sumB = 0, sumA = 0;

      // Initialize with left edge
      for (int i = -radius; i <= radius; i++) {
        final x = i.clamp(0, w - 1);
        final color = source.getPixel(x, y);
        sumR += color.red;
        sumG += color.green;
        sumB += color.blue;
        sumA += color.alpha;
      }

      for (int x = 0; x < w; x++) {
        result.setPixel(
          x,
          y,
          Color.fromRGBA(
            mulTable[sumR],
            mulTable[sumG],
            mulTable[sumB],
            mulTable[sumA],
          ),
        );

        // Update sliding window
        final removeX = (x - radius - 1).clamp(0, w - 1);
        final addX = (x + radius + 1).clamp(0, w - 1);

        final removeColor = source.getPixel(removeX, y);
        final addColor = source.getPixel(addX, y);

        sumR = sumR - removeColor.red + addColor.red;
        sumG = sumG - removeColor.green + addColor.green;
        sumB = sumB - removeColor.blue + addColor.blue;
        sumA = sumA - removeColor.alpha + addColor.alpha;
      }
    }

    // Process vertically (on result of horizontal pass)
    final temp = result.clone();
    for (int x = 0; x < w; x++) {
      int sumR = 0, sumG = 0, sumB = 0, sumA = 0;

      // Initialize with top edge
      for (int i = -radius; i <= radius; i++) {
        final y = i.clamp(0, h - 1);
        final color = temp.getPixel(x, y);
        sumR += color.red;
        sumG += color.green;
        sumB += color.blue;
        sumA += color.alpha;
      }

      for (int y = 0; y < h; y++) {
        result.setPixel(
          x,
          y,
          Color.fromRGBA(
            mulTable[sumR],
            mulTable[sumG],
            mulTable[sumB],
            mulTable[sumA],
          ),
        );

        // Update sliding window
        final removeY = (y - radius - 1).clamp(0, h - 1);
        final addY = (y + radius + 1).clamp(0, h - 1);

        final removeColor = temp.getPixel(x, removeY);
        final addColor = temp.getPixel(x, addY);

        sumR = sumR - removeColor.red + addColor.red;
        sumG = sumG - removeColor.green + addColor.green;
        sumB = sumB - removeColor.blue + addColor.blue;
        sumA = sumA - removeColor.alpha + addColor.alpha;
      }
    }

    return result;
  }
}

import 'dart:typed_data';

import '../limits.dart';

/// Pixels as W3C canvas `ImageData` holds them: [width] by [height], rows
/// from the top, four bytes per pixel in red, green, blue, alpha order, not
/// premultiplied.
class ImageData {
  final int width;
  final int height;
  final Uint8ClampedList data;

  /// Transparent black pixels. Sizes below one, or more pixels than the
  /// default [Limits.pixels], are programming errors and throw
  /// [ArgumentError] before anything is allocated.
  ImageData(this.width, this.height) : data = _allocate(width, height);

  /// Pixels from [data], which must hold exactly `width * height * 4` bytes;
  /// the bytes are used as given, not copied.
  ImageData.from(this.width, this.height, this.data) {
    _check(width, height);
    if (data.length != width * height * 4) {
      throw ArgumentError(
        'ImageData of ${width}x$height needs ${width * height * 4} bytes, '
        'got ${data.length}',
      );
    }
  }

  static Uint8ClampedList _allocate(final int width, final int height) {
    _check(width, height);
    return Uint8ClampedList(width * height * 4);
  }

  static void _check(final int width, final int height) {
    if (width < 1 || height < 1) {
      throw ArgumentError('ImageData must be at least 1x1: ${width}x$height');
    }
    if (width * height > const Limits().pixels) {
      throw ArgumentError(
        'ImageData of ${width}x$height exceeds '
        '${const Limits().pixels} pixels',
      );
    }
  }
}

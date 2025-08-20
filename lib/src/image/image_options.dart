import 'image_renderer.dart' show ImageFilter;
import '../matrix.dart';
import '../utils/transform_utils.dart' show ScaleMode, Alignment;

// Re-export types so they're available when importing ImageOptions
export 'image_renderer.dart' show ImageFilter;
export '../utils/transform_utils.dart' show ScaleMode, Alignment;

/// Options for drawing images
class ImageOptions {
  /// Destination x coordinate
  final double x;

  /// Destination y coordinate
  final double y;

  /// Optional width (null = use image width)
  final double? width;

  /// Optional height (null = use image height)
  final double? height;

  /// Scale mode when width and height are specified
  final ScaleMode scaleMode;

  /// Alignment within destination bounds
  final Alignment alignment;

  /// Image filtering mode
  final ImageFilter filter;

  /// Opacity (0.0 to 1.0)
  final double opacity;

  /// Custom transformation matrix (overrides other positioning)
  final Matrix2D? transform;

  /// Enable tiling/pattern mode
  final bool pattern;

  const ImageOptions({
    this.x = 0,
    this.y = 0,
    this.width,
    this.height,
    this.scaleMode = ScaleMode.fit,
    this.alignment = Alignment.center,
    this.filter = ImageFilter.bilinear,
    this.opacity = 1.0,
    this.transform,
    this.pattern = false,
  });

  /// Create options for simple positioning
  factory ImageOptions.at(double x, double y) {
    return ImageOptions(x: x, y: y);
  }

  /// Create options for scaled image
  factory ImageOptions.scaled(
    double x,
    double y,
    double width,
    double height, {
    ScaleMode scaleMode = ScaleMode.fit,
    Alignment alignment = Alignment.center,
  }) {
    return ImageOptions(
      x: x,
      y: y,
      width: width,
      height: height,
      scaleMode: scaleMode,
      alignment: alignment,
    );
  }

  /// Create options with custom transform
  factory ImageOptions.transformed(Matrix2D transform) {
    return ImageOptions(transform: transform);
  }

  /// Create options for pattern/tiling
  factory ImageOptions.pattern(
    double x,
    double y,
    double width,
    double height,
  ) {
    return ImageOptions(
      x: x,
      y: y,
      width: width,
      height: height,
      pattern: true,
    );
  }

  /// Copy with modifications
  ImageOptions copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    ScaleMode? scaleMode,
    Alignment? alignment,
    ImageFilter? filter,
    double? opacity,
    Matrix2D? transform,
    bool? pattern,
  }) {
    return ImageOptions(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      scaleMode: scaleMode ?? this.scaleMode,
      alignment: alignment ?? this.alignment,
      filter: filter ?? this.filter,
      opacity: opacity ?? this.opacity,
      transform: transform ?? this.transform,
      pattern: pattern ?? this.pattern,
    );
  }
}

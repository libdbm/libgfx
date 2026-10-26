import 'dart:math' as math;

import '../matrix.dart';
import '../point.dart';
import '../rectangle.dart';

/// Utilities for common transformation operations and matrix manipulations.
///
/// This class provides convenient methods for creating, composing, and working
/// with transformations in a 2D graphics context.
class TransformUtils {
  // Prevent instantiation
  TransformUtils._();

  /// Creates a transformation that fits one rectangle into another.
  ///
  /// [source] - The source rectangle to transform
  /// [target] - The target rectangle to fit into
  /// [scaleMode] - How to handle aspect ratio differences
  /// [alignment] - How to align within the target if aspect ratios differ
  static Matrix2D fit(
    Rectangle<double> source,
    Rectangle<double> target, {
    ScaleMode scaleMode = ScaleMode.fit,
    Alignment alignment = Alignment.center,
  }) {
    if (source.width == 0 || source.height == 0) {
      return Matrix2D.identity();
    }

    final scaleX = target.width / source.width;
    final scaleY = target.height / source.height;

    double sx, sy;

    switch (scaleMode) {
      case ScaleMode.fit:
        // Uniform scale to fit entirely within target
        final scale = math.min(scaleX, scaleY);
        sx = sy = scale;
        break;
      case ScaleMode.fill:
        // Uniform scale to fill target completely (may crop)
        final scale = math.max(scaleX, scaleY);
        sx = sy = scale;
        break;
      case ScaleMode.stretch:
        // Non-uniform scale to exactly match target
        sx = scaleX;
        sy = scaleY;
        break;
    }

    // Calculate translation to center the scaled source in target
    final width = source.width * sx;
    final height = source.height * sy;

    double tx = target.left - source.left * sx;
    double ty = target.top - source.top * sy;

    // Apply alignment offset
    final offset = _offset(
      width,
      height,
      target.width,
      target.height,
      alignment,
    );

    tx += offset.x;
    ty += offset.y;

    return Matrix2D(sx, 0, 0, sy, tx, ty);
  }

  /// Creates a transformation that positions content within a rectangle.
  static Matrix2D position(
    final double width,
    final double height,
    Rectangle<double> container,
    Alignment alignment,
  ) {
    final offset = _offset(
      width,
      height,
      container.width,
      container.height,
      alignment,
    );

    return Matrix2D.translation(
      container.left + offset.x,
      container.top + offset.y,
    );
  }

  /// Creates a combined transform: translate → rotate → scale.
  static Matrix2D compose(
    double tx,
    double ty,
    double rotation,
    double sx, [
    double? sy,
  ]) {
    sy ??= sx;
    final matrix = Matrix2D.identity();
    matrix.translate(tx, ty);
    matrix.rotate(rotation);
    matrix.scale(sx, sy);
    return matrix;
  }

  /// Creates a combined transform: scale → rotate → translate.
  static Matrix2D reverse(
    double sx,
    double sy,
    double rotation,
    double tx,
    double ty,
  ) {
    final matrix = Matrix2D.identity();
    matrix.scale(sx, sy);
    matrix.rotate(rotation);
    matrix.translate(tx, ty);
    return matrix;
  }

  /// Transforms a rectangle by a matrix and returns the axis-aligned bounding box.
  static Rectangle<double> bounds(
    final Rectangle<double> rectangle,
    Matrix2D transform,
  ) {
    // Transform all four corners
    final corners = [
      transform.transform(Point(rectangle.left, rectangle.top)),
      transform.transform(Point(rectangle.right, rectangle.top)),
      transform.transform(Point(rectangle.right, rectangle.bottom)),
      transform.transform(Point(rectangle.left, rectangle.bottom)),
    ];

    // Find bounding box
    double minX = corners[0].x;
    double maxX = corners[0].x;
    double minY = corners[0].y;
    double maxY = corners[0].y;

    for (int i = 1; i < corners.length; i++) {
      minX = math.min(minX, corners[i].x);
      maxX = math.max(maxX, corners[i].x);
      minY = math.min(minY, corners[i].y);
      maxY = math.max(maxY, corners[i].y);
    }

    return Rectangle<double>(minX, minY, maxX - minX, maxY - minY);
  }

  /// Transforms a list of points and returns their axis-aligned bounding box.
  static Rectangle<double> extent(List<Point> points, Matrix2D transform) {
    if (points.isEmpty) {
      return Rectangle<double>(0, 0, 0, 0);
    }

    final transformed = points
        .map((point) => transform.transform(point))
        .toList();

    double minX = transformed[0].x;
    double maxX = transformed[0].x;
    double minY = transformed[0].y;
    double maxY = transformed[0].y;

    for (int i = 1; i < transformed.length; i++) {
      final point = transformed[i];
      minX = math.min(minX, point.x);
      maxX = math.max(maxX, point.x);
      minY = math.min(minY, point.y);
      maxY = math.max(maxY, point.y);
    }

    return Rectangle<double>(minX, minY, maxX - minX, maxY - minY);
  }

  /// Extracts the translation component as a Point.
  static Point translation(Matrix2D matrix) {
    return Point(matrix.tx, matrix.ty);
  }

  /// Extracts the rotation angle in radians (assuming uniform scale).
  static double rotation(Matrix2D matrix) {
    return math.atan2(matrix.b, matrix.a);
  }

  /// Extracts the scale factors as a Point.
  static Point scale(Matrix2D matrix) {
    final sx = math.sqrt(matrix.a * matrix.a + matrix.b * matrix.b);
    final sy = math.sqrt(matrix.c * matrix.c + matrix.d * matrix.d);

    // Check for negative scale (flip)
    final determinant = matrix.determinant;
    return Point(sx, determinant < 0 ? -sy : sy);
  }

  static Point _offset(
    double contentWidth,
    double contentHeight,
    double containerWidth,
    double containerHeight,
    Alignment alignment,
  ) {
    final dx = containerWidth - contentWidth;
    final dy = containerHeight - contentHeight;

    switch (alignment) {
      case Alignment.topLeft:
        return Point(0, 0);
      case Alignment.topCenter:
        return Point(dx / 2, 0);
      case Alignment.topRight:
        return Point(dx, 0);
      case Alignment.centerLeft:
        return Point(0, dy / 2);
      case Alignment.center:
        return Point(dx / 2, dy / 2);
      case Alignment.centerRight:
        return Point(dx, dy / 2);
      case Alignment.bottomLeft:
        return Point(0, dy);
      case Alignment.bottomCenter:
        return Point(dx / 2, dy);
      case Alignment.bottomRight:
        return Point(dx, dy);
    }
  }
}

/// Defines how content should be scaled to fit within a target area.
enum ScaleMode {
  /// Scale uniformly to fit entirely within target (may leave empty space).
  fit,

  /// Scale uniformly to fill target completely (may crop content).
  fill,

  /// Scale non-uniformly to exactly match target dimensions.
  stretch,
}

/// Defines how content should be aligned within a container.
enum Alignment {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

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
  static Matrix2D fitRect(
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

    double finalScaleX, finalScaleY;

    switch (scaleMode) {
      case ScaleMode.fit:
        // Uniform scale to fit entirely within target
        final scale = math.min(scaleX, scaleY);
        finalScaleX = finalScaleY = scale;
        break;
      case ScaleMode.fill:
        // Uniform scale to fill target completely (may crop)
        final scale = math.max(scaleX, scaleY);
        finalScaleX = finalScaleY = scale;
        break;
      case ScaleMode.stretch:
        // Non-uniform scale to exactly match target
        finalScaleX = scaleX;
        finalScaleY = scaleY;
        break;
    }

    // Calculate translation to center the scaled source in target
    final scaledWidth = source.width * finalScaleX;
    final scaledHeight = source.height * finalScaleY;

    double tx = target.left - source.left * finalScaleX;
    double ty = target.top - source.top * finalScaleY;

    // Apply alignment offset
    final alignmentOffset = _calculateAlignmentOffset(
      scaledWidth,
      scaledHeight,
      target.width,
      target.height,
      alignment,
    );

    tx += alignmentOffset.x;
    ty += alignmentOffset.y;

    return Matrix2D(finalScaleX, 0, 0, finalScaleY, tx, ty);
  }

  /// Creates a transformation that positions content within a rectangle.
  static Matrix2D positionInRect(
    double contentWidth,
    double contentHeight,
    Rectangle<double> container,
    Alignment alignment,
  ) {
    final offset = _calculateAlignmentOffset(
      contentWidth,
      contentHeight,
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
  static Matrix2D createTRS(
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
  static Matrix2D createSRT(
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
  static Rectangle<double> transformBounds(
    Rectangle<double> rect,
    Matrix2D transform,
  ) {
    // Transform all four corners
    final corners = [
      transform.transform(Point(rect.left, rect.top)),
      transform.transform(Point(rect.right, rect.top)),
      transform.transform(Point(rect.right, rect.bottom)),
      transform.transform(Point(rect.left, rect.bottom)),
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
  static Rectangle<double> transformPointsBounds(
    List<Point> points,
    Matrix2D transform,
  ) {
    if (points.isEmpty) {
      return Rectangle<double>(0, 0, 0, 0);
    }

    final transformedPoints = points
        .map((p) => transform.transform(p))
        .toList();

    double minX = transformedPoints[0].x;
    double maxX = transformedPoints[0].x;
    double minY = transformedPoints[0].y;
    double maxY = transformedPoints[0].y;

    for (int i = 1; i < transformedPoints.length; i++) {
      final p = transformedPoints[i];
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }

    return Rectangle<double>(minX, minY, maxX - minX, maxY - minY);
  }

  /// Extracts the translation component as a Point.
  static Point getTranslation(Matrix2D matrix) {
    return Point(matrix.tx, matrix.ty);
  }

  /// Extracts the rotation angle in radians (assuming uniform scale).
  static double getRotation(Matrix2D matrix) {
    return math.atan2(matrix.b, matrix.a);
  }

  /// Extracts the scale factors as a Point.
  static Point getScale(Matrix2D matrix) {
    final sx = math.sqrt(matrix.a * matrix.a + matrix.b * matrix.b);
    final sy = math.sqrt(matrix.c * matrix.c + matrix.d * matrix.d);

    // Check for negative scale (flip)
    final determinant = matrix.determinant;
    return Point(sx, determinant < 0 ? -sy : sy);
  }

  static Point _calculateAlignmentOffset(
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

import 'dart:math' as math;

/// A 2D axis-aligned rectangle.
///
/// The class is generic to support both integer and floating-point coordinates.
class Rectangle<T extends num> {
  final T left;
  final T top;
  final T width;
  final T height;

  /// Creates a rectangle from left, top, width, and height.
  const Rectangle(this.left, this.top, this.width, this.height);

  /// Creates a rectangle from left, top, right, and bottom coordinates.
  factory Rectangle.fromLTRB(T left, T top, T right, T bottom) {
    return Rectangle<T>(left, top, (right - left) as T, (bottom - top) as T);
  }

  /// Creates a rectangle from left, top, width, and height (alias for default constructor).
  factory Rectangle.fromLTWH(T left, T top, T width, T height) {
    return Rectangle<T>(left, top, width, height);
  }

  /// Creates a rectangle centered at (cx, cy) with the given width and height.
  factory Rectangle.fromCenter(T cx, T cy, T width, T height) {
    final halfWidth = (width / 2) as T;
    final halfHeight = (height / 2) as T;
    return Rectangle<T>(
      (cx - halfWidth) as T,
      (cy - halfHeight) as T,
      width,
      height,
    );
  }

  /// Creates an empty rectangle at origin.
  static Rectangle<T> zero<T extends num>() =>
      Rectangle<T>((0 as T), (0 as T), (0 as T), (0 as T));

  /// Gets the right edge coordinate.
  T get right => (left + width) as T;

  /// Gets the bottom edge coordinate.
  T get bottom => (top + height) as T;

  /// Gets the center X coordinate.
  T get centerX => (left + width / 2) as T;

  /// Gets the center Y coordinate.
  T get centerY => (top + height / 2) as T;

  /// Checks if the rectangle is empty (has zero area).
  bool get isEmpty => width == 0 || height == 0;

  /// Checks if the rectangle is not empty (has non-zero area).
  bool get isNotEmpty => !isEmpty;

  /// Gets the area of the rectangle.
  T get area => (width * height) as T;

  /// Returns the intersection of this rectangle with another.
  /// Returns null if the rectangles don't intersect.
  Rectangle<T>? intersection(Rectangle<T> other) {
    final x1 = math.max(left, other.left);
    final y1 = math.max(top, other.top);
    final x2 = math.min(right, other.right);
    final y2 = math.min(bottom, other.bottom);

    if (x2 > x1 && y2 > y1) {
      return Rectangle<T>(x1, y1, (x2 - x1) as T, (y2 - y1) as T);
    }
    return null;
  }

  /// Converts this rectangle to integer coordinates.
  Rectangle<int> toInt() {
    if (this is Rectangle<int>) {
      return this as Rectangle<int>;
    }
    return Rectangle<int>(
      left.toInt(),
      top.toInt(),
      width.toInt(),
      height.toInt(),
    );
  }

  /// Converts this rectangle to double coordinates.
  Rectangle<double> toDouble() {
    if (this is Rectangle<double>) {
      return this as Rectangle<double>;
    }
    return Rectangle<double>(
      left.toDouble(),
      top.toDouble(),
      width.toDouble(),
      height.toDouble(),
    );
  }

  /// Rounds the rectangle coordinates to the nearest integer.
  Rectangle<int> round() {
    return Rectangle<int>(
      left.round(),
      top.round(),
      width.round(),
      height.round(),
    );
  }

  /// Expands the rectangle to include integer pixels (ceiling for max, floor for min).
  Rectangle<int> roundOut() {
    final l = left.floor();
    final t = top.floor();
    final r = right.ceil();
    final b = bottom.ceil();
    return Rectangle<int>(l, t, r - l, b - t);
  }

  /// Contracts the rectangle to integer pixels (floor for max, ceiling for min).
  Rectangle<int> roundIn() {
    final l = left.ceil();
    final t = top.ceil();
    final r = right.floor();
    final b = bottom.floor();
    if (r > l && b > t) {
      return Rectangle<int>(l, t, r - l, b - t);
    }
    // Return empty rectangle at original position if rounding makes it empty
    return Rectangle<int>(left.round(), top.round(), 0, 0);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Rectangle<T> &&
        other.left == left &&
        other.top == top &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() {
    return 'Rectangle($left, $top, $width × $height)';
  }

  /// Returns a string in LTRB format.
  String toLTRBString() {
    return 'Rectangle.fromLTRB($left, $top, $right, $bottom)';
  }
}

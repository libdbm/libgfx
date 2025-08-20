import 'dart:math';

import 'point.dart';
import 'utils/math_utils.dart';

/// An optimized 2D transformation matrix using 6 components.
///
/// The matrix is represented as:
/// | a  c  tx |
/// | b  d  ty |
/// | 0  0  1  |
///
/// Where:
/// - a, d: scaling factors for x and y
/// - b, c: shearing/rotation factors
/// - tx, ty: translation values
class Matrix2D {
  double a, b, c, d, tx, ty;

  /// Creates an identity matrix.
  Matrix2D.identity() : a = 1.0, b = 0.0, c = 0.0, d = 1.0, tx = 0.0, ty = 0.0;

  /// Creates a matrix with the specified components.
  Matrix2D(this.a, this.b, this.c, this.d, this.tx, this.ty);

  /// Creates a copy of another matrix.
  Matrix2D.copy(Matrix2D other)
    : a = other.a,
      b = other.b,
      c = other.c,
      d = other.d,
      tx = other.tx,
      ty = other.ty;

  /// Creates a translation matrix.
  factory Matrix2D.translation(double x, double y) {
    return Matrix2D(1.0, 0.0, 0.0, 1.0, x, y);
  }

  /// Creates a scaling matrix.
  factory Matrix2D.scaling(double sx, double sy) {
    return Matrix2D(sx, 0.0, 0.0, sy, 0.0, 0.0);
  }

  /// Creates a rotation matrix.
  factory Matrix2D.rotation(double radians) {
    final c = cos(radians);
    final s = sin(radians);
    return Matrix2D(c, s, -s, c, 0.0, 0.0);
  }

  /// Creates a deep copy of this matrix.
  Matrix2D clone() => Matrix2D.copy(this);

  /// Resets this matrix to identity.
  void setIdentity() {
    a = 1.0;
    b = 0.0;
    c = 0.0;
    d = 1.0;
    tx = 0.0;
    ty = 0.0;
  }

  /// Translates this matrix by the given values.
  void translate(double x, double y) {
    tx += a * x + c * y;
    ty += b * x + d * y;
  }

  /// Scales this matrix.
  void scale(double sx, [double? sy]) {
    sy ??= sx;
    a *= sx;
    b *= sx;
    c *= sy;
    d *= sy;
  }

  /// Rotates this matrix by the given angle in radians.
  void rotate(double radians) {
    final cosR = cos(radians);
    final sinR = sin(radians);

    final na = a * cosR + c * sinR;
    final nb = b * cosR + d * sinR;
    final nc = c * cosR - a * sinR;
    final nd = d * cosR - b * sinR;

    a = na;
    b = nb;
    c = nc;
    d = nd;
  }

  /// Alias for rotate method (for compatibility with old Matrix2D API).
  void rotateZ(double radians) => rotate(radians);

  /// Applies a shear transformation.
  void shear(double shx, double shy) {
    final na = a + c * shy;
    final nb = b + d * shy;
    final nc = c + a * shx;
    final nd = d + b * shx;

    a = na;
    b = nb;
    c = nc;
    d = nd;
  }

  /// Transforms a point by this matrix.
  Point transform(Point p) {
    return Point(a * p.x + c * p.y + tx, b * p.x + d * p.y + ty);
  }

  /// Transforms only the vector components (ignoring translation).
  Point transformVector(Point v) {
    return Point(a * v.x + c * v.y, b * v.x + d * v.y);
  }

  /// Inverts this matrix in place with improved numerical stability.
  /// Returns false if matrix is not invertible.
  bool invert() {
    final det = a * d - b * c;

    // Use relative tolerance for better numerical stability
    final maxElement = [
      a.abs(),
      b.abs(),
      c.abs(),
      d.abs(),
    ].reduce((a, b) => a > b ? a : b);
    final tolerance = maxElement * MathUtils.epsilon;

    if (det.abs() < tolerance) {
      // Matrix is singular or nearly singular
      // Set to identity to avoid NaN propagation
      a = 1.0;
      b = 0.0;
      c = 0.0;
      d = 1.0;
      tx = 0.0;
      ty = 0.0;
      return false;
    }

    // Use more numerically stable computation
    final invDet = 1.0 / det;

    // Calculate new values before assignment to avoid aliasing issues
    final na = d * invDet;
    final nb = -b * invDet;
    final nc = -c * invDet;
    final nd = a * invDet;
    final ntx = (c * ty - d * tx) * invDet;
    final nty = (b * tx - a * ty) * invDet;

    // Check for NaN or infinity
    if (!na.isFinite ||
        !nb.isFinite ||
        !nc.isFinite ||
        !nd.isFinite ||
        !ntx.isFinite ||
        !nty.isFinite) {
      // Numerical overflow, set to identity
      a = 1.0;
      b = 0.0;
      c = 0.0;
      d = 1.0;
      tx = 0.0;
      ty = 0.0;
      return false;
    }

    a = na;
    b = nb;
    c = nc;
    d = nd;
    tx = ntx;
    ty = nty;

    return true;
  }

  /// Returns the inverse of this matrix without modifying it.
  Matrix2D inverse() {
    final result = Matrix2D.copy(this);
    result.invert();
    return result;
  }

  /// Multiplies this matrix by another matrix.
  void multiply(Matrix2D other) {
    final na = a * other.a + c * other.b;
    final nb = b * other.a + d * other.b;
    final nc = a * other.c + c * other.d;
    final nd = b * other.c + d * other.d;
    final ntx = a * other.tx + c * other.ty + tx;
    final nty = b * other.tx + d * other.ty + ty;

    a = na;
    b = nb;
    c = nc;
    d = nd;
    tx = ntx;
    ty = nty;
  }

  /// Returns the result of multiplying this matrix by another.
  Matrix2D operator *(Matrix2D other) {
    final result = Matrix2D.copy(this);
    result.multiply(other);
    return result;
  }

  /// Pre-multiplies this matrix by another matrix.
  void preMultiply(Matrix2D other) {
    final na = other.a * a + other.c * b;
    final nb = other.b * a + other.d * b;
    final nc = other.a * c + other.c * d;
    final nd = other.b * c + other.d * d;
    final ntx = other.a * tx + other.c * ty + other.tx;
    final nty = other.b * tx + other.d * ty + other.ty;

    a = na;
    b = nb;
    c = nc;
    d = nd;
    tx = ntx;
    ty = nty;
  }

  /// Composes transformations: translation, rotation, scale.
  void setTransform(
    double x,
    double y,
    double rotation,
    double scaleX,
    double scaleY,
  ) {
    final cosR = cos(rotation);
    final sinR = sin(rotation);

    a = cosR * scaleX;
    b = sinR * scaleX;
    c = -sinR * scaleY;
    d = cosR * scaleY;
    tx = x;
    ty = y;
  }

  /// Gets the determinant of this matrix.
  double get determinant => a * d - b * c;

  /// Checks if this matrix is invertible.
  bool get isInvertible => determinant.abs() > MathUtils.epsilon;

  /// Checks if this matrix is identity.
  bool get isIdentity =>
      (a - 1.0).abs() < MathUtils.epsilon &&
      b.abs() < MathUtils.epsilon &&
      c.abs() < MathUtils.epsilon &&
      (d - 1.0).abs() < MathUtils.epsilon &&
      tx.abs() < MathUtils.epsilon &&
      ty.abs() < MathUtils.epsilon;

  /// Decomposes the matrix into translation, rotation, and scale components.
  void decompose(Point translation, List<double> rotation, Point scale) {
    translation.x = tx;
    translation.y = ty;

    final sx = sqrt(a * a + b * b);
    final sy = sqrt(c * c + d * d) * (determinant < 0 ? -1 : 1);

    scale.x = sx;
    scale.y = sy;

    rotation[0] = atan2(b, a);
  }

  @override
  String toString() {
    return 'Matrix2D('
        'a: ${a.toStringAsFixed(3)}, '
        'b: ${b.toStringAsFixed(3)}, '
        'c: ${c.toStringAsFixed(3)}, '
        'd: ${d.toStringAsFixed(3)}, '
        'tx: ${tx.toStringAsFixed(3)}, '
        'ty: ${ty.toStringAsFixed(3)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Matrix2D) return false;

    return (a - other.a).abs() < MathUtils.epsilon &&
        (b - other.b).abs() < MathUtils.epsilon &&
        (c - other.c).abs() < MathUtils.epsilon &&
        (d - other.d).abs() < MathUtils.epsilon &&
        (tx - other.tx).abs() < MathUtils.epsilon &&
        (ty - other.ty).abs() < MathUtils.epsilon;
  }

  @override
  int get hashCode => Object.hash(a, b, c, d, tx, ty);
}

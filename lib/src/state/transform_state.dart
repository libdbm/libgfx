import '../matrix.dart';
import '../result.dart';
import 'state_base.dart';

/// Manages transformation state
class TransformState extends StateBase<TransformState> {
  Matrix2D _transform;

  TransformState({Matrix2D? transform})
    : _transform = transform ?? Matrix2D.identity();

  Matrix2D get transformation => _transform;

  void transform(Matrix2D transform) {
    _transform = transform.clone();
  }

  void translate(double dx, double dy) {
    _transform.translate(dx, dy);
  }

  void scale(double sx, double sy) {
    _transform.scale(sx, sy);
  }

  void rotate(double angle) {
    _transform.rotate(angle);
  }

  void multiply(Matrix2D other) {
    _transform.multiply(other);
  }

  /// Inverse of the current transform, computed on each call because the
  /// matrix returned by [transformation] can be changed in place.
  Result<Matrix2D, ErrorDetails> inverse() => _transform.inverse();

  @override
  TransformState clone() {
    return TransformState(transform: _transform.clone());
  }
}

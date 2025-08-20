import '../matrix.dart';
import 'graphics_state_base.dart';

/// Manages transformation state
class TransformState extends GraphicsStateBase<TransformState> {
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

  void reset() {
    _transform = Matrix2D.identity();
  }

  Matrix2D inverse() {
    final inverse = _transform.clone();
    inverse.invert();
    return inverse;
  }

  @override
  TransformState clone() {
    return TransformState(transform: _transform.clone());
  }
}

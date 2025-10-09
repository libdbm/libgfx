import '../matrix.dart';
import 'state_base.dart';

/// Manages transformation state
class TransformState extends StateBase<TransformState> {
  Matrix2D _transform;
  Matrix2D? _cachedInverse;
  bool _inverseValid = false;

  TransformState({Matrix2D? transform})
    : _transform = transform ?? Matrix2D.identity();

  Matrix2D get transformation => _transform;

  void transform(Matrix2D transform) {
    _transform = transform.clone();
    _invalidateInverse();
  }

  void translate(double dx, double dy) {
    _transform.translate(dx, dy);
    _invalidateInverse();
  }

  void scale(double sx, double sy) {
    _transform.scale(sx, sy);
    _invalidateInverse();
  }

  void rotate(double angle) {
    _transform.rotate(angle);
    _invalidateInverse();
  }

  void multiply(Matrix2D other) {
    _transform.multiply(other);
    _invalidateInverse();
  }

  void reset() {
    _transform = Matrix2D.identity();
    _invalidateInverse();
  }

  void _invalidateInverse() {
    _inverseValid = false;
  }

  Matrix2D inverse() {
    if (!_inverseValid) {
      _cachedInverse = _transform.clone();
      _cachedInverse!.invert();
      _inverseValid = true;
    }
    return _cachedInverse!;
  }

  @override
  TransformState clone() {
    return TransformState(transform: _transform.clone());
  }
}

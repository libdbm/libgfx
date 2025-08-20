import '../graphics_state.dart';
import 'graphics_state_base.dart';

/// Manages stroke styling state
class StrokeState extends GraphicsStateBase<StrokeState> {
  double _strokeWidth;
  LineJoin _lineJoin;
  LineCap _lineCap;
  double _miterLimit;
  List<double>? _dashPattern;

  StrokeState({
    double strokeWidth = 1.0,
    LineJoin lineJoin = LineJoin.miter,
    LineCap lineCap = LineCap.butt,
    double miterLimit = 4.0,
    List<double>? dashPattern,
  }) : _strokeWidth = strokeWidth,
       _lineJoin = lineJoin,
       _lineCap = lineCap,
       _miterLimit = miterLimit,
       _dashPattern = dashPattern;

  double get strokeWidth => _strokeWidth;
  LineJoin get lineJoin => _lineJoin;
  LineCap get lineCap => _lineCap;
  double get miterLimit => _miterLimit;
  List<double>? get dashPattern => _dashPattern;

  void setStrokeWidth(double width) {
    _strokeWidth = GraphicsStateBase.validatePositive(
      width,
      'strokeWidth',
      1.0,
    );
  }

  void setLineJoin(LineJoin join) {
    _lineJoin = join;
  }

  void setLineCap(LineCap cap) {
    _lineCap = cap;
  }

  void setMiterLimit(double limit) {
    _miterLimit = GraphicsStateBase.validatePositive(limit, 'miterLimit', 4.0);
  }

  void setDashPattern(List<double>? pattern) {
    _dashPattern = pattern == null ? null : List.from(pattern);
  }

  bool hasDashPattern() {
    return _dashPattern != null && _dashPattern!.isNotEmpty;
  }

  @override
  StrokeState clone() {
    return StrokeState(
      strokeWidth: _strokeWidth,
      lineJoin: _lineJoin,
      lineCap: _lineCap,
      miterLimit: _miterLimit,
      dashPattern: _dashPattern == null ? null : List.from(_dashPattern!),
    );
  }
}

import '../graphics_state.dart';
import 'state_base.dart';

/// Manages stroke styling state
class StrokeState extends StateBase<StrokeState> {
  double _width;
  LineJoin _join;
  LineCap _cap;
  double _limit;
  List<double>? _pattern;

  StrokeState({
    double strokeWidth = 1.0,
    LineJoin lineJoin = LineJoin.miter,
    LineCap lineCap = LineCap.butt,
    double miterLimit = 4.0,
    List<double>? dashPattern,
  }) : _width = strokeWidth,
       _join = lineJoin,
       _cap = lineCap,
       _limit = miterLimit,
       _pattern = dashPattern;

  double get strokeWidth => _width;
  LineJoin get lineJoin => _join;
  LineCap get lineCap => _cap;
  double get miterLimit => _limit;
  List<double>? get dashPattern => _pattern;

  void setStrokeWidth(double width) {
    _width = StateBase.validatePositive(width, 1.0);
  }

  void setLineJoin(LineJoin join) {
    _join = join;
  }

  void setLineCap(LineCap cap) {
    _cap = cap;
  }

  void setMiterLimit(double limit) {
    _limit = StateBase.validatePositive(limit, 4.0);
  }

  void setDashPattern(List<double>? pattern) {
    _pattern = pattern == null ? null : List.from(pattern);
  }

  @override
  StrokeState clone() {
    return StrokeState(
      strokeWidth: _width,
      lineJoin: _join,
      lineCap: _cap,
      miterLimit: _limit,
      dashPattern: _pattern == null ? null : List.from(_pattern!),
    );
  }
}

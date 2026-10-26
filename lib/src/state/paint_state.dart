import '../color/color.dart';
import '../graphics_state.dart';
import '../paint.dart';
import 'state_base.dart';

/// Manages paint and styling state
class PaintState extends StateBase<PaintState> {
  Paint _fill;
  Paint _stroke;
  BlendMode _mode;
  double _alpha;

  PaintState({
    Paint? fillPaint,
    Paint? strokePaint,
    BlendMode blendMode = BlendMode.srcOver,
    double globalAlpha = 1.0,
  }) : _fill = fillPaint ?? const Color(0xFF000000),
       _stroke = strokePaint ?? const Color(0xFF000000),
       _mode = blendMode,
       _alpha = globalAlpha.clamp(0.0, 1.0);

  Paint get fillPaint => _fill;
  Paint get strokePaint => _stroke;
  BlendMode get blendMode => _mode;
  double get globalAlpha => _alpha;

  void setFillPaint(Paint paint) {
    _fill = paint;
  }

  void setStrokePaint(Paint paint) {
    _stroke = paint;
  }

  void setBlendMode(BlendMode mode) {
    _mode = mode;
  }

  void setGlobalAlpha(double alpha) {
    _alpha = alpha.clamp(0.0, 1.0);
  }

  @override
  PaintState clone() {
    return PaintState(
      fillPaint: _fill,
      strokePaint: _stroke,
      blendMode: _mode,
      globalAlpha: _alpha,
    );
  }
}

import '../color/color.dart';
import '../graphics_state.dart';
import '../paint.dart';
import 'graphics_state_base.dart';

/// Manages paint and styling state
class PaintState extends GraphicsStateBase<PaintState> {
  Paint _fillPaint;
  Paint _strokePaint;
  BlendMode _blendMode;
  double _globalAlpha;

  PaintState({
    Paint? fillPaint,
    Paint? strokePaint,
    BlendMode blendMode = BlendMode.srcOver,
    double globalAlpha = 1.0,
  }) : _fillPaint = fillPaint ?? SolidPaint(const Color(0xFF000000)),
       _strokePaint = strokePaint ?? SolidPaint(const Color(0xFF000000)),
       _blendMode = blendMode,
       _globalAlpha = globalAlpha.clamp(0.0, 1.0);

  Paint get fillPaint => _fillPaint;
  Paint get strokePaint => _strokePaint;
  BlendMode get blendMode => _blendMode;
  double get globalAlpha => _globalAlpha;

  void setFillPaint(Paint paint) {
    _fillPaint = paint;
  }

  void setStrokePaint(Paint paint) {
    _strokePaint = paint;
  }

  void setFillColor(Color color) {
    _fillPaint = SolidPaint(color);
  }

  void setStrokeColor(Color color) {
    _strokePaint = SolidPaint(color);
  }

  void setBlendMode(BlendMode mode) {
    _blendMode = mode;
  }

  void setGlobalAlpha(double alpha) {
    _globalAlpha = alpha.clamp(0.0, 1.0);
  }

  @override
  PaintState clone() {
    return PaintState(
      fillPaint: _fillPaint,
      strokePaint: _strokePaint,
      blendMode: _blendMode,
      globalAlpha: _globalAlpha,
    );
  }
}

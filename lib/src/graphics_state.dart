import 'clipping/clip_region.dart';
import 'color/color.dart';
import 'matrix.dart';
import 'paint.dart';
import 'paths/path.dart';
import 'state/clip_state.dart';
import 'state/paint_state.dart';
import 'state/stroke_state.dart';
import 'state/transform_state.dart';

/// Blend modes for compositing operations
enum BlendMode {
  // Porter-Duff compositing modes
  clear, // Clear destination
  src, // Replace destination with source
  dst, // Keep destination, ignore source
  srcOver, // Source over destination (default)
  dstOver, // Destination over source
  srcIn, // Source inside destination
  dstIn, // Destination inside source
  srcOut, // Source outside destination
  dstOut, // Destination outside source
  srcAtop, // Source on top, within destination
  dstAtop, // Destination on top, within source
  xor, // Exclusive OR of source and destination
  // Additional blend modes
  add, // Add source and destination
  multiply, // Multiply source and destination
  screen, // Screen blend mode
  overlay, // Overlay blend mode
  darken, // Use darker of source and destination
  lighten, // Use lighter of source and destination
  colorDodge, // Color dodge blend
  colorBurn, // Color burn blend
  hardLight, // Hard light blend
  softLight, // Soft light blend
  difference, // Difference blend
  exclusion, // Exclusion blend
}

/// Line join styles for stroked paths
enum LineJoin { miter, round, bevel }

/// Line cap styles for stroked paths
enum LineCap { butt, round, square }

/// Graphics state that manages rendering state using modular components
class GraphicsState {
  final TransformState _transformState;
  final ClipState _clipState;
  final PaintState _paintState;
  final StrokeState _strokeState;

  GraphicsState({
    Matrix2D? transform,
    Path? clipPath,
    ClipRegion? clipRegion,
    Paint? fillPaint,
    Paint? strokePaint,
    BlendMode blendMode = BlendMode.srcOver,
    double globalAlpha = 1.0,
    double strokeWidth = 1.0,
    LineJoin lineJoin = LineJoin.miter,
    LineCap lineCap = LineCap.butt,
    double miterLimit = 4.0,
    List<double>? dashPattern,
  }) : _transformState = TransformState(
         transform: transform ?? Matrix2D.identity(),
       ),
       _clipState = ClipState(clipPath: clipPath, clipRegion: clipRegion),
       _paintState = PaintState(
         fillPaint: fillPaint ?? SolidPaint(const Color(0xFF000000)),
         strokePaint: strokePaint ?? SolidPaint(const Color(0xFF000000)),
         blendMode: blendMode,
         globalAlpha: globalAlpha,
       ),
       _strokeState = StrokeState(
         strokeWidth: strokeWidth,
         lineJoin: lineJoin,
         lineCap: lineCap,
         miterLimit: miterLimit,
         dashPattern: dashPattern,
       );

  // For compatibility with existing code that expects a required transform parameter
  factory GraphicsState.withTransform({required Matrix2D transform}) {
    return GraphicsState(transform: transform);
  }

  // Transform properties
  Matrix2D get transform => _transformState.transformation;
  set transform(Matrix2D value) => _transformState.transform(value);

  // Clip properties
  Path? get clipPath => _clipState.clipPath;
  set clipPath(Path? value) {
    if (value != null) {
      _clipState.setClipPath(value);
    } else {
      _clipState.clearClip();
    }
  }

  ClipRegion? get clipRegion => _clipState.clipRegion;
  set clipRegion(ClipRegion? value) {
    if (value != null) {
      _clipState.setClipRegion(value);
    } else if (clipPath == null) {
      _clipState.clearClip();
    }
  }

  // Paint properties
  Paint get fillPaint => _paintState.fillPaint;
  set fillPaint(Paint value) => _paintState.setFillPaint(value);

  Paint get strokePaint => _paintState.strokePaint;
  set strokePaint(Paint value) => _paintState.setStrokePaint(value);

  BlendMode get blendMode => _paintState.blendMode;
  set blendMode(BlendMode value) => _paintState.setBlendMode(value);

  double get globalAlpha => _paintState.globalAlpha;
  set globalAlpha(double value) => _paintState.setGlobalAlpha(value);

  // Stroke properties
  double get strokeWidth => _strokeState.strokeWidth;
  set strokeWidth(double value) => _strokeState.setStrokeWidth(value);

  LineJoin get lineJoin => _strokeState.lineJoin;
  set lineJoin(LineJoin value) => _strokeState.setLineJoin(value);

  LineCap get lineCap => _strokeState.lineCap;
  set lineCap(LineCap value) => _strokeState.setLineCap(value);

  double get miterLimit => _strokeState.miterLimit;
  set miterLimit(double value) => _strokeState.setMiterLimit(value);

  List<double>? get dashPattern => _strokeState.dashPattern;
  set dashPattern(List<double>? value) => _strokeState.setDashPattern(value);

  /// Clone the current state
  GraphicsState clone() {
    return GraphicsState(
      transform: transform.clone(),
      clipPath: clipPath?.clone(),
      clipRegion: clipRegion,
      fillPaint: fillPaint,
      strokePaint: strokePaint,
      blendMode: blendMode,
      globalAlpha: globalAlpha,
      strokeWidth: strokeWidth,
      lineJoin: lineJoin,
      lineCap: lineCap,
      miterLimit: miterLimit,
      dashPattern: dashPattern == null ? null : List.from(dashPattern!),
    );
  }
}

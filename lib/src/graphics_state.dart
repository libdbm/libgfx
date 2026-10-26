import 'clipping/clip_region.dart';
import 'color/color.dart';
import 'fonts/font.dart';
import 'matrix.dart';
import 'paint.dart';
import 'paths/path.dart';
import 'result.dart';
import 'state/clip_state.dart';
import 'state/paint_state.dart';
import 'state/stroke_state.dart';
import 'state/text_state.dart';
import 'text/text_rendering.dart';
import 'text/text_types.dart';
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
  final TransformState _transform;
  final ClipState _clip;
  final PaintState _paint;
  final StrokeState _stroke;
  final TextState _text;

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
    Font? font,
    double fontSize = 12.0,
    TextAlign textAlign = TextAlign.start,
    TextBaseline textBaseline = TextBaseline.alphabetic,
    TextDirection direction = TextDirection.ltr,
    TextRendering textRendering = TextRendering.auto,
  }) : _transform = TransformState(transform: transform ?? Matrix2D.identity()),
       _clip = ClipState(clipPath: clipPath, clipRegion: clipRegion),
       _paint = PaintState(
         fillPaint: fillPaint ?? const Color(0xFF000000),
         strokePaint: strokePaint ?? const Color(0xFF000000),
         blendMode: blendMode,
         globalAlpha: globalAlpha,
       ),
       _stroke = StrokeState(
         strokeWidth: strokeWidth,
         lineJoin: lineJoin,
         lineCap: lineCap,
         miterLimit: miterLimit,
         dashPattern: dashPattern,
       ),
       _text = TextState(
         font: font,
         fontSize: fontSize,
         textAlign: textAlign,
         textBaseline: textBaseline,
         direction: direction,
         textRendering: textRendering,
       );

  // For compatibility with existing code that expects a required transform parameter
  factory GraphicsState.withTransform({required Matrix2D transform}) {
    return GraphicsState(transform: transform);
  }

  // Transform properties
  Matrix2D get transform => _transform.transformation;
  set transform(Matrix2D value) => _transform.transform(value);

  Result<Matrix2D, ErrorDetails> get inverse => _transform.inverse();

  // Clip properties
  Path? get clipPath => _clip.clipPath;
  set clipPath(Path? value) {
    if (value != null) {
      _clip.setClipPath(value);
    } else {
      _clip.clearClip();
    }
  }

  ClipRegion? get clipRegion => _clip.clipRegion;
  set clipRegion(ClipRegion? value) {
    if (value != null) {
      _clip.setClipRegion(value);
    } else if (clipPath == null) {
      _clip.clearClip();
    }
  }

  // Paint properties
  Paint get fillPaint => _paint.fillPaint;
  set fillPaint(Paint value) => _paint.setFillPaint(value);

  Paint get strokePaint => _paint.strokePaint;
  set strokePaint(Paint value) => _paint.setStrokePaint(value);

  BlendMode get blendMode => _paint.blendMode;
  set blendMode(BlendMode value) => _paint.setBlendMode(value);

  double get globalAlpha => _paint.globalAlpha;
  set globalAlpha(double value) => _paint.setGlobalAlpha(value);

  // Stroke properties
  double get strokeWidth => _stroke.strokeWidth;
  set strokeWidth(double value) => _stroke.setStrokeWidth(value);

  LineJoin get lineJoin => _stroke.lineJoin;
  set lineJoin(LineJoin value) => _stroke.setLineJoin(value);

  LineCap get lineCap => _stroke.lineCap;
  set lineCap(LineCap value) => _stroke.setLineCap(value);

  double get miterLimit => _stroke.miterLimit;
  set miterLimit(double value) => _stroke.setMiterLimit(value);

  List<double>? get dashPattern => _stroke.dashPattern;
  set dashPattern(List<double>? value) => _stroke.setDashPattern(value);

  // Text properties
  Font? get font => _text.font;
  set font(Font? value) => _text.setFont(value);

  double get fontSize => _text.fontSize;
  set fontSize(double value) => _text.setFontSize(value);

  TextAlign get textAlign => _text.textAlign;
  set textAlign(TextAlign value) => _text.setTextAlign(value);

  TextBaseline get textBaseline => _text.textBaseline;
  set textBaseline(TextBaseline value) => _text.setTextBaseline(value);

  TextDirection get direction => _text.direction;
  set direction(TextDirection value) => _text.setDirection(value);

  TextRendering get textRendering => _text.textRendering;
  set textRendering(TextRendering value) => _text.setTextRendering(value);

  /// Clone the current state
  GraphicsState clone() {
    return GraphicsState(
      transform: transform.clone(),
      clipPath: clipPath?.clone(),
      clipRegion: clipRegion?.clone(),
      fillPaint: fillPaint,
      strokePaint: strokePaint,
      blendMode: blendMode,
      globalAlpha: globalAlpha,
      strokeWidth: strokeWidth,
      lineJoin: lineJoin,
      lineCap: lineCap,
      miterLimit: miterLimit,
      dashPattern: dashPattern == null ? null : List.from(dashPattern!),
      font: font,
      fontSize: fontSize,
      textAlign: textAlign,
      textBaseline: textBaseline,
      direction: direction,
      textRendering: textRendering,
    );
  }
}

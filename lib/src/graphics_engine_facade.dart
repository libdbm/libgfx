import 'dart:math' show max, min;
import 'dart:typed_data';

import 'image/bitmap.dart';
import 'image/codecs/bmp_codec.dart';
import 'image/codecs/p3_codec.dart';
import 'image/codecs/p6_codec.dart';
import 'color/color.dart';
import 'fonts/font.dart';
import 'fonts/ttf/ttf_font.dart';
import 'graphics_context.dart';
import 'graphics_state.dart';
import 'image/codecs/png_codec.dart';
import 'image/image_data.dart';
import 'image/image_codec.dart';
import 'image/image_renderer.dart' show ImageFilter;
import 'limits.dart';
import 'result.dart';
import 'matrix.dart';
import 'paint.dart'
    show
        Paint,
        LinearGradient,
        RadialGradient,
        ConicalGradient,
        PatternPaint,
        PatternRepeat;
import 'paths/path.dart';
import 'point.dart';
import 'rasterize/rasterizer.dart';
import 'rectangle.dart';
import 'text/text_engine.dart';
import 'text/text_rendering.dart';
import 'text/text_types.dart'
    show TextAlign, TextBaseline, TextDirection, TextMetrics;
import 'io/file_system.dart';

/// A simple facade for the entire graphics engine.
///
/// This class provides a high-level API to create a canvas and perform
/// drawing operations, hiding the underlying complexity of the GraphicsContext.
class GraphicsEngine {
  late final Bitmap canvas;
  late final GraphicsContext _context;
  late final TextEngine _engine;
  GraphicsFileSystem? _filesystem;

  /// Sequence number of the latest font request; a slower earlier request
  /// must not replace the font chosen by a newer one.
  int _request = 0;

  /// Creates a new graphics engine with a canvas of the specified size.
  /// Optionally accepts a custom rasterizer implementation.
  GraphicsEngine(
    int width,
    int height, {
    Rasterizer? rasterizer,
    GraphicsFileSystem? filesystem,
    Limits limits = const Limits(),
  }) : this.withCanvas(
         Bitmap(width, height),
         rasterizer: rasterizer,
         filesystem: filesystem,
         limits: limits,
       );

  /// Creates a new graphics engine using a bitmap as a canvas
  /// Optionally accepts a custom rasterizer implementation.
  GraphicsEngine.withCanvas(
    final Bitmap bitmap, {
    Rasterizer? rasterizer,
    GraphicsFileSystem? filesystem,
    Limits limits = const Limits(),
  }) {
    canvas = bitmap;
    _context = GraphicsContext(canvas, rasterizer: rasterizer, limits: limits);
    _engine = TextEngine();
    _filesystem = filesystem;
  }

  /// Current filesystem adapter used for font/image IO.
  GraphicsFileSystem? get filesystem => _filesystem;

  set filesystem(GraphicsFileSystem? value) {
    _filesystem = value;
  }

  /// Intersects the clip with [path], using [rule] to decide which areas
  /// are inside (non-zero by default, as W3C canvas `clip` does).
  void clip(final Path path, {final FillRule rule = FillRule.nonZero}) {
    _context.clip(path, rule: rule);
  }

  /// Intersects the clip with a rectangle.
  void clipRect(
    final double x,
    final double y,
    final double width,
    final double height,
  ) {
    clip(PathBuilder().rect(x, y, width, height).build());
  }

  /// Sets the transformation matrix for the graphics engine
  void setTransform(
    double a,
    double b,
    double c,
    double d,
    double e,
    double f,
  ) {
    _context.state.transform = Matrix2D(a, b, c, d, e, f);
  }

  /// Resets the transformation matrix to identity
  void resetTransform() {
    _context.state.transform = Matrix2D.identity();
  }

  /// Transforms the current transformation matrix
  void transform(double a, double b, double c, double d, double e, double f) {
    final matrix = Matrix2D(a, b, c, d, e, f);
    _context.state.transform.multiply(matrix);
  }

  /// Translates the current transformation matrix
  void translate(double x, double y) {
    _context.state.transform.translate(x, y);
  }

  /// Rotates the current transformation matrix
  void rotate(double angle) {
    _context.state.transform.rotate(angle);
  }

  /// Scales the current transformation matrix
  void scale(double x, [double? y]) {
    _context.state.transform.scale(x, y ?? x);
  }

  /// Saves the current graphics state
  void save() {
    _context.save();
  }

  /// Restores the previously saved graphics state
  void restore() {
    _context.restore();
  }

  /// The paint used by fills; a [Color] paints solid
  Paint get fillStyle => _context.state.fillPaint;
  set fillStyle(final Paint paint) => _context.state.fillPaint = paint;

  /// The paint used by strokes; a [Color] paints solid
  Paint get strokeStyle => _context.state.strokePaint;
  set strokeStyle(final Paint paint) => _context.state.strokePaint = paint;

  /// The stroke width
  double get lineWidth => _context.state.strokeWidth;
  set lineWidth(final double width) => _context.state.strokeWidth = width;

  /// The shape at the ends of open strokes
  LineCap get lineCap => _context.state.lineCap;
  set lineCap(final LineCap cap) => _context.state.lineCap = cap;

  /// The shape where stroke segments meet
  LineJoin get lineJoin => _context.state.lineJoin;
  set lineJoin(final LineJoin join) => _context.state.lineJoin = join;

  /// The miter length, in stroke widths, beyond which a miter join is
  /// drawn as a bevel
  double get miterLimit => _context.state.miterLimit;
  set miterLimit(final double limit) => _context.state.miterLimit = limit;

  /// Sets the dash pattern for stroking
  ///
  /// The pattern is an array of distances specifying alternating lengths
  /// of dashes and gaps. If the array is empty, lines are drawn solid.
  void setLineDash(List<double> segments) {
    _context.state.dashPattern = segments;
  }

  // Note: Dash offset is not currently supported in the underlying implementation
  // Future versions may add this feature to the StrokeState and Dasher classes

  /// The opacity applied to everything drawn, from 0 to 1
  double get globalAlpha => _context.state.globalAlpha;
  set globalAlpha(final double alpha) => _context.state.globalAlpha = alpha;

  /// The blend mode used to composite what is drawn
  BlendMode get globalCompositeOperation => _context.state.blendMode;
  set globalCompositeOperation(final BlendMode mode) =>
      _context.state.blendMode = mode;

  /// Fills the given path with the current fill style, using [rule] to
  /// decide which areas are inside (non-zero by default). With [text], the
  /// path is drawn as [fillText] draws text, with partly covered pixels
  /// darkened unless [textRendering] is [TextRendering.geometricPrecision];
  /// use it for glyph outlines from [TextRenderer] or [Font.path].
  void fill(
    final Path path, {
    final FillRule rule = FillRule.nonZero,
    final bool text = false,
  }) {
    _context.fill(path, rule: rule, text: text && _legible);
  }

  /// Strokes the given path with the current stroke style
  void stroke(Path path) {
    _context.stroke(path);
  }

  /// Fills a rectangle with the current fill style
  void fillRect(double x, double y, double width, double height) {
    fill(PathBuilder().rect(x, y, width, height).build());
  }

  /// Strokes a rectangle with the current stroke style
  void strokeRect(double x, double y, double width, double height) {
    stroke(PathBuilder().rect(x, y, width, height).build());
  }

  /// Clears a rectangular area to transparent
  void clearRect(double x, double y, double width, double height) {
    save();
    try {
      globalCompositeOperation = BlendMode.clear;
      fillRect(x, y, width, height);
    } finally {
      restore();
    }
  }

  /// Creates a linear gradient paint
  LinearGradient createLinearGradient(
    double x0,
    double y0,
    double x1,
    double y1,
  ) {
    return LinearGradient(
      start: Point(x0, y0),
      end: Point(x1, y1),
      stops: const [], // Add stops with gradient.addColorStop(...)
    );
  }

  /// Creates a radial gradient paint
  RadialGradient createRadialGradient(
    final double x0,
    final double y0,
    double r0,
    final double x1,
    final double y1,
    double r1,
  ) {
    // RadialGradient only supports a single center and radius
    // Using the outer circle parameters
    return RadialGradient(
      center: Point(x1, y1),
      radius: r1,
      stops: const [], // Add stops with gradient.addColorStop(...)
      focal: r0 > 0 ? Point(x0, y0) : null,
    );
  }

  /// Creates a conic gradient starting at [startAngle] around (x, y), with
  /// the W3C canvas argument order
  ConicalGradient createConicGradient(
    final double startAngle,
    final double x,
    final double y,
  ) {
    return ConicalGradient(
      center: Point(x, y),
      startAngle: startAngle,
      stops: const [], // Add stops with gradient.addColorStop(...)
    );
  }

  /// Creates a pattern paint from a bitmap
  PatternPaint createPattern(
    Bitmap image,
    PatternRepeat repeat, [
    Matrix2D? transform,
  ]) {
    return PatternPaint(pattern: image, repeat: repeat, transform: transform);
  }

  /// Writes the canvas to [path], detecting the format from its extension
  /// unless [format] is given.
  Future<void> write(final String path, {final String? format}) async {
    final system = _filesystem;
    if (system == null) {
      throw UnsupportedError(
        'No GraphicsFileSystem configured. Attach one via the constructor or the filesystem setter before calling write.',
      );
    }

    final bytes = encode(canvas, format ?? _format(path) ?? 'p6');
    await system.write(path, bytes);
  }

  /// The format named by the extension of [path], or null
  String? _format(final String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) {
      return null;
    }

    final extension = path.substring(dot + 1).toLowerCase();
    switch (extension) {
      case 'png':
      case 'bmp':
      case 'p3':
      case 'p6':
        return extension;
      case 'ppm':
        return 'p6';
      default:
        return null;
    }
  }

  /// A copy of the canvas pixels in the [width] by [height] rectangle at
  /// (x, y), in bitmap coordinates (from the top left, ignoring the
  /// transform), as W3C canvas `getImageData` returns them; pixels outside
  /// the canvas are transparent black
  ImageData getImageData(
    final int x,
    final int y,
    final int width,
    final int height,
  ) {
    final image = ImageData(width, height);
    final data = image.data;
    for (var row = 0; row < height; row++) {
      for (var column = 0; column < width; column++) {
        final color = canvas.pixel(x + column, y + row);
        final index = (row * width + column) * 4;
        data[index] = color.red;
        data[index + 1] = color.green;
        data[index + 2] = color.blue;
        data[index + 3] = color.alpha;
      }
    }
    return image;
  }

  /// Writes the pixels of [image] to the canvas with its top left corner at
  /// (dx, dy), in bitmap coordinates, as W3C canvas `putImageData` does:
  /// pixels are replaced, ignoring the transform, clip, alpha and
  /// composite operation. Only the dirty rectangle of [image] is written,
  /// at its own offset from (dx, dy); a negative size extends it left or up
  void putImageData(
    final ImageData image,
    final int dx,
    final int dy, [
    final int dirtyX = 0,
    final int dirtyY = 0,
    final int? dirtyWidth,
    final int? dirtyHeight,
  ]) {
    final width = dirtyWidth ?? image.width;
    final height = dirtyHeight ?? image.height;
    final left = max(0, width < 0 ? dirtyX + width : dirtyX);
    final top = max(0, height < 0 ? dirtyY + height : dirtyY);
    final right = min(image.width, width < 0 ? dirtyX : dirtyX + width);
    final bottom = min(image.height, height < 0 ? dirtyY : dirtyY + height);

    final data = image.data;
    for (var row = top; row < bottom; row++) {
      for (var column = left; column < right; column++) {
        final index = (row * image.width + column) * 4;
        canvas.plot(
          dx + column,
          dy + row,
          Color.fromRGBA(
            data[index],
            data[index + 1],
            data[index + 2],
            data[index + 3],
          ),
        );
      }
    }
  }

  /// Draws [image] with its corner at (dx, dy), scaled to [width] by
  /// [height] when given, as the W3C canvas `drawImage` forms do. [source]
  /// selects part of the image; [filter] samples scaled or transformed
  /// images (nearest neighbour by default).
  void drawImage(
    final Bitmap image,
    final double dx,
    final double dy, {
    final double? width,
    final double? height,
    final Rectangle<double>? source,
    final ImageFilter filter = ImageFilter.nearest,
  }) {
    if (source != null) {
      _context.drawImageRect(
        image,
        source.left,
        source.top,
        source.width,
        source.height,
        dx,
        dy,
        width ?? source.width,
        height ?? source.height,
        filter: filter,
      );
    } else if (width != null || height != null) {
      _context.drawImageScaled(
        image,
        dx,
        dy,
        width ?? image.width.toDouble(),
        height ?? image.height.toDouble(),
        filter: filter,
      );
    } else {
      _context.drawImage(image, dx, dy, filter: filter);
    }
  }

  // ============================================================================
  // Text Rendering
  // ============================================================================

  /// Sets the current font from a file. On failure the current font is
  /// kept. If another font request is made before this one completes, this
  /// result is returned but does not replace the newer font.
  Future<Result<TTFFont, ErrorDetails>> loadFont(final String path) async {
    final system = _filesystem;
    if (system == null) {
      throw UnsupportedError(
        'No GraphicsFileSystem configured. Attach one via the constructor or the filesystem setter before calling loadFont.',
      );
    }

    final request = ++_request;
    final result = await TTFFont.load(
      path,
      filesystem: system,
      limits: _context.limits,
    );
    if (result case Ok(:final value) when request == _request) {
      _context.state.font = value;
    }
    return result;
  }

  /// Sets the current font from bytes. On failure the current font is kept.
  Result<TTFFont, ErrorDetails> readFont(final Uint8List bytes) {
    ++_request;
    final result = TTFFont.fromBytes(bytes, limits: _context.limits);
    if (result case Ok(:final value)) {
      _context.state.font = value;
    }
    return result;
  }

  /// The font size in pixels
  double get fontSize => _context.state.fontSize;
  set fontSize(final double size) => _context.state.fontSize = size;

  /// The horizontal alignment of text relative to its x position
  TextAlign get textAlign => _context.state.textAlign;
  set textAlign(final TextAlign align) => _context.state.textAlign = align;

  /// The vertical alignment of text relative to its y position
  TextBaseline get textBaseline => _context.state.textBaseline;
  set textBaseline(final TextBaseline baseline) =>
      _context.state.textBaseline = baseline;

  /// The direction of text, as W3C canvas `direction`: the paragraph
  /// direction for ordering right-to-left text, and the side that
  /// [TextAlign.start] and [TextAlign.end] mean. Left to right by default.
  TextDirection get direction => _context.state.direction;
  set direction(final TextDirection direction) =>
      _context.state.direction = direction;

  /// Fills text at the specified position using the current fill style
  void fillText(String text, double x, double y) {
    final path = _text.path(text, x, y);
    _context.fill(path, text: _legible);
  }

  /// Strokes text at the specified position using the current stroke style
  void strokeText(String text, double x, double y) {
    final path = _text.path(text, x, y);
    _context.stroke(path, text: _legible);
  }

  /// Whether text takes the contrast curve: every [textRendering] but
  /// [TextRendering.geometricPrecision]
  bool get _legible =>
      _context.state.textRendering != TextRendering.geometricPrecision;

  /// How text is rasterized, as W3C canvas `textRendering`
  TextRendering get textRendering => _context.state.textRendering;
  set textRendering(final TextRendering rendering) =>
      _context.state.textRendering = rendering;

  /// Uses text as a clipping path
  void clipText(String text, double x, double y) {
    final path = _text.path(text, x, y);
    clip(path);
  }

  /// Measures text and returns metrics
  TextMetrics measureText(String text) {
    return _text.measure(text);
  }

  /// The current font, or null before one is set. Setting it cancels the
  /// result of a pending [loadFont].
  Font? get font => _text.font;
  set font(final Font? value) {
    ++_request;
    _context.state.font = value;
  }

  /// The text engine, configured from the text settings of the current
  /// state, which [save] and [restore] cover.
  TextEngine get _text => _engine
    ..font = _context.state.font
    ..fontSize = _context.state.fontSize
    ..textAlign = _context.state.textAlign
    ..textBaseline = _context.state.textBaseline
    ..direction = _context.state.direction;

  /// The color of the canvas pixel at (x, y), in bitmap coordinates
  Color pixel(final int x, final int y) => canvas.pixel(x, y);

  /// Sets the canvas pixel at (x, y), in bitmap coordinates, to [color]
  void plot(final int x, final int y, final Color color) {
    canvas.plot(x, y, color);
  }

  /// Get the canvas width
  int get width => canvas.width;

  /// Get the canvas height
  int get height => canvas.height;

  /// Clear the entire canvas to a specific color
  void clear([Color color = const Color(0x00000000)]) {
    canvas.clear(color);
  }

  /// A copy of the canvas
  Bitmap snapshot() {
    // Create a copy of the bitmap
    final copy = Bitmap(canvas.width, canvas.height);
    for (int y = 0; y < canvas.height; y++) {
      for (int x = 0; x < canvas.width; x++) {
        copy.plot(x, y, canvas.pixel(x, y));
      }
    }
    return copy;
  }

  /// Get the current graphics context (for advanced usage)
  GraphicsContext get context => _context;

  // ============================================================================
  // Image Loading/Saving
  // ============================================================================

  /// Load an image from bytes (PNG, BMP, P3/P6 PPM). Without a [format]
  /// name the format is detected from the data; see [ImageLoader].
  static Result<Bitmap, ErrorDetails> decode(
    final Uint8List bytes, {
    String? format,
    Limits limits = const Limits(),
  }) => ImageLoader.loadFromBytes(bytes, format: format, limits: limits);

  /// Encodes [image] in [format] (png, bmp, p3 or ppm, p6)
  static Uint8List encode(final Bitmap image, final String format) {
    switch (format.toLowerCase()) {
      case 'png':
        final codec = PngImageCodec();
        return codec.encode(image);
      case 'bmp':
        final codec = BmpImageCodec();
        return codec.encode(image);
      case 'ppm':
      case 'p3':
        final codec = P3ImageCodec();
        return codec.encode(image);
      case 'p6':
        final codec = P6ImageCodec();
        return codec.encode(image);
      default:
        throw UnsupportedError('Unsupported image format: $format');
    }
  }
}

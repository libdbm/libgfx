import 'dart:io';
import 'dart:typed_data';

import 'image/bitmap.dart';
import 'image/codecs/bmp_codec.dart';
import 'image/codecs/p3_codec.dart';
import 'image/codecs/p6_codec.dart';
import 'clipping/clip_region.dart';
import 'color/color.dart';
import 'color/color_utils.dart';
import 'errors.dart';
import 'fonts/font.dart';
import 'fonts/font_error_messages.dart';
import 'fonts/ttf/ttf_font.dart';
import 'graphics_context.dart';
import 'graphics_state.dart';
import 'image/codecs/png_codec.dart';
import 'matrix.dart';
import 'paint.dart'
    show
        Paint,
        SolidPaint,
        LinearGradient,
        RadialGradient,
        ConicalGradient,
        PatternPaint,
        PatternRepeat;
import 'paths/path.dart';
import 'point.dart';
import 'rasterize/rasterizer.dart';
import 'text/text_engine.dart';
import 'text/text_types.dart' show TextAlign, TextBaseline, TextMetrics;
import 'paths/path_utils.dart';

/// A simple facade for the entire graphics engine.
///
/// This class provides a high-level API to create a canvas and perform
/// drawing operations, hiding the underlying complexity of the GraphicsContext.
class GraphicsEngine {
  late final Bitmap canvas;
  late final GraphicsContext _context;
  late final TextEngine _textEngine;

  // Text properties for backward compatibility
  Font? _currentFont;
  double _fontSize = 12.0;
  TextAlign _textAlign = TextAlign.left;
  TextBaseline _textBaseline = TextBaseline.alphabetic;

  /// Creates a new graphics engine with a canvas of the specified size.
  /// Optionally accepts a custom rasterizer implementation.
  GraphicsEngine(int width, int height, {Rasterizer? rasterizer}) {
    GraphicsEngine.withCanvas(Bitmap(width, height), rasterizer: rasterizer);
  }

  /// Creates a new graphics engine using a bitmap as a canvas
  /// Optionally accepts a custom rasterizer implementation.
  GraphicsEngine.withCanvas(Bitmap canvas, {Rasterizer? rasterizer}) {
    _context = GraphicsContext(canvas, rasterizer: rasterizer);
    _textEngine = TextEngine(
      fontSize: _fontSize,
      textAlign: _textAlign,
      textBaseline: _textBaseline,
    );
  }

  /// Sets the current path to be used as a clipping mask.
  void clip(Path path) {
    _context.clip(path);
  }

  /// Sets a rectangular clipping region.
  void clipRect(double x, double y, double width, double height) {
    clip(createRectanglePath(x, y, width, height));
  }

  /// Sets the current path to be used as a clipping mask with a specific fill rule.
  ///
  /// The fill rule determines how the interior of the path is calculated:
  /// - [FillRule.evenOdd]: Alternating fill (default for most graphics systems)
  /// - [FillRule.nonZero]: Non-zero winding rule
  void clipWithFillRule(Path path, {FillRule fillRule = FillRule.evenOdd}) {
    final advancedClip = ClipRegion.fromPath(
      path,
      _context.state.transform,
      canvas.width,
      canvas.height,
      fillRule: fillRule,
    );
    _context.clipWithAdvancedRegion(advancedClip);
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

  /// Sets the current fill paint
  void setFillPaint(Paint paint) {
    _context.state.fillPaint = paint;
  }

  /// Sets the fill color
  void setFillColor(Color color) {
    setFillPaint(SolidPaint(color));
  }

  /// Sets the fill style using hex color string (e.g., "#FF0000" or "#FF0000FF")
  void setFillStyle(String style) {
    setFillColor(ColorUtils.parseHexColor(style));
  }

  /// Sets the current stroke paint
  void setStrokePaint(Paint paint) {
    _context.state.strokePaint = paint;
  }

  /// Sets the stroke color
  void setStrokeColor(Color color) {
    setStrokePaint(SolidPaint(color));
  }

  /// Sets the stroke style using hex color string (e.g., "#FF0000" or "#FF0000FF")
  void setStrokeStyle(String style) {
    setStrokeColor(ColorUtils.parseHexColor(style));
  }

  /// Sets the line width for stroking
  void setLineWidth(double width) {
    _context.state.strokeWidth = width;
  }

  /// Sets the line cap style
  void setLineCap(LineCap cap) {
    _context.state.lineCap = cap;
  }

  /// Sets the line join style
  void setLineJoin(LineJoin join) {
    _context.state.lineJoin = join;
  }

  /// Sets the miter limit for line joins
  void setMiterLimit(double limit) {
    _context.state.miterLimit = limit;
  }

  /// Sets the dash pattern for stroking
  ///
  /// The pattern is an array of distances specifying alternating lengths
  /// of dashes and gaps. If the array is empty, lines are drawn solid.
  void setLineDash(List<double> segments) {
    _context.state.dashPattern = segments;
  }

  // Note: Dash offset is not currently supported in the underlying implementation
  // Future versions may add this feature to the StrokeState and Dasher classes

  /// Sets the global alpha (opacity) value
  void setGlobalAlpha(double alpha) {
    _context.state.globalAlpha = alpha;
  }

  /// Sets the global composite operation (blend mode)
  void setGlobalCompositeOperation(BlendMode mode) {
    _context.state.blendMode = mode;
  }

  /// Fills the given path with the current fill style
  void fill(Path path) {
    _context.fill(path);
  }

  /// Strokes the given path with the current stroke style
  void stroke(Path path) {
    _context.stroke(path);
  }

  /// Fills a rectangle with the current fill style
  void fillRect(double x, double y, double width, double height) {
    fill(createRectanglePath(x, y, width, height));
  }

  /// Strokes a rectangle with the current stroke style
  void strokeRect(double x, double y, double width, double height) {
    stroke(createRectanglePath(x, y, width, height));
  }

  /// Clears a rectangular area to transparent
  void clearRect(double x, double y, double width, double height) {
    save();
    setGlobalCompositeOperation(BlendMode.clear);
    fillRect(x, y, width, height);
    restore();
  }

  /// Fills a rounded rectangle
  void fillRoundRect(
    double x,
    double y,
    double width,
    double height,
    double radius,
  ) {
    fill(createRoundedRectanglePath(x, y, width, height, radius));
  }

  /// Strokes a rounded rectangle
  void strokeRoundRect(
    double x,
    double y,
    double width,
    double height,
    double radius,
  ) {
    stroke(createRoundedRectanglePath(x, y, width, height, radius));
  }

  /// Fills a circle
  void fillCircle(double cx, double cy, double radius) {
    fill(createCirclePath(cx, cy, radius));
  }

  /// Strokes a circle
  void strokeCircle(double cx, double cy, double radius) {
    stroke(createCirclePath(cx, cy, radius));
  }

  /// Fills an ellipse
  void fillEllipse(double cx, double cy, double rx, double ry) {
    fill(createEllipsePath(cx, cy, rx, ry));
  }

  /// Strokes an ellipse
  void strokeEllipse(double cx, double cy, double rx, double ry) {
    stroke(createEllipsePath(cx, cy, rx, ry));
  }

  /// Fills a polygon
  void fillPolygon(double cx, double cy, double radius, int sides) {
    fill(createPolygonPath(cx, cy, radius, sides));
  }

  /// Strokes a polygon
  void strokePolygon(double cx, double cy, double radius, int sides) {
    stroke(createPolygonPath(cx, cy, radius, sides));
  }

  /// Fills a star
  void fillStar(
    double cx,
    double cy,
    double outerRadius,
    double innerRadius,
    int points,
  ) {
    fill(createStarPath(cx, cy, outerRadius, innerRadius, points));
  }

  /// Strokes a star
  void strokeStar(
    double cx,
    double cy,
    double outerRadius,
    double innerRadius,
    int points,
  ) {
    stroke(createStarPath(cx, cy, outerRadius, innerRadius, points));
  }

  /// Creates a linear gradient paint
  LinearGradient createLinearGradient(
    double x0,
    double y0,
    double x1,
    double y1,
  ) {
    return LinearGradient(
      startPoint: Point(x0, y0),
      endPoint: Point(x1, y1),
      stops: [], // Stops should be added using addColorStop
    );
  }

  /// Creates a radial gradient paint
  RadialGradient createRadialGradient(
    double cx0,
    double cy0,
    double r0,
    double cx1,
    double cy1,
    double r1,
  ) {
    // RadialGradient only supports a single center and radius
    // Using the outer circle parameters
    return RadialGradient(
      center: Point(cx1, cy1),
      radius: r1,
      stops: [], // Stops should be added using addColorStop
      focal: r0 > 0 ? Point(cx0, cy0) : null,
    );
  }

  /// Creates a conic gradient paint
  ConicalGradient createConicGradient(double cx, double cy, double angle) {
    return ConicalGradient(
      center: Point(cx, cy),
      startAngle: angle,
      stops: [], // Stops should be added using addColorStop
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

  /// Saves the canvas as a PPM image file
  Future<void> saveToFile(String filename) async {
    final file = File(filename);

    // Create directory if it doesn't exist
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Write PPM header
    final buffer = StringBuffer();
    buffer.writeln('P6');
    buffer.writeln('${canvas.width} ${canvas.height}');
    buffer.writeln('255');

    // Write pixel data
    final bytes = <int>[];
    bytes.addAll(buffer.toString().codeUnits);

    for (int y = 0; y < canvas.height; y++) {
      for (int x = 0; x < canvas.width; x++) {
        final color = canvas.getPixel(x, y);
        bytes.add(color.red);
        bytes.add(color.green);
        bytes.add(color.blue);
      }
    }

    await file.writeAsBytes(bytes);
  }

  /// Gets the canvas bitmap data as bytes
  Uint8List getImageData() {
    return canvas.pixels.buffer.asUint8List();
  }

  /// Puts image data onto the canvas
  void putImageData(
    Uint8List data,
    int dx,
    int dy, [
    int? dirtyX,
    int? dirtyY,
    int? dirtyWidth,
    int? dirtyHeight,
  ]) {
    // Simplified implementation - copy data to canvas
    final srcX = dirtyX ?? 0;
    final srcY = dirtyY ?? 0;
    final width = dirtyWidth ?? canvas.width;
    final height = dirtyHeight ?? canvas.height;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (dx + x >= 0 &&
            dx + x < canvas.width &&
            dy + y >= 0 &&
            dy + y < canvas.height) {
          final srcIndex = ((srcY + y) * canvas.width + (srcX + x)) * 4;
          if (srcIndex + 3 < data.length) {
            final color = Color.fromRGBA(
              data[srcIndex],
              data[srcIndex + 1],
              data[srcIndex + 2],
              data[srcIndex + 3],
            );
            canvas.setPixel(dx + x, dy + y, color);
          }
        }
      }
    }
  }

  /// Draws an image onto the canvas
  void drawImage(Bitmap image, double dx, double dy) {
    _context.drawImage(image, dx, dy);
  }

  /// Draws a scaled image onto the canvas
  void drawImageScaled(
    Bitmap image,
    double dx,
    double dy,
    double dw,
    double dh,
  ) {
    // Simplified implementation - just draw at original size for now
    _context.drawImage(image, dx, dy);
  }

  /// Draws a portion of an image onto the canvas
  void drawImageRect(
    Bitmap image,
    double sx,
    double sy,
    double sw,
    double sh,
    double dx,
    double dy,
    double dw,
    double dh,
  ) {
    // Simplified implementation - just draw at original size for now
    _context.drawImage(image, dx, dy);
  }

  // ============================================================================
  // Text Rendering
  // ============================================================================

  /// Sets the current font from a file
  Future<void> setFontFromFile(String fontPath) async {
    try {
      final file = File(fontPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        setFontFromBytes(bytes);
      } else {
        // If file doesn't exist, just set null (examples can still run without font)
        _currentFont = null;
        _textEngine.font = _currentFont;
      }
    } catch (e) {
      // On error, just set null font
      _currentFont = null;
      _textEngine.font = _currentFont;
    }
  }

  /// Sets the current font from bytes
  void setFontFromBytes(Uint8List bytes) {
    _currentFont = TTFFont.fromBytes(bytes);
    _textEngine.font = _currentFont;
  }

  /// Sets the font size in pixels
  void setFontSize(double size) {
    _fontSize = size;
    _textEngine.fontSize = size;
  }

  /// Sets the text alignment (left, center, right)
  void setTextAlign(TextAlign align) {
    _textAlign = align;
    _textEngine.textAlign = align;
  }

  /// Sets the text baseline (alphabetic, top, middle, bottom)
  void setTextBaseline(TextBaseline baseline) {
    _textBaseline = baseline;
    _textEngine.textBaseline = baseline;
  }

  /// Fills text at the specified position using the current fill style
  void fillText(String text, double x, double y) {
    if (_currentFont == null) {
      throw FontException(FontErrorMessages.noFontSet);
    }

    final path = _textEngine.generateTextPath(text, x, y);
    fill(path);
  }

  /// Strokes text at the specified position using the current stroke style
  void strokeText(String text, double x, double y) {
    if (_currentFont == null) {
      throw FontException(FontErrorMessages.noFontSet);
    }

    final path = _textEngine.generateTextPath(text, x, y);
    stroke(path);
  }

  /// Uses text as a clipping path
  void clipText(String text, double x, double y) {
    if (_currentFont == null) {
      throw FontException(FontErrorMessages.noFontSet);
    }

    final path = _textEngine.generateTextPath(text, x, y);
    clip(path);
  }

  /// Fills and strokes text at the specified position
  void fillAndStrokeText(String text, double x, double y) {
    if (_currentFont == null) {
      throw FontException(FontErrorMessages.noFontSet);
    }

    final path = _textEngine.generateTextPath(text, x, y);
    fill(path);
    stroke(path);
  }

  /// Measures text and returns metrics
  TextMetrics measureText(String text) {
    if (_currentFont == null) {
      throw FontException(FontErrorMessages.noFontSetMeasure);
    }

    return _textEngine.measureText(text);
  }

  /// Gets the current font
  Font? get currentFont => _currentFont;

  /// Gets the current font size
  double get fontSize => _fontSize;

  /// Gets the current text alignment
  TextAlign get textAlign => _textAlign;

  /// Gets the current text baseline
  TextBaseline get textBaseline => _textBaseline;

  /// Get a pixel color at the specified coordinates
  Color getPixel(int x, int y) {
    return canvas.getPixel(x, y);
  }

  /// Set a pixel color at the specified coordinates
  void setPixel(int x, int y, Color color) {
    canvas.setPixel(x, y, color);
  }

  /// Get the canvas width
  int get width => canvas.width;

  /// Get the canvas height
  int get height => canvas.height;

  /// Clear the entire canvas to a specific color
  void clear([Color color = const Color(0x00000000)]) {
    canvas.clear(color);
  }

  /// Create a new bitmap from the current canvas
  Bitmap toBitmap() {
    // Create a copy of the bitmap
    final copy = Bitmap(canvas.width, canvas.height);
    for (int y = 0; y < canvas.height; y++) {
      for (int x = 0; x < canvas.width; x++) {
        copy.setPixel(x, y, canvas.getPixel(x, y));
      }
    }
    return copy;
  }

  /// Get the current graphics context (for advanced usage)
  GraphicsContext get context => _context;

  // ============================================================================
  // Path Creation Utilities
  // ============================================================================

  /// Create a rectangle path
  static Path createRectanglePath(
    double x,
    double y,
    double width,
    double height,
  ) {
    return PathUtils.createRectangle(x, y, width, height);
  }

  /// Create a rounded rectangle path
  static Path createRoundedRectanglePath(
    double x,
    double y,
    double width,
    double height,
    double radius,
  ) {
    return PathUtils.createRoundedRectangle(x, y, width, height, radius);
  }

  /// Create a circle path
  static Path createCirclePath(double cx, double cy, double radius) {
    return PathUtils.createCircle(cx, cy, radius);
  }

  /// Create an ellipse path
  static Path createEllipsePath(double cx, double cy, double rx, double ry) {
    return PathUtils.createEllipse(cx, cy, rx, ry);
  }

  /// Create a regular polygon path
  static Path createPolygonPath(
    double cx,
    double cy,
    double radius,
    int sides,
  ) {
    return PathUtils.createPolygon(cx, cy, radius, sides);
  }

  /// Create a star path
  static Path createStarPath(
    double cx,
    double cy,
    double outerRadius,
    double innerRadius,
    int points,
  ) {
    return PathUtils.createStar(cx, cy, outerRadius, innerRadius, points);
  }

  /// Create an arc path
  static Path createArcPath(
    double cx,
    double cy,
    double radius,
    double startAngle,
    double endAngle,
    bool clockwise,
  ) {
    return PathUtils.createArc(cx, cy, radius, startAngle, endAngle, clockwise);
  }

  // ============================================================================
  // Image Loading/Saving
  // ============================================================================

  /// Load an image from bytes (supports BMP, P3/P6 PPM formats)
  static Bitmap loadImageFromBytes(Uint8List bytes, {String? format}) {
    // Try to auto-detect format if not specified
    if (format == null) {
      if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
        format = 'bmp';
      } else if (bytes.length >= 2 &&
          bytes[0] == 0x50 &&
          (bytes[1] == 0x33 || bytes[1] == 0x36)) {
        format = 'ppm';
      } else {
        throw UnsupportedError(
          'Cannot detect image format. Specify format parameter.',
        );
      }
    }

    switch (format.toLowerCase()) {
      case 'png':
        final codec = PngImageCodec();
        return codec.decode(bytes);
      case 'bmp':
        final codec = BmpImageCodec();
        return codec.decode(bytes);
      case 'ppm':
      case 'p3':
        final codec = P3ImageCodec();
        return codec.decode(bytes);
      case 'p6':
        final codec = P6ImageCodec();
        return codec.decode(bytes);
      default:
        throw UnsupportedError('Unsupported image format: $format');
    }
  }

  /// Save an image to bytes in the specified format
  static Uint8List saveImageToBytes(Bitmap image, String format) {
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

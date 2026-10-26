import 'dart:math' show pow;

import 'image/bitmap.dart';
import 'clipping/clip_region.dart';
import 'utils/dasher.dart';
import 'graphics_state.dart';
import 'image/image_renderer.dart';
import 'limits.dart';
import 'matrix.dart';
import 'rectangle.dart';
import 'result.dart';
import 'paths/path.dart';
import 'rasterize/rasterizer.dart';
import 'rasterize/implementations/basic_rasterizer.dart';
import 'spans/span.dart';
import 'spans/span_pipeline.dart';
import 'utils/stroker.dart';

class GraphicsContext {
  final Bitmap bitmap;
  final List<GraphicsState> _stack = [];
  final Rasterizer _rasterizer;
  final Stroker _stroker = Stroker();
  final Dasher _dasher = Dasher();
  late final SpanPipeline _pipeline;

  /// Limits applied to drawing operations, such as the dash count.
  final Limits limits;

  GraphicsContext(
    this.bitmap, {
    Rasterizer? rasterizer,
    this.limits = const Limits(),
  }) : _rasterizer = rasterizer ?? BasicRasterizer(antiAlias: true) {
    final initial = GraphicsState(transform: Matrix2D.identity());
    _stack.add(initial);
    _pipeline = SpanPipeline.createStandard(bitmap);
  }

  Rasterizer get rasterizer => _rasterizer;
  GraphicsState get state => _stack.last;

  void save() => _stack.add(state.clone());

  void restore() {
    if (_stack.length > 1) _stack.removeLast();
  }

  void clip(Path path, {FillRule rule = FillRule.evenOdd}) {
    // Transform path using only user transform (no Y-flip)
    final transformed = path.transform(state.transform);

    // Create new clip region from path in graphics coordinates
    final region = ClipRegion.fromPath(
      transformed,
      Matrix2D.identity(),
      bitmap.width,
      bitmap.height,
      rule: rule,
      rasterizer: _rasterizer,
    );

    // Store the clip path for save/restore
    state.clipPath = path.clone();

    // If there's an existing clip region, intersect with it
    if (state.clipRegion != null) {
      state.clipRegion = state.clipRegion!.intersect(region);
    } else {
      state.clipRegion = region;
    }
  }

  void drawImage(
    Bitmap image,
    double x,
    double y, {
    ImageFilter filter = ImageFilter.nearest,
    double opacity = 1.0,
  }) {
    _renderImage(
      image,
      dx: x,
      dy: y,
      scaleX: 1.0,
      scaleY: 1.0,
      filter: filter,
      opacity: opacity,
    );
  }

  void drawImageScaled(
    Bitmap image,
    double x,
    double y,
    double width,
    double height, {
    ImageFilter filter = ImageFilter.nearest,
    double opacity = 1.0,
  }) {
    if (width == 0 || height == 0) {
      return;
    }

    final scaleX = width / image.width;
    final scaleY = height / image.height;

    _renderImage(
      image,
      dx: x,
      dy: y,
      scaleX: scaleX,
      scaleY: scaleY,
      filter: filter,
      opacity: opacity,
    );
  }

  void drawImageRect(
    Bitmap image,
    double sx,
    double sy,
    double sw,
    double sh,
    double dx,
    double dy,
    double dw,
    double dh, {
    ImageFilter filter = ImageFilter.nearest,
    double opacity = 1.0,
  }) {
    if (sw <= 0 || sh <= 0 || dw == 0 || dh == 0) {
      return;
    }

    final scaleX = dw / sw;
    final scaleY = dh / sh;
    final sourceRect = Rectangle<double>(sx, sy, sw, sh);

    _renderImage(
      image,
      dx: dx,
      dy: dy,
      scaleX: scaleX,
      scaleY: scaleY,
      filter: filter,
      opacity: opacity,
      sourceRect: sourceRect,
    );
  }

  void _renderImage(
    Bitmap image, {
    required double dx,
    required double dy,
    required double scaleX,
    required double scaleY,
    ImageFilter filter = ImageFilter.nearest,
    double opacity = 1.0,
    Rectangle<double>? sourceRect,
  }) {
    final bounds =
        sourceRect ??
        Rectangle<double>(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        );

    final left = bounds.left;
    final top = bounds.top;
    final height = bounds.height;

    final device = Matrix2D.identity()
      ..translate(0, bitmap.height.toDouble())
      ..scale(1.0, -1.0);

    final transform = Matrix2D.identity()
      ..multiply(device)
      ..multiply(state.transform)
      ..translate(dx, dy)
      ..scale(scaleX, scaleY)
      ..translate(-left, -top)
      ..translate(0, height)
      ..scale(1.0, -1.0);

    ImageRenderer.renderImage(
      bitmap,
      image,
      transform,
      state,
      filter: filter,
      opacity: opacity,
      sourceRect: bounds,
    );
  }

  /// Coverage mapped through `coverage ^ 0.6`, for [fill] of text
  static final List<int> _contrast = [
    for (var coverage = 0; coverage < 256; coverage++)
      (pow(coverage / 255, 0.6) * 255).round(),
  ];

  /// Fills [path] under [rule]. With [text], partly covered pixels are
  /// darkened by a contrast curve, so that unhinted glyph stems read less
  /// blurred.
  void fill(
    Path path, {
    FillRule rule = FillRule.nonZero,
    final bool text = false,
  }) {
    // A singular transform collapses the path; there is nothing to paint
    final Matrix2D inverse;
    switch (state.transform.inverse()) {
      case Ok(:final value):
        inverse = value;
      case Err():
        return;
    }

    // Transform the entire path (preserving all contours for even-odd fill rule)
    final transformed = path.transform(state.transform);
    final spans = _rasterizer.rasterize(
      transformed,
      rule: rule,
      viewport: Rectangle(0, 0, bitmap.width, bitmap.height),
    );

    // Process spans through the pipeline
    var processed = _pipeline.process(
      text
          ? [
              for (final span in spans)
                span.coverage == 255
                    ? span
                    : Span(
                        span.y,
                        span.x,
                        span.length,
                        _contrast[span.coverage],
                      ),
            ]
          : spans,
    );

    // Apply clipping if a clip region exists
    final region = state.clipRegion;
    if (region != null) {
      processed = region.clip(processed);
    }

    // Render the processed spans
    _pipeline.render(
      processed,
      state.fillPaint,
      inverse,
      state.blendMode,
      globalAlpha: state.globalAlpha,
    );
  }

  /// Strokes [path] with the stroke state; [text] as for [fill]
  void stroke(Path path, {final bool text = false}) {
    var input = path;
    if (state.dashPattern != null && state.dashPattern!.isNotEmpty) {
      input = _dasher.dash(path, state.dashPattern!, limits: limits);
    }
    final outline = _stroker.stroke(input, state);
    save();
    try {
      state.fillPaint = state.strokePaint;
      // Overlapping parts of an outline (adjacent round caps, joins) add up
      // rather than cancel
      fill(outline, rule: FillRule.nonZero, text: text);
    } finally {
      restore();
    }
  }
}

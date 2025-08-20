import 'image/bitmap.dart';
import 'clipping/clip_region.dart';
import 'utils/dasher.dart';
import 'graphics_state.dart';
import 'image/image_renderer.dart';
import 'matrix.dart';
import 'paths/path.dart';
import 'rasterize/rasterizer.dart';
import 'rasterize/implementations/basic_rasterizer.dart';
import 'spans/span_pipeline.dart';
import 'utils/stroker.dart';

class GraphicsContext {
  final Bitmap bitmap;
  final List<GraphicsState> _stateStack = [];
  final Rasterizer _rasterizer;
  final Stroker _stroker = Stroker();
  final Dasher _dasher = Dasher();
  late final SpanPipeline _spanPipeline;

  GraphicsContext(this.bitmap, {Rasterizer? rasterizer})
    : _rasterizer = rasterizer ?? BasicRasterizer(antiAlias: true) {
    final initialState = GraphicsState(transform: Matrix2D.identity());
    _stateStack.add(initialState);
    _spanPipeline = SpanPipeline.createStandard(bitmap);
  }

  Rasterizer get rasterizer => _rasterizer;
  GraphicsState get state => _stateStack.last;

  void save() => _stateStack.add(state.clone());

  void restore() {
    if (_stateStack.length > 1) _stateStack.removeLast();
  }

  void clip(Path path) {
    // Transform path using only user transform (no Y-flip)
    final transformedPath = path.transform(state.transform);

    // Create new clip region from path in graphics coordinates
    final newClipRegion = ClipRegion.fromPath(
      transformedPath,
      Matrix2D.identity(),
      bitmap.width,
      bitmap.height,
    );

    // Store the clip path for save/restore
    state.clipPath = path.clone();

    // If there's an existing clip region, intersect with it
    if (state.clipRegion != null) {
      state.clipRegion = state.clipRegion!.intersect(newClipRegion);
    } else {
      state.clipRegion = newClipRegion;
    }
  }

  void clipWithAdvancedRegion(ClipRegion advancedClip) {
    // Transform path using only user transform (no Y-flip)
    final transformedPath = advancedClip.path!.transform(state.transform);

    // Create new clip region with fill rule
    final newClipRegion = ClipRegion.fromPath(
      transformedPath,
      Matrix2D.identity(),
      bitmap.width,
      bitmap.height,
      fillRule: advancedClip.fillRule,
    );

    // Store the clip path for save/restore
    state.clipPath = advancedClip.path!.clone();

    // If there's an existing clip region, intersect with it
    if (state.clipRegion != null) {
      state.clipRegion = state.clipRegion!.intersect(newClipRegion);
    } else {
      state.clipRegion = newClipRegion;
    }
  }

  void drawImage(
    Bitmap image,
    double x,
    double y, {
    ImageFilter filter = ImageFilter.nearest,
    double opacity = 1.0,
  }) {
    // Create transform that positions the image and handles Y-flip
    // In graphics space, image origin is bottom-left
    final imageTransform = Matrix2D.identity()
      ..multiply(state.transform)
      ..translate(x, y)
      // Flip Y to match graphics coordinate system
      ..translate(0, image.height.toDouble())
      ..scale(1.0, -1.0);

    // Use EnhancedImageRenderer for high-quality rendering
    ImageRenderer.renderImage(
      bitmap,
      image,
      imageTransform,
      state,
      filter: filter,
      opacity: opacity,
    );
  }

  void fill(Path path) {
    // Transform path using only user transform (no Y-flip)
    final inverseTransform = Matrix2D.copy(state.transform)..invert();

    // Transform the entire path (preserving all contours for even-odd fill rule)
    final transformedPath = path.transform(state.transform);
    final dataSpans = _rasterizer.rasterize(transformedPath);

    // Process spans through the pipeline
    var processedSpans = _spanPipeline.process(dataSpans);

    // Apply clipping if a clip region exists
    final clipRegion = state.clipRegion;
    if (clipRegion != null) {
      processedSpans = clipRegion.clipSpans(processedSpans);
    }

    // Render the processed spans
    _spanPipeline.render(
      processedSpans,
      state.fillPaint,
      inverseTransform,
      state.blendMode,
      globalAlpha: state.globalAlpha,
    );
  }

  void stroke(Path path) {
    var pathToStroke = path;
    if (state.dashPattern != null && state.dashPattern!.isNotEmpty) {
      pathToStroke = _dasher.dash(path, state.dashPattern!);
    }
    final outlinePath = _stroker.stroke(pathToStroke, state);
    save();
    state.fillPaint = state.strokePaint;
    fill(outlinePath);
    restore();
  }
}

/// A comprehensive 2D vector graphics engine for Dart with software rasterization.
///
/// Pure Dart implementation with no external dependencies, providing high-quality
/// rendering for vector graphics, text, and images.
library libgfx;

export 'src/image/bitmap.dart';
export 'src/clipping/clip_region.dart' show ClipRegion, FillRule;
export 'src/color/color.dart';
export 'src/errors.dart';
export 'src/fonts/font.dart' show Font;
export 'src/fonts/ttf/ttf_font.dart' show TTFFont;
export 'src/fonts/font_fallback.dart';
export 'src/text/text_types.dart'
    show
        TextAlign,
        TextBaseline,
        TextMetrics,
        TextOperation,
        TextDirection,
        ScriptType,
        TextPosition;
export 'src/text/text_engine.dart' show TextEngine;
export 'src/text/text_shaper.dart'
    show ShapedGlyph, ShapedText, TextShaper, BasicTextShaper;
export 'src/text/text_renderer.dart' show TextRenderer;
export 'src/graphics_engine_facade.dart' show GraphicsEngine;
export 'src/graphics_state.dart' show BlendMode, LineCap, LineJoin;
export 'src/image/image_filters.dart';
export 'src/image/image_options.dart';
export 'src/matrix.dart' show Matrix2D;
export 'src/paint.dart';
export 'src/paths/path.dart'
    show Path, PathBuilder, PathCommand, PathCommandType;
export 'src/paths/path_operations.dart' show PathOperations;
export 'src/point.dart' show Point;
export 'src/rasterize/rasterizer.dart';
export 'src/rectangle.dart' show Rectangle;
export 'src/utils/transform_utils.dart'
    show TransformUtils, ScaleMode, Alignment;

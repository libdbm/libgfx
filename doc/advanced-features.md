# Advanced Features

This guide covers the advanced features of libgfx including gradients, patterns, filters, clipping, path operations, and
more. For the rules on coordinates, coverage and fill rules, see the [Rendering Model](rendering-model.md).

## Gradients

Gradients are immutable. Their constructors take a list of `ColorStop`s, and `addColorStop(offset, color)` returns a
new gradient (W3C canvas changes the gradient in place). The engine factories `createLinearGradient`, `createRadialGradient` and
`createConicGradient` return gradients with no stops, so add stops to the result:

```dart
final fade = engine
    .createLinearGradient(0, 0, 200, 0)
    .addColorStop(0.0, const Color(0xFFFF0000))
    .addColorStop(1.0, const Color(0xFF0000FF));
```

### Linear Gradients

Linear gradients create smooth color transitions along a line.

```dart
import 'package:libgfx/libgfx.dart';

// Basic linear gradient
final gradient = LinearGradient(
  start: const Point(0, 0),
  end: const Point(200, 0),
  stops: [
    ColorStop(0.0, const Color(0xFFFF0000)),  // Red
    ColorStop(1.0, const Color(0xFF0000FF)),  // Blue
  ],
);

engine.fillStyle = gradient;
engine.fillRect(0, 0, 200, 100);
```

#### Multi-stop Gradients

```dart
final rainbow = LinearGradient(
  start: const Point(0, 0),
  end: const Point(300, 0),
  stops: [
    ColorStop(0.0, const Color(0xFFFF0000)),   // Red
    ColorStop(0.17, const Color(0xFFFF7F00)),  // Orange
    ColorStop(0.33, const Color(0xFFFFFF00)),  // Yellow
    ColorStop(0.5, const Color(0xFF00FF00)),   // Green
    ColorStop(0.67, const Color(0xFF0000FF)),  // Blue
    ColorStop(0.83, const Color(0xFF4B0082)),  // Indigo
    ColorStop(1.0, const Color(0xFF9400D3)),   // Violet
  ],
);
```

#### Spread Modes

```dart
final stops = [
  ColorStop(0.0, const Color(0xFFFF0000)),
  ColorStop(1.0, const Color(0xFF0000FF)),
];

// Pad - extend edge colors (default)
final padGradient = LinearGradient(
  start: const Point(50, 0),
  end: const Point(150, 0),
  stops: stops,
  spread: GradientSpread.pad,
);

// Repeat - repeat the gradient
final repeatGradient = LinearGradient(
  start: const Point(0, 0),
  end: const Point(50, 0),
  stops: stops,
  spread: GradientSpread.repeat,
);

// Reflect - mirror the gradient
final reflectGradient = LinearGradient(
  start: const Point(0, 0),
  end: const Point(50, 0),
  stops: stops,
  spread: GradientSpread.reflect,
);
```

### Radial Gradients

Radial gradients create circular color transitions.

```dart
// Basic radial gradient
final radial = RadialGradient(
  center: const Point(100, 100),
  radius: 50,
  stops: [
    ColorStop(0.0, const Color(0xFFFFFFFF)),
    ColorStop(1.0, const Color(0xFF000000)),
  ],
);

engine.fillStyle = radial;
engine.fill(PathBuilder().circle(100, 100, 80).build());
```

#### Focal Point Radial Gradients

```dart
// Off-center focal point for 3D effect
final focalRadial = RadialGradient(
  center: const Point(100, 100),
  radius: 50,
  focal: const Point(85, 85),  // Offset focal point
  stops: [
    ColorStop(0.0, const Color(0xFFFFFFFF)),
    ColorStop(0.7, const Color(0xFF2196F3)),
    ColorStop(1.0, const Color(0xFF0D47A1)),
  ],
);
```

### Conic Gradients

Conic (angular) gradients sweep around a center point. The class is `ConicalGradient`.

```dart
// Color wheel
final conic = ConicalGradient(
  center: const Point(100, 100),
  startAngle: 0,
  stops: [
    ColorStop(0.0, const Color(0xFFFF0000)),
    ColorStop(0.17, const Color(0xFFFFFF00)),
    ColorStop(0.33, const Color(0xFF00FF00)),
    ColorStop(0.5, const Color(0xFF00FFFF)),
    ColorStop(0.67, const Color(0xFF0000FF)),
    ColorStop(0.83, const Color(0xFFFF00FF)),
    ColorStop(1.0, const Color(0xFFFF0000)),
  ],
);

engine.fillStyle = conic;
engine.fill(PathBuilder().circle(100, 100, 80).build());
```

## Pattern Fills

### Basic Patterns

`PatternPaint` copies its bitmap and transform, so later changes to either do not affect the paint.

```dart
import 'dart:io';

// Load pattern image
final bytes = await File('pattern.png').readAsBytes();
final patternImage = switch (GraphicsEngine.decode(bytes)) {
  Ok(:final value) => value,
  Err(:final error) => throw StateError(error.message),
};

// Create pattern paint
final pattern = PatternPaint(
  pattern: patternImage,
  repeat: PatternRepeat.repeat,
);

engine.fillStyle = pattern;
engine.fillRect(0, 0, 400, 400);
```

### Pattern Transformations

```dart
import 'dart:math' as math;

final patternImage = Bitmap(16, 16);

// Scaled and rotated pattern
final transform = Matrix2D.identity()
  ..scale(0.5, 0.5)
  ..rotate(math.pi / 4);

final transformedPattern = PatternPaint(
  pattern: patternImage,
  transform: transform,
  repeat: PatternRepeat.repeat,
);
```

### Repeat Modes

<!-- snippet: skip -->
```dart
enum PatternRepeat {
  repeat,    // Tile in both directions (default)
  repeatX,   // Tile horizontally only
  repeatY,   // Tile vertically only
  noRepeat,  // Single instance
}
```

## Image Filters

Filters are static methods on `ImageFilters`. Each takes a `Bitmap`, such as `engine.canvas`, and returns a new bitmap;
the source is left unchanged. Blur radii are limited by `Limits.radius` (256 pixels by default); a larger radius throws
an `ArgumentError`.

### Blur Filters

```dart
import 'dart:math' as math;

// Gaussian blur - high quality; the kernel radius is 3 * sigma
final gaussian = ImageFilters.gaussian(engine.canvas, 2.0);

// Box blur - simple, lower quality
final box = ImageFilters.box(engine.canvas, 5);

// Stack blur - fast approximation of a Gaussian blur
final stack = ImageFilters.stack(engine.canvas, 5);

// Motion blur
final motion = ImageFilters.motion(
  engine.canvas,
  math.pi / 4,  // 45 degrees
  20,           // 20 pixels
);

// Save a result
final png = GraphicsEngine.encode(gaussian, 'png');
```

### Sharpening

```dart
// Sharpen with an amount; larger values sharpen more
final sharpened = ImageFilters.sharpen(engine.canvas, 1.0);
final stronger = ImageFilters.sharpen(engine.canvas, 2.0);
```

### Edge Detection

```dart
// Sobel edge detection with a threshold
final edges = ImageFilters.edges(engine.canvas, threshold: 128);

// A single Sobel kernel through the custom filter
final sobelX = [
  [-1.0, 0.0, 1.0],
  [-2.0, 0.0, 2.0],
  [-1.0, 0.0, 1.0],
];
final horizontal = ImageFilters.convolve(engine.canvas, sobelX);
```

### Emboss Effect

```dart
// Create embossed effect
final embossed = ImageFilters.emboss(engine.canvas);
final deeper = ImageFilters.emboss(engine.canvas, strength: 2.0);

// Custom emboss kernel
final embossKernel = [
  [-2.0, -1.0, 0.0],
  [-1.0,  1.0, 1.0],
  [ 0.0,  1.0, 2.0],
];
final custom = ImageFilters.convolve(engine.canvas, embossKernel);
```

### Custom Convolution Filters

```dart
// Custom kernel for special effects
final customKernel = [
  [0.0,  -1.0,  0.0],
  [-1.0,  5.0, -1.0],
  [0.0,  -1.0,  0.0],
];

final filtered = ImageFilters.convolve(engine.canvas, customKernel);
```

## Advanced Clipping

`clip(path)` uses the non-zero rule, as W3C canvas does; `clip(path, FillRule.evenOdd)` chooses even-odd. Each clip intersects with
the current clip region, and `save`/`restore` bracket it. See the [Rendering Model](rendering-model.md) for how fill
rules are applied.

### Complex Clip Regions

```dart
// Star-shaped clip
final star = PathBuilder();
for (int i = 0; i < 10; i++) {
  final angle = i * math.pi / 5;
  final radius = i.isEven ? 50.0 : 25.0;
  final x = 100 + radius * math.cos(angle);
  final y = 100 + radius * math.sin(angle);

  if (i == 0) {
    star.moveTo(x, y);
  } else {
    star.lineTo(x, y);
  }
}
star.closePath();

engine.clip(star.build(), rule: FillRule.nonZero);
```

### Clip Intersection

```dart
// First clip - circle
engine.save();
engine.clip(PathBuilder().circle(100, 100, 50).build());

// Second clip - rectangle (intersection)
engine.clipRect(75, 75, 100, 100);

// Only the intersection area will be drawn
engine.fillStyle = const Color(0xFFFF0000);
engine.fillRect(0, 0, 400, 400);
engine.restore();
```

### Text as Clipping Path

```dart
// Requires a font; see loadFont or readFont
engine.fontSize = 72;
engine.clipText('CLIP', 50, 100);

// Draw gradient through text
final gradient = LinearGradient(
  start: const Point(0, 0),
  end: const Point(300, 150),
  stops: [
    ColorStop(0.0, const Color(0xFFFF0000)),
    ColorStop(0.5, const Color(0xFF00FF00)),
    ColorStop(1.0, const Color(0xFF0000FF)),
  ],
);
engine.fillStyle = gradient;
engine.fillRect(0, 0, 400, 200);
```

## Path Operations

### Experimental Outline Operations

`PathOperations.union`, `intersection`, `difference` and `xor` (and the matching `Path` methods) are `@experimental`
and only approximate. They are not true boolean operations on areas:

- Each input path is flattened into a single ring: the points of all its contours are joined in order, cubic curves
  are subdivided, and arc and ellipse commands are dropped.
- `union` joins the two outlines into one ring; overlapping or contained shapes are not merged.
- `intersection` is a ring through the edges that cross the other outline; it is empty when the outlines do not
  cross, even if one shape lies inside the other.
- `difference` keeps the edges of the first path that do not cross the second; the second path's area is never
  subtracted.
- `xor` keeps the edges of either path that do not cross the other.

```dart
// Two paths built from curves and lines (arc commands would be dropped)
final circle = PathBuilder().circle(100, 100, 50).build();
final square = PathBuilder().rect(75, 75, 50, 50).build();

final union = PathOperations.union(circle, square);
final intersection = PathOperations.intersection(circle, square);
final difference = PathOperations.difference(circle, square);
final xor = PathOperations.xor(circle, square);

engine.fill(union);
```

`PathOperations.offset(path, distance)` is also experimental: it returns the outline of the path stroked with width
`2 * distance.abs()`, so it covers `distance` on both sides. The sign of `distance` is ignored, and self-intersections
are not removed.

### Path Simplification

```dart
// A path with many nearly collinear points
final builder = PathBuilder()..moveTo(0, 0);
for (int i = 1; i <= 100; i++) {
  builder.lineTo(i * 2.0, math.sin(i * 0.05) * 20);
}
final complex = builder.build();

// Ramer-Douglas-Peucker simplification
final simplified = complex.simplify(1.0);

// Reduces number of points while maintaining shape
print('Original commands: ${complex.commands.length}');
print('Simplified commands: ${simplified.commands.length}');
```

### Path Bounds

```dart
final path = (PathBuilder()
      ..moveTo(10, 10)
      ..lineTo(100, 50)
      ..lineTo(50, 100)
      ..closePath())
    .build();

// Get bounding box
final bounds = path.bounds;
print('Bounds: ${bounds.left}, ${bounds.top}, ${bounds.width}, ${bounds.height}');
```

`Path.commands` and each `PathCommand.points` are unmodifiable; add commands with `PathBuilder`, `Path.add` or
`Path.addPath`.

## Advanced Text Features

Font, size, alignment and baseline are part of the saved state, so `save` and `restore` cover them.

### Text Metrics

```dart
engine.fontSize = 24;
final metrics = engine.measureText('Hello World');

print('Width: ${metrics.width}');
print('Ascent: ${metrics.ascent}');
print('Descent: ${metrics.descent}');

// Use for text positioning
const centerX = 200.0;
const centerY = 100.0;
engine.textAlign = TextAlign.center;
engine.textBaseline = TextBaseline.middle;
engine.fillText('Centered', centerX, centerY);
```

### Font Fallback

`fillText` uses only the current font. To draw text that needs glyphs from several fonts, build a `FontFallbackChain`
and fill the path it produces. Each font is added only when it loads.

```dart
import 'package:libgfx/io/local_file_system.dart';

const filesystem = LocalGraphicsFileSystem();
final chain = FontFallbackChain();

// Primary font first, then fallbacks for missing glyphs
for (final path in ['fonts/primary.ttf', 'fonts/chinese.ttf', 'fonts/arabic.ttf']) {
  final result = await chain.load(path, filesystem: filesystem);
  if (result case Err(:final error)) {
    print('Skipped $path: ${error.message}');
  }
}

// Each run of characters uses the first font that has its glyphs
engine.fill(chain.path('Hello 你好 مرحبا', 10, 50, 24));
```

## Blend Modes

### Porter-Duff Compositing

```dart
// Draw base layer
engine.fillStyle = const Color(0xFF0000FF);
engine.fill(PathBuilder().circle(100, 100, 50).build());

// Set blend mode
engine.globalCompositeOperation = BlendMode.multiply;

// Draw overlay
engine.fillStyle = const Color(0xFFFF0000);
engine.fill(PathBuilder().circle(130, 100, 50).build());
```

### Common Blend Modes

```dart
const modes = [
  // Porter-Duff modes
  BlendMode.srcOver,     // Source over destination (default)
  BlendMode.src,         // Replace destination
  BlendMode.srcIn,       // Source inside destination
  BlendMode.dstOut,      // Destination outside source
  BlendMode.xor,         // Exclusive OR
  BlendMode.clear,       // Clear destination

  // Darken modes
  BlendMode.multiply,    // Multiply colors
  BlendMode.darken,      // Use darker color
  BlendMode.colorBurn,   // Darken based on overlay

  // Lighten modes
  BlendMode.screen,      // Inverse multiply
  BlendMode.lighten,     // Use lighter color
  BlendMode.colorDodge,  // Lighten based on overlay
  BlendMode.add,         // Add colors

  // Contrast modes
  BlendMode.overlay,     // Multiply or screen
  BlendMode.hardLight,   // Vivid light
  BlendMode.softLight,   // Subtle light

  // Difference modes
  BlendMode.difference,  // Absolute difference
  BlendMode.exclusion,   // Softer difference
];
```

## Performance Optimization

### Path Caching

```dart
import 'package:libgfx/libgfx.dart';

class OptimizedDrawing {
  late Path _cachedPath;

  void initialize() {
    // Build complex path once
    _cachedPath = PathBuilder()
      // ... complex operations
      .build();
  }

  void draw(GraphicsEngine engine) {
    // Reuse cached path
    for (int i = 0; i < 100; i++) {
      engine.save();
      engine.translate(i * 10.0, 0);
      engine.fill(_cachedPath);
      engine.restore();
    }
  }
}

void main() {
  final drawing = OptimizedDrawing()..initialize();
  drawing.draw(GraphicsEngine(400, 300));
}
```

### Dirty Rectangle Optimization

```dart
import 'package:libgfx/libgfx.dart';

class IncrementalRenderer {
  final regions = <Rectangle<double>>[];

  void markDirty(Rectangle<double> region) {
    regions.add(region);
  }

  void render(GraphicsEngine engine, void Function(GraphicsEngine) drawScene) {
    // Only redraw dirty regions
    for (final region in regions) {
      engine.save();
      engine.clipRect(region.left, region.top, region.width, region.height);
      drawScene(engine);
      engine.restore();
    }
    regions.clear();
  }
}

void main() {
  final renderer = IncrementalRenderer()
    ..markDirty(const Rectangle(10.0, 10.0, 50.0, 50.0));
  renderer.render(GraphicsEngine(400, 300), (engine) => engine.fillRect(0, 0, 400, 300));
}
```

## Custom Paint Implementation

### Creating Custom Paint

A `Paint` returns the color at a device-space point; `inverse` maps that point back to user space.

```dart
import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';

class CustomPaint extends Paint {
  @override
  Color sample(Point point, Matrix2D inverse) {
    // Custom color calculation in user space
    final user = inverse.transform(point);
    final distance = math.sqrt(user.x * user.x + user.y * user.y);
    final intensity = (math.sin(distance * 0.1) + 1) / 2;
    return Color.fromRGBA(
      (255 * intensity).round(),
      0,
      (255 * (1 - intensity)).round(),
      255,
    );
  }
}

void main() {
  final engine = GraphicsEngine(400, 300);
  engine.fillStyle = CustomPaint();
  engine.fillRect(0, 0, 400, 300);
}
```

## Advanced Transformations

### 3D-like Transformations

```dart
// Perspective-like effect using 2D transforms
void drawPerspective(GraphicsEngine engine) {
  final cards = 5;
  for (int i = 0; i < cards; i++) {
    engine.save();

    // Calculate perspective scale
    final z = i * 0.2;
    final scale = 1 / (1 + z);

    // Apply transformations
    engine.translate(200, 200);
    engine.scale(scale, scale);
    engine.rotate(i * 0.1);

    // Draw with opacity based on depth
    engine.globalAlpha = 1.0 - z * 0.5;
    engine.fillStyle = const Color(0xFF2196F3);
    engine.fillRect(-50, -75, 100, 150);

    engine.restore();
  }
}
```

### Transform Interpolation

`Matrix2D` does not decompose a transform, so keep the components and interpolate those:

```dart
Matrix2D interpolateTransform(
  Point fromTranslate, double fromRotation, Point fromScale,
  Point toTranslate, double toRotation, Point toScale,
  double t,
) {
  // Interpolate components
  final translate = Point.lerp(fromTranslate, toTranslate, t);
  final rotation = fromRotation + (toRotation - fromRotation) * t;
  final scale = Point.lerp(fromScale, toScale, t);

  // Reconstruct transform
  return Matrix2D.identity()
    ..translate(translate.x, translate.y)
    ..rotate(rotation)
    ..scale(scale.x, scale.y);
}
```

## Working with Large Images

### Tiled Rendering

```dart
import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';

class TiledRenderer {
  static const tileSize = 256;

  void renderLargeImage(Bitmap source, GraphicsEngine engine) {
    final tilesX = (source.width / tileSize).ceil();
    final tilesY = (source.height / tileSize).ceil();

    for (int y = 0; y < tilesY; y++) {
      for (int x = 0; x < tilesX; x++) {
        final srcX = x * tileSize;
        final srcY = y * tileSize;
        final srcW = math.min(tileSize, source.width - srcX);
        final srcH = math.min(tileSize, source.height - srcY);

        // Source rectangle, then destination rectangle
        engine.drawImage(source, srcX.toDouble(), srcY.toDouble(), width: srcW.toDouble(), height: srcH.toDouble(), source: Rectangle(srcX.toDouble(), srcY.toDouble(), srcW.toDouble(), srcH.toDouble()));
      }
    }
  }
}

void main() {
  TiledRenderer().renderLargeImage(Bitmap(1000, 1000), GraphicsEngine(1000, 1000));
}
```

## Debugging and Visualization

### Path Visualization

`PathBuilder` stores quadratic curves as cubic curves, so a path holds `moveTo`, `lineTo`, `cubicCurveTo`, `arc`,
`ellipse` and `close` commands (the `PathCommandType` values).

```dart
void debugPath(GraphicsEngine engine, Path path) {
  // Draw path outline
  engine.strokeStyle = const Color(0xFF000000);
  engine.lineWidth = 1;
  engine.stroke(path);

  // Draw control points
  engine.fillStyle = const Color(0xFFFF0000);
  for (final command in path.commands) {
    if (command.type == PathCommandType.cubicCurveTo) {
      engine.fill(PathBuilder().circle(command.points[0].x, command.points[0].y, 3).build());
      engine.fill(PathBuilder().circle(command.points[1].x, command.points[1].y, 3).build());
    }
  }

  // Draw vertices
  engine.fillStyle = const Color(0xFF0000FF);
  for (final command in path.commands) {
    if (command.type == PathCommandType.moveTo ||
        command.type == PathCommandType.lineTo) {
      engine.fill(PathBuilder().circle(command.points[0].x, command.points[0].y, 4).build());
    }
  }
}
```

### Performance Profiling

```dart
class RenderProfiler {
  final stopwatch = Stopwatch();
  final timings = <String, Duration>{};

  void startTimer(String operation) {
    stopwatch.reset();
    stopwatch.start();
  }

  void endTimer(String operation) {
    stopwatch.stop();
    timings[operation] = stopwatch.elapsed;
  }

  void printReport() {
    print('Render Performance Report:');
    for (final entry in timings.entries) {
      print('  ${entry.key}: ${entry.value.inMilliseconds}ms');
    }
  }
}

void main() {
  final profiler = RenderProfiler()..startTimer('fill');
  profiler
    ..endTimer('fill')
    ..printReport();
}
```

## See Also

- [Getting Started Guide](getting-started.md)
- [Rendering Model](rendering-model.md)
- [API Reference](api-reference.md)
- [Examples](examples.md)

---

Note on File IO:
If an advanced example loads fonts from files or saves images, ensure a GraphicsFileSystem is configured on your GraphicsEngine (e.g., LocalGraphicsFileSystem on VM). See the API Reference section “File IO and GraphicsFileSystem”.

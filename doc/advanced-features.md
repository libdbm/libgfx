# Advanced Features

This guide covers the advanced features of libgfx including gradients, patterns, filters, clipping, path operations, and
more.

## Gradients

### Linear Gradients

Linear gradients create smooth color transitions along a line.

```dart
import 'package:libgfx/libgfx.dart';

// Basic linear gradient
final gradient = LinearGradient(
  start: Point(0, 0),
  end: Point(200, 0),
  colors: [
    const Color(0xFFFF0000),  // Red
    const Color(0xFF0000FF),  // Blue
  ],
  stops: [0.0, 1.0],
);

engine.setFillPaint(gradient);
engine.fillRect(0, 0, 200, 100);
```

#### Multi-stop Gradients

```dart
final rainbow = LinearGradient(
  start: Point(0, 0),
  end: Point(300, 0),
  colors: [
    const Color(0xFFFF0000),  // Red
    const Color(0xFFFF7F00),  // Orange
    const Color(0xFFFFFF00),  // Yellow
    const Color(0xFF00FF00),  // Green
    const Color(0xFF0000FF),  // Blue
    const Color(0xFF4B0082),  // Indigo
    const Color(0xFF9400D3),  // Violet
  ],
  stops: [0.0, 0.17, 0.33, 0.5, 0.67, 0.83, 1.0],
);
```

#### Spread Modes

```dart
// Pad - extend edge colors (default)
final padGradient = LinearGradient(
  start: Point(50, 0),
  end: Point(150, 0),
  colors: [const Color(0xFFFF0000), const Color(0xFF0000FF)],
  spreadMode: SpreadMode.pad,
);

// Repeat - repeat the gradient
final repeatGradient = LinearGradient(
  start: Point(0, 0),
  end: Point(50, 0),
  colors: [const Color(0xFFFF0000), const Color(0xFF0000FF)],
  spreadMode: SpreadMode.repeat,
);

// Reflect - mirror the gradient
final reflectGradient = LinearGradient(
  start: Point(0, 0),
  end: Point(50, 0),
  colors: [const Color(0xFFFF0000), const Color(0xFF0000FF)],
  spreadMode: SpreadMode.reflect,
);
```

### Radial Gradients

Radial gradients create circular color transitions.

```dart
// Basic radial gradient
final radial = RadialGradient(
  center: Point(100, 100),
  radius: 50,
  colors: [
    const Color(0xFFFFFFFF),
    const Color(0xFF000000),
  ],
);

engine.setFillPaint(radial);
engine.fillCircle(100, 100, 80);
```

#### Focal Point Radial Gradients

```dart
// Off-center focal point for 3D effect
final focalRadial = RadialGradient(
  center: Point(100, 100),
  radius: 50,
  focal: Point(85, 85),  // Offset focal point
  colors: [
    const Color(0xFFFFFFFF),
    const Color(0xFF2196F3),
    const Color(0xFF0D47A1),
  ],
  stops: [0.0, 0.7, 1.0],
);
```

### Conic Gradients

Conic (angular) gradients sweep around a center point.

```dart
// Color wheel
final conic = ConicGradient(
  center: Point(100, 100),
  startAngle: 0,
  colors: [
    const Color(0xFFFF0000),
    const Color(0xFFFFFF00),
    const Color(0xFF00FF00),
    const Color(0xFF00FFFF),
    const Color(0xFF0000FF),
    const Color(0xFFFF00FF),
    const Color(0xFFFF0000),
  ],
  stops: [0.0, 0.17, 0.33, 0.5, 0.67, 0.83, 1.0],
);

engine.setFillPaint(conic);
engine.fillCircle(100, 100, 80);
```

## Pattern Fills

### Basic Patterns

```dart
// Load pattern image
final patternImage = await Bitmap.fromFile('pattern.png');

// Create pattern paint
final pattern = PatternPaint(
  bitmap: patternImage,
  repeatX: RepeatMode.repeat,
  repeatY: RepeatMode.repeat,
);

engine.setFillPaint(pattern);
engine.fillRect(0, 0, 400, 400);
```

### Pattern Transformations

```dart
import 'dart:math' as math;

// Scaled and rotated pattern
final transform = Matrix4.identity()
  ..scale(0.5, 0.5)
  ..rotate(math.pi / 4);

final transformedPattern = PatternPaint(
  bitmap: patternImage,
  transform: transform,
  repeatX: RepeatMode.repeat,
  repeatY: RepeatMode.repeat,
);
```

### Repeat Modes

```dart
enum RepeatMode {
  repeat,     // Tile in both directions
  noRepeat,   // Single instance
  repeatX,    // Tile horizontally only
  repeatY,    // Tile vertically only
  mirror,     // Mirror tile
}
```

## Image Filters

### Blur Filters

```dart
// Gaussian blur - high quality
engine.applyGaussianBlur(5.0);  // 5 pixel radius

// Box blur - faster, lower quality
engine.applyBoxBlur(5.0);

// Motion blur
engine.applyMotionBlur(
  angle: math.pi / 4,  // 45 degrees
  distance: 20.0,      // 20 pixels
);
```

### Sharpening

```dart
// Basic sharpen
engine.applySharpen();  // Default amount

// Custom sharpen amount
engine.applySharpen(2.0);  // Stronger sharpening
```

### Edge Detection

```dart
// Detect edges
engine.applyEdgeDetect(threshold: 128);

// Sobel edge detection
final sobelX = [
  [-1, 0, 1],
  [-2, 0, 2],
  [-1, 0, 1],
];
engine.applyConvolution(sobelX);
```

### Emboss Effect

```dart
// Create embossed effect
engine.applyEmboss();

// Custom emboss kernel
final embossKernel = [
  [-2, -1, 0],
  [-1,  1, 1],
  [ 0,  1, 2],
];
engine.applyConvolution(embossKernel);
```

### Custom Convolution Filters

```dart
// Custom kernel for special effects
final customKernel = [
  [0,  -1,  0],
  [-1,  5, -1],
  [0,  -1,  0],
];

engine.applyConvolution(
  customKernel,
  divisor: 1.0,  // Sum of kernel values
  bias: 0.0,      // Brightness adjustment
);
```

## Advanced Clipping

### Complex Clip Regions

```dart
// Star-shaped clip
final star = PathBuilder();
for (int i = 0; i < 10; i++) {
  final angle = i * math.pi / 5;
  final radius = i.isEven ? 50 : 25;
  final x = 100 + radius * math.cos(angle);
  final y = 100 + radius * math.sin(angle);
  
  if (i == 0) {
    star.moveTo(x, y);
  } else {
    star.lineTo(x, y);
  }
}
star.close();

engine.clipWithFillRule(
  star.build(),
  fillRule: FillRule.evenOdd,
);
```

### Clip Intersection

```dart
// First clip - circle
engine.save();
engine.beginPath();
engine.arc(100, 100, 50, 0, math.pi * 2);
engine.clip();

// Second clip - rectangle (intersection)
engine.beginPath();
engine.rect(75, 75, 100, 100);
engine.clip();

// Only the intersection area will be drawn
engine.setFillColor(const Color(0xFFFF0000));
engine.fillRect(0, 0, 400, 400);
engine.restore();
```

### Text as Clipping Path

```dart
// Create text path
engine.setFontSize(72);
engine.beginPath();
engine.textPath('CLIP', 50, 100);
engine.clip();

// Draw gradient through text
final gradient = LinearGradient(
  start: Point(0, 0),
  end: Point(300, 150),
  colors: [
    const Color(0xFFFF0000),
    const Color(0xFF00FF00),
    const Color(0xFF0000FF),
  ],
);
engine.setFillPaint(gradient);
engine.fillRect(0, 0, 400, 200);
```

## Path Operations

### Boolean Operations

```dart
// Create two paths
final circle = PathBuilder()
  ..arc(100, 100, 50, 0, math.pi * 2)
  ..close();

final square = PathBuilder()
  ..rect(75, 75, 50, 50)
  ..close();

// Union - combine paths
final union = PathOperations.union(circle.build(), square.build());
engine.fill(union);

// Intersection - overlap only
final intersection = PathOperations.intersection(circle.build(), square.build());
engine.fill(intersection);

// Difference - subtract second from first
final difference = PathOperations.difference(circle.build(), square.build());
engine.fill(difference);

// XOR - non-overlapping parts
final xor = PathOperations.xor(circle.build(), square.build());
engine.fill(xor);
```

### Path Simplification

```dart
// Simplify complex path
final complex = createComplexPath();
final simplified = complex.simplify(tolerance: 1.0);

// Reduces number of points while maintaining shape
print('Original points: ${complex.commands.length}');
print('Simplified points: ${simplified.commands.length}');
```

### Path Bounds and Hit Testing

```dart
final path = PathBuilder()
  ..moveTo(10, 10)
  ..lineTo(100, 50)
  ..lineTo(50, 100)
  ..close();

// Get bounding box
final bounds = path.build().getBounds();
print('Bounds: ${bounds.x}, ${bounds.y}, ${bounds.width}, ${bounds.height}');

// Hit testing
final point = Point(55, 60);
final contains = path.build().contains(point);
print('Path contains point: $contains');

// With fill rule
final containsEvenOdd = path.build().contains(
  point,
  fillRule: FillRule.evenOdd,
);
```

## Advanced Text Features

### Text Metrics

```dart
engine.setFontSize(24);
final metrics = engine.measureText('Hello World');

print('Width: ${metrics.width}');
print('Ascent: ${metrics.actualBoundingBoxAscent}');
print('Descent: ${metrics.actualBoundingBoxDescent}');

// Use for text positioning
final centerX = 200;
final centerY = 100;
engine.setTextAlign(TextAlign.center);
engine.setTextBaseline(TextBaseline.middle);
engine.fillText('Centered', centerX, centerY);
```

### Font Fallback

```dart
// Set primary font
await engine.setFontFromFile('fonts/primary.ttf');

// Add fallback fonts for missing glyphs
engine.addFallbackFont(await Font.fromFile('fonts/emoji.ttf'));
engine.addFallbackFont(await Font.fromFile('fonts/chinese.ttf'));
engine.addFallbackFont(await Font.fromFile('fonts/arabic.ttf'));

// Automatically uses fallback for missing characters
engine.fillText('Hello 😀 你好 مرحبا', 10, 50);
```

### Advanced Text Layout

```dart
// Letter spacing
engine.setLetterSpacing(2.0);
engine.fillText('SPACED', 10, 50);

// Word spacing
engine.setWordSpacing(10.0);
engine.fillText('Word spacing example', 10, 80);

// Text along path
final pathForText = PathBuilder()
  ..moveTo(50, 100)
  ..quadTo(150, 50, 250, 100);

engine.fillTextAlongPath('Text along a curved path', pathForText.build());
```

## Blend Modes

### Porter-Duff Compositing

```dart
// Draw base layer
engine.setFillColor(const Color(0xFF0000FF));
engine.fillCircle(100, 100, 50);

// Set blend mode
engine.setGlobalCompositeOperation(BlendMode.multiply);

// Draw overlay
engine.setFillColor(const Color(0xFFFF0000));
engine.fillCircle(130, 100, 50);
```

### Common Blend Modes

```dart
// Darken modes
BlendMode.multiply    // Multiply colors
BlendMode.darken      // Use darker color
BlendMode.colorBurn   // Darken based on overlay

// Lighten modes
BlendMode.screen      // Inverse multiply
BlendMode.lighten     // Use lighter color
BlendMode.colorDodge  // Lighten based on overlay

// Contrast modes
BlendMode.overlay     // Multiply or screen
BlendMode.hardLight   // Vivid light
BlendMode.softLight   // Subtle light

// Difference modes
BlendMode.difference  // Absolute difference
BlendMode.exclusion   // Softer difference

// Component modes
BlendMode.hue         // Use overlay hue
BlendMode.saturation  // Use overlay saturation
BlendMode.color       // Use overlay color
BlendMode.luminosity  // Use overlay luminosity
```

## Performance Optimization

### Path Caching

```dart
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
      engine.translate(i * 10, 0);
      engine.fill(_cachedPath);
      engine.restore();
    }
  }
}
```

### Batch Rendering

```dart
// Batch similar operations
engine.setFillColor(const Color(0xFF2196F3));
engine.beginBatch();

for (final position in positions) {
  engine.fillCircle(position.x, position.y, 5);
}

engine.endBatch();
```

### Dirty Rectangle Optimization

```dart
class IncrementalRenderer {
  final regions = <Rectangle>[];
  
  void markDirty(Rectangle region) {
    regions.add(region);
  }
  
  void render(GraphicsEngine engine) {
    // Only redraw dirty regions
    for (final region in regions) {
      engine.save();
      engine.clipRect(region.x, region.y, region.width, region.height);
      drawScene(engine);
      engine.restore();
    }
    regions.clear();
  }
}
```

## Custom Paint Implementation

### Creating Custom Paint

```dart
class CustomPaint extends Paint {
  @override
  Color getColorAt(double x, double y) {
    // Custom color calculation
    final distance = math.sqrt(x * x + y * y);
    final intensity = (math.sin(distance * 0.1) + 1) / 2;
    return Color.fromRGBA(
      (255 * intensity).round(),
      0,
      (255 * (1 - intensity)).round(),
      255,
    );
  }
  
  @override
  Paint transform(Matrix4 matrix) {
    // Return transformed paint
    return this; // Or create new transformed instance
  }
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
    engine.setGlobalAlpha(1.0 - z * 0.5);
    engine.setFillColor(const Color(0xFF2196F3));
    engine.fillRect(-50, -75, 100, 150);
    
    engine.restore();
  }
}
```

### Transform Interpolation

```dart
Matrix4 interpolateTransform(Matrix4 from, Matrix4 to, double t) {
  // Decompose transforms
  final fromTranslate = from.getTranslation();
  final toTranslate = to.getTranslation();
  final fromRotation = from.getRotation();
  final toRotation = to.getRotation();
  final fromScale = from.getScale();
  final toScale = to.getScale();
  
  // Interpolate components
  final translate = Point.lerp(fromTranslate, toTranslate, t);
  final rotation = lerpDouble(fromRotation, toRotation, t);
  final scale = Point.lerp(fromScale, toScale, t);
  
  // Reconstruct transform
  return Matrix4.identity()
    ..translate(translate.x, translate.y)
    ..rotate(rotation)
    ..scale(scale.x, scale.y);
}
```

## Working with Large Images

### Tiled Rendering

```dart
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
        
        engine.drawImageRect(
          source,
          srcX: srcX.toDouble(),
          srcY: srcY.toDouble(),
          srcWidth: srcW.toDouble(),
          srcHeight: srcH.toDouble(),
          destX: srcX.toDouble(),
          destY: srcY.toDouble(),
          destWidth: srcW.toDouble(),
          destHeight: srcH.toDouble(),
        );
      }
    }
  }
}
```

## Debugging and Visualization

### Path Visualization

```dart
void debugPath(GraphicsEngine engine, Path path) {
  // Draw path outline
  engine.setStrokeColor(const Color(0xFF000000));
  engine.setStrokeWidth(1);
  engine.stroke(path);
  
  // Draw control points
  engine.setFillColor(const Color(0xFFFF0000));
  for (final command in path.commands) {
    if (command is QuadraticCurveToCommand) {
      engine.fillCircle(command.cpx, command.cpy, 3);
    } else if (command is BezierCurveToCommand) {
      engine.fillCircle(command.cp1x, command.cp1y, 3);
      engine.fillCircle(command.cp2x, command.cp2y, 3);
    }
  }
  
  // Draw vertices
  engine.setFillColor(const Color(0xFF0000FF));
  for (final command in path.commands) {
    if (command is MoveToCommand || command is LineToCommand) {
      engine.fillCircle(command.x, command.y, 4);
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
```

## See Also

- [Getting Started Guide](getting-started.md)
- [API Reference](api-reference.md)
- [Examples](examples.md)
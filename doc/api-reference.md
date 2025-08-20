# API Reference

Complete API documentation for libgfx graphics engine.

## Table of Contents

- [GraphicsEngine](#graphicsengine)
- [FluentGraphicsEngine](#fluentgraphicsengine)
- [Color](#color)
- [Path and PathBuilder](#path-and-pathbuilder)
- [Paint System](#paint-system)
- [Text and Fonts](#text-and-fonts)
- [Transformations](#transformations)
- [Image Operations](#image-operations)
- [Filters](#filters)
- [Clipping](#clipping)
- [Blend Modes](#blend-modes)

## GraphicsEngine

The main class for creating and manipulating graphics.

### Constructor

```dart
GraphicsEngine(int width, int height)
```

Creates a new graphics engine with the specified canvas dimensions.

### Basic Drawing Methods

#### Fill Operations

```dart
void setFillColor(Color color)
void setFillPaint(Paint paint)
void fill([Path? path])
void fillRect(double x, double y, double width, double height)
void fillCircle(double cx, double cy, double radius)
void fillText(String text, double x, double y)
```

#### Stroke Operations

```dart
void setStrokeColor(Color color)
void setStrokePaint(Paint paint)
void setStrokeWidth(double width)
void stroke([Path? path])
void strokeRect(double x, double y, double width, double height)
void strokeCircle(double cx, double cy, double radius)
void strokeText(String text, double x, double y)
```

#### Line Styling

```dart
void setLineCap(LineCap cap)
  // LineCap.butt (default)
  // LineCap.round
  // LineCap.square

void setLineJoin(LineJoin join)
  // LineJoin.miter (default)
  // LineJoin.round
  // LineJoin.bevel

void setMiterLimit(double limit)
void setLineDash(List<double> pattern, [double offset = 0])
void clearLineDash()
```

### Path Operations

```dart
void beginPath()
void moveTo(double x, double y)
void lineTo(double x, double y)
void quadraticCurveTo(double cpx, double cpy, double x, double y)
void bezierCurveTo(double cp1x, double cp1y, double cp2x, double cp2y, double x, double y)
void arcTo(double x1, double y1, double x2, double y2, double radius)
void arc(double cx, double cy, double radius, double startAngle, double endAngle, [bool anticlockwise = false])
void closePath()
```

### State Management

```dart
void save()
void restore()
void reset()
```

### Transformations

```dart
void translate(double dx, double dy)
void rotate(double angle)
void scale(double sx, [double? sy])
void transform(double a, double b, double c, double d, double e, double f)
void setTransform(double a, double b, double c, double d, double e, double f)
Matrix4 getTransform()
```

### Clipping

```dart
void clip([Path? path])
void clipRect(double x, double y, double width, double height)
void clipWithFillRule(Path path, {FillRule fillRule = FillRule.nonZero})
void resetClip()
```

### Canvas Operations

```dart
void clear([Color? color])
Bitmap get canvas
Future<void> saveToFile(String filename)
void drawImage(Bitmap image, double x, double y)
void drawImageScaled(Bitmap image, {required double destX, required double destY, required double destWidth, required double destHeight})
void drawImageRect(Bitmap image, {required double srcX, required double srcY, required double srcWidth, required double srcHeight, required double destX, required double destY, required double destWidth, required double destHeight})
```

### Blend Modes

```dart
void setGlobalAlpha(double alpha)
void setGlobalCompositeOperation(BlendMode mode)
```

## FluentGraphicsEngine

A fluent API wrapper that allows method chaining.

### Creating Fluent API

```dart
FluentGraphicsEngine fluent()
```

### Fluent Methods

All methods return `FluentGraphicsEngine` for chaining:

```dart
engine.fluent()
  .fillColor(Color color)
  .fillRect(double x, double y, double width, double height)
  .fillCircle(double cx, double cy, double radius)
  .strokeColor(Color color)
  .strokeWidth(double width)
  .strokeRect(double x, double y, double width, double height)
  .translate(double dx, double dy)
  .rotate(double angle)
  .scale(double sx, [double? sy])
  .save()
  .restore()
  // ... and more
```

## Color

Represents ARGB colors with 8 bits per channel.

### Constructors

```dart
const Color(int value)  // 0xAARRGGBB format
Color.fromRGBA(int r, int g, int b, int a)  // Deprecated
Color.fromRGB(int r, int g, int b)  // Opaque color
```

### Properties

```dart
int get value     // Raw ARGB value
int get alpha     // Alpha channel (0-255)
int get red       // Red channel (0-255)
int get green     // Green channel (0-255)
int get blue      // Blue channel (0-255)
double get opacity  // Alpha as 0.0-1.0
```

### Methods

```dart
Color withAlpha(int alpha)
Color withOpacity(double opacity)
```

### Predefined Colors

```dart
static const Color transparent = Color(0x00000000);
static const Color black = Color(0xFF000000);
static const Color white = Color(0xFFFFFFFF);
// Common colors available through Colors class
```

## Path and PathBuilder

### Path

Represents a vector path.

```dart
class Path {
  List<PathCommand> get commands
  Path transform(Matrix4 matrix)
  Rectangle getBounds()
  Path simplify([double tolerance = 1.0])
  bool contains(Point point, {FillRule fillRule = FillRule.nonZero})
}
```

### PathBuilder

Fluent builder for creating paths.

```dart
class PathBuilder {
  PathBuilder moveTo(double x, double y)
  PathBuilder lineTo(double x, double y)
  PathBuilder quadTo(double cpx, double cpy, double x, double y)
  PathBuilder cubicTo(double cp1x, double cp1y, double cp2x, double cp2y, double x, double y)
  PathBuilder arcTo(double cx, double cy, double rx, double ry, double startAngle, double sweepAngle, bool largeArc)
  PathBuilder arc(double cx, double cy, double radius, double startAngle, double endAngle, [bool anticlockwise = false])
  PathBuilder rect(double x, double y, double width, double height)
  PathBuilder roundRect(double x, double y, double width, double height, double radius)
  PathBuilder ellipse(double cx, double cy, double rx, double ry)
  PathBuilder close()
  PathBuilder addPath(Path path, [Matrix4? transform])
  Path build()
}
```

## Paint System

### Paint (Abstract)

Base class for all paint types.

```dart
abstract class Paint {
  Paint transform(Matrix4 matrix);
}
```

### SolidPaint

Solid color paint.

```dart
class SolidPaint extends Paint {
  final Color color;
  SolidPaint(this.color);
}
```

### LinearGradient

```dart
class LinearGradient extends Paint {
  LinearGradient({
    required Point start,
    required Point end,
    required List<Color> colors,
    List<double>? stops,
    SpreadMode spreadMode = SpreadMode.pad,
  });
}
```

### RadialGradient

```dart
class RadialGradient extends Paint {
  RadialGradient({
    required Point center,
    required double radius,
    Point? focal,
    required List<Color> colors,
    List<double>? stops,
    SpreadMode spreadMode = SpreadMode.pad,
  });
}
```

### ConicGradient

```dart
class ConicGradient extends Paint {
  ConicGradient({
    required Point center,
    required double startAngle,
    required List<Color> colors,
    List<double>? stops,
    SpreadMode spreadMode = SpreadMode.pad,
  });
}
```

### PatternPaint

```dart
class PatternPaint extends Paint {
  PatternPaint({
    required Bitmap bitmap,
    Matrix4? transform,
    RepeatMode repeatX = RepeatMode.repeat,
    RepeatMode repeatY = RepeatMode.repeat,
  });
}
```

### SpreadMode

```dart
enum SpreadMode {
  pad,      // Extend with edge colors
  repeat,   // Repeat gradient
  reflect,  // Mirror gradient
}
```

## Text and Fonts

### Font Loading

```dart
Future<void> setFontFromFile(String path)
Future<void> setFontFromBytes(Uint8List bytes)
void setFont(Font font)
```

### Text Configuration

```dart
void setFontSize(double size)
void setTextAlign(TextAlign align)
  // TextAlign.left (default)
  // TextAlign.center
  // TextAlign.right
  
void setTextBaseline(TextBaseline baseline)
  // TextBaseline.top
  // TextBaseline.middle
  // TextBaseline.alphabetic (default)
  // TextBaseline.bottom

void setLetterSpacing(double spacing)
void setWordSpacing(double spacing)
```

### Text Measurement

```dart
TextMetrics measureText(String text)

class TextMetrics {
  final double width;
  final double actualBoundingBoxLeft;
  final double actualBoundingBoxRight;
  final double actualBoundingBoxAscent;
  final double actualBoundingBoxDescent;
  final double fontBoundingBoxAscent;
  final double fontBoundingBoxDescent;
}
```

## Transformations

### Matrix4

4x4 transformation matrix.

```dart
class Matrix4 {
  // Constructors
  Matrix4.identity()
  Matrix4.translation(double x, double y, [double z = 0])
  Matrix4.rotation(double angle)
  Matrix4.scaling(double x, [double? y, double? z])
  
  // Operations
  void translate(double x, double y, [double z = 0])
  void rotate(double angle)
  void scale(double x, [double? y, double? z])
  Matrix4 multiply(Matrix4 other)
  Matrix4 get inverse
  Point transform(Point point)
}
```

## Image Operations

### Bitmap

Pixel buffer representation.

```dart
class Bitmap {
  final int width;
  final int height;
  Uint32List get pixels
  
  // Constructors
  Bitmap(int width, int height)
  static Future<Bitmap> fromFile(String path)
  static Bitmap fromBytes(Uint8List bytes, int width, int height)
  
  // Methods
  Color getPixel(int x, int y)
  void setPixel(int x, int y, Color color)
  Bitmap clone()
  Future<void> saveToFile(String path)
}
```

### Image Rendering

```dart
class ImageRenderer {
  static void render(
    Bitmap source,
    Bitmap destination,
    Matrix4 transform,
    {Paint? paint, double opacity = 1.0}
  );
}
```

## Filters

### Applying Filters

```dart
void applyGaussianBlur(double radius)
void applyBoxBlur(double radius)
void applySharpen([double amount = 1.0])
void applyEdgeDetect({int threshold = 128})
void applyEmboss()
void applyMotionBlur(double angle, double distance)
```

### Custom Filters

```dart
void applyConvolution(List<List<double>> kernel, [double divisor = 1.0, double bias = 0.0])
```

## Clipping

### ClipRegion

```dart
class ClipRegion {
  void set(Path path, {FillRule fillRule = FillRule.nonZero})
  void intersect(Path path, {FillRule fillRule = FillRule.nonZero})
  void clear()
  bool contains(int x, int y)
}
```

### FillRule

```dart
enum FillRule {
  nonZero,  // Default winding rule
  evenOdd,  // Alternating fill rule
}
```

## Blend Modes

### Porter-Duff Modes

```dart
enum BlendMode {
  // Porter-Duff modes
  clear,
  src,
  dst,
  srcOver,    // Default
  dstOver,
  srcIn,
  dstIn,
  srcOut,
  dstOut,
  srcAtop,
  dstAtop,
  xor,
  plus,
  
  // Separable blend modes
  multiply,
  screen,
  overlay,
  darken,
  lighten,
  colorDodge,
  colorBurn,
  hardLight,
  softLight,
  difference,
  exclusion,
  
  // Non-separable blend modes
  hue,
  saturation,
  color,
  luminosity,
}
```

## Utility Classes

### Point

```dart
class Point {
  final double x;
  final double y;
  
  Point(this.x, this.y);
  Point transform(Matrix4 matrix);
  double distanceTo(Point other);
}
```

### Rectangle

```dart
class Rectangle {
  final double x;
  final double y;
  final double width;
  final double height;
  
  Rectangle(this.x, this.y, this.width, this.height);
  bool contains(Point point);
  Rectangle intersect(Rectangle other);
  Rectangle union(Rectangle other);
}
```

### ColorStop

```dart
class ColorStop {
  final double offset;  // 0.0 to 1.0
  final Color color;
  
  ColorStop(this.offset, this.color);
}
```

## Error Handling

### GraphicsException

```dart
class GraphicsException implements Exception {
  final String message;
  GraphicsException(this.message);
}
```

Common exceptions:

- Invalid image format
- File not found
- Invalid transformation matrix
- Clipping region errors
- Font loading errors

## Performance Considerations

### Best Practices

1. **Path Caching**: Build paths once and reuse them
2. **State Management**: Minimize save/restore calls
3. **Batch Operations**: Group similar operations
4. **Transform Optimization**: Combine transformations when possible
5. **Image Caching**: Load images once and reuse

### Memory Management

- Bitmaps are stored as `Uint32List` (4 bytes per pixel)
- Large canvases consume significant memory (width × height × 4 bytes)
- Dispose of unused bitmaps when possible
- Use appropriate image formats for your needs

## Thread Safety

libgfx is not thread-safe. All operations should be performed on the same thread. For concurrent rendering, create
separate `GraphicsEngine` instances.

## Platform Support

libgfx is pure Dart and runs on all platforms that support Dart:

- Flutter (iOS, Android, Web, Desktop)
- Dart VM
- Dart Native (AOT compiled)

## See Also

- [Getting Started Guide](getting-started.md)
- [Advanced Features](advanced-features.md)
- [Examples](examples.md)
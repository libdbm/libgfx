# API Reference

Complete API documentation for libgfx graphics engine.

## Table of Contents

- [GraphicsEngine](#graphicsengine)
- [Color](#color)
- [Path and PathBuilder](#path-and-pathbuilder)
- [Paint System](#paint-system)
- [Text and Fonts](#text-and-fonts)
- [Transformations](#transformations)
- [Image Operations](#image-operations)
- [Filters](#filters)
- [Clipping](#clipping)
- [Blend Modes](#blend-modes)
- [File IO and GraphicsFileSystem](#file-io-and-graphicsfilesystem)

## GraphicsEngine

The main class for creating and manipulating graphics.

### Constructor

<!-- snippet: skip -->
```dart
GraphicsEngine(int width, int height, {Rasterizer? rasterizer, GraphicsFileSystem? filesystem, Limits limits = const Limits()})
GraphicsEngine.withCanvas(Bitmap bitmap, {Rasterizer? rasterizer, GraphicsFileSystem? filesystem, Limits limits = const Limits()})
```

Creates a new graphics engine with the specified canvas dimensions, or one that draws into an existing bitmap.

### Basic Drawing Methods

The engine has no current path: build a `Path` (see [PathBuilder](#pathbuilder)) and pass it to `fill`, `stroke` or `clip`.
For how coordinates map to pixels and how fill rules decide the inside of a path, see the
[Rendering Model](rendering-model.md). Names follow the W3C `CanvasRenderingContext2D` API where it has an equivalent.

#### Fill Operations

<!-- snippet: skip -->
```dart
Paint fillStyle  // Getter and setter; a Color paints solid
void fill(Path path, {FillRule rule = FillRule.nonZero, bool text = false})
void fillRect(double x, double y, double width, double height)
void fillText(String text, double x, double y)
```

#### Stroke Operations

<!-- snippet: skip -->
```dart
Paint strokeStyle  // Getter and setter; a Color paints solid
double lineWidth
void stroke(Path path)
void strokeRect(double x, double y, double width, double height)
void strokeText(String text, double x, double y)
```

Other shapes are built with `PathBuilder` (`rect`, `roundRect`, `circle`, `ellipse`, `arc`, `polygon`, `star`) and
passed to `fill` or `stroke`:

```dart
engine.fill(PathBuilder().roundRect(10, 10, 100, 60, 8).build());
engine.stroke(PathBuilder().circle(200, 50, 30).build());
```

#### Line Styling

<!-- snippet: skip -->
```dart
LineCap lineCap
  // LineCap.butt (default)
  // LineCap.round
  // LineCap.square

LineJoin lineJoin
  // LineJoin.miter (default)
  // LineJoin.round
  // LineJoin.bevel

double miterLimit  // Default 4.0
void setLineDash(List<double> segments)  // An empty list draws solid lines; there is no dash offset
```

### State Management

<!-- snippet: skip -->
```dart
void save()
void restore()
```

`save` pushes a copy of the whole graphics state: transform, clip, fill and stroke paints, stroke settings, global
alpha, blend mode, and the text settings (font, size, alignment and baseline). `restore` pops it.

### Transformations

<!-- snippet: skip -->
```dart
void translate(double x, double y)
void rotate(double angle)
void scale(double x, [double? y])
void transform(double a, double b, double c, double d, double e, double f)
void setTransform(double a, double b, double c, double d, double e, double f)
void resetTransform()
```

### Clipping

<!-- snippet: skip -->
```dart
void clip(Path path, {FillRule rule = FillRule.nonZero})
void clipRect(double x, double y, double width, double height)
void clipText(String text, double x, double y)
```

Each clip intersects the current clip region. There is no method to remove a clip; wrap clipped drawing in
`save`/`restore` instead.

### Canvas Operations

<!-- snippet: skip -->
```dart
Bitmap canvas
int get width
int get height
void clear([Color color = const Color(0x00000000)])
void clearRect(double x, double y, double width, double height)
Color pixel(int x, int y)  // Bitmap coordinates
void plot(int x, int y, Color color)
ImageData getImageData(int x, int y, int width, int height)  // A copy, bitmap coordinates
void putImageData(ImageData image, int dx, int dy, [int dirtyX = 0, int dirtyY = 0, int? dirtyWidth, int? dirtyHeight])
Bitmap snapshot()  // A copy of the canvas
Future<void> write(String path, {String? format})
void drawImage(Bitmap image, double dx, double dy, {double? width, double? height, Rectangle<double>? source, ImageFilter filter = ImageFilter.nearest})
```

`drawImage` covers the three W3C forms: give `width` and `height` to scale, and `source` to draw part of the image.
`filter` samples scaled or transformed images (`nearest`, `bilinear` or `bicubic`).

`ImageData` holds `width`, `height` and `data`, four bytes per pixel in red, green, blue, alpha order from the top
row, as in W3C canvas. `getImageData` returns transparent black for pixels outside the canvas; `putImageData` replaces
pixels, ignoring the transform, clip, `globalAlpha` and composite operation, and writes only the dirty rectangle when
one is given, at its offset from (dx, dy).

### Blend Modes

<!-- snippet: skip -->
```dart
double globalAlpha
BlendMode globalCompositeOperation
```

## Color

Represents ARGB colors with 8 bits per channel.

### Constructors

<!-- snippet: skip -->
```dart
const Color(int value)  // 0xAARRGGBB format
const Color.fromARGB(int a, int r, int g, int b)
Color.fromRGBA(int r, int g, int b, int a)
Color.clamped(double r, double g, double b, double a)  // Rounds and clamps each channel to 0-255
```

### Properties

<!-- snippet: skip -->
```dart
int get value     // Raw ARGB value
int get alpha     // Alpha channel (0-255), also available as a
int get red       // Red channel (0-255), also available as r
int get green     // Green channel (0-255), also available as g
int get blue      // Blue channel (0-255), also available as b
double get opacity  // Alpha as 0.0-1.0
```

### Predefined Colors

<!-- snippet: skip -->
```dart
static const Color transparent = Color(0x00000000);
Color get white  // Instance getter returning Color(0xFFFFFFFF)
Color get black  // Instance getter returning Color(0xFF000000)
```

There is no `Colors` class; write other colors as `const Color(0xAARRGGBB)`.

## Path and PathBuilder

### Path

Represents a vector path.

<!-- snippet: skip -->
```dart
class Path {
  List<PathCommand> get commands  // Unmodifiable
  Rectangle get bounds
  Path clone()
  void add(PathCommand command)
  void addPath(Path other)
  Path transform(Matrix2D matrix)
  Path simplify(double tolerance)

  // Experimental, see below
  Path union(Path other)
  Path intersection(Path other)
  Path difference(Path other)
  Path xor(Path other)
}

class PathCommand {
  final PathCommandType type;
  final List<Point> points;  // Copied on construction and unmodifiable
  PathCommand(PathCommandType type, List<Point> points)
}

enum PathCommandType { moveTo, lineTo, cubicCurveTo, arc, ellipse, close }
```

`union`, `intersection`, `difference` and `xor` (and the matching static methods on `PathOperations`, together with
`PathOperations.offset`) are marked `@experimental`. They only approximate the named operations: each path is
flattened into a single ring, and the result is built from the points or edges of those rings rather than from their
areas. For example, `union` joins the two outlines into one ring and does not merge overlapping shapes. See the doc
comments in `lib/src/paths/path_operations.dart` for the exact behaviour of each.

### PathBuilder

Fluent builder for creating paths.

<!-- snippet: skip -->
```dart
class PathBuilder {
  PathBuilder moveTo(double x, double y)
  PathBuilder lineTo(double x, double y)
  PathBuilder quadraticCurveTo(double cpx, double cpy, double x, double y)
  PathBuilder bezierCurveTo(double cp1x, double cp1y, double cp2x, double cp2y, double x, double y)
  PathBuilder arcTo(double x1, double y1, double x2, double y2, double radius)
  PathBuilder arc(double x, double y, double radius, double startAngle, double endAngle, [bool counterclockwise = false])
  PathBuilder ellipse(double x, double y, double radiusX, double radiusY, double rotation, double startAngle, double endAngle, [bool counterclockwise = false])
  PathBuilder circle(double x, double y, double radius)
  PathBuilder rect(double x, double y, double width, double height)
  PathBuilder roundRect(double x, double y, double width, double height, double radius)
  PathBuilder polygon(double x, double y, double radius, int sides)
  PathBuilder star(double x, double y, double outer, double inner, int points)
  PathBuilder closePath()
  PathBuilder addPath(Path other)
  Path build()
}
```

`arc` and `ellipse` follow W3C canvas: they run from `startAngle` to `endAngle` in increasing angle unless
`counterclockwise`, and a sweep of a full turn or more draws the whole curve once.

## Paint System

### Paint (Abstract)

Base class for all paint types.

<!-- snippet: skip -->
```dart
abstract class Paint {
  Color sample(Point point, Matrix2D inverse);
}
```

### Color as paint

`Color` implements `Paint`, so a solid color is assigned wherever a paint is expected; `Color.parse('#FF0000')` reads
`#RRGGBB` or `#RRGGBBAA` and returns a `Result`.

### Gradients

Gradients are immutable. `LinearGradient`, `RadialGradient` and `ConicalGradient` extend `GradientPaint`, whose
`stops` are sorted by offset with offsets clamped to 0..1. `addColorStop` returns a new gradient of the same type.

<!-- snippet: skip -->
```dart
abstract class GradientPaint extends Paint {
  final List<ColorStop> stops;  // Unmodifiable
  final GradientSpread spread;
  GradientPaint addColorStop(double offset, Color color);
}
```

### LinearGradient

<!-- snippet: skip -->
```dart
class LinearGradient extends GradientPaint {
  LinearGradient({
    required Point start,
    required Point end,
    required List<ColorStop> stops,
    GradientSpread spread = GradientSpread.pad,
  });
}
```

### RadialGradient

<!-- snippet: skip -->
```dart
class RadialGradient extends GradientPaint {
  RadialGradient({
    required Point center,
    required double radius,
    required List<ColorStop> stops,
    GradientSpread spread = GradientSpread.pad,
    Point? focal,
  });
}
```

### ConicalGradient

<!-- snippet: skip -->
```dart
class ConicalGradient extends GradientPaint {
  ConicalGradient({
    required Point center,
    double startAngle = 0.0,
    required List<ColorStop> stops,
    GradientSpread spread = GradientSpread.pad,
  });
}
```

### Engine Factories

The gradient factories return gradients with no stops; add stops with `addColorStop`.

<!-- snippet: skip -->
```dart
LinearGradient createLinearGradient(double x0, double y0, double x1, double y1)
RadialGradient createRadialGradient(double x0, double y0, double r0, double x1, double y1, double r1)
ConicalGradient createConicGradient(double startAngle, double x, double y)
PatternPaint createPattern(Bitmap image, PatternRepeat repeat, [Matrix2D? transform])
```

`createRadialGradient` uses the second circle as the center and radius, and the first center as the focal point when
`r0 > 0`.

```dart
final gradient = engine
    .createLinearGradient(0, 0, 200, 0)
    .addColorStop(0, const Color(0xFFFF0000))
    .addColorStop(1, const Color(0xFF0000FF));
engine.fillStyle = gradient;
engine.fillRect(0, 0, 200, 100);
```

### PatternPaint

<!-- snippet: skip -->
```dart
class PatternPaint extends Paint {
  PatternPaint({
    required Bitmap pattern,
    Matrix2D? transform,
    PatternRepeat repeat = PatternRepeat.repeat,
    double opacity = 1.0,
  });
  Bitmap get pattern  // A copy
  Matrix2D get transform  // A copy
}

enum PatternRepeat { repeat, repeatX, repeatY, noRepeat }
```

The constructor copies `pattern` and `transform`, so later changes to them do not affect the paint. A singular
transform makes the pattern paint nothing.

### GradientSpread

<!-- snippet: skip -->
```dart
enum GradientSpread {
  pad,      // Extend with edge colors
  reflect,  // Mirror gradient
  repeat,   // Repeat gradient
}
```

## Text and Fonts

### Font Loading

<!-- snippet: skip -->
```dart
Future<Result<TTFFont, ErrorDetails>> loadFont(String path)
Result<TTFFont, ErrorDetails> readFont(Uint8List bytes)

static Future<Result<TTFFont, ErrorDetails>> TTFFont.load(String path, {required GraphicsFileSystem filesystem, Limits limits = const Limits()})
static Result<TTFFont, ErrorDetails> TTFFont.fromBytes(Uint8List bytes, {Limits limits = const Limits()})
```

On failure the engine keeps its current font. The engine applies the `Limits` it was created with. `loadFont`
requires a configured [GraphicsFileSystem](#file-io-and-graphicsfilesystem).

### Text Configuration

<!-- snippet: skip -->
```dart
Font? font  // Getter and setter
double fontSize  // Default 12.0
TextAlign textAlign
  // TextAlign.start (default): left for left-to-right text, right for right-to-left
  // TextAlign.end: right for left-to-right text, left for right-to-left
  // TextAlign.left
  // TextAlign.center
  // TextAlign.right
  // TextAlign.justify

TextBaseline textBaseline
  // TextBaseline.alphabetic (default)
  // TextBaseline.top
  // TextBaseline.middle
  // TextBaseline.bottom
  // TextBaseline.ideographic
  // TextBaseline.hanging

TextDirection direction
  // TextDirection.ltr (default)
  // TextDirection.rtl
  // TextDirection.auto: from the first strong character

TextRendering textRendering
  // TextRendering.auto (default), optimizeSpeed, optimizeLegibility: partly covered pixels darkened
  // TextRendering.geometricPrecision: exact coverage
```

Font, size, alignment, baseline, direction and rendering are part of the saved state, so `restore` returns them to
their values at the matching `save`. Text is shaped one glyph per character, with the font's `ccmp` and `liga`
ligatures (flags, emoji sequences, `fi`), and laid out by a simplified Unicode bidirectional algorithm (UAX #9 without
explicit embeddings, isolates or bracket pairs) in the paragraph `direction`: right-to-left runs read right to left,
brackets in them are mirrored, and Arabic letters join through the font's presentation forms.

Unhinted glyph stems that fall between pixels draw as two grey columns. Unless `textRendering` is
`geometricPrecision`, `fillText` and `strokeText` map coverage `c` to `c^0.6` so that they read less blurred, and
`fill(path, text: true)` does the same for glyph outlines from `TextRenderer` or `Font.path`.

### Text Drawing

<!-- snippet: skip -->
```dart
void fillText(String text, double x, double y)
void strokeText(String text, double x, double y)
void clipText(String text, double x, double y)
```

### Text Measurement

<!-- snippet: skip -->
```dart
TextMetrics measureText(String text)

class TextMetrics {
  final double width;
  final double height;
  final double ascent;
  final double descent;
  final double lineHeight;
}
```

## Transformations

### Matrix2D

2D affine transformation matrix `[a c tx; b d ty]`.

<!-- snippet: skip -->
```dart
class Matrix2D {
  double a, b, c, d, tx, ty;

  // Constructors
  Matrix2D(double a, double b, double c, double d, double tx, double ty)
  Matrix2D.identity()
  Matrix2D.copy(Matrix2D other)
  Matrix2D.translation(double x, double y)
  Matrix2D.scaling(double x, double y)
  Matrix2D.rotation(double radians)

  // Operations (these modify the matrix in place)
  void reset()  // To identity
  void translate(double x, double y)
  void scale(double x, [double? y])
  void rotate(double radians)
  void shear(double x, double y)
  void multiply(Matrix2D other)
  void premultiply(Matrix2D other)
  void assign(double a, double b, double c, double d, double tx, double ty)

  // Queries
  Matrix2D clone()
  Matrix2D operator *(Matrix2D other)
  Point transform(Point point)
  Point direction(Point vector)  // Applies the matrix without its translation
  Result<Matrix2D, ErrorDetails> inverse()  // Err with ErrorKind.singular when not invertible
  ({Point translation, double rotation, Point scale}) decompose()
  double get determinant
  bool get isInvertible
  bool get isIdentity
}
```

## Image Operations

### Bitmap

Pixel buffer representation.

<!-- snippet: skip -->
```dart
class Bitmap {
  final int width;
  final int height;
  Uint32List get pixels

  // Constructors
  Bitmap(int width, int height)
  Bitmap.fromPixels(int width, int height, Uint32List pixels)
  Bitmap.empty(int width, int height)

  // Methods
  Color pixel(int x, int y)
  void plot(int x, int y, Color color)
  void clear(Color color)
  Bitmap clone()
  Bitmap scale(int columns, int rows)
  Bitmap crop(int x, int y, int columns, int rows)
  Bitmap mirror()  // Left to right
  Bitmap flip()  // Top to bottom
  Bitmap rotate90()
  Bitmap rotate180()
  Bitmap rotate270()
  Bitmap rotate(double angle, [Color background = Color.transparent])
  Bitmap fade(double opacity)
}
```

### Loading and Saving Images

<!-- snippet: skip -->
```dart
static Result<Bitmap, ErrorDetails> GraphicsEngine.decode(Uint8List bytes, {String? format, Limits limits = const Limits()})
static Uint8List GraphicsEngine.encode(Bitmap image, String format)  // "png", "bmp", "p3"/"ppm", "p6"
```

Without a `format`, `decode` detects PNG, BMP and P3/P6 PPM from the data. Draw a loaded image with the engine's
`drawImage` (see [Canvas Operations](#canvas-operations)).

## Filters

### Applying Filters

Filters are static methods on `ImageFilters`. Each takes a source `Bitmap` and returns a new one; apply the result to
the canvas with `drawImage`.

<!-- snippet: skip -->
```dart
static Bitmap ImageFilters.gaussian(Bitmap source, double sigma, {Limits limits = const Limits()})
static Bitmap ImageFilters.box(Bitmap source, int radius, {Limits limits = const Limits()})
static Bitmap ImageFilters.stack(Bitmap source, int radius, {Limits limits = const Limits()})
static Bitmap ImageFilters.motion(Bitmap source, double angle, int distance, {Limits limits = const Limits()})
static Bitmap ImageFilters.sharpen(Bitmap source, double amount)
static Bitmap ImageFilters.edges(Bitmap source, {double threshold = 128})
static Bitmap ImageFilters.emboss(Bitmap source, {double strength = 1.0})
```

The blur radius (for `gaussian`, the kernel radius of `3 * sigma`) is checked against `limits.radius`.

### Custom Filters

<!-- snippet: skip -->
```dart
static Bitmap ImageFilters.convolve(Bitmap source, List<List<double>> kernel)
```

## Clipping

### ClipRegion

<!-- snippet: skip -->
```dart
class ClipRegion {
  final Rectangle<int> bounds;
  final FillRule rule;

  ClipRegion.fromPath(Path path, Matrix2D transform, int width, int height, {FillRule rule = FillRule.evenOdd, Rasterizer? rasterizer})
  ClipRegion.fromRect(int x, int y, int width, int height)
  ClipRegion.empty()

  ClipRegion intersect(ClipRegion other)
  ClipRegion clone()
  bool contains(int x, int y)
  int coverage(int x, int y)
  bool includes(Point point)
  bool get isEmpty
}
```

### FillRule

<!-- snippet: skip -->
```dart
enum FillRule {
  evenOdd,  // Alternating fill rule
  nonZero,  // Winding rule
}
```

`fill` and the engine's `clip` default to `FillRule.nonZero`, as W3C canvas does. See
[Fill rules](rendering-model.md#fill-rules) in the Rendering Model.

## Blend Modes

### Porter-Duff Modes

<!-- snippet: skip -->
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

  // Additional blend modes
  add,
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
}
```

## Utility Classes

### Point

Immutable 2D point or vector.

<!-- snippet: skip -->
```dart
class Point {
  final double x;
  final double y;

  const Point(this.x, this.y);
  static Point get zero
  static Point lerp(Point a, Point b, double t)
  static Point midpoint(Point a, Point b)

  double get length
  double get length2
  Point normalized()
  double dot(Point other)
  double cross(Point other)
  double distance(Point other)
  double distance2(Point other)  // Squared
  Point rotate(double angle)
  Point rotateAround(Point center, double angle)
  bool equals(Point other, {double tolerance = 1e-9})
  Point operator +(Point other)
  Point operator -(Point other)
  Point operator *(double scale)
}
```

### Rectangle

<!-- snippet: skip -->
```dart
class Rectangle<T extends num> {
  final T left;
  final T top;
  final T width;
  final T height;

  const Rectangle(this.left, this.top, this.width, this.height);
  Rectangle.fromLTRB(T left, T top, T right, T bottom)
  Rectangle.fromLTWH(T left, T top, T width, T height)
  Rectangle.fromCenter(T cx, T cy, T width, T height)

  T get right
  T get bottom
  bool get isEmpty
  Rectangle<T>? intersection(Rectangle<T> other)  // null when they do not overlap
}
```

### ColorStop

<!-- snippet: skip -->
```dart
class ColorStop {
  final double offset;  // 0.0 to 1.0
  final Color color;

  ColorStop(this.offset, this.color);
}
```

## Error Handling

### Result

Operations whose failure is an expected outcome, such as decoding untrusted font or image data, return
`Result<T, ErrorDetails>` instead of throwing. This covers `TTFFont.fromBytes`, `TTFFont.load`,
`GraphicsEngine.readFont`, `GraphicsEngine.loadFont`, `GraphicsEngine.decode` and
`Matrix2D.inverse`.

<!-- snippet: skip -->
```dart
sealed class Result<T, E> {
  Result<U, E> map<U>(U Function(T value) transform)
  Result<U, E> flatMap<U>(Result<U, E> Function(T value) transform)
  R fold<R>(R Function(T value) ok, R Function(E error) err)
}
final class Ok<T, E> extends Result<T, E> { final T value; }
final class Err<T, E> extends Result<T, E> { final E error; }

final class ErrorDetails {
  final ErrorKind kind;
  final String message;
  final Object? cause;
}

enum ErrorKind { truncated, malformed, unsupported, limit, io, singular }
```

```dart
final result = GraphicsEngine.decode(Uint8List(0));
switch (result) {
  case Ok(:final value):
    engine.drawImage(value, 0, 0);
  case Err(:final error):
    print('${error.kind.name}: ${error.message}');
}
```

### Limits

`Limits` bounds the resources that untrusted input may claim before memory is allocated. It is immutable; pass one to
the `GraphicsEngine` constructor, `TTFFont.fromBytes`, `GraphicsEngine.decode` or the blur filters.

<!-- snippet: skip -->
```dart
final class Limits {
  const Limits({
    int dimension = 32768,    // Largest width or height, in pixels
    int pixels = 1 << 28,     // Largest pixel count
    int font = 64 << 20,      // Largest font file, in bytes
    int depth = 16,           // Deepest composite glyph nesting
    int points = 65536,       // Largest expanded glyph size
    int radius = 256,         // Largest blur radius, in pixels
    int dashes = 1000000,     // Most dash pattern elements applied to one path
  });
}
```

### Exceptions

Programming errors and unrecoverable states throw. libgfx exceptions extend `LibgfxException`, which has a `message`
and an optional `cause`:

- `GraphicsException`, and its subclass `RenderException`
- `ResourceException`, and its subclasses `FontException` and `ImageException`
- `UnsupportedFormatException`
- `ConfigurationException`
- `ResourceLimitException`

Calling `write` or `loadFont` without a configured `GraphicsFileSystem` throws `UnsupportedError`.

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
- Release references to unused bitmaps so they can be garbage collected
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
- [Rendering Model](rendering-model.md)

## File IO and GraphicsFileSystem

libgfx performs all file IO (reading fonts/images and writing images) through a pluggable GraphicsFileSystem so it can run on the web and in isolates without depending on dart:io.

- Interface: GraphicsFileSystem (lib/src/io/file_system.dart)
  - Future<Uint8List?> read(String path)
  - Future<void> write(String path, List<int> bytes)
- Default VM adapter: LocalGraphicsFileSystem (import from package:libgfx/io/local_file_system.dart)

When you want to use write or loadFont you must attach a GraphicsFileSystem to the engine.

Example (VM/CLI):

```dart
import 'package:libgfx/libgfx.dart';
import 'package:libgfx/io/local_file_system.dart';

void main() async {
  final engine = GraphicsEngine(400, 300, filesystem: const LocalGraphicsFileSystem());

  engine.fillStyle = const Color(0xFF009688);
  engine.fillRect(50, 50, 200, 150);

  // Load a font using the filesystem
  final font = await engine.loadFont('data/fonts/Roboto-Regular.ttf');
  if (font case Err(:final error)) {
    print('Font not loaded: ${error.message}');
  }
  engine.fontSize = 24;
  engine.fillText('Hello FS', 80, 130);

  // Save using the filesystem
  await engine.write('output/example.png');
}
```

Methods that require a configured filesystem:
- GraphicsEngine.write
- GraphicsEngine.loadFont
- Any helper in io/ that reads fonts/images via the filesystem

Notes:
- On web, provide your own GraphicsFileSystem implementation backed by HTTP or asset bundles.
- LocalGraphicsFileSystem lives under package:libgfx/io/ so apps targeting the VM can opt-in without pulling dart:io into web builds.

Breaking change notice:
- Recent versions introduced GraphicsFileSystem and removed direct dart:io usage from core APIs. If you previously called write or loadFont without configuration, you now must set engine.filesystem or pass filesystem: in the constructor. See Getting Started for migration tips.

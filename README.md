# libgfx

A comprehensive 2D vector graphics engine for Dart with software rasterization. Pure Dart implementation whose only
dependency is the `meta` annotations package, providing high-quality rendering for vector graphics, text, and images.

## Features

### Core Graphics

- **Vector Graphics**: Full path support with lines, Bézier curves, arcs, and complex transformations
- **Software Rasterization**: High-performance scanline-based rendering with sub-pixel precision
- **Anti-aliasing**: Exact-area pixel coverage, or aliased rendering with `BasicRasterizer(antiAlias: false)`
- **Transform Stack**: Full save/restore state management with nested transformations

### Text & Fonts

- **TrueType Font Support**: Complete TTF parser with glyph rendering
- **Text Layout**: Kerning, alignment, baselines, line wrapping, and Unicode support
- **Text Metrics**: Precise font measurements and bounding box calculations
- **Font Fallback**: Automatic fallback for missing glyphs

### Painting & Effects

- **Gradients**: Linear, radial, and conic gradients with multiple color stops
- **Patterns**: Bitmap patterns with repeat modes
- **Blend Modes**: Complete Porter-Duff compositing and separable blend modes
- **Image Filters**: Gaussian blur, box blur, sharpen, edge detection, emboss, motion blur
- **Stroke Styles**: Configurable line caps (butt, round, square), joins (miter, round, bevel), and dashing

### Advanced Features

- **Clipping**: Complex clipping regions with even-odd and non-zero winding rules
- **Path Operations** (experimental): approximate union, intersection, difference, XOR and offset; see their API
  documentation for what they actually compute
- **Image Codecs**: PNG (every colour type and bit depth, transparency, interlacing), BMP (24- and 32-bit) and PPM
  (P3 and P6) decoding and encoding, returning a `Result` instead of throwing on bad input
- **Resource Limits**: `Limits` bounds image size, font size, glyph complexity, blur radius and dash count for
  untrusted input

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  libgfx: ^2.0.0
```

### Font Setup

Fonts are not included in the package to reduce size. Download them using:

```bash
./scripts/download_fonts.sh
```

See [data/fonts/README.md](data/fonts/README.md) for manual download instructions.

## Quick Start

### Basic Drawing

```dart
import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

void main() async {
  // Create a 400x300 canvas and attach the default IO adapter
  final engine = GraphicsEngine(
    400,
    300,
    filesystem: const LocalGraphicsFileSystem(),
  );
  
  // Set up styling
  engine.fillStyle = const Color(0xFFFF0000); // Red
  engine.strokeStyle = const Color(0xFF0000FF); // Blue
  engine.lineWidth = 3.0;
  
  // Draw a rectangle using a path
  final path = (PathBuilder()
        ..moveTo(50, 50)
        ..lineTo(200, 50)
        ..lineTo(200, 150)
        ..lineTo(50, 150)
        ..closePath())
      .build();
  
  engine.fill(path);
  engine.stroke(path);
  
  // Or use convenience methods
  engine.fillRect(250, 50, 100, 100);
  engine.strokeRect(250, 50, 100, 100);
  
  // Save to file (defaults to PPM format)
  await engine.write('output.ppm');
  
  // For other formats, use the codec system:
  final pngBytes = GraphicsEngine.encode(engine.canvas, 'png');
  await engine.filesystem?.write('output.png', pngBytes);
}
```

## Text Rendering

```dart
import 'package:libgfx/io/local_file_system.dart';

// Ensure the engine has a file system before loading fonts
engine.filesystem ??= const LocalGraphicsFileSystem();

// Load a font; failures are returned, not thrown, and keep the current font
final loaded = await engine.loadFont('fonts/Roboto-Regular.ttf');
if (loaded case Err(:final error)) {
  print('Cannot load font: ${error.message}');
}
engine.fontSize = 24;
engine.textAlign = TextAlign.center;
engine.textBaseline = TextBaseline.middle;

// Render text
engine.fillStyle = Color.fromRGBA(0, 0, 0, 255);
engine.fillText('Hello, World!', 200, 150);
```

Font, size, alignment and baseline are part of the graphics state, so `save()` and `restore()` cover them.

## Gradients

```dart
// Linear gradient
final gradient = LinearGradient(
  start: Point(0, 0),
  end: Point(200, 0),
  stops: [
    ColorStop(0.0, Color.fromRGBA(255, 0, 0, 255)),
    ColorStop(1.0, Color.fromRGBA(0, 0, 255, 255)),
  ],
);
engine.fillStyle = gradient;

// Radial gradient, built from the engine's factory; gradients are
// immutable, so addColorStop returns a new gradient
final radial = engine
    .createRadialGradient(100, 100, 0, 100, 100, 50)
    .addColorStop(0.0, Color.fromRGBA(255, 255, 255, 255))
    .addColorStop(1.0, Color.fromRGBA(0, 0, 0, 255));
engine.fillStyle = radial;
```

## Transformations

```dart
import 'dart:math' as math;

final path = (PathBuilder()
      ..moveTo(0, 0)
      ..lineTo(20, 0)
      ..lineTo(0, 20)
      ..closePath())
    .build();

// Apply transformations
engine.save();
engine.translate(100, 100);
engine.rotate(math.pi / 4);
engine.scale(2.0, 2.0);

// Draw transformed content
engine.fill(path);

engine.restore();
```

## Image Filters

Filters take a bitmap and return a new one:

```dart
// Apply Gaussian blur
final blurred = ImageFilters.gaussian(engine.canvas, 5.0);

// Apply sharpening
final sharpened = ImageFilters.sharpen(engine.canvas, 1.5);

// Apply edge detection
final edges = ImageFilters.edges(engine.canvas, threshold: 128);

// Draw a result back onto the canvas
engine.drawImage(blurred, 0, 0);
```

## Advanced Clipping

```dart
import 'dart:math' as math;

// Create a circular clipping region: centre, radius, start angle, sweep
final clipPath = PathBuilder()
  ..arc(100, 100, 50, 0, math.pi * 2)
  ..closePath();

engine.clip(clipPath.build(), rule: FillRule.nonZero);
```

`clip()` uses the even-odd rule; `fill()` uses non-zero unless given a rule.

## Documentation

Comprehensive documentation is available in the `doc/` directory:

- [Getting Started Guide](doc/getting-started.md) - Installation and basic usage
- [API Reference](doc/api-reference.md) - Complete API documentation
- [Advanced Features](doc/advanced-features.md) - Filters, clipping, path operations
- [Examples](doc/examples.md) - Complete working examples
- [Rendering Model](doc/rendering-model.md) - Coordinates, coverage, compositing and fill rules, with the tests that
  pin them

## Example Programs

The `example/` directory contains runnable example programs. Each draws at twice its page size
(`GraphicsEngine(2 * width, 2 * height)..scale(2, 2)`), so its output is sharp on high-DPI screens; the drawing code is
in page units.

### Basic Examples

- `example.dart` - Basic shapes and paths
- `drawing.dart` - Simple drawing operations
- `smiley.dart` - Drawing a smiley face
- `curve_methods_demo.dart` - Cubic and quadratic Bezier curve methods

### Text & Fonts

- `ttf_demo.dart` - TrueType font demonstration
- `unicode_text_demo.dart` - Unicode text support

### Gradients & Patterns

- `gradient_spread_demo.dart` - Gradient spread modes
- `pattern_paint_demo.dart` - Pattern fill examples
- `waterfall.dart` - Gradient waterfall effect

### Advanced Graphics

- `advanced_features_demo.dart` - Comprehensive feature showcase
- `blend_modes_demo.dart` - All blend mode demonstrations
- `clip_demo.dart` - Clipping region examples
- `clipping.dart` - A dashed circle clipped to a star
- `path_operations_demo.dart` - Path operations, including the experimental boolean operations
- `image_demo.dart` - Drawing images with each sampling filter
- `quality_demo.dart` - Fill rules, text and curve quality
- `antialiasing_test.dart` - Anti-aliased shape edges

### Strokes & Dashes

- `stroking.dart` - Stroke styles and line joins
- `dashes.dart` - Dash patterns and effects
- `square_cap_demo.dart` - Line cap demonstrations

### Transformations

- `nested_transforms.dart` - Complex transformation stacks
- `state_spiral.dart` - State management with spirals

### Artistic Examples

- `snowflake.dart` - Procedural snowflake generation
- `escher.dart` - Escher-like patterns
- `tiger.dart` - Complex path rendering

### Tools

- `compare_images.dart` - Compares two PPM images pixel by pixel

## Architecture

The library uses a layered architecture:

1. **GraphicsEngine** - High-level facade API
2. **GraphicsContext** - State management and coordination
3. **Core Components**:
    - Path - Vector path representation
    - Paint - Color, gradient, and pattern system
    - Rasterizer - Scanline-based software rendering
    - Stroker - Path stroking and outlining
    - Bitmap - Pixel buffer management

## Development

```bash
# Run tests
dart test

# Run specific test
dart test test/graphics_context_test.dart

# Analyze code
dart analyze

# Run examples
dart run example/example.dart
```

## Publishing to pub.dev

To publish this package to pub.dev, follow these steps:

### Prerequisites

1. Ensure you have the Dart SDK installed
2. Verify you have a pub.dev account and are logged in:
   ```bash
   dart pub login
   ```

### Pre-publish Checklist

1. **Update version**: Bump the version in `pubspec.yaml` following [semantic versioning](https://semver.org/)
2. **Update CHANGELOG.md**: Document all changes in the new version
3. **Run tests**: Ensure all tests pass
   ```bash
   dart test
   ```
4. **Analyze code**: Fix any analysis issues
   ```bash
   dart analyze
   ```
5. **Format code**: Ensure consistent formatting
   ```bash
   dart format .
   ```
6. **Validate package**: Check for any publishing issues
   ```bash
   dart pub publish --dry-run
   ```

### Publishing

1. **Publish the package**:
   ```bash
   dart pub publish
   ```
2. **Tag the release** (recommended):
   ```bash
   git tag v<version>
   git push origin v<version>
   ```

### Post-publish

- Verify the package appears correctly on [pub.dev](https://pub.dev)
- Test installation in a new project to ensure everything works
- Update any documentation that references the new version

## Roadmap / Future Enhancements

The following features are planned for future releases:

### Graphics Engine Enhancements

- **Boolean Path Operations**: True area-based union, intersection, difference and XOR to replace the experimental
  edge-based versions
- **Path Offsetting**: Proper inside and outside offsets with configurable join types and miter limits

### Text & Font System

- **HarfBuzz Integration**: Advanced text shaping for complex scripts, ligatures, and bidirectional text
- **Font Chain Improvements**: Better fallback font selection and tracking

### Performance & Quality

- **GPU Acceleration**: Optional hardware-accelerated rendering backend
- **Multi-threading**: Parallel rasterization for improved performance
- **Advanced Anti-aliasing**: Sub-pixel rendering and coverage optimization

### Additional Features

- **SVG Import**: Full SVG documents (`SVGPath.parse` reads only `<path>` elements, with all their path commands, and
  their fill colours)
- **PDF Export**: Export graphics to PDF format
- **Animation Framework**: Timeline-based animation system
- **Vector Effects**: Stroke effects, shadows, and lighting

Contributions are welcome! Check the source code for `TODO` comments to find specific implementation points.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions to libgfx are welcome! Here's how you can help:

1. **Report bugs**: If you find a bug, please create an issue with a detailed description and steps to reproduce.
2. **Suggest features**: Have an idea for a new feature? Open an issue to discuss it.
3. **Submit pull requests**: Want to fix a bug or add a feature? Fork the repository, make your changes, and submit a pull request.

### Development Workflow

1. Fork the repository
2. Clone your fork: `git clone https://github.com/libdbm/libgfx.git`
3. Create a branch for your changes: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Run tests: `dart test`
6. Commit your changes: `git commit -m "Add your feature description"`
7. Push to your fork: `git push origin feature/your-feature-name`
8. Create a pull request

### Code Style

Please follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style) and run `dart format` before submitting your code.

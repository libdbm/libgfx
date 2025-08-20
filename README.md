# libgfx

A comprehensive 2D vector graphics engine for Dart with software rasterization. Pure Dart implementation with no
external dependencies, providing high-quality rendering for vector graphics, text, and images.

## Features

### Core Graphics

- **Vector Graphics**: Full path support with lines, Bézier curves, arcs, and complex transformations
- **Software Rasterization**: High-performance scanline-based rendering with sub-pixel precision
- **Anti-aliasing**: Superior edge smoothing with configurable quality levels
- **Transform Stack**: Full save/restore state management with nested transformations

### Text & Fonts

- **TrueType Font Support**: Complete TTF parser with glyph rendering
- **Advanced Text Layout**: Kerning, ligatures, and unicode support
- **Text Metrics**: Precise font measurements and bounding box calculations
- **Multiple Font Formats**: Support for various font weights and styles
- **Font Fallback**: Automatic fallback for missing glyphs

### Painting & Effects

- **Gradients**: Linear, radial, and conic gradients with multiple color stops
- **Patterns**: Bitmap patterns with repeat modes
- **Blend Modes**: Complete Porter-Duff compositing and separable blend modes
- **Image Filters**: Gaussian blur, box blur, sharpen, edge detection, emboss, motion blur
- **Stroke Styles**: Configurable line caps (butt, round, square), joins (miter, round, bevel), and dashing

### Advanced Features

- **Clipping**: Complex clipping regions with even-odd and non-zero winding rules
- **Path Operations**: Boolean operations (union, intersection, difference, XOR)
- **Image Codecs**: PNG, BMP, PPM/P3/P6 format support

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  libgfx: ^1.0.0
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
import 'package:libgfx/libgfx.dart';

void main() async {
  // Create a 400x300 canvas
  final engine = GraphicsEngine(400, 300);
  
  // Set up styling
  engine.setFillColor(const Color(0xFFFF0000)); // Red
  engine.setStrokeColor(const Color(0xFF0000FF)); // Blue
  engine.setStrokeWidth(3.0);
  
  // Draw a rectangle using path
  final path = PathBuilder()
    ..moveTo(50, 50)
    ..lineTo(200, 50)
    ..lineTo(200, 150)
    ..lineTo(50, 150)
    ..close();
  
  engine.fill(path.build());
  engine.stroke(path.build());
  
  // Or use convenience methods
  engine.fillRect(250, 50, 100, 100);
  engine.strokeRect(250, 50, 100, 100);
  
  // Save to file (defaults to PPM format)
  await engine.saveToFile('output.ppm');
  
  // For other formats, use the codec system:
  final pngBytes = GraphicsEngine.saveImageToBytes(engine.canvas, 'png');
  await File('output.png').writeAsBytes(pngBytes);
}
```

## Text Rendering

```dart
// Load a font
await engine.setFontFromFile('fonts/Roboto-Regular.ttf');
engine.setFontSize(24);
engine.setTextAlign(TextAlign.center);
engine.setTextBaseline(TextBaseline.middle);

// Render text
engine.setFillColor(Color.fromRGBA(0, 0, 0, 255));
engine.fillText('Hello, World!', 200, 150);
```

## Gradients

```dart
// Linear gradient
final gradient = LinearGradient(
  startPoint: Point(0, 0),
  endPoint: Point(200, 0),
  colors: [
    Color.fromRGBA(255, 0, 0, 255),
    Color.fromRGBA(0, 0, 255, 255),
  ],
  stops: [0.0, 1.0],
);
engine.setFillPaint(gradient);

// Radial gradient
final radial = RadialGradient(
  center: Point(100, 100),
  radius: 50,
  colors: [
    Color.fromRGBA(255, 255, 255, 255),
    Color.fromRGBA(0, 0, 0, 255),
  ],
  stops: [0.0, 1.0],
);
engine.setFillPaint(radial);
```

## Transformations

```dart
// Apply transformations
engine.save();
engine.translate(100, 100);
engine.rotate(math.pi / 4);
engine.scale(2.0, 2.0);

// Draw transformed content
engine.fill(path.build());

engine.restore();
```

## Image Filters

```dart
// Apply Gaussian blur
engine.applyGaussianBlur(5.0);

// Apply sharpening
engine.applySharpen(1.5);

// Apply edge detection
engine.applyEdgeDetect(threshold: 128);
```

## Advanced Clipping

```dart
// Create a circular clipping region
final clipPath = PathBuilder()
  ..moveTo(150, 100)
  ..arcTo(100, 100, 50, 0, math.pi * 2, false)
  ..close();

engine.clipWithFillRule(clipPath.build(), fillRule: FillRule.evenOdd);
```

## Documentation

Comprehensive documentation is available in the `doc/` directory:

- [Getting Started Guide](doc/getting-started.md) - Installation and basic usage
- [API Reference](doc/api-reference.md) - Complete API documentation
- [Advanced Features](doc/advanced-features.md) - Filters, clipping, path operations
- [Examples](doc/examples.md) - Complete working examples

## Example Programs

The `example/` directory contains runnable example programs:

### Basic Examples

- `example.dart` - Basic shapes and paths
- `drawing.dart` - Simple drawing operations
- `smiley.dart` - Drawing a smiley face

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
- `path_operations_demo.dart` - Boolean path operations

### Strokes & Dashes

- `stroking.dart` - Stroke styles and line joins
- `dashes.dart` - Dash patterns and effects
- `square_cap_test.dart` - Line cap demonstrations

### Transformations

- `nested_transforms.dart` - Complex transformation stacks
- `state_spiral.dart` - State management with spirals
- `transform_utils_demo.dart` - Transform utilities

### Artistic Examples

- `snowflake.dart` - Procedural snowflake generation
- `escher.dart` - Escher-like patterns
- `tiger.dart` - Complex path rendering

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
dart test test/graphics_engine_test.dart

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

- **Gradient Support in Fluent API**: Full gradient implementation for `fillLinearGradient()` and `fillRadialGradient()`
  methods in FluentGraphicsEngine (currently uses first color stop as fallback)
- **Image Filters**: Complete implementation of `applyFilter()` method with support for blur, sharpen, edge detection,
  and other effects
- **Path Offsetting**: Proper path offset/outline operations with configurable join types and miter limits

### Text & Font System

- **HarfBuzz Integration**: Advanced text shaping for complex scripts, ligatures, and bidirectional text
- **Font Chain Improvements**: Better fallback font selection and tracking

### Performance & Quality

- **GPU Acceleration**: Optional hardware-accelerated rendering backend
- **Multi-threading**: Parallel rasterization for improved performance
- **Advanced Anti-aliasing**: Sub-pixel rendering and coverage optimization

### Additional Features

- **SVG Parser**: Import and render SVG files
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
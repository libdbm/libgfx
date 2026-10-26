# Getting Started with libgfx

This guide will help you get started with libgfx, a comprehensive 2D vector graphics engine for Dart.

## Installation

### From pub.dev

Add libgfx to your `pubspec.yaml`:

```yaml
dependencies:
  libgfx: ^2.0.0
```

### Using as a Local Package

Add libgfx to your `pubspec.yaml`:

```yaml
dependencies:
  libgfx:
    path: /path/to/libgfx
```

Then run:

```bash
dart pub get
```

## Breaking changes: GraphicsFileSystem requirement

Recent versions introduced a pluggable file system to decouple libgfx from dart:io. As a result, functions that perform IO (saving images, loading fonts from files) now require a configured GraphicsFileSystem.

Migration:
- VM/CLI: import `package:libgfx/io/local_file_system.dart` and either pass `filesystem: const LocalGraphicsFileSystem()` to the GraphicsEngine constructor or set `engine.filesystem = const LocalGraphicsFileSystem();` before calling `write` or `loadFont`.
- Web/other: implement `GraphicsFileSystem` for your platform (e.g., HTTP/asset-backed) and provide it to the engine.

See the API Reference section “File IO and GraphicsFileSystem” for details.

## Basic Concepts

### GraphicsEngine

The `GraphicsEngine` is your main entry point for drawing. It represents a canvas with a specific width and height:

```dart
import 'package:libgfx/libgfx.dart';

// Create a 800x600 canvas
final engine = GraphicsEngine(800, 600);
```

### Colors

Colors in libgfx use ARGB format with 8 bits per channel:

```dart
// Using hex notation (0xAARRGGBB)
final red = const Color(0xFFFF0000);
final blue = const Color(0xFF0000FF);
final semiTransparentGreen = const Color(0x8000FF00);

// Using individual channels in RGBA order
final yellow = Color.fromRGBA(255, 255, 0, 255);
```

### Paths

Paths are the foundation of vector graphics. Use `PathBuilder` to create complex shapes:

```dart
final path = PathBuilder()
  ..moveTo(10, 10)      // Move to starting point
  ..lineTo(100, 10)     // Draw line
  ..lineTo(100, 100)    // Draw another line
  ..lineTo(10, 100)     // And another
  ..closePath();            // Close the path

final builtPath = path.build();
```

## Your First Drawing

Let's create a simple drawing with basic shapes:

```dart
import 'package:libgfx/libgfx.dart';
import 'package:libgfx/io/local_file_system.dart';

void main() async {
  // Create canvas and configure filesystem for IO (required for save/load)
  final engine = GraphicsEngine(400, 400, filesystem: const LocalGraphicsFileSystem());
  
  // Set background (optional - default is transparent)
  engine.clear(const Color(0xFFF0F0F0));
  
  // Draw a filled rectangle
  engine.fillStyle = const Color(0xFF4CAF50);
  engine.fillRect(50, 50, 100, 100);
  
  // Draw a stroked circle
  engine.strokeStyle = const Color(0xFF2196F3);
  engine.lineWidth = 3.0;
  engine.stroke(PathBuilder().circle(250, 100, 50).build());
  
  // Draw a filled triangle using a path
  engine.fillStyle = const Color(0xFFFF9800);
  final triangle = PathBuilder()
    ..moveTo(200, 200)
    ..lineTo(300, 200)
    ..lineTo(250, 300)
    ..closePath();
  engine.fill(triangle.build());
  
  // Save the result
  await engine.write('my_first_drawing.ppm');
  print('Drawing saved to my_first_drawing.ppm');
}
```

## Drawing Primitives

### Rectangles

```dart
const x = 20.0, y = 20.0, width = 120.0, height = 80.0, radius = 12.0;

// Filled rectangle
engine.fillStyle = const Color(0xFFFF0000);
engine.fillRect(x, y, width, height);

// Stroked rectangle
engine.strokeStyle = const Color(0xFF0000FF);
engine.lineWidth = 2.0;
engine.strokeRect(x, y, width, height);

// Rounded rectangle
final rounded = PathBuilder().roundRect(x, y, width, height, radius).build();
engine.fill(rounded);
engine.stroke(rounded);
```

### Circles and Ellipses

```dart
const centerX = 200.0, centerY = 150.0, radius = 50.0;
const radiusX = 80.0, radiusY = 40.0;

// Circle
engine.fill(PathBuilder().circle(centerX, centerY, radius).build());
engine.stroke(PathBuilder().circle(centerX, centerY, radius).build());

// Ellipse: centre, radii, rotation, start angle, end angle
final ellipse = PathBuilder()
  ..ellipse(centerX, centerY, radiusX, radiusY, 0, 0, 2 * math.pi);
engine.fill(ellipse.build());
```

### Lines

```dart
// Single line
engine.strokeStyle = const Color(0xFF000000);
engine.lineWidth = 1.0;
final line = PathBuilder()
  ..moveTo(10, 10)
  ..lineTo(200, 60);
engine.stroke(line.build());

// Polyline
final polyline = PathBuilder()
  ..moveTo(10, 10)
  ..lineTo(50, 30)
  ..lineTo(90, 20)
  ..lineTo(130, 50);
engine.stroke(polyline.build());
```

## Transformations

Transformations allow you to move, rotate, and scale your drawings:

```dart
import 'dart:math' as math;

// Save the current transformation state
engine.save();

// Apply transformations (order matters!)
engine.translate(100, 100);        // Move origin
engine.rotate(math.pi / 4);        // Rotate 45 degrees
engine.scale(2.0, 2.0);            // Scale 2x

// Draw something (will be transformed)
engine.fillRect(-25, -25, 50, 50);

// Restore original transformation state
engine.restore();
```

### Transformation Order

The order of transformations is important. They are applied in the order you call them:

```dart
// This draws a rectangle at (100, 50) then rotates around (100, 50)
engine.save();
engine.translate(100, 50);
engine.rotate(math.pi / 4);
engine.fillRect(-25, -25, 50, 50);
engine.restore();

// This rotates around origin (0, 0) then translates
engine.save();
engine.rotate(math.pi / 4);
engine.translate(100, 50);
engine.fillRect(-25, -25, 50, 50);
engine.restore();
```

## State Management

The graphics engine maintains a state stack. You can save and restore states to isolate transformations and style
changes:

```dart
// Save current state
engine.save();

// Make changes (these won't affect the saved state)
engine.fillStyle = const Color(0xFFFF0000);
engine.translate(50, 50);
engine.rotate(math.pi / 6);
engine.fillRect(0, 0, 100, 100);

// Restore previous state (undoes color, translation, and rotation)
engine.restore();

// Draw with original settings
engine.fillRect(200, 200, 100, 100);
```

## Working with Images

### Loading and Drawing Images

Read the file through a `GraphicsFileSystem`, then decode the bytes. Decoding returns a `Result` instead of
throwing on bad input:

```dart
import 'package:libgfx/io/local_file_system.dart';

// Read the file; read returns null when it does not exist
const filesystem = LocalGraphicsFileSystem();
final bytes = await filesystem.read('image.png');
if (bytes == null) {
  print('image.png not found');
  return;
}

switch (GraphicsEngine.decode(bytes)) {
  case Ok(value: final imageBitmap):
    // Draw the image at a specific position
    engine.drawImage(imageBitmap, 100, 100);

    // Draw scaled image: destination x, y, width, height
    engine.drawImage(imageBitmap, 100, 100, width: 200, height: 150);

    // Draw a portion of an image: source rectangle, then destination rectangle
    engine.drawImage(imageBitmap, 200, 200, width: 100, height: 100, source: Rectangle(50, 50, 100, 100));
  case Err(:final error):
    print('Cannot decode image: ${error.message}');
}
```

### Saving Your Work

```dart
import 'package:libgfx/io/local_file_system.dart';

// Saving needs a file system
engine.filesystem ??= const LocalGraphicsFileSystem();

// write picks the format from the extension (.png, .bmp, .ppm, .p3, .p6)
await engine.write('output.ppm');
await engine.write('output.png');

// Or encode to bytes yourself and write them wherever you need
final bmpBytes = GraphicsEngine.encode(engine.canvas, 'bmp');
await engine.filesystem?.write('output.bmp', bmpBytes);

// Get bitmap for custom processing
final bitmap = engine.canvas;
// Process bitmap pixels directly...
```

## Basic Animation Loop

For animations, you typically create frames and save them:

```dart
import 'dart:math' as math;

import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

void main() async {
  const frames = 60;
  const width = 400;
  const height = 400;
  
  for (int frame = 0; frame < frames; frame++) {
    final engine = GraphicsEngine(
      width,
      height,
      filesystem: const LocalGraphicsFileSystem(),
    );
    engine.clear(const Color(0xFFFFFFFF));
    
    // Calculate animation progress (0.0 to 1.0)
    final progress = frame / frames;
    final angle = progress * 2 * math.pi;
    
    // Animated rotating square
    engine.save();
    engine.translate(width / 2, height / 2);
    engine.rotate(angle);
    engine.fillStyle = const Color(0xFF2196F3);
    engine.fillRect(-50, -50, 100, 100);
    engine.restore();
    
    // Save frame
    await engine.write('frame_${frame.toString().padLeft(3, '0')}.ppm');
  }
  
  print('Animation frames saved');
}
```

## Error Handling

Saving throws: `write` throws `UnsupportedError` when no `GraphicsFileSystem` is attached, and passes on
whatever the file system throws when writing fails. Loading fonts and images returns a `Result<T, ErrorDetails>`
instead (`Ok` or `Err`, where `ErrorDetails` has a `kind` and a `message`); a failed font load keeps the current
font.

```dart
try {
  await engine.write('output.ppm');
  print('Image saved successfully');
} catch (e) {
  print('Error saving image: $e');
}

switch (await engine.loadFont('data/fonts/NotoSans-Regular.ttf')) {
  case Ok():
    print('Font loaded');
  case Err(:final error):
    print('Error loading font (${error.kind.name}): ${error.message}');
}
```

## Performance Tips

1. **Reuse Paths**: Build paths once and reuse them:
   ```dart
   final star = PathBuilder().star(0, 0, 20, 8, 5).build();
   final random = math.Random(42);
   for (int i = 0; i < 100; i++) {
     engine.save();
     engine.translate(
       random.nextDouble() * engine.width,
       random.nextDouble() * engine.height,
     );
     engine.fill(star);
     engine.restore();
   }
   ```

2. **Batch Operations**: Group similar operations together:
   ```dart
   // Set color once for multiple shapes
   engine.fillStyle = const Color(0xFF0000FF);
   engine.fillRect(10, 10, 50, 50);
   engine.fillRect(70, 10, 50, 50);
   engine.fillRect(130, 10, 50, 50);
   ```

3. **Use Appropriate Image Formats**:
    - PNG: Lossless, supports transparency, compressed
    - BMP: Fast to save, large file size, no compression
    - PPM: Simple format, useful for debugging, very large files

   `write` picks the format from the file extension.

4. **Manage State Stack**: Don't forget to balance save/restore calls:
   ```dart
   engine.save();    // Push state
   // ... do work ...
   engine.restore(); // Pop state (must match save)
   ```

## Next Steps

Now that you understand the basics, explore:

- [API Reference](api-reference.md) - Complete API documentation
- [Advanced Features](advanced-features.md) - Gradients, filters, clipping, and more
- [Examples](examples.md) - Complete working examples

## Common Issues

### Nothing Appears on Canvas

- Check your coordinates - graphics space is Y-up, so (0,0) is the bottom-left corner and y increases upwards (see
  [Rendering Model](rendering-model.md))
- Ensure colors are opaque (alpha = 0xFF)
- Verify canvas size is large enough for your drawing

### Transformations Not Working

- Remember to use save/restore to isolate transformations
- Order matters: translate, then rotate is different from rotate, then translate
- Rotations are in radians, not degrees (use `degrees * math.pi / 180`)

### File Not Saving

- Ensure a `GraphicsFileSystem` is attached to the engine
- Ensure the output location is writable (`LocalGraphicsFileSystem` creates missing parent directories)
- Check the file extension: `write` recognises .png, .bmp, .ppm, .p3 and .p6, and saves any other extension as
  binary PPM (P6)
- Wrap in try-catch to see error messages

### Performance Issues

- Avoid creating new paths in loops
- Minimize state changes (color, stroke width)
- Consider canvas size - larger canvases take longer to render
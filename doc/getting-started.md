# Getting Started with libgfx

This guide will help you get started with libgfx, a comprehensive 2D vector graphics engine for Dart.

## Installation

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

// Using Color.fromRGBA (deprecated, use hex notation)
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
  ..close();            // Close the path

final builtPath = path.build();
```

## Your First Drawing

Let's create a simple drawing with basic shapes:

```dart
import 'package:libgfx/libgfx.dart';

void main() async {
  // Create canvas
  final engine = GraphicsEngine(400, 400);
  
  // Set background (optional - default is transparent)
  engine.clear(const Color(0xFFF0F0F0));
  
  // Draw a filled rectangle
  engine.setFillColor(const Color(0xFF4CAF50));
  engine.fillRect(50, 50, 100, 100);
  
  // Draw a stroked circle
  engine.setStrokeColor(const Color(0xFF2196F3));
  engine.setStrokeWidth(3.0);
  engine.strokeCircle(250, 100, 50);
  
  // Draw a filled triangle using a path
  engine.setFillColor(const Color(0xFFFF9800));
  final triangle = PathBuilder()
    ..moveTo(200, 200)
    ..lineTo(300, 200)
    ..lineTo(250, 300)
    ..close();
  engine.fill(triangle.build());
  
  // Save the result
  await engine.saveToFile('my_first_drawing.ppm');
  print('Drawing saved to my_first_drawing.ppm');
}
```

## Drawing Primitives

### Rectangles

```dart
// Filled rectangle
engine.setFillColor(const Color(0xFFFF0000));
engine.fillRect(x, y, width, height);

// Stroked rectangle
engine.setStrokeColor(const Color(0xFF0000FF));
engine.setStrokeWidth(2.0);
engine.strokeRect(x, y, width, height);

// Rounded rectangle
final roundedRect = PathBuilder()
  ..roundRect(x, y, width, height, radius);
engine.fill(roundedRect.build());
```

### Circles and Ellipses

```dart
// Circle
engine.fillCircle(centerX, centerY, radius);
engine.strokeCircle(centerX, centerY, radius);

// Ellipse (using path)
final ellipse = PathBuilder()
  ..moveTo(centerX + radiusX, centerY)
  ..arcTo(centerX, centerY, radiusX, radiusY, 0, 2 * math.pi, false);
engine.fill(ellipse.build());
```

### Lines

```dart
// Single line
engine.setStrokeColor(const Color(0xFF000000));
engine.setStrokeWidth(1.0);
engine.beginPath();
engine.moveTo(x1, y1);
engine.lineTo(x2, y2);
engine.stroke();

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
engine.translate(100, 50);
engine.rotate(math.pi / 4);
engine.fillRect(-25, -25, 50, 50);

// This rotates around origin (0, 0) then translates
engine.rotate(math.pi / 4);
engine.translate(100, 50);
engine.fillRect(-25, -25, 50, 50);
```

## State Management

The graphics engine maintains a state stack. You can save and restore states to isolate transformations and style
changes:

```dart
// Save current state
engine.save();

// Make changes (these won't affect the saved state)
engine.setFillColor(const Color(0xFFFF0000));
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

```dart
// Load an image from file
final imageBitmap = await Bitmap.fromFile('image.png');

// Draw the image at a specific position
engine.drawImage(imageBitmap, 100, 100);

// Draw scaled image
engine.drawImageScaled(imageBitmap, 
  destX: 100, 
  destY: 100, 
  destWidth: 200, 
  destHeight: 150
);

// Draw a portion of an image
engine.drawImageRect(imageBitmap,
  srcX: 50, srcY: 50, srcWidth: 100, srcHeight: 100,
  destX: 200, destY: 200, destWidth: 100, destHeight: 100
);
```

### Saving Your Work

```dart
// Save as PPM (direct file save method)
await engine.saveToFile('output.ppm');

// For other formats, use the codec system which supports all formats:
// Save as PNG
final pngBytes = GraphicsEngine.saveImageToBytes(engine.canvas, 'png');
await File('output.png').writeAsBytes(pngBytes);

// Save as BMP  
final bmpBytes = GraphicsEngine.saveImageToBytes(engine.canvas, 'bmp');
await File('output.bmp').writeAsBytes(bmpBytes);

// Get bitmap for custom processing
final bitmap = engine.canvas;
// Process bitmap pixels directly...
```

## Basic Animation Loop

For animations, you typically create frames and save them:

```dart
import 'dart:math' as math;

void main() async {
  const frames = 60;
  const width = 400;
  const height = 400;
  
  for (int frame = 0; frame < frames; frame++) {
    final engine = GraphicsEngine(width, height);
    engine.clear(const Color(0xFFFFFFFF));
    
    // Calculate animation progress (0.0 to 1.0)
    final progress = frame / frames;
    final angle = progress * 2 * math.pi;
    
    // Animated rotating square
    engine.save();
    engine.translate(width / 2, height / 2);
    engine.rotate(angle);
    engine.setFillColor(const Color(0xFF2196F3));
    engine.fillRect(-50, -50, 100, 100);
    engine.restore();
    
    // Save frame
    await engine.saveToFile('frame_${frame.toString().padLeft(3, '0')}.ppm');
  }
  
  print('Animation frames saved');
}
```

## Error Handling

Always wrap file operations in try-catch blocks:

```dart
try {
  await engine.saveToFile('output.ppm');
  print('Image saved successfully');
} catch (e) {
  print('Error saving image: $e');
}

try {
  final bitmap = await Bitmap.fromFile('input.png');
  engine.drawImage(bitmap, 0, 0);
} catch (e) {
  print('Error loading image: $e');
}
```

## Performance Tips

1. **Reuse Paths**: Build paths once and reuse them:
   ```dart
   final star = createStarPath();
   for (int i = 0; i < 100; i++) {
     engine.save();
     engine.translate(randomX(), randomY());
     engine.fill(star);
     engine.restore();
   }
   ```

2. **Batch Operations**: Group similar operations together:
   ```dart
   // Set color once for multiple shapes
   engine.setFillColor(const Color(0xFF0000FF));
   engine.fillRect(10, 10, 50, 50);
   engine.fillRect(70, 10, 50, 50);
   engine.fillRect(130, 10, 50, 50);
   ```

3. **Use Appropriate Image Formats**:
    - PNG: Best quality, supports transparency, moderate file size (via codec system)
    - BMP: Fast to save, large file size, no compression (via codec system)
    - PPM: Simple format, useful for debugging, very large files (direct saveToFile method)

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

- Check your coordinates - remember (0,0) is top-left
- Ensure colors are opaque (alpha = 0xFF)
- Verify canvas size is large enough for your drawing

### Transformations Not Working

- Remember to use save/restore to isolate transformations
- Order matters: translate, then rotate is different from rotate, then translate
- Rotations are in radians, not degrees (use `degrees * math.pi / 180`)

### File Not Saving

- Ensure the output directory exists and is writable
- Check file extension is supported (.png, .bmp, .ppm)
- Wrap in try-catch to see error messages

### Performance Issues

- Avoid creating new paths in loops
- Minimize state changes (color, stroke width)
- Consider canvas size - larger canvases take longer to render
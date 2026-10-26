# Complete Examples

This document provides complete, runnable examples demonstrating various features of libgfx.

Important: File IO requires a configured GraphicsFileSystem. For VM/CLI usage, the examples below import it and pass it to the engine:

```dart
import 'package:libgfx/io/local_file_system.dart';
// ...
final engine = GraphicsEngine(800, 600, filesystem: const LocalGraphicsFileSystem());
```

On web, implement your own GraphicsFileSystem and pass it to the engine.

## Note on File Formats and IO

The examples call `engine.write(...)`. This method uses the configured GraphicsFileSystem and auto-detects the format from the file extension (png, bmp, p3, p6, ppm). For example:

```dart
await engine.write('output.png');
await engine.write('output.bmp');
```

Note: You must configure a GraphicsFileSystem (e.g., LocalGraphicsFileSystem) for file operations. See the Getting Started guide.

Text rendering needs a font: `fillText` throws when no font is set. The examples that draw text load
`data/fonts/NotoSans-Regular.ttf`, which `./scripts/download_fonts.sh` downloads. Loading returns a `Result`, so a
missing font is reported instead of thrown.

## Basic Drawing Example

A simple example showing basic shapes and colors.

```dart
import 'dart:math' as math;

import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

void main() async {
  final engine = GraphicsEngine(
    800,
    600,
    filesystem: const LocalGraphicsFileSystem(),
  );
  
  // Strokes a straight line
  void line(double x1, double y1, double x2, double y2) {
    engine.stroke((PathBuilder()..moveTo(x1, y1)..lineTo(x2, y2)).build());
  }

  // White background
  engine.clear(const Color(0xFFFFFFFF));

  // Draw a house
  // House body
  engine.fillStyle = const Color(0xFFD2691E);
  engine.fillRect(200, 150, 200, 150);
  
  // Roof
  final roof = PathBuilder()
    ..moveTo(180, 300)
    ..lineTo(300, 400)
    ..lineTo(420, 300)
    ..closePath();
  engine.fillStyle = const Color(0xFF8B0000);
  engine.fill(roof.build());
  
  // Door
  engine.fillStyle = const Color(0xFF654321);
  engine.fillRect(280, 150, 40, 70);
  
  // Windows
  engine.fillStyle = const Color(0xFF87CEEB);
  engine.fillRect(230, 230, 40, 40);
  engine.fillRect(330, 230, 40, 40);
  
  // Window frames
  engine.strokeStyle = const Color(0xFF000000);
  engine.lineWidth = 2;
  engine.strokeRect(230, 230, 40, 40);
  line(250, 230, 250, 270);
  line(230, 250, 270, 250);
  engine.strokeRect(330, 230, 40, 40);
  line(350, 230, 350, 270);
  line(330, 250, 370, 250);
  
  // Sun
  engine.fillStyle = const Color(0xFFFFD700);
  engine.fill(PathBuilder().circle(650, 500, 40).build());
  
  // Sun rays
  engine.strokeStyle = const Color(0xFFFFD700);
  engine.lineWidth = 3;
  for (int i = 0; i < 8; i++) {
    final angle = i * math.pi / 4;
    final x1 = 650 + 50 * math.cos(angle);
    final y1 = 500 + 50 * math.sin(angle);
    final x2 = 650 + 70 * math.cos(angle);
    final y2 = 500 + 70 * math.sin(angle);
    line(x1, y1, x2, y2);
  }
  
  // Tree
  engine.fillStyle = const Color(0xFF8B4513);
  engine.fillRect(500, 150, 30, 100);
  engine.fillStyle = const Color(0xFF228B22);
  engine.fill(PathBuilder().circle(515, 280, 40).build());
  engine.fill(PathBuilder().circle(500, 260, 35).build());
  engine.fill(PathBuilder().circle(530, 260, 35).build());
  
  // Grass
  engine.fillStyle = const Color(0xFF90EE90);
  engine.fillRect(0, 0, 800, 150);
  
  // Clouds
  engine.fillStyle = const Color(0xC8FFFFFF);
  void drawCloud(double x, double y) {
    engine.fill(PathBuilder().circle(x, y, 20).build());
    engine.fill(PathBuilder().circle(x + 15, y, 25).build());
    engine.fill(PathBuilder().circle(x + 30, y, 20).build());
    engine.fill(PathBuilder().circle(x + 7, y + 10, 18).build());
    engine.fill(PathBuilder().circle(x + 23, y + 10, 18).build());
  }
  drawCloud(100, 520);
  drawCloud(350, 480);
  
  await engine.write('house_scene.ppm');
  print('House scene saved to house_scene.ppm');
}
```

## Gradient Showcase

Demonstrates all gradient types and spread modes.

```dart
import 'dart:math' as math;

import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

void main() async {
  final engine = GraphicsEngine(
    800,
    600,
    filesystem: const LocalGraphicsFileSystem(),
  );
  engine.clear(const Color(0xFFF0F0F0));

  // Load a font for the labels
  final font = await engine.loadFont('data/fonts/NotoSans-Regular.ttf');
  if (font case Err(:final error)) {
    print('Cannot load font: ${error.message}');
    return;
  }

  // Linear gradient examples
  engine.save();
  engine.translate(50, 450);
  
  // Horizontal gradient
  final horizontalGradient = LinearGradient(
    start: Point(0, 0),
    end: Point(100, 0),
    stops: [
      ColorStop(0.0, const Color(0xFFFF0000)),
      ColorStop(0.5, const Color(0xFF00FF00)),
      ColorStop(1.0, const Color(0xFF0000FF)),
    ],
  );
  engine.fillStyle = horizontalGradient;
  engine.fillRect(0, 0, 100, 100);
  
  // Vertical gradient
  engine.translate(120, 0);
  final verticalGradient = LinearGradient(
    start: Point(0, 100),
    end: Point(0, 0),
    stops: [
      ColorStop(0.0, const Color(0xFFFFFF00)),
      ColorStop(1.0, const Color(0xFFFF00FF)),
    ],
  );
  engine.fillStyle = verticalGradient;
  engine.fillRect(0, 0, 100, 100);
  
  // Diagonal gradient, built from the engine factory; gradients are
  // immutable, so addColorStop returns a new gradient
  engine.translate(120, 0);
  final diagonalGradient = engine
      .createLinearGradient(0, 100, 100, 0)
      .addColorStop(0.0, const Color(0xFF000000))
      .addColorStop(1.0, const Color(0xFFFFFFFF));
  engine.fillStyle = diagonalGradient;
  engine.fillRect(0, 0, 100, 100);
  
  engine.restore();
  
  // Radial gradient examples
  engine.save();
  engine.translate(50, 300);
  
  // Basic radial
  final radialGradient = RadialGradient(
    center: Point(50, 50),
    radius: 50,
    stops: [
      ColorStop(0.0, const Color(0xFFFFFFFF)),
      ColorStop(1.0, const Color(0xFF2196F3)),
    ],
  );
  engine.fillStyle = radialGradient;
  engine.fill(PathBuilder().circle(50, 50, 50).build());
  
  // Multi-stop radial
  engine.translate(120, 0);
  final multiRadial = RadialGradient(
    center: Point(50, 50),
    radius: 50,
    stops: [
      ColorStop(0.0, const Color(0xFFFFFF00)),
      ColorStop(0.33, const Color(0xFFFF9800)),
      ColorStop(0.67, const Color(0xFFFF5722)),
      ColorStop(1.0, const Color(0xFF000000)),
    ],
  );
  engine.fillStyle = multiRadial;
  engine.fill(PathBuilder().circle(50, 50, 50).build());
  
  // Focal point radial (3D sphere effect)
  engine.translate(120, 0);
  final focalRadial = RadialGradient(
    center: Point(50, 50),
    radius: 50,
    focal: Point(35, 65),
    stops: [
      ColorStop(0.0, const Color(0xFFFFFFFF)),
      ColorStop(0.7, const Color(0xFF4CAF50)),
      ColorStop(1.0, const Color(0xFF1B5E20)),
    ],
  );
  engine.fillStyle = focalRadial;
  engine.fill(PathBuilder().circle(50, 50, 50).build());
  
  engine.restore();
  
  // Conic gradient examples
  engine.save();
  engine.translate(50, 150);
  
  // Color wheel
  final colorWheel = ConicalGradient(
    center: Point(50, 50),
    startAngle: 0,
    stops: [
      ColorStop(0.0, const Color(0xFFFF0000)),
      ColorStop(0.167, const Color(0xFFFFFF00)),
      ColorStop(0.333, const Color(0xFF00FF00)),
      ColorStop(0.5, const Color(0xFF00FFFF)),
      ColorStop(0.667, const Color(0xFF0000FF)),
      ColorStop(0.833, const Color(0xFFFF00FF)),
      ColorStop(1.0, const Color(0xFFFF0000)),
    ],
  );
  engine.fillStyle = colorWheel;
  engine.fill(PathBuilder().circle(50, 50, 50).build());
  
  // Pie chart effect
  engine.translate(120, 0);
  final pieChart = ConicalGradient(
    center: Point(50, 50),
    startAngle: math.pi / 2,
    stops: [
      ColorStop(0.0, const Color(0xFFE91E63)),
      ColorStop(0.25, const Color(0xFFE91E63)),
      ColorStop(0.25, const Color(0xFF2196F3)),
      ColorStop(0.6, const Color(0xFF2196F3)),
      ColorStop(0.6, const Color(0xFF4CAF50)),
      ColorStop(0.8, const Color(0xFF4CAF50)),
      ColorStop(0.8, const Color(0xFFFF9800)),
      ColorStop(1.0, const Color(0xFFFF9800)),
    ],
  );
  engine.fillStyle = pieChart;
  engine.fill(PathBuilder().circle(50, 50, 50).build());
  
  engine.restore();
  
  // Spread mode demonstration
  engine.save();
  engine.translate(450, 500);
  
  // Pad mode
  engine.fillStyle = const Color(0xFF000000);
  engine.fillText('Pad Mode', 0, 60);
  final padGradient = LinearGradient(
    start: Point(25, 0),
    end: Point(75, 0),
    stops: [
      ColorStop(0.0, const Color(0xFFFF0000)),
      ColorStop(1.0, const Color(0xFF0000FF)),
    ],
    spread: GradientSpread.pad,
  );
  engine.fillStyle = padGradient;
  engine.fillRect(0, 0, 150, 50);
  
  // Repeat mode
  engine.translate(0, -70);
  engine.fillStyle = const Color(0xFF000000);
  engine.fillText('Repeat Mode', 0, 60);
  final repeatGradient = LinearGradient(
    start: Point(0, 0),
    end: Point(30, 0),
    stops: [
      ColorStop(0.0, const Color(0xFFFF0000)),
      ColorStop(1.0, const Color(0xFF0000FF)),
    ],
    spread: GradientSpread.repeat,
  );
  engine.fillStyle = repeatGradient;
  engine.fillRect(0, 0, 150, 50);
  
  // Reflect mode
  engine.translate(0, -70);
  engine.fillStyle = const Color(0xFF000000);
  engine.fillText('Reflect Mode', 0, 60);
  final reflectGradient = LinearGradient(
    start: Point(0, 0),
    end: Point(30, 0),
    stops: [
      ColorStop(0.0, const Color(0xFFFF0000)),
      ColorStop(1.0, const Color(0xFF0000FF)),
    ],
    spread: GradientSpread.reflect,
  );
  engine.fillStyle = reflectGradient;
  engine.fillRect(0, 0, 150, 50);
  
  engine.restore();
  
  await engine.write('gradients_showcase.ppm');
  print('Gradients showcase saved');
}
```

## Animated Spiral

Creates an animated spiral pattern using transformations.

```dart
import 'dart:math' as math;

import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

/// Converts a hue in degrees and saturation and lightness from 0 to 1 to an
/// opaque color.
Color hsl(double hue, double saturation, double lightness) {
  final chroma = (1 - (2 * lightness - 1).abs()) * saturation;
  final x = chroma * (1 - ((hue / 60) % 2 - 1).abs());
  final m = lightness - chroma / 2;
  final (r, g, b) = switch (hue ~/ 60) {
    0 => (chroma, x, 0.0),
    1 => (x, chroma, 0.0),
    2 => (0.0, chroma, x),
    3 => (0.0, x, chroma),
    4 => (x, 0.0, chroma),
    _ => (chroma, 0.0, x),
  };
  return Color.clamped((r + m) * 255, (g + m) * 255, (b + m) * 255, 255);
}

void main() async {
  const frames = 60;
  const width = 600;
  const height = 600;
  
  for (int frame = 0; frame < frames; frame++) {
    final engine = GraphicsEngine(
      width,
      height,
      filesystem: const LocalGraphicsFileSystem(),
    );
    
    // Load a font for the frame number
    final font = await engine.loadFont('data/fonts/NotoSans-Regular.ttf');
    if (font case Err(:final error)) {
      print('Cannot load font: ${error.message}');
      return;
    }

    // Dark background
    engine.clear(const Color(0xFF0A0A0A));
    
    // Animation progress
    final progress = frame / frames;
    final globalRotation = progress * 2 * math.pi;
    
    // Draw spiral
    engine.save();
    engine.translate(width / 2, height / 2);
    engine.rotate(globalRotation);
    
    const numArms = 8;
    const numCirclesPerArm = 12;
    
    for (int arm = 0; arm < numArms; arm++) {
      final armAngle = (arm / numArms) * 2 * math.pi;
      
      engine.save();
      engine.rotate(armAngle);
      
      for (int i = 0; i < numCirclesPerArm; i++) {
        final distance = (i + 1) * 20.0;
        final size = 15.0 - (i * 0.8);
        final hue = (arm * 45 + i * 15 + frame * 6) % 360;
        
        // Convert HSL to RGB
        final color = hsl(
          hue.toDouble(),
          0.6,
          0.5 + (i / numCirclesPerArm) * 0.3,
        );
        
        engine.save();
        engine.translate(distance, 0);
        engine.rotate(-globalRotation - i * 0.1);
        
        // Glow effect
        final glowGradient = RadialGradient(
          center: Point(0, 0),
          radius: size * 2,
          stops: [
            ColorStop(0.0, color),
            ColorStop(0.5, Color.fromARGB(100, color.red, color.green, color.blue)),
            ColorStop(1.0, Color.fromARGB(0, color.red, color.green, color.blue)),
          ],
        );
        engine.fillStyle = glowGradient;
        engine.fill(PathBuilder().circle(0, 0, size * 2).build());
        
        // Core circle
        engine.fillStyle = color;
        engine.fill(PathBuilder().circle(0, 0, size).build());
        
        engine.restore();
      }
      
      engine.restore();
    }
    
    engine.restore();
    
    // Add frame number
    engine.fillStyle = const Color(0xFFFFFFFF);
    engine.fontSize = 12;
    engine.fillText('Frame ${frame + 1}/$frames', 10, 10);
    
    await engine.write('spiral_frame_${frame.toString().padLeft(3, '0')}.png');
  }
  
  print('Spiral animation frames saved');
}
```

## Text Effects

Demonstrates various text rendering effects.

```dart
import 'dart:math' as math;

import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

void main() async {
  final engine = GraphicsEngine(
    800,
    600,
    filesystem: const LocalGraphicsFileSystem(),
  );
  engine.clear(const Color(0xFFFFFFFF));
  
  // Load font
  final font = await engine.loadFont('data/fonts/NotoSans-Regular.ttf');
  if (font case Err(:final error)) {
    print('Cannot load font: ${error.message}');
    return;
  }

  // Simple text
  engine.fontSize = 24;
  engine.fillStyle = const Color(0xFF000000);
  engine.fillText('Simple Text', 50, 550);
  
  // Outlined text
  engine.fontSize = 36;
  engine.fillStyle = const Color(0xFFFFD700);
  engine.fillText('Outlined Text', 50, 500);
  engine.strokeStyle = const Color(0xFF000000);
  engine.lineWidth = 2;
  engine.strokeText('Outlined Text', 50, 500);
  
  // Gradient text
  engine.save();
  engine.translate(50, 450);
  engine.fontSize = 48;
  
  // Use the text outline as the clip
  engine.clipText('Gradient Text', 0, 0);

  // Fill with gradient
  final textGradient = LinearGradient(
    start: Point(0, 30),
    end: Point(0, -20),
    stops: [
      ColorStop(0.0, const Color(0xFFFF0000)),
      ColorStop(0.5, const Color(0xFFFFFF00)),
      ColorStop(1.0, const Color(0xFF00FF00)),
    ],
  );
  engine.fillStyle = textGradient;
  engine.fillRect(-10, -20, 400, 70);
  engine.restore();
  
  // Shadow text
  engine.fontSize = 36;
  // Draw shadow
  engine.fillStyle = const Color(0x80000000);
  engine.fillText('Shadow Text', 53, 377);
  // Draw text
  engine.fillStyle = const Color(0xFF2196F3);
  engine.fillText('Shadow Text', 50, 380);
  
  // Rotated text
  engine.save();
  engine.translate(400, 300);
  engine.rotate(math.pi / 6);
  engine.fontSize = 28;
  engine.fillStyle = const Color(0xFF9C27B0);
  engine.fillText('Rotated Text', 0, 0);
  engine.restore();
  
  // Text with different alignments
  engine.strokeStyle = const Color(0xFFCCCCCC);
  engine.lineWidth = 1;
  engine.stroke((PathBuilder()..moveTo(400, 250)..lineTo(400, 100)).build());
  
  engine.fontSize = 20;
  engine.fillStyle = const Color(0xFF000000);
  
  engine.textAlign = TextAlign.left;
  engine.fillText('Left Aligned', 400, 220);
  
  engine.textAlign = TextAlign.center;
  engine.fillText('Center Aligned', 400, 190);
  
  engine.textAlign = TextAlign.right;
  engine.fillText('Right Aligned', 400, 160);
  
  // Multi-line text simulation
  engine.textAlign = TextAlign.left;
  final lines = [
    'This is a multi-line',
    'text example showing',
    'how to render text',
    'across multiple lines',
  ];
  
  engine.fontSize = 18;
  engine.fillStyle = const Color(0xFF333333);
  for (int i = 0; i < lines.length; i++) {
    engine.fillText(lines[i], 50, 250 - i * 25);
  }
  
  // Curved text (manual positioning)
  engine.save();
  engine.translate(600, 150);
  final text = 'CURVED';
  engine.fontSize = 24;
  engine.fillStyle = const Color(0xFFE91E63);
  
  for (int i = 0; i < text.length; i++) {
    final angle = (i - text.length / 2) * 0.2;
    final radius = 80.0;
    
    engine.save();
    engine.rotate(-angle);
    engine.translate(0, radius);
    engine.fillText(text[i], 0, 0);
    engine.restore();
  }
  engine.restore();
  
  await engine.write('text_effects.png');
  print('Text effects saved');
}
```

## Complex Path Operations

Demonstrates the boolean operations in `PathOperations`. They are experimental and only approximate: each path is
flattened into a single ring, arc and ellipse commands are dropped, and the result is built from edges, not areas.
For example, `union` joins the two outlines into one ring instead of merging the shapes, and `difference` never
subtracts a shape that lies wholly inside the other. See their API documentation for what each one computes. The
shapes below are built from straight segments so that nothing is dropped.

```dart
import 'dart:math' as math;

import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

void main() async {
  final engine = GraphicsEngine(
    800,
    600,
    filesystem: const LocalGraphicsFileSystem(),
  );
  engine.clear(const Color(0xFFF5F5F5));
  
  // Load a font for the labels
  final font = await engine.loadFont('data/fonts/NotoSans-Regular.ttf');
  if (font case Err(:final error)) {
    print('Cannot load font: ${error.message}');
    return;
  }
  
  // Helper function to create a star path
  Path createStar(double cx, double cy, double outerRadius, double innerRadius, int points) {
    final builder = PathBuilder();
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi) / points;
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = cx + radius * math.cos(angle + math.pi / 2);
      final y = cy + radius * math.sin(angle + math.pi / 2);
      
      if (i == 0) {
        builder.moveTo(x, y);
      } else {
        builder.lineTo(x, y);
      }
    }
    builder.closePath();
    return builder.build();
  }
  
  // Circles approximated by 48-sided polygons, since the boolean
  // operations drop arc commands
  Path createCircle(double cx, double cy, double radius) =>
      PathBuilder().polygon(cx, cy, radius, 48).build();
  
  // Create basic shapes
  final circle1 = createCircle(100, 500, 50);
  final circle2 = createCircle(140, 500, 50);
  
  final square = PathBuilder().rect(250, 450, 100, 100).build();
  
  final triangle = PathBuilder()
    ..moveTo(300, 530)
    ..lineTo(350, 470)
    ..lineTo(250, 470)
    ..closePath();
  
  // Union operation
  engine.fillStyle = const Color(0xFF2196F3);
  final union = PathOperations.union(circle1, circle2);
  engine.fill(union);
  engine.strokeStyle = const Color(0xFF1976D2);
  engine.lineWidth = 2;
  engine.stroke(union);
  
  // Label
  engine.fillStyle = const Color(0xFF000000);
  engine.fontSize = 14;
  engine.fillText('Union', 90, 430);
  
  // Intersection operation
  engine.save();
  engine.translate(0, -200);
  
  engine.fillStyle = const Color(0xFF4CAF50);
  final intersection = PathOperations.intersection(circle1, circle2);
  engine.fill(intersection);
  engine.strokeStyle = const Color(0xFF388E3C);
  engine.stroke(intersection);
  
  engine.fillStyle = const Color(0xFF000000);
  engine.fillText('Intersection', 70, 430);
  engine.restore();
  
  // Difference operation
  engine.save();
  engine.translate(0, -400);
  
  engine.fillStyle = const Color(0xFFFF9800);
  final difference = PathOperations.difference(circle1, circle2);
  engine.fill(difference);
  engine.strokeStyle = const Color(0xFFE65100);
  engine.stroke(difference);
  
  engine.fillStyle = const Color(0xFF000000);
  engine.fillText('Difference', 75, 430);
  engine.restore();
  
  // XOR operation
  engine.save();
  engine.translate(0, -200);
  
  engine.fillStyle = const Color(0xFFE91E63);
  final xor = PathOperations.xor(square, triangle.build());
  engine.fill(xor);
  engine.strokeStyle = const Color(0xFFC2185B);
  engine.stroke(xor);
  
  engine.fillStyle = const Color(0xFF000000);
  engine.fillText('XOR', 285, 430);
  engine.restore();
  
  // Combining operations
  engine.save();
  engine.translate(500, 300);
  
  final star = createStar(100, 100, 60, 30, 5);
  final circle = createCircle(100, 100, 40);
  
  // Combine the results of several operations
  final complex1 = PathOperations.difference(star, circle);
  final ring = createCircle(100, 100, 60);
  final innerCircle = createCircle(100, 100, 45);
  final complex2 = PathOperations.difference(ring, innerCircle);
  final finalShape = PathOperations.union(complex1, complex2);
  
  // Draw with gradient
  final gradient = RadialGradient(
    center: Point(100, 100),
    radius: 60,
    stops: [
      ColorStop(0.0, const Color(0xFF9C27B0)),
      ColorStop(0.5, const Color(0xFF673AB7)),
      ColorStop(1.0, const Color(0xFF3F51B5)),
    ],
  );
  engine.fillStyle = gradient;
  engine.fill(finalShape);
  
  engine.strokeStyle = const Color(0xFF311B92);
  engine.lineWidth = 2;
  engine.stroke(finalShape);
  
  engine.fillStyle = const Color(0xFF000000);
  engine.fillText('Combined', 65, 10);
  engine.restore();
  
  await engine.write('path_operations.png');
  print('Path operations saved');
}
```

## Image Filter Effects

Demonstrates various image filtering capabilities. Filters are static methods on `ImageFilters` that take a `Bitmap`
and return a new one, so this example draws a test pattern into a small bitmap once and draws filtered copies of it
onto the canvas.

```dart
import 'dart:math' as math;

import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

void main() async {
  const filesystem = LocalGraphicsFileSystem();
  final engine = GraphicsEngine(800, 600, filesystem: filesystem);
  engine.clear(const Color(0xFFFFFFFF));
  
  // A separate 100x100 engine for the test pattern
  final tile = GraphicsEngine(100, 100, filesystem: filesystem);
  
  // Load a font into both engines
  const path = 'data/fonts/NotoSans-Regular.ttf';
  for (final target in [engine, tile]) {
    if (await target.loadFont(path) case Err(:final error)) {
      print('Cannot load font: ${error.message}');
      return;
    }
  }
  
  // Create a test pattern
  tile.clear(const Color(0xFFFFFFFF));
  
  // Colorful circles
  tile.fillStyle = const Color(0xFFFF0000);
  tile.fill(PathBuilder().circle(30, 70, 20).build());
  tile.fillStyle = const Color(0xFF00FF00);
  tile.fill(PathBuilder().circle(70, 70, 20).build());
  tile.fillStyle = const Color(0xFF0000FF);
  tile.fill(PathBuilder().circle(50, 40, 20).build());
  
  // Text
  tile.fillStyle = const Color(0xFF000000);
  tile.fontSize = 16;
  tile.fillText('Test', 35, 6);
  
  // Border
  tile.strokeStyle = const Color(0xFF333333);
  tile.lineWidth = 2;
  tile.strokeRect(0, 0, 100, 100);
  
  final source = tile.canvas;
  
  // Draws an image with a label below it
  engine.fillStyle = const Color(0xFF000000);
  engine.fontSize = 12;
  void show(Bitmap image, String label, double x, double y) {
    engine.drawImage(image, x, y);
    engine.fillText(label, x, y - 20);
  }
  
  // Original
  show(source, 'Original', 50, 450);
  
  // Gaussian Blur
  show(ImageFilters.gaussian(source, 3.0), 'Gaussian Blur', 200, 450);
  
  // Box Blur
  show(ImageFilters.box(source, 3), 'Box Blur', 350, 450);
  
  // Sharpen
  show(ImageFilters.sharpen(source, 1.5), 'Sharpen', 500, 450);
  
  // Edge Detection
  show(ImageFilters.edges(source, threshold: 100), 'Edge Detect', 650, 450);
  
  // Emboss
  show(ImageFilters.emboss(source), 'Emboss', 50, 250);
  
  // Motion Blur
  show(ImageFilters.motion(source, math.pi / 4, 10), 'Motion Blur', 200, 250);
  
  // Custom Convolution - High Pass
  final highPass = [
    [-1.0, -1.0, -1.0],
    [-1.0,  9.0, -1.0],
    [-1.0, -1.0, -1.0],
  ];
  show(ImageFilters.convolve(source, highPass), 'High Pass', 350, 250);
  
  // Combined filters
  final blurred = ImageFilters.gaussian(source, 1.0);
  show(ImageFilters.sharpen(blurred, 2.0), 'Blur + Sharpen', 500, 250);
  
  await engine.write('filter_effects.png');
  print('Filter effects saved');
}
```

## Interactive Clock

Creates a functional analog clock visualization.

```dart
import 'dart:math' as math;

import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

void main() async {
  final now = DateTime.now();
  final engine = GraphicsEngine(
    400,
    400,
    filesystem: const LocalGraphicsFileSystem(),
  );

  // Load a font for the numbers
  final font = await engine.loadFont('data/fonts/NotoSans-Regular.ttf');
  if (font case Err(:final error)) {
    print('Cannot load font: ${error.message}');
    return;
  }

  // Background
  final bgGradient = RadialGradient(
    center: Point(200, 200),
    radius: 200,
    stops: [
      ColorStop(0.0, const Color(0xFFF5F5F5)),
      ColorStop(1.0, const Color(0xFFE0E0E0)),
    ],
  );
  engine.fillStyle = bgGradient;
  engine.fillRect(0, 0, 400, 400);
  
  // Clock face
  engine.save();
  engine.translate(200, 200);
  
  // Outer ring
  final ringGradient = RadialGradient(
    center: Point(0, 0),
    radius: 150,
    stops: [
      ColorStop(0.0, const Color(0xFF37474F)),
      ColorStop(1.0, const Color(0xFF263238)),
    ],
  );
  engine.fillStyle = ringGradient;
  engine.fill(PathBuilder().circle(0, 0, 150).build());
  
  // Inner face
  engine.fillStyle = const Color(0xFFECEFF1);
  engine.fill(PathBuilder().circle(0, 0, 140).build());
  
  // Hour markers
  for (int i = 0; i < 12; i++) {
    final angle = i * 30 * math.pi / 180;
    final isHour = i % 3 == 0;
    
    engine.save();
    engine.rotate(-angle);
    
    if (isHour) {
      // Large hour markers
      engine.fillStyle = const Color(0xFF263238);
      engine.fillRect(-2, 110, 4, 20);
      
      // Hour numbers, inside the markers
      engine.save();
      engine.translate(0, 92);
      engine.rotate(angle);
      engine.fontSize = 18;
      engine.textAlign = TextAlign.center;
      engine.textBaseline = TextBaseline.middle;
      final hour = i == 0 ? 12 : i;
      engine.fillText(hour.toString(), 0, 0);
      engine.restore();
    } else {
      // Small minute markers
      engine.fillStyle = const Color(0xFF607D8B);
      engine.fillRect(-1, 120, 2, 10);
    }
    
    engine.restore();
  }
  
  // Calculate angles
  final hours = now.hour % 12;
  final minutes = now.minute;
  final seconds = now.second;
  final milliseconds = now.millisecond;
  
  final secondAngle = (seconds + milliseconds / 1000) * 6;
  final minuteAngle = (minutes + seconds / 60) * 6;
  final hourAngle = (hours + minutes / 60) * 30;
  
  // Hour hand
  engine.save();
  engine.rotate(-hourAngle * math.pi / 180);
  engine.fillStyle = const Color(0xFF263238);
  final hourHand = PathBuilder()
    ..moveTo(-8, 0)
    ..lineTo(-3, 50)
    ..lineTo(0, 60)
    ..lineTo(3, 50)
    ..lineTo(8, 0)
    ..lineTo(4, -15)
    ..lineTo(-4, -15)
    ..closePath();
  engine.fill(hourHand.build());
  engine.restore();
  
  // Minute hand
  engine.save();
  engine.rotate(-minuteAngle * math.pi / 180);
  engine.fillStyle = const Color(0xFF37474F);
  final minuteHand = PathBuilder()
    ..moveTo(-6, 0)
    ..lineTo(-2, 75)
    ..lineTo(0, 85)
    ..lineTo(2, 75)
    ..lineTo(6, 0)
    ..lineTo(3, -15)
    ..lineTo(-3, -15)
    ..closePath();
  engine.fill(minuteHand.build());
  engine.restore();
  
  // Second hand
  engine.save();
  engine.rotate(-secondAngle * math.pi / 180);
  engine.fillStyle = const Color(0xFFE53935);
  engine.fillRect(-1, -20, 2, 115);
  engine.fill(PathBuilder().circle(0, 95, 4).build());
  engine.restore();
  
  // Center cap
  final capGradient = RadialGradient(
    center: Point(0, 0),
    radius: 12,
    stops: [
      ColorStop(0.0, const Color(0xFF546E7A)),
      ColorStop(1.0, const Color(0xFF37474F)),
    ],
  );
  engine.fillStyle = capGradient;
  engine.fill(PathBuilder().circle(0, 0, 12).build());
  
  engine.fillStyle = const Color(0xFF263238);
  engine.fill(PathBuilder().circle(0, 0, 8).build());
  
  engine.restore();
  
  // Digital time display
  engine.fillStyle = const Color(0xFF263238);
  engine.fontSize = 24;
  engine.textAlign = TextAlign.center;
  engine.textBaseline = TextBaseline.alphabetic;
  final timeString = '${now.hour.toString().padLeft(2, '0')}:'
                    '${now.minute.toString().padLeft(2, '0')}:'
                    '${now.second.toString().padLeft(2, '0')}';
  engine.fillText(timeString, 200, 150);
  
  // Date display
  engine.fontSize = 16;
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final dateString = '${months[now.month - 1]} ${now.day}, ${now.year}';
  engine.fillText(dateString, 200, 128);
  
  await engine.write('clock.png');
  print('Clock saved at ${timeString}');
}
```

## Fractal Tree

Generates a recursive fractal tree pattern.

```dart
import 'dart:math' as math;

import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

void main() async {
  final engine = GraphicsEngine(
    800,
    600,
    filesystem: const LocalGraphicsFileSystem(),
  );
  
  // Sky gradient background
  final skyGradient = LinearGradient(
    start: Point(0, 600),
    end: Point(0, 0),
    stops: [
      ColorStop(0.0, const Color(0xFF87CEEB)),
      ColorStop(1.0, const Color(0xFFF0E68C)),
    ],
  );
  engine.fillStyle = skyGradient;
  engine.fillRect(0, 0, 800, 600);
  
  // Ground
  engine.fillStyle = const Color(0xFF8B7355);
  engine.fillRect(0, 0, 800, 100);
  
  // Strokes a straight line
  void line(double x1, double y1, double x2, double y2) {
    engine.stroke((PathBuilder()..moveTo(x1, y1)..lineTo(x2, y2)).build());
  }

  // Recursive tree drawing function
  void drawBranch(double x, double y, double length, double angle, int depth) {
    if (depth == 0 || length < 2) return;
    
    // Calculate end point
    final endX = x + length * math.cos(angle);
    final endY = y + length * math.sin(angle);
    
    // Set color based on depth (trunk to leaves)
    final greenAmount = (1 - depth / 12) * 255;
    final color = Color.fromRGBA(
      (139 - greenAmount * 0.5).round(),
      (69 + greenAmount * 0.7).round(),
      19,
      255,
    );
    engine.strokeStyle = color;
    
    // Thicker branches at the base
    engine.lineWidth = depth * 0.5;
    
    // Draw branch
    line(x, y, endX, endY);
    
    // Add leaves at the tips
    if (depth <= 2) {
      engine.fillStyle = const Color(0x96228B22);
      engine.fill(PathBuilder().circle(endX, endY, 3).build());
    }
    
    // Create child branches
    final random = math.Random(depth * 42);
    final branches = 2 + (random.nextDouble() > 0.7 ? 1 : 0);
    
    for (int i = 0; i < branches; i++) {
      final angleVariation = (random.nextDouble() - 0.5) * math.pi / 6;
      final lengthFactor = 0.6 + random.nextDouble() * 0.2;
      final branchAngle = angle + (i - branches / 2) * math.pi / 6 + angleVariation;
      
      drawBranch(
        endX,
        endY,
        length * lengthFactor,
        branchAngle,
        depth - 1,
      );
    }
  }
  
  // Draw multiple trees
  final treePositions = [
    {'x': 200.0, 'size': 1.0},
    {'x': 400.0, 'size': 1.2},
    {'x': 600.0, 'size': 0.8},
  ];
  
  for (final tree in treePositions) {
    drawBranch(
      tree['x']!,
      100,
      80 * tree['size']!,
      math.pi / 2,
      12,
    );
  }
  
  // Add some grass
  engine.strokeStyle = const Color(0xFF355E3B);
  final random = math.Random(42);
  for (int i = 0; i < 200; i++) {
    final x = random.nextDouble() * 800;
    final y = 100 - random.nextDouble() * 100;
    final height = 5 + random.nextDouble() * 10;
    engine.lineWidth = 1;
    line(x, y, x + random.nextDouble() * 4 - 2, y + height);
  }
  
  await engine.write('fractal_tree.png');
  print('Fractal tree saved');
}
```

## Running the Examples

To run any of these examples:

1. Ensure libgfx is properly installed in your project
2. Copy the example code to a Dart file (e.g., `example.dart`)
3. Run with: `dart run example.dart`
4. Check the output files in your project directory

## Customizing Examples

These examples are designed to be modified and extended:

- **Colors**: Change color values to create different palettes
- **Sizes**: Adjust dimensions for different canvas sizes; for a high-DPI screen, create the engine at twice the size
  and call `scale(2, 2)` before drawing, as the programs in `example/` do
- **Parameters**: Modify algorithm parameters for different effects
- **Combinations**: Mix techniques from different examples

## Performance Considerations

When working with these examples:

1. **Large Canvases**: Bigger canvases require more memory and processing time
2. **Complex Paths**: Simplify paths when possible for better performance
3. **Filters**: Apply filters to smaller regions when possible
4. **Animations**: Pre-calculate values outside the rendering loop

## See Also

- [Getting Started Guide](getting-started.md)
- [API Reference](api-reference.md)
- [Advanced Features](advanced-features.md)
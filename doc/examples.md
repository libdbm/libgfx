# Complete Examples

This document provides complete, runnable examples demonstrating various features of libgfx.

## Note on File Formats

The examples use `saveToFile()` which defaults to PPM format. To save in other formats (PNG, BMP), use:

```dart
// For PNG
final pngBytes = GraphicsEngine.saveImageToBytes(engine.canvas, 'png');
await File('output.png').writeAsBytes(pngBytes);

// For BMP
final bmpBytes = GraphicsEngine.saveImageToBytes(engine.canvas, 'bmp');
await File('output.bmp').writeAsBytes(bmpBytes);
```

## Basic Drawing Example

A simple example showing basic shapes and colors.

```dart
import 'package:libgfx/libgfx.dart';
import 'dart:math' as math;

void main() async {
  final engine = GraphicsEngine(800, 600);
  
  // White background
  engine.clear(const Color(0xFFFFFFFF));
  
  // Draw a house
  // House body
  engine.setFillColor(const Color(0xFFD2691E));
  engine.fillRect(200, 300, 200, 150);
  
  // Roof
  final roof = PathBuilder()
    ..moveTo(180, 300)
    ..lineTo(300, 200)
    ..lineTo(420, 300)
    ..close();
  engine.setFillColor(const Color(0xFF8B0000));
  engine.fill(roof.build());
  
  // Door
  engine.setFillColor(const Color(0xFF654321));
  engine.fillRect(280, 380, 40, 70);
  
  // Windows
  engine.setFillColor(const Color(0xFF87CEEB));
  engine.fillRect(230, 330, 40, 40);
  engine.fillRect(330, 330, 40, 40);
  
  // Window frames
  engine.setStrokeColor(const Color(0xFF000000));
  engine.setStrokeWidth(2);
  engine.strokeRect(230, 330, 40, 40);
  engine.strokeLine(250, 330, 250, 370);
  engine.strokeLine(230, 350, 270, 350);
  engine.strokeRect(330, 330, 40, 40);
  engine.strokeLine(350, 330, 350, 370);
  engine.strokeLine(330, 350, 370, 350);
  
  // Sun
  engine.setFillColor(const Color(0xFFFFD700));
  engine.fillCircle(650, 100, 40);
  
  // Sun rays
  engine.setStrokeColor(const Color(0xFFFFD700));
  engine.setStrokeWidth(3);
  for (int i = 0; i < 8; i++) {
    final angle = i * math.pi / 4;
    final x1 = 650 + 50 * math.cos(angle);
    final y1 = 100 + 50 * math.sin(angle);
    final x2 = 650 + 70 * math.cos(angle);
    final y2 = 100 + 70 * math.sin(angle);
    engine.strokeLine(x1, y1, x2, y2);
  }
  
  // Tree
  engine.setFillColor(const Color(0xFF8B4513));
  engine.fillRect(500, 350, 30, 100);
  engine.setFillColor(const Color(0xFF228B22));
  engine.fillCircle(515, 320, 40);
  engine.fillCircle(500, 340, 35);
  engine.fillCircle(530, 340, 35);
  
  // Grass
  engine.setFillColor(const Color(0xFF90EE90));
  engine.fillRect(0, 450, 800, 150);
  
  // Clouds
  engine.setFillColor(const Color(0xFFFFFFFF).withAlpha(200));
  void drawCloud(double x, double y) {
    engine.fillCircle(x, y, 20);
    engine.fillCircle(x + 15, y, 25);
    engine.fillCircle(x + 30, y, 20);
    engine.fillCircle(x + 7, y - 10, 18);
    engine.fillCircle(x + 23, y - 10, 18);
  }
  drawCloud(100, 80);
  drawCloud(350, 120);
  
  await engine.saveToFile('house_scene.ppm');
  print('House scene saved to house_scene.ppm');
}
```

## Gradient Showcase

Demonstrates all gradient types and spread modes.

```dart
import 'package:libgfx/libgfx.dart';
import 'dart:math' as math;

void main() async {
  final engine = GraphicsEngine(800, 600);
  engine.clear(const Color(0xFFF0F0F0));
  
  // Linear gradient examples
  engine.save();
  engine.translate(50, 50);
  
  // Horizontal gradient
  final horizontalGradient = LinearGradient(
    start: Point(0, 0),
    end: Point(100, 0),
    colors: [
      const Color(0xFFFF0000),
      const Color(0xFF00FF00),
      const Color(0xFF0000FF),
    ],
    stops: [0.0, 0.5, 1.0],
  );
  engine.setFillPaint(horizontalGradient);
  engine.fillRect(0, 0, 100, 100);
  
  // Vertical gradient
  engine.translate(120, 0);
  final verticalGradient = LinearGradient(
    start: Point(0, 0),
    end: Point(0, 100),
    colors: [
      const Color(0xFFFFFF00),
      const Color(0xFFFF00FF),
    ],
  );
  engine.setFillPaint(verticalGradient);
  engine.fillRect(0, 0, 100, 100);
  
  // Diagonal gradient
  engine.translate(120, 0);
  final diagonalGradient = LinearGradient(
    start: Point(0, 0),
    end: Point(100, 100),
    colors: [
      const Color(0xFF000000),
      const Color(0xFFFFFFFF),
    ],
  );
  engine.setFillPaint(diagonalGradient);
  engine.fillRect(0, 0, 100, 100);
  
  engine.restore();
  
  // Radial gradient examples
  engine.save();
  engine.translate(50, 200);
  
  // Basic radial
  final radialGradient = RadialGradient(
    center: Point(50, 50),
    radius: 50,
    colors: [
      const Color(0xFFFFFFFF),
      const Color(0xFF2196F3),
    ],
  );
  engine.setFillPaint(radialGradient);
  engine.fillCircle(50, 50, 50);
  
  // Multi-stop radial
  engine.translate(120, 0);
  final multiRadial = RadialGradient(
    center: Point(50, 50),
    radius: 50,
    colors: [
      const Color(0xFFFFFF00),
      const Color(0xFFFF9800),
      const Color(0xFFFF5722),
      const Color(0xFF000000),
    ],
    stops: [0.0, 0.33, 0.67, 1.0],
  );
  engine.setFillPaint(multiRadial);
  engine.fillCircle(50, 50, 50);
  
  // Focal point radial (3D sphere effect)
  engine.translate(120, 0);
  final focalRadial = RadialGradient(
    center: Point(50, 50),
    radius: 50,
    focal: Point(35, 35),
    colors: [
      const Color(0xFFFFFFFF),
      const Color(0xFF4CAF50),
      const Color(0xFF1B5E20),
    ],
    stops: [0.0, 0.7, 1.0],
  );
  engine.setFillPaint(focalRadial);
  engine.fillCircle(50, 50, 50);
  
  engine.restore();
  
  // Conic gradient examples
  engine.save();
  engine.translate(50, 350);
  
  // Color wheel
  final colorWheel = ConicGradient(
    center: Point(50, 50),
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
    stops: [0.0, 0.167, 0.333, 0.5, 0.667, 0.833, 1.0],
  );
  engine.setFillPaint(colorWheel);
  engine.fillCircle(50, 50, 50);
  
  // Pie chart effect
  engine.translate(120, 0);
  final pieChart = ConicGradient(
    center: Point(50, 50),
    startAngle: -math.pi / 2,
    colors: [
      const Color(0xFFE91E63),
      const Color(0xFFE91E63),
      const Color(0xFF2196F3),
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFFFF9800),
    ],
    stops: [0.0, 0.25, 0.25, 0.6, 0.6, 0.8, 0.8, 1.0],
  );
  engine.setFillPaint(pieChart);
  engine.fillCircle(50, 50, 50);
  
  engine.restore();
  
  // Spread mode demonstration
  engine.save();
  engine.translate(450, 50);
  
  // Pad mode
  engine.setFillColor(const Color(0xFF000000));
  engine.fillText('Pad Mode', 0, -10);
  final padGradient = LinearGradient(
    start: Point(25, 0),
    end: Point(75, 0),
    colors: [const Color(0xFFFF0000), const Color(0xFF0000FF)],
    spreadMode: SpreadMode.pad,
  );
  engine.setFillPaint(padGradient);
  engine.fillRect(0, 0, 150, 50);
  
  // Repeat mode
  engine.translate(0, 70);
  engine.setFillColor(const Color(0xFF000000));
  engine.fillText('Repeat Mode', 0, -10);
  final repeatGradient = LinearGradient(
    start: Point(0, 0),
    end: Point(30, 0),
    colors: [const Color(0xFFFF0000), const Color(0xFF0000FF)],
    spreadMode: SpreadMode.repeat,
  );
  engine.setFillPaint(repeatGradient);
  engine.fillRect(0, 0, 150, 50);
  
  // Reflect mode
  engine.translate(0, 70);
  engine.setFillColor(const Color(0xFF000000));
  engine.fillText('Reflect Mode', 0, -10);
  final reflectGradient = LinearGradient(
    start: Point(0, 0),
    end: Point(30, 0),
    colors: [const Color(0xFFFF0000), const Color(0xFF0000FF)],
    spreadMode: SpreadMode.reflect,
  );
  engine.setFillPaint(reflectGradient);
  engine.fillRect(0, 0, 150, 50);
  
  engine.restore();
  
  await engine.saveToFile('gradients_showcase.ppm');
  print('Gradients showcase saved');
}
```

## Animated Spiral

Creates an animated spiral pattern using transformations.

```dart
import 'package:libgfx/libgfx.dart';
import 'dart:math' as math;

void main() async {
  const frames = 60;
  const width = 600;
  const height = 600;
  
  for (int frame = 0; frame < frames; frame++) {
    final engine = GraphicsEngine(width, height);
    
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
        final color = HSLColor.fromAHSL(
          1.0,
          hue.toDouble(),
          0.6,
          0.5 + (i / numCirclesPerArm) * 0.3,
        ).toColor();
        
        engine.save();
        engine.translate(distance, 0);
        engine.rotate(-globalRotation - i * 0.1);
        
        // Glow effect
        final glowGradient = RadialGradient(
          center: Point(0, 0),
          radius: size * 2,
          colors: [
            color,
            color.withAlpha(100),
            color.withAlpha(0),
          ],
          stops: [0.0, 0.5, 1.0],
        );
        engine.setFillPaint(glowGradient);
        engine.fillCircle(0, 0, size * 2);
        
        // Core circle
        engine.setFillColor(color);
        engine.fillCircle(0, 0, size);
        
        engine.restore();
      }
      
      engine.restore();
    }
    
    engine.restore();
    
    // Add frame number
    engine.setFillColor(const Color(0xFFFFFFFF));
    engine.setFontSize(12);
    engine.fillText('Frame ${frame + 1}/$frames', 10, height - 10);
    
    await engine.saveToFile('spiral_frame_${frame.toString().padLeft(3, '0')}.png');
  }
  
  print('Spiral animation frames saved');
}
```

## Text Effects

Demonstrates various text rendering effects.

```dart
import 'package:libgfx/libgfx.dart';
import 'dart:math' as math;

void main() async {
  final engine = GraphicsEngine(800, 600);
  engine.clear(const Color(0xFFFFFFFF));
  
  // Load font
  await engine.setFontFromFile('fonts/NotoSans-Regular.ttf');
  
  // Simple text
  engine.setFontSize(24);
  engine.setFillColor(const Color(0xFF000000));
  engine.fillText('Simple Text', 50, 50);
  
  // Outlined text
  engine.setFontSize(36);
  engine.setFillColor(const Color(0xFFFFD700));
  engine.fillText('Outlined Text', 50, 100);
  engine.setStrokeColor(const Color(0xFF000000));
  engine.setStrokeWidth(2);
  engine.strokeText('Outlined Text', 50, 100);
  
  // Gradient text
  engine.save();
  engine.translate(50, 150);
  engine.setFontSize(48);
  
  // Create text path and use as clip
  engine.beginPath();
  engine.textPath('Gradient Text', 0, 0);
  engine.clip();
  
  // Fill with gradient
  final textGradient = LinearGradient(
    start: Point(0, -30),
    end: Point(0, 20),
    colors: [
      const Color(0xFFFF0000),
      const Color(0xFFFFFF00),
      const Color(0xFF00FF00),
    ],
  );
  engine.setFillPaint(textGradient);
  engine.fillRect(-10, -50, 400, 70);
  engine.restore();
  
  // Shadow text
  engine.setFontSize(36);
  // Draw shadow
  engine.setFillColor(const Color(0x80000000));
  engine.fillText('Shadow Text', 53, 223);
  // Draw text
  engine.setFillColor(const Color(0xFF2196F3));
  engine.fillText('Shadow Text', 50, 220);
  
  // Rotated text
  engine.save();
  engine.translate(400, 300);
  engine.rotate(-math.pi / 6);
  engine.setFontSize(28);
  engine.setFillColor(const Color(0xFF9C27B0));
  engine.fillText('Rotated Text', 0, 0);
  engine.restore();
  
  // Text with different alignments
  engine.setStrokeColor(const Color(0xFFCCCCCC));
  engine.setStrokeWidth(1);
  engine.strokeLine(400, 350, 400, 500);
  
  engine.setFontSize(20);
  engine.setFillColor(const Color(0xFF000000));
  
  engine.setTextAlign(TextAlign.left);
  engine.fillText('Left Aligned', 400, 380);
  
  engine.setTextAlign(TextAlign.center);
  engine.fillText('Center Aligned', 400, 410);
  
  engine.setTextAlign(TextAlign.right);
  engine.fillText('Right Aligned', 400, 440);
  
  // Letter spacing
  engine.setTextAlign(TextAlign.left);
  engine.setLetterSpacing(5);
  engine.fillText('S P A C E D', 50, 300);
  engine.setLetterSpacing(0);
  
  // Multi-line text simulation
  final lines = [
    'This is a multi-line',
    'text example showing',
    'how to render text',
    'across multiple lines',
  ];
  
  engine.setFontSize(18);
  engine.setFillColor(const Color(0xFF333333));
  for (int i = 0; i < lines.length; i++) {
    engine.fillText(lines[i], 50, 350 + i * 25);
  }
  
  // Curved text (manual positioning)
  engine.save();
  engine.translate(600, 450);
  final text = 'CURVED';
  engine.setFontSize(24);
  engine.setFillColor(const Color(0xFFE91E63));
  
  for (int i = 0; i < text.length; i++) {
    final angle = (i - text.length / 2) * 0.2;
    final radius = 80;
    
    engine.save();
    engine.rotate(angle);
    engine.translate(0, -radius);
    engine.fillText(text[i], 0, 0);
    engine.restore();
  }
  engine.restore();
  
  await engine.saveToFile('text_effects.png');
  print('Text effects saved');
}
```

## Complex Path Operations

Demonstrates boolean operations and path manipulation.

```dart
import 'package:libgfx/libgfx.dart';
import 'dart:math' as math;

void main() async {
  final engine = GraphicsEngine(800, 600);
  engine.clear(const Color(0xFFF5F5F5));
  
  // Helper function to create a star path
  Path createStar(double cx, double cy, double outerRadius, double innerRadius, int points) {
    final builder = PathBuilder();
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi) / points;
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = cx + radius * math.cos(angle - math.pi / 2);
      final y = cy + radius * math.sin(angle - math.pi / 2);
      
      if (i == 0) {
        builder.moveTo(x, y);
      } else {
        builder.lineTo(x, y);
      }
    }
    builder.close();
    return builder.build();
  }
  
  // Create basic shapes
  final circle1 = PathBuilder()
    ..arc(100, 100, 50, 0, math.pi * 2)
    ..close();
  
  final circle2 = PathBuilder()
    ..arc(140, 100, 50, 0, math.pi * 2)
    ..close();
  
  final square = PathBuilder()
    ..rect(250, 50, 100, 100)
    ..close();
  
  final triangle = PathBuilder()
    ..moveTo(300, 70)
    ..lineTo(350, 130)
    ..lineTo(250, 130)
    ..close();
  
  // Union operation
  engine.setFillColor(const Color(0xFF2196F3));
  final union = PathOperations.union(circle1.build(), circle2.build());
  engine.fill(union);
  engine.setStrokeColor(const Color(0xFF1976D2));
  engine.setStrokeWidth(2);
  engine.stroke(union);
  
  // Label
  engine.setFillColor(const Color(0xFF000000));
  engine.setFontSize(14);
  engine.fillText('Union', 90, 170);
  
  // Intersection operation
  engine.save();
  engine.translate(0, 200);
  
  final circle3 = PathBuilder()
    ..arc(100, 100, 50, 0, math.pi * 2)
    ..close();
  
  final circle4 = PathBuilder()
    ..arc(140, 100, 50, 0, math.pi * 2)
    ..close();
  
  engine.setFillColor(const Color(0xFF4CAF50));
  final intersection = PathOperations.intersection(circle3.build(), circle4.build());
  engine.fill(intersection);
  engine.setStrokeColor(const Color(0xFF388E3C));
  engine.stroke(intersection);
  
  engine.setFillColor(const Color(0xFF000000));
  engine.fillText('Intersection', 70, 170);
  engine.restore();
  
  // Difference operation
  engine.save();
  engine.translate(0, 400);
  
  final circle5 = PathBuilder()
    ..arc(100, 100, 50, 0, math.pi * 2)
    ..close();
  
  final circle6 = PathBuilder()
    ..arc(140, 100, 50, 0, math.pi * 2)
    ..close();
  
  engine.setFillColor(const Color(0xFFFF9800));
  final difference = PathOperations.difference(circle5.build(), circle6.build());
  engine.fill(difference);
  engine.setStrokeColor(const Color(0xFFE65100));
  engine.stroke(difference);
  
  engine.setFillColor(const Color(0xFF000000));
  engine.fillText('Difference', 75, 170);
  engine.restore();
  
  // XOR operation
  engine.save();
  engine.translate(250, 200);
  
  engine.setFillColor(const Color(0xFFE91E63));
  final xor = PathOperations.xor(square.build(), triangle.build());
  engine.fill(xor);
  engine.setStrokeColor(const Color(0xFFC2185B));
  engine.stroke(xor);
  
  engine.setFillColor(const Color(0xFF000000));
  engine.fillText('XOR', 275, 170);
  engine.restore();
  
  // Complex combination
  engine.save();
  engine.translate(500, 100);
  
  final star = createStar(100, 100, 60, 30, 5);
  final circle = PathBuilder()
    ..arc(100, 100, 40, 0, math.pi * 2)
    ..close();
  
  // Create a complex shape
  final complex1 = PathOperations.difference(star, circle.build());
  final ring = PathBuilder()
    ..arc(100, 100, 60, 0, math.pi * 2)
    ..close();
  final innerCircle = PathBuilder()
    ..arc(100, 100, 45, 0, math.pi * 2)
    ..close();
  final complex2 = PathOperations.difference(ring.build(), innerCircle.build());
  final finalShape = PathOperations.union(complex1, complex2);
  
  // Draw with gradient
  final gradient = RadialGradient(
    center: Point(100, 100),
    radius: 60,
    colors: [
      const Color(0xFF9C27B0),
      const Color(0xFF673AB7),
      const Color(0xFF3F51B5),
    ],
  );
  engine.setFillPaint(gradient);
  engine.fill(finalShape);
  
  engine.setStrokeColor(const Color(0xFF311B92));
  engine.setStrokeWidth(2);
  engine.stroke(finalShape);
  
  engine.setFillColor(const Color(0xFF000000));
  engine.fillText('Complex Shape', 50, 190);
  engine.restore();
  
  await engine.saveToFile('path_operations.png');
  print('Path operations saved');
}
```

## Image Filter Effects

Demonstrates various image filtering capabilities.

```dart
import 'package:libgfx/libgfx.dart';
import 'dart:math' as math;

void main() async {
  final engine = GraphicsEngine(800, 600);
  engine.clear(const Color(0xFFFFFFFF));
  
  // Create a test pattern
  void drawTestPattern(double x, double y) {
    engine.save();
    engine.translate(x, y);
    
    // Colorful circles
    engine.setFillColor(const Color(0xFFFF0000));
    engine.fillCircle(30, 30, 20);
    engine.setFillColor(const Color(0xFF00FF00));
    engine.fillCircle(70, 30, 20);
    engine.setFillColor(const Color(0xFF0000FF));
    engine.fillCircle(50, 60, 20);
    
    // Text
    engine.setFillColor(const Color(0xFF000000));
    engine.setFontSize(16);
    engine.fillText('Test', 35, 90);
    
    // Border
    engine.setStrokeColor(const Color(0xFF333333));
    engine.setStrokeWidth(2);
    engine.strokeRect(0, 0, 100, 100);
    
    engine.restore();
  }
  
  // Original
  drawTestPattern(50, 50);
  engine.setFillColor(const Color(0xFF000000));
  engine.setFontSize(12);
  engine.fillText('Original', 50, 170);
  
  // Gaussian Blur
  engine.save();
  engine.translate(200, 50);
  engine.clipRect(0, 0, 100, 100);
  drawTestPattern(0, 0);
  engine.applyGaussianBlur(3.0);
  engine.restore();
  engine.fillText('Gaussian Blur', 200, 170);
  
  // Box Blur
  engine.save();
  engine.translate(350, 50);
  engine.clipRect(0, 0, 100, 100);
  drawTestPattern(0, 0);
  engine.applyBoxBlur(3.0);
  engine.restore();
  engine.fillText('Box Blur', 350, 170);
  
  // Sharpen
  engine.save();
  engine.translate(500, 50);
  engine.clipRect(0, 0, 100, 100);
  drawTestPattern(0, 0);
  engine.applySharpen(1.5);
  engine.restore();
  engine.fillText('Sharpen', 500, 170);
  
  // Edge Detection
  engine.save();
  engine.translate(650, 50);
  engine.clipRect(0, 0, 100, 100);
  drawTestPattern(0, 0);
  engine.applyEdgeDetect(threshold: 100);
  engine.restore();
  engine.fillText('Edge Detect', 650, 170);
  
  // Emboss
  engine.save();
  engine.translate(50, 250);
  engine.clipRect(0, 0, 100, 100);
  drawTestPattern(0, 0);
  engine.applyEmboss();
  engine.restore();
  engine.fillText('Emboss', 50, 370);
  
  // Motion Blur
  engine.save();
  engine.translate(200, 250);
  engine.clipRect(0, 0, 100, 100);
  drawTestPattern(0, 0);
  engine.applyMotionBlur(math.pi / 4, 10);
  engine.restore();
  engine.fillText('Motion Blur', 200, 370);
  
  // Custom Convolution - High Pass
  engine.save();
  engine.translate(350, 250);
  engine.clipRect(0, 0, 100, 100);
  drawTestPattern(0, 0);
  final highPass = [
    [-1, -1, -1],
    [-1,  9, -1],
    [-1, -1, -1],
  ];
  engine.applyConvolution(highPass);
  engine.restore();
  engine.fillText('High Pass', 350, 370);
  
  // Combined filters
  engine.save();
  engine.translate(500, 250);
  engine.clipRect(0, 0, 100, 100);
  drawTestPattern(0, 0);
  engine.applyGaussianBlur(1.0);
  engine.applySharpen(2.0);
  engine.restore();
  engine.fillText('Blur + Sharpen', 500, 370);
  
  await engine.saveToFile('filter_effects.png');
  print('Filter effects saved');
}
```

## Interactive Clock

Creates a functional analog clock visualization.

```dart
import 'package:libgfx/libgfx.dart';
import 'dart:math' as math;

void main() async {
  final now = DateTime.now();
  final engine = GraphicsEngine(400, 400);
  
  // Background
  final bgGradient = RadialGradient(
    center: Point(200, 200),
    radius: 200,
    colors: [
      const Color(0xFFF5F5F5),
      const Color(0xFFE0E0E0),
    ],
  );
  engine.setFillPaint(bgGradient);
  engine.fillRect(0, 0, 400, 400);
  
  // Clock face
  engine.save();
  engine.translate(200, 200);
  
  // Outer ring
  final ringGradient = RadialGradient(
    center: Point(0, 0),
    radius: 150,
    colors: [
      const Color(0xFF37474F),
      const Color(0xFF263238),
    ],
  );
  engine.setFillPaint(ringGradient);
  engine.fillCircle(0, 0, 150);
  
  // Inner face
  engine.setFillColor(const Color(0xFFECEFF1));
  engine.fillCircle(0, 0, 140);
  
  // Hour markers
  for (int i = 0; i < 12; i++) {
    final angle = (i * 30 - 90) * math.pi / 180;
    final isHour = i % 3 == 0;
    
    engine.save();
    engine.rotate(angle + math.pi / 2);
    
    if (isHour) {
      // Large hour markers
      engine.setFillColor(const Color(0xFF263238));
      engine.fillRect(-2, -130, 4, 20);
      
      // Hour numbers
      engine.save();
      engine.translate(0, -105);
      engine.rotate(-(angle + math.pi / 2));
      engine.setFontSize(18);
      engine.setTextAlign(TextAlign.center);
      engine.setTextBaseline(TextBaseline.middle);
      final hour = i == 0 ? 12 : i;
      engine.fillText(hour.toString(), 0, 0);
      engine.restore();
    } else {
      // Small minute markers
      engine.setFillColor(const Color(0xFF607D8B));
      engine.fillRect(-1, -130, 2, 10);
    }
    
    engine.restore();
  }
  
  // Calculate angles
  final hours = now.hour % 12;
  final minutes = now.minute;
  final seconds = now.second;
  final milliseconds = now.millisecond;
  
  final secondAngle = (seconds + milliseconds / 1000) * 6 - 90;
  final minuteAngle = (minutes + seconds / 60) * 6 - 90;
  final hourAngle = (hours + minutes / 60) * 30 - 90;
  
  // Hour hand
  engine.save();
  engine.rotate(hourAngle * math.pi / 180);
  engine.setFillColor(const Color(0xFF263238));
  final hourHand = PathBuilder()
    ..moveTo(-8, 0)
    ..lineTo(-3, -50)
    ..lineTo(0, -60)
    ..lineTo(3, -50)
    ..lineTo(8, 0)
    ..lineTo(4, 15)
    ..lineTo(-4, 15)
    ..close();
  engine.fill(hourHand.build());
  engine.restore();
  
  // Minute hand
  engine.save();
  engine.rotate(minuteAngle * math.pi / 180);
  engine.setFillColor(const Color(0xFF37474F));
  final minuteHand = PathBuilder()
    ..moveTo(-6, 0)
    ..lineTo(-2, -75)
    ..lineTo(0, -85)
    ..lineTo(2, -75)
    ..lineTo(6, 0)
    ..lineTo(3, 15)
    ..lineTo(-3, 15)
    ..close();
  engine.fill(minuteHand.build());
  engine.restore();
  
  // Second hand
  engine.save();
  engine.rotate(secondAngle * math.pi / 180);
  engine.setFillColor(const Color(0xFFE53935));
  engine.fillRect(-1, 20, 2, -115);
  engine.fillCircle(0, -95, 4);
  engine.restore();
  
  // Center cap
  final capGradient = RadialGradient(
    center: Point(0, 0),
    radius: 12,
    colors: [
      const Color(0xFF546E7A),
      const Color(0xFF37474F),
    ],
  );
  engine.setFillPaint(capGradient);
  engine.fillCircle(0, 0, 12);
  
  engine.setFillColor(const Color(0xFF263238));
  engine.fillCircle(0, 0, 8);
  
  engine.restore();
  
  // Digital time display
  engine.setFillColor(const Color(0xFF263238));
  engine.setFontSize(24);
  engine.setTextAlign(TextAlign.center);
  final timeString = '${now.hour.toString().padLeft(2, '0')}:'
                    '${now.minute.toString().padLeft(2, '0')}:'
                    '${now.second.toString().padLeft(2, '0')}';
  engine.fillText(timeString, 200, 320);
  
  // Date display
  engine.setFontSize(16);
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final dateString = '${months[now.month - 1]} ${now.day}, ${now.year}';
  engine.fillText(dateString, 200, 345);
  
  await engine.saveToFile('clock.png');
  print('Clock saved at ${timeString}');
}
```

## Fractal Tree

Generates a recursive fractal tree pattern.

```dart
import 'package:libgfx/libgfx.dart';
import 'dart:math' as math;

void main() async {
  final engine = GraphicsEngine(800, 600);
  
  // Sky gradient background
  final skyGradient = LinearGradient(
    start: Point(0, 0),
    end: Point(0, 600),
    colors: [
      const Color(0xFF87CEEB),
      const Color(0xFFF0E68C),
    ],
  );
  engine.setFillPaint(skyGradient);
  engine.fillRect(0, 0, 800, 600);
  
  // Ground
  engine.setFillColor(const Color(0xFF8B7355));
  engine.fillRect(0, 500, 800, 100);
  
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
    engine.setStrokeColor(color);
    
    // Thicker branches at the base
    engine.setStrokeWidth(depth * 0.5);
    
    // Draw branch
    engine.strokeLine(x, y, endX, endY);
    
    // Add leaves at the tips
    if (depth <= 2) {
      engine.setFillColor(const Color(0xFF228B22).withAlpha(150));
      engine.fillCircle(endX, endY, 3);
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
      500,
      80 * tree['size']!,
      -math.pi / 2,
      12,
    );
  }
  
  // Add some grass
  engine.setStrokeColor(const Color(0xFF355E3B));
  final random = math.Random(42);
  for (int i = 0; i < 200; i++) {
    final x = random.nextDouble() * 800;
    final y = 500 + random.nextDouble() * 100;
    final height = 5 + random.nextDouble() * 10;
    engine.setStrokeWidth(1);
    engine.strokeLine(x, y, x + random.nextDouble() * 4 - 2, y - height);
  }
  
  await engine.saveToFile('fractal_tree.png');
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
- **Sizes**: Adjust dimensions for different canvas sizes
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
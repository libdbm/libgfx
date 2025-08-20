import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/color/color_utils.dart';

void main() async {
  final engine = GraphicsEngine(800, 800);

  // Set background
  engine.clear(const Color(0xFF1a1a2e));

  // Move to center of canvas
  engine.translate(400, 400);

  // Create a spiraling pattern of squares with different styles
  const numIterations = 50;
  const initialSize = 300.0;
  const shrinkFactor = 0.92;
  const rotationAngle = math.pi / 20;

  for (int i = 0; i < numIterations; i++) {
    // Save the current state before each square
    engine.save();

    // Apply cumulative rotation for spiral effect
    engine.rotate(rotationAngle * i);

    // Scale down progressively
    final scaleFactor = math.pow(shrinkFactor, i).toDouble();
    engine.scale(scaleFactor);

    // Calculate color based on iteration
    final hue = (i * 7) % 360;
    final color = ColorUtils.hslToRgb(HSLColor(hue.toDouble(), 0.7, 0.6));

    // Alternate between filled and stroked squares
    if (i % 3 == 0) {
      // Filled square with gradient
      engine.setFillPaint(
        LinearGradient(
          startPoint: Point(-initialSize / 2, -initialSize / 2),
          endPoint: Point(initialSize / 2, initialSize / 2),
          stops: [
            ColorStop(0.0, color),
            ColorStop(1.0, ColorUtils.adjustBrightness(color, -0.5)),
          ],
        ),
      );
      drawSquare(engine, initialSize, filled: true);
    } else if (i % 3 == 1) {
      // Stroked square with varying width
      engine.setStrokeColor(color);
      engine.setLineWidth(3 + (i % 5));

      // Add dashed pattern for some squares
      if (i % 7 == 0) {
        engine.setLineDash([10, 5, 2, 5]);
      } else {
        engine.setLineDash([]);
      }

      drawSquare(engine, initialSize, filled: false);
    } else {
      // Combination of fill and stroke
      engine.setFillColor(ColorUtils.adjustBrightness(color, -0.7));
      engine.setStrokeColor(color);
      engine.setLineWidth(2);

      drawSquare(engine, initialSize, filled: true, stroked: true);
    }

    // Restore state for next iteration
    engine.restore();
  }

  // Add some decorative elements using different line styles
  addDecorativeElements(engine);

  // Save the result
  await engine.saveToFile('output/spiral_state_demo.ppm');
  print('Saved output/spiral_state_demo.ppm');
}

void drawSquare(
  GraphicsEngine engine,
  double size, {
  bool filled = true,
  bool stroked = false,
}) {
  final halfSize = size / 2;
  final builder = PathBuilder()
    ..moveTo(-halfSize, -halfSize)
    ..lineTo(halfSize, -halfSize)
    ..lineTo(halfSize, halfSize)
    ..lineTo(-halfSize, halfSize)
    ..close();

  final square = builder.build();

  if (filled) {
    engine.fill(square);
  }
  if (stroked || !filled) {
    engine.stroke(square);
  }
}

void addDecorativeElements(GraphicsEngine engine) {
  // Save current state
  engine.save();

  // Draw corner decorations
  const corners = [
    [-350, -350],
    [350, -350],
    [350, 350],
    [-350, 350],
  ];

  for (int i = 0; i < corners.length; i++) {
    engine.save();

    engine.translate(corners[i][0].toDouble(), corners[i][1].toDouble());
    engine.rotate(i * math.pi / 2);

    // Set style for decorative element
    engine.setStrokeColor(const Color(0xFF16213e));
    engine.setLineWidth(3);
    engine.setLineCap(LineCap.round);
    engine.setLineJoin(LineJoin.round);

    // Draw decorative corner pattern
    final decoration = PathBuilder()
      ..moveTo(0, 0)
      ..lineTo(30, 0)
      ..moveTo(0, 0)
      ..lineTo(0, 30)
      ..moveTo(10, 0)
      ..lineTo(10, 10)
      ..lineTo(0, 10);

    engine.stroke(decoration.build());

    engine.restore();
  }

  // Draw central circles with different blend modes
  for (int i = 0; i < 3; i++) {
    engine.save();

    final radius = 50.0 + i * 30;
    engine.setStrokeColor(Color(0x40FFFFFF));
    engine.setLineWidth(1);
    engine.setLineDash([5, 10]);

    drawCircle(engine, radius);

    engine.restore();
  }

  // Restore original state
  engine.restore();
}

void drawCircle(GraphicsEngine engine, double radius) {
  final builder = PathBuilder();
  const segments = 64;

  for (int i = 0; i <= segments; i++) {
    final angle = (i / segments) * 2 * math.pi;
    final x = radius * math.cos(angle);
    final y = radius * math.sin(angle);

    if (i == 0) {
      builder.moveTo(x, y);
    } else {
      builder.lineTo(x, y);
    }
  }

  engine.stroke(builder.build());
}

// Using ColorUtils functions for color manipulation

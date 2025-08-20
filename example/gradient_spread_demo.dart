import 'dart:math' as math;

import 'package:libgfx/src/color/color.dart';
import 'package:libgfx/src/graphics_engine_facade.dart';
import 'package:libgfx/src/paint.dart';
import 'package:libgfx/src/paths/path.dart';
import 'package:libgfx/src/point.dart';

void main() async {
  final engine = GraphicsEngine(900, 600);

  // Set background
  engine.clear(const Color(0xFF2a2a2a));

  // Gradient stops for demonstration
  final stops = [
    ColorStop(0.0, const Color(0xFFFF0000)), // Red
    ColorStop(0.33, const Color(0xFF00FF00)), // Green
    ColorStop(0.66, const Color(0xFF0000FF)), // Blue
    ColorStop(1.0, const Color(0xFFFF00FF)), // Magenta
  ];

  // Demonstrate Linear Gradient Spreads
  drawLinearGradientSpreads(engine, stops);

  // Demonstrate Radial Gradient Spreads
  drawRadialGradientSpreads(engine, stops);

  // Add labels
  addLabels(engine);

  await engine.saveToFile('output/gradient_spread_demo.ppm');
  print('Saved output/gradient_spread_demo.ppm');
}

void drawLinearGradientSpreads(GraphicsEngine engine, List<ColorStop> stops) {
  const boxWidth = 250.0;
  const boxHeight = 150.0;
  const startY = 50.0;

  // Pad spread (default)
  engine.save();
  engine.setFillPaint(
    LinearGradient(
      startPoint: Point(50, 0),
      endPoint: Point(150, 0),
      stops: stops,
      spread: GradientSpread.pad,
    ),
  );
  final padRect = createRect(50, startY, boxWidth, boxHeight);
  engine.fill(padRect);
  engine.restore();

  // Reflect spread
  engine.save();
  engine.setFillPaint(
    LinearGradient(
      startPoint: Point(350, 0),
      endPoint: Point(450, 0),
      stops: stops,
      spread: GradientSpread.reflect,
    ),
  );
  final reflectRect = createRect(325, startY, boxWidth, boxHeight);
  engine.fill(reflectRect);
  engine.restore();

  // Repeat spread
  engine.save();
  engine.setFillPaint(
    LinearGradient(
      startPoint: Point(625, 0),
      endPoint: Point(725, 0),
      stops: stops,
      spread: GradientSpread.repeat,
    ),
  );
  final repeatRect = createRect(600, startY, boxWidth, boxHeight);
  engine.fill(repeatRect);
  engine.restore();
}

void drawRadialGradientSpreads(GraphicsEngine engine, List<ColorStop> stops) {
  const boxSize = 150.0;
  const startY = 300.0;

  // Pad spread (default)
  engine.save();
  engine.setFillPaint(
    RadialGradient(
      center: Point(125, startY + 75),
      radius: 50,
      stops: stops,
      spread: GradientSpread.pad,
    ),
  );
  final padCircle = createRect(50, startY, boxSize, boxSize);
  engine.fill(padCircle);
  engine.restore();

  // Reflect spread
  engine.save();
  engine.setFillPaint(
    RadialGradient(
      center: Point(400, startY + 75),
      radius: 50,
      stops: stops,
      spread: GradientSpread.reflect,
    ),
  );
  final reflectCircle = createRect(325, startY, boxSize, boxSize);
  engine.fill(reflectCircle);
  engine.restore();

  // Repeat spread
  engine.save();
  engine.setFillPaint(
    RadialGradient(
      center: Point(675, startY + 75),
      radius: 50,
      stops: stops,
      spread: GradientSpread.repeat,
    ),
  );
  final repeatCircle = createRect(600, startY, boxSize, boxSize);
  engine.fill(repeatCircle);
  engine.restore();

  // Focal point radial gradient
  engine.save();
  engine.setFillPaint(
    RadialGradient(
      center: Point(400, 500),
      focal: Point(380, 480),
      // Offset focal point
      radius: 60,
      stops: stops,
      spread: GradientSpread.reflect,
    ),
  );
  final focalCircle = createCircle(400, 500, 70);
  engine.fill(focalCircle);
  engine.restore();
}

void addLabels(GraphicsEngine engine) {
  // Draw borders and labels for clarity
  engine.setStrokeColor(const Color(0xFF888888));
  engine.setLineWidth(2);

  // Linear gradient labels
  engine.stroke(createRect(50, 50, 250, 150));
  engine.stroke(createRect(325, 50, 250, 150));
  engine.stroke(createRect(600, 50, 250, 150));

  // Radial gradient labels
  engine.stroke(createRect(50, 300, 150, 150));
  engine.stroke(createRect(325, 300, 150, 150));
  engine.stroke(createRect(600, 300, 150, 150));

  // Focal gradient circle
  engine.stroke(createCircle(400, 500, 70));

  // Add small markers to show gradient control points
  engine.setFillColor(const Color(0xFFFFFFFF));

  // Linear gradient control points
  drawMarker(engine, 50, 125);
  drawMarker(engine, 150, 125);
  drawMarker(engine, 350, 125);
  drawMarker(engine, 450, 125);
  drawMarker(engine, 625, 125);
  drawMarker(engine, 725, 125);

  // Radial gradient centers
  drawMarker(engine, 125, 375);
  drawMarker(engine, 400, 375);
  drawMarker(engine, 675, 375);

  // Focal point markers
  drawMarker(engine, 400, 500); // Center
  drawMarker(engine, 380, 480); // Focal
}

Path createRect(double x, double y, double width, double height) {
  final builder = PathBuilder()
    ..moveTo(x, y)
    ..lineTo(x + width, y)
    ..lineTo(x + width, y + height)
    ..lineTo(x, y + height)
    ..close();
  return builder.build();
}

Path createCircle(double cx, double cy, double radius) {
  final builder = PathBuilder();
  const segments = 64;

  for (int i = 0; i <= segments; i++) {
    final angle = (i / segments) * 2 * math.pi;
    final x = cx + radius * math.cos(angle);
    final y = cy + radius * math.sin(angle);

    if (i == 0) {
      builder.moveTo(x, y);
    } else {
      builder.lineTo(x, y);
    }
  }

  return builder.build();
}

void drawMarker(GraphicsEngine engine, double x, double y) {
  final marker = PathBuilder()
    ..moveTo(x - 3, y - 3)
    ..lineTo(x + 3, y - 3)
    ..lineTo(x + 3, y + 3)
    ..lineTo(x - 3, y + 3)
    ..close();
  engine.fill(marker.build());
}

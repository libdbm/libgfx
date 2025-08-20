import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';

void main() async {
  final engine = GraphicsEngine(800, 600);
  engine.clear(const Color(0xFFFFFFFF));

  // Load font for labels
  await engine.setFontFromFile('data/fonts/NotoSans-Regular.ttf');

  // Demo 1: cubicCurveTo method
  demoCubicCurve(engine, 50, 50);

  // Demo 2: quadraticCurveTo method
  demoQuadraticCurve(engine, 50, 250);

  // Demo 3: Complex path with multiple curve types
  demoComplexPath(engine, 50, 450);

  await engine.saveToFile('output/curve_methods_demo.png');
  print('Curve methods demo saved to output/curve_methods_demo.png');
}

void demoCubicCurve(GraphicsEngine engine, double x, double y) {
  engine.save();
  engine.translate(x, y);

  // Draw cubic Bézier curve using the new cubicCurveTo method
  final path = PathBuilder()
      .moveTo(0, 100)
      .cubicCurveTo(100, 0, 200, 200, 300, 100)
      .build();

  // Draw the curve
  engine.setStrokeColor(const Color(0xFF2196F3));
  engine.setLineWidth(3);
  engine.stroke(path);

  // Draw control points and lines
  engine.setStrokeColor(const Color(0xFFCCCCCC));
  engine.setLineWidth(1);

  // Control lines
  final controlLines = PathBuilder()
      .moveTo(0, 100)
      .lineTo(100, 0)
      .moveTo(200, 200)
      .lineTo(300, 100)
      .build();
  engine.stroke(controlLines);

  // Draw points
  engine.setFillColor(const Color(0xFFFF5722));
  drawPoint(engine, 0, 100, "Start");
  drawPoint(engine, 100, 0, "CP1");
  drawPoint(engine, 200, 200, "CP2");
  drawPoint(engine, 300, 100, "End");

  // Label
  engine.setFillColor(const Color(0xFF333333));
  engine.setFontSize(14);
  engine.fillText("cubicCurveTo(100, 0, 200, 200, 300, 100)", 0, 140);

  engine.restore();
}

void demoQuadraticCurve(GraphicsEngine engine, double x, double y) {
  engine.save();
  engine.translate(x, y);

  // Draw quadratic Bézier curve using the new quadraticCurveTo method
  final path = PathBuilder()
      .moveTo(0, 100)
      .quadraticCurveTo(150, 0, 300, 100)
      .build();

  // Draw the curve
  engine.setStrokeColor(const Color(0xFF4CAF50));
  engine.setLineWidth(3);
  engine.stroke(path);

  // Draw control point and lines
  engine.setStrokeColor(const Color(0xFFCCCCCC));
  engine.setLineWidth(1);

  // Control lines
  final controlLines = PathBuilder()
      .moveTo(0, 100)
      .lineTo(150, 0)
      .lineTo(300, 100)
      .build();
  engine.stroke(controlLines);

  // Draw points
  engine.setFillColor(const Color(0xFFFF5722));
  drawPoint(engine, 0, 100, "Start");
  drawPoint(engine, 150, 0, "Control");
  drawPoint(engine, 300, 100, "End");

  // Label
  engine.setFillColor(const Color(0xFF333333));
  engine.setFontSize(14);
  engine.fillText("quadraticCurveTo(150, 0, 300, 100)", 0, 140);

  engine.restore();
}

void demoComplexPath(GraphicsEngine engine, double x, double y) {
  engine.save();
  engine.translate(x, y);

  // Create a complex path mixing different curve types
  final path = PathBuilder()
      .moveTo(0, 50)
      .lineTo(50, 50)
      .quadraticCurveTo(100, 0, 150, 50)
      .cubicCurveTo(200, 100, 250, 0, 300, 50)
      .lineTo(350, 50)
      .arc(400, 50, 50, 0, math.pi)
      .lineTo(350, 100)
      .quadraticCurveTo(300, 120, 250, 100)
      .cubicCurveTo(200, 80, 150, 120, 100, 100)
      .lineTo(50, 100)
      .close()
      .build();

  // Fill with gradient
  final gradient = LinearGradient(
    startPoint: Point(0, 0),
    endPoint: Point(450, 120),
    stops: [
      ColorStop(0.0, const Color(0x44FF6B6B)),
      ColorStop(0.5, const Color(0x444ECDC4)),
      ColorStop(1.0, const Color(0x4445B7D1)),
    ],
  );
  engine.setFillPaint(gradient);
  engine.fill(path);

  // Stroke the path
  engine.setStrokeColor(const Color(0xFF333333));
  engine.setLineWidth(2);
  engine.stroke(path);

  // Label
  engine.setFillColor(const Color(0xFF333333));
  engine.setFontSize(14);
  engine.fillText("Complex path with mixed curve types", 100, -20);

  engine.restore();
}

void drawPoint(GraphicsEngine engine, double x, double y, String label) {
  // Draw dot
  final dot = PathBuilder().arc(x, y, 4, 0, 2 * math.pi).build();
  engine.fill(dot);

  // Draw label
  engine.setFontSize(10);
  engine.fillText(label, x + 8, y + 3);
}

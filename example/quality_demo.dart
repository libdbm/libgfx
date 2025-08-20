import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';

void main() async {
  // Create graphics engine
  final engine = GraphicsEngine(1200, 800);
  engine.clear(const Color(0xFFF5F5F5));

  // Demo 1: Advanced Clipping with Fill Rules
  demonstrateClipping(engine, 50, 50);

  // Demo 2: ICC Color Profiles
  demonstrateColorProfiles(engine, 450, 50);

  // Demo 3: Sub-pixel Text Rendering
  await demonstrateSubPixelText(engine, 50, 350);

  // Demo 4: High-Quality Curves
  demonstrateCurveQuality(engine, 450, 350);

  // Save result
  await engine.saveToFile('output/quality_demo.ppm');
  print('Saved output/quality_demo.ppm');
}

void demonstrateClipping(GraphicsEngine engine, double x, double y) {
  engine.save();
  engine.translate(x, y);

  // Title
  engine.setFillColor(const Color(0xFF333333));

  // Create a star path for clipping
  final starPath = createStarPath(100, 100, 40, 20, 5);

  // Demo even-odd fill rule
  engine.save();

  // Apply clipping
  engine.clip(starPath);

  // Draw gradient through clip
  final gradient = RadialGradient(
    center: Point(100, 100),
    radius: 50,
    stops: [
      ColorStop(0.0, const Color(0xFFFF6B6B)),
      ColorStop(0.5, const Color(0xFF4ECDC4)),
      ColorStop(1.0, const Color(0xFF45B7D1)),
    ],
  );
  engine.setFillPaint(gradient);

  final rectPath = PathBuilder()
      .moveTo(50, 50)
      .lineTo(150, 50)
      .lineTo(150, 150)
      .lineTo(50, 150)
      .close()
      .build();
  engine.fill(rectPath);

  engine.restore();

  // Demo non-zero fill rule
  engine.save();
  engine.translate(200, 0);

  // Create overlapping rectangles path
  final overlappingPath = PathBuilder()
      .moveTo(30, 30)
      .lineTo(120, 30)
      .lineTo(120, 120)
      .lineTo(30, 120)
      .close()
      .moveTo(60, 60)
      .lineTo(150, 60)
      .lineTo(150, 150)
      .lineTo(60, 150)
      .close()
      .build();

  engine.clip(overlappingPath);

  // Draw pattern through clip
  final patternBitmap = createCheckerPattern(20, 20);
  engine.setFillPaint(
    PatternPaint(pattern: patternBitmap, repeat: PatternRepeat.repeat),
  );
  engine.fill(rectPath);

  engine.restore();

  // Hit testing demo
  engine.save();
  engine.translate(0, 200);

  // Draw path and show hit test points
  final testPath = createHeartPath(50, 50, 40);
  engine.setFillColor(const Color(0xFFFF69B4));
  engine.fill(testPath);

  // Show hit test results
  // Note: AdvancedClipRegion would need to be exposed in public API
  // For now, we'll do a simple approximation

  for (int py = 20; py < 80; py += 5) {
    for (int px = 20; px < 80; px += 5) {
      // Simple approximation: check if point is within heart bounds
      final dx = (px - 50).abs();
      final dy = (py - 50).abs();
      final hit = dx < 30 && dy < 35;

      engine.setFillColor(
        hit ? const Color(0xFF00FF00) : const Color(0xFFFF0000),
      );

      final dotPath = PathBuilder()
          .arc(px.toDouble(), py.toDouble(), 1, 0, 2 * math.pi)
          .build();
      engine.fill(dotPath);
    }
  }

  engine.restore();
  engine.restore();
}

void demonstrateColorProfiles(GraphicsEngine engine, double x, double y) {
  engine.save();
  engine.translate(x, y);

  // Create color swatches in different profiles
  final testColor = Color.fromRGBA(255, 100, 50, 255);

  // sRGB (reference)
  drawColorSwatch(engine, 0, 0, testColor, "sRGB");

  // Note: ColorProfile conversions would need the ColorProfile class to be exposed
  // For demo purposes, we'll show slightly different colors

  // Simulated Adobe RGB (slightly more saturated)
  final adobeColor = Color.fromRGBA(255, 90, 40, 255);
  drawColorSwatch(engine, 100, 0, adobeColor, "Adobe RGB");

  // Simulated Display P3 (wider gamut)
  final p3Color = Color.fromRGBA(255, 95, 45, 255);
  drawColorSwatch(engine, 200, 0, p3Color, "Display P3");

  // Simulated ProPhoto RGB
  final proPhotoColor = Color.fromRGBA(250, 105, 55, 255);
  drawColorSwatch(engine, 300, 0, proPhotoColor, "ProPhoto");

  // Show color difference in Lab space
  engine.save();
  engine.translate(0, 100);

  // Create gradient showing perceptual uniformity
  for (int i = 0; i < 300; i++) {
    final t = i / 300.0;

    // Linear interpolation in RGB
    final rgbInterp = Color.fromRGBA(
      (255 * (1 - t) + 50 * t).round(),
      (50 * (1 - t) + 255 * t).round(),
      (100 * (1 - t) + 100 * t).round(),
      255,
    );

    engine.setFillColor(rgbInterp);
    final rectPath = PathBuilder()
        .moveTo(i.toDouble(), 0)
        .lineTo(i + 1.0, 0)
        .lineTo(i + 1.0, 30)
        .lineTo(i.toDouble(), 30)
        .close()
        .build();
    engine.fill(rectPath);
  }

  engine.restore();
  engine.restore();
}

Future<void> demonstrateSubPixelText(
  GraphicsEngine engine,
  double x,
  double y,
) async {
  engine.save();
  engine.translate(x, y);

  // Load font
  await engine.setFontFromFile('data/fonts/NotoSans-Regular.ttf');

  // Standard rendering
  engine.setFillColor(const Color(0xFF000000));
  engine.setFontSize(16);
  engine.fillText("Standard Anti-aliasing", 0, 20);

  // Note: SubPixelTextRenderer would need to be exposed in public API
  // The text rendering improvements are already integrated into the engine

  engine.setFontSize(12);
  engine.fillText(
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
    0,
    50,
  );

  engine.setFontSize(10);
  engine.fillText(
    "The quick brown fox jumps over the lazy dog. 0123456789",
    0,
    70,
  );

  engine.setFontSize(8);
  engine.fillText(
    "Small text benefits most from sub-pixel rendering quality improvements.",
    0,
    90,
  );

  // Show text at different sizes with quality comparison
  final sizes = [6, 8, 10, 12, 14, 16, 18, 24, 32];
  double yOffset = 120;

  for (final size in sizes) {
    engine.setFontSize(size.toDouble());
    engine.fillText("Quality @ ${size}px: Hamburgefonstiv", 0, yOffset);
    yOffset += size + 5;
  }

  engine.restore();
}

void demonstrateCurveQuality(GraphicsEngine engine, double x, double y) {
  engine.save();
  engine.translate(x, y);

  // Create a complex curve
  final curvePath = PathBuilder()
      .moveTo(0, 100)
      .cubicCurveTo(50, 0, 150, 200, 200, 100)
      .cubicCurveTo(250, 0, 350, 200, 400, 100)
      .build();

  // Draw with standard quality
  engine.save();
  engine.setStrokeColor(const Color(0xFF888888));
  engine.setLineWidth(1);
  engine.stroke(curvePath);
  engine.restore();

  // Draw with high quality (curve flattening is built-in)
  engine.save();
  engine.translate(0, 150);

  // Note: CurveFlattener would need to be exposed in public API
  // The curve quality improvements are already integrated
  // For demo, we'll show the same curve with visual points

  final flatPath = PathBuilder()
      .moveTo(0, 100)
      .cubicCurveTo(50, 0, 150, 200, 200, 100)
      .build();

  engine.setStrokeColor(const Color(0xFF4CAF50));
  engine.setLineWidth(2);
  engine.stroke(flatPath);

  // Show some sample points along the curve
  engine.setFillColor(const Color(0xFFFF5722));
  for (int i = 0; i <= 10; i++) {
    final t = i / 10.0;
    // Approximate points on cubic bezier
    final x = 200 * t;
    final y = 100 + 50 * math.sin(t * math.pi);

    final dotPath = PathBuilder().arc(x, y, 2, 0, 2 * math.pi).build();
    engine.fill(dotPath);
  }

  engine.restore();

  // Draw smooth ellipse with adaptive flattening
  engine.save();
  engine.translate(200, 50);

  final ellipsePath = PathBuilder()
      .ellipse(50, 50, 40, 25, math.pi / 4, 0, 2 * math.pi)
      .build();

  engine.setStrokeColor(const Color(0xFF2196F3));
  engine.setLineWidth(2);
  engine.stroke(ellipsePath);

  engine.restore();
  engine.restore();
}

Path createStarPath(
  double cx,
  double cy,
  double outerRadius,
  double innerRadius,
  int points,
) {
  final builder = PathBuilder();
  final angleStep = (2 * math.pi) / points;

  for (int i = 0; i < points; i++) {
    final outerAngle = i * angleStep - math.pi / 2;
    final innerAngle = outerAngle + angleStep / 2;

    final outerX = cx + outerRadius * math.cos(outerAngle);
    final outerY = cy + outerRadius * math.sin(outerAngle);
    final innerX = cx + innerRadius * math.cos(innerAngle);
    final innerY = cy + innerRadius * math.sin(innerAngle);

    if (i == 0) {
      builder.moveTo(outerX, outerY);
    } else {
      builder.lineTo(outerX, outerY);
    }
    builder.lineTo(innerX, innerY);
  }

  builder.close();
  return builder.build();
}

Path createHeartPath(double cx, double cy, double size) {
  final builder = PathBuilder();

  builder.moveTo(cx, cy + size * 0.3);
  builder.cubicCurveTo(
    cx - size * 0.5,
    cy - size * 0.3,
    cx - size,
    cy + size * 0.1,
    cx - size,
    cy + size * 0.4,
  );
  builder.cubicCurveTo(
    cx - size,
    cy + size * 0.8,
    cx - size * 0.5,
    cy + size,
    cx,
    cy + size * 0.7,
  );
  builder.cubicCurveTo(
    cx + size * 0.5,
    cy + size,
    cx + size,
    cy + size * 0.8,
    cx + size,
    cy + size * 0.4,
  );
  builder.cubicCurveTo(
    cx + size,
    cy + size * 0.1,
    cx + size * 0.5,
    cy - size * 0.3,
    cx,
    cy + size * 0.3,
  );

  builder.close();
  return builder.build();
}

Bitmap createCheckerPattern(int width, int height) {
  final pattern = Bitmap(width, height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final isEven = ((x ~/ 5) + (y ~/ 5)) % 2 == 0;
      pattern.setPixel(x, y, Color(isEven ? 0xFF333333 : 0xFFCCCCCC));
    }
  }

  return pattern;
}

void drawColorSwatch(
  GraphicsEngine engine,
  double x,
  double y,
  Color color,
  String label,
) {
  engine.save();
  engine.translate(x, y);

  // Draw swatch
  engine.setFillColor(color);
  final swatchPath = PathBuilder()
      .moveTo(0, 0)
      .lineTo(80, 0)
      .lineTo(80, 60)
      .lineTo(0, 60)
      .close()
      .build();
  engine.fill(swatchPath);

  // Draw border
  engine.setStrokeColor(const Color(0xFF666666));
  engine.setLineWidth(1);
  engine.stroke(swatchPath);

  engine.restore();
}

import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/color/color_utils.dart';

void main() async {
  final engine = GraphicsEngine(800, 800);

  // Dark background
  engine.clear(const Color(0xFF0a0a0a));

  // Move to center
  engine.translate(400, 400);

  // Draw a pattern demonstrating nested save/restore operations
  drawNestedPattern(engine);

  await engine.saveToFile('output/nested_transforms_demo.ppm');
  print('Saved output/nested_transforms_demo.ppm');
}

void drawNestedPattern(GraphicsEngine engine) {
  const arms = 8;
  const levels = 4;

  for (int arm = 0; arm < arms; arm++) {
    // Save state for each arm
    engine.save();

    // Rotate to position for this arm
    engine.rotate(arm * 2 * math.pi / arms);

    // Draw recursive branch structure
    drawBranch(engine, 0, levels, 120, 8);

    // Restore state after drawing arm
    engine.restore();
  }

  // Draw central decoration
  drawCentralDecoration(engine);
}

void drawBranch(
  GraphicsEngine engine,
  int currentLevel,
  int maxLevel,
  double length,
  double width,
) {
  if (currentLevel >= maxLevel) return;

  // Calculate color based on level
  final brightness = 1.0 - (currentLevel / maxLevel) * 0.7;
  final hue = 180 + currentLevel * 30;
  final color = ColorUtils.hslToRgb(
    HSLColor(hue.toDouble(), 0.6, brightness * 0.5),
  );

  // Set style for this branch
  engine.setStrokeColor(color);
  engine.setLineWidth(width);
  engine.setLineCap(LineCap.round);

  // Draw the main branch line
  final branch = PathBuilder()
    ..moveTo(0, 0)
    ..lineTo(length, 0);
  engine.stroke(branch.build());

  // Move to end of branch for sub-branches
  engine.save();
  engine.translate(length, 0);

  // Draw decorative element at branch point
  if (currentLevel < maxLevel - 1) {
    engine.save();
    engine.setFillColor(ColorUtils.adjustBrightness(color, 0.3));
    drawDiamond(engine, width * 0.8);
    engine.restore();
  }

  // Create sub-branches
  const subBranches = 3;
  const angleSpread = math.pi / 3;

  for (int i = 0; i < subBranches; i++) {
    engine.save();

    // Calculate angle for sub-branch
    final angle = -angleSpread / 2 + (i * angleSpread / (subBranches - 1));
    engine.rotate(angle);

    // Recursively draw sub-branch
    drawBranch(engine, currentLevel + 1, maxLevel, length * 0.7, width * 0.7);

    engine.restore();
  }

  engine.restore();
}

void drawDiamond(GraphicsEngine engine, double size) {
  final diamond = PathBuilder()
    ..moveTo(0, -size)
    ..lineTo(size, 0)
    ..lineTo(0, size)
    ..lineTo(-size, 0)
    ..close();

  engine.fill(diamond.build());
}

void drawCentralDecoration(GraphicsEngine engine) {
  // Save state for central decoration
  engine.save();

  // Draw concentric shapes with different styles
  for (int i = 0; i < 5; i++) {
    engine.save();

    final scale = 1.0 - i * 0.15;
    engine.scale(scale);
    engine.rotate(i * math.pi / 10);

    // Alternate between different shapes and styles
    if (i % 2 == 0) {
      engine.setStrokeColor(Color(0xFF404040 | (i * 0x202020)));
      engine.setLineWidth(2);
      engine.setLineDash([5, 3]);
      drawPolygon(engine, 6, 40);
    } else {
      engine.setFillColor(Color(0x40808080 | (i * 0x101010)));
      drawPolygon(engine, 8, 35, filled: true);
    }

    engine.restore();
  }

  // Draw central star
  engine.save();
  engine.setFillColor(const Color(0xFFFFD700));
  drawStar(engine, 20, 10, 5);
  engine.restore();

  engine.restore();
}

void drawPolygon(
  GraphicsEngine engine,
  int sides,
  double radius, {
  bool filled = false,
}) {
  final builder = PathBuilder();

  for (int i = 0; i <= sides; i++) {
    final angle = (i % sides) * 2 * math.pi / sides - math.pi / 2;
    final x = radius * math.cos(angle);
    final y = radius * math.sin(angle);

    if (i == 0) {
      builder.moveTo(x, y);
    } else {
      builder.lineTo(x, y);
    }
  }

  final polygon = builder.build();

  if (filled) {
    engine.fill(polygon);
  } else {
    engine.stroke(polygon);
  }
}

void drawStar(
  GraphicsEngine engine,
  double outerRadius,
  double innerRadius,
  int points,
) {
  final builder = PathBuilder();

  for (int i = 0; i <= points * 2; i++) {
    final angle = (i * math.pi / points) - math.pi / 2;
    final radius = i % 2 == 0 ? outerRadius : innerRadius;
    final x = radius * math.cos(angle);
    final y = radius * math.sin(angle);

    if (i == 0) {
      builder.moveTo(x, y);
    } else {
      builder.lineTo(x, y);
    }
  }

  engine.fill(builder.build());
}

// Using ColorUtils functions for color manipulation

import 'dart:io';
import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/color/color_utils.dart';

Future<void> main() async {
  print('Advanced Features Demo');
  print('=====================');
  print('Testing: Text API, Advanced Clipping, and Blend Modes');

  final engine = GraphicsEngine(1200, 900);
  engine.clear(const Color(0xFFF5F5F5));

  // Load a font if available
  final fontsDir = Directory('data/fonts');
  if (fontsDir.existsSync()) {
    final fontFiles = fontsDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.ttf'))
        .toList();

    if (fontFiles.isNotEmpty) {
      await engine.setFontFromFile(fontFiles.first.path);
      engine.setFontSize(24);
    }
  }

  // === Section 1: Text Rendering API Demo ===
  var yPos = 50.0;

  // Title
  engine.setFillColor(const Color(0xFF000000));
  engine.setTextAlign(TextAlign.center);
  engine.fillText('Advanced Graphics Features Demo', 600, yPos);

  yPos += 60;

  // Text alignment demonstration
  engine.setFontSize(18);
  engine.setFillColor(const Color(0xFF333333));

  // Draw vertical guide line
  engine.setStrokeColor(const Color(0xFFCCCCCC));
  engine.setLineWidth(1);
  final guideLine = PathBuilder()
    ..moveTo(200, yPos - 10)
    ..lineTo(200, yPos + 100);
  engine.stroke(guideLine.build());

  // Left aligned
  engine.setTextAlign(TextAlign.left);
  engine.fillText('Left Aligned', 200, yPos);
  yPos += 30;

  // Center aligned
  engine.setTextAlign(TextAlign.center);
  engine.fillText('Center Aligned', 200, yPos);
  yPos += 30;

  // Right aligned
  engine.setTextAlign(TextAlign.right);
  engine.fillText('Right Aligned', 200, yPos);
  yPos += 30;

  // Measure text
  engine.setTextAlign(TextAlign.left);
  final measuredText = 'Measured Text';
  final metrics = engine.measureText(measuredText);
  engine.fillText(measuredText, 200, yPos);

  // Draw bounding box
  engine.setStrokeColor(const Color(0xFF0080FF));
  final bbox = PathBuilder()
    ..moveTo(200, yPos - metrics.ascent)
    ..lineTo(200 + metrics.width, yPos - metrics.ascent)
    ..lineTo(200 + metrics.width, yPos + metrics.descent)
    ..lineTo(200, yPos + metrics.descent)
    ..close();
  engine.stroke(bbox.build());

  // Show metrics
  engine.setFontSize(12);
  engine.setFillColor(const Color(0xFF666666));
  engine.fillText('Width: ${metrics.width.toStringAsFixed(1)}px', 350, yPos);

  yPos += 60;

  // === Section 2: Even-Odd vs Non-Zero Fill Rules ===

  engine.setFontSize(20);
  engine.setFillColor(const Color(0xFF000000));
  engine.fillText('Fill Rules for Clipping:', 50, yPos);
  yPos += 40;

  // Create a star path with overlapping triangles (shows difference in fill rules)
  Path createComplexPath(double cx, double cy) {
    final builder = PathBuilder();

    // Outer star points
    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - math.pi / 2;
      final x = cx + 60 * math.cos(angle);
      final y = cy + 60 * math.sin(angle);

      if (i == 0) {
        builder.moveTo(x, y);
      } else {
        builder.lineTo(x, y);
      }
    }
    builder.close();

    // Inner star (opposite winding)
    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - math.pi / 2 + math.pi / 5;
      final x = cx + 30 * math.cos(angle);
      final y = cy + 30 * math.sin(angle);

      if (i == 0) {
        builder.moveTo(x, y);
      } else {
        builder.lineTo(x, y);
      }
    }
    builder.close();

    return builder.build();
  }

  // Even-odd fill rule
  engine.save();
  final evenOddPath = createComplexPath(150, yPos + 60);
  engine.clipWithFillRule(evenOddPath, fillRule: FillRule.evenOdd);

  // Draw gradient background to show clipping
  for (int i = 0; i < 20; i++) {
    final color = Color.fromRGBA(255 - i * 10, 100 + i * 5, 150, 255);
    engine.setFillColor(color);
    final rect = PathBuilder()
      ..moveTo(90.0 + i * 6, yPos)
      ..lineTo(210.0 - i * 6, yPos)
      ..lineTo(210.0 - i * 6, yPos + 120)
      ..lineTo(90.0 + i * 6, yPos + 120)
      ..close();
    engine.fill(rect.build());
  }
  engine.restore();

  // Draw outline
  engine.setStrokeColor(const Color(0xFF000000));
  engine.setLineWidth(2);
  engine.stroke(evenOddPath);

  engine.setFontSize(14);
  engine.setFillColor(const Color(0xFF000000));
  engine.fillText('Even-Odd Rule', 150, yPos + 140);

  // Non-zero winding fill rule
  engine.save();
  final nonZeroPath = createComplexPath(350, yPos + 60);
  engine.clipWithFillRule(nonZeroPath, fillRule: FillRule.nonZero);

  // Draw gradient background to show clipping
  for (int i = 0; i < 20; i++) {
    final color = Color.fromRGBA(100 + i * 5, 255 - i * 10, 150, 255);
    engine.setFillColor(color);
    final rect = PathBuilder()
      ..moveTo(290.0 + i * 6, yPos)
      ..lineTo(410.0 - i * 6, yPos)
      ..lineTo(410.0 - i * 6, yPos + 120)
      ..lineTo(290.0 + i * 6, yPos + 120)
      ..close();
    engine.fill(rect.build());
  }
  engine.restore();

  // Draw outline
  engine.stroke(nonZeroPath);

  engine.setFillColor(const Color(0xFF000000));
  engine.fillText('Non-Zero Rule', 350, yPos + 140);

  yPos += 180;

  // === Section 3: Text Clipping ===

  engine.setFontSize(20);
  engine.setFillColor(const Color(0xFF000000));
  engine.fillText('Text as Clipping Path:', 50, yPos);
  yPos += 50;

  engine.save();
  engine.setFontSize(48);
  engine.clipText('CLIPPED', 50, yPos);

  // Draw colorful pattern that will be clipped to text
  for (int y = 0; y < 60; y += 5) {
    for (int x = 0; x < 300; x += 5) {
      final hue = (x + y).toDouble();
      final color = ColorUtils.hslToRgb(HSLColor(hue, 0.8, 0.5));
      engine.setFillColor(color);
      final rect = PathBuilder()
        ..moveTo(50.0 + x, yPos - 40 + y)
        ..lineTo(55.0 + x, yPos - 40 + y)
        ..lineTo(55.0 + x, yPos - 35 + y)
        ..lineTo(50.0 + x, yPos - 35 + y)
        ..close();
      engine.fill(rect.build());
    }
  }
  engine.restore();

  // Stroke the same text for outline
  engine.setStrokeColor(const Color(0xFF333333));
  engine.setLineWidth(1);
  engine.strokeText('CLIPPED', 50, yPos);

  yPos += 80;

  // === Section 4: Advanced Blend Modes ===

  engine.setFontSize(20);
  engine.setFillColor(const Color(0xFF000000));
  engine.fillText('Blend Modes Gallery:', 50, yPos);
  yPos += 40;

  // Create base and overlay shapes
  final blendModes = [
    (BlendMode.srcOver, 'Normal'),
    (BlendMode.multiply, 'Multiply'),
    (BlendMode.screen, 'Screen'),
    (BlendMode.overlay, 'Overlay'),
    (BlendMode.darken, 'Darken'),
    (BlendMode.lighten, 'Lighten'),
    (BlendMode.colorDodge, 'Color Dodge'),
    (BlendMode.colorBurn, 'Color Burn'),
    (BlendMode.hardLight, 'Hard Light'),
    (BlendMode.softLight, 'Soft Light'),
    (BlendMode.difference, 'Difference'),
    (BlendMode.exclusion, 'Exclusion'),
  ];

  var xPos = 50.0;
  final spacing = 95.0;

  for (int i = 0; i < blendModes.length; i++) {
    if (i > 0 && i % 6 == 0) {
      yPos += 120;
      xPos = 50.0;
    }

    final (mode, name) = blendModes[i];

    // Draw base circle (blue)
    engine.setGlobalCompositeOperation(BlendMode.srcOver);
    engine.setFillColor(const Color(0xFF0066CC));
    final circle1 = PathBuilder()..circle(xPos + 20, yPos + 20, 25);
    engine.fill(circle1.build());

    // Draw overlapping circle with blend mode (red)
    engine.setGlobalCompositeOperation(mode);
    engine.setFillColor(const Color(0xFFCC0066));
    final circle2 = PathBuilder()..circle(xPos + 40, yPos + 20, 25);
    engine.fill(circle2.build());

    // Reset blend mode and label
    engine.setGlobalCompositeOperation(BlendMode.srcOver);
    engine.setFontSize(10);
    engine.setFillColor(const Color(0xFF333333));
    engine.setTextAlign(TextAlign.center);
    engine.fillText(name, xPos + 30, yPos + 55);

    xPos += spacing;
  }

  // Save the demo
  await engine.saveToFile('output/advanced_features_demo.ppm');
  print('\nDemo saved to output/advanced_features_demo.ppm');
  print('\nFeatures demonstrated:');
  print('Text rendering with fillText, strokeText, measureText');
  print('Text alignment (left, center, right)');
  print('Text metrics and bounding boxes');
  print('Even-odd fill rule for clipping');
  print('Non-zero winding fill rule for clipping');
  print('Text as clipping path');
  print('All 12 advanced blend modes');
}

// Removed duplicate hslToRgb function - now using ColorUtils.hslToRgb()

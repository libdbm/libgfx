import 'dart:io';
import 'dart:math' as math;

import 'package:libgfx/src/image/bitmap.dart';
import 'package:libgfx/src/color/color.dart';
import 'package:libgfx/src/fonts/ttf/ttf_font.dart';
import 'package:libgfx/src/graphics_engine_facade.dart';
import 'package:libgfx/src/matrix.dart';
import 'package:libgfx/src/paint.dart';
import 'package:libgfx/src/paths/path.dart';
import 'package:libgfx/src/utils/transform_utils.dart';

void main() async {
  print('Creating pattern paint demonstration...');

  final engine = GraphicsEngine(1600, 1200);
  engine.clear(const Color(0xFFF5F5F5)); // Off-white background

  // Load font for labels
  TTFFont? font;
  final fontsDir = Directory('data/fonts');
  final fontFiles = fontsDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.ttf'))
      .toList();

  if (fontFiles.isNotEmpty) {
    font = await TTFFont.loadFromFile(fontFiles.first.path);
  }

  var yPos = 40.0;

  // Title
  if (font != null) {
    engine.setFillColor(const Color(0xFF000000));
    final titlePath = font.getTextPath(
      'Pattern Paint Demonstrations',
      50,
      yPos,
      28,
    );
    engine.fill(titlePath);
  }
  yPos += 60;

  // Create various pattern images
  final checkerPattern = createCheckerboardPattern(32, 32);
  final stripePattern = createStripePattern(32, 32);
  final dotPattern = createDotPattern(32, 32);
  final diamondPattern = createDiamondPattern(32, 32);
  final gradientPattern = createGradientPattern(32, 32);

  // Section 1: Basic Pattern Fills
  if (font != null) {
    final sectionPath = font.getTextPath(
      '1. Basic Pattern Fills',
      50,
      yPos,
      18,
    );
    engine.fill(sectionPath);
  }
  yPos += 40;

  var xPos = 100.0;
  final patterns = [
    (checkerPattern, 'Checker'),
    (stripePattern, 'Stripes'),
    (dotPattern, 'Dots'),
    (diamondPattern, 'Diamond'),
    (gradientPattern, 'Gradient'),
  ];

  for (final (pattern, name) in patterns) {
    // Set pattern as fill
    engine.setFillPaint(
      PatternPaint(pattern: pattern, repeat: PatternRepeat.repeat),
    );

    // Draw filled rectangle
    final rectPath = PathBuilder()
      ..moveTo(xPos, yPos)
      ..lineTo(xPos + 120, yPos)
      ..lineTo(xPos + 120, yPos + 80)
      ..lineTo(xPos, yPos + 80)
      ..close();
    engine.fill(rectPath.build());

    // Label
    if (font != null) {
      engine.setFillColor(const Color(0xFF000000));
      final labelPath = font.getTextPath(name, xPos + 30, yPos + 100, 12);
      engine.fill(labelPath);
    }

    xPos += 150;
  }

  yPos += 140;

  // Section 2: Pattern Transformations
  if (font != null) {
    engine.setFillColor(const Color(0xFF000000));
    final sectionPath = font.getTextPath(
      '2. Pattern Transformations',
      50,
      yPos,
      18,
    );
    engine.fill(sectionPath);
  }
  yPos += 40;

  xPos = 100.0;
  final transformTests = [
    ('Normal', Matrix2D.identity()),
    ('Scaled 2x', Matrix2D.scaling(2.0, 2.0)),
    ('Rotated 45°', Matrix2D.rotation(math.pi / 4)),
    ('Skewed', Matrix2D(1.0, 0.3, 0.2, 1.0, 0, 0)),
    ('Complex', TransformUtils.createSRT(1.5, 1.5, math.pi / 6, 0, 0)),
  ];

  for (final (name, transform) in transformTests) {
    // Set pattern with transformation
    engine.setFillPaint(
      PatternPaint(
        pattern: stripePattern,
        repeat: PatternRepeat.repeat,
        transform: transform,
      ),
    );

    // Draw filled circle
    final circlePath = createCirclePath(xPos + 60, yPos + 40, 35);
    engine.fill(circlePath);

    // Label
    if (font != null) {
      engine.setFillColor(const Color(0xFF000000));
      final labelPath = font.getTextPath(name, xPos + 20, yPos + 90, 12);
      engine.fill(labelPath);
    }

    xPos += 140;
  }

  yPos += 120;

  // Section 3: Pattern Repeat Modes
  if (font != null) {
    engine.setFillColor(const Color(0xFF000000));
    final sectionPath = font.getTextPath(
      '3. Pattern Repeat Modes',
      50,
      yPos,
      18,
    );
    engine.fill(sectionPath);
  }
  yPos += 40;

  xPos = 100.0;
  final repeatModes = [
    (PatternRepeat.repeat, 'Repeat'),
    (PatternRepeat.repeatX, 'Repeat X'),
    (PatternRepeat.repeatY, 'Repeat Y'),
    (PatternRepeat.noRepeat, 'No Repeat'),
  ];

  // Create a larger pattern for testing repeat modes
  final largePattern = createLargePattern(64, 64);

  for (final (mode, name) in repeatModes) {
    // Set pattern with repeat mode
    engine.setFillPaint(PatternPaint(pattern: largePattern, repeat: mode));

    // Draw filled rectangle
    final rectPath = PathBuilder()
      ..moveTo(xPos, yPos)
      ..lineTo(xPos + 150, yPos)
      ..lineTo(xPos + 150, yPos + 100)
      ..lineTo(xPos, yPos + 100)
      ..close();
    engine.fill(rectPath.build());

    // Draw border for clarity
    engine.setStrokeColor(const Color(0xFF333333));
    engine.setLineWidth(1);
    engine.stroke(rectPath.build());

    // Label
    if (font != null) {
      engine.setFillColor(const Color(0xFF000000));
      final labelPath = font.getTextPath(name, xPos + 45, yPos + 120, 12);
      engine.fill(labelPath);
    }

    xPos += 180;
  }

  yPos += 160;

  // Section 4: Pattern Opacity
  if (font != null) {
    engine.setFillColor(const Color(0xFF000000));
    final sectionPath = font.getTextPath('4. Pattern Opacity', 50, yPos, 18);
    engine.fill(sectionPath);
  }
  yPos += 40;

  xPos = 100.0;
  final opacities = [0.25, 0.5, 0.75, 1.0];

  for (final opacity in opacities) {
    // Draw background color
    engine.setFillColor(const Color(0xFF4169E1)); // Royal Blue
    final bgPath = PathBuilder()
      ..moveTo(xPos, yPos)
      ..lineTo(xPos + 120, yPos)
      ..lineTo(xPos + 120, yPos + 80)
      ..lineTo(xPos, yPos + 80)
      ..close();
    engine.fill(bgPath.build());

    // Overlay pattern with opacity
    engine.setFillPaint(
      PatternPaint(
        pattern: checkerPattern,
        repeat: PatternRepeat.repeat,
        opacity: opacity,
      ),
    );
    engine.fill(bgPath.build());

    // Label
    if (font != null) {
      engine.setFillColor(const Color(0xFF000000));
      final labelPath = font.getTextPath(
        '${(opacity * 100).toInt()}%',
        xPos + 45,
        yPos + 100,
        12,
      );
      engine.fill(labelPath);
    }

    xPos += 150;
  }

  yPos += 140;

  // Section 5: Complex Shapes with Patterns
  if (font != null) {
    engine.setFillColor(const Color(0xFF000000));
    final sectionPath = font.getTextPath(
      '5. Complex Shapes with Patterns',
      50,
      yPos,
      18,
    );
    engine.fill(sectionPath);
  }
  yPos += 40;

  xPos = 100.0;

  // Star shape with pattern
  engine.setFillPaint(
    PatternPaint(pattern: gradientPattern, repeat: PatternRepeat.repeat),
  );
  final starPath = createStarPath(xPos + 60, yPos + 50, 40, 20, 5);
  engine.fill(starPath);

  xPos += 150;

  // Heart shape with pattern
  engine.setFillPaint(
    PatternPaint(
      pattern: dotPattern,
      repeat: PatternRepeat.repeat,
      transform: Matrix2D.identity()..scale(0.5, 0.5),
    ),
  );
  final heartPath = createHeartPath(xPos + 60, yPos + 50, 40);
  engine.fill(heartPath);

  xPos += 150;

  // Text with pattern fill
  if (font != null) {
    engine.setFillPaint(
      PatternPaint(
        pattern: stripePattern,
        repeat: PatternRepeat.repeat,
        transform: Matrix2D.identity()..rotateZ(-math.pi / 12),
      ),
    );
    final textPath = font.getTextPath('PATTERN', xPos, yPos + 60, 48);
    engine.fill(textPath);
  }

  xPos += 250;

  // Bezier curve with pattern stroke
  engine.setStrokePaint(
    PatternPaint(pattern: diamondPattern, repeat: PatternRepeat.repeat),
  );
  engine.setLineWidth(15);
  final curvePath = PathBuilder()
    ..moveTo(xPos, yPos + 60)
    ..curveTo(xPos + 50, yPos, xPos + 100, yPos + 100, xPos + 150, yPos + 40);
  engine.stroke(curvePath.build());

  await engine.saveToFile('output/pattern_paint_demo.ppm');
  print('\nCreated output/pattern_paint_demo.ppm');

  print('\n🎨 Pattern Paint Features Summary:');
  print('');
  print('PATTERN TYPES');
  print('   • Image-based patterns');
  print('   • Procedural patterns');
  print('   • Tiled textures');
  print('');
  print('TRANSFORMATIONS');
  print('   • Scale patterns independently');
  print('   • Rotate patterns');
  print('   • Skew and shear');
  print('   • Combined transformations');
  print('');
  print('REPEAT MODES');
  print('   • Repeat (tile in both directions)');
  print('   • Repeat X only');
  print('   • Repeat Y only');
  print('   • No repeat (single instance)');
  print('');
  print('COMPOSITING');
  print('   • Pattern opacity control');
  print('   • Blend with underlying colors');
  print('   • Pattern strokes and fills');
  print('');
  print('SHAPE SUPPORT');
  print('   • Fill any path with patterns');
  print('   • Pattern strokes');
  print('   • Text with pattern fills');
  print('   • Complex shapes');
}

// Helper functions to create pattern images

Bitmap createCheckerboardPattern(int width, int height) {
  final image = Bitmap.empty(width, height);
  final cellSize = 8;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final isWhite = ((x ~/ cellSize) + (y ~/ cellSize)) % 2 == 0;
      image.setPixel(
        x,
        y,
        isWhite ? const Color(0xFFFFFFFF) : const Color(0xFF333333),
      );
    }
  }

  return image;
}

Bitmap createStripePattern(int width, int height) {
  final image = Bitmap.empty(width, height);
  final stripeWidth = 4;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final isStripe = (x ~/ stripeWidth) % 2 == 0;
      image.setPixel(
        x,
        y,
        isStripe ? const Color(0xFF2E86AB) : const Color(0xFFA0E7E5),
      );
    }
  }

  return image;
}

Bitmap createDotPattern(int width, int height) {
  final image = Bitmap.empty(width, height);
  final dotSpacing = 8;
  final dotRadius = 2;

  // Fill with background
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      image.setPixel(x, y, const Color(0xFFFFF0F5)); // Lavender blush
    }
  }

  // Add dots
  for (int cy = dotSpacing ~/ 2; cy < height; cy += dotSpacing) {
    for (int cx = dotSpacing ~/ 2; cx < width; cx += dotSpacing) {
      for (int y = cy - dotRadius; y <= cy + dotRadius; y++) {
        for (int x = cx - dotRadius; x <= cx + dotRadius; x++) {
          if (x >= 0 && x < width && y >= 0 && y < height) {
            final dx = x - cx;
            final dy = y - cy;
            if (dx * dx + dy * dy <= dotRadius * dotRadius) {
              image.setPixel(x, y, const Color(0xFFFF69B4)); // Hot pink
            }
          }
        }
      }
    }
  }

  return image;
}

Bitmap createDiamondPattern(int width, int height) {
  final image = Bitmap.empty(width, height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final dx = (x % 16) - 8;
      final dy = (y % 16) - 8;
      final inDiamond = dx.abs() + dy.abs() <= 6;

      image.setPixel(
        x,
        y,
        inDiamond
            ? const Color(0xFF4B0082) // Indigo
            : const Color(0xFFE6E6FA),
      ); // Lavender
    }
  }

  return image;
}

Bitmap createGradientPattern(int width, int height) {
  final image = Bitmap.empty(width, height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final t = (x + y) / (width + height);
      final r = (255 * (1 - t)).round();
      final g = (100 + 155 * t).round();
      final b = (255 * t).round();
      image.setPixel(x, y, Color.fromRGBA(r, g, b, 255));
    }
  }

  return image;
}

Bitmap createLargePattern(int width, int height) {
  final image = Bitmap.empty(width, height);

  // Create a pattern with distinct quadrants to show repeat behavior
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      Color color;

      if (x < width ~/ 2 && y < height ~/ 2) {
        // Top-left: Red
        color = const Color(0xFFFF6B6B);
      } else if (x >= width ~/ 2 && y < height ~/ 2) {
        // Top-right: Blue
        color = const Color(0xFF4ECDC4);
      } else if (x < width ~/ 2 && y >= height ~/ 2) {
        // Bottom-left: Green
        color = const Color(0xFF95E77E);
      } else {
        // Bottom-right: Yellow
        color = const Color(0xFFFFE66D);
      }

      // Add some texture
      final noise = ((x + y) % 3) * 10;
      final r = (color.red - noise).clamp(0, 255);
      final g = (color.green - noise).clamp(0, 255);
      final b = (color.blue - noise).clamp(0, 255);

      image.setPixel(x, y, Color.fromRGBA(r, g, b, 255));
    }
  }

  return image;
}

Path createCirclePath(double cx, double cy, double radius) {
  final builder = PathBuilder();
  const segments = 64;

  for (int i = 0; i <= segments; i++) {
    final angle = (i * 2 * math.pi) / segments;
    final x = cx + radius * math.cos(angle);
    final y = cy + radius * math.sin(angle);

    if (i == 0) {
      builder.moveTo(x, y);
    } else {
      builder.lineTo(x, y);
    }
  }

  builder.close();
  return builder.build();
}

Path createStarPath(
  double cx,
  double cy,
  double outerRadius,
  double innerRadius,
  int points,
) {
  final builder = PathBuilder();
  final angleStep = math.pi / points;

  for (int i = 0; i < points * 2; i++) {
    final angle = i * angleStep - math.pi / 2;
    final radius = i % 2 == 0 ? outerRadius : innerRadius;
    final x = cx + radius * math.cos(angle);
    final y = cy + radius * math.sin(angle);

    if (i == 0) {
      builder.moveTo(x, y);
    } else {
      builder.lineTo(x, y);
    }
  }

  builder.close();
  return builder.build();
}

Path createHeartPath(double cx, double cy, double size) {
  final builder = PathBuilder();

  // Heart shape using cubic bezier curves
  builder.moveTo(cx, cy + size * 0.3);

  // Left side of heart
  builder.curveTo(
    cx - size * 0.5,
    cy,
    cx - size,
    cy - size * 0.3,
    cx - size,
    cy - size * 0.5,
  );

  builder.curveTo(
    cx - size,
    cy - size * 0.8,
    cx - size * 0.5,
    cy - size,
    cx,
    cy - size * 0.5,
  );

  // Right side of heart
  builder.curveTo(
    cx + size * 0.5,
    cy - size,
    cx + size,
    cy - size * 0.8,
    cx + size,
    cy - size * 0.5,
  );

  builder.curveTo(
    cx + size,
    cy - size * 0.3,
    cx + size * 0.5,
    cy,
    cx,
    cy + size * 0.3,
  );

  builder.close();
  return builder.build();
}

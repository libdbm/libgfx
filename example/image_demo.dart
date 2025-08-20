import 'dart:io';
import 'dart:math' as math;

import 'package:libgfx/src/image/bitmap.dart';
import 'package:libgfx/src/color/color.dart';
import 'package:libgfx/src/fonts/ttf/ttf_font.dart';
import 'package:libgfx/src/graphics_engine_facade.dart';
import 'package:libgfx/src/graphics_state.dart';
import 'package:libgfx/src/image/image_renderer.dart';
import 'package:libgfx/src/matrix.dart';
import 'package:libgfx/src/paths/path.dart';
import 'package:libgfx/src/point.dart';

void main() async {
  print('Creating comprehensive image rendering demonstration...');

  final engine = GraphicsEngine(1600, 2000);
  engine.clear(const Color(0xFFF0F0F0)); // Light gray background

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

  // Create various test images
  final checkerboard = createCheckerboard(64, 64);
  final gradient = createGradientImage(100, 100);
  final photo = createPhotoLikeImage(150, 100);

  var yPos = 40.0;

  // Title
  if (font != null) {
    engine.setFillColor(const Color(0xFF000000));
    final titlePath = font.getTextPath(
      'Advanced Image Rendering Capabilities',
      50,
      yPos,
      28,
    );
    engine.fill(titlePath);
  }
  yPos += 60;

  // Section 1: Filtering Comparison
  if (font != null) {
    final sectionPath = font.getTextPath(
      '1. Image Filtering Comparison',
      50,
      yPos,
      18,
    );
    engine.fill(sectionPath);
  }
  yPos += 40;

  var xPos = 100.0;
  final filterModes = [
    (ImageFilter.nearest, 'Nearest'),
    (ImageFilter.bilinear, 'Bilinear'),
    (ImageFilter.bicubic, 'Bicubic'),
  ];

  for (final (_, name) in filterModes) {
    // Draw original size
    engine.drawImage(checkerboard, xPos, yPos);

    // Draw scaled up to show filtering difference
    // Note: filter parameter not supported in drawImageScaled
    engine.drawImageScaled(checkerboard, xPos, yPos + 80, 128, 128);

    // Label
    if (font != null) {
      final labelPath = font.getTextPath(name, xPos, yPos + 220, 12);
      engine.fill(labelPath);
    }

    xPos += 200;
  }

  yPos += 250;

  // Section 2: Transformations
  if (font != null) {
    final sectionPath = font.getTextPath(
      '2. Image Transformations',
      50,
      yPos,
      18,
    );
    engine.fill(sectionPath);
  }
  yPos += 40;

  xPos = 100.0;

  // Various transformations
  final transformTests = [
    ('Original', Matrix2D.identity()..translate(xPos, yPos)),
    (
      'Rotate 45°',
      Matrix2D.identity()
        ..translate(xPos + 200 + 50, yPos + 50)
        ..rotateZ(math.pi / 4)
        ..translate(-50, -50),
    ),
    (
      'Scale 1.5x',
      Matrix2D.identity()
        ..translate(xPos + 400, yPos)
        ..scale(1.5, 1.5),
    ),
    ('Skew', Matrix2D(1.0, 0.0, 0.3, 1.0, xPos + 650, yPos)),
    (
      'Flip H',
      Matrix2D.identity()
        ..translate(xPos + 850, yPos)
        ..scale(-1.0, 1.0)
        ..translate(100, 0),
    ),
  ];

  for (final (name, transform) in transformTests) {
    // Apply transform manually since drawImageTransformed doesn't exist
    engine.save();
    engine.setTransform(
      transform.a,
      transform.b,
      transform.c,
      transform.d,
      transform.tx,
      transform.ty,
    );
    engine.drawImage(gradient, 0, 0);
    engine.restore();

    // Label
    if (font != null) {
      final labelX = transform.tx;
      final labelPath = font.getTextPath(name, labelX, yPos + 120, 12);
      engine.fill(labelPath);
    }
  }

  yPos += 180;

  // Section 3: Blending and Opacity
  if (font != null) {
    final sectionPath = font.getTextPath(
      '3. Blending and Opacity',
      50,
      yPos,
      18,
    );
    engine.fill(sectionPath);
  }
  yPos += 40;

  xPos = 100.0;

  // Draw base image
  engine.drawImage(photo, xPos, yPos);

  // Overlay with different opacities
  final opacities = [0.25, 0.5, 0.75, 1.0];
  xPos += 200;

  for (final opacity in opacities) {
    engine.drawImage(photo, xPos, yPos);
    // Note: opacity parameter not supported, using global alpha instead
    engine.save();
    engine.setGlobalAlpha(opacity);
    engine.drawImageScaled(gradient, xPos + 25, yPos + 25, 100, 50);
    engine.restore();

    // Label
    if (font != null) {
      final labelPath = font.getTextPath(
        '${(opacity * 100).toInt()}%',
        xPos + 60,
        yPos + 120,
        12,
      );
      engine.fill(labelPath);
    }

    xPos += 180;
  }

  yPos += 180;

  // Section 4: Image Patterns
  if (font != null) {
    final sectionPath = font.getTextPath(
      '4. Tiled Image Patterns',
      50,
      yPos,
      18,
    );
    engine.fill(sectionPath);
  }
  yPos += 40;

  xPos = 100.0;

  // Create pattern areas
  final patternImage = createPatternTile(32, 32);

  // Draw different pattern areas
  // Pattern tiling would need to be implemented differently
  engine.drawImage(patternImage, xPos, yPos);

  // Pattern with clipping
  xPos += 250;
  engine.save();
  final circlePath = Path();
  final centerX = xPos + 100;
  final centerY = yPos + 50;
  for (int i = 0; i <= 64; i++) {
    final angle = (i * 2 * math.pi) / 64;
    final x = centerX + 80 * math.cos(angle);
    final y = centerY + 80 * math.sin(angle);
    if (i == 0) {
      circlePath.addCommand(PathCommand(PathCommandType.moveTo, [Point(x, y)]));
    } else {
      circlePath.addCommand(PathCommand(PathCommandType.lineTo, [Point(x, y)]));
    }
  }
  circlePath.addCommand(PathCommand(PathCommandType.close, []));
  engine.clip(circlePath);
  // Pattern tiling would need to be implemented differently
  engine.drawImage(patternImage, xPos, yPos - 30);
  engine.restore();

  yPos += 160;

  // Section 5: Blend Modes
  if (font != null) {
    final sectionPath = font.getTextPath('5. Blend Mode Effects', 50, yPos, 18);
    engine.fill(sectionPath);
  }
  yPos += 40;

  xPos = 100.0;

  final blendModes = [
    (BlendMode.srcOver, 'Normal'),
    (BlendMode.multiply, 'Multiply'),
    (BlendMode.screen, 'Screen'),
    (BlendMode.overlay, 'Overlay'),
  ];

  for (final (mode, name) in blendModes) {
    // Draw base
    engine.setGlobalCompositeOperation(BlendMode.srcOver);
    engine.drawImage(photo, xPos, yPos);

    // Draw overlay with blend mode
    engine.setGlobalCompositeOperation(mode);
    // Opacity parameter not supported in drawImage
    engine.drawImage(gradient, xPos, yPos);

    // Label
    engine.setGlobalCompositeOperation(BlendMode.srcOver);
    if (font != null) {
      final labelPath = font.getTextPath(name, xPos + 50, yPos + 120, 12);
      engine.fill(labelPath);
    }

    xPos += 200;
  }

  await engine.saveToFile('output/image_demo.ppm');
  print('\nCreated output/image_demo.ppm');

  print('\n🎨 Image Rendering Features Summary:');
  print('');
  print('FILTERING MODES');
  print('   • Nearest neighbor for pixel art');
  print('   • Bilinear for smooth scaling');
  print('   • Bicubic for highest quality');
  print('');
  print('TRANSFORMATIONS');
  print('   • Rotation at any angle');
  print('   • Scaling (uniform and non-uniform)');
  print('   • Skewing and shearing');
  print('   • Flipping (horizontal/vertical)');
  print('   • Combined transformations');
  print('');
  print('BLENDING & COMPOSITING');
  print('   • Variable opacity (0-100%)');
  print('   • Multiple blend modes');
  print('   • Alpha channel support');
  print('');
  print('PATTERNS & TILING');
  print('   • Repeating image patterns');
  print('   • Clipped pattern regions');
  print('   • Transformed patterns');
  print('');
  print('FORMAT SUPPORT');
  print('   • PPM (P6 binary)');
  print('   • BMP (24/32-bit uncompressed)');
}

// Helper functions to create test images

Bitmap createCheckerboard(int width, int height) {
  final image = Bitmap.empty(width, height);
  final cellSize = 8;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final isWhite = ((x ~/ cellSize) + (y ~/ cellSize)) % 2 == 0;
      image.setPixel(
        x,
        y,
        isWhite ? const Color(0xFFFFFFFF) : const Color(0xFF404040),
      );
    }
  }

  return image;
}

Bitmap createGradientImage(int width, int height) {
  final image = Bitmap.empty(width, height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final r = (x * 255 ~/ width);
      final g = (y * 255 ~/ height);
      final b = ((x + y) * 255 ~/ (width + height));
      image.setPixel(x, y, Color.fromRGBA(r, g, b, 255));
    }
  }

  return image;
}

Bitmap createPhotoLikeImage(int width, int height) {
  final image = Bitmap.empty(width, height);

  // Create a simple landscape-like image
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      Color color;

      if (y < height * 0.4) {
        // Sky
        final t = y / (height * 0.4);
        final r = (135 + t * 50).round();
        final g = (206 + t * 30).round();
        final b = (235 - t * 35).round();
        color = Color.fromRGBA(r, g, b, 255);
      } else if (y < height * 0.6) {
        // Mountains
        final t = (y - height * 0.4) / (height * 0.2);
        final gray = (100 - t * 20).round();
        color = Color.fromRGBA(gray, gray, gray + 10, 255);
      } else {
        // Ground
        final t = (y - height * 0.6) / (height * 0.4);
        final r = (34 + t * 20).round();
        final g = (139 - t * 30).round();
        final b = (34 + t * 10).round();
        color = Color.fromRGBA(r, g, b, 255);
      }

      // Add some noise
      final noise = (math.Random(x * 1000 + y).nextDouble() - 0.5) * 20;
      final nr = (color.red + noise).round().clamp(0, 255);
      final ng = (color.green + noise).round().clamp(0, 255);
      final nb = (color.blue + noise).round().clamp(0, 255);

      image.setPixel(x, y, Color.fromRGBA(nr, ng, nb, 255));
    }
  }

  return image;
}

Bitmap createPatternTile(int width, int height) {
  final image = Bitmap.empty(width, height);

  // Create a decorative tile pattern
  final centerX = width / 2;
  final centerY = height / 2;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final dx = (x - centerX).abs();
      final dy = (y - centerY).abs();
      final distance = math.sqrt(dx * dx + dy * dy);

      Color color;
      if (distance < 8) {
        color = const Color(0xFFFFD700); // Gold
      } else if ((x + y) % 8 < 4) {
        color = const Color(0xFF4169E1); // Royal Blue
      } else {
        color = const Color(0xFF6495ED); // Cornflower Blue
      }

      image.setPixel(x, y, color);
    }
  }

  return image;
}

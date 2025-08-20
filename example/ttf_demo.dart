import 'dart:io';
import 'dart:math' as math;

import 'package:libgfx/src/color/color.dart';
import 'package:libgfx/src/fonts/ttf/ttf_font.dart';
import 'package:libgfx/src/graphics_engine_facade.dart';
import 'package:libgfx/src/paths/path.dart';

void main() async {
  print('TTF Font Rendering Demo');
  print('=======================');

  // Load all available fonts
  final fontsDir = Directory('data/fonts');
  final fontFiles = fontsDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.ttf'))
      .toList();

  if (fontFiles.isEmpty) {
    print('No TTF fonts found in data/fonts directory');
    return;
  }

  print('Found ${fontFiles.length} fonts:');
  for (final file in fontFiles) {
    print('  - ${file.path.split('/').last}');
  }

  final fonts = <TTFFont>[];
  for (final fontFile in fontFiles) {
    try {
      final font = await TTFFont.loadFromFile(fontFile.path);
      fonts.add(font);
      print('Loaded: ${font.familyName} ${font.styleName}');
    } catch (e) {
      print('Failed to load ${fontFile.path}: $e');
    }
  }

  if (fonts.isEmpty) {
    print('No fonts could be loaded successfully');
    return;
  }

  // Create various demos
  await createFontShowcaseDemo(fonts);
  await createTypographyDemo(fonts);
  await createSizesDemo(fonts);
  await createMetricsDemo(fonts);
  await createKerningDemo(fonts);

  print('\nDemo images created successfully!');
}

Future<void> createFontShowcaseDemo(List<TTFFont> fonts) async {
  final engine = GraphicsEngine(1200, 800);
  engine.clear(const Color(0xFF2C3E50)); // Dark blue background

  // Title
  engine.setFillColor(const Color(0xFFFFFFFF));
  if (fonts.isNotEmpty) {
    final titlePath = fonts.first.getTextPath('Font Showcase', 50, 80, 36);
    engine.fill(titlePath);
  }

  // Draw a line under title
  engine.setStrokeColor(const Color(0xFFE74C3C));
  engine.setLineWidth(3);
  final underline = PathBuilder()
    ..moveTo(50, 100)
    ..lineTo(600, 100);
  engine.stroke(underline.build());

  // Display each font
  double y = 150;
  final testText = 'The quick brown fox jumps over the lazy dog';
  final colors = [
    const Color(0xFFE74C3C), // Red
    const Color(0xFF3498DB), // Blue
    const Color(0xFF2ECC71), // Green
    const Color(0xFFF39C12), // Orange
    const Color(0xFF9B59B6), // Purple
  ];

  for (int i = 0; i < fonts.length && i < colors.length; i++) {
    final font = fonts[i];
    final color = colors[i % colors.length];

    engine.setFillColor(color);

    // Font name
    final fontNamePath = font.getTextPath(
      '${font.familyName} ${font.styleName}',
      50,
      y,
      18,
    );
    engine.fill(fontNamePath);

    // Sample text
    final textPath = font.getTextPath(testText, 50, y + 40, 16);
    engine.fill(textPath);

    // Font info
    engine.setFillColor(const Color(0xFFBDC3C7)); // Light gray
    final infoText =
        'Units/Em: ${font.unitsPerEm} | Ascender: ${font.metrics.ascender} | Descender: ${font.metrics.descender}';
    if (fonts.isNotEmpty) {
      final infoPath = fonts.first.getTextPath(infoText, 50, y + 65, 12);
      engine.fill(infoPath);
    }

    y += 120;
  }

  await engine.saveToFile('output/ttf_showcase.ppm');
  print('Created output/ttf_showcase.ppm');
}

Future<void> createTypographyDemo(List<TTFFont> fonts) async {
  if (fonts.isEmpty) return;

  final engine = GraphicsEngine(800, 1000);
  engine.clear(const Color(0xFFF8F9FA)); // Light background

  final font = fonts.first;

  // Title
  engine.setFillColor(const Color(0xFF212529));
  final title = font.getTextPath('Typography Samples', 50, 80, 32);
  engine.fill(title);

  double y = 150;

  // Heading styles
  final headingTexts = [
    ('Heading 1', 28.0),
    ('Heading 2', 24.0),
    ('Heading 3', 20.0),
    ('Body Text', 16.0),
    ('Small Text', 12.0),
  ];

  for (final (text, size) in headingTexts) {
    engine.setFillColor(const Color(0xFF495057));
    final path = font.getTextPath(text, 50, y, size);
    engine.fill(path);
    y += size + 10;
  }

  y += 30;

  // Paragraph text
  final paragraphLines = [
    'This is a sample paragraph demonstrating text rendering',
    'with the TTF font system. The text should flow naturally',
    'and maintain consistent spacing between lines.',
    '',
    'Multiple paragraphs can be rendered by calculating',
    'appropriate line heights and vertical spacing.',
    'Font metrics help ensure proper text layout.',
  ];

  engine.setFillColor(const Color(0xFF212529));
  for (final line in paragraphLines) {
    if (line.isNotEmpty) {
      final path = font.getTextPath(line, 50, y, 14);
      engine.fill(path);
    }
    y += 20; // Line height
  }

  y += 40;

  // Different styles if we have multiple fonts
  if (fonts.length > 1) {
    final regularFont = fonts.firstWhere(
      (f) => f.styleName.toLowerCase().contains('regular'),
      orElse: () => fonts.first,
    );
    final italicFont = fonts
        .where((f) => f.styleName.toLowerCase().contains('italic'))
        .firstOrNull;
    final lightFont = fonts
        .where((f) => f.styleName.toLowerCase().contains('light'))
        .firstOrNull;

    engine.setFillColor(const Color(0xFF6C757D));
    final styleTitle = regularFont.getTextPath('Font Styles:', 50, y, 18);
    engine.fill(styleTitle);
    y += 30;

    engine.setFillColor(const Color(0xFF212529));
    final regularText = regularFont.getTextPath(
      'Regular: Standard font weight',
      50,
      y,
      16,
    );
    engine.fill(regularText);
    y += 25;

    if (italicFont != null) {
      final italicText = italicFont.getTextPath(
        'Italic: Slanted text style',
        50,
        y,
        16,
      );
      engine.fill(italicText);
      y += 25;
    }

    if (lightFont != null) {
      final lightText = lightFont.getTextPath(
        'Light: Thinner font weight',
        50,
        y,
        16,
      );
      engine.fill(lightText);
      y += 25;
    }
  }

  await engine.saveToFile('output/ttf_typography.ppm');
  print('Created output/ttf_typography.ppm');
}

Future<void> createSizesDemo(List<TTFFont> fonts) async {
  if (fonts.isEmpty) return;

  final engine = GraphicsEngine(1000, 600);
  engine.clear(const Color(0xFFFFFFFF));

  final font = fonts.first;
  final testText = 'Size Test';

  // Title
  engine.setFillColor(const Color(0xFF333333));
  final title = font.getTextPath('Font Size Variations', 50, 60, 24);
  engine.fill(title);

  // Different sizes
  final sizes = [8.0, 12.0, 16.0, 20.0, 24.0, 32.0, 48.0, 64.0, 96.0];
  double y = 120;

  for (final size in sizes) {
    engine.setFillColor(const Color(0xFF444444));

    // Size label
    final label = font.getTextPath('${size.toInt()}pt', 50, y, 12);
    engine.fill(label);

    // Sample text at that size
    final path = font.getTextPath(testText, 120, y, size);
    engine.fill(path);

    // Measure the text
    final metrics = font.measureText(testText, size);
    final infoText =
        '(${metrics.width.toStringAsFixed(1)}×${metrics.height.toStringAsFixed(1)}px)';
    final info = font.getTextPath(infoText, 120 + metrics.width + 20, y, 10);
    engine.setFillColor(const Color(0xFF888888));
    engine.fill(info);

    y += math.max(size + 10, 25);
  }

  await engine.saveToFile('output/ttf_sizes.ppm');
  print('Created output/ttf_sizes.ppm');
}

Future<void> createMetricsDemo(List<TTFFont> fonts) async {
  if (fonts.isEmpty) return;

  final engine = GraphicsEngine(800, 600);
  engine.clear(const Color(0xFFF5F5F5));

  final font = fonts.first;
  final fontSize = 48.0;
  final testText = 'Typography';

  // Title
  engine.setFillColor(const Color(0xFF333333));
  final title = font.getTextPath('Font Metrics Visualization', 50, 60, 20);
  engine.fill(title);

  // Position text
  final textX = 100.0;
  final textY = 200.0;

  // Render the text
  engine.setFillColor(const Color(0xFF2C3E50));
  final textPath = font.getTextPath(testText, textX, textY, fontSize);
  engine.fill(textPath);

  // Get font metrics
  final fontMetrics = font.metrics.scale(fontSize, font.unitsPerEm);
  final textMetrics = font.measureText(testText, fontSize);

  // Draw baseline
  engine.setStrokeColor(const Color(0xFFE74C3C)); // Red
  engine.setLineWidth(2);
  final baseline = PathBuilder()
    ..moveTo(textX - 20, textY)
    ..lineTo(textX + textMetrics.width + 20, textY);
  engine.stroke(baseline.build());

  // Draw ascender line
  engine.setStrokeColor(const Color(0xFF3498DB)); // Blue
  engine.setLineWidth(1);
  final ascenderY = textY - fontMetrics.ascender;
  final ascenderLine = PathBuilder()
    ..moveTo(textX - 20, ascenderY)
    ..lineTo(textX + textMetrics.width + 20, ascenderY);
  engine.stroke(ascenderLine.build());

  // Draw descender line
  engine.setStrokeColor(const Color(0xFF2ECC71)); // Green
  final descenderY = textY - fontMetrics.descender;
  final descenderLine = PathBuilder()
    ..moveTo(textX - 20, descenderY)
    ..lineTo(textX + textMetrics.width + 20, descenderY);
  engine.stroke(descenderLine.build());

  // Draw text width indicator
  engine.setStrokeColor(const Color(0xFF9B59B6)); // Purple
  final widthLine = PathBuilder()
    ..moveTo(textX, textY + 30)
    ..lineTo(textX + textMetrics.width, textY + 30);
  engine.stroke(widthLine.build());

  // Labels
  engine.setFillColor(const Color(0xFF666666));
  final labels = [
    (
      'Baseline',
      textX + textMetrics.width + 30,
      textY,
      const Color(0xFFE74C3C),
    ),
    (
      'Ascender',
      textX + textMetrics.width + 30,
      ascenderY,
      const Color(0xFF3498DB),
    ),
    (
      'Descender',
      textX + textMetrics.width + 30,
      descenderY,
      const Color(0xFF2ECC71),
    ),
    (
      'Width',
      textX + textMetrics.width / 2,
      textY + 50,
      const Color(0xFF9B59B6),
    ),
  ];

  for (final (label, x, y, color) in labels) {
    engine.setFillColor(color);
    final labelPath = font.getTextPath(label, x, y, 12);
    engine.fill(labelPath);
  }

  // Metrics info
  double infoY = 350;
  engine.setFillColor(const Color(0xFF333333));
  final metricsInfo = [
    'Font Metrics (${fontSize.toInt()}pt):',
    'Ascender: ${fontMetrics.ascender.toInt()}px',
    'Descender: ${fontMetrics.descender.toInt()}px',
    'Line Gap: ${fontMetrics.lineGap.toInt()}px',
    'Line Height: ${fontMetrics.lineHeight.toInt()}px',
    '',
    'Text Metrics:',
    'Width: ${textMetrics.width.toStringAsFixed(1)}px',
    'Height: ${textMetrics.height.toStringAsFixed(1)}px',
    'Ascent: ${textMetrics.ascent.toStringAsFixed(1)}px',
    'Descent: ${textMetrics.descent.toStringAsFixed(1)}px',
  ];

  for (final info in metricsInfo) {
    if (info.isNotEmpty) {
      final infoPath = font.getTextPath(info, 50, infoY, 14);
      engine.fill(infoPath);
    }
    infoY += 18;
  }

  await engine.saveToFile('output/ttf_metrics.ppm');
  print('Created output/ttf_metrics.ppm');
}

Future<void> createKerningDemo(List<TTFFont> fonts) async {
  if (fonts.isEmpty) return;

  final engine = GraphicsEngine(800, 500);
  engine.clear(const Color(0xFFFFFFFF));

  final font = fonts.first;
  final fontSize = 36.0;

  // Title
  engine.setFillColor(const Color(0xFF333333));
  final title = font.getTextPath('Kerning Demonstration', 50, 60, 20);
  engine.fill(title);

  // Test kerning pairs
  final kerningPairs = ['AV', 'To', 'We', 'Yo', 'VA', 'LT'];
  double y = 120;

  for (final pair in kerningPairs) {
    // Check if font supports these characters
    final char1 = pair.codeUnitAt(0);
    final char2 = pair.codeUnitAt(1);

    if (font.hasGlyph(char1) && font.hasGlyph(char2)) {
      // Without kerning - manual spacing
      engine.setFillColor(const Color(0xFF666666));
      final label1 = font.getTextPath('No kerning:', 50, y, 14);
      engine.fill(label1);

      final glyph1Index = font.getGlyphIndex(char1);
      final glyph2Index = font.getGlyphIndex(char2);

      final glyph1Metrics = font.getGlyphMetrics(glyph1Index);
      final scale = fontSize / font.unitsPerEm;

      engine.setFillColor(const Color(0xFF333333));
      final char1Path = font.getTextPath(pair[0], 200, y, fontSize);
      engine.fill(char1Path);

      final char2Path = font.getTextPath(
        pair[1],
        200 + glyph1Metrics.advanceWidth * scale,
        y,
        fontSize,
      );
      engine.fill(char2Path);

      y += 50;

      // With kerning - using font's kerning
      engine.setFillColor(const Color(0xFF666666));
      final label2 = font.getTextPath('With kerning:', 50, y, 14);
      engine.fill(label2);

      engine.setFillColor(const Color(0xFF333333));
      final kernedPath = font.getTextPath(pair, 200, y, fontSize);
      engine.fill(kernedPath);

      // Show kerning value
      final kerning = font.getKerning(glyph1Index, glyph2Index, fontSize);
      if (kerning != 0.0) {
        engine.setFillColor(const Color(0xFF2ECC71));
        final kernValue = font.getTextPath(
          'Kerning: ${kerning.toStringAsFixed(1)}px',
          350,
          y,
          12,
        );
        engine.fill(kernValue);
      } else {
        engine.setFillColor(const Color(0xFF95A5A6));
        final noKern = font.getTextPath('No kerning data', 350, y, 12);
        engine.fill(noKern);
      }

      y += 60;
    }
  }

  await engine.saveToFile('output/ttf_kerning.ppm');
  print('Created output/ttf_kerning.ppm');
}

import 'dart:io';
import 'dart:math' as math;

import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

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
    print('No TTF fonts found in data/fonts; run ./scripts/download_fonts.sh');
    return;
  }

  print('Found ${fontFiles.length} fonts:');
  for (final file in fontFiles) {
    print('  - ${file.path.split('/').last}');
  }

  const filesystem = LocalGraphicsFileSystem();

  final fonts = <TTFFont>[];
  for (final fontFile in fontFiles) {
    switch (await TTFFont.load(fontFile.path, filesystem: filesystem)) {
      case Ok(:final value):
        fonts.add(value);
        print('Loaded: ${value.family} ${value.style}');
      case Err(:final error):
        print('Failed to load ${fontFile.path}: $error');
    }
  }

  if (fonts.isEmpty) {
    print('No fonts could be loaded successfully');
    return;
  }

  // Create various demos
  await createFontShowcaseDemo(fonts, filesystem);
  await createTypographyDemo(fonts, filesystem);
  await createSizesDemo(fonts, filesystem);
  await createMetricsDemo(fonts, filesystem);
  await createKerningDemo(fonts, filesystem);

  print('\nDemo images created successfully!');
}

Future<void> createFontShowcaseDemo(
  List<TTFFont> fonts,
  GraphicsFileSystem filesystem,
) async {
  // Drawn at twice the size, for high-DPI screens; the drawing below is in
  // page units
  final engine = GraphicsEngine(2 * 1200, 2 * 800, filesystem: filesystem)
    ..scale(2, 2);
  engine.clear(const Color(0xFF2C3E50)); // Dark blue background

  // Title
  engine.fillStyle = const Color(0xFFFFFFFF);
  if (fonts.isNotEmpty) {
    final titlePath = fonts.first.path('Font Showcase', 50, 80, 36);
    engine.fill(titlePath, text: true);
  }

  // Draw a line under title
  engine.strokeStyle = const Color(0xFFE74C3C);
  engine.lineWidth = 3;
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

    engine.fillStyle = color;

    // Font name
    final fontNamePath = font.path('${font.family} ${font.style}', 50, y, 18);
    engine.fill(fontNamePath, text: true);

    // Sample text
    final textPath = font.path(testText, 50, y + 40, 16);
    engine.fill(textPath, text: true);

    // Font info
    engine.fillStyle = const Color(0xFFBDC3C7); // Light gray
    final infoText =
        'Units/Em: ${font.unitsPerEm} | Ascender: ${font.metrics.ascender} | Descender: ${font.metrics.descender}';
    if (fonts.isNotEmpty) {
      final infoPath = fonts.first.path(infoText, 50, y + 65, 12);
      engine.fill(infoPath, text: true);
    }

    y += 120;
  }

  await engine.write('output/ttf_showcase.ppm');
  print('Created output/ttf_showcase.ppm');
}

Future<void> createTypographyDemo(
  List<TTFFont> fonts,
  GraphicsFileSystem filesystem,
) async {
  if (fonts.isEmpty) return;

  // Drawn at twice the size, for high-DPI screens; the drawing below is in

  // page units

  final engine = GraphicsEngine(2 * 800, 2 * 1000, filesystem: filesystem)
    ..scale(2, 2);
  engine.clear(const Color(0xFFF8F9FA)); // Light background

  final font = fonts.first;

  // Title
  engine.fillStyle = const Color(0xFF212529);
  final title = font.path('Typography Samples', 50, 80, 32);
  engine.fill(title, text: true);

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
    engine.fillStyle = const Color(0xFF495057);
    final path = font.path(text, 50, y, size);
    engine.fill(path, text: true);
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

  engine.fillStyle = const Color(0xFF212529);
  for (final line in paragraphLines) {
    if (line.isNotEmpty) {
      final path = font.path(line, 50, y, 14);
      engine.fill(path, text: true);
    }
    y += 20; // Line height
  }

  y += 40;

  // Different styles if we have multiple fonts
  if (fonts.length > 1) {
    final regularFont = fonts.firstWhere(
      (f) => f.style.toLowerCase().contains('regular'),
      orElse: () => fonts.first,
    );
    final italicFont = fonts
        .where((f) => f.style.toLowerCase().contains('italic'))
        .firstOrNull;
    final lightFont = fonts
        .where((f) => f.style.toLowerCase().contains('light'))
        .firstOrNull;

    engine.fillStyle = const Color(0xFF6C757D);
    final styleTitle = regularFont.path('Font Styles:', 50, y, 18);
    engine.fill(styleTitle, text: true);
    y += 30;

    engine.fillStyle = const Color(0xFF212529);
    final regularText = regularFont.path(
      'Regular: Standard font weight',
      50,
      y,
      16,
    );
    engine.fill(regularText, text: true);
    y += 25;

    if (italicFont != null) {
      final italicText = italicFont.path(
        'Italic: Slanted text style',
        50,
        y,
        16,
      );
      engine.fill(italicText, text: true);
      y += 25;
    }

    if (lightFont != null) {
      final lightText = lightFont.path('Light: Thinner font weight', 50, y, 16);
      engine.fill(lightText, text: true);
      y += 25;
    }
  }

  await engine.write('output/ttf_typography.ppm');
  print('Created output/ttf_typography.ppm');
}

Future<void> createSizesDemo(
  List<TTFFont> fonts,
  GraphicsFileSystem filesystem,
) async {
  if (fonts.isEmpty) return;

  // Drawn at twice the size, for high-DPI screens; the drawing below is in

  // page units

  final engine = GraphicsEngine(2 * 1000, 2 * 600, filesystem: filesystem)
    ..scale(2, 2);
  engine.clear(const Color(0xFFFFFFFF));

  final font = fonts.first;
  final testText = 'Size Test';

  // Title
  engine.fillStyle = const Color(0xFF333333);
  final title = font.path('Font Size Variations', 50, 60, 24);
  engine.fill(title, text: true);

  // Different sizes
  final sizes = [8.0, 12.0, 16.0, 20.0, 24.0, 32.0, 48.0, 64.0, 96.0];
  double y = 120;

  for (final size in sizes) {
    engine.fillStyle = const Color(0xFF444444);

    // Size label
    final label = font.path('${size.toInt()}pt', 50, y, 12);
    engine.fill(label, text: true);

    // Sample text at that size
    final path = font.path(testText, 120, y, size);
    engine.fill(path, text: true);

    // Measure the text
    final metrics = font.measure(testText, size);
    final infoText =
        '(${metrics.width.toStringAsFixed(1)}×${metrics.height.toStringAsFixed(1)}px)';
    final info = font.path(infoText, 120 + metrics.width + 20, y, 10);
    engine.fillStyle = const Color(0xFF888888);
    engine.fill(info, text: true);

    y += math.max(size + 10, 25);
  }

  await engine.write('output/ttf_sizes.ppm');
  print('Created output/ttf_sizes.ppm');
}

Future<void> createMetricsDemo(
  List<TTFFont> fonts,
  GraphicsFileSystem filesystem,
) async {
  if (fonts.isEmpty) return;

  // Drawn at twice the size, for high-DPI screens; the drawing below is in

  // page units

  final engine = GraphicsEngine(2 * 800, 2 * 600, filesystem: filesystem)
    ..scale(2, 2);
  engine.clear(const Color(0xFFF5F5F5));

  final font = fonts.first;
  final fontSize = 48.0;
  final testText = 'Typography';

  // Title
  engine.fillStyle = const Color(0xFF333333);
  final title = font.path('Font Metrics Visualization', 50, 60, 20);
  engine.fill(title, text: true);

  // Position text
  final textX = 100.0;
  final textY = 200.0;

  // Render the text
  engine.fillStyle = const Color(0xFF2C3E50);
  final textPath = font.path(testText, textX, textY, fontSize);
  engine.fill(textPath, text: true);

  // Get font metrics
  final fontMetrics = font.metrics.scale(fontSize, font.unitsPerEm);
  final textMetrics = font.measure(testText, fontSize);

  // Draw baseline
  engine.strokeStyle = const Color(0xFFE74C3C); // Red
  engine.lineWidth = 2;
  final baseline = PathBuilder()
    ..moveTo(textX - 20, textY)
    ..lineTo(textX + textMetrics.width + 20, textY);
  engine.stroke(baseline.build());

  // Draw ascender line
  engine.strokeStyle = const Color(0xFF3498DB); // Blue
  engine.lineWidth = 1;
  final ascenderY = textY - fontMetrics.ascender;
  final ascenderLine = PathBuilder()
    ..moveTo(textX - 20, ascenderY)
    ..lineTo(textX + textMetrics.width + 20, ascenderY);
  engine.stroke(ascenderLine.build());

  // Draw descender line
  engine.strokeStyle = const Color(0xFF2ECC71); // Green
  final descenderY = textY - fontMetrics.descender;
  final descenderLine = PathBuilder()
    ..moveTo(textX - 20, descenderY)
    ..lineTo(textX + textMetrics.width + 20, descenderY);
  engine.stroke(descenderLine.build());

  // Draw text width indicator
  engine.strokeStyle = const Color(0xFF9B59B6); // Purple
  final widthLine = PathBuilder()
    ..moveTo(textX, textY + 30)
    ..lineTo(textX + textMetrics.width, textY + 30);
  engine.stroke(widthLine.build());

  // Labels
  engine.fillStyle = const Color(0xFF666666);
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
    engine.fillStyle = color;
    final labelPath = font.path(label, x, y, 12);
    engine.fill(labelPath, text: true);
  }

  // Metrics info
  double infoY = 350;
  engine.fillStyle = const Color(0xFF333333);
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
      final infoPath = font.path(info, 50, infoY, 14);
      engine.fill(infoPath, text: true);
    }
    infoY += 18;
  }

  await engine.write('output/ttf_metrics.ppm');
  print('Created output/ttf_metrics.ppm');
}

Future<void> createKerningDemo(
  List<TTFFont> fonts,
  GraphicsFileSystem filesystem,
) async {
  if (fonts.isEmpty) return;

  // Drawn at twice the size, for high-DPI screens; the drawing below is in

  // page units

  final engine = GraphicsEngine(2 * 800, 2 * 500, filesystem: filesystem)
    ..scale(2, 2);
  engine.clear(const Color(0xFFFFFFFF));

  final font = fonts.first;
  final fontSize = 36.0;

  // Title
  engine.fillStyle = const Color(0xFF333333);
  final title = font.path('Kerning Demonstration', 50, 60, 20);
  engine.fill(title, text: true);

  // Test kerning pairs
  final kerningPairs = ['AV', 'To', 'We', 'Yo', 'VA', 'LT'];
  double y = 120;

  for (final pair in kerningPairs) {
    // Check if font supports these characters
    final char1 = pair.codeUnitAt(0);
    final char2 = pair.codeUnitAt(1);

    if (font.covers(char1) && font.covers(char2)) {
      // Without kerning - manual spacing
      engine.fillStyle = const Color(0xFF666666);
      final label1 = font.path('No kerning:', 50, y, 14);
      engine.fill(label1, text: true);

      final glyph1Index = font.glyph(char1);
      final glyph2Index = font.glyph(char2);

      final glyph1Metrics = font.dimensions(glyph1Index);
      final scale = fontSize / font.unitsPerEm;

      engine.fillStyle = const Color(0xFF333333);
      final char1Path = font.path(pair[0], 200, y, fontSize);
      engine.fill(char1Path, text: true);

      final char2Path = font.path(
        pair[1],
        200 + glyph1Metrics.advanceWidth * scale,
        y,
        fontSize,
      );
      engine.fill(char2Path, text: true);

      y += 50;

      // With kerning - using font's kerning
      engine.fillStyle = const Color(0xFF666666);
      final label2 = font.path('With kerning:', 50, y, 14);
      engine.fill(label2, text: true);

      engine.fillStyle = const Color(0xFF333333);
      final kernedPath = font.path(pair, 200, y, fontSize);
      engine.fill(kernedPath, text: true);

      // Show kerning value
      final kerning = font.kerning(glyph1Index, glyph2Index, fontSize);
      if (kerning != 0.0) {
        engine.fillStyle = const Color(0xFF2ECC71);
        final kernValue = font.path(
          'Kerning: ${kerning.toStringAsFixed(1)}px',
          350,
          y,
          12,
        );
        engine.fill(kernValue, text: true);
      } else {
        engine.fillStyle = const Color(0xFF95A5A6);
        final noKern = font.path('No kerning data', 350, y, 12);
        engine.fill(noKern, text: true);
      }

      y += 60;
    }
  }

  await engine.write('output/ttf_kerning.ppm');
  print('Created output/ttf_kerning.ppm');
}

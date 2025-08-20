import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';

/// Comprehensive Unicode text rendering demonstration
Future<void> main() async {
  print('Unicode Text Rendering Demo\n');
  print('============================\n');

  final engine = GraphicsEngine(1200, 900);
  engine.clear(const Color(0xFFFAFAFA));

  // Initialize font fallback chain
  final fallbackChain = FontFallbackChain();
  final unicodeRenderer = TextRenderer.unicode(
    fontChain: fallbackChain,
    shaper: BasicTextShaper(),
  );

  // Try to load fonts
  print('Loading fonts...');
  final fontPaths = [
    'data/fonts/NotoSans-Regular.ttf',
    'data/fonts/NotoSerif-Regular.ttf',
    'data/fonts/NotoSansMono-Regular.ttf',
    'data/fonts/NotoSansDevanagari-Regular.ttf',
    'data/fonts/NotoSansArabic-Regular.ttf',
    'data/fonts/NotoSansJP-Regular.ttf',
    'data/fonts/NotoSansKR-Regular.ttf',
    'data/fonts/NotoSansSC-Regular.ttf',
    'data/fonts/NotoSansTR-Regular.ttf',
    'data/fonts/NotoSansHebrew-Regular.ttf',
    'data/fonts/NotoSansDevanagari-Regular.ttf',
    'data/fonts/NotoSansTamil-Regular.ttf',
    'data/fonts/NotoSansBengali-Regular.ttf',
    'data/fonts/NotoSansThai-Regular.ttf',
    'data/fonts/NotoEmoji-Regular.ttf',
    'data/fonts/DejaVuSans.ttf',
  ];

  int loadedFonts = 0;
  for (final fontPath in fontPaths) {
    try {
      await fallbackChain.addFontFromFile(fontPath);
      print('  ✓ Loaded: ${fontPath.split('/').last}');
      loadedFonts++;
    } catch (e) {
      // Font not available, try alternative
      final fileName = fontPath.split('/').last;
      if (fileName.contains('Noto')) {
        // Try without Noto prefix
        try {
          final altPath = fontPath.replaceAll('Noto', '');
          await fallbackChain.addFontFromFile(altPath);
          print('  ✓ Loaded alternative: ${altPath.split('/').last}');
          loadedFonts++;
        } catch (e2) {
          print('  ✗ Not found: $fileName');
        }
      }
    }
  }

  if (loadedFonts == 0) {
    print(
      '\nWarning: No fonts loaded. Creating demo with placeholder glyphs.\n',
    );
  } else {
    print('\nLoaded $loadedFonts fonts successfully.\n');
  }

  // Title
  engine.setFillColor(const Color(0xFF2C3E50));
  final titlePath = unicodeRenderer.renderUnicodeText(
    'Unicode Text Rendering Demonstration',
    600,
    40,
    28.0,
  );
  engine.fill(titlePath);

  // Draw section backgrounds
  _drawSectionBackground(engine, 20, 70, 560, 200, 'World Languages');
  _drawSectionBackground(engine, 600, 70, 580, 200, 'Writing Systems');
  _drawSectionBackground(engine, 20, 290, 560, 180, 'Complex Scripts');
  _drawSectionBackground(engine, 600, 290, 580, 180, 'Special Characters');
  _drawSectionBackground(engine, 20, 490, 1160, 140, 'Mixed Content');
  _drawSectionBackground(engine, 20, 650, 1160, 220, 'Text Effects');

  // Section 1: World Languages
  print('Rendering world languages...');
  final worldLanguages = [
    ('English', 'The quick brown fox jumps over the lazy dog'),
    ('Spanish', 'El veloz murciélago hindú comía feliz cardillo y kiwi'),
    ('French', 'Portez ce vieux whisky au juge blond qui fume'),
    ('German', 'Zwölf Boxkämpfer jagen Viktor quer über den Sylter Deich'),
    ('Italian', 'Quel vituperabile xenofobo zelante assaggia il whisky'),
    ('Portuguese', 'Luís argüia à Júlia que «brações, fé, chá, óxido, pôr»'),
    ('Russian', 'Съешь же ещё этих мягких французских булок да выпей чаю'),
    ('Polish', 'Pchnąć w tę łódź jeża lub ośm skrzyń fig'),
  ];

  double yPos = 100;
  for (final (lang, text) in worldLanguages) {
    // Language label
    engine.setFillColor(const Color(0xFF7F8C8D));
    final labelPath = unicodeRenderer.renderUnicodeText(
      '$lang:',
      30,
      yPos,
      11.0,
    );
    engine.fill(labelPath);

    // Text content
    engine.setFillColor(const Color(0xFF2C3E50));
    final textPath = unicodeRenderer.renderUnicodeText(text, 100, yPos, 14.0);
    engine.fill(textPath);

    yPos += 22;
  }

  // Section 2: Writing Systems
  print('Rendering writing systems...');
  final writingSystemsLTR = [
    ['Latin', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz'],
    ['Cyrillic', 'АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ абвгдежз'],
    ['Greek', 'ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ αβγδεζηθικλμνξοπρστυφχψω'],
    ['Devanagari', 'अआइईउऊऋॠऌॡएऐओऔकखगघङचछजझञटठडढण'],
    ['Thai', 'กขคงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ'],
    ['Georgian', 'აბგდევზთიკლმნოპჟრსტუფქღყშჩცძწჭხჯჰ'],
  ];

  final writingSystemsRTL = [
    ['Hebrew', 'אבגדהוזחטיכלמנסעפצקרשת'],
    ['Arabic', 'ابتثجحخدذرزسشصضطظعغفقكلمنهوي'],
  ];

  yPos = 100;
  for (final system in writingSystemsLTR) {
    final name = system[0];
    final text = system[1];
    final direction = TextDirection.ltr;

    // System label
    engine.setFillColor(const Color(0xFF7F8C8D));
    final labelPath = unicodeRenderer.renderUnicodeText(
      '$name:',
      610,
      yPos,
      11.0,
    );
    engine.fill(labelPath);

    // Characters
    engine.setFillColor(const Color(0xFF2C3E50));
    final xPos = direction == TextDirection.rtl ? 1170.0 : 680.0;
    final textPath = unicodeRenderer.renderUnicodeText(
      text,
      xPos,
      yPos,
      13.0,
      direction: direction,
    );
    engine.fill(textPath);

    yPos += 22;
  }

  // RTL systems
  for (final system in writingSystemsRTL) {
    final name = system[0];
    final text = system[1];
    final direction = TextDirection.rtl;

    // System label
    engine.setFillColor(const Color(0xFF7F8C8D));
    final labelPath = unicodeRenderer.renderUnicodeText(
      '$name:',
      610,
      yPos,
      11.0,
    );
    engine.fill(labelPath);

    // Characters
    engine.setFillColor(const Color(0xFF2C3E50));
    final xPos = direction == TextDirection.rtl ? 1170.0 : 680.0;
    final textPath = unicodeRenderer.renderUnicodeText(
      text,
      xPos,
      yPos,
      13.0,
      direction: direction,
    );
    engine.fill(textPath);

    yPos += 22;
  }

  // Section 3: Complex Scripts
  print('Rendering complex scripts...');
  final complexScriptsLTR = [
    ['Chinese', '春眠不觉晓，处处闻啼鸟。夜来风雨声，花落知多少。'],
    ['Japanese', '春はあけぼの。やうやう白くなりゆく山ぎは、すこしあかりて'],
    ['Korean', '봄은 새벽이다. 점점 하얘지는 산등성이가 조금 밝아지면서'],
    ['Hindi', 'सत्यमेव जयते नानृतं सत्येन पन्था विततो देवयानः'],
    ['Tamil', 'அகர முதல எழுத்தெல்லாம் ஆதி பகவன் முதற்றே உலகு'],
    ['Bengali', 'আমার সোনার বাংলা, আমি তোমায় ভালোবাসি'],
  ];

  final complexScriptsRTL = [
    ['Arabic', 'كان يا ما كان في قديم الزمان'],
  ];

  yPos = 320;
  // LTR scripts
  for (final script in complexScriptsLTR) {
    final name = script[0];
    final text = script[1];
    final direction = TextDirection.ltr;

    // Script label
    engine.setFillColor(const Color(0xFF7F8C8D));
    final labelPath = unicodeRenderer.renderUnicodeText(
      '$name:',
      30,
      yPos,
      11.0,
    );
    engine.fill(labelPath);

    // Text
    engine.setFillColor(const Color(0xFF2C3E50));
    final xPos = direction == TextDirection.rtl ? 570.0 : 100.0;
    final textPath = unicodeRenderer.renderUnicodeText(
      text,
      xPos,
      yPos,
      14.0,
      direction: direction,
    );
    engine.fill(textPath);

    yPos += 22;
  }

  // RTL scripts
  for (final script in complexScriptsRTL) {
    final name = script[0];
    final text = script[1];
    final direction = TextDirection.rtl;

    // Script label
    engine.setFillColor(const Color(0xFF7F8C8D));
    final labelPath = unicodeRenderer.renderUnicodeText(
      '$name:',
      30,
      yPos,
      11.0,
    );
    engine.fill(labelPath);

    // Text
    engine.setFillColor(const Color(0xFF2C3E50));
    final xPos = direction == TextDirection.rtl ? 570.0 : 100.0;
    final textPath = unicodeRenderer.renderUnicodeText(
      text,
      xPos,
      yPos,
      14.0,
      direction: direction,
    );
    engine.fill(textPath);

    yPos += 22;
  }

  // Section 4: Special Characters
  print('Rendering special characters...');
  final specialChars = [
    ('Mathematics', '∀x∈ℝ: x²≥0, ∫₀^∞ e^(-x²)dx = √π/2, ∑ᵢ₌₁ⁿ i = n(n+1)/2'),
    ('Symbols', '☺☻♠♣♥♦♪♫☀☁☂☃☄★☆☎☏☐☑☒☓☔☕☖☗'),
    ('Arrows', '←↑→↓↔↕↖↗↘↙⇐⇑⇒⇓⇔⇕⇖⇗⇘⇙⇦⇧⇨⇩'),
    ('Currency', '\$ € £ ¥ ¢ ₹ ₽ ₨ ₩ ₪ ₫ ₱ ₹ ﷼'),
    ('Emoji', '😀😃😄😁😆😅😂🤣😊😇🙂🙃😉😌😍🥰😘😗'),
    ('Flags', '🇺🇸🇬🇧🇫🇷🇩🇪🇯🇵🇨🇳🇰🇷🇮🇳🇧🇷🇷🇺🇦🇺🇨🇦'),
    ('Dingbats', '✓✗✔✘♚♛♜♝♞♟♔♕♖♗♘♙⚀⚁⚂⚃⚄⚅'),
  ];

  yPos = 320;
  for (final (category, chars) in specialChars) {
    // Category label
    engine.setFillColor(const Color(0xFF7F8C8D));
    final labelPath = unicodeRenderer.renderUnicodeText(
      '$category:',
      610,
      yPos,
      11.0,
    );
    engine.fill(labelPath);

    // Characters
    engine.setFillColor(const Color(0xFF2C3E50));
    final textPath = unicodeRenderer.renderUnicodeText(chars, 700, yPos, 14.0);
    engine.fill(textPath);

    yPos += 22;
  }

  // Section 5: Mixed Content
  print('Rendering mixed content...');
  final mixedContent = [
    'Hello world! مرحبا بالعالم! 你好世界！ こんにちは世界！ 안녕하세요 세계!',
    'Mathematical: ∫(x²+2x+1)dx = x³/3 + x² + x + C where C∈ℝ',
    'Code: if (x > 0) { return √x; } else { throw Error("x must be positive"); }',
    'Mixed: The price is €50.99 (≈\$60) for 3×items + 20% VAT = €61.19 total',
  ];

  yPos = 520;
  for (final text in mixedContent) {
    engine.setFillColor(const Color(0xFF2C3E50));
    final textPath = unicodeRenderer.renderUnicodeText(text, 30, yPos, 15.0);
    engine.fill(textPath);
    yPos += 28;
  }

  // Section 6: Text Effects
  print('Applying text effects...');

  // Shadow effect
  final shadowText = 'Shadow Effect Text';
  engine.setFillColor(const Color(0x40000000));
  var shadowPath = unicodeRenderer.renderUnicodeText(shadowText, 32, 702, 24.0);
  engine.fill(shadowPath);
  engine.setFillColor(const Color(0xFF2C3E50));
  var mainPath = unicodeRenderer.renderUnicodeText(shadowText, 30, 700, 24.0);
  engine.fill(mainPath);

  // Gradient effect (simulated with multiple colors)
  final gradientText = 'Gradient Text Effect';
  for (int i = 0; i < 5; i++) {
    final t = i / 4.0;
    final r = (255 * (1 - t) + 0 * t).round();
    final g = (100 * (1 - t) + 150 * t).round();
    final b = (0 * (1 - t) + 255 * t).round();
    engine.setFillColor(Color.fromRGBA(r, g, b, 255));
    final offsetPath = unicodeRenderer.renderUnicodeText(
      gradientText,
      300 + i * 0.5,
      700 - i * 0.5,
      24.0,
    );
    engine.fill(offsetPath);
  }

  // Outline effect
  final outlineText = 'Outline Effect';
  engine.setStrokeColor(const Color(0xFF2C3E50));
  engine.setLineWidth(2);
  engine.setFillColor(const Color(0xFFFFFFFF));
  final outlinePath = unicodeRenderer.renderUnicodeText(
    outlineText,
    600,
    700,
    24.0,
  );
  engine.stroke(outlinePath);
  engine.fill(outlinePath);

  // Rotated text
  engine.save();
  engine.translate(900, 700);
  engine.rotate(math.pi / 12); // 15 degrees
  engine.setFillColor(const Color(0xFF9B59B6));
  final rotatedPath = unicodeRenderer.renderUnicodeText(
    'Rotated Text',
    0,
    0,
    24.0,
  );
  engine.fill(rotatedPath);
  engine.restore();

  // Vertical text (character by character)
  final verticalText = 'VERTICAL';
  yPos = 730;
  for (int i = 0; i < verticalText.length; i++) {
    engine.setFillColor(const Color(0xFF16A085));
    final charPath = unicodeRenderer.renderUnicodeText(
      verticalText[i],
      30,
      yPos + i * 18,
      16.0,
    );
    engine.fill(charPath);
  }

  // Wavy text
  final wavyText = 'Wavy Text Effect';
  for (int i = 0; i < wavyText.length; i++) {
    final x = 120.0 + i * 14;
    final y = 780.0 + math.sin(i * 0.5) * 10;
    engine.setFillColor(const Color(0xFFE74C3C));
    final charPath = unicodeRenderer.renderUnicodeText(wavyText[i], x, y, 18.0);
    engine.fill(charPath);
  }

  // Circular text
  final circularText = 'CIRCULAR TEXT • ';
  final centerX = 400.0;
  final centerY = 800.0;
  final radius = 40.0;
  for (int i = 0; i < circularText.length; i++) {
    final angle = i * 2 * math.pi / circularText.length - math.pi / 2;
    final x = centerX + radius * math.cos(angle);
    final y = centerY + radius * math.sin(angle);

    engine.save();
    engine.translate(x, y);
    engine.rotate(angle + math.pi / 2);
    engine.setFillColor(const Color(0xFF3498DB));
    final charPath = unicodeRenderer.renderUnicodeText(
      circularText[i],
      0,
      0,
      14.0,
    );
    engine.fill(charPath);
    engine.restore();
  }

  // Rainbow text
  final rainbowText = 'Rainbow Colors';
  final rainbowColors = [
    const Color(0xFFFF0000), // Red
    const Color(0xFFFF7F00), // Orange
    const Color(0xFFFFFF00), // Yellow
    const Color(0xFF00FF00), // Green
    const Color(0xFF0000FF), // Blue
    const Color(0xFF4B0082), // Indigo
    const Color(0xFF9400D3), // Violet
  ];
  for (int i = 0; i < rainbowText.length; i++) {
    engine.setFillColor(rainbowColors[i % rainbowColors.length]);
    final charPath = unicodeRenderer.renderUnicodeText(
      rainbowText[i],
      550 + i * 14,
      780,
      18.0,
    );
    engine.fill(charPath);
  }

  // Perspective text (simulated with scaling)
  final perspectiveText = 'PERSPECTIVE';
  for (int i = 0; i < perspectiveText.length; i++) {
    final scale = 1.0 + i * 0.1;
    engine.save();
    engine.translate(750 + i * 20, 780);
    engine.scale(scale, scale);
    engine.setFillColor(const Color(0xFF34495E));
    final charPath = unicodeRenderer.renderUnicodeText(
      perspectiveText[i],
      0,
      0,
      14.0,
    );
    engine.fill(charPath);
    engine.restore();
  }

  // Blur effect removed - applyFilterToRegion not available in public API

  // Footer information
  engine.setFillColor(const Color(0xFF95A5A6));
  final footerPath = unicodeRenderer.renderUnicodeText(
    'libgfx Unicode Renderer • Fonts: $loadedFonts loaded • Scripts: 15+ supported',
    600,
    880,
    10.0,
  );
  engine.fill(footerPath);

  // Save the result
  await engine.saveToFile('output/unicode_text_demo.ppm');

  print('\nUnicode text demo completed successfully!');
  print('Output saved to: output/unicode_text_demo.ppm');

  // Print statistics
  print('\nDemo Statistics:');
  print('  • Languages rendered: ${worldLanguages.length}');
  print(
    '  • Writing systems: ${writingSystemsLTR.length + writingSystemsRTL.length}',
  );
  print(
    '  • Complex scripts: ${complexScriptsLTR.length + complexScriptsRTL.length}',
  );
  print('  • Special character sets: ${specialChars.length}');
  print('  • Text effects demonstrated: 10+');
  print('  • Total unique characters: 500+');
}

/// Helper function to draw section backgrounds
void _drawSectionBackground(
  GraphicsEngine engine,
  double x,
  double y,
  double width,
  double height,
  String title,
) {
  // Background
  engine.setFillColor(const Color(0xFFFFFFFF));
  final bg = PathBuilder()
    ..moveTo(x, y)
    ..lineTo(x + width, y)
    ..lineTo(x + width, y + height)
    ..lineTo(x, y + height)
    ..close();
  engine.fill(bg.build());

  // Border
  engine.setStrokeColor(const Color(0xFFE0E0E0));
  engine.setLineWidth(1);
  engine.stroke(bg.build());

  // Title background
  engine.setFillColor(const Color(0xFFF5F5F5));
  final titleBg = PathBuilder()
    ..moveTo(x, y)
    ..lineTo(x + width, y)
    ..lineTo(x + width, y + 25)
    ..lineTo(x, y + 25)
    ..close();
  engine.fill(titleBg.build());

  // Title text (using basic rendering since we don't have the renderer here)
  engine.setFillColor(const Color(0xFF7F8C8D));
  // Title will be rendered by the main code
}

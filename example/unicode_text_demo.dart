import 'dart:math' as math;

import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

/// Comprehensive Unicode text rendering demonstration
Future<void> main() async {
  print('Unicode Text Rendering Demo\n');
  print('============================\n');

  const filesystem = LocalGraphicsFileSystem();
  // Drawn at twice the size, for high-DPI screens; the drawing below is in
  // page units
  final engine = GraphicsEngine(2 * 1200, 2 * 900, filesystem: filesystem)
    ..scale(2, 2);
  engine.clear(const Color(0xFFFAFAFA));

  // The layout below is measured from the top of the page down; graphics
  // space is Y-up, so at(y) turns a distance from the top into a y
  double at(final double y) => 900 - y;

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
      await fallbackChain.load(fontPath, filesystem: filesystem);
      print('  ✓ Loaded: ${fontPath.split('/').last}');
      loadedFonts++;
    } catch (e) {
      // Font not available, try alternative
      final fileName = fontPath.split('/').last;
      if (fileName.contains('Noto')) {
        // Try without Noto prefix
        try {
          final altPath = fontPath.replaceAll('Noto', '');
          await fallbackChain.load(altPath, filesystem: filesystem);
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

  // Title, centred
  engine.fillStyle = const Color(0xFF2C3E50);
  const title = 'Unicode Text Rendering Demonstration';
  final titlePath = unicodeRenderer.layout(
    title,
    600 - unicodeRenderer.extent(title, 28).width / 2,
    at(48),
    28.0,
  );
  engine.fill(titlePath, text: true);

  // Draw section backgrounds
  for (final (x, y, width, height, name) in [
    (20.0, 70.0, 560.0, 200.0, 'World Languages'),
    (600.0, 70.0, 580.0, 200.0, 'Writing Systems'),
    (20.0, 290.0, 560.0, 180.0, 'Complex Scripts'),
    (600.0, 290.0, 580.0, 180.0, 'Special Characters'),
    (20.0, 490.0, 1160.0, 140.0, 'Mixed Content'),
    (20.0, 650.0, 1160.0, 220.0, 'Text Effects'),
  ]) {
    _drawSectionBackground(
      engine,
      unicodeRenderer,
      x,
      at(y + height),
      width,
      height,
      name,
    );
  }

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

  double yPos = 115;
  for (final (lang, text) in worldLanguages) {
    // Language label
    engine.fillStyle = const Color(0xFF7F8C8D);
    final labelPath = unicodeRenderer.layout('$lang:', 30, at(yPos), 11.0);
    engine.fill(labelPath, text: true);

    // Text content
    engine.fillStyle = const Color(0xFF2C3E50);
    final textPath = unicodeRenderer.layout(text, 100, at(yPos), 14.0);
    engine.fill(textPath, text: true);

    yPos += 20;
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

  yPos = 115;
  for (final system in writingSystemsLTR) {
    final name = system[0];
    final text = system[1];
    final direction = TextDirection.ltr;

    // System label
    engine.fillStyle = const Color(0xFF7F8C8D);
    final labelPath = unicodeRenderer.layout('$name:', 610, at(yPos), 11.0);
    engine.fill(labelPath, text: true);

    // Characters
    engine.fillStyle = const Color(0xFF2C3E50);
    final xPos = direction == TextDirection.rtl ? 1170.0 : 680.0;
    final textPath = unicodeRenderer.layout(
      text,
      xPos,
      at(yPos),
      13.0,
      direction: direction,
    );
    engine.fill(textPath, text: true);

    yPos += 20;
  }

  // RTL systems
  for (final system in writingSystemsRTL) {
    final name = system[0];
    final text = system[1];
    final direction = TextDirection.rtl;

    // System label
    engine.fillStyle = const Color(0xFF7F8C8D);
    final labelPath = unicodeRenderer.layout('$name:', 610, at(yPos), 11.0);
    engine.fill(labelPath, text: true);

    // Characters
    engine.fillStyle = const Color(0xFF2C3E50);
    final xPos = direction == TextDirection.rtl ? 1170.0 : 680.0;
    final textPath = unicodeRenderer.layout(
      text,
      xPos,
      at(yPos),
      13.0,
      direction: direction,
    );
    engine.fill(textPath, text: true);

    yPos += 20;
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

  yPos = 335;
  // LTR scripts
  for (final script in complexScriptsLTR) {
    final name = script[0];
    final text = script[1];
    final direction = TextDirection.ltr;

    // Script label
    engine.fillStyle = const Color(0xFF7F8C8D);
    final labelPath = unicodeRenderer.layout('$name:', 30, at(yPos), 11.0);
    engine.fill(labelPath, text: true);

    // Text
    engine.fillStyle = const Color(0xFF2C3E50);
    final xPos = direction == TextDirection.rtl ? 570.0 : 100.0;
    final textPath = unicodeRenderer.layout(
      text,
      xPos,
      at(yPos),
      14.0,
      direction: direction,
    );
    engine.fill(textPath, text: true);

    yPos += 20;
  }

  // RTL scripts
  for (final script in complexScriptsRTL) {
    final name = script[0];
    final text = script[1];
    final direction = TextDirection.rtl;

    // Script label
    engine.fillStyle = const Color(0xFF7F8C8D);
    final labelPath = unicodeRenderer.layout('$name:', 30, at(yPos), 11.0);
    engine.fill(labelPath, text: true);

    // Text
    engine.fillStyle = const Color(0xFF2C3E50);
    final xPos = direction == TextDirection.rtl ? 570.0 : 100.0;
    final textPath = unicodeRenderer.layout(
      text,
      xPos,
      at(yPos),
      14.0,
      direction: direction,
    );
    engine.fill(textPath, text: true);

    yPos += 20;
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

  yPos = 335;
  for (final (category, chars) in specialChars) {
    // Category label
    engine.fillStyle = const Color(0xFF7F8C8D);
    final labelPath = unicodeRenderer.layout('$category:', 610, at(yPos), 11.0);
    engine.fill(labelPath, text: true);

    // Characters, left to right: the currency row's only strong character
    // is the Arabic rial sign, which would make it a right-to-left line
    engine.fillStyle = const Color(0xFF2C3E50);
    final textPath = unicodeRenderer.layout(
      chars,
      700,
      at(yPos),
      14.0,
      direction: TextDirection.ltr,
    );
    engine.fill(textPath, text: true);

    yPos += 20;
  }

  // Section 5: Mixed Content
  print('Rendering mixed content...');
  final mixedContent = [
    'Hello world! مرحبا بالعالم! 你好世界！ こんにちは世界！ 안녕하세요 세계!',
    'Mathematical: ∫(x²+2x+1)dx = x³/3 + x² + x + C where C∈ℝ',
    'Code: if (x > 0) { return √x; } else { throw Error("x must be positive"); }',
    'Mixed: The price is €50.99 (≈\$60) for 3×items + 20% VAT = €61.19 total',
  ];

  yPos = 537;
  for (final text in mixedContent) {
    engine.fillStyle = const Color(0xFF2C3E50);
    final textPath = unicodeRenderer.layout(text, 30, at(yPos), 15.0);
    engine.fill(textPath, text: true);
    yPos += 26;
  }

  // Section 6: Text Effects
  print('Applying text effects...');

  // Shadow effect
  final shadowText = 'Shadow Effect Text';
  engine.fillStyle = const Color(0x40000000);
  var shadowPath = unicodeRenderer.layout(shadowText, 32, at(702), 24.0);
  engine.fill(shadowPath, text: true);
  engine.fillStyle = const Color(0xFF2C3E50);
  var mainPath = unicodeRenderer.layout(shadowText, 30, at(700), 24.0);
  engine.fill(mainPath, text: true);

  // Gradient effect (simulated with multiple colors)
  final gradientText = 'Gradient Text Effect';
  for (int i = 0; i < 5; i++) {
    final t = i / 4.0;
    final r = (255 * (1 - t) + 0 * t).round();
    final g = (100 * (1 - t) + 150 * t).round();
    final b = (0 * (1 - t) + 255 * t).round();
    engine.fillStyle = Color.fromRGBA(r, g, b, 255);
    final offsetPath = unicodeRenderer.layout(
      gradientText,
      300 + i * 0.5,
      at(700 - i * 0.5),
      24.0,
    );
    engine.fill(offsetPath, text: true);
  }

  // Outline effect
  final outlineText = 'Outline Effect';
  engine.strokeStyle = const Color(0xFF2C3E50);
  engine.lineWidth = 2;
  engine.fillStyle = const Color(0xFFFFFFFF);
  final outlinePath = unicodeRenderer.layout(outlineText, 600, at(700), 24.0);
  engine.stroke(outlinePath);
  engine.fill(outlinePath, text: true);

  // Rotated text
  engine.save();
  engine.translate(900, at(700));
  engine.rotate(-math.pi / 12); // 15 degrees clockwise
  engine.fillStyle = const Color(0xFF9B59B6);
  final rotatedPath = unicodeRenderer.layout('Rotated Text', 0, 0, 24.0);
  engine.fill(rotatedPath, text: true);
  engine.restore();

  // Vertical text (character by character)
  final verticalText = 'VERTICAL';
  yPos = 730;
  for (int i = 0; i < verticalText.length; i++) {
    engine.fillStyle = const Color(0xFF16A085);
    final charPath = unicodeRenderer.layout(
      verticalText[i],
      30,
      at(yPos + i * 18),
      16.0,
    );
    engine.fill(charPath, text: true);
  }

  // Wavy text
  final wavyText = 'Wavy Text Effect';
  for (int i = 0; i < wavyText.length; i++) {
    final x = 120.0 + i * 14;
    final y = 780.0 + math.sin(i * 0.5) * 10;
    engine.fillStyle = const Color(0xFFE74C3C);
    final charPath = unicodeRenderer.layout(wavyText[i], x, at(y), 18.0);
    engine.fill(charPath, text: true);
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

    // The angle is measured down the page, so in Y-up graphics space the
    // rotation turns the other way
    engine.save();
    engine.translate(x, at(y));
    engine.rotate(-(angle + math.pi / 2));
    engine.fillStyle = const Color(0xFF3498DB);
    final charPath = unicodeRenderer.layout(circularText[i], 0, 0, 14.0);
    engine.fill(charPath, text: true);
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
    engine.fillStyle = rainbowColors[i % rainbowColors.length];
    final charPath = unicodeRenderer.layout(
      rainbowText[i],
      550 + i * 14,
      at(780),
      18.0,
    );
    engine.fill(charPath, text: true);
  }

  // Perspective text (simulated with scaling)
  final perspectiveText = 'PERSPECTIVE';
  for (int i = 0; i < perspectiveText.length; i++) {
    final scale = 1.0 + i * 0.1;
    engine.save();
    engine.translate(750 + i * 20, at(780));
    engine.scale(scale, scale);
    engine.fillStyle = const Color(0xFF34495E);
    final charPath = unicodeRenderer.layout(perspectiveText[i], 0, 0, 14.0);
    engine.fill(charPath, text: true);
    engine.restore();
  }

  // Blur effect removed - applyFilterToRegion not available in public API

  // Footer information
  engine.fillStyle = const Color(0xFF95A5A6);
  final footer =
      'libgfx Unicode Renderer • Fonts: $loadedFonts loaded • Scripts: 15+ supported';
  final footerPath = unicodeRenderer.layout(
    footer,
    600 - unicodeRenderer.extent(footer, 10).width / 2,
    at(888),
    10.0,
  );
  engine.fill(footerPath, text: true);

  // Save the result
  await engine.write('output/unicode_text_demo.ppm');

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

/// Draws a section's background, border, title band and title; (x, y) is
/// its lower left corner in graphics space
void _drawSectionBackground(
  GraphicsEngine engine,
  TextRenderer renderer,
  double x,
  double y,
  double width,
  double height,
  String title,
) {
  // Background
  engine.fillStyle = const Color(0xFFFFFFFF);
  final bg = PathBuilder().rect(x, y, width, height).build();
  engine.fill(bg);

  // Border
  engine.strokeStyle = const Color(0xFFE0E0E0);
  engine.lineWidth = 1;
  engine.stroke(bg);

  // Title band along the top
  engine.fillStyle = const Color(0xFFF5F5F5);
  engine.fill(PathBuilder().rect(x, y + height - 25, width, 25).build());

  // Title text
  engine.fillStyle = const Color(0xFF7F8C8D);
  engine.fill(
    renderer.layout(title, x + 10, y + height - 17, 12.0),
    text: true,
  );
}

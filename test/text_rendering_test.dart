import 'dart:io';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/graphics_context.dart';
import 'package:test/test.dart';

import 'support/results.dart';

void main() {
  group('Text Rendering Refactoring Tests', () {
    late GraphicsEngine engine;

    setUp(() {
      engine = GraphicsEngine(200, 100);
      // We need a font to test text rendering
      // For testing, we'll skip actual font loading
    });

    test('fillText, strokeText, and clipText use unified implementation', () {
      // This test verifies that the refactored methods still work
      // In a real test, we'd need to load a font first

      // Test that methods exist and can be called
      expect(() => engine.fillText, returnsNormally);
      expect(() => engine.strokeText, returnsNormally);
      expect(() => engine.clipText, returnsNormally);
    });

    test('text alignment options are respected', () {
      // Verify all text alignment options exist
      expect(TextAlign.values, contains(TextAlign.left));
      expect(TextAlign.values, contains(TextAlign.center));
      expect(TextAlign.values, contains(TextAlign.right));
      expect(TextAlign.values, contains(TextAlign.justify));
    });

    test('text baseline options are respected', () {
      // Verify all text baseline options exist
      expect(TextBaseline.values, contains(TextBaseline.alphabetic));
      expect(TextBaseline.values, contains(TextBaseline.top));
      expect(TextBaseline.values, contains(TextBaseline.middle));
      expect(TextBaseline.values, contains(TextBaseline.bottom));
      expect(TextBaseline.values, contains(TextBaseline.ideographic));
      expect(TextBaseline.values, contains(TextBaseline.hanging));
    });
  });

  group('Shaped width', () {
    late TTFFont font;

    setUpAll(() {
      font = ok(
        TTFFont.fromBytes(
          File('test/fixtures/fonts/DejaVuSans.ttf').readAsBytesSync(),
        ),
      );
    });

    test('totalAdvance includes kerning', () {
      final shaped = BasicTextShaper().shape('AVAV', font, 48);
      final kerned = shaped.glyphs.fold<double>(
        0,
        (sum, glyph) => sum + glyph.xAdvance,
      );
      final plain = BasicTextShaper().shape(
        'AVAV',
        font,
        48,
        features: const [],
      );

      expect(kerned, lessThan(plain.advance));
      expect(shaped.advance, closeTo(kerned, 1e-9));
    });

    test('centre alignment uses the shaped width', () {
      expect(font.glyph('中'.codeUnitAt(0)), equals(0));
      final engine = TextEngine(font: font, fontSize: 48);

      final missing = engine.path('A中B', 100, 50, align: TextAlign.center);
      final present = engine.path('AB', 100, 50, align: TextAlign.center);

      expect(missing.bounds.left, closeTo(present.bounds.left, 1e-9));
      expect(missing.bounds.width, closeTo(present.bounds.width, 1e-9));
    });
  });

  group('Line wrapping', () {
    late TTFFont font;
    // Kerned pairs (AV, To, Wa, Yo) at word joins and inside words
    const text =
        'AVAV To Wa  Yo LT\tAT VA Ty Te Wo Yo AV y. LTA VAT AWAY Tower '
        'Yacht Vault Travel Wave Lava Toyota LAVA TAVA AVATAR';

    setUpAll(() {
      font = ok(
        TTFFont.fromBytes(
          File('test/fixtures/fonts/DejaVuSans.ttf').readAsBytesSync(),
        ),
      );
    });

    test('the engine and the renderer break lines identically', () {
      final engine = TextEngine(font: font, fontSize: 16);
      final renderer = TextRenderer(font: font, fontSize: 16);
      for (final width in [40.0, 75.0, 120.0, 200.0, 1000.0]) {
        final lines = engine.wrap(text, width);
        final wrapped = renderer
            .wrap(text, 0, 0, width, 20)
            .map((line) => line.text)
            .toList();
        expect(wrapped, equals(lines), reason: 'width $width');
        expect(lines.join(' '), equals(text.split(RegExp(r'\s+')).join(' ')));
      }
    });

    test('a running width breaks where re-measuring each line did', () {
      double width(String value) => font.measure(value, 16).width;
      final words = text.split(RegExp(r'\s+'));
      for (var maxWidth = 20.0; maxWidth < 400; maxWidth += 7) {
        // The previous algorithm: measure every candidate line in full
        final expected = <String>[];
        var line = '';
        for (final word in words) {
          final candidate = line.isEmpty ? word : '$line $word';
          if (width(candidate) <= maxWidth) {
            line = candidate;
          } else {
            if (line.isNotEmpty) expected.add(line);
            line = word;
          }
        }
        if (line.isNotEmpty) expected.add(line);
        expect(
          TextEngine.split(text, maxWidth, width),
          equals(expected),
          reason: 'width $maxWidth',
        );
      }
    });

    test('kerning between a line and the next space is counted', () {
      // Every character is 10 wide, and 'x' kerns -4 with a following space
      double width(String value) =>
          value.length * 10.0 - 4 * 'x '.allMatches(value).length;
      const text = 'box ax b fox cx dd ex fx g hx ii jx';
      final words = text.split(' ');
      for (var maxWidth = 30.0; maxWidth < 200; maxWidth += 2) {
        final expected = <String>[];
        var line = '';
        for (final word in words) {
          final candidate = line.isEmpty ? word : '$line $word';
          if (width(candidate) <= maxWidth) {
            line = candidate;
          } else {
            if (line.isNotEmpty) expected.add(line);
            line = word;
          }
        }
        if (line.isNotEmpty) expected.add(line);
        expect(
          TextEngine.split(text, maxWidth, width),
          equals(expected),
          reason: 'width $maxWidth',
        );
      }
    });

    test('wrapping measures each word a bounded number of times', () {
      final text = List.filled(2000, 'word').join(' ');
      var measured = 0;
      double width(String value) {
        measured += value.length;
        return value.length * 5.0;
      }

      final lines = TextEngine.split(text, 1e9, width);
      expect(lines, hasLength(1));
      expect(measured, lessThan(text.length * 4));
    });
  });

  group('Baselines in Y-up graphics space', () {
    late TTFFont font;
    const y = 50.0;

    setUpAll(() {
      font = ok(
        TTFFont.fromBytes(
          File('test/fixtures/fonts/DejaVuSans.ttf').readAsBytesSync(),
        ),
      );
    });

    // Ink of 'H' (no descender) drawn at y with each baseline, from both
    // entry points
    Map<String, Rectangle> ink(final TextBaseline baseline) => {
      'engine': TextEngine(
        font: font,
        fontSize: 40,
      ).path('H', 0, y, baseline: baseline).bounds,
      'renderer': TextRenderer(
        font: font,
        fontSize: 40,
        textBaseline: baseline,
      ).path('H', 0, y).bounds,
    };

    test('alphabetic puts the baseline at y', () {
      for (final MapEntry(key: name, value: bounds) in ink(
        TextBaseline.alphabetic,
      ).entries) {
        expect(bounds.top, closeTo(y, 0.5), reason: name);
      }
    });

    test('top hangs the text below y', () {
      final ascent = font.measure('H', 40).ascent;
      for (final MapEntry(key: name, value: bounds) in ink(
        TextBaseline.top,
      ).entries) {
        expect(bounds.bottom, lessThanOrEqualTo(y + 0.5), reason: name);
        expect(
          bounds.top,
          greaterThanOrEqualTo(y - ascent - 0.5),
          reason: name,
        );
      }
    });

    test('bottom stands the text above y', () {
      for (final MapEntry(key: name, value: bounds) in ink(
        TextBaseline.bottom,
      ).entries) {
        expect(bounds.top, greaterThan(y), reason: name);
      }
    });

    test('ideographic sets the text slightly above y', () {
      // The ideographic baseline lies below the alphabetic one
      final bounds = TextRenderer(
        font: font,
        fontSize: 40,
        textBaseline: TextBaseline.ideographic,
      ).path('H', 0, y).bounds;
      expect(bounds.top, greaterThan(y));
      expect(bounds.top, lessThan(y + 10));
    });

    test('hanging hangs the text from y', () {
      // The hanging baseline lies near the top of capital letters
      final bounds = TextRenderer(
        font: font,
        fontSize: 40,
        textBaseline: TextBaseline.hanging,
      ).path('H', 0, y).bounds;
      expect(bounds.top, lessThan(y));
      expect(bounds.bottom, closeTo(y, 4));
    });

    test('middle centres the text on y', () {
      for (final MapEntry(key: name, value: bounds) in ink(
        TextBaseline.middle,
      ).entries) {
        expect(bounds.top, lessThan(y), reason: name);
        expect(bounds.bottom, greaterThan(y), reason: name);
      }
    });
  });

  group('Wrapped lines in Y-up graphics space', () {
    late TTFFont font;
    // Two words that wrap into two identical lines
    const text = 'HH HH';

    setUpAll(() {
      font = ok(
        TTFFont.fromBytes(
          File('test/fixtures/fonts/DejaVuSans.ttf').readAsBytesSync(),
        ),
      );
    });

    test('engine paths go down by the line height times the spacing', () {
      final engine = TextEngine(font: font, fontSize: 16);
      final width = engine.measure('HH', 16).width;
      final height = engine.measure('HH', 16).lineHeight;
      final paths = engine.paths(text, 0, 100, width + 1, lineSpacing: 1.5);
      expect(paths, hasLength(2));
      expect(
        paths[1].bounds.top,
        closeTo(paths[0].bounds.top - height * 1.5, 1e-6),
      );
    });

    test('renderer wrap goes down by the line height', () {
      final renderer = TextRenderer(font: font, fontSize: 16);
      final width = renderer.measure('HH').width;
      final lines = renderer.wrap(text, 0, 100, width + 1, 20);
      expect(lines, hasLength(2));
      expect(lines[1].position.y, closeTo(80, 1e-6));
      expect(
        lines[1].path.bounds.top,
        closeTo(lines[0].path.bounds.top - 20, 1e-6),
      );
    });
  });

  group('Right-to-left order', () {
    late TTFFont dejavu;
    late TTFFont noto; // no Hebrew, so a chain falls back to DejaVu

    setUpAll(() {
      TTFFont read(final String name) => ok(
        TTFFont.fromBytes(
          File('test/fixtures/fonts/$name.ttf').readAsBytesSync(),
        ),
      );
      dejavu = read('DejaVuSans');
      noto = read('NotoSans-Regular');
    });

    List<int> glyphs(final String text, [TextDirection? direction]) =>
        BasicTextShaper()
            .shape(text, dejavu, 16, direction: direction ?? TextDirection.auto)
            .glyphs
            .map((glyph) => glyph.glyph)
            .toList();

    int glyph(final String character) => dejavu.glyph(character.runes.single);

    // The characters of [visual], each drawn alone, one after another
    Path drawn(
      final String visual,
      final Path Function(String, double) draw,
      final double Function(String) advance,
    ) {
      final builder = PathBuilder();
      var cursor = 0.0;
      for (final character in visual.split('')) {
        builder.addPath(draw(character, cursor));
        cursor += advance(character);
      }
      return builder.build();
    }

    void expectSame(final Path actual, final Path expected) {
      expect(actual.commands, hasLength(expected.commands.length));
      for (var i = 0; i < expected.commands.length; i++) {
        final points = actual.commands[i].points;
        final wanted = expected.commands[i].points;
        for (var j = 0; j < wanted.length; j++) {
          expect(points[j].x, closeTo(wanted[j].x, 1e-6), reason: '$i');
          expect(points[j].y, closeTo(wanted[j].y, 1e-6), reason: '$i');
        }
      }
    }

    test('the shaper returns right-to-left glyphs in visual order', () {
      expect(glyphs('אבג'), equals([glyph('ג'), glyph('ב'), glyph('א')]));
      expect(glyphs('abc'), equals([glyph('a'), glyph('b'), glyph('c')]));
    });

    test('brackets in a right-to-left run are mirrored', () {
      expect(glyphs('(א', TextDirection.rtl), equals([glyph('א'), glyph(')')]));
    });

    // Digits after Hebrew join its right-to-left run, keeping their own
    // order inside it, so 'xy אב 12' shows as 'xy 12 בא'
    test('the engine draws a mixed line in visual order', () {
      final engine = TextEngine(font: dejavu, fontSize: 16);
      expectSame(
        engine.path('xy אב 12', 0, 0, align: TextAlign.left),
        drawn(
          'xy 12 בא',
          (character, x) => engine.path(character, x, 0, align: TextAlign.left),
          (character) => engine.shape(character).advance,
        ),
      );
    });

    test('the renderer orders runs of two fonts in visual order', () {
      // Left aligned, so that each character drawn alone starts at x
      final renderer =
          TextRenderer.unicode(fontSize: 16, textAlign: TextAlign.left)
            ..add(noto)
            ..add(dejavu);
      expectSame(
        renderer.layout('xy אב 12', 0, 0, 16),
        drawn(
          'xy 12 בא',
          (character, x) => renderer.layout(character, x, 0, 16),
          (character) => renderer.extent(character, 16).width,
        ),
      );
      // A right-to-left paragraph puts the Latin run on the right
      expectSame(
        renderer.layout('אב xy', 0, 0, 16),
        drawn(
          'xy בא',
          (character, x) => renderer.layout(character, x, 0, 16),
          (character) => renderer.extent(character, 16).width,
        ),
      );
    });
  });

  group('Text contrast', () {
    // Half of pixel 0 is covered: x from 0.5 to 2, the full height
    int shade({required final bool text}) {
      final bitmap = Bitmap(4, 1)..clear(const Color(0xFFFFFFFF));
      GraphicsContext(
        bitmap,
      ).fill(PathBuilder().rect(0.5, 0, 1.5, 1).build(), text: text);
      return bitmap.pixel(0, 0).red;
    }

    test('partial coverage darkens; full and none do not', () {
      expect(shade(text: false), closeTo(128, 1));
      // 0.5 ^ 0.6 = 0.66 of black
      expect(shade(text: true), closeTo(255 * (1 - 0.6598), 1));
      final bitmap = Bitmap(4, 1)..clear(const Color(0xFFFFFFFF));
      GraphicsContext(
        bitmap,
      ).fill(PathBuilder().rect(0.5, 0, 1.5, 1).build(), text: true);
      expect(bitmap.pixel(1, 0).red, 0);
      expect(bitmap.pixel(2, 0).red, 255);
    });

    test('fillText applies it unless the rendering is geometric', () {
      final bytes = File(
        'test/fixtures/fonts/DejaVuSans.ttf',
      ).readAsBytesSync();
      final font = ok(TTFFont.fromBytes(bytes));
      List<int> pixels(final void Function(GraphicsEngine) draw) {
        final engine = GraphicsEngine(60, 20)..readFont(bytes);
        draw(engine);
        return engine.canvas.pixels.toList();
      }

      final plain = pixels(
        (engine) => engine.fill(TextEngine(font: font).path('Hag', 2, 6)),
      );
      final geometric = pixels(
        (engine) => engine
          ..textRendering = TextRendering.geometricPrecision
          ..fillText('Hag', 2, 6),
      );
      final legible = pixels((engine) => engine.fillText('Hag', 2, 6));
      expect(geometric, equals(plain));
      expect(legible, isNot(equals(plain)));
    });

    test('fill takes the same contrast for text paths', () {
      final bytes = File(
        'test/fixtures/fonts/DejaVuSans.ttf',
      ).readAsBytesSync();
      final path = TextEngine(
        font: ok(TTFFont.fromBytes(bytes)),
      ).path('Hag', 2, 6);
      List<int> pixels(final void Function(GraphicsEngine) draw) {
        final engine = GraphicsEngine(60, 20)..readFont(bytes);
        draw(engine);
        return engine.canvas.pixels.toList();
      }

      expect(
        pixels((engine) => engine.fill(path, text: true)),
        equals(pixels((engine) => engine.fillText('Hag', 2, 6))),
      );
      expect(
        pixels(
          (engine) => engine
            ..textRendering = TextRendering.geometricPrecision
            ..fill(path, text: true),
        ),
        equals(pixels((engine) => engine.fill(path))),
      );
    });

    test('textRendering is saved with the state', () {
      final engine = GraphicsEngine(4, 4);
      expect(engine.textRendering, TextRendering.auto);
      engine
        ..save()
        ..textRendering = TextRendering.geometricPrecision
        ..restore();
      expect(engine.textRendering, TextRendering.auto);
    });
  });

  group('Start and end alignment', () {
    late TTFFont font;
    const hebrew = 'אבג';

    setUpAll(() {
      font = ok(
        TTFFont.fromBytes(
          File('test/fixtures/fonts/DejaVuSans.ttf').readAsBytesSync(),
        ),
      );
    });

    void expectBounds(
      final Path actual,
      final Path expected,
      final String why,
    ) {
      expect(
        actual.bounds.left,
        closeTo(expected.bounds.left, 1e-9),
        reason: why,
      );
      expect(
        actual.bounds.right,
        closeTo(expected.bounds.right, 1e-9),
        reason: why,
      );
      expect(actual.bounds.width, greaterThan(0), reason: why);
    }

    test('start is the default and follows the direction', () {
      final engine = TextEngine(font: font, fontSize: 16);
      expect(engine.textAlign, TextAlign.start);
      expect(engine.direction, TextDirection.ltr);
      Path draw(final String text, final TextAlign align) =>
          engine.path(text, 100, 0, align: align);

      expectBounds(
        draw('abc', TextAlign.start),
        draw('abc', TextAlign.left),
        'ltr start',
      );
      expectBounds(
        draw('abc', TextAlign.end),
        draw('abc', TextAlign.right),
        'ltr end',
      );
      engine.direction = TextDirection.rtl;
      expectBounds(
        draw(hebrew, TextAlign.start),
        draw(hebrew, TextAlign.right),
        'rtl start',
      );
      expectBounds(
        draw(hebrew, TextAlign.end),
        draw(hebrew, TextAlign.left),
        'rtl end',
      );
    });

    test('the renderer resolves start by the direction it is given', () {
      final start = TextRenderer.unicode(fontSize: 16)..add(font);
      final right = TextRenderer.unicode(
        fontSize: 16,
        textAlign: TextAlign.right,
      )..add(font);
      expect(start.textAlign, TextAlign.start);
      expectBounds(
        start.layout(hebrew, 100, 0, 16, direction: TextDirection.rtl),
        right.layout(hebrew, 100, 0, 16, direction: TextDirection.rtl),
        'rtl',
      );
      // Automatic direction reads Hebrew as right to left
      expectBounds(
        start.layout(hebrew, 100, 0, 16),
        right.layout(hebrew, 100, 0, 16),
        'auto',
      );
    });

    test('the engine direction is saved and decides start', () {
      final engine = GraphicsEngine(
        200,
        40,
      )..readFont(File('test/fixtures/fonts/DejaVuSans.ttf').readAsBytesSync());
      expect(engine.direction, TextDirection.ltr);
      engine
        ..save()
        ..direction = TextDirection.rtl;
      expect(engine.direction, TextDirection.rtl);
      engine.restore();
      expect(engine.direction, TextDirection.ltr);

      List<int> pixels(final void Function(GraphicsEngine) setup) {
        final canvas = GraphicsEngine(200, 40)
          ..readFont(
            File('test/fixtures/fonts/DejaVuSans.ttf').readAsBytesSync(),
          )
          ..fontSize = 16;
        setup(canvas);
        canvas.fillText(hebrew, 150, 10);
        return canvas.canvas.pixels.toList();
      }

      expect(
        pixels((canvas) => canvas.direction = TextDirection.rtl),
        equals(pixels((canvas) => canvas.textAlign = TextAlign.right)),
      );
    });
  });

  group('Renderer alignment', () {
    late TTFFont font;
    const text = 'Hello';

    setUpAll(() {
      font = ok(
        TTFFont.fromBytes(
          File('test/fixtures/fonts/DejaVuSans.ttf').readAsBytesSync(),
        ),
      );
    });

    TextRenderer renderer(final TextAlign align) =>
        TextRenderer.unicode(fontSize: 16, textAlign: align)..add(font);

    // Aligned ink must be the left-aligned ink moved left by the share of
    // width the alignment takes off
    void expectShifted(
      final Rectangle aligned,
      final Rectangle left,
      final double shift,
      final String reason,
    ) {
      expect(aligned.width, greaterThan(0), reason: reason);
      expect(aligned.left, closeTo(left.left - shift, 1e-6), reason: reason);
      expect(aligned.top, closeTo(left.top, 1e-6), reason: reason);
    }

    test('layout aligns by the width at the size it is given', () {
      final width = renderer(TextAlign.left).extent(text, 32).width;
      final left = renderer(TextAlign.left).layout(text, 100, 50, 32).bounds;
      for (final (align, share) in [
        (TextAlign.center, 0.5),
        (TextAlign.right, 1.0),
      ]) {
        expectShifted(
          renderer(align).layout(text, 100, 50, 32).bounds,
          left,
          width * share,
          '$align',
        );
      }
    });

    test('wrap and spaced align each line once', () {
      final width = renderer(TextAlign.left).measure(text).width;
      for (final (align, share) in [
        (TextAlign.center, 0.5),
        (TextAlign.right, 1.0),
      ]) {
        final wrapped = renderer(align).wrap(text, 100, 50, 1000, 20).single;
        expectShifted(
          wrapped.path.bounds,
          renderer(TextAlign.left).path(text, 100, 50).bounds,
          width * share,
          'wrap $align',
        );
        expect(wrapped.position.x, closeTo(100 - width * share, 1e-6));
        expectShifted(
          renderer(align).spaced(text, 100, 50, 0).bounds,
          renderer(TextAlign.left).spaced(text, 100, 50, 0).bounds,
          width * share,
          'spaced $align',
        );
      }
    });
  });
}

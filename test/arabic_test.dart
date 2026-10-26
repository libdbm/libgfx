import 'dart:io';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/text/arabic.dart';
import 'package:test/test.dart';

import 'support/results.dart';

void main() {
  List<int> join(final String text, [bool Function(int)? covers]) =>
      Arabic.join(text.runes.toList(), covers ?? (_) => true);

  group('Arabic joining', () {
    test('letters take the form their neighbours call for', () {
      // Kaf joins the alef after it; alef does not join forward, so noon
      // stands alone
      expect(join('كان'), equals([0xFEDB, 0xFE8E, 0xFEE5]));
      // Beh, medial beh, final beh
      expect(join('ببب'), equals([0xFE91, 0xFE92, 0xFE90]));
    });

    test('marks do not break joining', () {
      expect(join('بَب'), equals([0xFE91, 0x064E, 0xFE90]));
    });

    test('a non-joining letter breaks joining', () {
      // Hamza joins neither way
      expect(join('بءب'), equals([0xFE8F, 0xFE80, 0xFE8F]));
    });

    test('tatweel joins both ways', () {
      expect(join('بـ'), equals([0xFE91, 0x0640]));
      expect(join('ـب'), equals([0x0640, 0xFE90]));
    });

    test('lam and alef become one ligature', () {
      expect(join('لا'), equals([0xFEFB, -1]));
      expect(join('بلا'), equals([0xFE91, 0xFEFC, -1]));
      expect(join('لأ'), equals([0xFEF7, -1]));
    });

    test('letters from Presentation Forms-A join', () {
      // Peh (Persian) then alef
      expect(join('پا'), equals([0xFB58, 0xFE8E]));
    });

    test('forms the font lacks fall back to the letter', () {
      expect(join('كان', (code) => code != 0xFEDB), [0x0643, 0xFE8E, 0xFEE5]);
      // Without the ligature, lam joins the alef as a letter
      expect(join('لا', (code) => code != 0xFEFB), equals([0xFEDF, 0xFE8E]));
    });

    test('other text is unchanged', () {
      expect(join('abc אב'), equals('abc אב'.runes.toList()));
    });
  });

  group('Arabic shaping', () {
    late TTFFont font;

    setUpAll(() {
      font = ok(
        TTFFont.fromBytes(
          File('test/fixtures/fonts/DejaVuSans.ttf').readAsBytesSync(),
        ),
      );
    });

    List<int> glyphs(final String text) => BasicTextShaper()
        .shape(text, font, 16)
        .glyphs
        .map((glyph) => glyph.glyph)
        .toList();

    test('the shaper draws joined forms, right to left', () {
      expect(
        glyphs('كان'),
        equals([font.glyph(0xFEE5), font.glyph(0xFE8E), font.glyph(0xFEDB)]),
      );
      expect(glyphs('لا'), equals([font.glyph(0xFEFB)]));
    });
  });
}

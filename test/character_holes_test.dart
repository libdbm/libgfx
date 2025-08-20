import 'dart:io';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/graphics_context.dart';
import 'package:test/test.dart';

void main() {
  group('Character Holes (Counter) Tests', () {
    late List<File> fontFiles;

    setUpAll(() async {
      final fontsDir = Directory('data/fonts');
      fontFiles = fontsDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.ttf'))
          .toList();

      expect(fontFiles.length, greaterThan(0));
    });

    test('characters with holes have multiple contours', () async {
      if (fontFiles.isNotEmpty) {
        final font = await TTFFont.loadFromFile(fontFiles.first.path);

        // Characters that should have holes (multiple contours)
        final charsWithHoles = [
          'e',
          'o',
          'O',
          'a',
          'd',
          'b',
          'p',
          'q',
          'A',
          'D',
          'P',
          'R',
          'B',
          '0',
          '4',
          '6',
          '8',
          '9',
        ];

        for (final char in charsWithHoles) {
          final charCode = char.codeUnitAt(0);
          if (font.hasGlyph(charCode)) {
            final glyphIndex = font.getGlyphIndex(charCode);
            final path = font.getGlyphPath(glyphIndex, 48);

            // Count moveTo commands (indicates number of contours)
            var moveToCount = 0;
            for (final cmd in path.commands) {
              if (cmd.type.toString().contains('moveTo')) {
                moveToCount++;
              }
            }

            expect(
              moveToCount,
              greaterThan(1),
              reason: 'Character "$char" should have holes (multiple contours)',
            );
            print('Character "$char": $moveToCount contours');
          }
        }
      }
    });

    test('characters without holes have single contours', () async {
      if (fontFiles.isNotEmpty) {
        final font = await TTFFont.loadFromFile(fontFiles.first.path);

        // Characters that should NOT have holes (single contours)
        // Note: 'i' and 'j' often have separate contours for dots, so we exclude them
        final charsWithoutHoles = [
          'l',
          'I',
          't',
          'f',
          'r',
          'n',
          'm',
          'h',
          'u',
          'v',
          'w',
          'x',
          'y',
          'z',
        ];

        for (final char in charsWithoutHoles) {
          final charCode = char.codeUnitAt(0);
          if (font.hasGlyph(charCode)) {
            final glyphIndex = font.getGlyphIndex(charCode);
            final path = font.getGlyphPath(glyphIndex, 48);

            // Count moveTo commands (indicates number of contours)
            var moveToCount = 0;
            for (final cmd in path.commands) {
              if (cmd.type.toString().contains('moveTo')) {
                moveToCount++;
              }
            }

            expect(
              moveToCount,
              equals(1),
              reason:
                  'Character "$char" should NOT have holes (single contour)',
            );
            print('Character "$char": $moveToCount contour');
          }
        }
      }
    });

    test('rasterizer properly handles even-odd fill rule', () {
      final bitmap = Bitmap(200, 200);
      final context = GraphicsContext(bitmap);

      // Create a simple path with a hole (outer rectangle + inner rectangle)
      final path = Path();

      // Outer rectangle (0,0 to 100,100)
      path.addCommand(PathCommand(PathCommandType.moveTo, [Point(0, 0)]));
      path.addCommand(PathCommand(PathCommandType.lineTo, [Point(100, 0)]));
      path.addCommand(PathCommand(PathCommandType.lineTo, [Point(100, 100)]));
      path.addCommand(PathCommand(PathCommandType.lineTo, [Point(0, 100)]));
      path.addCommand(PathCommand(PathCommandType.close, []));

      // Inner rectangle (25,25 to 75,75) - should be a hole
      path.addCommand(PathCommand(PathCommandType.moveTo, [Point(25, 25)]));
      path.addCommand(PathCommand(PathCommandType.lineTo, [Point(75, 25)]));
      path.addCommand(PathCommand(PathCommandType.lineTo, [Point(75, 75)]));
      path.addCommand(PathCommand(PathCommandType.lineTo, [Point(25, 75)]));
      path.addCommand(PathCommand(PathCommandType.close, []));

      final spans = context.rasterizer.rasterize(path);

      // Should have spans, but NOT in the hole area
      expect(spans.length, greaterThan(0));

      // Check that the hole area (around y=50, x=50) is not filled
      final holeAreaSpans = spans
          .where(
            (span) => span.y == 50 && span.x <= 50 && span.x + span.length > 50,
          )
          .toList();

      // If even-odd fill is working correctly, there should be no spans covering the hole
      expect(
        holeAreaSpans.length,
        equals(0),
        reason: 'Hole area should not be filled with even-odd fill rule',
      );

      print('Rasterized ${spans.length} spans total');
      print('Hole area spans: ${holeAreaSpans.length} (should be 0)');
    });

    test('can render text with holes to graphics engine', () async {
      if (fontFiles.isNotEmpty) {
        final engine = GraphicsEngine(200, 100);
        engine.clear(const Color(0xFFFFFFFF)); // White background

        final font = await TTFFont.loadFromFile(fontFiles.first.path);

        // Render a character with a hole
        final testText = 'eOaB8';
        engine.setFillColor(const Color(0xFF000000)); // Black text
        final textPath = font.getTextPath(testText, 10, 50, 36);

        // Should render without errors
        expect(() => engine.fill(textPath), returnsNormally);

        print('Successfully rendered text with holes: "$testText"');
      }
    });
  });
}

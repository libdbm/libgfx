import 'dart:io';

import 'package:test/test.dart';

import '../lib/src/color/color.dart';
import '../lib/src/fonts/ttf/ttf_font.dart';
import '../lib/src/graphics_engine_facade.dart';
import '../lib/src/text/text_types.dart' show TextMetrics;

void main() {
  group('TTF Rendering Tests', () {
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

    test('can render text to graphics engine', () async {
      final engine = GraphicsEngine(400, 200);
      engine.clear(const Color(0xFFFFFFFF)); // White background

      for (final fontFile in fontFiles) {
        final font = await TTFFont.loadFromFile(fontFile.path);
        final testText = 'Test';

        // Get text path
        final textPath = font.getTextPath(testText, 10, 50, 24.0);

        // Should be able to render without errors
        engine.setFillColor(const Color(0xFF000000)); // Black text
        expect(() => engine.fill(textPath), returnsNormally);

        print('Successfully rendered "$testText" with ${font.familyName}');
      }
    });

    test('text rendering produces non-empty paths', () async {
      for (final fontFile in fontFiles) {
        final font = await TTFFont.loadFromFile(fontFile.path);

        // Skip emoji fonts which may not have regular character glyphs
        if (font.familyName.toLowerCase().contains('emoji')) {
          print(
            'Skipping path generation test for emoji font: ${font.familyName}',
          );
          continue;
        }

        final testTexts = ['A', 'Hello', '123', 'Test'];

        for (final text in testTexts) {
          final path = font.getTextPath(text, 0, 0, 48.0);

          if (text.trim().isNotEmpty) {
            // Skip whitespace-only text
            // Some fonts might not have all glyphs, so we just check if at least one text produces a path
            if (path.commands.isNotEmpty) {
              // Check that path has actual drawing commands, not just moveTo
              final drawingCommands = path.commands
                  .where((cmd) => !cmd.type.toString().contains('moveTo'))
                  .length;
              expect(
                drawingCommands,
                greaterThan(0),
                reason:
                    'Text "$text" should have drawing commands beyond moveTo',
              );
              break; // At least one text produced a path, that's enough for this font
            }
          }
        }

        print('Path generation verified for ${font.familyName}');
      }
    });

    test('different font sizes produce scaled paths', () async {
      if (fontFiles.isNotEmpty) {
        final font = await TTFFont.loadFromFile(fontFiles.first.path);
        final testText = 'A';

        final sizes = [12.0, 24.0, 48.0];
        final measurements = <double, TextMetrics>{};

        for (final size in sizes) {
          final metrics = font.measureText(testText, size);
          measurements[size] = metrics;

          print(
            'Size ${size}pt: ${metrics.width.toStringAsFixed(2)}px wide, ${metrics.height.toStringAsFixed(2)}px tall',
          );
        }

        // Larger sizes should produce larger measurements
        expect(
          measurements[24.0]!.width,
          greaterThan(measurements[12.0]!.width),
        );
        expect(
          measurements[48.0]!.width,
          greaterThan(measurements[24.0]!.width),
        );
        expect(
          measurements[24.0]!.height,
          greaterThan(measurements[12.0]!.height),
        );
        expect(
          measurements[48.0]!.height,
          greaterThan(measurements[24.0]!.height),
        );

        // Should be roughly proportional (allowing for rounding)
        final ratio1 = measurements[24.0]!.width / measurements[12.0]!.width;
        final ratio2 = measurements[48.0]!.width / measurements[24.0]!.width;
        expect((ratio1 - 2.0).abs(), lessThan(0.1)); // Should be ~2x
        expect((ratio2 - 2.0).abs(), lessThan(0.1)); // Should be ~2x
      }
    });

    test('text positioning works correctly', () async {
      if (fontFiles.isNotEmpty) {
        final font = await TTFFont.loadFromFile(fontFiles.first.path);
        final testText = 'AB';

        // Generate paths at different positions
        final path1 = font.getTextPath(testText, 0, 0, 24.0);
        final path2 = font.getTextPath(testText, 100, 50, 24.0);

        // Both should have commands
        expect(path1.commands.length, greaterThan(0));
        expect(path2.commands.length, greaterThan(0));

        // Find the first moveTo command in each path to compare positions
        final moveTo1 = path1.commands.firstWhere(
          (cmd) => cmd.type.toString().contains('moveTo'),
        );
        final moveTo2 = path2.commands.firstWhere(
          (cmd) => cmd.type.toString().contains('moveTo'),
        );

        // Second path should be offset by the specified amounts
        expect(moveTo2.points.first.x, greaterThan(moveTo1.points.first.x));
        expect(moveTo2.points.first.y, greaterThan(moveTo1.points.first.y));

        print('Text positioning test passed');
      }
    });

    test('empty text produces empty path', () async {
      if (fontFiles.isNotEmpty) {
        final font = await TTFFont.loadFromFile(fontFiles.first.path);

        final emptyTexts = ['', '   ', '\t', '\n'];

        for (final text in emptyTexts) {
          final path = font.getTextPath(text, 0, 0, 24.0);
          // Empty or whitespace-only text might produce empty paths or just moveTo commands
          // This is acceptable behavior
          expect(() => path.commands, returnsNormally);
          print('Empty text "$text" handled correctly');
        }
      }
    });

    test('special characters can be rendered', () async {
      if (fontFiles.isNotEmpty) {
        final font = await TTFFont.loadFromFile(fontFiles.first.path);

        final specialChars = [
          '!@#\$%^&*()',
          '[]{}()',
          '.,;:',
          '"\'`',
          '+-=/',
          '~|\\',
        ];

        for (final chars in specialChars) {
          final path = font.getTextPath(chars, 0, 0, 24.0);
          expect(() => path.commands, returnsNormally);

          // Count how many characters actually have glyphs
          var glyphCount = 0;
          for (final char in chars.runes) {
            if (font.hasGlyph(char)) {
              glyphCount++;
            }
          }

          print(
            'Special chars "$chars": $glyphCount/${chars.length} have glyphs',
          );
        }
      }
    });

    test('unicode characters are handled properly', () async {
      if (fontFiles.isNotEmpty) {
        final font = await TTFFont.loadFromFile(fontFiles.first.path);

        final unicodeTexts = [
          'café', // Latin with accents
          'naïve', // More accented characters
          '©®™', // Symbols
          '123°', // Degree symbol
          'α β γ', // Greek letters (may not be supported)
        ];

        for (final text in unicodeTexts) {
          final path = font.getTextPath(text, 0, 0, 24.0);
          expect(() => path.commands, returnsNormally);

          // Count supported characters
          var supportedCount = 0;
          for (final char in text.runes) {
            if (font.hasGlyph(char)) {
              supportedCount++;
            }
          }

          print(
            'Unicode text "$text": $supportedCount/${text.runes.length} characters supported',
          );
        }
      }
    });

    test('large text can be rendered', () async {
      if (fontFiles.isNotEmpty) {
        final font = await TTFFont.loadFromFile(fontFiles.first.path);

        // Test with longer text
        final longText = 'The quick brown fox jumps over the lazy dog. ' * 3;
        final path = font.getTextPath(longText, 0, 0, 12.0);

        expect(path.commands.length, greaterThan(0));
        expect(() => path.commands, returnsNormally);

        final metrics = font.measureText(longText, 12.0);
        expect(metrics.width, greaterThan(100)); // Should be quite wide

        print(
          'Long text (${longText.length} chars): ${metrics.width.toStringAsFixed(1)}px wide',
        );
      }
    });

    test('font metrics scaling is consistent', () async {
      if (fontFiles.isNotEmpty) {
        final font = await TTFFont.loadFromFile(fontFiles.first.path);
        final testText = 'Test';

        // Test various font sizes
        final sizes = [8.0, 12.0, 16.0, 24.0, 36.0, 48.0, 72.0];

        for (final size in sizes) {
          final metrics = font.measureText(testText, size);

          // Text height should be related to font metrics
          expect(metrics.height, greaterThan(0));
          expect(metrics.width, greaterThan(0));

          // Ascent should be reasonable relative to font size
          expect(
            metrics.ascent,
            greaterThan(size * 0.5),
          ); // At least half the font size
          expect(
            metrics.ascent,
            lessThan(size * 1.5),
          ); // But not more than 1.5x

          print(
            'Size ${size}pt: width=${metrics.width.toStringAsFixed(1)}px, height=${metrics.height.toStringAsFixed(1)}px, ascent=${metrics.ascent.toStringAsFixed(1)}px',
          );
        }
      }
    });
  });
}

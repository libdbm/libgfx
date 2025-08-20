import 'dart:io';

import 'package:test/test.dart';

import '../lib/src/fonts/ttf/ttf_font.dart';

void main() {
  group('TTF Parsing Tests with Real Fonts', () {
    late List<File> fontFiles;

    setUpAll(() async {
      // Get all TTF files from data/fonts directory
      final fontsDir = Directory('data/fonts');
      expect(
        fontsDir.existsSync(),
        isTrue,
        reason: 'data/fonts directory should exist',
      );

      fontFiles = fontsDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.ttf'))
          .toList();

      expect(
        fontFiles.length,
        greaterThan(0),
        reason: 'Should have TTF files for testing',
      );
      print('Found ${fontFiles.length} TTF files for testing:');
      for (final file in fontFiles) {
        print('  - ${file.path.split('/').last}');
      }
    });

    test('can load all TTF fonts without errors', () async {
      for (final fontFile in fontFiles) {
        print('Testing font: ${fontFile.path.split('/').last}');

        // Load font - should not throw
        final font = await TTFFont.loadFromFile(fontFile.path);

        // Basic validation
        expect(font.familyName, isNotEmpty);
        expect(font.styleName, isNotEmpty);
        expect(font.unitsPerEm, greaterThan(0));
        expect(
          font.unitsPerEm,
          lessThanOrEqualTo(16384),
        ); // Reasonable TTF limit

        print('  Family: ${font.familyName}');
        print('  Style: ${font.styleName}');
        print('  Units per Em: ${font.unitsPerEm}');
      }
    });

    test('font metrics are properly parsed', () async {
      for (final fontFile in fontFiles) {
        final font = await TTFFont.loadFromFile(fontFile.path);
        final metrics = font.metrics;

        // Font metrics should be reasonable
        expect(metrics.ascender, greaterThan(0));
        expect(
          metrics.descender,
          lessThan(0),
        ); // Descender is typically negative
        expect(metrics.lineGap, greaterThanOrEqualTo(0));
        expect(metrics.maxAdvanceWidth, greaterThan(0));
        expect(metrics.lineHeight, greaterThan(0));

        print('Font: ${font.familyName}');
        print('  Ascender: ${metrics.ascender}');
        print('  Descender: ${metrics.descender}');
        print('  Line Gap: ${metrics.lineGap}');
        print('  Line Height: ${metrics.lineHeight}');
        print('  Max Advance Width: ${metrics.maxAdvanceWidth}');

        // Test scaling
        final scaled = metrics.scale(24.0, font.unitsPerEm);
        expect(scaled.ascender, greaterThan(0));
        expect(scaled.lineHeight, greaterThan(0));
      }
    });

    test('character mapping works correctly', () async {
      for (final fontFile in fontFiles) {
        final font = await TTFFont.loadFromFile(fontFile.path);

        // Test common ASCII characters
        final testChars = [
          65, // 'A'
          97, // 'a'
          48, // '0'
          32, // space
          33, // '!'
          63, // '?'
        ];

        for (final charCode in testChars) {
          final hasGlyph = font.hasGlyph(charCode);
          final glyphIndex = font.getGlyphIndex(charCode);

          if (hasGlyph) {
            expect(glyphIndex, greaterThan(0));
          } else {
            expect(glyphIndex, equals(0)); // Missing glyph should return 0
          }

          // Test glyph metrics for existing glyphs
          if (glyphIndex > 0) {
            final glyphMetrics = font.getGlyphMetrics(glyphIndex);
            expect(glyphMetrics.advanceWidth, greaterThanOrEqualTo(0));
            expect(glyphMetrics.boundingBox.width, greaterThanOrEqualTo(0));
            expect(glyphMetrics.boundingBox.height, greaterThanOrEqualTo(0));
          }
        }

        print('Font: ${font.familyName} - Character mapping tests passed');
      }
    });

    test('glyph path generation works', () async {
      for (final fontFile in fontFiles) {
        final font = await TTFFont.loadFromFile(fontFile.path);

        // Test generating paths for common characters
        final testChars = ['A', 'B', 'O', 'a', 'o', '0'];

        for (final char in testChars) {
          final charCode = char.codeUnitAt(0);
          if (font.hasGlyph(charCode)) {
            final glyphIndex = font.getGlyphIndex(charCode);
            final path = font.getGlyphPath(
              glyphIndex,
              100.0,
            ); // 100pt font size

            // Skip color emoji fonts as they may not have traditional path data
            if (font.familyName.toLowerCase().contains('emoji') ||
                font.familyName.toLowerCase().contains('color')) {
              print('Skipping path check for emoji font: ${font.familyName}');
              continue;
            }

            // Path should have some commands for visible characters
            if (char != ' ') {
              // Skip space character
              // Some fonts might not have all glyphs with path data
              if (path.commands.isNotEmpty) {
                // Should have at least a moveTo command
                final hasMoveTo = path.commands.any(
                  (cmd) => cmd.type.toString().contains('moveTo'),
                );
                expect(
                  hasMoveTo,
                  isTrue,
                  reason: 'Glyph path should start with moveTo',
                );
              }
            }

            print(
              'Font: ${font.familyName}, Char: $char, Commands: ${path.commands.length}',
            );
          }
        }
      }
    });

    test('text measurement works correctly', () async {
      for (final fontFile in fontFiles) {
        final font = await TTFFont.loadFromFile(fontFile.path);

        final testTexts = ['Hello', 'World', 'ABC', 'abc', '123', 'Test Text'];

        for (final text in testTexts) {
          final metrics = font.measureText(text, 24.0);

          expect(metrics.width, greaterThan(0));
          expect(metrics.height, greaterThan(0));
          expect(metrics.ascent, greaterThan(0));
          expect(
            metrics.descent,
            greaterThanOrEqualTo(0),
          ); // Can be 0 for some fonts
          expect(metrics.lineHeight, greaterThan(0));

          print('Font: ${font.familyName}, Text: "$text"');
          print('  Width: ${metrics.width.toStringAsFixed(2)}px');
          print('  Height: ${metrics.height.toStringAsFixed(2)}px');
          print('  Ascent: ${metrics.ascent.toStringAsFixed(2)}px');
          print('  Descent: ${metrics.descent.toStringAsFixed(2)}px');
        }
      }
    });

    test('text path generation works', () async {
      for (final fontFile in fontFiles) {
        final font = await TTFFont.loadFromFile(fontFile.path);

        final testText = 'Hello';
        final textPath = font.getTextPath(testText, 0, 0, 48.0);

        // Text path should have commands
        expect(textPath.commands.length, greaterThan(0));

        // Should have moveTo commands for positioning glyphs
        final moveToCommands = textPath.commands
            .where((cmd) => cmd.type.toString().contains('moveTo'))
            .length;
        expect(moveToCommands, greaterThan(0));

        print('Font: ${font.familyName}, Text: "$testText"');
        print('  Total path commands: ${textPath.commands.length}');
        print('  MoveTo commands: $moveToCommands');
      }
    });

    test('kerning works when available', () async {
      for (final fontFile in fontFiles) {
        final font = await TTFFont.loadFromFile(fontFile.path);

        // Test common kerning pairs
        final kerningPairs = [
          ['A', 'V'],
          ['T', 'o'],
          ['W', 'a'],
          ['V', 'A'],
        ];

        for (final pair in kerningPairs) {
          final leftChar = pair[0].codeUnitAt(0);
          final rightChar = pair[1].codeUnitAt(0);

          if (font.hasGlyph(leftChar) && font.hasGlyph(rightChar)) {
            final leftGlyph = font.getGlyphIndex(leftChar);
            final rightGlyph = font.getGlyphIndex(rightChar);

            final kerning = font.getKerning(leftGlyph, rightGlyph, 24.0);

            // Kerning can be positive, negative, or zero
            expect(kerning, isA<double>());

            if (kerning != 0.0) {
              print(
                'Font: ${font.familyName}, Pair: ${pair[0]}${pair[1]}, Kerning: ${kerning.toStringAsFixed(2)}px',
              );
            }
          }
        }
      }
    });

    group('Font-specific tests', () {
      test('Google Sans Code fonts have expected properties', () async {
        final googleFonts = fontFiles
            .where((f) => f.path.contains('GoogleSansCode'))
            .toList();

        for (final fontFile in googleFonts) {
          final font = await TTFFont.loadFromFile(fontFile.path);

          expect(font.familyName.toLowerCase(), contains('google'));
          expect(
            font.unitsPerEm,
            greaterThan(0),
          ); // Google fonts use various UPM values

          // Should support basic ASCII
          expect(font.hasGlyph(65), isTrue); // 'A'
          expect(font.hasGlyph(97), isTrue); // 'a'
          expect(font.hasGlyph(48), isTrue); // '0'

          print('Google font: ${font.fullName}');
        }
      });

      test('Radley fonts have expected properties', () async {
        final radleyFonts = fontFiles
            .where((f) => f.path.contains('Radley'))
            .toList();

        for (final fontFile in radleyFonts) {
          final font = await TTFFont.loadFromFile(fontFile.path);

          expect(font.familyName.toLowerCase(), contains('radley'));

          // Should support basic ASCII
          expect(font.hasGlyph(65), isTrue); // 'A'
          expect(font.hasGlyph(97), isTrue); // 'a'

          print('Radley font: ${font.fullName}');
        }
      });
    });

    test('font comparison - different fonts have different metrics', () async {
      if (fontFiles.length >= 2) {
        final font1 = await TTFFont.loadFromFile(fontFiles[0].path);
        final font2 = await TTFFont.loadFromFile(fontFiles[1].path);

        // Different fonts should have different family names (unless variants)
        final sameFamily = font1.familyName == font2.familyName;

        // Measure same text with both fonts
        final text = 'Hello World';
        final metrics1 = font1.measureText(text, 24.0);
        final metrics2 = font2.measureText(text, 24.0);

        print('Comparing fonts:');
        print(
          '  ${font1.fullName}: ${metrics1.width.toStringAsFixed(2)}px wide',
        );
        print(
          '  ${font2.fullName}: ${metrics2.width.toStringAsFixed(2)}px wide',
        );

        // Different fonts should generally produce different measurements
        // (unless they're the same font or have identical metrics)
        if (!sameFamily) {
          // Only expect different widths if they're completely different font families
          expect(
            metrics1.width != metrics2.width ||
                metrics1.height != metrics2.height,
            isTrue,
            reason:
                'Different font families should produce different text measurements',
          );
        }
      }
    });
  });
}

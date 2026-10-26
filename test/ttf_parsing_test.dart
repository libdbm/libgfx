import 'dart:io';
import 'dart:typed_data';

import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';
import 'package:test/test.dart';

import 'support/fonts.dart' as synthetic;
import 'support/results.dart';

void main() {
  const filesystem = LocalGraphicsFileSystem();
  group('Glyph metrics and cache', () {
    test('a glyph with a truncated outline is rejected at load', () {
      // One contour claiming 5 points, with no flags or coordinates; it
      // used to load and then throw when drawn
      final glyph = ByteData(12)
        ..setInt16(0, 1)
        ..setInt16(2, 1)
        ..setInt16(4, 2)
        ..setInt16(6, 30)
        ..setInt16(8, 40)
        ..setUint16(10, 4);
      final bytes = synthetic.font(
        outlines: [glyph.buffer.asUint8List()],
        glyphs: 1,
      );
      err(TTFFont.fromBytes(bytes), ErrorKind.truncated);
    });

    test('measuring and drawing decode each glyph once', () {
      final bytes = File(
        'test/fixtures/fonts/DejaVuSans.ttf',
      ).readAsBytesSync();
      final font = ok(TTFFont.fromBytes(bytes));
      const sample =
          'The quick brown fox jumps over the lazy dog. '
          'Voix ambiguë d\'un cœur qui préfère les jattes de kiwis! 0123456789';
      final text = sample * (90000 ~/ sample.length + 1);
      expect(text.length, greaterThan(90000));

      font.measure(text, 16);
      expect(font.decodes, equals(0), reason: 'metrics need no outlines');

      font.path(text, 0, 0, 16);
      final distinct = sample.runes.map(font.glyph).toSet().length;
      final decodes = font.decodes;
      expect(decodes, greaterThanOrEqualTo(distinct));
      // Components of composite glyphs are the only other glyphs decoded
      expect(decodes, lessThan(distinct * 2));

      font.measure(text, 24);
      font.path(text, 10, 10, 24);
      expect(font.decodes, equals(decodes));
    });

    test('cached outlines scale with the font size', () {
      final bytes = File(
        'test/fixtures/fonts/DejaVuSans.ttf',
      ).readAsBytesSync();
      final font = ok(TTFFont.fromBytes(bytes));
      final glyph = font.glyph('é'.runes.first);
      final small = font.outline(glyph, 10).commands;
      final large = font.outline(glyph, 40).commands;
      expect(large.length, equals(small.length));
      for (var i = 0; i < small.length; i++) {
        for (var j = 0; j < small[i].points.length; j++) {
          expect(large[i].points[j].x, closeTo(small[i].points[j].x * 4, 1e-9));
          expect(large[i].points[j].y, closeTo(small[i].points[j].y * 4, 1e-9));
        }
      }
    });
  });

  group('Composite transforms', () {
    const triangle = [(0, 0), (100, 0), (0, 50)];

    // The points of the outline of the last of [outlines], in font units
    List<(double, double)> points(final List<Uint8List> outlines) {
      final font = ok(
        TTFFont.fromBytes(
          synthetic.font(outlines: outlines, glyphs: outlines.length),
        ),
      );
      return [
        for (final command in font.outline(outlines.length - 1, 1000).commands)
          for (final point in command.points)
            (
              (point.x * 1000).roundToDouble() / 1000,
              (point.y * 1000).roundToDouble() / 1000,
            ),
      ];
    }

    List<(double, double)> placed(final List<(num, num)> expected) => [
      for (final point in expected) (point.$1.toDouble(), point.$2.toDouble()),
    ];

    test('offsets and scales place the component', () {
      for (final (component, expected) in [
        (synthetic.Component(0, x: 10, y: 20), [(10, 20), (110, 20), (10, 70)]),
        (synthetic.Component(0, transform: [0.5]), [(0, 0), (50, 0), (0, 25)]),
        (
          synthetic.Component(0, transform: [1.5, -1]),
          [(0, 0), (150, 0), (0, -50)],
        ),
      ]) {
        expect(
          points([
            synthetic.polygon(triangle),
            synthetic.composed([component]),
          ]),
          equals(placed(expected)),
          reason: '${component.transform}',
        );
      }
    });

    test('a 2x2 transform mirrors and shears the component', () {
      // Stored as xx, xy, yx, yy: x' = xx x + yx y, y' = xy x + yy y
      for (final (transform, expected) in [
        ([-1.0, 0.0, 0.0, 1.0], [(200, 0), (100, 0), (200, 50)]),
        ([1.0, 0.5, 0.0, 1.0], [(200, 0), (300, 50), (200, 50)]),
        ([1.0, 0.0, 0.5, 1.0], [(200, 0), (300, 0), (225, 50)]),
      ]) {
        expect(
          points([
            synthetic.polygon(triangle),
            synthetic.composed([
              synthetic.Component(0, x: 200, transform: transform),
            ]),
          ]),
          equals(placed(expected)),
          reason: '$transform',
        );
      }
    });

    test('matched points place the component on the composite', () {
      // The second triangle's point 2 lands on the first triangle's point 1
      expect(
        points([
          synthetic.polygon(triangle),
          synthetic.composed([
            synthetic.Component(0),
            synthetic.Component(0, x: 1, y: 2, matched: true),
          ]),
        ]),
        equals(
          placed([(0, 0), (100, 0), (0, 50), (100, -50), (200, -50), (100, 0)]),
        ),
      );
      // Matched after a scale, and inside a composite that is matched itself
      expect(
        points([
          synthetic.polygon(triangle),
          synthetic.composed([
            synthetic.Component(0),
            synthetic.Component(0, x: 1, y: 2, matched: true, transform: [1.5]),
          ]),
          synthetic.composed([
            synthetic.Component(0, x: 1000),
            synthetic.Component(1, x: 0, y: 5, matched: true),
          ]),
        ]),
        equals(
          placed([
            (1000, 0),
            (1100, 0),
            (1000, 50),
            // Glyph 1, its point 5 at (100, 0) moved to (1000, 0)
            (900, 0),
            (1000, 0),
            (900, 50),
            (1000, -75),
            (1150, -75),
            (1000, 0),
          ]),
        ),
      );
    });

    test('matched point numbers out of range are malformed', () {
      for (final components in [
        [synthetic.Component(0, x: 0, y: 0, matched: true)],
        [
          synthetic.Component(0),
          synthetic.Component(0, x: 3, y: 0, matched: true),
        ],
        [
          synthetic.Component(0),
          synthetic.Component(0, x: 0, y: 3, matched: true),
        ],
      ]) {
        err(
          TTFFont.fromBytes(
            synthetic.font(
              outlines: [
                synthetic.polygon(triangle),
                synthetic.composed(components),
              ],
              glyphs: 2,
            ),
          ),
          ErrorKind.malformed,
        );
      }
    });
  });

  group('Composite glyph budget', () {
    Uint8List chain(final int depth, {final int fanout = 1}) => synthetic.font(
      outlines: [
        synthetic.simple(1),
        for (var level = 1; level <= depth; level++)
          synthetic.composite(List.filled(fanout, level - 1)),
      ],
      glyphs: depth + 1,
    );

    test('a valid composite loads and draws its components', () {
      final bytes = synthetic.font(
        outlines: [
          synthetic.simple(3),
          synthetic.simple(4),
          synthetic.composite([1, 0], dx: 10),
        ],
        glyphs: 3,
      );
      final font = ok(TTFFont.fromBytes(bytes));
      expect(font.outline(2, 1000).commands, isNotEmpty);
    });

    test('a glyph that refers to itself is malformed', () {
      final bytes = synthetic.font(
        outlines: [
          synthetic.simple(1),
          synthetic.composite([1]),
        ],
        glyphs: 2,
      );
      err(TTFFont.fromBytes(bytes), ErrorKind.malformed);
    });

    test('glyphs that refer to each other are malformed', () {
      final bytes = synthetic.font(
        outlines: [
          synthetic.simple(1),
          synthetic.composite([2]),
          synthetic.composite([1]),
        ],
        glyphs: 3,
      );
      err(TTFFont.fromBytes(bytes), ErrorKind.malformed);
    });

    test('fan-out of depth 30 returns a limit error promptly', () {
      final watch = Stopwatch()..start();
      err(TTFFont.fromBytes(chain(30, fanout: 2)), ErrorKind.limit);
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });

    test('a chain of 60000 composites returns a limit error', () {
      // Glyph 1 refers to glyph 2, which refers to glyph 3, and so on, so
      // expanding glyph 1 descends the whole chain unless the depth is
      // checked on the way down
      final bytes = synthetic.font(
        outlines: [
          synthetic.simple(1),
          for (var glyph = 1; glyph < 60000; glyph++)
            synthetic.composite([glyph + 1 < 60000 ? glyph + 1 : 0]),
        ],
        glyphs: 60000,
      );
      err(TTFFont.fromBytes(bytes), ErrorKind.limit);
    });

    test('fan-out within the depth limit is bounded by the points limit', () {
      err(TTFFont.fromBytes(chain(9, fanout: 4)), ErrorKind.limit);
    });

    test('custom limits apply', () {
      err(
        TTFFont.fromBytes(chain(4), limits: Limits(depth: 3)),
        ErrorKind.limit,
      );
      ok(TTFFont.fromBytes(chain(4), limits: Limits(depth: 4)));
      // Glyph 1 is two references to glyph 0 and its point: 2 * (1 + 1) = 4.
      // Glyph 2 is two references to glyph 1: 2 * (1 + 4) = 10
      err(
        TTFFont.fromBytes(chain(2, fanout: 2), limits: Limits(points: 9)),
        ErrorKind.limit,
      );
      ok(TTFFont.fromBytes(chain(2, fanout: 2), limits: Limits(points: 10)));
    });

    test('the default limits are depth 16 and 65536 points', () {
      expect(const Limits().depth, equals(16));
      expect(const Limits().points, equals(65536));
    });
  });

  group('Limits on every font loader', () {
    const path = 'test/fixtures/fonts/DejaVuSans.ttf';
    const small = Limits(font: 100);

    test('TTFFont.loadFromFile applies its limits', () async {
      err(
        await TTFFont.load(path, filesystem: filesystem, limits: small),
        ErrorKind.limit,
      );
    });

    test('FontFallbackChain.load applies its limits', () async {
      final chain = FontFallbackChain();
      err(
        await chain.load(path, filesystem: filesystem, limits: small),
        ErrorKind.limit,
      );
      expect(chain.primary, isNull);
    });

    test('the engine loads fonts within its own limits', () async {
      final engine = GraphicsEngine(10, 10, filesystem: filesystem);
      final current = ok(engine.readFont(File(path).readAsBytesSync()));

      final limited = GraphicsEngine(
        10,
        10,
        filesystem: filesystem,
        limits: small,
      );
      err(limited.readFont(File(path).readAsBytesSync()), ErrorKind.limit);
      err(await limited.loadFont(path), ErrorKind.limit);
      expect(limited.font, isNull);
      expect(engine.font, same(current));
    });
  });

  group('Table directory bounds', () {
    test('a table count larger than the file is malformed', () {
      err(TTFFont.fromBytes(_sfnt(65535, [])), ErrorKind.malformed);
    });

    test('a table extending past the end of the file is truncated', () {
      final bytes = _sfnt(1, [_record('head', 28, 54)]);
      final details = err(TTFFont.fromBytes(bytes), ErrorKind.truncated);
      expect('${details.cause}', contains('head'));
    });

    test('a table reader cannot read past its table', () {
      // The head table claims 10 bytes; the file has 54 after it
      final bytes = Uint8List.fromList([
        ..._sfnt(1, [_record('head', 28, 10)]),
        ...List.filled(54, 0),
      ]);
      err(TTFFont.fromBytes(bytes), ErrorKind.truncated);
    });

    test('a font file over the size limit returns a limit error', () {
      final bytes = File(
        'test/fixtures/fonts/DejaVuSans.ttf',
      ).readAsBytesSync();
      err(
        TTFFont.fromBytes(bytes, limits: Limits(font: bytes.length - 1)),
        ErrorKind.limit,
      );
      ok(TTFFont.fromBytes(bytes, limits: Limits(font: bytes.length)));
    });

    test('the default limit is 64 MiB', () {
      expect(const Limits().font, equals(64 << 20));
    });
  });

  group('Glyph records and loca', () {
    /// Glyph 0 is a three-point triangle and glyph 1 a one-point glyph.
    Uint8List triangle() => synthetic.font(
      outlines: [synthetic.simple(3), synthetic.simple(1)],
      glyphs: 2,
    );

    /// [bytes] with entry [index] of the long-format loca table set to
    /// [offset].
    Uint8List locate(final Uint8List bytes, final int index, final int offset) {
      final data = ByteData.sublistView(bytes);
      for (var record = 12; ; record += 16) {
        if (String.fromCharCodes(bytes, record, record + 4) == 'loca') {
          data.setUint32(data.getUint32(record + 8) + index * 4, offset);
          return bytes;
        }
      }
    }

    test('a record that ends before its contour end points is truncated', () {
      // Glyph 0 is a header claiming one contour with no room for its end
      // point, so the end point would be read from glyph 1
      final bytes = synthetic.font(
        outlines: [
          (ByteData(10)..setInt16(0, 1)).buffer.asUint8List(),
          synthetic.simple(3),
        ],
        glyphs: 2,
      );
      err(TTFFont.fromBytes(bytes), ErrorKind.truncated);
    });

    test('decreasing loca offsets are malformed', () {
      final length = synthetic.simple(3).length;
      // Glyph 1 would end before it starts
      err(
        TTFFont.fromBytes(locate(triangle(), 2, length - 2)),
        ErrorKind.malformed,
      );
    });

    test('a loca offset past the glyf table is malformed', () {
      final end = synthetic.simple(3).length + synthetic.simple(1).length;
      err(
        TTFFont.fromBytes(locate(triangle(), 2, end + 4)),
        ErrorKind.malformed,
      );
    });

    test('loca offsets up to the end of the glyf table load', () {
      final font = ok(TTFFont.fromBytes(triangle()));
      expect(font.outline(0, 1000).commands, isNotEmpty);
    });
  });

  group('Glyph outlines at load', () {
    /// A font whose glyph 0 is [record] and glyph 1 a one-point glyph.
    Uint8List font(final List<int> record) => synthetic.font(
      outlines: [Uint8List.fromList(record), synthetic.simple(1)],
      glyphs: 2,
    );

    /// A font whose glyph 0 is a simple glyph with [ends] as its contour end
    /// points, followed by [rest]: instructions, flags and coordinates.
    Uint8List glyph(final List<int> ends, final List<int> rest) => font([
      ...[0, ends.length, 0, 0, 0, 0, 0, 0, 0, 0],
      for (final end in ends) ...[end >> 8, end & 0xFF],
      ...rest,
    ]);

    test('a record whose coordinates end early is truncated', () {
      // Three points whose flags call for an int16 x and y each
      final bytes = glyph([2], [0, 0, 0x01, 0x01, 0x01]);
      err(TTFFont.fromBytes(bytes), ErrorKind.truncated);
    });

    test('instructions running past the record are truncated', () {
      err(TTFFont.fromBytes(glyph([0], [0, 8, 0x31])), ErrorKind.truncated);
    });

    test('flags that repeat past the last point are malformed', () {
      // Three points, but the first flag repeats three more times
      final bytes = glyph([2], [0, 0, 0x39, 3]);
      err(TTFFont.fromBytes(bytes), ErrorKind.malformed);
    });

    test('end points that do not increase are malformed', () {
      final bytes = glyph([2, 2], [0, 0, 0x39, 2]);
      err(TTFFont.fromBytes(bytes), ErrorKind.malformed);
    });

    test('a composite whose arguments run past its record is truncated', () {
      // One component with word arguments (flag 0x0001), but no arguments
      final bytes = font([0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1]);
      err(TTFFont.fromBytes(bytes), ErrorKind.truncated);
    });

    test('a complete record with repeated flags loads and draws', () {
      // Three points whose flags repeat and whose x and y are bytes
      final bytes = glyph([2], [0, 0, 0x3F, 2, 10, 20, 30, 40, 50, 60]);
      final loaded = ok(TTFFont.fromBytes(bytes));
      expect(loaded.decodes, equals(0), reason: 'loading decodes no outlines');
      // A move, two lines and a close
      expect(loaded.outline(0, 1000).commands, hasLength(4));
    });
  });

  group('TTF Parsing Tests with Real Fonts', () {
    late List<File> fontFiles;

    setUpAll(() async {
      // Get all TTF files from test/fixtures/fonts directory
      final fontsDir = Directory('test/fixtures/fonts');
      expect(
        fontsDir.existsSync(),
        isTrue,
        reason: 'test/fixtures/fonts directory should exist',
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
        final font = ok(
          await TTFFont.load(fontFile.path, filesystem: filesystem),
        );

        // Basic validation
        expect(font.family, isNotEmpty);
        expect(font.style, isNotEmpty);
        expect(font.unitsPerEm, greaterThan(0));
        expect(
          font.unitsPerEm,
          lessThanOrEqualTo(16384),
        ); // Reasonable TTF limit

        print('  Family: ${font.family}');
        print('  Style: ${font.style}');
        print('  Units per Em: ${font.unitsPerEm}');
      }
    });

    test('font metrics are properly parsed', () async {
      for (final fontFile in fontFiles) {
        final font = ok(
          await TTFFont.load(fontFile.path, filesystem: filesystem),
        );
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

        print('Font: ${font.family}');
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
        final font = ok(
          await TTFFont.load(fontFile.path, filesystem: filesystem),
        );

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
          final hasGlyph = font.covers(charCode);
          final glyphIndex = font.glyph(charCode);

          if (hasGlyph) {
            expect(glyphIndex, greaterThan(0));
          } else {
            expect(glyphIndex, equals(0)); // Missing glyph should return 0
          }

          // Test glyph metrics for existing glyphs
          if (glyphIndex > 0) {
            final glyphMetrics = font.dimensions(glyphIndex);
            expect(glyphMetrics.advanceWidth, greaterThanOrEqualTo(0));
            expect(glyphMetrics.boundingBox.width, greaterThanOrEqualTo(0));
            expect(glyphMetrics.boundingBox.height, greaterThanOrEqualTo(0));
          }
        }

        print('Font: ${font.family} - Character mapping tests passed');
      }
    });

    test('glyph path generation works', () async {
      for (final fontFile in fontFiles) {
        final font = ok(
          await TTFFont.load(fontFile.path, filesystem: filesystem),
        );

        // Test generating paths for common characters
        final testChars = ['A', 'B', 'O', 'a', 'o', '0'];

        for (final char in testChars) {
          final charCode = char.codeUnitAt(0);
          if (font.covers(charCode)) {
            final glyphIndex = font.glyph(charCode);
            final path = font.outline(glyphIndex, 100.0); // 100pt font size

            // Skip color emoji fonts as they may not have traditional path data
            if (font.family.toLowerCase().contains('emoji') ||
                font.family.toLowerCase().contains('color')) {
              print('Skipping path check for emoji font: ${font.family}');
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
              'Font: ${font.family}, Char: $char, Commands: ${path.commands.length}',
            );
          }
        }
      }
    });

    test('text measurement works correctly', () async {
      for (final fontFile in fontFiles) {
        final font = ok(
          await TTFFont.load(fontFile.path, filesystem: filesystem),
        );

        final testTexts = ['Hello', 'World', 'ABC', 'abc', '123', 'Test Text'];

        for (final text in testTexts) {
          final metrics = font.measure(text, 24.0);

          expect(metrics.width, greaterThan(0));
          expect(metrics.height, greaterThan(0));
          expect(metrics.ascent, greaterThan(0));
          expect(
            metrics.descent,
            greaterThanOrEqualTo(0),
          ); // Can be 0 for some fonts
          expect(metrics.lineHeight, greaterThan(0));

          print('Font: ${font.family}, Text: "$text"');
          print('  Width: ${metrics.width.toStringAsFixed(2)}px');
          print('  Height: ${metrics.height.toStringAsFixed(2)}px');
          print('  Ascent: ${metrics.ascent.toStringAsFixed(2)}px');
          print('  Descent: ${metrics.descent.toStringAsFixed(2)}px');
        }
      }
    });

    test('text path generation works', () async {
      for (final fontFile in fontFiles) {
        final font = ok(
          await TTFFont.load(fontFile.path, filesystem: filesystem),
        );

        final testText = 'Hello';
        final textPath = font.path(testText, 0, 0, 48.0);

        // Text path should have commands
        expect(textPath.commands.length, greaterThan(0));

        // Should have moveTo commands for positioning glyphs
        final moveToCommands = textPath.commands
            .where((cmd) => cmd.type.toString().contains('moveTo'))
            .length;
        expect(moveToCommands, greaterThan(0));

        print('Font: ${font.family}, Text: "$testText"');
        print('  Total path commands: ${textPath.commands.length}');
        print('  MoveTo commands: $moveToCommands');
      }
    });

    test('kerning works when available', () async {
      for (final fontFile in fontFiles) {
        final font = ok(
          await TTFFont.load(fontFile.path, filesystem: filesystem),
        );

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

          if (font.covers(leftChar) && font.covers(rightChar)) {
            final leftGlyph = font.glyph(leftChar);
            final rightGlyph = font.glyph(rightChar);

            final kerning = font.kerning(leftGlyph, rightGlyph, 24.0);

            // Kerning can be positive, negative, or zero
            expect(kerning, isA<double>());

            if (kerning != 0.0) {
              print(
                'Font: ${font.family}, Pair: ${pair[0]}${pair[1]}, Kerning: ${kerning.toStringAsFixed(2)}px',
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
          final font = ok(
            await TTFFont.load(fontFile.path, filesystem: filesystem),
          );

          expect(font.family.toLowerCase(), contains('google'));
          expect(
            font.unitsPerEm,
            greaterThan(0),
          ); // Google fonts use various UPM values

          // Should support basic ASCII
          expect(font.covers(65), isTrue); // 'A'
          expect(font.covers(97), isTrue); // 'a'
          expect(font.covers(48), isTrue); // '0'

          print('Google font: ${font.name}');
        }
      });

      test('Radley fonts have expected properties', () async {
        final radleyFonts = fontFiles
            .where((f) => f.path.contains('Radley'))
            .toList();

        for (final fontFile in radleyFonts) {
          final font = ok(
            await TTFFont.load(fontFile.path, filesystem: filesystem),
          );

          expect(font.family.toLowerCase(), contains('radley'));

          // Should support basic ASCII
          expect(font.covers(65), isTrue); // 'A'
          expect(font.covers(97), isTrue); // 'a'

          print('Radley font: ${font.name}');
        }
      });
    });

    test('font comparison - different fonts have different metrics', () async {
      if (fontFiles.length >= 2) {
        final font1 = ok(
          await TTFFont.load(fontFiles[0].path, filesystem: filesystem),
        );
        final font2 = ok(
          await TTFFont.load(fontFiles[1].path, filesystem: filesystem),
        );

        // Different fonts should have different family names (unless variants)
        final sameFamily = font1.family == font2.family;

        // Measure same text with both fonts
        final text = 'Hello World';
        final metrics1 = font1.measure(text, 24.0);
        final metrics2 = font2.measure(text, 24.0);

        print('Comparing fonts:');
        print('  ${font1.name}: ${metrics1.width.toStringAsFixed(2)}px wide');
        print('  ${font2.name}: ${metrics2.width.toStringAsFixed(2)}px wide');

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

/// An sfnt header declaring [count] tables, followed by [records].
Uint8List _sfnt(final int count, final List<List<int>> records) {
  final header = ByteData(12)
    ..setUint32(0, 0x00010000)
    ..setUint16(4, count);
  return Uint8List.fromList([
    ...header.buffer.asUint8List(),
    for (final record in records) ...record,
  ]);
}

/// A table directory record for [tag] at [offset] with [length] bytes.
List<int> _record(final String tag, final int offset, final int length) {
  final record = ByteData(16)
    ..setUint32(8, offset)
    ..setUint32(12, length);
  final bytes = record.buffer.asUint8List();
  bytes.setRange(0, 4, tag.codeUnits);
  return bytes;
}

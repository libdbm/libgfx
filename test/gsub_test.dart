import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/fonts/font.dart' show GlyphBoundingBox, GlyphMetrics;
import 'package:libgfx/src/fonts/ttf/gsub.dart';
import 'package:libgfx/src/fonts/ttf/ttf_parser.dart';
import 'package:test/test.dart';

import 'support/results.dart';

void main() {
  Uint8List read(final String name) =>
      File('test/fixtures/fonts/$name.ttf').readAsBytesSync();
  const wanted = {'ccmp', 'liga'};

  group('GSUB ligatures in real fonts', () {
    test('two regional indicators make a flag', () {
      final font = ok(TTFFont.fromBytes(read('NotoEmoji-Regular')));
      final united = font.glyph(0x1F1FA);
      final states = font.glyph(0x1F1F8);
      expect([united, states], isNot(contains(0)));
      // flagUnitedStates, by fontTools
      expect(font.ligate([united, states]), equals([(1857, 2)]));
      expect(font.ligate([united]), equals([(united, 1)]));
    });

    test('the longest Latin ligature wins', () {
      final font = ok(TTFFont.fromBytes(read('NotoSans-Regular')));
      final f = font.glyph('f'.codeUnitAt(0));
      final i = font.glyph('i'.codeUnitAt(0));
      final l = font.glyph('l'.codeUnitAt(0));
      // f_f_i, fi and fl, by fontTools
      expect(font.ligate([f, f, i]), equals([(1656, 3)]));
      expect(font.ligate([f, i, l]), equals([(1654, 2), (l, 1)]));
      expect(font.ligate([l, f, l]), equals([(l, 1), (1655, 2)]));
    });
  });

  group('Ligatures in the shaper', () {
    List<ShapedGlyph> shape(
      final Font font,
      final String text, [
      final TextDirection direction = TextDirection.auto,
    ]) => BasicTextShaper().shape(text, font, 16, direction: direction).glyphs;

    test('a flag and an emoji shape to their glyphs', () {
      final font = ok(TTFFont.fromBytes(read('NotoEmoji-Regular')));
      expect(shape(font, '🇺🇸').map((glyph) => glyph.glyph), equals([1857]));
      expect(
        shape(font, '😀').map((glyph) => glyph.glyph),
        equals([font.glyph(0x1F600)]),
      );
    });

    test('a Latin ligature takes its own advance and the first cluster', () {
      final font = ok(TTFFont.fromBytes(read('NotoSans-Regular')));
      final glyphs = shape(font, 'xfi');
      expect(glyphs.map((glyph) => glyph.glyph), [font.glyph(0x78), 1654]);
      expect(glyphs.map((glyph) => glyph.cluster), [0, 1]);
      expect(
        glyphs.last.xAdvance,
        closeTo(
          font.dimensions(1654).advanceWidth / font.unitsPerEm * 16,
          1e-9,
        ),
      );
    });

    test('a right-to-left ligature keeps its place in visual order', () {
      // א and ב ligate; the run reads right to left, so ג is drawn first
      final glyphs = shape(_Ligating(), 'אבג', TextDirection.rtl);
      expect(glyphs.map((glyph) => glyph.glyph), [0x5D2, 999]);
      expect(glyphs.map((glyph) => glyph.cluster), [2, 0]);
    });
  });

  group('GSUB structure', () {
    test('extension lookups apply; other types and features do not', () {
      final gsub = Gsub.parse(_table(), wanted, 100, const Limits());
      // 10 11 ligate through the extension; 12 13 only under smcp
      expect(
        gsub.apply([10, 11, 12, 13, 10]),
        equals([(50, 2), (12, 1), (13, 1), (10, 1)]),
      );
    });

    test('a ligature glyph the font does not have is malformed', () {
      expect(
        () => Gsub.parse(_table(), wanted, 50, const Limits()),
        throwsFormatException,
      );
    });

    test('the ligature limit holds', () {
      final data = TTFParser(read('NotoEmoji-Regular')).table('GSUB');
      expect(
        () => Gsub.parse(data, wanted, 2000, const Limits(ligatures: 100)),
        throwsA(isA<ResourceLimitException>()),
      );
      final font = ok(
        TTFFont.fromBytes(
          read('NotoEmoji-Regular'),
          limits: const Limits(ligatures: 100),
        ),
      );
      final pair = [font.glyph(0x1F1FA), font.glyph(0x1F1F8)];
      expect(font.ligate(pair), equals([(pair[0], 1), (pair[1], 1)]));
    });

    test('every prefix of a GSUB table parses or fails cleanly', () {
      final whole = TTFParser(read('NotoEmoji-Regular')).table('GSUB');
      final bytes = whole.buffer.asUint8List(
        whole.offsetInBytes,
        whole.lengthInBytes,
      );
      for (var length = 0; length < bytes.length; length += 97) {
        try {
          Gsub.parse(
            ByteData.sublistView(bytes, 0, length),
            wanted,
            2000,
            const Limits(),
          );
        } on RangeError {
          // expected for most prefixes
        } on FormatException {
          // and for glyph numbers read from the wrong place
        }
      }
    });
  });

  group('GSUB corruption', () {
    for (final name in ['NotoEmoji-Regular', 'GoogleSansCode-Regular']) {
      test('$name loads with any single-byte GSUB corruption', () {
        final bytes = read(name);
        final record = _record(bytes, 'GSUB');
        final data = ByteData.sublistView(bytes);
        final start = data.getUint32(record + 8);
        final length = data.getUint32(record + 12);
        final random = Random(15);
        for (var i = 0; i < 300; i++) {
          final position = i < 64 ? start + i : start + random.nextInt(length);
          final corrupted = Uint8List.fromList(bytes);
          corrupted[position] ^= 1 + random.nextInt(255);
          final font = ok(TTFFont.fromBytes(corrupted));
          font.ligate([font.glyph(0x66), font.glyph(0x69), 3, 4]);
        }
      });
    }
  });
}

/// The table record of [tag] in the font [bytes]
int _record(final Uint8List bytes, final String tag) {
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < data.getUint16(4); i++) {
    if (String.fromCharCodes(bytes, 12 + i * 16, 16 + i * 16) == tag) {
      return 12 + i * 16;
    }
  }
  throw StateError('No $tag table');
}

/// A GSUB table whose DFLT script lists two features: liga, with an
/// extension lookup ligating 10 11 to 50 and a single substitution lookup,
/// and smcp, with a ligature lookup of 12 13 to 51
ByteData _table() {
  Uint8List words(final List<int> values) {
    final data = ByteData(values.length * 2);
    for (var i = 0; i < values.length; i++) {
      data.setUint16(i * 2, values[i]);
    }
    return data.buffer.asUint8List();
  }

  // Ligature substitution: header, ligature set, ligature, coverage
  Uint8List ligature(final int first, final int second, final int glyph) =>
      words([1, 18, 1, 8, 1, 4, glyph, 2, second, 1, 1, first]);
  Uint8List lookup(final int type, final Uint8List subtable) =>
      Uint8List.fromList([
        ...words([type, 0, 1, 8]),
        ...subtable,
      ]);
  Uint8List extension(final Uint8List subtable) => Uint8List.fromList([
    ...words([1, 4, 0, 8]),
    ...subtable,
  ]);

  final lookups = [
    lookup(7, extension(ligature(10, 11, 50))),
    lookup(1, words([1, 6, 5, 1, 1, 10])), // single substitution, skipped
    lookup(4, ligature(12, 13, 51)),
  ];
  final scripts = Uint8List.fromList([
    ...words([1]),
    ...'DFLT'.codeUnits,
    ...words([8, 4, 0, 0, 0xFFFF, 2, 0, 1]),
  ]);
  final features = Uint8List.fromList([
    ...words([2]),
    ...'liga'.codeUnits,
    ...words([14]),
    ...'smcp'.codeUnits,
    ...words([22, 0, 2, 0, 1, 0, 1, 2]),
  ]);
  var offset = 2 + lookups.length * 2;
  final offsets = <int>[];
  for (final each in lookups) {
    offsets.add(offset);
    offset += each.length;
  }
  final list = Uint8List.fromList([
    ...words([lookups.length, ...offsets]),
    for (final each in lookups) ...each,
  ]);
  final header = words([
    1,
    0,
    10,
    10 + scripts.length,
    10 + scripts.length + features.length,
  ]);
  return ByteData.sublistView(
    Uint8List.fromList([...header, ...scripts, ...features, ...list]),
  );
}

/// A font that maps every code point to itself and ligates א ב to 999
class _Ligating extends Font {
  @override
  String get family => 'Ligating';
  @override
  String get style => 'Regular';
  @override
  int get unitsPerEm => 1000;
  @override
  bool covers(final int codePoint) => true;
  @override
  int glyph(final int codePoint) => codePoint;
  @override
  GlyphMetrics dimensions(final int glyph) => const GlyphMetrics(
    advanceWidth: 500,
    advanceHeight: 0,
    leftSideBearing: 0,
    topSideBearing: 0,
    boundingBox: GlyphBoundingBox(xMin: 0, yMin: 0, xMax: 500, yMax: 700),
  );
  @override
  double kerning(final int left, final int right, final double size) => 0;
  @override
  TextMetrics measure(final String text, final double size) =>
      TextMetrics(width: 0, height: 0, ascent: 0, descent: 0, lineHeight: 0);
  @override
  List<(int, int)> ligate(final List<int> glyphs) {
    final result = <(int, int)>[];
    for (var i = 0; i < glyphs.length; i++) {
      if (glyphs[i] == 0x5D0 &&
          i + 1 < glyphs.length &&
          glyphs[i + 1] == 0x5D1) {
        result.add((999, 2));
        i++;
      } else {
        result.add((glyphs[i], 1));
      }
    }
    return result;
  }

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      throw UnimplementedError();
}

import 'dart:io';
import 'dart:typed_data';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/fonts/ttf/ttf_parser.dart';
import 'package:test/test.dart';

import 'support/fonts.dart' as synthetic;
import 'support/results.dart';

void main() {
  group('cmap subtable choice', () {
    test('a full-repertoire subtable wins over a BMP one before it', () {
      final font = ok(
        TTFFont.fromBytes(
          synthetic.font(
            cmaps: [
              (0, 3, _format4(0x20, 0x7E, 1)),
              (3, 10, _format12([(0x20, 0x7E, 1), (0x1F600, 0x1F64F, 200)])),
            ],
          ),
        ),
      );
      expect(font.glyph(0x1F600), equals(200));
      expect(font.glyph(0x41), equals(34));
    });

    test('a BMP subtable alone still maps', () {
      final font = ok(
        TTFFont.fromBytes(
          synthetic.font(cmaps: [(3, 1, _format4(0x20, 0x7E, 1))]),
        ),
      );
      expect(font.glyph(0x41), equals(34));
      expect(font.glyph(0x1F600), equals(0));
    });

    test('a real font maps emoji', () {
      final font = ok(
        TTFFont.fromBytes(
          File('test/fixtures/fonts/DejaVuSans.ttf').readAsBytesSync(),
        ),
      );
      expect(font.covers(0x1F600), isTrue);
      expect(font.covers(0x41), isTrue);
    });
  });

  group('cmap format 12', () {
    test('one group covering every code point loads quickly', () {
      final bytes = synthetic.font(
        cmap: _format12([(0, 0x10FFFF, 1)]),
        glyphs: 65535,
      );
      // The first load compiles the parser; time the second
      ok(TTFFont.fromBytes(bytes));
      final watch = Stopwatch()..start();
      final font = ok(TTFFont.fromBytes(bytes));
      expect(watch.elapsedMilliseconds, lessThan(10));
      expect(font.glyph(0), equals(1));
      expect(font.glyph(0x41), equals(0x42));
      expect(font.glyph(65533), equals(65534));
    });

    test('glyph ids at or above numGlyphs are missing', () {
      final font = ok(
        TTFFont.fromBytes(
          synthetic.font(cmap: _format12([(0, 0x10FFFF, 1)]), glyphs: 100),
        ),
      );
      expect(font.glyph(98), equals(99));
      expect(font.glyph(99), equals(0));
      expect(font.glyph(0x10FFFF), equals(0));
      expect(font.covers(99), isFalse);
    });

    test('unsorted groups map by binary search, gaps are missing', () {
      final font = ok(
        TTFFont.fromBytes(
          synthetic.font(
            cmap: _format12([
              (0x1F600, 0x1F64F, 300),
              (0x20, 0x7E, 1),
              (0x400, 0x4FF, 100),
            ]),
          ),
        ),
      );
      expect(font.glyph(0x20), equals(1));
      expect(font.glyph(0x7E), equals(95));
      expect(font.glyph(0x7F), equals(0));
      expect(font.glyph(0x410), equals(116));
      expect(font.glyph(0x1F64F), equals(379));
      expect(font.glyph(0x1F650), equals(0));
      expect(font.glyph(0x1F), equals(0));
    });

    test('a group count beyond the subtable length is clamped', () {
      final font = ok(
        TTFFont.fromBytes(
          synthetic.font(cmap: _format12([(0x20, 0x7E, 1)], count: 1000000)),
        ),
      );
      expect(font.glyph(0x41), equals(34));
    });

    test('a real font maps every code point as the expanded table did', () {
      final bytes = File(
        'test/fixtures/fonts/DejaVuSans.ttf',
      ).readAsBytesSync();
      final cmap = TTFParser(bytes).readCmapTable();
      final subtables = cmap.subtables.where((each) => each.format == 12);
      expect(subtables, isNotEmpty);
      final expected = _expand(bytes);
      for (final subtable in subtables) {
        for (var code = 0; code <= 0x10FFFF; code++) {
          if (subtable.glyph(code) != (expected[code] ?? 0)) {
            fail(
              'code point $code: ${subtable.glyph(code)} != ${expected[code]}',
            );
          }
        }
      }
    });
  });
}

/// The format 12 mapping of [bytes] built the way the parser used to: one
/// map entry per code point of each group of the first format 12 subtable.
Map<int, int> _expand(final Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var cmap = 0;
  for (var i = 0; i < data.getUint16(4); i++) {
    if (String.fromCharCodes(bytes, 12 + i * 16, 16 + i * 16) == 'cmap') {
      cmap = data.getUint32(20 + i * 16);
    }
  }
  final map = <int, int>{};
  for (var i = 0; i < data.getUint16(cmap + 2); i++) {
    final start = cmap + data.getUint32(cmap + 8 + i * 8);
    if (data.getUint16(start) != 12) continue;
    for (var group = 0; group < data.getUint32(start + 12); group++) {
      final offset = start + 16 + group * 12;
      final first = data.getUint32(offset);
      for (var code = first; code <= data.getUint32(offset + 4); code++) {
        map[code] = data.getUint32(offset + 8) + code - first;
      }
    }
    break;
  }
  return map;
}

/// A format 4 subtable mapping [first] to [last] to glyphs from [glyph] on,
/// with the closing segment format 4 requires.
Uint8List _format4(final int first, final int last, final int glyph) {
  final data = ByteData(14 + 2 * 4 * 2 + 2)
    ..setUint16(0, 4)
    ..setUint16(2, 14 + 2 * 4 * 2 + 2)
    ..setUint16(6, 4) // two segments
    ..setUint16(14, last) // end codes
    ..setUint16(16, 0xFFFF)
    ..setUint16(20, first) // start codes, after the pad
    ..setUint16(22, 0xFFFF)
    ..setUint16(24, (glyph - first) & 0xFFFF) // deltas
    ..setUint16(26, 1);
  return data.buffer.asUint8List();
}

/// A format 12 subtable with [groups] of (start, end, glyph). [count]
/// overrides the declared number of groups.
Uint8List _format12(final List<(int, int, int)> groups, {final int? count}) {
  final data = ByteData(16 + groups.length * 12)
    ..setUint16(0, 12)
    ..setUint32(4, 16 + groups.length * 12)
    ..setUint32(12, count ?? groups.length);
  for (var i = 0; i < groups.length; i++) {
    final (start, end, glyph) = groups[i];
    data
      ..setUint32(16 + i * 12, start)
      ..setUint32(20 + i * 12, end)
      ..setUint32(24 + i * 12, glyph);
  }
  return data.buffer.asUint8List();
}

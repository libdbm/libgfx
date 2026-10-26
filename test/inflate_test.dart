import 'dart:io' show ZLibEncoder, ZLibOption;
import 'dart:math';
import 'dart:typed_data';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/image/codecs/inflate.dart';
import 'package:test/test.dart';

void main() {
  final text = 'The quick brown fox jumps over the lazy dog. '.codeUnits;

  group('Stored blocks', () {
    test('two stored blocks decode', () {
      final stream = _zlib(
        [
          ..._stored([1, 2, 3], last: false),
          ..._stored([4, 5], last: true),
        ],
        [1, 2, 3, 4, 5],
      );
      expect(inflate(stream, limit: 100), equals([1, 2, 3, 4, 5]));
    });

    test('a length that does not match its complement is malformed', () {
      final block = _stored([1, 2, 3], last: true)..[3] ^= 1;
      expect(
        () => inflate(_zlib(block, [1, 2, 3]), limit: 100),
        throwsFormatException,
      );
    });
  });

  group('Fixed Huffman blocks', () {
    test('text with repeats decodes', () {
      final data = [for (var i = 0; i < 50; i++) ...text, ...'end'.codeUnits];
      final stream = _fixed(data);
      expect((stream[2] >> 1) & 3, equals(1), reason: 'fixed Huffman block');
      expect(inflate(stream, limit: data.length), equals(data));
    });

    test('a run copies overlapping output', () {
      final data = List.filled(100000, 0x61);
      expect(inflate(_fixed(data), limit: data.length), equals(data));
    });

    test('every byte value decodes', () {
      final data = [for (var i = 0; i < 3000; i++) (i * 7 + i ~/ 256) & 0xFF];
      expect(inflate(_fixed(data), limit: data.length), equals(data));
    });

    test('an empty stream decodes to nothing', () {
      expect(inflate(_fixed([]), limit: 0), isEmpty);
    });

    test('a distance before the start of the output is malformed', () {
      // Length 3 (code 257) at distance 1 with no output yet
      final bits = _Bits()
        ..add(1, 1)
        ..add(1, 2)
        ..code(1, 7)
        ..code(0, 5)
        ..code(0, 7);
      final stream = _zlib(bits.bytes, []);
      expect(() => inflate(stream, limit: 100), throwsFormatException);
    });
  });

  group('Dynamic Huffman blocks', () {
    test('level 9 text decodes', () {
      final data = [for (var i = 0; i < 50; i++) ...text, ...'end'.codeUnits];
      final stream = _deflate(data, 9);
      expect((stream[2] >> 1) & 3, equals(2), reason: 'dynamic Huffman block');
      expect(inflate(stream, limit: data.length), equals(data));
    });

    test('a large stream of several blocks decodes', () {
      var seed = 1;
      final data = Uint8List(300000);
      for (var i = 0; i < data.length; i++) {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
        data[i] = ((i >> 6) + (seed >> 28)) & 0xFF;
      }
      expect(inflate(_deflate(data, 6), limit: data.length), equals(data));
    });

    // Code-length code symbols used below: with lengths {1: 1, 18: 1},
    // code 0 is symbol 1 and code 1 is symbol 18 (11 + 7 extra bits zeros)
    final invalid = <String, (String, void Function(_Bits))>{
      'an over-subscribed code-length code': (
        'code-length code',
        (bits) => _dynamic(bits, 257, 1, {for (var i = 0; i < 19; i++) i: 1}),
      ),
      'an incomplete code-length code': (
        'code-length code',
        (bits) => _dynamic(bits, 257, 1, {16: 2}),
      ),
      'a repeat with no previous length': (
        'Repeat with no length',
        (bits) {
          _dynamic(bits, 257, 1, {0: 1, 16: 1});
          bits.code(1, 1); // 16
        },
      ),
      'a repeat past the end of the lengths': (
        'past the end',
        (bits) {
          _dynamic(bits, 257, 1, {1: 1, 18: 1});
          bits
            ..code(1, 1)
            ..add(127, 7) // 138 zeros
            ..code(1, 1)
            ..add(127, 7); // 276 > 258
        },
      ),
      'no end-of-block code': (
        'end-of-block',
        (bits) {
          _dynamic(bits, 257, 1, {1: 1, 18: 1});
          bits
            ..code(1, 1)
            ..add(127, 7) // 138 zeros
            ..code(1, 1)
            ..add(108, 7) // 119 zeros: symbols 0 to 256
            ..code(0, 1); // distance code of length 1
        },
      ),
      'an over-subscribed literal/length code': (
        'over-subscribed Huffman code',
        (bits) {
          _dynamic(bits, 257, 1, {1: 1, 18: 1});
          bits
            ..code(0, 1)
            ..code(0, 1) // symbols 0 and 1
            ..code(1, 1)
            ..add(127, 7) // 138 zeros
            ..code(1, 1)
            ..add(105, 7) // 116 zeros: symbols 2 to 255
            ..code(0, 1) // symbol 256: a third code of length 1
            ..code(0, 1); // distance code
        },
      ),
      'more than 286 literal/length codes': (
        'Too many deflate codes',
        (bits) => _dynamic(bits, 287, 1, {1: 1, 18: 1}),
      ),
    };
    for (final MapEntry(key: name, value: (message, write))
        in invalid.entries) {
      test('$name is malformed', () {
        final bits = _Bits();
        write(bits);
        expect(
          () => inflate(_zlib([...bits.bytes, 0, 0, 0, 0], []), limit: 1000),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains(message),
            ),
          ),
        );
      });
    }
  });

  group('Empty distance code', () {
    // A dynamic block with literal/length lengths A (65): 1, end of block
    // (256): 2, length 3 (257): 2, and one distance code of length zero,
    // which RFC 1951 allows for a block that uses no distances. Code-length
    // code {18: 1, 2: 2, 0: 3, 1: 3}: 18 is 0, 2 is 10, 0 is 110, 1 is 111.
    _Bits header() {
      final bits = _Bits();
      _dynamic(bits, 258, 1, {18: 1, 2: 2, 0: 3, 1: 3});
      bits
        ..code(0, 1)
        ..add(54, 7) // 65 zeros: symbols 0 to 64
        ..code(7, 3) // symbol 65: length 1
        ..code(0, 1)
        ..add(127, 7) // 138 zeros
        ..code(0, 1)
        ..add(41, 7) // 52 zeros: symbols 66 to 255
        ..code(2, 2) // symbol 256: length 2
        ..code(2, 2) // symbol 257: length 2
        ..code(6, 3); // the distance code: length 0
      return bits;
    }

    test('a block of literals only decodes', () {
      final bits = header()
        ..code(0, 1)
        ..code(0, 1)
        ..code(0, 1) // A A A
        ..code(2, 2); // end of block
      expect(
        inflate(_zlib(bits.bytes, 'AAA'.codeUnits), limit: 1000),
        equals('AAA'.codeUnits),
      );
    });

    test('a distance with no distance codes is malformed', () {
      final bits = header()
        ..code(0, 1) // A
        ..code(3, 2); // length 3, then a distance it cannot decode
      expect(
        () => inflate(_zlib([...bits.bytes, 0, 0, 0, 0], []), limit: 1000),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Invalid Huffman code'),
          ),
        ),
      );
    });
  });

  group('Stream checks', () {
    test('a wrong Adler-32 checksum is malformed', () {
      final stream = _fixed(text)..last ^= 1;
      expect(() => inflate(stream, limit: 100), throwsFormatException);
    });

    test('invalid zlib headers are malformed', () {
      final stream = _fixed(text);
      for (final header in [
        [0x79, 0x18], // compression method 9
        [0x78, 0x9D], // check bits wrong
        [0x78, 0xBB], // preset dictionary
        [0x88, 0x98], // window over 32K
      ]) {
        final copy = Uint8List.fromList(stream)..setRange(0, 2, header);
        expect(
          () => inflate(copy, limit: 100),
          throwsFormatException,
          reason: '$header',
        );
      }
    });

    test('block type 3 is malformed', () {
      expect(
        () => inflate(_zlib([0x07], []), limit: 100),
        throwsFormatException,
      );
    });

    test('every truncation is a RangeError or FormatException', () {
      final stream = _fixed([for (var i = 0; i < 20; i++) ...text]);
      for (var length = 0; length < stream.length; length++) {
        expect(
          () => inflate(Uint8List.sublistView(stream, 0, length), limit: 2000),
          throwsA(anyOf(isA<RangeError>(), isA<FormatException>())),
          reason: 'prefix of $length bytes',
        );
      }
    });

    test('output over the limit throws ResourceLimitException', () {
      final stream = _fixed(List.filled(1000, 0));
      expect(
        () => inflate(stream, limit: 999),
        throwsA(isA<ResourceLimitException>()),
      );
      expect(inflate(stream, limit: 1000), hasLength(1000));
    });
  });
}

/// [data] compressed with fixed Huffman codes only.
Uint8List _fixed(final List<int> data) => Uint8List.fromList(
  ZLibEncoder(level: 1, strategy: ZLibOption.strategyFixed).convert(data),
);

/// [data] compressed at [level], letting zlib choose the block types.
Uint8List _deflate(final List<int> data, final int level) =>
    Uint8List.fromList(ZLibEncoder(level: level).convert(data));

/// Writes the header of a final dynamic Huffman block with [lengths]
/// literal/length codes, [distances] distance codes, and code-length code
/// [codes] mapping symbol to code length.
void _dynamic(
  final _Bits bits,
  final int lengths,
  final int distances,
  final Map<int, int> codes,
) {
  const order = [
    16,
    17,
    18,
    0,
    8,
    7,
    9,
    6,
    10,
    5,
    11,
    4,
    12,
    3,
    13,
    2,
    14,
    1,
    15,
  ];
  var count = 4;
  for (var i = 0; i < order.length; i++) {
    if ((codes[order[i]] ?? 0) != 0) count = max(count, i + 1);
  }
  bits
    ..add(1, 1)
    ..add(2, 2)
    ..add(lengths - 257, 5)
    ..add(distances - 1, 5)
    ..add(count - 4, 4);
  for (var i = 0; i < count; i++) {
    bits.add(codes[order[i]] ?? 0, 3);
  }
}

/// A stored block holding [data].
List<int> _stored(final List<int> data, {required final bool last}) {
  final length = data.length;
  return [
    last ? 1 : 0,
    length & 0xFF,
    length >> 8,
    ~length & 0xFF,
    (~length >> 8) & 0xFF,
    ...data,
  ];
}

/// A zlib stream of deflate [blocks] whose decompressed content is [data].
Uint8List _zlib(final List<int> blocks, final List<int> data) {
  var a = 1;
  var b = 0;
  for (final byte in data) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  return Uint8List.fromList([
    0x78, 0x01, //
    ...blocks,
    b >> 8, b & 0xFF, a >> 8, a & 0xFF,
  ]);
}

/// Writes a deflate bit stream: values least significant bit first,
/// Huffman codes most significant bit first.
class _Bits {
  final bytes = <int>[];
  var _count = 0;

  void add(final int value, final int length) {
    for (var i = 0; i < length; i++) {
      _bit((value >> i) & 1);
    }
  }

  void code(final int code, final int length) {
    for (var i = length - 1; i >= 0; i--) {
      _bit((code >> i) & 1);
    }
  }

  void _bit(final int bit) {
    if (_count % 8 == 0) bytes.add(0);
    bytes[bytes.length - 1] |= bit << (_count % 8);
    _count++;
  }
}

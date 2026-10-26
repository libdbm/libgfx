import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/image/codecs/bmp_codec.dart';
import 'package:libgfx/src/image/codecs/p3_codec.dart';
import 'package:libgfx/src/image/codecs/p6_codec.dart';
import 'package:libgfx/src/image/codecs/png_codec.dart';
import 'package:libgfx/src/image/image_codec.dart';
import 'package:test/test.dart';

/// Decodes truncated and corrupted copies of valid input and checks that
/// every one returns a [Result]: no exception escapes a decode or load.
void main() {
  final codecs = <String, ImageCodec>{
    'BMP': BmpImageCodec(),
    'P3': P3ImageCodec(),
    'P6': P6ImageCodec(),
    'PNG': PngImageCodec(),
  };
  for (final MapEntry(key: name, value: codec) in codecs.entries) {
    group(name, () {
      final bytes = codec.encode(_image());

      test('every prefix returns a result', () {
        expect(codec.decode(bytes), isA<Ok<Bitmap, ErrorDetails>>());
        _expectResults(_prefixes(bytes), codec.decode);
      });

      test('every single-byte corruption returns a result', () {
        _expectResults(
          _corruptions(bytes, [for (var i = 0; i < bytes.length; i++) i]),
          codec.decode,
        );
      });
    });
  }

  test('PNG corruptions with a valid chunk CRC return a result', () {
    // The CRC rejects nearly every plain corruption; recomputing it reaches
    // the header and decompression checks
    final codec = PngImageCodec();
    final bytes = codec.encode(_image());
    final inputs = _corruptions(bytes, [
      for (var i = 8; i < bytes.length; i++) i,
    ]).map((input) => (input.$1, _recrc(input.$2)));
    _expectResults(inputs, codec.decode);
  });

  for (final name in [
    'rgba8-fixed',
    'rgba8-dynamic',
    'rgb8-mixed',
    'gray1',
    'palette4',
    'rgb16-trns',
    'adam7-gray1-13x11',
    'adam7-rgb8-1x1',
  ]) {
    test('$name.png: prefixes and corruptions return a result', () {
      // The encoder writes stored blocks only; these fixtures reach the
      // Huffman decoders
      final codec = PngImageCodec();
      final bytes = File('test/fixtures/png/$name.png').readAsBytesSync();
      expect(codec.decode(bytes), isA<Ok<Bitmap, ErrorDetails>>());
      _expectResults(_prefixes(bytes), codec.decode);
      final inputs = _corruptions(bytes, [
        for (var i = 8; i < bytes.length; i++) i,
      ]).map((input) => (input.$1, _recrc(input.$2)));
      _expectResults(inputs, codec.decode);
    });
  }

  group('Font', () {
    final bytes = File(
      'test/fixtures/fonts/GoogleSansCode-Regular.ttf',
    ).readAsBytesSync();

    test('every prefix returns a result', () {
      expect(TTFFont.fromBytes(bytes), isA<Ok<TTFFont, ErrorDetails>>());
      _expectResults(_prefixes(bytes), _draw);
    });

    test('single-byte corruptions return a result', () {
      // Every byte of the header and table directory, then a fixed sample
      // of the rest
      final directory = 12 + ByteData.sublistView(bytes).getUint16(4) * 16;
      final random = Random(42);
      final positions = [
        for (var i = 0; i < directory; i++) i,
        for (var i = 0; i < 2000; i++) random.nextInt(bytes.length),
      ];
      _expectResults(_corruptions(bytes, positions), TTFFont.fromBytes);
    });

    test('fonts with corrupted outlines draw every glyph', () {
      // A fixed sample of the outline tables, since every glyph is drawn
      final random = Random(7);
      final positions = [
        for (final tag in ['glyf', 'loca'])
          for (var i = 0; i < 150; i++)
            _table(bytes, tag) + random.nextInt(_length(bytes, tag)),
      ];
      _expectResults(_corruptions(bytes, positions), _draw);
    });
  });
}

/// Loads [bytes] as the font of a small engine and, if it loads, draws every
/// glyph and measures, fills, strokes and clips to some text with it.
Result<TTFFont, ErrorDetails> _draw(final Uint8List bytes) {
  final engine = GraphicsEngine(32, 32);
  final result = engine.readFont(bytes);
  if (result case Ok(value: final font)) {
    for (var glyph = 0; glyph < _glyphs(bytes); glyph++) {
      font.outline(glyph, 16);
    }
    const text = 'Ag{é}';
    engine
      ..measureText(text)
      ..fillText(text, 2, 20)
      ..strokeText(text, 2, 20)
      ..clipText(text, 2, 20);
  }
  return result;
}

/// The glyph count in the `maxp` table of the font [bytes].
int _glyphs(final Uint8List bytes) =>
    ByteData.sublistView(bytes).getUint16(_table(bytes, 'maxp') + 4);

/// The offset of table [tag] in the font [bytes], whose table directory is
/// known to be valid.
int _table(final Uint8List bytes, final String tag) =>
    ByteData.sublistView(bytes).getUint32(_record(bytes, tag) + 8);

/// The length of table [tag] in the font [bytes].
int _length(final Uint8List bytes, final String tag) =>
    ByteData.sublistView(bytes).getUint32(_record(bytes, tag) + 12);

/// The table directory record of [tag] in the font [bytes].
int _record(final Uint8List bytes, final String tag) {
  for (var record = 12; ; record += 16) {
    if (String.fromCharCodes(bytes, record, record + 4) == tag) return record;
  }
}

/// A small image with distinct colours and alpha in every pixel.
Bitmap _image() {
  final image = Bitmap(7, 5);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.plot(
        x,
        y,
        Color.fromRGBA(x * 36, y * 60, (x + y) * 20, 255 - x * y * 5),
      );
    }
  }
  return image;
}

/// Every proper prefix of [bytes], shortest first.
Iterable<(String, Uint8List)> _prefixes(final Uint8List bytes) sync* {
  for (var length = 0; length < bytes.length; length++) {
    yield ('prefix of $length bytes', Uint8List.sublistView(bytes, 0, length));
  }
}

/// Copies of [bytes] with the byte at each of [positions] replaced by 0x00,
/// 0xFF, and its value with the low or high bit flipped.
Iterable<(String, Uint8List)> _corruptions(
  final Uint8List bytes,
  final List<int> positions,
) sync* {
  for (final position in positions) {
    final original = bytes[position];
    for (final value in {0x00, 0xFF, original ^ 0x01, original ^ 0x80}) {
      if (value == original) continue;
      final copy = Uint8List.fromList(bytes)..[position] = value;
      yield ('byte $position set to $value', copy);
    }
  }
  return;
}

/// Runs [decode] on each input and fails, listing the first few, if any
/// throws.
void _expectResults<T>(
  final Iterable<(String, Uint8List)> inputs,
  final Result<T, ErrorDetails> Function(Uint8List) decode,
) {
  final failures = <String>[];
  var count = 0;
  for (final (name, input) in inputs) {
    count++;
    try {
      decode(input);
    } catch (error) {
      failures.add('$name: ${error.runtimeType}: $error');
    }
  }
  expect(
    failures,
    isEmpty,
    reason:
        '${failures.length} of $count inputs threw:\n'
        '${failures.take(10).join('\n')}',
  );
}

/// [png] with the CRC of every chunk recomputed. A corrupted length that
/// runs past the end leaves the rest unchanged.
Uint8List _recrc(final Uint8List png) {
  final data = ByteData.sublistView(png);
  var offset = 8;
  while (offset + 12 <= png.length) {
    final length = data.getUint32(offset);
    final end = offset + 8 + length;
    if (end + 4 > png.length) break;
    data.setUint32(end, _crc(Uint8List.sublistView(png, offset + 4, end)));
    offset = end + 4;
  }
  return png;
}

/// CRC-32 (ISO 3309) of [bytes], as PNG uses.
int _crc(final Uint8List bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = crc & 1 != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

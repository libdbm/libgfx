import 'dart:typed_data';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/image/codecs/p6_codec.dart';
import 'package:test/test.dart';

import 'support/results.dart';

void main() {
  final codec = P6ImageCodec();

  Result<Bitmap, ErrorDetails> decode(
    final String header,
    final List<int> raster, {
    final Limits limits = const Limits(),
  }) => codec.decode(
    Uint8List.fromList([...header.codeUnits, ...raster]),
    limits: limits,
  );

  List<int> rgb(final Color color) => [color.red, color.green, color.blue];

  group('P6ImageCodec', () {
    test('round-trips its own output', () {
      final image = Bitmap(2, 2)
        ..plot(0, 0, Color.fromRGBA(255, 0, 0, 255))
        ..plot(1, 1, Color.fromRGBA(10, 20, 30, 255));
      final decoded = ok(codec.decode(codec.encode(image)));
      expect(rgb(decoded.pixel(0, 0)), equals([255, 0, 0]));
      expect(rgb(decoded.pixel(1, 1)), equals([10, 20, 30]));
    });

    test('a one-line header decodes', () {
      final bitmap = ok(decode('P6 2 1 255\n', [255, 0, 0, 0, 0, 255]));
      expect(rgb(bitmap.pixel(0, 0)), equals([255, 0, 0]));
      expect(rgb(bitmap.pixel(1, 0)), equals([0, 0, 255]));
    });

    test('tabs and a comment before maxval decode', () {
      final bitmap = ok(
        decode('P6\t2\t1\n# maximum value follows\n255\n', [
          255,
          0,
          0,
          0,
          0,
          255,
        ]),
      );
      expect(rgb(bitmap.pixel(0, 0)), equals([255, 0, 0]));
      expect(rgb(bitmap.pixel(1, 0)), equals([0, 0, 255]));
    });

    test('raster bytes that look like whitespace or # are pixels', () {
      final bitmap = ok(decode('P6 1 1 255\n', [0x20, 0x23, 0x0A]));
      expect(rgb(bitmap.pixel(0, 0)), equals([0x20, 0x23, 0x0A]));
    });

    test('samples are scaled by maxval', () {
      final bitmap = ok(decode('P6 1 1 15\n', [15, 8, 0]));
      expect(rgb(bitmap.pixel(0, 0)), equals([255, 136, 0]));
    });

    test('16-bit samples are big-endian and scaled', () {
      final bitmap = ok(
        decode('P6 1 1 65535\n', [0xFF, 0xFF, 0x80, 0x00, 0x00, 0x00]),
      );
      expect(rgb(bitmap.pixel(0, 0)), equals([255, 128, 0]));
    });

    test('a sample above maxval is malformed', () {
      err(decode('P6 1 1 15\n', [16, 0, 0]), ErrorKind.malformed);
      err(
        decode('P6 1 1 1000\n', [0x03, 0xE9, 0, 0, 0, 0]),
        ErrorKind.malformed,
      );
    });

    test('a truncated raster is truncated', () {
      err(decode('P6 2 1 255\n', [1, 2, 3, 4, 5]), ErrorKind.truncated);
      err(decode('P6 1 1 65535\n', [1, 2, 3, 4, 5]), ErrorKind.truncated);
    });

    test('a truncated header is truncated', () {
      err(decode('P6 2 1', []), ErrorKind.truncated);
      err(decode('P6 2 1 255', []), ErrorKind.truncated);
    });

    test('a truncated raster is truncated before allocating', () {
      // These limits let 100000 x 100000 through, but the Bitmap
      // constructor rejects it, so allocating first would throw
      err(
        decode(
          'P6 100000 100000 255\n',
          [],
          limits: const Limits(dimension: 100000, pixels: 1 << 40),
        ),
        ErrorKind.truncated,
      );
    });

    test('invalid header values are malformed', () {
      for (final header in [
        'P6 0 1 255\n',
        'P6 1 1 0\n',
        'P6 1 1 65536\n',
        'P6 1 x 255\n',
      ]) {
        err(decode(header, [0, 0, 0]), ErrorKind.malformed);
      }
    });

    test('dimensions over the limits are a limit error', () {
      err(
        decode('P6 5 5 255\n', [], limits: const Limits(dimension: 4)),
        ErrorKind.limit,
      );
    });
  });
}

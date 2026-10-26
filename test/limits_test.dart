import 'dart:typed_data';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/image/codecs/bmp_codec.dart';
import 'package:libgfx/src/image/codecs/p3_codec.dart';
import 'package:libgfx/src/image/codecs/p6_codec.dart';
import 'package:libgfx/src/image/codecs/png_codec.dart';
import 'package:libgfx/src/image/image_codec.dart';
import 'package:test/test.dart';

import 'support/results.dart';

void main() {
  group('Bitmap preconditions', () {
    final invalid = <String, Bitmap Function()>{
      'Bitmap(-2, -3)': () => Bitmap(-2, -3),
      'Bitmap(0, -5)': () => Bitmap(0, -5),
      'Bitmap(-2, 3)': () => Bitmap(-2, 3),
      'Bitmap.empty(-1, -1)': () => Bitmap.empty(-1, -1),
      'Bitmap.fromPixels(-2, -3)': () =>
          Bitmap.fromPixels(-2, -3, Uint32List(6)),
      'crop(0, 0, -2, -3)': () => Bitmap(10, 10).crop(0, 0, -2, -3),
      'more pixels than the default limit': () => Bitmap(32768, 8193),
    };
    for (final MapEntry(key: name, value: create) in invalid.entries) {
      test('$name throws ArgumentError', () {
        expect(create, throwsArgumentError);
      });
    }

    test('an empty bitmap is allowed', () {
      expect(Bitmap(0, 0).pixels, isEmpty);
    });
  });

  group('Decoders respect limits', () {
    final image = Bitmap(3, 2)..clear(const Color(0xFF336699));
    const small = Limits(pixels: 4);
    final codecs = <String, ImageCodec>{
      'bmp': BmpImageCodec(),
      'p3': P3ImageCodec(),
      'p6': P6ImageCodec(),
      'png': PngImageCodec(),
    };

    for (final MapEntry(key: name, value: codec) in codecs.entries) {
      test('$name over the pixel limit is a limit error', () {
        err(codec.decode(codec.encode(image), limits: small), ErrorKind.limit);
      });

      test('$name within the limits decodes', () {
        ok(codec.decode(codec.encode(image), limits: const Limits(pixels: 6)));
      });
    }

    test(
      'a BMP header claiming 100000x100000 is rejected before allocating',
      () {
        final bytes = BmpImageCodec().encode(image);
        ByteData.sublistView(bytes)
          ..setInt32(18, 100000, Endian.little)
          ..setInt32(22, 100000, Endian.little);

        err(BmpImageCodec().decode(bytes), ErrorKind.limit);
      },
    );

    test('negative P3 dimensions are malformed', () {
      final bytes = Uint8List.fromList('P3\n-2 -3\n255\n'.codeUnits);

      err(P3ImageCodec().decode(bytes), ErrorKind.malformed);
    });

    test('limits pass through ImageLoader and GraphicsEngine', () {
      final bytes = PngImageCodec().encode(image);

      err(ImageLoader.loadFromBytes(bytes, limits: small), ErrorKind.limit);
      err(GraphicsEngine.decode(bytes, limits: small), ErrorKind.limit);
    });
  });
}

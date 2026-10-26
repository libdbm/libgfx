import 'dart:typed_data';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/image/codecs/bmp_codec.dart';
import 'package:libgfx/src/image/codecs/p3_codec.dart';
import 'package:libgfx/src/image/codecs/p6_codec.dart';
import 'package:libgfx/src/image/codecs/png_codec.dart';
import 'package:libgfx/src/image/image_codec.dart';
import 'package:test/test.dart';

import 'support/results.dart';

class _MissingFileSystem implements GraphicsFileSystem {
  @override
  Future<Uint8List?> read(String path) async => null;

  @override
  Future<void> write(String path, List<int> bytes) async {}
}

void main() {
  final image = Bitmap(3, 2)..clear(const Color(0xFF336699));

  group('Truncated images return Err', () {
    final codecs = <String, ImageCodec>{
      'bmp': BmpImageCodec(),
      'p3': P3ImageCodec(),
      'p6': P6ImageCodec(),
      'png': PngImageCodec(),
    };
    for (final MapEntry(key: name, value: codec) in codecs.entries) {
      test('$name truncated to half its length', () {
        final bytes = codec.encode(image);
        final truncated = Uint8List.sublistView(bytes, 0, bytes.length ~/ 2);

        final result = codec.decode(truncated);

        expect(result, isA<Err<Bitmap, ErrorDetails>>());
      });
    }
  });

  group('ImageLoader', () {
    test('unrecognised data is unsupported', () {
      err(
        ImageLoader.loadFromBytes(Uint8List.fromList([1, 2, 3, 4])),
        ErrorKind.unsupported,
      );
    });

    test('unknown format name is unsupported', () {
      err(
        ImageLoader.loadFromBytes(
          BmpImageCodec().encode(image),
          format: 'tiff',
        ),
        ErrorKind.unsupported,
      );
    });

    test('missing file is an io error', () async {
      err(
        await ImageLoader.loadFromFile(
          'missing.bmp',
          filesystem: _MissingFileSystem(),
        ),
        ErrorKind.io,
      );
    });
  });

  group('GraphicsEngine.loadImageFromBytes', () {
    test('detects PNG without a format name', () {
      final bytes = PngImageCodec().encode(image);

      final decoded = ok(GraphicsEngine.decode(bytes));

      expect(decoded.pixels, equals(image.pixels));
    });

    test('garbage returns Err instead of throwing', () {
      err(
        GraphicsEngine.decode(Uint8List.fromList([0, 1, 2])),
        ErrorKind.unsupported,
      );
    });
  });
}

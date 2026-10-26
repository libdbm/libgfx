import 'dart:math' as math;
import 'dart:typed_data';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/graphics_context.dart';
import 'package:test/test.dart';

import 'support/pixels.dart';

class MemoryFileSystem implements GraphicsFileSystem {
  final Map<String, List<int>> writes = {};

  @override
  Future<Uint8List?> read(String path) async => null;

  @override
  Future<void> write(String path, List<int> bytes) async {
    writes[path] = List<int>.from(bytes);
  }
}

Color rgba(int r, int g, int b, [int a = 255]) => Color.fromRGBA(r, g, b, a);

Map<int, int> _pixelCounts(GraphicsEngine engine) {
  final counts = <int, int>{};
  for (var y = 0; y < engine.height; y++) {
    for (var x = 0; x < engine.width; x++) {
      final value = engine.pixel(x, y).value;
      counts[value] = (counts[value] ?? 0) + 1;
    }
  }
  return counts;
}

void main() {
  group('Image drawing', () {
    test('drawImage with a size scales image content', () {
      final engine = GraphicsEngine(4, 4);
      final source = Bitmap(2, 2);
      source.plot(0, 0, rgba(255, 0, 0));
      source.plot(1, 0, rgba(0, 255, 0));
      source.plot(0, 1, rgba(0, 0, 255));
      source.plot(1, 1, rgba(255, 255, 0));

      engine.drawImage(source, 0, 0, width: 4, height: 4);

      final counts = _pixelCounts(engine);
      final expectedColors = [
        source.pixel(0, 0).value,
        source.pixel(1, 0).value,
        source.pixel(0, 1).value,
        source.pixel(1, 1).value,
      ];

      for (final color in expectedColors) {
        expect(
          counts[color] ?? 0,
          greaterThanOrEqualTo(4),
          reason:
              'Scaled image should dedicate at least 4 pixels to color 0x${color.toRadixString(16)}',
        );
      }

      final unexpected = counts.keys.where(
        (value) => value != 0 && !expectedColors.contains(value),
      );
      expect(unexpected, isEmpty);
    });

    test('drawImageRect draws cropped region at destination', () {
      final engine = GraphicsEngine(2, 2);
      final source = Bitmap(3, 3);

      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < 3; x++) {
          source.plot(x, y, rgba(x * 30, y * 40, 0));
        }
      }

      engine.drawImage(
        source,
        0,
        0,
        width: 2,
        height: 2,
        source: Rectangle(1, 0, 2, 2),
      );

      final counts = _pixelCounts(engine);
      final expectedColors = [
        source.pixel(1, 0).value,
        source.pixel(2, 0).value,
        source.pixel(1, 1).value,
        source.pixel(2, 1).value,
      ];

      for (final color in expectedColors) {
        expect(counts[color] ?? 0, greaterThan(0));
      }

      final unexpected = counts.keys.where(
        (value) => value != 0 && !expectedColors.contains(value),
      );
      expect(unexpected, isEmpty);
    });

    test('drawImage respects active clip region', () {
      final engine = GraphicsEngine(4, 4);
      final source = Bitmap(2, 2);
      for (var y = 0; y < 2; y++) {
        for (var x = 0; x < 2; x++) {
          source.plot(x, y, rgba(200, 100, 50));
        }
      }

      engine.clear(const Color(0x00000000));
      engine.clipRect(0, 0, 2, 2);
      engine.drawImage(source, 1, 1);

      final counts = _pixelCounts(engine);
      final drawnColor = source.pixel(0, 0).value;

      expect(counts[drawnColor] ?? 0, greaterThan(0));
      expect(counts[0] ?? 0, greaterThan(0));

      final nonZeroColors = counts.keys.where((value) => value != 0).toList();
      expect(nonZeroColors, everyElement(equals(drawnColor)));
    });

    test('write infers PNG encoding', () async {
      final fs = MemoryFileSystem();
      final engine = GraphicsEngine(2, 2, filesystem: fs);

      await engine.write('test_output.png');

      final bytes = fs.writes['test_output.png'];
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(8));
      expect(bytes[0], equals(0x89));
      expect(bytes[1], equals(0x50));
      expect(bytes[2], equals(0x4E));
      expect(bytes[3], equals(0x47));
    });

    test('write defaults to P6 PPM for unknown formats', () async {
      final fs = MemoryFileSystem();
      final engine = GraphicsEngine(2, 2, filesystem: fs);

      await engine.write('test_output.custom');

      final bytes = fs.writes['test_output.custom'];
      expect(bytes, isNotNull);
      expect(String.fromCharCodes(bytes!.take(2)), equals('P6'));
    });

    test('drawImage with globalAlpha 0 paints nothing', () {
      final engine = GraphicsEngine(10, 10)..globalAlpha = 0;
      final source = Bitmap(4, 4)..clear(rgba(255, 0, 0));

      engine.drawImage(source, 2, 2);

      expect(painted(engine.canvas), equals(0));
    });

    test('drawImage scales alpha by globalAlpha', () {
      final engine = GraphicsEngine(10, 10)..globalAlpha = 0.5;
      final source = Bitmap(4, 4)..clear(rgba(255, 0, 0));

      engine.drawImage(source, 2, 2);

      final alphas = engine.canvas.pixels
          .map((pixel) => pixel >> 24 & 0xFF)
          .where((alpha) => alpha > 0);
      expect(alphas, isNotEmpty);
      expect(alphas, everyElement(closeTo(128, 1)));
    });

    test('drawImage paints exactly the image footprint', () {
      final engine = GraphicsEngine(10, 10);
      final source = Bitmap(4, 4)..clear(rgba(255, 0, 0));

      engine.drawImage(source, 2, 2);

      expect(painted(engine.canvas), equals(16));
      // Graphics rows 2..5 are bitmap rows 4..7.
      for (var y = 4; y <= 7; y++) {
        for (var x = 2; x <= 5; x++) {
          expect(engine.pixel(x, y).value, equals(0xFFFF0000));
        }
      }
    });

    test('rotated drawImage paints only inside the rotated footprint', () {
      final engine = GraphicsEngine(30, 30)
        ..translate(15, 15)
        ..rotate(math.pi / 4);
      final source = Bitmap(10, 10)..clear(rgba(255, 0, 0));

      engine.drawImage(source, -5, -5);

      // A 10x10 square has area 100 whatever its rotation.
      expect(painted(engine.canvas), closeTo(100, 12));
      // Corners of the diamond's bounding box lie outside the diamond.
      for (final (x, y) in [(8, 8), (21, 8), (8, 21), (21, 21)]) {
        expect(engine.pixel(x, y).alpha, equals(0), reason: '($x, $y)');
      }
    });

    test('drawImage with a size maps each source pixel to its own block', () {
      final engine = GraphicsEngine(4, 4);
      final source = Bitmap(2, 2)
        ..plot(0, 0, rgba(255, 0, 0))
        ..plot(1, 0, rgba(0, 255, 0))
        ..plot(0, 1, rgba(0, 0, 255))
        ..plot(1, 1, rgba(255, 255, 0));

      engine.drawImage(source, 0, 0, width: 4, height: 4);

      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          expect(
            engine.pixel(x, y).value,
            equals(source.pixel(x ~/ 2, y ~/ 2).value),
            reason: '($x, $y)',
          );
        }
      }
    });

    test('drawImage through an anti-aliased clip has partial edge alpha', () {
      final engine = GraphicsEngine(20, 20)
        ..clip(PathBuilder().circle(10, 10, 6).build());
      final source = Bitmap(20, 20)..clear(rgba(255, 0, 0));

      engine.drawImage(source, 0, 0);

      final partial = engine.canvas.pixels
          .map((pixel) => pixel >> 24 & 0xFF)
          .where((alpha) => alpha > 0 && alpha < 255);
      expect(partial, isNotEmpty);
    });

    test('drawImage under a singular transform paints nothing', () {
      final engine = GraphicsEngine(10, 10)..scale(0, 1);
      final source = Bitmap(4, 4)..clear(rgba(255, 0, 0));

      engine.drawImage(source, 2, 2);

      expect(painted(engine.canvas), equals(0));
    });

    test('drawImage samples a scaled image with the given filter', () {
      final source = Bitmap(2, 1)
        ..plot(0, 0, rgba(255, 0, 0))
        ..plot(1, 0, rgba(0, 0, 255));
      Color middle(final ImageFilter filter) {
        final engine = GraphicsEngine(8, 1)
          ..drawImage(source, 0, 0, width: 8, height: 1, filter: filter);
        return engine.pixel(3, 0);
      }

      // Nearest copies the left pixel; bilinear mixes in the right one
      expect(middle(ImageFilter.nearest).value, rgba(255, 0, 0).value);
      final mixed = middle(ImageFilter.bilinear);
      expect(mixed.red, lessThan(255));
      expect(mixed.blue, greaterThan(0));
    });

    test('bilinear upscaling is symmetric about the image centre', () {
      final bitmap = Bitmap(8, 1);
      final source = Bitmap(2, 1)
        ..plot(0, 0, rgba(255, 0, 0))
        ..plot(1, 0, rgba(0, 0, 255));

      GraphicsContext(
        bitmap,
      ).drawImageScaled(source, 0, 0, 8, 1, filter: ImageFilter.bilinear);

      for (var x = 0; x < 4; x++) {
        final left = bitmap.pixel(x, 0);
        final right = bitmap.pixel(7 - x, 0);
        expect(left.red, closeTo(right.blue, 1), reason: 'x=$x');
        expect(left.blue, closeTo(right.red, 1), reason: 'x=$x');
      }
    });
  });

  group('Images through a partial clip', () {
    /// Draws a blue 10 x 10 image, or fills the same area with blue, over
    /// opaque red through a clip covering a quarter of column 5, in [mode]
    /// at [alpha].
    GraphicsEngine draw(
      final BlendMode mode,
      final bool image, {
      final double alpha = 1.0,
    }) {
      final engine = GraphicsEngine(10, 10)
        ..clear(rgba(255, 0, 0))
        ..clip(
          (PathBuilder()
                ..moveTo(0, 0)
                ..lineTo(5.25, 0)
                ..lineTo(5.25, 10)
                ..lineTo(0, 10)
                ..closePath())
              .build(),
        )
        ..globalCompositeOperation = mode
        ..globalAlpha = alpha;
      if (image) {
        engine.drawImage(Bitmap(10, 10)..clear(rgba(0, 0, 255)), 0, 0);
      } else {
        engine
          ..fillStyle = rgba(0, 0, 255)
          ..fillRect(0, 0, 10, 10);
      }
      return engine;
    }

    for (final mode in [BlendMode.clear, BlendMode.src, BlendMode.srcOver]) {
      for (final alpha in [1.0, 0.5]) {
        test('${mode.name} at global alpha $alpha matches the vector fill', () {
          final image = draw(mode, true, alpha: alpha);
          final fill = draw(mode, false, alpha: alpha);
          for (final x in [4, 5, 6]) {
            final actual = image.pixel(x, 5);
            final expected = fill.pixel(x, 5);
            for (final (name, value, target) in [
              ('a', actual.alpha, expected.alpha),
              ('r', actual.red, expected.red),
              ('g', actual.green, expected.green),
              ('b', actual.blue, expected.blue),
            ]) {
              expect(value, closeTo(target, 1), reason: 'x=$x $name');
            }
          }
        });
      }
    }

    test('clear at the clip edge removes only the covered quarter', () {
      expect(draw(BlendMode.clear, true).pixel(5, 5).alpha, closeTo(191, 1));
    });

    test('src at the clip edge keeps the uncovered part of the pixel', () {
      final pixel = draw(BlendMode.src, true).pixel(5, 5);
      expect(pixel.alpha, equals(255));
      expect(pixel.red, closeTo(191, 1));
      expect(pixel.blue, closeTo(64, 1));
    });
  });

  group('Transparent image pixels', () {
    // Pixel counts after drawing a 4 x 4 transparent image over red, with
    // every fully transparent pixel counted as 0 whatever its colour
    Map<int, int> draw(final BlendMode mode) {
      final engine = GraphicsEngine(10, 10)
        ..clear(rgba(255, 0, 0))
        ..globalCompositeOperation = mode;
      engine.drawImage(Bitmap(4, 4), 2, 2);
      final counts = <int, int>{};
      for (final pixel in engine.canvas.pixels) {
        final value = pixel >>> 24 == 0 ? 0 : pixel;
        counts[value] = (counts[value] ?? 0) + 1;
      }
      return counts;
    }

    test('src replaces the footprint with transparent pixels', () {
      expect(draw(BlendMode.src), equals({0: 16, 0xFFFF0000: 84}));
    });

    test('srcIn, dstIn, srcOut, dstAtop and clear empty the footprint', () {
      for (final mode in [
        BlendMode.srcIn,
        BlendMode.dstIn,
        BlendMode.srcOut,
        BlendMode.dstAtop,
        BlendMode.clear,
      ]) {
        expect(draw(mode), equals({0: 16, 0xFFFF0000: 84}), reason: '$mode');
      }
    });

    test('srcOver leaves the destination unchanged', () {
      expect(draw(BlendMode.srcOver), equals({0xFFFF0000: 100}));
    });
  });

  group('ImageData', () {
    // A 4 x 3 canvas whose every pixel has its own colour, one translucent
    GraphicsEngine canvas() {
      final engine = GraphicsEngine(4, 3);
      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < 4; x++) {
          engine.plot(x, y, Color.fromRGBA(x * 60, y * 100, 7, 255 - x * y));
        }
      }
      return engine;
    }

    List<int> pixels(final GraphicsEngine engine) => [
      for (var y = 0; y < engine.height; y++)
        for (var x = 0; x < engine.width; x++) engine.pixel(x, y).value,
    ];

    test('getImageData holds red, green, blue, alpha from the top row', () {
      final image = canvas().getImageData(1, 2, 2, 1);
      expect([image.width, image.height], equals([2, 1]));
      expect(image.data, equals([60, 200, 7, 253, 120, 200, 7, 251]));
    });

    test('pixels outside the canvas are transparent black', () {
      final image = canvas().getImageData(3, 2, 2, 2);
      expect(image.data.sublist(0, 4), equals([180, 200, 7, 249]));
      expect(image.data.sublist(4), everyElement(equals(0)));
    });

    test('putImageData of what getImageData returned changes nothing', () {
      final engine = canvas();
      final before = pixels(engine);
      final image = engine.getImageData(0, 0, 4, 3);
      engine.clear(const Color(0x00000000));
      engine.putImageData(image, 0, 0);
      expect(pixels(engine), equals(before));
    });

    test('the data is a copy', () {
      final engine = canvas();
      final before = pixels(engine);
      engine.getImageData(0, 0, 4, 3).data.fillRange(0, 48, 9);
      expect(pixels(engine), equals(before));
    });

    test('data narrower than the canvas lands row by row', () {
      final engine = GraphicsEngine(4, 3);
      final image = ImageData(2, 2);
      for (var i = 0; i < 4; i++) {
        image.data.setRange(i * 4, i * 4 + 4, [i * 50, 0, 0, 255]);
      }
      engine.putImageData(image, 1, 1);
      expect(engine.pixel(1, 1).red, equals(0));
      expect(engine.pixel(2, 1).red, equals(50));
      expect(engine.pixel(1, 2).red, equals(100));
      expect(engine.pixel(2, 2).red, equals(150));
      expect(engine.pixel(0, 0).value, equals(0));
      expect(engine.pixel(3, 1).value, equals(0));
    });

    test('a dirty rectangle copies only its part, at its offset', () {
      final engine = GraphicsEngine(4, 3);
      final image = ImageData(3, 2)..data.fillRange(0, 24, 255);
      engine.putImageData(image, 1, 0, 1, 1, 2, 1);
      final painted = [
        for (var y = 0; y < 3; y++)
          for (var x = 0; x < 4; x++)
            if (engine.pixel(x, y).alpha != 0) (x, y),
      ];
      expect(painted, equals([(2, 1), (3, 1)]));
    });

    test('putImageData replaces pixels, ignoring alpha and compositing', () {
      final engine = GraphicsEngine(1, 1)..clear(const Color(0xFFFFFFFF));
      engine.globalAlpha = 0.5;
      engine.putImageData(
        ImageData.from(1, 1, Uint8ClampedList.fromList([10, 20, 30, 40])),
        0,
        0,
      );
      expect(engine.pixel(0, 0).value, equals(0x280A141E));
    });

    test('sizes below one and mismatched data are rejected', () {
      expect(() => ImageData(0, 1), throwsArgumentError);
      expect(
        () => ImageData.from(2, 2, Uint8ClampedList(15)),
        throwsArgumentError,
      );
    });
  });
}

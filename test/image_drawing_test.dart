import 'dart:typed_data';

import 'package:libgfx/libgfx.dart';
import 'package:test/test.dart';

class MemoryFileSystem implements GraphicsFileSystem {
  final Map<String, List<int>> writes = {};

  @override
  Future<Uint8List?> readFile(String path) async => null;

  @override
  Future<void> writeFile(String path, List<int> bytes) async {
    writes[path] = List<int>.from(bytes);
  }
}

Color rgba(int r, int g, int b, [int a = 255]) => Color.fromRGBA(r, g, b, a);

Map<int, int> _pixelCounts(GraphicsEngine engine) {
  final counts = <int, int>{};
  for (var y = 0; y < engine.height; y++) {
    for (var x = 0; x < engine.width; x++) {
      final value = engine.getPixel(x, y).value;
      counts[value] = (counts[value] ?? 0) + 1;
    }
  }
  return counts;
}

void main() {
  group('Image drawing', () {
    test('drawImageScaled scales image content', () {
      final engine = GraphicsEngine(4, 4);
      final source = Bitmap(2, 2);
      source.setPixel(0, 0, rgba(255, 0, 0));
      source.setPixel(1, 0, rgba(0, 255, 0));
      source.setPixel(0, 1, rgba(0, 0, 255));
      source.setPixel(1, 1, rgba(255, 255, 0));

      engine.drawImageScaled(source, 0, 0, 4, 4);

      final counts = _pixelCounts(engine);
      final expectedColors = [
        source.getPixel(0, 0).value,
        source.getPixel(1, 0).value,
        source.getPixel(0, 1).value,
        source.getPixel(1, 1).value,
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
          source.setPixel(x, y, rgba(x * 30, y * 40, 0));
        }
      }

      engine.drawImageRect(source, 1, 0, 2, 2, 0, 0, 2, 2);

      final counts = _pixelCounts(engine);
      final expectedColors = [
        source.getPixel(1, 0).value,
        source.getPixel(2, 0).value,
        source.getPixel(1, 1).value,
        source.getPixel(2, 1).value,
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
          source.setPixel(x, y, rgba(200, 100, 50));
        }
      }

      engine.clear(const Color(0x00000000));
      engine.clipRect(0, 0, 2, 2);
      engine.drawImage(source, 1, 1);

      final counts = _pixelCounts(engine);
      final drawnColor = source.getPixel(0, 0).value;

      expect(counts[drawnColor] ?? 0, greaterThan(0));
      expect(counts[0] ?? 0, greaterThan(0));

      final nonZeroColors = counts.keys.where((value) => value != 0).toList();
      expect(nonZeroColors, everyElement(equals(drawnColor)));
    });

    test('saveToFile infers PNG encoding', () async {
      final fs = MemoryFileSystem();
      final engine = GraphicsEngine(2, 2, filesystem: fs);

      await engine.saveToFile('test_output.png');

      final bytes = fs.writes['test_output.png'];
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(8));
      expect(bytes[0], equals(0x89));
      expect(bytes[1], equals(0x50));
      expect(bytes[2], equals(0x4E));
      expect(bytes[3], equals(0x47));
    });

    test('saveToFile defaults to P6 PPM for unknown formats', () async {
      final fs = MemoryFileSystem();
      final engine = GraphicsEngine(2, 2, filesystem: fs);

      await engine.saveToFile('test_output.custom');

      final bytes = fs.writes['test_output.custom'];
      expect(bytes, isNotNull);
      expect(String.fromCharCodes(bytes!.take(2)), equals('P6'));
    });
  });
}

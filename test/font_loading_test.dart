import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:libgfx/libgfx.dart';
import 'package:test/test.dart';

import 'support/results.dart';

/// Serves fixture fonts; each read waits for its [gates] completer if any.
class _GatedFileSystem implements GraphicsFileSystem {
  final Map<String, Completer<void>> gates = {};

  @override
  Future<Uint8List?> read(String path) async {
    await gates[path]?.future;
    final file = File(path);
    return file.existsSync() ? file.readAsBytesSync() : null;
  }

  @override
  Future<void> write(String path, List<int> bytes) async {}
}

/// Holds [files] in memory and records the paths it served
class _MemoryFileSystem implements GraphicsFileSystem {
  final Map<String, Uint8List> files;
  final List<String> served = [];

  _MemoryFileSystem(this.files);

  @override
  Future<Uint8List?> read(String path) async {
    final file = files[path];
    if (file != null) served.add(path);
    return file;
  }

  @override
  Future<void> write(String path, List<int> bytes) async {}
}

void main() {
  const dejavu = 'test/fixtures/fonts/DejaVuSans.ttf';
  const radley = 'test/fixtures/fonts/Radley-Regular.ttf';
  final bytes = File(dejavu).readAsBytesSync();

  group('TTFFont', () {
    test('garbage bytes are malformed', () {
      err(
        TTFFont.fromBytes(Uint8List.fromList(List.filled(64, 7))),
        ErrorKind.malformed,
      );
    });

    for (final length in [3, 10, 100, 1000]) {
      test('a font truncated to $length bytes returns Err', () {
        final result = TTFFont.fromBytes(
          Uint8List.sublistView(bytes, 0, length),
        );

        expect(result, isA<Err<TTFFont, ErrorDetails>>());
      });
    }

    test('a missing file is an io error', () async {
      err(
        await TTFFont.load('missing.ttf', filesystem: _GatedFileSystem()),
        ErrorKind.io,
      );
    });
  });

  group('FontFallbackChain', () {
    test('a missing file is an io error and adds nothing', () async {
      final chain = FontFallbackChain();

      err(
        await chain.load('missing.ttf', filesystem: _GatedFileSystem()),
        ErrorKind.io,
      );
      expect(chain.primary, isNull);
    });
  });

  group('GraphicsEngine font loading', () {
    test('bad bytes return Err and keep the current font', () {
      final engine = GraphicsEngine(10, 10);
      ok(engine.readFont(bytes));
      final current = engine.font;

      err(engine.readFont(Uint8List.fromList([1, 2, 3])), ErrorKind.truncated);

      expect(engine.font, same(current));
    });

    test('a missing file returns Err and keeps the current font', () async {
      final engine = GraphicsEngine(10, 10, filesystem: _GatedFileSystem());
      ok(engine.readFont(bytes));
      final current = engine.font;

      err(await engine.loadFont('missing.ttf'), ErrorKind.io);

      expect(engine.font, same(current));
    });

    test('a slower earlier request does not replace a newer font', () async {
      final filesystem = _GatedFileSystem()
        ..gates[dejavu] = Completer<void>()
        ..gates[radley] = Completer<void>();
      final engine = GraphicsEngine(10, 10, filesystem: filesystem);

      final first = engine.loadFont(dejavu);
      final second = engine.loadFont(radley);
      filesystem.gates[radley]!.complete();
      ok(await second);
      filesystem.gates[dejavu]!.complete();
      ok(await first);

      expect(engine.font?.family, equals('Radley'));
    });
  });

  group('System fonts', () {
    // A name no real system has, in the first and second font directories
    // of every platform
    const name = 'LibgfxTestFontXYZ';
    const first = [
      '/System/Library/Fonts/',
      '/usr/share/fonts/',
      'C:\\Windows\\Fonts\\',
    ];
    const second = ['/Library/Fonts/', '/usr/local/share/fonts/'];

    test('fonts are found through the given file system', () async {
      final filesystem = _MemoryFileSystem({
        for (final directory in first) '$directory$name.ttf': bytes,
      });
      final chain = await SystemFontManager.load(
        preferredFonts: [name],
        filesystem: filesystem,
      );
      expect(chain.primary, isNotNull);
    });

    test('a name in two directories loads once', () async {
      final filesystem = _MemoryFileSystem({
        for (final directory in [...first, ...second])
          '$directory$name.ttf': bytes,
      });
      await SystemFontManager.load(
        preferredFonts: [name],
        filesystem: filesystem,
      );
      expect(filesystem.served, hasLength(1));
    });
  });
}

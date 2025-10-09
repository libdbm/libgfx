import 'dart:io';

import '../src/fonts/font_fallback.dart';
import '../src/io/file_system.dart';
import '../src/logging.dart';

import 'local_file_system.dart';

const List<String> _commonFonts = [
  'Arial',
  'Helvetica',
  'Times',
  'Courier',
  'Verdana',
  'Georgia',
  'NotoSans',
  'NotoSerif',
  'DejaVu',
  'Liberation',
  'Roboto',
];

const Map<String, List<String>> _systemFontPaths = {
  'macos': ['/System/Library/Fonts/', '/Library/Fonts/', '~/Library/Fonts/'],
  'darwin': ['/System/Library/Fonts/', '/Library/Fonts/', '~/Library/Fonts/'],
  'linux': [
    '/usr/share/fonts/',
    '/usr/local/share/fonts/',
    '~/.fonts/',
    '~/.local/share/fonts/',
  ],
  'windows': ['C:\\Windows\\Fonts\\'],
};

Future<FontFallbackChain> loadSystemFontsImpl({
  List<String>? preferredFonts,
  int maxFonts = 5,
  GraphicsFileSystem? filesystem,
}) async {
  final chain = FontFallbackChain();
  final fs = filesystem ?? const LocalGraphicsFileSystem();
  final platform = Platform.operatingSystem;
  final searchPaths = _systemFontPaths[platform] ?? [];

  final fontsToLoad = preferredFonts ?? _commonFonts;
  var loaded = 0;

  for (final fontName in fontsToLoad) {
    if (loaded >= maxFonts) break;

    for (final basePath in searchPaths) {
      final expandedPath = basePath.replaceFirst(
        '~',
        Platform.environment['HOME'] ?? '',
      );

      for (final ext in ['.ttf', '.otf', '.TTF', '.OTF']) {
        final fontPath = '$expandedPath$fontName$ext';
        final file = File(fontPath);

        if (await file.exists()) {
          try {
            await chain.addFontFromFile(fontPath, filesystem: fs);
            loaded++;
            logger.info('Loaded system font: $fontPath');
            break;
          } catch (_) {
            // Continue searching for other fonts/extensions
          }
        }
      }

      if (loaded >= maxFonts) break;
    }
  }

  if (loaded == 0) {
    logger.warning('No system fonts could be loaded');
  }

  return chain;
}

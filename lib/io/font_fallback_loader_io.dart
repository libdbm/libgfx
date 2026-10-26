import 'dart:io';

import '../src/fonts/font_fallback.dart';
import '../src/io/file_system.dart';
import '../src/logging.dart';
import '../src/result.dart';

import 'local_file_system.dart';

const List<String> _defaults = [
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

const Map<String, List<String>> _directories = {
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
  final system = filesystem ?? const LocalGraphicsFileSystem();
  final platform = Platform.operatingSystem;
  final directories = _directories[platform] ?? [];

  final names = preferredFonts ?? _defaults;
  var loaded = 0;

  for (final name in names) {
    if (loaded >= maxFonts) break;

    // The first file that loads, through the file system, wins the name;
    // a missing or unreadable file moves on to the next candidate
    search:
    for (final base in directories) {
      final directory = base.replaceFirst(
        '~',
        Platform.environment['HOME'] ?? '',
      );

      for (final extension in ['.ttf', '.otf', '.TTF', '.OTF']) {
        final path = '$directory$name$extension';
        final result = await chain.load(path, filesystem: system);
        if (result is Ok) {
          loaded++;
          logger.info('Loaded system font: $path');
          break search;
        }
      }
    }
  }

  if (loaded == 0) {
    logger.warning('No system fonts could be loaded');
  }

  return chain;
}

import '../src/fonts/font_fallback.dart';
import '../src/io/file_system.dart';

Future<FontFallbackChain> loadSystemFontsImpl({
  List<String>? preferredFonts,
  int maxFonts = 5,
  GraphicsFileSystem? filesystem,
}) {
  throw UnsupportedError(
    'System font loading requires dart:io. Import package:libgfx/io/font_fallback_loader_io.dart on IO platforms.',
  );
}

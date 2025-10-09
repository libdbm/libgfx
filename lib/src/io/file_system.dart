import 'dart:typed_data';

/// Provides byte-level IO without depending on `dart:io`, enabling libgfx to
/// run in browser and isolate environments. Implementations handle any
/// platform-specific directory management.
abstract class GraphicsFileSystem {
  /// Returns the file contents for [path], or `null` when the resource cannot
  /// be found.
  Future<Uint8List?> readFile(String path);

  /// Persists [bytes] at [path], creating parent directories when required.
  Future<void> writeFile(String path, List<int> bytes);
}

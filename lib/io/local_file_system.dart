import 'dart:io';
import 'dart:typed_data';

import '../src/io/file_system.dart';

/// Default `GraphicsFileSystem` backed by `dart:io`. This sits in the optional
/// `lib/io` import path so apps targeting the VM can opt-in without pulling the
/// dependency into web builds.
class LocalGraphicsFileSystem implements GraphicsFileSystem {
  const LocalGraphicsFileSystem();

  @override
  Future<Uint8List?> read(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  @override
  Future<void> write(String path, List<int> bytes) async {
    final file = File(path);
    final directory = file.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    await file.writeAsBytes(bytes, flush: true);
  }
}

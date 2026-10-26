import 'dart:typed_data';

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/image/codecs/png_codec.dart';

/// Times decoding PNGs whose image data is split into one-byte IDAT chunks.
/// Doubling the chunk count should roughly double the time (linear), not
/// quadruple it. Run with `dart run benchmark/png_chunks.dart`.
void main() {
  final codec = PngImageCodec();
  for (final height in [40, 80]) {
    final bytes = _split(codec.encode(Bitmap(50, height)));
    final chunks = (bytes.length - 8) ~/ 13;
    _measure('decode $chunks one-byte IDAT chunks', () => codec.decode(bytes));
  }
}

/// Rewrites [png], whose chunks are IHDR, one IDAT and IEND, with the IDAT
/// data split into one-byte chunks.
Uint8List _split(final Uint8List png) {
  final view = ByteData.sublistView(png);
  final header = 8 + 25; // signature and IHDR chunk
  final length = view.getUint32(header);
  final data = Uint8List.sublistView(png, header + 8, header + 8 + length);
  final builder = BytesBuilder()..add(Uint8List.sublistView(png, 0, header));
  for (final byte in data) {
    final body = [...'IDAT'.codeUnits, byte];
    builder
      ..add((ByteData(4)..setUint32(0, 1)).buffer.asUint8List())
      ..add(body)
      ..add((ByteData(4)..setUint32(0, _crc(body))).buffer.asUint8List());
  }
  builder.add(Uint8List.sublistView(png, header + 12 + length));
  return builder.takeBytes();
}

int _crc(final List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? 0xEDB88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

/// Runs [body] a few times to warm up, then [runs] times, and prints the
/// median wall-clock time.
void _measure(final String name, final void Function() body) {
  const warmup = 3;
  const runs = 20;
  for (var i = 0; i < warmup; i++) {
    body();
  }
  final times = <int>[];
  for (var i = 0; i < runs; i++) {
    final watch = Stopwatch()..start();
    body();
    times.add(watch.elapsedMicroseconds);
  }
  times.sort();
  final median = times[runs ~/ 2] / 1000;
  print('${name.padRight(36)} ${median.toStringAsFixed(2).padLeft(9)} ms');
}

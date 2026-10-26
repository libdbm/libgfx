import 'dart:typed_data';

import '../bitmap.dart';
import '../../color/color.dart';
import '../image_codec.dart';
import '../../result.dart';
import '../../limits.dart';
import 'pnm_tokenizer.dart';

/// PPM image codec (P3 ASCII format)
class P3ImageCodec extends ImageCodec {
  @override
  bool canDecode(Uint8List bytes) {
    if (bytes.length < 2) return false;
    return bytes[0] == 0x50 && bytes[1] == 0x33; // "P3"
  }

  @override
  Result<Bitmap, ErrorDetails> decode(
    Uint8List bytes, {
    Limits limits = const Limits(),
  }) => ImageCodec.guard(() => _decode(bytes, limits));

  Bitmap _decode(Uint8List bytes, Limits limits) {
    final tokenizer = PnmTokenizer(bytes);
    final (:width, :height, :maxval) = tokenizer.header('P3', limits);

    final bitmap = Bitmap(width, height);
    for (int i = 0; i < width * height; i++) {
      final r = tokenizer.number(0, 65535, 'sample');
      final g = tokenizer.number(0, 65535, 'sample');
      final b = tokenizer.number(0, 65535, 'sample');
      bitmap.pixels[i] = Color.fromARGB(
        255,
        PnmTokenizer.scale(r, maxval),
        PnmTokenizer.scale(g, maxval),
        PnmTokenizer.scale(b, maxval),
      ).value;
    }

    return bitmap;
  }

  @override
  Uint8List encode(Bitmap bitmap) {
    final buffer = StringBuffer();
    buffer.writeln('P3\n${bitmap.width} ${bitmap.height}\n255');
    int column = 0;

    for (final pixel in bitmap.pixels) {
      final color = Color(pixel);
      final text = '${color.red} ${color.green} ${color.blue} ';
      if (column + text.length > 70) {
        buffer.writeln();
        column = 0;
      }
      buffer.write(text);
      column += text.length;
    }

    return Uint8List.fromList(buffer.toString().codeUnits);
  }
}

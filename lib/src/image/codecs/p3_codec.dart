import 'dart:typed_data';

import '../bitmap.dart';
import '../../color/color.dart';
import '../image_codec.dart';

/// PPM image codec (P3 ASCII format)
class P3ImageCodec extends ImageCodec {
  @override
  bool canDecode(Uint8List bytes) {
    if (bytes.length < 2) return false;
    return bytes[0] == 0x50 && bytes[1] == 0x33; // "P3"
  }

  @override
  Bitmap decode(Uint8List bytes) {
    final contents = String.fromCharCodes(bytes);
    final tokens = contents
        .replaceAll(RegExp(r'#.*'), '')
        .split(RegExp(r'\s+'));
    tokens.removeWhere((s) => s.isEmpty);

    if (tokens.isEmpty || tokens[0] != 'P3') {
      throw FormatException('Not a valid PPM P3 file.');
    }

    final width = int.parse(tokens[1]);
    final height = int.parse(tokens[2]);
    // tokens[3] is max value (usually 255)

    final bitmap = Bitmap(width, height);
    int pixelIndex = 0;

    for (
      int i = 4;
      i < tokens.length - 2 && pixelIndex < width * height;
      i += 3
    ) {
      final r = int.parse(tokens[i]);
      final g = int.parse(tokens[i + 1]);
      final b = int.parse(tokens[i + 2]);
      bitmap.pixels[pixelIndex++] = Color.fromARGB(255, r, g, b).value;
    }

    return bitmap;
  }

  @override
  Uint8List encode(Bitmap bitmap) {
    final buffer = StringBuffer();
    buffer.writeln('P3\n${bitmap.width} ${bitmap.height}\n255');
    int lineCharCount = 0;

    for (final pixel in bitmap.pixels) {
      final color = Color(pixel);
      final pixelString = '${color.red} ${color.green} ${color.blue} ';
      if (lineCharCount + pixelString.length > 70) {
        buffer.writeln();
        lineCharCount = 0;
      }
      buffer.write(pixelString);
      lineCharCount += pixelString.length;
    }

    return Uint8List.fromList(buffer.toString().codeUnits);
  }
}

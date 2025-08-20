import 'dart:typed_data';

import '../bitmap.dart';
import '../../color/color.dart';
import '../image_codec.dart';

/// PPM image codec (P6 binary format)
class P6ImageCodec extends ImageCodec {
  @override
  bool canDecode(Uint8List bytes) {
    if (bytes.length < 3) return false;
    return bytes[0] == 0x50 && bytes[1] == 0x36; // "P6"
  }

  @override
  Bitmap decode(Uint8List bytes) {
    final text = String.fromCharCodes(bytes);
    final lines = text.split('\n');

    if (!lines[0].startsWith('P6')) {
      throw FormatException('Not a PPM P6 file');
    }

    int lineIndex = 1;
    // Skip comments
    while (lineIndex < lines.length && lines[lineIndex].startsWith('#')) {
      lineIndex++;
    }

    // Parse dimensions
    final dimensions = lines[lineIndex++].split(' ');
    final width = int.parse(dimensions[0]);
    final height = int.parse(dimensions[1]);

    // Parse max value (usually 255)
    lineIndex++; // Skip the max value line

    // Find start of binary data
    final headerEnd = lines.take(lineIndex).join('\n').length + 1;
    final pixelData = bytes.sublist(headerEnd);

    final image = Bitmap.empty(width, height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final offset = (y * width + x) * 3;
        final r = pixelData[offset];
        final g = pixelData[offset + 1];
        final b = pixelData[offset + 2];
        image.setPixel(x, y, Color.fromRGBA(r, g, b, 255));
      }
    }

    return image;
  }

  @override
  Uint8List encode(Bitmap image) {
    final header = 'P6\n${image.width} ${image.height}\n255\n';
    final headerBytes = Uint8List.fromList(header.codeUnits);

    final pixelBytes = Uint8List(image.width * image.height * 3);
    var offset = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final color = image.getPixel(x, y);
        pixelBytes[offset++] = color.red;
        pixelBytes[offset++] = color.green;
        pixelBytes[offset++] = color.blue;
      }
    }

    return Uint8List.fromList([...headerBytes, ...pixelBytes]);
  }
}

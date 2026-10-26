import 'dart:typed_data';

import '../bitmap.dart';
import '../../color/color.dart';
import '../image_codec.dart';
import '../../result.dart';
import '../../limits.dart';
import 'pnm_tokenizer.dart';

/// PPM image codec (P6 binary format)
class P6ImageCodec extends ImageCodec {
  @override
  bool canDecode(Uint8List bytes) {
    if (bytes.length < 3) return false;
    return bytes[0] == 0x50 && bytes[1] == 0x36; // "P6"
  }

  @override
  Result<Bitmap, ErrorDetails> decode(
    Uint8List bytes, {
    Limits limits = const Limits(),
  }) => ImageCodec.guard(() => _decode(bytes, limits));

  Bitmap _decode(Uint8List bytes, Limits limits) {
    final tokenizer = PnmTokenizer(bytes);
    final (:width, :height, :maxval) = tokenizer.header('P6', limits);
    tokenizer.separator();

    // Samples are one byte, or two big-endian bytes when maxval exceeds 255
    final size = maxval < 256 ? 1 : 2;
    final start = tokenizer.offset;
    if (bytes.length - start < width * height * 3 * size) {
      throw RangeError('PPM pixel data ends early');
    }

    int sample(final int index) {
      final offset = start + index * size;
      final value = size == 1
          ? bytes[offset]
          : (bytes[offset] << 8) | bytes[offset + 1];
      return PnmTokenizer.scale(value, maxval);
    }

    final image = Bitmap.empty(width, height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final index = (y * width + x) * 3;
        image.plot(
          x,
          y,
          Color.fromRGBA(
            sample(index),
            sample(index + 1),
            sample(index + 2),
            255,
          ),
        );
      }
    }

    return image;
  }

  @override
  Uint8List encode(Bitmap image) {
    final text = 'P6\n${image.width} ${image.height}\n255\n';
    final header = Uint8List.fromList(text.codeUnits);

    final pixels = Uint8List(image.width * image.height * 3);
    var offset = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final color = image.pixel(x, y);
        pixels[offset++] = color.red;
        pixels[offset++] = color.green;
        pixels[offset++] = color.blue;
      }
    }

    return Uint8List.fromList([...header, ...pixels]);
  }
}

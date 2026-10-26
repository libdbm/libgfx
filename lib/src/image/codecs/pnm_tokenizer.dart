import 'dart:typed_data';

import '../../limits.dart';

/// Reads the whitespace-separated tokens of a PNM (P3, P6) file. Any
/// whitespace separates tokens, and a `#` starts a comment that runs to the
/// end of the line, anywhere a token may start or end.
///
/// Data that ends early throws [RangeError]; invalid data throws
/// [FormatException].
class PnmTokenizer {
  final Uint8List bytes;

  /// Index of the next unread byte.
  int offset = 0;

  PnmTokenizer(this.bytes);

  /// Reads the magic number, dimensions and maxval, checking the dimensions
  /// against [limits].
  ({int width, int height, int maxval}) header(
    final String magic,
    final Limits limits,
  ) {
    if (next() != magic) {
      throw FormatException('Not a PPM $magic file');
    }
    final width = number(1, 0x7FFFFFFF, 'width');
    final height = number(1, 0x7FFFFFFF, 'height');
    final maxval = number(1, 65535, 'maxval');
    limits.require(width, height);
    return (width: width, height: height, maxval: maxval);
  }

  /// Reads a decimal number in [min]..[max]; [name] describes it in errors.
  int number(final int min, final int max, final String name) {
    final token = next();
    final value = _digits.hasMatch(token) ? int.tryParse(token) : null;
    if (value == null || value < min || value > max) {
      throw FormatException('Invalid PPM $name "$token"');
    }
    return value;
  }

  /// Reads the next token.
  String next() {
    while (offset < bytes.length) {
      final byte = bytes[offset];
      if (byte == _hash) {
        while (offset < bytes.length &&
            bytes[offset] != _newline &&
            bytes[offset] != _return) {
          offset++;
        }
      } else if (_space(byte)) {
        offset++;
      } else {
        break;
      }
    }
    final start = offset;
    while (offset < bytes.length &&
        !_space(bytes[offset]) &&
        bytes[offset] != _hash) {
      offset++;
    }
    if (offset == start) {
      throw RangeError('PPM data ends early');
    }
    return String.fromCharCodes(bytes, start, offset);
  }

  /// Consumes the single whitespace byte that ends a binary header.
  void separator() {
    if (offset >= bytes.length) {
      throw RangeError('PPM data ends early');
    }
    if (!_space(bytes[offset])) {
      throw FormatException('PPM header must end with one whitespace byte');
    }
    offset++;
  }

  /// [sample] in 0..[maxval] scaled to 0..255, rounding to nearest.
  static int scale(final int sample, final int maxval) {
    if (sample > maxval) {
      throw FormatException('PPM sample $sample exceeds maxval $maxval');
    }
    return (sample * 255 + maxval ~/ 2) ~/ maxval;
  }

  static final _digits = RegExp(r'^[0-9]+$');
  static const _hash = 0x23;
  static const _newline = 0x0A;
  static const _return = 0x0D;

  static bool _space(final int byte) =>
      byte == 0x20 || (byte >= 0x09 && byte <= 0x0D);
}

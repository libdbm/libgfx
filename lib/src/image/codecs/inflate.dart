import 'dart:math';
import 'dart:typed_data';

import '../../errors.dart';

/// Decompresses a zlib stream (RFC 1950) of deflate data (RFC 1951) and
/// verifies its Adler-32 checksum.
///
/// Data that ends early throws [RangeError]; invalid data throws
/// [FormatException]; output longer than [limit] bytes throws
/// [ResourceLimitException]. The output grows with the data, so a short
/// stream never allocates [limit] bytes.
Uint8List inflate(final Uint8List bytes, {required final int limit}) =>
    _Inflater(bytes, limit).run();

/// A canonical Huffman code, decoded one bit at a time.
class _Huffman {
  /// Number of codes of each length, 1 to 15; [counts] at 0 is the number
  /// of unused symbols.
  final counts = Int16List(16);

  /// Symbols ordered by code.
  final Int16List symbols;

  /// Codes left unused by the lengths: negative if they are
  /// over-subscribed, positive if the code is incomplete.
  int left = 1;

  _Huffman(final List<int> lengths) : symbols = Int16List(lengths.length) {
    for (final length in lengths) {
      counts[length]++;
    }
    for (var length = 1; length < 16 && left >= 0; length++) {
      left = (left << 1) - counts[length];
    }
    final offsets = Int16List(16);
    for (var length = 1; length < 15; length++) {
      offsets[length + 1] = offsets[length] + counts[length];
    }
    for (var symbol = 0; symbol < lengths.length; symbol++) {
      if (lengths[symbol] != 0) {
        symbols[offsets[lengths[symbol]]++] = symbol;
      }
    }
  }
}

class _Inflater {
  final Uint8List bytes;
  final int limit;

  /// Index of the next unread byte.
  int _offset = 0;

  /// Bits read from [bytes] but not consumed, least significant first.
  int _buffer = 0;
  int _count = 0;

  Uint8List _output;
  int _length = 0;

  _Inflater(this.bytes, this.limit)
    : _output = Uint8List(min(limit, max(1024, bytes.length * 4)));

  Uint8List run() {
    _header();
    var last = 0;
    while (last == 0) {
      last = _bits(1);
      switch (_bits(2)) {
        case 0:
          _stored();
        case 1:
          _codes(_fixedLengths, _fixedDistances);
        case 2:
          _dynamic();
        default:
          throw FormatException('Invalid deflate block type 3');
      }
    }
    _trailer();
    return Uint8List.sublistView(_output, 0, _length);
  }

  void _header() {
    if (bytes.length < 2) throw RangeError('zlib data ends early');
    final method = bytes[0];
    final flags = bytes[1];
    if (method & 0x0F != 8) {
      throw FormatException('Unknown zlib compression method ${method & 0x0F}');
    }
    if (method >> 4 > 7) {
      throw FormatException('zlib window size ${method >> 4} exceeds 32K');
    }
    if ((method << 8 | flags) % 31 != 0) {
      throw FormatException('Invalid zlib header check bits');
    }
    if (flags & 0x20 != 0) {
      throw FormatException('zlib preset dictionaries are not allowed');
    }
    _offset = 2;
  }

  /// Checks the Adler-32 checksum that follows the last block.
  void _trailer() {
    // Skip the rest of the last partial byte
    _buffer = 0;
    _count = 0;
    if (_offset + 4 > bytes.length) throw RangeError('zlib data ends early');
    final expected = ByteData.sublistView(bytes).getUint32(_offset);
    _offset += 4;
    if (_adler() != expected) {
      throw FormatException('zlib Adler-32 checksum mismatch');
    }
  }

  int _adler() {
    var a = 1;
    var b = 0;
    // 5552 bytes is the most that can be summed before b overflows 32 bits
    for (var start = 0; start < _length; start += 5552) {
      final end = min(start + 5552, _length);
      for (var i = start; i < end; i++) {
        a += _output[i];
        b += a;
      }
      a %= 65521;
      b %= 65521;
    }
    return b << 16 | a;
  }

  /// Reads [count] bits, least significant first.
  int _bits(final int count) {
    while (_count < count) {
      if (_offset >= bytes.length) throw RangeError('zlib data ends early');
      _buffer |= bytes[_offset++] << _count;
      _count += 8;
    }
    final value = _buffer & ((1 << count) - 1);
    _buffer >>= count;
    _count -= count;
    return value;
  }

  void _stored() {
    // Stored blocks start on a byte boundary
    _buffer = 0;
    _count = 0;
    if (_offset + 4 > bytes.length) throw RangeError('zlib data ends early');
    final length = bytes[_offset] | bytes[_offset + 1] << 8;
    final complement = bytes[_offset + 2] | bytes[_offset + 3] << 8;
    _offset += 4;
    if (length != ~complement & 0xFFFF) {
      throw FormatException('Stored block length does not match complement');
    }
    if (_offset + length > bytes.length) {
      throw RangeError('zlib data ends early');
    }
    _reserve(length);
    _output.setRange(_length, _length + length, bytes, _offset);
    _length += length;
    _offset += length;
  }

  /// Reads the code lengths of a dynamic block, then decodes the block.
  void _dynamic() {
    final count = _bits(5) + 257; // literal/length codes
    final distances = _bits(5) + 1;
    final codes = _bits(4) + 4; // code-length codes
    if (count > 286 || distances > 30) {
      throw FormatException('Too many deflate codes: $count and $distances');
    }

    final lengths = List.filled(19, 0);
    for (var i = 0; i < codes; i++) {
      lengths[_order[i]] = _bits(3);
    }
    final code = _Huffman(lengths);
    if (code.left != 0) {
      throw FormatException('Incomplete or over-subscribed code-length code');
    }

    final all = List.filled(count + distances, 0);
    var index = 0;
    while (index < all.length) {
      final symbol = _decode(code);
      if (symbol < 16) {
        all[index++] = symbol;
        continue;
      }
      var length = 0;
      final int repeat;
      if (symbol == 16) {
        if (index == 0) throw FormatException('Repeat with no length');
        length = all[index - 1];
        repeat = 3 + _bits(2);
      } else if (symbol == 17) {
        repeat = 3 + _bits(3);
      } else {
        repeat = 11 + _bits(7);
      }
      if (index + repeat > all.length) {
        throw FormatException('Repeated code lengths run past the end');
      }
      all.fillRange(index, index + repeat, length);
      index += repeat;
    }
    if (all[256] == 0) throw FormatException('No end-of-block code');

    final literals = _Huffman(all.sublist(0, count));
    final distance = _Huffman(all.sublist(count));
    // As in zlib's puff, a code may be incomplete only if it has one code,
    // and the distance code may be empty: a block of literals uses no
    // distances (RFC 1951 3.2.7), and decoding one with it is malformed
    for (final (huffman, size) in [(literals, count), (distance, distances)]) {
      final empty = identical(huffman, distance) && huffman.counts[0] == size;
      if (huffman.left < 0 ||
          (huffman.left > 0 && size - huffman.counts[0] != 1 && !empty)) {
        throw FormatException('Incomplete or over-subscribed Huffman code');
      }
    }
    _codes(literals, distance);
  }

  int _decode(final _Huffman huffman) {
    var code = 0; // bits read so far
    var first = 0; // first code of the current length
    var index = 0; // index of the first code of the current length
    for (var length = 1; length < 16; length++) {
      code |= _bits(1);
      final count = huffman.counts[length];
      if (code - first < count) return huffman.symbols[index + code - first];
      index += count;
      first = (first + count) << 1;
      code <<= 1;
    }
    throw FormatException('Invalid Huffman code');
  }

  void _codes(final _Huffman lengths, final _Huffman distances) {
    while (true) {
      final symbol = _decode(lengths);
      if (symbol < 256) {
        _reserve(1);
        _output[_length++] = symbol;
      } else if (symbol == 256) {
        return;
      } else {
        final index = symbol - 257;
        if (index >= _lengthBase.length) {
          throw FormatException('Invalid deflate length symbol $symbol');
        }
        final length = _lengthBase[index] + _bits(_lengthExtra[index]);
        final code = _decode(distances);
        if (code >= _distanceBase.length) {
          throw FormatException('Invalid deflate distance symbol $code');
        }
        final distance = _distanceBase[code] + _bits(_distanceExtra[code]);
        if (distance > _length) {
          throw FormatException('Deflate distance $distance is too far back');
        }
        _reserve(length);
        // Byte by byte, as the copy may overlap the bytes it writes
        for (var i = 0; i < length; i++) {
          _output[_length] = _output[_length - distance];
          _length++;
        }
      }
    }
  }

  /// Makes room for [count] more output bytes, up to [limit].
  void _reserve(final int count) {
    final needed = _length + count;
    if (needed > limit) {
      throw ResourceLimitException(
        'Decompressed data exceeds the limit of $limit bytes',
      );
    }
    if (needed > _output.length) {
      final grown = Uint8List(min(limit, max(needed, _output.length * 2)));
      grown.setRange(0, _length, _output);
      _output = grown;
    }
  }

  static final _fixedLengths = _Huffman([
    for (var symbol = 0; symbol < 288; symbol++)
      symbol < 144
          ? 8
          : symbol < 256
          ? 9
          : symbol < 280
          ? 7
          : 8,
  ]);
  static final _fixedDistances = _Huffman(List.filled(30, 5));

  /// The order in which code-length code lengths are stored.
  static const _order = [
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15, //
  ];

  static const _lengthBase = [
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, //
    35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258,
  ];
  static const _lengthExtra = [
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, //
    3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
  ];
  static const _distanceBase = [
    1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, //
    257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289,
    16385, 24577,
  ];
  static const _distanceExtra = [
    0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, //
    7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13,
  ];
}

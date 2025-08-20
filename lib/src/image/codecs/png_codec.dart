import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../bitmap.dart';
import '../../color/color.dart';
import '../../errors.dart';
import '../image_codec.dart';

/// PNG image codec for encoding and decoding PNG files
class PngImageCodec extends ImageCodec {
  static const List<int> _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

  @override
  bool canDecode(Uint8List bytes) {
    if (bytes.length < 8) return false;
    for (int i = 0; i < 8; i++) {
      if (bytes[i] != _pngSignature[i]) return false;
    }
    return true;
  }

  @override
  Bitmap decode(Uint8List bytes) {
    final decoder = _PngDecoder(bytes);
    return decoder.decode();
  }

  @override
  Uint8List encode(Bitmap image) {
    final encoder = _PngEncoder(image);
    return encoder.encode();
  }
}

/// PNG encoder implementation
class _PngEncoder {
  final Bitmap image;
  final BytesBuilder output = BytesBuilder();

  _PngEncoder(this.image);

  Uint8List encode() {
    // Write PNG signature
    output.add(PngImageCodec._pngSignature);

    // Write IHDR chunk
    _writeIHDR();

    // Write IDAT chunk(s)
    _writeIDAT();

    // Write IEND chunk
    _writeIEND();

    return output.takeBytes();
  }

  void _writeIHDR() {
    final data = BytesBuilder();

    // Width and height (4 bytes each)
    data.add(_int32Bytes(image.width));
    data.add(_int32Bytes(image.height));

    // Bit depth (1 byte) - 8 bits per channel
    data.addByte(8);

    // Color type (1 byte) - 6 = RGBA
    data.addByte(6);

    // Compression method (1 byte) - 0 = deflate
    data.addByte(0);

    // Filter method (1 byte) - 0 = adaptive
    data.addByte(0);

    // Interlace method (1 byte) - 0 = no interlace
    data.addByte(0);

    _writeChunk('IHDR', data.takeBytes());
  }

  void _writeIDAT() {
    // Build raw image data with filter bytes
    final rawData = BytesBuilder();

    for (int y = 0; y < image.height; y++) {
      // Filter type 0 (None) for simplicity
      rawData.addByte(0);

      for (int x = 0; x < image.width; x++) {
        final color = image.getPixel(x, y);
        rawData.addByte(color.red);
        rawData.addByte(color.green);
        rawData.addByte(color.blue);
        rawData.addByte(color.alpha);
      }
    }

    // Compress using zlib deflate
    final compressed = _zlibCompress(rawData.takeBytes());
    _writeChunk('IDAT', compressed);
  }

  void _writeIEND() {
    _writeChunk('IEND', Uint8List(0));
  }

  void _writeChunk(String type, Uint8List data) {
    // Length (4 bytes)
    output.add(_int32Bytes(data.length));

    // Type (4 bytes)
    output.add(utf8.encode(type));

    // Data
    output.add(data);

    // CRC32 (4 bytes)
    final crcData = BytesBuilder();
    crcData.add(utf8.encode(type));
    crcData.add(data);
    output.add(_int32Bytes(_crc32(crcData.takeBytes())));
  }

  Uint8List _int32Bytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }

  // Simple zlib compression (deflate with zlib header)
  Uint8List _zlibCompress(Uint8List data) {
    // For simplicity, we'll use uncompressed deflate blocks
    // In production, you'd want to use a proper deflate implementation

    final output = BytesBuilder();

    // zlib header
    output.addByte(0x78); // CMF
    output.addByte(0x01); // FLG (no compression)

    // Process data in chunks (max 65535 bytes per block)
    const maxBlockSize = 65535;
    int offset = 0;

    while (offset < data.length) {
      final remaining = data.length - offset;
      final blockSize = math.min(remaining, maxBlockSize);
      final isLast = offset + blockSize >= data.length;

      // Block header
      output.addByte(isLast ? 1 : 0); // BFINAL and BTYPE (00 = no compression)

      // Length and complement
      output.addByte(blockSize & 0xFF);
      output.addByte((blockSize >> 8) & 0xFF);
      output.addByte((~blockSize) & 0xFF);
      output.addByte(((~blockSize) >> 8) & 0xFF);

      // Raw data
      output.add(data.sublist(offset, offset + blockSize));

      offset += blockSize;
    }

    // Adler32 checksum
    output.add(_int32Bytes(_adler32(data)));

    return output.takeBytes();
  }

  // CRC32 implementation for PNG chunks
  int _crc32(Uint8List data) {
    const table = _crc32Table;
    int crc = 0xFFFFFFFF;

    for (int byte in data) {
      crc = table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }

    return crc ^ 0xFFFFFFFF;
  }

  // Adler32 checksum for zlib
  int _adler32(Uint8List data) {
    int a = 1;
    int b = 0;

    for (int byte in data) {
      a = (a + byte) % 65521;
      b = (b + a) % 65521;
    }

    return (b << 16) | a;
  }

  // CRC32 lookup table
  static const _crc32Table = [
    0x00000000,
    0x77073096,
    0xee0e612c,
    0x990951ba,
    0x076dc419,
    0x706af48f,
    0xe963a535,
    0x9e6495a3,
    0x0edb8832,
    0x79dcb8a4,
    0xe0d5e91e,
    0x97d2d988,
    0x09b64c2b,
    0x7eb17cbd,
    0xe7b82d07,
    0x90bf1d91,
    0x1db71064,
    0x6ab020f2,
    0xf3b97148,
    0x84be41de,
    0x1adad47d,
    0x6ddde4eb,
    0xf4d4b551,
    0x83d385c7,
    0x136c9856,
    0x646ba8c0,
    0xfd62f97a,
    0x8a65c9ec,
    0x14015c4f,
    0x63066cd9,
    0xfa0f3d63,
    0x8d080df5,
    0x3b6e20c8,
    0x4c69105e,
    0xd56041e4,
    0xa2677172,
    0x3c03e4d1,
    0x4b04d447,
    0xd20d85fd,
    0xa50ab56b,
    0x35b5a8fa,
    0x42b2986c,
    0xdbbbc9d6,
    0xacbcf940,
    0x32d86ce3,
    0x45df5c75,
    0xdcd60dcf,
    0xabd13d59,
    0x26d930ac,
    0x51de003a,
    0xc8d75180,
    0xbfd06116,
    0x21b4f4b5,
    0x56b3c423,
    0xcfba9599,
    0xb8bda50f,
    0x2802b89e,
    0x5f058808,
    0xc60cd9b2,
    0xb10be924,
    0x2f6f7c87,
    0x58684c11,
    0xc1611dab,
    0xb6662d3d,
    0x76dc4190,
    0x01db7106,
    0x98d220bc,
    0xefd5102a,
    0x71b18589,
    0x06b6b51f,
    0x9fbfe4a5,
    0xe8b8d433,
    0x7807c9a2,
    0x0f00f934,
    0x9609a88e,
    0xe10e9818,
    0x7f6a0dbb,
    0x086d3d2d,
    0x91646c97,
    0xe6635c01,
    0x6b6b51f4,
    0x1c6c6162,
    0x856530d8,
    0xf262004e,
    0x6c0695ed,
    0x1b01a57b,
    0x8208f4c1,
    0xf50fc457,
    0x65b0d9c6,
    0x12b7e950,
    0x8bbeb8ea,
    0xfcb9887c,
    0x62dd1ddf,
    0x15da2d49,
    0x8cd37cf3,
    0xfbd44c65,
    0x4db26158,
    0x3ab551ce,
    0xa3bc0074,
    0xd4bb30e2,
    0x4adfa541,
    0x3dd895d7,
    0xa4d1c46d,
    0xd3d6f4fb,
    0x4369e96a,
    0x346ed9fc,
    0xad678846,
    0xda60b8d0,
    0x44042d73,
    0x33031de5,
    0xaa0a4c5f,
    0xdd0d7cc9,
    0x5005713c,
    0x270241aa,
    0xbe0b1010,
    0xc90c2086,
    0x5768b525,
    0x206f85b3,
    0xb966d409,
    0xce61e49f,
    0x5edef90e,
    0x29d9c998,
    0xb0d09822,
    0xc7d7a8b4,
    0x59b33d17,
    0x2eb40d81,
    0xb7bd5c3b,
    0xc0ba6cad,
    0xedb88320,
    0x9abfb3b6,
    0x03b6e20c,
    0x74b1d29a,
    0xead54739,
    0x9dd277af,
    0x04db2615,
    0x73dc1683,
    0xe3630b12,
    0x94643b84,
    0x0d6d6a3e,
    0x7a6a5aa8,
    0xe40ecf0b,
    0x9309ff9d,
    0x0a00ae27,
    0x7d079eb1,
    0xf00f9344,
    0x8708a3d2,
    0x1e01f268,
    0x6906c2fe,
    0xf762575d,
    0x806567cb,
    0x196c3671,
    0x6e6b06e7,
    0xfed41b76,
    0x89d32be0,
    0x10da7a5a,
    0x67dd4acc,
    0xf9b9df6f,
    0x8ebeeff9,
    0x17b7be43,
    0x60b08ed5,
    0xd6d6a3e8,
    0xa1d1937e,
    0x38d8c2c4,
    0x4fdff252,
    0xd1bb67f1,
    0xa6bc5767,
    0x3fb506dd,
    0x48b2364b,
    0xd80d2bda,
    0xaf0a1b4c,
    0x36034af6,
    0x41047a60,
    0xdf60efc3,
    0xa867df55,
    0x316e8eef,
    0x4669be79,
    0xcb61b38c,
    0xbc66831a,
    0x256fd2a0,
    0x5268e236,
    0xcc0c7795,
    0xbb0b4703,
    0x220216b9,
    0x5505262f,
    0xc5ba3bbe,
    0xb2bd0b28,
    0x2bb45a92,
    0x5cb36a04,
    0xc2d7ffa7,
    0xb5d0cf31,
    0x2cd99e8b,
    0x5bdeae1d,
    0x9b64c2b0,
    0xec63f226,
    0x756aa39c,
    0x026d930a,
    0x9c0906a9,
    0xeb0e363f,
    0x72076785,
    0x05005713,
    0x95bf4a82,
    0xe2b87a14,
    0x7bb12bae,
    0x0cb61b38,
    0x92d28e9b,
    0xe5d5be0d,
    0x7cdcefb7,
    0x0bdbdf21,
    0x86d3d2d4,
    0xf1d4e242,
    0x68ddb3f8,
    0x1fda836e,
    0x81be16cd,
    0xf6b9265b,
    0x6fb077e1,
    0x18b74777,
    0x88085ae6,
    0xff0f6a70,
    0x66063bca,
    0x11010b5c,
    0x8f659eff,
    0xf862ae69,
    0x616bffd3,
    0x166ccf45,
    0xa00ae278,
    0xd70dd2ee,
    0x4e048354,
    0x3903b3c2,
    0xa7672661,
    0xd06016f7,
    0x4969474d,
    0x3e6e77db,
    0xaed16a4a,
    0xd9d65adc,
    0x40df0b66,
    0x37d83bf0,
    0xa9bcae53,
    0xdebb9ec5,
    0x47b2cf7f,
    0x30b5ffe9,
    0xbdbdf21c,
    0xcabac28a,
    0x53b39330,
    0x24b4a3a6,
    0xbad03605,
    0xcdd70693,
    0x54de5729,
    0x23d967bf,
    0xb3667a2e,
    0xc4614ab8,
    0x5d681b02,
    0x2a6f2b94,
    0xb40bbe37,
    0xc30c8ea1,
    0x5a05df1b,
    0x2d02ef8d,
  ];
}

/// PNG decoder implementation
class _PngDecoder {
  final Uint8List data;
  int offset = 0;

  int? width;
  int? height;
  int? bitDepth;
  int? colorType;
  Uint8List? imageData;

  _PngDecoder(this.data);

  Bitmap decode() {
    // Verify PNG signature
    if (!_checkSignature()) {
      throw FormatException('Invalid PNG signature');
    }

    offset = 8; // Skip signature

    // Read chunks
    while (offset < data.length) {
      final chunk = _readChunk();
      if (chunk.type == 'IEND') break;

      switch (chunk.type) {
        case 'IHDR':
          _parseIHDR(chunk.data);
          break;
        case 'IDAT':
          // Accumulate image data
          imageData = imageData == null
              ? chunk.data
              : Uint8List.fromList([...imageData!, ...chunk.data]);
          break;
      }
    }

    if (width == null || height == null || imageData == null) {
      throw FormatException('Invalid PNG file: missing required chunks');
    }

    // Decompress image data
    final decompressed = _zlibDecompress(imageData!);

    // Create bitmap and fill with decompressed data
    final bitmap = Bitmap(width!, height!);
    _fillBitmap(bitmap, decompressed);

    return bitmap;
  }

  bool _checkSignature() {
    if (data.length < 8) return false;
    for (int i = 0; i < 8; i++) {
      if (data[i] != PngImageCodec._pngSignature[i]) return false;
    }
    return true;
  }

  _Chunk _readChunk() {
    // Read length (4 bytes)
    final length = _readInt32();

    // Read type (4 bytes)
    final typeBytes = data.sublist(offset, offset + 4);
    offset += 4;
    final type = utf8.decode(typeBytes);

    // Read data
    final chunkData = data.sublist(offset, offset + length);
    offset += length;

    // Skip CRC (4 bytes)
    offset += 4;

    return _Chunk(type, chunkData);
  }

  void _parseIHDR(Uint8List ihdr) {
    width = _bytesToInt32(ihdr, 0);
    height = _bytesToInt32(ihdr, 4);
    bitDepth = ihdr[8];
    colorType = ihdr[9];
    // Skip compression method, filter method, interlace method
  }

  int _readInt32() {
    final value = _bytesToInt32(data, offset);
    offset += 4;
    return value;
  }

  int _bytesToInt32(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  // Simple zlib decompression for uncompressed blocks
  Uint8List _zlibDecompress(Uint8List compressed) {
    // Skip zlib header (2 bytes)
    int offset = 2;
    final output = BytesBuilder();

    while (offset < compressed.length - 4) {
      // -4 for Adler32
      // Read block header
      final header = compressed[offset++];
      final bfinal = header & 1;
      final btype = (header >> 1) & 3;

      if (btype == 0) {
        // Uncompressed block
        // Read length and complement
        final len = compressed[offset] | (compressed[offset + 1] << 8);
        offset += 4; // Skip length and complement

        // Read raw data
        output.add(compressed.sublist(offset, offset + len));
        offset += len;

        if (bfinal != 0) break;
      } else {
        // For compressed blocks, we'd need a full deflate implementation
        // For now, throw an error
        throw UnsupportedFormatException(
          'PNG',
          'Compressed PNG blocks not yet supported',
        );
      }
    }

    return output.takeBytes();
  }

  void _fillBitmap(Bitmap bitmap, Uint8List data) {
    int dataOffset = 0;

    for (int y = 0; y < height!; y++) {
      // Skip filter byte
      dataOffset++;

      for (int x = 0; x < width!; x++) {
        if (colorType == 6) {
          // RGBA
          final r = data[dataOffset++];
          final g = data[dataOffset++];
          final b = data[dataOffset++];
          final a = data[dataOffset++];
          bitmap.setPixel(x, y, Color.fromRGBA(r, g, b, a));
        } else if (colorType == 2) {
          // RGB
          final r = data[dataOffset++];
          final g = data[dataOffset++];
          final b = data[dataOffset++];
          bitmap.setPixel(x, y, Color.fromRGBA(r, g, b, 255));
        }
      }
    }
  }
}

class _Chunk {
  final String type;
  final Uint8List data;

  _Chunk(this.type, this.data);
}

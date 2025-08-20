import 'dart:io';
import 'dart:typed_data';

void main(List<String> args) async {
  if (args.length != 2) {
    print('Usage: dart compare_images.dart <image1.ppm> <image2.ppm>');
    exit(1);
  }

  final file1 = File(args[0]);
  final file2 = File(args[1]);

  if (!file1.existsSync() || !file2.existsSync()) {
    print('Error: One or both files do not exist');
    exit(1);
  }

  final bytes1 = await file1.readAsBytes();
  final bytes2 = await file2.readAsBytes();

  // Parse PPM headers
  final header1 = parsePPMHeader(bytes1);
  final header2 = parsePPMHeader(bytes2);

  if (header1.width != header2.width || header1.height != header2.height) {
    print('Images have different dimensions:');
    print('  ${args[0]}: ${header1.width}x${header1.height}');
    print('  ${args[1]}: ${header2.width}x${header2.height}');
    exit(1);
  }

  print('Comparing ${header1.width}x${header1.height} images...');

  // Compare pixel data
  final pixelStart1 = header1.dataOffset;
  final pixelStart2 = header2.dataOffset;

  int totalPixels = header1.width * header1.height;
  int differentPixels = 0;
  double totalDiff = 0;
  double maxDiff = 0;

  for (int i = 0; i < totalPixels * 3; i += 3) {
    final r1 = bytes1[pixelStart1 + i];
    final g1 = bytes1[pixelStart1 + i + 1];
    final b1 = bytes1[pixelStart1 + i + 2];

    final r2 = bytes2[pixelStart2 + i];
    final g2 = bytes2[pixelStart2 + i + 1];
    final b2 = bytes2[pixelStart2 + i + 2];

    if (r1 != r2 || g1 != g2 || b1 != b2) {
      differentPixels++;
      final diff = ((r1 - r2).abs() + (g1 - g2).abs() + (b1 - b2).abs()) / 3.0;
      totalDiff += diff;
      if (diff > maxDiff) maxDiff = diff;
    }
  }

  final percentDifferent = (differentPixels / totalPixels) * 100;
  final avgDiff = differentPixels > 0 ? totalDiff / differentPixels : 0;

  print('\nResults:');
  print('  Total pixels: $totalPixels');
  print(
    '  Different pixels: $differentPixels (${percentDifferent.toStringAsFixed(2)}%)',
  );
  print('  Average difference: ${avgDiff.toStringAsFixed(2)}/255');
  print('  Maximum difference: ${maxDiff.toStringAsFixed(2)}/255');

  if (differentPixels == 0) {
    print('\nImages are IDENTICAL!');
  } else if (percentDifferent < 1) {
    print('\nImages are NEARLY IDENTICAL (less than 1% difference)');
  } else if (percentDifferent < 5) {
    print('\nImages are VERY SIMILAR (less than 5% difference)');
  } else {
    print('\nImages have SIGNIFICANT DIFFERENCES');
  }
}

class PPMHeader {
  final int width;
  final int height;
  final int dataOffset;

  PPMHeader(this.width, this.height, this.dataOffset);
}

PPMHeader parsePPMHeader(Uint8List bytes) {
  int offset = 0;

  // Skip P6
  while (bytes[offset] != 0x0A) offset++; // Skip to newline
  offset++;

  // Read width
  String widthStr = '';
  while (bytes[offset] >= 0x30 && bytes[offset] <= 0x39) {
    widthStr += String.fromCharCode(bytes[offset]);
    offset++;
  }
  final width = int.parse(widthStr);

  // Skip whitespace
  while (bytes[offset] == 0x20 ||
      bytes[offset] == 0x0A ||
      bytes[offset] == 0x0D)
    offset++;

  // Read height
  String heightStr = '';
  while (bytes[offset] >= 0x30 && bytes[offset] <= 0x39) {
    heightStr += String.fromCharCode(bytes[offset]);
    offset++;
  }
  final height = int.parse(heightStr);

  // Skip to 255 and newline
  while (bytes[offset] != 0x0A) offset++;
  offset++;

  return PPMHeader(width, height, offset);
}

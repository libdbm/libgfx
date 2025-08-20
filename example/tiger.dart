import 'dart:io';
import 'package:libgfx/libgfx.dart';

void main() async {
  final engine = GraphicsEngine(900, 900);

  // White background
  engine.clear(Color.fromARGB(255, 255, 255, 255));

  // Load and parse SVG
  final svgContent = await File('data/tiger.svg').readAsString();
  final paths = parseSVGPaths(svgContent);

  // Apply transform to fit the SVG viewBox (0, 0, 680, 688) into 900x900 canvas
  engine.save();

  // Center and scale to fit
  final scaleX = 900.0 / 680.0;
  final scaleY = 900.0 / 688.0;
  final scale = (scaleX < scaleY) ? scaleX : scaleY;

  engine.translate(450, 450); // Center of canvas
  engine.scale(scale, -scale); // Negative scale on Y to flip vertically
  engine.translate(-340, -344); // Center of SVG viewBox

  // Draw all paths
  for (final pathData in paths) {
    engine.setFillColor(pathData.color);
    engine.fill(pathData.path);
  }

  engine.restore();

  // Save the image
  final bytes = GraphicsEngine.saveImageToBytes(engine.canvas, 'p3');
  await File('output/tiger.ppm').writeAsBytes(bytes);
  print('Tiger from SVG saved to output/tiger.ppm');
}

class SVGPathData {
  final Path path;
  final Color color;

  SVGPathData(this.path, this.color);
}

List<SVGPathData> parseSVGPaths(String svgContent) {
  final paths = <SVGPathData>[];

  // Regular expression to match path elements
  final pathRegex = RegExp(
    r'<path\s+d="([^"]+)"(?:\s+fill="([^"]+)")?[^>]*/?>',
    multiLine: true,
  );

  for (final match in pathRegex.allMatches(svgContent)) {
    final pathData = match.group(1);
    final fillColor = match.group(2) ?? '#000000';

    if (pathData != null) {
      try {
        final path = parseSVGPathData(pathData);
        final color = parseColor(fillColor);
        paths.add(SVGPathData(path, color));
      } catch (e) {
        print('Failed to parse path: $e');
      }
    }
  }

  return paths;
}

Color parseColor(String colorStr) {
  if (colorStr.startsWith('#')) {
    final hex = colorStr.substring(1);
    if (hex.length == 6) {
      final r = int.parse(hex.substring(0, 2), radix: 16);
      final g = int.parse(hex.substring(2, 4), radix: 16);
      final b = int.parse(hex.substring(4, 6), radix: 16);
      return Color.fromARGB(255, r, g, b);
    }
  }
  // Default to black if parsing fails
  return Color.fromARGB(255, 0, 0, 0);
}

Path parseSVGPathData(String pathData) {
  final builder = PathBuilder();
  final commands = tokenizeSVGPath(pathData);

  double currentX = 0;
  double currentY = 0;
  double lastControlX = 0;
  double lastControlY = 0;
  double startX = 0;
  double startY = 0;
  String lastCommand = '';

  int i = 0;
  while (i < commands.length) {
    final cmd = commands[i];
    i++;

    switch (cmd.toUpperCase()) {
      case 'M':
        if (i + 1 < commands.length) {
          final x = double.parse(commands[i++]);
          final y = double.parse(commands[i++]);
          if (cmd == 'M') {
            builder.moveTo(x, y);
            currentX = x;
            currentY = y;
          } else {
            builder.moveTo(currentX + x, currentY + y);
            currentX += x;
            currentY += y;
          }
          startX = currentX;
          startY = currentY;

          // Handle implicit lineTo after moveTo
          while (i + 1 < commands.length &&
              double.tryParse(commands[i]) != null &&
              double.tryParse(commands[i + 1]) != null) {
            final lx = double.parse(commands[i++]);
            final ly = double.parse(commands[i++]);
            if (cmd == 'M') {
              builder.lineTo(lx, ly);
              currentX = lx;
              currentY = ly;
            } else {
              builder.lineTo(currentX + lx, currentY + ly);
              currentX += lx;
              currentY += ly;
            }
          }
        }
        break;

      case 'L':
        while (i + 1 < commands.length &&
            double.tryParse(commands[i]) != null &&
            double.tryParse(commands[i + 1]) != null) {
          final x = double.parse(commands[i++]);
          final y = double.parse(commands[i++]);
          if (cmd == 'L') {
            builder.lineTo(x, y);
            currentX = x;
            currentY = y;
          } else {
            builder.lineTo(currentX + x, currentY + y);
            currentX += x;
            currentY += y;
          }
        }
        break;

      case 'H':
        while (i < commands.length && double.tryParse(commands[i]) != null) {
          final x = double.parse(commands[i++]);
          if (cmd == 'H') {
            builder.lineTo(x, currentY);
            currentX = x;
          } else {
            builder.lineTo(currentX + x, currentY);
            currentX += x;
          }
        }
        break;

      case 'V':
        while (i < commands.length && double.tryParse(commands[i]) != null) {
          final y = double.parse(commands[i++]);
          if (cmd == 'V') {
            builder.lineTo(currentX, y);
            currentY = y;
          } else {
            builder.lineTo(currentX, currentY + y);
            currentY += y;
          }
        }
        break;

      case 'C':
        while (i + 5 < commands.length &&
            double.tryParse(commands[i]) != null &&
            double.tryParse(commands[i + 5]) != null) {
          final x1 = double.parse(commands[i++]);
          final y1 = double.parse(commands[i++]);
          final x2 = double.parse(commands[i++]);
          final y2 = double.parse(commands[i++]);
          final x = double.parse(commands[i++]);
          final y = double.parse(commands[i++]);

          if (cmd == 'C') {
            builder.curveTo(x1, y1, x2, y2, x, y);
            currentX = x;
            currentY = y;
            lastControlX = x2;
            lastControlY = y2;
          } else {
            builder.curveTo(
              currentX + x1,
              currentY + y1,
              currentX + x2,
              currentY + y2,
              currentX + x,
              currentY + y,
            );
            lastControlX = currentX + x2;
            lastControlY = currentY + y2;
            currentX += x;
            currentY += y;
          }
        }
        break;

      case 'S':
        while (i + 3 < commands.length &&
            double.tryParse(commands[i]) != null &&
            double.tryParse(commands[i + 3]) != null) {
          final x2 = double.parse(commands[i++]);
          final y2 = double.parse(commands[i++]);
          final x = double.parse(commands[i++]);
          final y = double.parse(commands[i++]);

          // Calculate first control point as reflection of previous
          double x1, y1;
          if (lastCommand.toUpperCase() == 'C' ||
              lastCommand.toUpperCase() == 'S') {
            x1 = 2 * currentX - lastControlX;
            y1 = 2 * currentY - lastControlY;
          } else {
            x1 = currentX;
            y1 = currentY;
          }

          if (cmd == 'S') {
            builder.curveTo(x1, y1, x2, y2, x, y);
            currentX = x;
            currentY = y;
            lastControlX = x2;
            lastControlY = y2;
          } else {
            builder.curveTo(
              x1,
              y1,
              currentX + x2,
              currentY + y2,
              currentX + x,
              currentY + y,
            );
            lastControlX = currentX + x2;
            lastControlY = currentY + y2;
            currentX += x;
            currentY += y;
          }
        }
        break;

      case 'Z':
        builder.close();
        currentX = startX;
        currentY = startY;
        break;

      default:
        // Skip unknown commands
        continue;
    }

    if (cmd.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(cmd)) {
      lastCommand = cmd;
    }
  }

  return builder.build();
}

List<String> tokenizeSVGPath(String pathData) {
  final tokens = <String>[];
  final buffer = StringBuffer();

  for (int i = 0; i < pathData.length; i++) {
    final char = pathData[i];

    if (RegExp(r'[MmLlHhVvCcSsQqTtAaZz]').hasMatch(char)) {
      // Command character
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
      tokens.add(char);
    } else if (char == ',' ||
        char == ' ' ||
        char == '\n' ||
        char == '\r' ||
        char == '\t') {
      // Separator
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
    } else if (char == '-') {
      // Negative number start
      if (buffer.isNotEmpty &&
          !buffer.toString().endsWith('e') &&
          !buffer.toString().endsWith('E')) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
      buffer.write(char);
    } else if (char == '.') {
      // Decimal point - could be start of new number or part of current
      if (buffer.isNotEmpty && buffer.toString().contains('.')) {
        // Already has decimal, must be new number
        tokens.add(buffer.toString());
        buffer.clear();
      }
      buffer.write(char);
    } else {
      // Part of a number
      buffer.write(char);
    }
  }

  if (buffer.isNotEmpty) {
    tokens.add(buffer.toString());
  }

  return tokens;
}

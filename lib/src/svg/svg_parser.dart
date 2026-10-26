import 'dart:math';

import '../color/color.dart';
import '../logging.dart';
import '../paths/path.dart';

/// A filled path read from an SVG document
class SVGPath {
  final Path path;
  final Color color;

  SVGPath(this.path, this.color);

  /// The `<path>` elements of [svg] with their fill colors; other elements
  /// are ignored, and a path that fails to parse is logged and skipped
  static List<SVGPath> parse(final String svg) => _parse(svg);
}

List<SVGPath> _parse(String svg) {
  final paths = <SVGPath>[];

  // Regular expression to match path elements
  final pattern = RegExp(
    r'<path\s+d="([^"]+)"(?:\s+fill="([^"]+)")?[^>]*/?>',
    multiLine: true,
  );

  for (final match in pattern.allMatches(svg)) {
    final data = match.group(1);
    final fill = match.group(2) ?? '#000000';

    if (data != null) {
      try {
        final path = _path(data);
        final color = _color(fill);
        paths.add(SVGPath(path, color));
      } catch (e) {
        logger.warning('Failed to parse path: $e');
      }
    }
  }

  return paths;
}

Color _color(final String text) {
  if (text.startsWith('#')) {
    final hex = text.substring(1);
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

Path _path(final String data) {
  final builder = PathBuilder();
  final commands = _tokenize(data);

  double currentX = 0;
  double currentY = 0;
  double controlX = 0;
  double controlY = 0;
  // Control point of the last quadratic curve, which T reflects
  double quadraticX = 0;
  double quadraticY = 0;
  double startX = 0;
  double startY = 0;
  String previous = '';

  int i = 0;
  while (i < commands.length) {
    final command = commands[i];
    i++;

    switch (command.toUpperCase()) {
      case 'M':
        if (i + 1 < commands.length) {
          final x = double.parse(commands[i++]);
          final y = double.parse(commands[i++]);
          if (command == 'M') {
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
            if (command == 'M') {
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
          if (command == 'L') {
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
          if (command == 'H') {
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
          if (command == 'V') {
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

          if (command == 'C') {
            builder.bezierCurveTo(x1, y1, x2, y2, x, y);
            currentX = x;
            currentY = y;
            controlX = x2;
            controlY = y2;
          } else {
            builder.bezierCurveTo(
              currentX + x1,
              currentY + y1,
              currentX + x2,
              currentY + y2,
              currentX + x,
              currentY + y,
            );
            controlX = currentX + x2;
            controlY = currentY + y2;
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
          if (previous.toUpperCase() == 'C' || previous.toUpperCase() == 'S') {
            x1 = 2 * currentX - controlX;
            y1 = 2 * currentY - controlY;
          } else {
            x1 = currentX;
            y1 = currentY;
          }

          if (command == 'S') {
            builder.bezierCurveTo(x1, y1, x2, y2, x, y);
            currentX = x;
            currentY = y;
            controlX = x2;
            controlY = y2;
          } else {
            builder.bezierCurveTo(
              x1,
              y1,
              currentX + x2,
              currentY + y2,
              currentX + x,
              currentY + y,
            );
            controlX = currentX + x2;
            controlY = currentY + y2;
            currentX += x;
            currentY += y;
          }
        }
        break;

      case 'Q':
        while (i + 3 < commands.length &&
            double.tryParse(commands[i]) != null &&
            double.tryParse(commands[i + 3]) != null) {
          final relative = command == 'q';
          final baseX = relative ? currentX : 0.0;
          final baseY = relative ? currentY : 0.0;
          quadraticX = baseX + double.parse(commands[i++]);
          quadraticY = baseY + double.parse(commands[i++]);
          currentX = baseX + double.parse(commands[i++]);
          currentY = baseY + double.parse(commands[i++]);
          builder.quadraticCurveTo(quadraticX, quadraticY, currentX, currentY);
        }
        break;

      case 'T':
        var follows =
            previous.toUpperCase() == 'Q' || previous.toUpperCase() == 'T';
        while (i + 1 < commands.length &&
            double.tryParse(commands[i]) != null &&
            double.tryParse(commands[i + 1]) != null) {
          // Reflect the last control point, or use the current point
          quadraticX = follows ? 2 * currentX - quadraticX : currentX;
          quadraticY = follows ? 2 * currentY - quadraticY : currentY;
          follows = true;
          final relative = command == 't';
          currentX = (relative ? currentX : 0) + double.parse(commands[i++]);
          currentY = (relative ? currentY : 0) + double.parse(commands[i++]);
          builder.quadraticCurveTo(quadraticX, quadraticY, currentX, currentY);
        }
        break;

      case 'A':
        while (i + 2 < commands.length &&
            double.tryParse(commands[i]) != null) {
          final radiusX = double.parse(commands[i++]);
          final radiusY = double.parse(commands[i++]);
          final rotation = double.parse(commands[i++]);
          final large = _flag(commands, i);
          if (large == null) break;
          i = large.next;
          final sweep = _flag(commands, i);
          if (sweep == null || sweep.next + 1 >= commands.length) break;
          i = sweep.next;
          final relative = command == 'a';
          final x = (relative ? currentX : 0) + double.parse(commands[i++]);
          final y = (relative ? currentY : 0) + double.parse(commands[i++]);
          _arc(
            builder,
            currentX,
            currentY,
            radiusX,
            radiusY,
            rotation * pi / 180,
            large.value,
            sweep.value,
            x,
            y,
          );
          currentX = x;
          currentY = y;
        }
        break;

      case 'Z':
        builder.closePath();
        currentX = startX;
        currentY = startY;
        break;

      default:
        // Skip unknown commands
        continue;
    }

    if (command.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(command)) {
      previous = command;
    }
  }

  return builder.build();
}

/// The arc flag at [index] of [tokens] and the index after it. A flag is a
/// single 0 or 1 and may run into what follows (`0110` is two flags and 10),
/// so a longer token is split, leaving its remainder at [index].
({bool value, int next})? _flag(final List<String> tokens, final int index) {
  if (index >= tokens.length) return null;
  final token = tokens[index];
  if (token.isEmpty || (token[0] != '0' && token[0] != '1')) return null;
  if (token.length == 1) return (value: token == '1', next: index + 1);
  tokens[index] = token.substring(1);
  return (value: token[0] == '1', next: index);
}

/// Adds the SVG elliptical arc from (x1, y1) to (x2, y2), converted from
/// endpoint to centre form as in SVG implementation notes B.2.4: nothing
/// when the end points coincide, a line when either radius is zero or the
/// arc turns too little to draw, and radii too small to join the points
/// scaled up until they do (B.2.5).
void _arc(
  final PathBuilder builder,
  final double x1,
  final double y1,
  final double rx,
  final double ry,
  final double rotation,
  final bool large,
  final bool sweep,
  final double x2,
  final double y2,
) {
  if (x1 == x2 && y1 == y2) return;
  if (rx == 0 || ry == 0) {
    builder.lineTo(x2, y2);
    return;
  }

  final cosine = cos(rotation);
  final sine = sin(rotation);

  // The midpoint between the ends, in the ellipse's own axes
  final dx = (x1 - x2) / 2;
  final dy = (y1 - y2) / 2;
  final x = cosine * dx + sine * dy;
  final y = -sine * dx + cosine * dy;

  var radiusX = rx.abs();
  var radiusY = ry.abs();
  final reach = (x * x) / (radiusX * radiusX) + (y * y) / (radiusY * radiusY);
  if (reach > 1) {
    radiusX *= sqrt(reach);
    radiusY *= sqrt(reach);
  }

  // The centre, on the side the flags choose
  final xx = radiusX * radiusX * y * y;
  final yy = radiusY * radiusY * x * x;
  final square = (radiusX * radiusX * radiusY * radiusY - xx - yy) / (xx + yy);
  final scale = (large == sweep ? -1 : 1) * sqrt(max(0, square));
  final centreX = scale * radiusX * y / radiusY;
  final centreY = -scale * radiusY * x / radiusX;

  final start = atan2((y - centreY) / radiusY, (x - centreX) / radiusX);
  final end = atan2((-y - centreY) / radiusY, (-x - centreX) / radiusX);
  var turn = end - start;
  if (sweep && turn < 0) turn += 2 * pi;
  if (!sweep && turn > 0) turn -= 2 * pi;

  // PathBuilder.ellipse draws nothing for so small a turn; the line strays
  // from the arc by under a millionth of the radius
  if (turn.abs() < 0.001) {
    builder.lineTo(x2, y2);
    return;
  }

  builder.ellipse(
    cosine * centreX - sine * centreY + (x1 + x2) / 2,
    sine * centreX + cosine * centreY + (y1 + y2) / 2,
    radiusX,
    radiusY,
    rotation,
    start,
    start + turn,
    !sweep,
  );
}

List<String> _tokenize(final String data) {
  final tokens = <String>[];
  final buffer = StringBuffer();

  for (int i = 0; i < data.length; i++) {
    final char = data[i];

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

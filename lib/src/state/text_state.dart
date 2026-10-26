import '../fonts/font.dart';
import '../text/text_rendering.dart';
import '../text/text_types.dart';
import 'state_base.dart';

/// Manages text settings: font, size, alignment, baseline, direction and
/// rendering
class TextState extends StateBase<TextState> {
  Font? _font;
  double _size;
  TextAlign _align;
  TextBaseline _baseline;
  TextDirection _direction;
  TextRendering _rendering;

  TextState({
    Font? font,
    double fontSize = 12.0,
    TextAlign textAlign = TextAlign.start,
    TextBaseline textBaseline = TextBaseline.alphabetic,
    TextDirection direction = TextDirection.ltr,
    TextRendering textRendering = TextRendering.auto,
  }) : _font = font,
       _size = fontSize,
       _align = textAlign,
       _baseline = textBaseline,
       _direction = direction,
       _rendering = textRendering;

  Font? get font => _font;
  double get fontSize => _size;
  TextAlign get textAlign => _align;
  TextBaseline get textBaseline => _baseline;
  TextDirection get direction => _direction;
  TextRendering get textRendering => _rendering;

  void setFont(Font? font) {
    _font = font;
  }

  void setFontSize(double size) {
    _size = size;
  }

  void setTextAlign(TextAlign align) {
    _align = align;
  }

  void setTextBaseline(TextBaseline baseline) {
    _baseline = baseline;
  }

  void setDirection(TextDirection direction) {
    _direction = direction;
  }

  void setTextRendering(TextRendering rendering) {
    _rendering = rendering;
  }

  @override
  TextState clone() {
    return TextState(
      font: _font,
      fontSize: _size,
      textAlign: _align,
      textBaseline: _baseline,
      direction: _direction,
      textRendering: _rendering,
    );
  }
}

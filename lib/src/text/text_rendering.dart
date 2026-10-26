/// How text is rasterized, as W3C canvas `textRendering`: every value but
/// [geometricPrecision] darkens partly covered pixels of text, so that
/// unhinted stems that fall between pixels read less blurred;
/// [geometricPrecision] draws the exact coverage of the outlines
enum TextRendering {
  auto,
  optimizeSpeed,
  optimizeLegibility,
  geometricPrecision,
}

## 1.0.0

- Initial release of libgfx
- Comprehensive 2D vector graphics engine with software rasterization
- Full TrueType font support with text rendering
- Linear, radial, and conic gradients
- Advanced blend modes and image filters
- Path operations and boolean operations
- Multiple image codec support (PNG, BMP, PPM)
- Fluent API for chainable operations
- 30+ example programs demonstrating features
- Font files distributed separately via download scripts to reduce package size

## 1.0.1

- Minor upgrades

## 1.0.2

- Linting upgrade

## 1.0.3

- Update dependencies

## 1.0.4

- Maintenance and housekeeping
  - Update Dart SDK constraint to ^3.8.1
  - Update dev dependencies: lints ^6.0.0, test ^1.24.0
- Documentation and examples
  - Improve README and examples;
- Code quality
  - Apply lint fixes, minor refactors, and formatting
- Pulled SVG parsing out into the library
- Performance improvements for common operations
- Added I/O abstraction to allow the library to run in the browser
- Update documentation as appropriate



## 2.0.0

Rendering correctness, hardened parsing of untrusted fonts and images, a complete pure-Dart PNG decoder, and
documentation that matches the API. 

### Breaking changes

Each change is followed by how to migrate.

- **Loading returns `Result` instead of throwing.** `TTFFont.fromBytes` returns `Result<TTFFont, ErrorDetails>`;
  `TTFFont.load`, `FontFallbackChain.load`, `GraphicsEngine.loadFont` return `Future<Result<...>>`;
  `GraphicsEngine.readFont` and `GraphicsEngine.decode` return `Result` (names as renamed below).
  `ErrorDetails.kind` is one of `truncated`, `malformed`, `unsupported`, `limit`, `io` or `singular`. A failed font load
  keeps the current font.
  - Migration: replace `try`/`catch` (or unchecked use) with a switch:
    `switch (TTFFont.fromBytes(bytes)) { case Ok(:final value): use(value); case Err(:final error): report(error); }`.
- **`Matrix2D.inverse()` returns `Result<Matrix2D, ErrorDetails>`**, `Err(singular)` for a non-invertible matrix;
  `invert()`, which silently reset the matrix to identity, is removed.
  - Migration: `if (matrix.inverse() case Ok(:final value)) { ... }`; use `isInvertible` to test first.
- **`Matrix2D.decompose()` returns a record** `({Point translation, double rotation, Point scale})` instead of filling
  out-parameters.
  - Migration: `final (:translation, :rotation, :scale) = matrix.decompose();`.
- **`Point` is immutable**: `x` and `y` are final and the constructor is `const`.
  - Migration: build a new point (`Point(p.x + 1, p.y)`) instead of assigning `p.x`.
- **Paths are immutable after construction.** `Path.commands` and `PathCommand.points` are unmodifiable; a
  `PathCommand` copies the points it is given.
  - Migration: add commands with `add`/`addPath` or a `PathBuilder` instead of `path.commands.add(...)`.
- **Gradients are immutable.** `addColorStop` returns a new gradient of the same type instead of changing the gradient;
  `setColorStops` and `clearColorStops` are removed. Constructor stops are copied, clamped to 0..1 and sorted (stops at
  the same offset keep their order).
  - Migration: `gradient = gradient.addColorStop(0.5, color);`, or pass all stops to the constructor. The engine's
    `createLinearGradient`/`createRadialGradient`/`createConicGradient` still return empty gradients to extend this way.
- **`PatternPaint` copies its bitmap and transform**; its `pattern` and `transform` getters return copies.
  - Migration: changing the source bitmap or matrix after construction no longer changes the paint; create a new
    `PatternPaint` instead.
- **`fill` and `clip` use the non-zero fill rule by default**, as W3C canvas does (fills previously behaved as
  even-odd, and `clip` used even-odd): `fill(Path path, [FillRule rule])` and `clip(Path path, [FillRule rule])`.
  `clipWithFillRule` is removed.
  - Migration: pass `FillRule.evenOdd` where shapes with holes relied on even-odd: `engine.fill(path, FillRule.evenOdd)`,
    `engine.clip(path, FillRule.evenOdd)`.
- **Text settings are saved state.** Font, size, alignment and baseline are covered by `save()`/`restore()`.
  - Migration: settings changed inside a `save()`/`restore()` pair no longer persist after `restore()`; set them
    outside the pair if they should.
- **Resource limits.** `Bitmap` throws `ArgumentError` for negative dimensions or more than 2^28 pixels; fonts over
  64 MiB, composite glyphs nested deeper than 16 or larger than 65536 points, and images over the dimension and pixel
  limits are rejected with `Err(limit)`; blur radii over 256 and dash patterns producing more than 1e6 pieces per path
  throw `ArgumentError`.
  - Migration: pass a custom `Limits` (`GraphicsEngine(w, h, limits: ...)`, `TTFFont.fromBytes(bytes, limits: ...)`,
    `GraphicsEngine.decode(bytes, limits: ...)`, `ImageFilters.gaussian(image, sigma, limits: ...)`) to raise them.
- **Names follow the W3C canvas API and single words.** `GraphicsEngine` uses the `CanvasRenderingContext2D` names
  where one exists: canvas state is set through properties, `PathBuilder` has `bezierCurveTo`, `closePath`, `rect`
  and `roundRect`, and `arc` takes an end angle. Elsewhere multi-word and abbreviated names become single words. Old
  names are removed, not deprecated. `Color` implements `Paint`, so `SolidPaint` is removed.
  - **`PathBuilder.arc` takes an end angle** (it took a sweep), drawn in increasing angle unless `counterclockwise`,
    with at most one full turn: `arc(x, y, radius, start, start + sweep)` draws what `arc(x, y, radius, start, sweep)`
    drew. `ellipse` follows the same rules.
  - **`createConicGradient(startAngle, x, y)`** takes its arguments in W3C order (it took `cx, cy, angle`).
  - **Shapes moved to `PathBuilder`:** the `fill`/`stroke` pairs for round rectangles, circles, ellipses, polygons and
    stars, and the static `create*Path` methods, are removed. Build the shape and fill it:
    `engine.fill(PathBuilder().roundRect(x, y, width, height, radius).build())`. `fillRect`, `strokeRect`,
    `clearRect` and `clipRect` remain.
  - **`drawImage(image, dx, dy, {width, height, source, filter})`** replaces `drawImageScaled` and `drawImageRect`,
    and takes the `ImageFilter` used to sample the image (nearest by default). `ImageOptions` is removed.
  - Migration: rename by the table below; most changes are mechanical.

  | Type | Old | New |
  |---|---|---|
  | GraphicsEngine | `setFillColor`, `setFillPaint`, `setFillStyle` | `fillStyle = ...` |
  | | `setStrokeColor`, `setStrokePaint`, `setStrokeStyle` | `strokeStyle = ...` |
  | | `setLineWidth`, `setLineCap`, `setLineJoin`, `setMiterLimit` | `lineWidth`, `lineCap`, `lineJoin`, `miterLimit` |
  | | `setGlobalAlpha`, `setGlobalCompositeOperation` | `globalAlpha`, `globalCompositeOperation` |
  | | `setFontSize`, `setTextAlign`, `setTextBaseline`, `currentFont` | `fontSize`, `textAlign`, `textBaseline`, `font` |
  | | `setFontFromFile`, `setFontFromBytes` | `loadFont`, `readFont` |
  | | `clipWithFillRule(path, fillRule: rule)` | `clip(path, rule)` |
  | | `saveToFile`, `getPixel`, `setPixel`, `toBitmap` | `write`, `pixel`, `plot`, `snapshot` |
  | | `loadImageFromBytes`, `saveImageToBytes` | `decode`, `encode` |
  | | `fillAndStrokeText` | `fillText` then `strokeText` |
  | PathBuilder | `curveTo`, `cubicCurveTo`, `close` | `bezierCurveTo`, `closePath` |
  | Path | `addCommand`, `exclusiveOr` | `add`, `xor` |
  | Paint | `getColorAt` | `sample` |
  | GradientPaint | `withColorStop`, `withColorStops` | `addColorStop`, constructor `stops:` |
  | | `getColorAtOffset`, `applySpread` | `lookup`, `wrap` |
  | LinearGradient | `startPoint`, `endPoint`, `getTAt`, `getTDeltaX` | `start`, `end`, `offset`, `step` |
  | Color, ColorUtils | `ColorUtils.parseHexColor` | `Color.parse` (returns `Result`) |
  | | `unpremultiplyRGBA`, `toGrayscale`, `adjustBrightness`, `withAlpha` | `unpremultiply`, `grayscale`, `brighten`, `opacity` |
  | | `lerpRgb`, `bilerpColor`, `hslToRgb(hsl)` | `lerp`, `bilerp`, `hsl.color` |
  | Matrix2D | `setIdentity`, `setTransform`, `preMultiply`, `transformVector`, `rotateZ` | `reset`, `assign`, `premultiply`, `direction`, `rotate` |
  | Point | `distanceTo`, `distanceToSquared` | `distance`, `distance2` |
  | Bitmap | `getPixel`, `setPixel`, `blendPixel` | `pixel`, `plot`, `blend` |
  | | `flipHorizontal`, `flipVertical`, `withOpacity`, `rotateAngle` | `mirror`, `flip`, `fade`, `rotate` |
  | | `drawHorizontalSpan`, `drawAntiAliasedSpan`, `fillSolid` | `span`, `shade`, `fill` |
  | Font, TTFFont | `familyName`, `styleName`, `fullName` | `family`, `style`, `name` |
  | | `getGlyphIndex`, `getGlyphMetrics`, `getGlyphPath`, `getKerning`, `hasGlyph` | `glyph`, `dimensions`, `outline`, `kerning`, `covers` |
  | | `measureText`, `getTextPath`, `TTFFont.loadFromFile` | `measure`, `path`, `TTFFont.load` |
  | FontFallbackChain | `primaryFont`, `addFont`, `addFontFromFile`, `removeFont` | `primary`, `add`, `load`, `remove` |
  | | `getFontForCharacter`, `getFontForString`, `hasGlyph`, `splitIntoFontRuns` | `lookup`, `find`, `covers`, `runs` |
  | | `measureText`, `getTextPath`, `SystemFontManager.loadSystemFonts` | `measure`, `path`, `SystemFontManager.load` |
  | TextEngine | `addFont`, `clearCache`, `cacheStats`, `measureText`, `shapeText` | `add`, `purge`, `stats`, `measure`, `shape` |
  | | `generateTextPath`, `generateMultilineTextPaths`, `layoutMultilineText`, `breakLines` | `path`, `paths`, `wrap`, `split` |
  | TextShaper | `shapeText`; `ShapedGlyph.glyphId`; `ShapedText.totalAdvance` | `shape`; `glyph`; `advance` |
  | TextRenderer | `addFont`, `primaryFont`, `getTextPath`, `measureText` | `add`, `primary`, `path`, `measure` |
  | | `renderUnicodeText`, `measureUnicodeText`, `getTextPathWithSpacing`, `getWrappedTextPaths`, `getCategory` | `layout`, `extent`, `spaced`, `wrap`, `category` |
  | TransformUtils | `fitRect`, `positionInRect`, `createTRS`, `createSRT` | `fit`, `position`, `compose`, `reverse` |
  | | `transformBounds`, `transformPointsBounds`, `getTranslation`, `getRotation`, `getScale` | `bounds`, `extent`, `translation`, `rotation`, `scale` |
  | ImageFilters | `gaussianBlur`, `boxBlur`, `stackBlur`, `motionBlur`, `edgeDetect`, `customFilter` | `gaussian`, `box`, `stack`, `motion`, `edges`, `convolve` |
  | ClipRegion | `spansByY`, `fillRule`, `clipSpans`, `containsPoint`, `calculatePathBounds` | `rows`, `rule`, `clip`, `includes`, `extent` |
  | GraphicsFileSystem | `readFile`, `writeFile` | `read`, `write` |
  | Logging | `setLogger(l)`, `enableConsoleLogging()`, `ConsoleLogger(enableDebug:)` | `logger = l`, `logger = ConsoleLogger()`, `ConsoleLogger(verbose:)` |
  | SVG | `parsePaths`, `SVGPathData` | `SVGPath.parse`, `SVGPath` |

  `TextEngine.wrap` loses its `lineSpacing` argument, which had no effect since `wrap` returns the lines as strings;
  `TextEngine.paths` keeps its own.

  `getImageData(x, y, width, height)` and `putImageData(image, dx, dy, ...)` take and return an `ImageData` (`width`,
  `height`, RGBA bytes), as W3C canvas does; `getImageData()` returned the canvas's own pixel words as bytes and
  `putImageData` took a `Uint8List`.

  `TextAlign` gains `start` and `end`, as in W3C canvas, and `start` is the default alignment of `GraphicsEngine`,
  `TextEngine` and `TextRenderer` (it was `left`): the same for left-to-right text, and right-anchored for
  right-to-left text. `GraphicsEngine.direction` and `TextEngine.direction` (default `ltr`) set the paragraph
  direction; `direction` is saved with the state.

  `fill` and `clip` take the fill rule as a named argument (`fill(path, rule: FillRule.evenOdd)`), so that `fill` can
  also take `text`; W3C passes it positionally, which Dart does not allow beside a named argument.

- **New runtime dependency on `meta`** for the `@experimental` annotation.
  - Migration: none; `meta` has no dependencies of its own.

### Behaviour changes

- **Coverage and opacity:** coverage masks the composited result (`lerp(dest, composite(src * alpha, dest), coverage)`),
  so `clear` and `src` affect only the covered part of an edge pixel; `globalAlpha` scales the source instead of the
  coverage; clip coverage multiplies shape coverage, so anti-aliased clips have soft edges for fills and images, and
  images composite through a partial clip by the same rule as fills.
- **Anti-aliasing** measures the covered area of each pixel with the fill rule applied before coverage is added up.
  Each pixel row is split into bands at the edge ends inside it and, where no edges cross, each band's inside area is
  measured exactly; rows where edges cross, or with many edge ends (lines of text), are sampled at 16 sub-rows, exact
  horizontally and within 1/16 of a pixel vertically. Shapes thinner than a pixel row no longer vanish, and the fill
  rule holds inside a pixel (shapes wound in opposite directions no longer cancel, and shapes or strokes that overlap
  themselves are no longer counted twice at their edges). Rasterizing costs up to about 2x more for typical shapes and
  about 3x for shapes with very dense edges.
- **Fill rules** are computed from signed edge winding, for fills and clips; non-zero now fills nested same-direction
  contours.
- **Example scenes** in `doc/examples.md` are written for Y-up graphics space.
- **Paints and images** are sampled in graphics space (gradients and patterns are no longer mirrored vertically) and
  at pixel centres (a gradient across ten pixels is symmetric).
- **Images** paint only the pixels whose centre maps inside the source rectangle, and honour `globalAlpha`.
  Transparent image pixels are composited too, so modes such as `src`, `srcIn` and `clear` empty the destination
  under them.
- **Singular transforms** paint nothing.
- **Dashes with round caps:** overlapping caps of adjacent dashes stay filled instead of cancelling.
- **Filters:** soft-light follows the W3C compositing formula; stack blur preserves constant images; Sobel edge
  detection is independent of edge polarity.
- **Fonts:** glyph ids at or beyond the font's glyph count are treated as missing; glyph metrics come from the glyph
  header, so measuring no longer decodes outlines. Every glyph record is read within its own `loca` range and checked
  completely at load (contour end points, instructions, flags and coordinates, composite components), so a font that
  loads can draw every glyph; a malformed or truncated glyph rejects the font with `Err`.
- **Text:** `TextRenderer` wraps on any run of whitespace, like `TextEngine`; both use the same line breaker. The
  `top`, `middle`, `bottom`, `hanging` and `ideographic` baselines position text correctly in Y-up graphics space (text
  hangs below a `top` baseline); they previously applied Y-down offsets.
- **Path operations:** `union`, `intersection`, `difference`, `xor` and `offset` are marked `@experimental`, and their
  documentation now states what they compute (edge-based approximations, not true area operations).

### Added

- `GraphicsEngine.textRendering` (W3C canvas `textRendering`): unless it is `geometricPrecision`, `fillText` and
  `strokeText` map partial coverage `c` to `c^0.6`, so unhinted glyph stems that fall between pixels read less
  blurred; `fill(path, text: true)` does the same for glyph outlines from `TextRenderer` or `Font.path`. Saved with
  the state.
- `Result<T, E>` (`Ok`/`Err`), `ErrorDetails` and `ErrorKind`.
- `Limits`, accepted by `GraphicsEngine` (and applied to the fonts it loads), `TTFFont.fromBytes`,
  `TTFFont.load`, `FontFallbackChain.load`, image loading and the blur filters.
- Full PNG decoding in pure Dart: stored, fixed and dynamic Huffman compression, all five row filters, every colour type
  and bit depth (1 to 16), `tRNS` transparency and Adam7 interlacing, with CRC and Adler-32 checks.
- BMP: top-down images (negative height) and validation of headers and payload sizes. PPM: comments and any whitespace
  in headers, samples scaled by maxval, 16-bit P6.
- `TextEngine.split(text, maxWidth, width)`, the shared line breaker.
- `TTFFont.decodes`, the number of glyph outlines decoded (outlines are cached).
- `doc/rendering-model.md`.
- Exports that examples reached through `package:libgfx/src/...`: `ColorUtils` and `HSLColor`, the SVG path parser
  (`SVGPath`) and logging (`LibgfxLogger`, `ConsoleLogger`, `SilentLogger`, `logger`).
- `Color.parse`, `PathBuilder.rect`, `roundRect`, `polygon` and `star`, and the `filter` argument of `drawImage`.

### Fixed

- Malformed, truncated or hostile fonts and images return an `Err` instead of throwing `RangeError`, overflowing the
  stack or exhausting memory (decompression bombs, composite glyph cycles and fan-out, cmap format 12 groups covering
  every code point, oversized table directories).
- `Path.bounds` of an empty path no longer throws.
- `PathBuilder.arcTo` centres its arc on the bisector of the corner, as W3C canvas does, so the arc touches both
  lines (it was off the corner at every angle); with collinear points or no radius it draws a line to the corner.
- `TextRenderer.layout` aligns text by its width at the size passed to it (it used the renderer's size), and
  `wrap` and `spaced` align once (centred and right-aligned lines moved twice, and `spaced` re-aligned each
  character).
- `TextEngine.paths` and `TextRenderer.wrap` put each wrapped line below the one before (in Y-up graphics space they
  went up the page).
- `Rectangle<int>.fromCenter`, `centerX` and `centerY` no longer throw (they halve integer sizes by flooring), nor
  does `Rectangle.zero<double>()`.
- Image data round trips: `getImageData` returned a live view of the canvas in the machine's byte order (blue, green,
  red, alpha on little-endian machines), so clearing the canvas cleared the data and `putImageData`, which read red,
  green, blue, alpha, swapped red and blue. `putImageData` also read the data with the canvas width as its row length
  and wrote a dirty rectangle at (dx, dy) instead of its offset from it.
- `FontFallbackChain.find` looks up the first character of text that starts outside the Basic Multilingual Plane
  (emoji, for example); it looked up half of a surrogate pair and found no font.
- Composite glyphs apply their components' 2x2 transforms (they were skipped) and place components by matched points
  (they were drawn at the origin); a matched point number a glyph does not have is a malformed font. Offsets marked
  as scaled are transformed with the component.
- `SVGPath.parse` reads quadratic curves (`Q`, `T`) and elliptical arcs (`A`), absolute and relative, including arc
  flags written without separators; it skipped them and their coordinates.
- `SystemFontManager.load` looks for fonts through the file system it is given (it checked with `dart:io` first, so a
  custom file system never saw the paths) and loads each name once (a name found in two directories loaded twice).
- PNG decoding accepts a compressed block of literals only that declares no distance codes, as RFC 1951 allows; it
  was rejected as an incomplete Huffman code.
- Right-to-left text is drawn right to left: the shaper and `TextRenderer` order glyphs by a simplified Unicode
  bidirectional algorithm (UAX #9 without explicit embeddings, isolates or bracket pairs), so Hebrew and Arabic
  read correctly and mixed lines keep each run in its own direction, with brackets mirrored in right-to-left runs.
  It drew every character left to right in the order stored.
- Arabic letters join: each takes the isolated, final, initial or medial form its neighbours call for (marks do not
  break joining), and lam followed by alef becomes its ligature, drawn with the font's Arabic presentation forms when
  it maps them. Every letter was drawn in its isolated form.
- Characters beyond the Basic Multilingual Plane (emoji, for example) map in fonts that list a BMP-only cmap subtable
  before their full-repertoire one, as most fonts do: the first Unicode subtable was used, so they never mapped.
- Text uses the font's ligatures: the GSUB ligature lookups of the `ccmp` and `liga` features (default script and
  language), so flags and other emoji sequences draw as one glyph and Latin text takes ligatures such as `fi` and `ff`
  where the font has them. `Font.ligate` exposes them; a GSUB that is malformed or larger than the new
  `Limits.ligatures` is ignored and the font loads without ligatures.
- Path simplification no longer overflows the stack on long paths.
- Text wrapping is linear in the line length instead of quadratic.
- Loading 8000 one-byte PNG IDAT chunks is linear instead of quadratic.
- Box blur takes the same time at any radius (it grew with the radius squared); merging overlapping spans is linear
  in their number (it was quadratic); gradient colour lookup is a binary search over the stops; an opaque source
  drawn with `srcOver` is written directly, and bilinear image sampling reads pixels without bounds checks. Output
  is unchanged.
- Internal `save()`/`restore()` pairs are exception safe.
- The README and the guides in `doc/` match the API; their code blocks are compiled by the test suite.

## 2.0.1

- pub.dev formatting cleanup.

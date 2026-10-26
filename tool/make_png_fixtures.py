#!/usr/bin/env python3
"""Generates the PNG test fixtures in test/fixtures/png/.

Run from the repository root: python3 tool/make_png_fixtures.py

Every fixture is a 16x16 image whose pixel (x, y) is
    red = x * 16, green = y * 16, blue = (x * y) & 0xFF, alpha = 255 - x * 8
so the tests can compute the expected pixels instead of storing them (RGB
fixtures drop the alpha). Rows use filter type 0 (None) unless the name gives
a filter.

The colour type and bit depth fixtures (gray1.png to palette8-trns.png) use
other samples, given by samples() below, and cycle through the five filters
by row; each has a .rgba file of the expected 8-bit RGBA pixels, row by row.
The adam7-*.png fixtures are interlaced, each with a non-interlaced twin
(-flat.png) and a .rgba file for the twin.
Uses only the Python standard library.
"""

import struct
import zlib
from pathlib import Path

SIZE = 16
OUTPUT = Path('test/fixtures/png')


def pixel(x, y):
    return (x * 16, y * 16, (x * y) & 0xFF, 255 - x * 8)


def raw_rgba():
    """The unfiltered scanlines of the RGBA image."""
    return filtered(4, lambda y: 0)


def paeth(left, up, corner):
    estimate = left + up - corner
    distances = (abs(estimate - left), abs(estimate - up),
                 abs(estimate - corner))
    if distances[0] <= distances[1] and distances[0] <= distances[2]:
        return left
    return up if distances[1] <= distances[2] else corner


def filtered(channels, kind):
    """The scanlines of the image with [channels] channels, row y filtered
    with filter type kind(y)."""
    rows = [bytes(sample for x in range(SIZE)
                  for sample in pixel(x, y)[:channels]) for y in range(SIZE)]
    return filter_rows(rows, channels, kind)


def filter_rows(rows, step, kind):
    """Filters [rows] of bytes with [step] bytes per pixel, row y with
    filter type kind(y)."""
    output = bytearray()
    for y, row in enumerate(rows):
        previous = rows[y - 1] if y > 0 else bytes(len(row))
        filter = kind(y)
        output.append(filter)
        for i, value in enumerate(row):
            left = row[i - step] if i >= step else 0
            up = previous[i]
            corner = previous[i - step] if i >= step else 0
            predictor = (0, left, up, (left + up) // 2,
                         paeth(left, up, corner))[filter]
            output.append((value - predictor) & 0xFF)
    return bytes(output)


def compress(data, level, strategy=zlib.Z_DEFAULT_STRATEGY):
    compressor = zlib.compressobj(level, zlib.DEFLATED, 15, 9, strategy)
    return compressor.compress(data) + compressor.flush()


def block_type(stream):
    """BTYPE of the first deflate block, after the 2-byte zlib header."""
    return (stream[2] >> 1) & 3


def chunk(kind, data):
    body = kind + data
    return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body))


def unfiltered(data, channels, stride=None, count=SIZE):
    """Reverses filtered() and filter_rows(), to check them. [channels] is
    the number of bytes per pixel, [count] the number of rows."""
    stride = stride or SIZE * channels
    rows = []
    for y in range(count):
        filter = data[y * (stride + 1)]
        line = data[y * (stride + 1) + 1:(y + 1) * (stride + 1)]
        previous = rows[-1] if rows else bytes(stride)
        row = bytearray(stride)
        for i in range(stride):
            left = row[i - channels] if i >= channels else 0
            up = previous[i]
            corner = previous[i - channels] if i >= channels else 0
            predictor = (0, left, up, (left + up) // 2,
                         paeth(left, up, corner))[filter]
            row[i] = (line[i] + predictor) & 0xFF
        rows.append(bytes(row))
    return b''.join(rows)


def png(stream, colour=6, depth=8, chunks=(), width=SIZE, height=SIZE,
        interlace=0):
    """A PNG file of [stream], with [chunks] of (type, data) before IDAT."""
    header = struct.pack('>IIBBBBB', width, height, depth, colour, 0, 0,
                         interlace)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) +
            b''.join(chunk(kind, data) for kind, data in chunks) +
            chunk(b'IDAT', stream) + chunk(b'IEND', b''))


CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


def samples(colour, depth, x, y):
    """The samples of pixel (x, y): channel values for colour types 0, 2,
    4 and 6, or a palette index for colour type 3."""
    if colour == 3:
        return ((x + y * 16) % palette_size(depth),)
    top = 1 << depth
    if depth == 16:
        return tuple((x * 4099 + y * 257 + k * 1031) % top
                     for k in range(CHANNELS[colour]))
    return tuple((x * 7 + y * 13 + k * 29) % top
                 for k in range(CHANNELS[colour]))


def palette_size(depth):
    # Shorter than 256 at depth 8, so not every index is valid
    return 200 if depth == 8 else 1 << depth


def palette(depth):
    return [((i * 37) & 0xFF, (i * 91) & 0xFF, (i * 53) & 0xFF)
            for i in range(palette_size(depth))]


def alphas(depth):
    """tRNS alphas for the first half of the palette."""
    return [(255 - i * 7) & 0xFF for i in range(palette_size(depth) // 2)]


def pack(values, depth):
    """Packs sample [values] into bytes, most significant bits first."""
    if depth == 16:
        return b''.join(struct.pack('>H', value) for value in values)
    if depth == 8:
        return bytes(values)
    output = bytearray()
    for start in range(0, len(values), 8 // depth):
        byte = 0
        group = values[start:start + 8 // depth]
        for i, value in enumerate(group):
            byte |= value << (8 - depth * (i + 1))
        output.append(byte)
    return bytes(output)


def eight(value, depth):
    """A sample scaled to 8 bits: exactly for depths below 8, the high byte
    for depth 16."""
    if depth == 16:
        return value >> 8
    return value * 255 // ((1 << depth) - 1)


def expected(colour, depth, transparent, width=SIZE, height=SIZE):
    """The expected 8-bit RGBA pixels. [transparent] is the tRNS colour of a
    greyscale or RGB image, or True for a palette image with tRNS."""
    output = bytearray()
    for y in range(height):
        for x in range(width):
            values = samples(colour, depth, x, y)
            if colour == 3:
                index = values[0]
                red, green, blue = palette(depth)[index]
                table = alphas(depth) if transparent else []
                alpha = table[index] if index < len(table) else 255
                output.extend((red, green, blue, alpha))
                continue
            channel = [eight(value, depth) for value in values]
            alpha = 255
            if colour in (4, 6):
                alpha = channel.pop()
            elif transparent is not None and values == transparent:
                alpha = 0
            if len(channel) == 1:
                channel *= 3
            output.extend((*channel, alpha))
    return bytes(output)


def matrix():
    """Every colour type and bit depth, and tRNS for greyscale, RGB and
    palette images."""
    names = {0: 'gray', 2: 'rgb', 3: 'palette', 4: 'gray-alpha', 6: 'rgba'}
    depths = {0: [1, 2, 4, 8, 16], 2: [8, 16], 3: [1, 2, 4, 8],
              4: [8, 16], 6: [8, 16]}
    cases = [(colour, depth, False) for colour in names
             for depth in depths[colour]]
    cases += [(0, 4, True), (0, 16, True), (2, 8, True), (2, 16, True),
              (3, 2, True), (3, 8, True)]
    for colour, depth, trns in cases:
        name = f'{names[colour]}{depth}' + ('-trns' if trns else '')
        image, pixels = encode(colour, depth, trns)
        (OUTPUT / f'{name}.png').write_bytes(image)
        (OUTPUT / f'{name}.rgba').write_bytes(pixels)
        print(f'{name}.png')


# Adam7 passes: first column and row, then column and row spacing
PASSES = [(0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4),
          (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2)]


def encode(colour, depth, trns, width=SIZE, height=SIZE, interlace=0,
           first=0):
    """A PNG of the samples() image and its expected RGBA pixels. Rows cycle
    through the five filters starting with filter type [first], restarting
    with each Adam7 pass."""
    step = max(1, CHANNELS[colour] * depth // 8)
    passes = PASSES if interlace else [(0, 0, 1, 1)]
    data = b''
    for left, top, across, down in passes:
        columns = range(left, width, across)
        lines = range(top, height, down)
        if not columns or not lines:
            continue  # empty passes have no rows at all
        rows = [pack([value for x in columns
                      for value in samples(colour, depth, x, y)], depth)
                for y in lines]
        filtered = filter_rows(rows, step, lambda y: (y + first) % 5)
        assert (unfiltered(filtered, step, len(rows[0]), len(rows)) ==
                b''.join(rows))
        data += filtered

    chunks = []
    transparent = None
    if colour == 3:
        chunks.append((b'PLTE', bytes(v for entry in palette(depth)
                                      for v in entry)))
        if trns:
            chunks.append((b'tRNS', bytes(alphas(depth))))
            transparent = True
    elif trns:
        # The colour of one pixel, so some pixels match it
        transparent = samples(colour, depth, min(3, width - 1),
                              min(5, height - 1))
        chunks.append((b'tRNS', b''.join(struct.pack('>H', value)
                                         for value in transparent)))
    image = png(compress(data, 9), colour, depth, chunks, width, height,
                interlace)
    return image, expected(colour, depth, transparent, width, height)


def adam7():
    """Interlaced images and their non-interlaced twins, including sizes
    where packed rows end mid-byte and where some passes are empty."""
    cases = {
        'rgba8-16x16': (6, 8, False, 16, 16),
        'gray1-13x11': (0, 1, False, 13, 11),
        'palette4-13x11': (3, 4, False, 13, 11),
        'rgb16-trns-9x7': (2, 16, True, 9, 7),
        'gray-alpha8-3x2': (4, 8, False, 3, 2),
        'rgb8-1x1': (2, 8, False, 1, 1),
    }
    for name, (colour, depth, trns, width, height) in cases.items():
        # Each pass starts with Up, which needs a zero row above it
        interlaced, pixels = encode(colour, depth, trns, width, height, 1, 2)
        flat, same = encode(colour, depth, trns, width, height, 0, 2)
        assert pixels == same
        (OUTPUT / f'adam7-{name}.png').write_bytes(interlaced)
        (OUTPUT / f'adam7-{name}-flat.png').write_bytes(flat)
        (OUTPUT / f'adam7-{name}-flat.rgba').write_bytes(pixels)
        print(f'adam7-{name}.png')


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    fixtures = {
        # Stored blocks (BTYPE 0)
        'rgba8-stored.png': (compress(raw_rgba(), 0), 0),
        # Fixed Huffman codes (BTYPE 1), forced with Z_FIXED
        'rgba8-fixed.png': (compress(raw_rgba(), 1, zlib.Z_FIXED), 1),
        # Dynamic Huffman codes (BTYPE 2), as zlib level 9 chooses here
        'rgba8-dynamic.png': (compress(raw_rgba(), 9), 2),
    }
    for name, (stream, kind) in fixtures.items():
        assert block_type(stream) == kind, (name, block_type(stream))
        assert zlib.decompress(stream) == raw_rgba(), name
        (OUTPUT / name).write_bytes(png(stream))
        print(f'{name}: {len(stream)} byte stream, BTYPE {kind}')

    # One fixture per filter type, and RGB with the filter cycling by row
    filters = ['none', 'sub', 'up', 'average', 'paeth']
    images = {f'rgba8-{name}.png': (4, lambda y, f=f: f)
              for f, name in enumerate(filters)}
    images['rgb8-mixed.png'] = (3, lambda y: y % 5)
    for name, (channels, kind) in images.items():
        data = filtered(channels, kind)
        expected = b''.join(bytes(sample for x in range(SIZE)
                                  for sample in pixel(x, y)[:channels])
                            for y in range(SIZE))
        assert unfiltered(data, channels) == expected, name
        colour = 6 if channels == 4 else 2
        (OUTPUT / name).write_bytes(png(compress(data, 9), colour))
        print(f'{name}: filters {sorted({kind(y) for y in range(SIZE)})}')

    matrix()
    adam7()


if __name__ == '__main__':
    main()

import 'package:libgfx/libgfx.dart';

/// Sum of the alpha channel over every pixel of [bitmap].
int coverage(final Bitmap bitmap) =>
    bitmap.pixels.fold(0, (sum, pixel) => sum + (pixel >> 24 & 0xFF));

/// Number of pixels in [bitmap] with non-zero alpha.
int painted(final Bitmap bitmap) =>
    bitmap.pixels.where((pixel) => pixel >> 24 & 0xFF != 0).length;

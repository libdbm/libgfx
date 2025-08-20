# Font Files

This directory should contain TrueType font files (.ttf) for text rendering in libgfx.

## Downloading Fonts

The font files are not included in the package to reduce size. You can download them using:

```bash
# From the project root directory
./scripts/download_fonts.sh
```

### Manual Download

Download the following fonts and place them in this directory:

#### Essential Fonts
- **NotoSans-Regular.ttf** - Basic Latin text
- **NotoSansMono-Regular.ttf** - Monospace text
- **NotoSerif-Regular.ttf** - Serif text
- **DejaVuSans.ttf** - Common open-source font

#### International Support (Optional)
- **NotoSansArabic-Regular.ttf** - Arabic script
- **NotoSansBengali-Regular.ttf** - Bengali script
- **NotoSansDevanagari-Regular.ttf** - Devanagari script
- **NotoSansHebrew-Regular.ttf** - Hebrew script
- **NotoSansTamil-Regular.ttf** - Tamil script
- **NotoSansThai-Regular.ttf** - Thai script

#### CJK Support (Optional, Large Files)
- **NotoSansJP-Regular.ttf** - Japanese (~5MB)
- **NotoSansKR-Regular.ttf** - Korean (~6MB)
- **NotoSansSC-Regular.ttf** - Simplified Chinese (~10MB)
- **NotoSansTC-Regular.ttf** - Traditional Chinese (~6MB)

#### Emoji Support (Optional)
- **NotoEmoji-Regular.ttf** - Black & white emoji
- **NotoColorEmoji-Regular.ttf** - Color emoji (~23MB)

## Font Sources

All Noto fonts are available from:
- https://github.com/notofonts/noto-fonts
- https://github.com/googlefonts/noto-cjk
- https://github.com/googlefonts/noto-emoji

DejaVu fonts are available from:
- https://github.com/dejavu-fonts/dejavu-fonts

## License

The Noto fonts are licensed under the SIL Open Font License 1.1.
DejaVu fonts are also licensed under a permissive open-source license.

## Testing Without Fonts

The library includes fallback rendering for when fonts are not available. Text rendering features will be limited but the library will still function.
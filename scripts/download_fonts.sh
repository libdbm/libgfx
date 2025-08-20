#!/bin/bash

set -e

# Check for curl or wget
if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    echo "Error: Neither curl nor wget is installed."
    echo "Please install one of them to download fonts."
    exit 1
fi

FONTS_DIR="data/fonts"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Create fonts directory if it doesn't exist
mkdir -p "$FONTS_DIR"

echo "Downloading fonts for libgfx..."
echo "This may take a few minutes as some font files are large."
echo ""

# Function to download a font
download_font() {
    local url=$1
    local filename=$2
    local filepath="$FONTS_DIR/$filename"
    
    if [ -f "$filepath" ]; then
        echo "✓ $filename already exists, skipping..."
    else
        echo "Downloading $filename..."
        if command -v curl &> /dev/null; then
            curl -L -o "$filepath" "$url"
        else
            wget -O "$filepath" "$url"
        fi
        echo "✓ Downloaded $filename"
    fi
}

# Google Fonts - Noto Sans family
# Using Google Fonts API v2 URLs
download_font "https://github.com/notofonts/noto-fonts/raw/main/hinted/ttf/NotoSans/NotoSans-Regular.ttf" "NotoSans-Regular.ttf"
download_font "https://github.com/notofonts/noto-fonts/raw/main/hinted/ttf/NotoSansMono/NotoSansMono-Regular.ttf" "NotoSansMono-Regular.ttf"
download_font "https://github.com/notofonts/noto-fonts/raw/main/hinted/ttf/NotoSerif/NotoSerif-Regular.ttf" "NotoSerif-Regular.ttf"

# Noto Sans for various scripts
download_font "https://github.com/notofonts/noto-fonts/raw/main/hinted/ttf/NotoSansArabic/NotoSansArabic-Regular.ttf" "NotoSansArabic-Regular.ttf"
download_font "https://github.com/notofonts/noto-fonts/raw/main/hinted/ttf/NotoSansBengali/NotoSansBengali-Regular.ttf" "NotoSansBengali-Regular.ttf"
download_font "https://github.com/notofonts/noto-fonts/raw/main/hinted/ttf/NotoSansDevanagari/NotoSansDevanagari-Regular.ttf" "NotoSansDevanagari-Regular.ttf"
download_font "https://github.com/notofonts/noto-fonts/raw/main/hinted/ttf/NotoSansHebrew/NotoSansHebrew-Regular.ttf" "NotoSansHebrew-Regular.ttf"
download_font "https://github.com/notofonts/noto-fonts/raw/main/hinted/ttf/NotoSansTamil/NotoSansTamil-Regular.ttf" "NotoSansTamil-Regular.ttf"
download_font "https://github.com/notofonts/noto-fonts/raw/main/hinted/ttf/NotoSansThai/NotoSansThai-Regular.ttf" "NotoSansThai-Regular.ttf"

# CJK fonts (these are large)
echo ""
echo "Downloading CJK fonts (these are large files)..."
download_font "https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/Japanese/NotoSansCJKjp-Regular.otf" "NotoSansJP-Regular.ttf"
download_font "https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/Korean/NotoSansCJKkr-Regular.otf" "NotoSansKR-Regular.ttf"
download_font "https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf" "NotoSansSC-Regular.ttf"
download_font "https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/TraditionalChinese/NotoSansCJKtc-Regular.otf" "NotoSansTC-Regular.ttf"

# Emoji fonts
echo ""
echo "Downloading emoji fonts..."
download_font "https://github.com/googlefonts/noto-emoji/raw/main/fonts/NotoEmoji-Regular.ttf" "NotoEmoji-Regular.ttf"
download_font "https://github.com/googlefonts/noto-emoji/raw/main/fonts/NotoColorEmoji.ttf" "NotoColorEmoji-Regular.ttf"

# DejaVu Sans (common open source font)
download_font "https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/dejavu-fonts-ttf-2.37.tar.bz2" "dejavu-temp.tar.bz2"
if [ -f "$FONTS_DIR/dejavu-temp.tar.bz2" ]; then
    echo "Extracting DejaVu fonts..."
    cd "$FONTS_DIR"
    tar -xjf dejavu-temp.tar.bz2 dejavu-fonts-ttf-2.37/ttf/DejaVuSans.ttf
    mv dejavu-fonts-ttf-2.37/ttf/DejaVuSans.ttf .
    rm -rf dejavu-fonts-ttf-2.37 dejavu-temp.tar.bz2
    cd "$PROJECT_ROOT"
    echo "✓ Extracted DejaVuSans.ttf"
fi

# Google Sans Code fonts (if available from public sources)
# Note: These might not be publicly available, so we'll check for alternatives
echo ""
echo "Note: GoogleSansCode fonts are proprietary and not included in this script."
echo "You may need to obtain them separately if required."

# Radley fonts from Google Fonts
download_font "https://github.com/google/fonts/raw/main/ofl/radley/Radley-Regular.ttf" "Radley-Regular.ttf"
download_font "https://github.com/google/fonts/raw/main/ofl/radley/Radley-Italic.ttf" "Radley-Italic.ttf"

echo ""
echo "Font download complete!"
echo ""
echo "Fonts installed in: $FONTS_DIR"
echo ""
echo "Note: Some fonts (GoogleSansCode) are proprietary and not included."
echo "The library will work with the downloaded open-source alternatives."
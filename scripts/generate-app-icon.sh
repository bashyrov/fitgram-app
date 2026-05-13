#!/usr/bin/env bash
# Generates the full AppIcon.appiconset PNG bundle from icon-source.svg
# using rsvg-convert (most consistent SVG renderer on macOS — Mojave+
# bundles it via Homebrew librsvg).
#
# Install once:    brew install librsvg
# Run:             ./scripts/generate-app-icon.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE="$ROOT/docs/app-store/icon-source.svg"
DEST="$ROOT/Mealgram/Resources/Assets.xcassets/AppIcon.appiconset"

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "✗ rsvg-convert not found. Install with: brew install librsvg" >&2
  exit 1
fi

if [[ ! -f "$SOURCE" ]]; then
  echo "✗ Source SVG missing at $SOURCE" >&2
  exit 1
fi

mkdir -p "$DEST"

# Standard iOS / iPad / App Store sizes. Format: <output_filename>:<pixel_size>
SIZES=(
  "icon-20@2x.png:40"
  "icon-20@3x.png:60"
  "icon-29@2x.png:58"
  "icon-29@3x.png:87"
  "icon-40@2x.png:80"
  "icon-40@3x.png:120"
  "icon-60@2x.png:120"
  "icon-60@3x.png:180"
  "icon-20.png:20"
  "icon-29.png:29"
  "icon-40.png:40"
  "icon-76.png:76"
  "icon-76@2x.png:152"
  "icon-83.5@2x.png:167"
  "icon-1024.png:1024"
)

for entry in "${SIZES[@]}"; do
  name="${entry%%:*}"
  size="${entry##*:}"
  echo "→ ${name} (${size}×${size})"
  rsvg-convert -w "$size" -h "$size" "$SOURCE" > "$DEST/$name"
done

# Write the Contents.json that maps PNGs into Xcode asset slots.
cat > "$DEST/Contents.json" <<'EOF'
{
  "images" : [
    { "size" : "20x20", "idiom" : "iphone", "filename" : "icon-20@2x.png", "scale" : "2x" },
    { "size" : "20x20", "idiom" : "iphone", "filename" : "icon-20@3x.png", "scale" : "3x" },
    { "size" : "29x29", "idiom" : "iphone", "filename" : "icon-29@2x.png", "scale" : "2x" },
    { "size" : "29x29", "idiom" : "iphone", "filename" : "icon-29@3x.png", "scale" : "3x" },
    { "size" : "40x40", "idiom" : "iphone", "filename" : "icon-40@2x.png", "scale" : "2x" },
    { "size" : "40x40", "idiom" : "iphone", "filename" : "icon-40@3x.png", "scale" : "3x" },
    { "size" : "60x60", "idiom" : "iphone", "filename" : "icon-60@2x.png", "scale" : "2x" },
    { "size" : "60x60", "idiom" : "iphone", "filename" : "icon-60@3x.png", "scale" : "3x" },
    { "size" : "20x20", "idiom" : "ipad", "filename" : "icon-20.png", "scale" : "1x" },
    { "size" : "20x20", "idiom" : "ipad", "filename" : "icon-20@2x.png", "scale" : "2x" },
    { "size" : "29x29", "idiom" : "ipad", "filename" : "icon-29.png", "scale" : "1x" },
    { "size" : "29x29", "idiom" : "ipad", "filename" : "icon-29@2x.png", "scale" : "2x" },
    { "size" : "40x40", "idiom" : "ipad", "filename" : "icon-40.png", "scale" : "1x" },
    { "size" : "40x40", "idiom" : "ipad", "filename" : "icon-40@2x.png", "scale" : "2x" },
    { "size" : "76x76", "idiom" : "ipad", "filename" : "icon-76.png", "scale" : "1x" },
    { "size" : "76x76", "idiom" : "ipad", "filename" : "icon-76@2x.png", "scale" : "2x" },
    { "size" : "83.5x83.5", "idiom" : "ipad", "filename" : "icon-83.5@2x.png", "scale" : "2x" },
    { "size" : "1024x1024", "idiom" : "ios-marketing", "filename" : "icon-1024.png", "scale" : "1x" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "✓ AppIcon.appiconset populated. Run 'make generate && make build' next."

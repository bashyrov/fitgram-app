#!/usr/bin/env bash
# Renders launch-logo-source.svg into the three Xcode-asset scales.
# Install once: brew install librsvg

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE="$ROOT/docs/app-store/launch-logo-source.svg"
DEST="$ROOT/Mealgram/Resources/Assets.xcassets/LaunchLogo.imageset"

command -v rsvg-convert >/dev/null 2>&1 || {
  echo "✗ rsvg-convert not found. Install with: brew install librsvg" >&2
  exit 1
}

mkdir -p "$DEST"

# Render at 1x = 200pt; @2x and @3x scale accordingly.
rsvg-convert -w 200 -h 200 "$SOURCE" > "$DEST/launch-logo.png"
rsvg-convert -w 400 -h 400 "$SOURCE" > "$DEST/launch-logo@2x.png"
rsvg-convert -w 600 -h 600 "$SOURCE" > "$DEST/launch-logo@3x.png"

echo "✓ LaunchLogo.imageset populated."

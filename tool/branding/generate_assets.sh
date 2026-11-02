#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BRANDING_DIR="$ROOT_DIR/tool/branding"
TMP_CACHE_DIR="${TMPDIR:-/tmp}/wrait-fontconfig-cache"

mkdir -p "$TMP_CACHE_DIR"
export XDG_CACHE_HOME="$TMP_CACHE_DIR"

if ! command -v magick >/dev/null 2>&1; then
  echo "magick is required to generate branding assets." >&2
  exit 1
fi

render_square() {
  local source="$1"
  local size="$2"
  local output="$3"
  local background="${4:-none}"

  mkdir -p "$(dirname "$output")"
  magick -background "$background" "$source" -resize "${size}x${size}" -strip "$output"
  assert_png "$output" "$size" "$size"
}

render_launch() {
  local scale="$1"
  local output="$2"
  local size=$((720 * scale))

  mkdir -p "$(dirname "$output")"
  magick -background none "$BRANDING_DIR/launch_mark.svg" -resize "${size}x${size}" -strip "$output"
  assert_png "$output" "$size" "$size"
}

assert_png() {
  local output="$1"
  local expected_width="$2"
  local expected_height="$3"
  local format
  local width
  local height

  if [[ ! -f "$output" ]]; then
    echo "Missing generated asset: $output" >&2
    exit 1
  fi

  read -r format width height <<<"$(magick identify -format '%m %w %h' "$output")"

  if [[ "$format" != "PNG" ]]; then
    echo "Generated asset is not a PNG: $output ($format)" >&2
    exit 1
  fi

  if [[ "$width" != "$expected_width" || "$height" != "$expected_height" ]]; then
    echo "Generated asset has unexpected dimensions: $output (${width}x${height}, expected ${expected_width}x${expected_height})" >&2
    exit 1
  fi
}

render_square "$BRANDING_DIR/app_icon_release.svg" 20 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_release.svg" 40 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_release.svg" 60 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_release.svg" 29 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_release.svg" 58 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_release.svg" 87 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_release.svg" 40 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_release.svg" 80 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_release.svg" 120 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_release.svg" 120 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_release.svg" 180 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_release.svg" 76 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_release.svg" 152 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_release.svg" 167 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_release.svg" 1024 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" "#1A1917"

render_square "$BRANDING_DIR/app_icon_debug.svg" 20 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-20x20@1x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_debug.svg" 40 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-20x20@2x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_debug.svg" 60 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-20x20@3x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_debug.svg" 29 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-29x29@1x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_debug.svg" 58 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-29x29@2x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_debug.svg" 87 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-29x29@3x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_debug.svg" 40 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-40x40@1x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_debug.svg" 80 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-40x40@2x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_debug.svg" 120 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-40x40@3x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_debug.svg" 120 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-60x60@2x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_debug.svg" 180 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-60x60@3x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_debug.svg" 76 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-76x76@1x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_debug.svg" 152 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-76x76@2x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_debug.svg" 167 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-83.5x83.5@2x.png" "#1A1917"
render_square "$BRANDING_DIR/app_icon_debug.svg" 1024 "$ROOT_DIR/ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-1024x1024@1x.png" "#1A1917"

render_launch 1 "$ROOT_DIR/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png"
render_launch 2 "$ROOT_DIR/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png"
render_launch 3 "$ROOT_DIR/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png"

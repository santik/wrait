#!/usr/bin/env bash
#
# Generates every Wrait launcher-icon asset (feature 056) from a single
# fills-only vector definition. Run from the repository root:
#
#   tool/generate_app_icons.sh
#
# Requires ImageMagick (`magick`). IMPORTANT: the mark is defined entirely with
# FILLS — the bubble is a filled ring (even-odd), the bars are filled pills, and
# the tail is a filled path. No strokes are used anywhere, because ImageMagick's
# internal MSVG rasterizer silently drops stroked elements. The same path data
# feeds both the rasterized PNGs and the Android VectorDrawables, so vector and
# raster are guaranteed identical.
#
# The mark: a rounded-square voice-note bubble with a bottom-left tail holding
# seven vertical bars whose heights trace a "w" (voice waveform + brand letter).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/specs/056-app-icon-redesign/assets"
ANDROID_MAIN="$ROOT/android/app/src/main/res"
ANDROID_DEBUG="$ROOT/android/app/src/debug/res"
ANDROID_PROFILE="$ROOT/android/app/src/profile/res"
IOS_SET="$ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
IOS_DEBUG_SET="$ROOT/ios/Runner/Assets.xcassets/AppIconDebug.appiconset"
IOS_LAUNCH_SET="$ROOT/ios/Runner/Assets.xcassets/LaunchImage.imageset"

mkdir -p "$ASSETS"

# --- single source of truth: all geometry on the 108 adaptive grid, fills only.
# Bubble outline as a filled ring (outer rounded rect + inner rounded rect, even-odd).
RING="M38,34 H70 A9,9 0 0 1 79,43 V59 A9,9 0 0 1 70,68 H38 A9,9 0 0 1 29,59 V43 A9,9 0 0 1 38,34 Z M38,38 H70 A5,5 0 0 1 75,43 V59 A5,5 0 0 1 70,64 H38 A5,5 0 0 1 33,59 V43 A5,5 0 0 1 38,38 Z"
# Seven vertical pills (filled), heights tracing a "w".
BARS="M34.5,43.5 A1.5,1.5 0 0 1 37.5,43.5 L37.5,58.5 A1.5,1.5 0 0 1 34.5,58.5 Z M40.5,46.5 A1.5,1.5 0 0 1 43.5,46.5 L43.5,55.5 A1.5,1.5 0 0 1 40.5,55.5 Z M46.5,49 A1.5,1.5 0 0 1 49.5,49 L49.5,53 A1.5,1.5 0 0 1 46.5,53 Z M52.5,45.5 A1.5,1.5 0 0 1 55.5,45.5 L55.5,56.5 A1.5,1.5 0 0 1 52.5,56.5 Z M58.5,49 A1.5,1.5 0 0 1 61.5,49 L61.5,53 A1.5,1.5 0 0 1 58.5,53 Z M64.5,46.5 A1.5,1.5 0 0 1 67.5,46.5 L67.5,55.5 A1.5,1.5 0 0 1 64.5,55.5 Z M70.5,43.5 A1.5,1.5 0 0 1 73.5,43.5 L73.5,58.5 A1.5,1.5 0 0 1 70.5,58.5 Z"
# Speech-bubble tail (filled).
TAIL="M40,68 Q34,80 32,80 Q40,76 48,68 Z"

# emit_svg <outfile> <bg-color-or-none> <fg-color>
# Full-bleed raster source: the viewBox crops to the mark (centered on 54,57)
# so the mark fills ~85% of the frame with a small margin — right for iOS,
# legacy mipmaps and the Play Store icon. The Android adaptive VectorDrawable
# keeps the full 108 grid (safe-zone padding) instead.
emit_svg() {
  local out="$1" bg="$2" fg="$3" bgrect=""
  if [ "$bg" != "none" ]; then
    bgrect="<rect x=\"25\" y=\"28\" width=\"58\" height=\"58\" fill=\"$bg\"/>"
  fi
  cat > "$out" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="108" height="108" viewBox="25 28 58 58">
  $bgrect
  <path fill="$fg" d="$TAIL"/>
  <path fill="$fg" fill-rule="evenodd" d="$RING"/>
  <path fill="$fg" d="$BARS"/>
</svg>
SVG
}

# emit_splash <outfile> <fg-color>: the mark alone (transparent), with margin,
# for the iOS launch screen logo (centered on the dark storyboard background).
emit_splash() {
  local out="$1" fg="$2"
  cat > "$out" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="108" height="108" viewBox="15 18 78 78">
  <path fill="$fg" d="$TAIL"/>
  <path fill="$fg" fill-rule="evenodd" d="$RING"/>
  <path fill="$fg" d="$BARS"/>
</svg>
SVG
}

# emit_vd_foreground <outfile> <fg-color> ; emit_vd_background <outfile> <bg-color>
emit_vd_foreground() {
  local out="$1" fg="$2"
  cat > "$out" <<VD
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="$fg"
        android:pathData="$TAIL" />
    <path
        android:fillColor="$fg"
        android:fillType="evenOdd"
        android:pathData="$RING" />
    <path
        android:fillColor="$fg"
        android:pathData="$BARS" />
</vector>
VD
}
emit_vd_background() {
  local out="$1" bg="$2"
  cat > "$out" <<VD
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="$bg"
        android:pathData="M0,0h108v108h-108z" />
</vector>
VD
}

# rasterize <svg> <size> <outpng> [flatten]
# -density rasterizes the VECTOR at ~4x the target size (crisp), then -resize
# downsamples for anti-aliasing. (Rendering at the SVG's 108px intrinsic size and
# upscaling blurs the result — density is what makes it sharp.)
rasterize() {
  local svg="$1" size="$2" out="$3" flatten="${4:-}"
  local dens=$(( size * 4 * 96 / 108 ))
  if [ "$flatten" = "flatten" ]; then
    magick -density "$dens" -background white "$svg" -resize "${size}x${size}" \
      -background white -alpha remove -alpha off "$out"
  else
    magick -density "$dens" -background none "$svg" -resize "${size}x${size}" "$out"
  fi
}

echo "==> master SVGs"
emit_svg "$ASSETS/icon-light.svg"      "#F0EDE8" "#2C2B27"
emit_svg "$ASSETS/icon-dark.svg"       "#1A1917" "#FAF9F7"
emit_svg "$ASSETS/icon-debug.svg"      "#C62828" "#FFFFFF"
emit_svg "$ASSETS/icon-monochrome.svg" "none"    "#FFFFFF"
emit_svg "$ASSETS/icon-tinted.svg"     "#000000" "#FFFFFF"

echo "==> Android adaptive VectorDrawables (release / debug / profile)"
emit_vd_background "$ANDROID_MAIN/drawable/ic_launcher_background.xml"    "#F0EDE8"
emit_vd_foreground "$ANDROID_MAIN/drawable/ic_launcher_foreground.xml"    "#2C2B27"
emit_vd_background "$ANDROID_DEBUG/drawable/ic_launcher_background.xml"   "#C62828"
emit_vd_foreground "$ANDROID_DEBUG/drawable/ic_launcher_foreground.xml"   "#FFFFFF"
emit_vd_background "$ANDROID_PROFILE/drawable/ic_launcher_background.xml" "#C62828"
emit_vd_foreground "$ANDROID_PROFILE/drawable/ic_launcher_foreground.xml" "#FFFFFF"

densities=(mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192)
gen_android_mipmaps() {
  local resdir="$1" svg="$2"
  for d in "${densities[@]}"; do
    local name="${d%%:*}" px="${d##*:}"
    mkdir -p "$resdir/mipmap-$name"
    rasterize "$svg" "$px" "$resdir/mipmap-$name/ic_launcher.png"
  done
}

echo "==> Android legacy mipmaps (release / debug / profile)"
gen_android_mipmaps "$ANDROID_MAIN"    "$ASSETS/icon-light.svg"
gen_android_mipmaps "$ANDROID_DEBUG"   "$ASSETS/icon-debug.svg"
gen_android_mipmaps "$ANDROID_PROFILE" "$ASSETS/icon-debug.svg"

echo "==> iOS 1024 appearance variants (flattened, no alpha)"
mkdir -p "$IOS_SET" "$IOS_DEBUG_SET"
rasterize "$ASSETS/icon-light.svg"  1024 "$IOS_SET/Icon-App-1024-light.png"        flatten
rasterize "$ASSETS/icon-dark.svg"   1024 "$IOS_SET/Icon-App-1024-dark.png"         flatten
rasterize "$ASSETS/icon-tinted.svg" 1024 "$IOS_SET/Icon-App-1024-tinted.png"       flatten
rasterize "$ASSETS/icon-debug.svg"  1024 "$IOS_DEBUG_SET/Icon-App-1024-debug.png"  flatten

echo "==> Play Store 512"
rasterize "$ASSETS/icon-light.svg" 512 "$ASSETS/play-store-512.png" flatten

echo "==> iOS launch-screen logo (cream mark, transparent, on #1A1917 storyboard bg)"
emit_splash "$ASSETS/splash-mark.svg" "#FAF9F7"
rasterize "$ASSETS/splash-mark.svg" 720  "$IOS_LAUNCH_SET/LaunchImage.png"
rasterize "$ASSETS/splash-mark.svg" 1440 "$IOS_LAUNCH_SET/LaunchImage@2x.png"
rasterize "$ASSETS/splash-mark.svg" 2160 "$IOS_LAUNCH_SET/LaunchImage@3x.png"

echo "==> done"

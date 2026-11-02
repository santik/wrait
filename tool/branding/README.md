# Wrait Branding Assets

This directory contains the checked-in sources and generation script for the
platform branding assets used by US-038.

Branding constants:

- release icon circle/button color: `#E8E4DD`
- release wordmark color: `#1A1917`
- debug icon circle color: `#C62828`
- debug wordmark color: `#FFFFFF`
- launch background color: `#1A1917`

Inputs:

- `app_icon_release.svg`: release app icon source
- `app_icon_debug.svg`: debug/profile app icon source
- `launch_mark.svg`: launch-screen mark source

Android launcher icons are not generated from this script anymore. They are
hand-authored adaptive-icon resources under:

- `android/app/src/main/res/mipmap-anydpi/`
- `android/app/src/main/res/drawable/`
- `android/app/src/debug/res/drawable/`
- `android/app/src/profile/res/drawable/`

Generated outputs:

- iOS release app icons under
  `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- iOS debug/profile app icons under
  `ios/Runner/Assets.xcassets/AppIconDebug.appiconset/`
- iOS launch images under
  `ios/Runner/Assets.xcassets/LaunchImage.imageset/`

Run:

```sh
tool/branding/generate_assets.sh
```

Notes:

- Android launcher icons use adaptive-icon XML resources that render only a
  solid background plus the `wrait` wordmark, matching
  `android/app/src/main/res`.
- iOS app icon outputs are rendered onto the dark background color above so
  the generated icon catalog remains fully opaque.
- The generator overwrites the tracked iOS PNG outputs and validates that each
  result is a PNG with the expected dimensions.

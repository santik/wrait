#!/usr/bin/env bash
set -euo pipefail

# Windsurf may inject a Java runtime path that no longer exists.
unset VSCODE_JAVA_EXEC || true

# Prefer Android Studio's bundled JDK for consistent Android builds.
if [[ -z "${JAVA_HOME:-}" ]]; then
  if [[ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  elif command -v /usr/libexec/java_home >/dev/null 2>&1; then
    export JAVA_HOME="$(/usr/libexec/java_home -v 21 2>/dev/null || /usr/libexec/java_home 2>/dev/null || true)"
  fi
fi

if [[ -n "${JAVA_HOME:-}" ]]; then
  export PATH="$JAVA_HOME/bin:$PATH"
fi

# Ensure no stale daemon pinned to an invalid JDK is reused.
./gradlew --stop >/dev/null 2>&1 || true

#./gradlew --no-daemon testDebugUnitTest assembleRelease
./gradlew --no-daemon testDebugUnitTest connectedDebugAndroidTest assembleRelease

# Remove the debug APK (com.wrait.app.debug) installed by connectedDebugAndroidTest.
# The release app (com.wrait.app) is a separate package and is never touched.
adb -s 4A181FDJH0030G uninstall com.wrait.app.debug 2>/dev/null || true

adb -s 4A181FDJH0030G install /Users/alexander/AndroidStudioProjects/wrait/app/build/outputs/apk/release/app-release.apk

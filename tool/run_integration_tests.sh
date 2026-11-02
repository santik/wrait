#!/usr/bin/env bash
# Run Flutter integration tests on simulators/emulators without hanging on the
# native microphone permission dialog.
#
# Why this exists
# ---------------
# The first time a recording flow runs, the app calls
# `Permission.microphone.request()` (permission_handler). On a fresh
# simulator/emulator that pops a native OS permission dialog, and the Flutter
# integration-test harness cannot tap it, so the whole run hangs.
#
# `MicrophonePermissionService.requestMicrophoneAccess()` short-circuits and
# never shows the dialog when the status is already `granted`. So the fix is to
# grant microphone access to the test app so the dialog never appears:
#   * Android — `adb shell pm grant <pkg> RECORD_AUDIO`. `flutter test`
#            reinstalls the app and its `.test` package before each file, which
#            resets the grant, so a background watchdog keeps re-granting while
#            the suite runs (app-safe: `pm grant` does not restart the app).
#   * iOS  — `xcrun simctl privacy <udid> grant microphone <bundle-id>` once, up
#            front, as defense. It is NOT re-granted on a loop: `simctl privacy`
#            terminates the target app to apply, so re-granting mid-run kills the
#            app under test. Because that one grant does not reliably survive the
#            per-file reinstalls either, the iOS tests that exercise the real
#            recording path inject an always-granted microphone permission
#            service (integration_test/support/microphone_test_overrides.dart)
#            instead of depending on the native grant at all.
# As a backstop, a stall guard kills the run if output goes silent (see
# run_flutter_with_stall_guard), so a stuck dialog can never hang for hours.
#
# Usage
# -----
#   tool/run_integration_tests.sh [device-id ...] [-- <test target / flutter test args>]
#
# With no device ids, every booted iOS simulator and running Android emulator
# that `flutter devices` reports is used. Anything after `--` replaces the test
# target (default: the whole `integration_test` directory); when you pass flags
# only, include the target yourself. Examples:
#   tool/run_integration_tests.sh
#   tool/run_integration_tests.sh emulator-5554
#   tool/run_integration_tests.sh 0140EF83-... -- integration_test/tags_flow_test.dart
#   tool/run_integration_tests.sh -- integration_test --reporter=expanded

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Debug build ids used by `flutter test` (see android/app/build.gradle.kts and
# ios/Runner.xcodeproj). The `.test`/RunnerTests entries are the instrumentation
# hosts flutter installs alongside the app.
ANDROID_PACKAGES=("com.wrait.flutter.dev" "com.wrait.flutter.dev.test")
IOS_BUNDLE_IDS=("com.wrait.app" "com.wrait.app.RunnerTests")
ANDROID_WATCHDOG_INTERVAL_SECONDS="0.5"
ANDROID_WATCHDOG_MAX_SECONDS="${WRAIT_ANDROID_WATCHDOG_MAX_SECONDS:-1800}"
# If `flutter test` produces no output for this long, treat the run as wedged
# (almost always a native dialog the harness can't dismiss) and kill it, instead
# of letting it hang indefinitely.
STALL_TIMEOUT_SECONDS="${WRAIT_INTEGRATION_TEST_STALL_SECONDS:-300}"

warn() { printf 'warning: %s\n' "$*" >&2; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

# Prints the flutter targetPlatform for a device id, or nothing if unknown.
device_platform() {
  local device_id="$1"
  flutter devices --machine 2>/dev/null | python3 -c "
import json, sys
wanted = sys.argv[1]
for device in json.load(sys.stdin):
    if device.get('id') == wanted:
        print(device.get('targetPlatform', ''))
        break
" "$device_id"
}

# Prints every mobile simulator/emulator id, one per line.
discover_mobile_devices() {
  flutter devices --machine 2>/dev/null | python3 -c "
import json, sys
for device in json.load(sys.stdin):
    platform = device.get('targetPlatform', '')
    if platform.startswith('android') or platform == 'ios':
        if device.get('emulator'):
            print(device['id'])
"
}

grant_ios_microphone() {
  local udid="$1"
  local bundle_id
  for bundle_id in "${IOS_BUNDLE_IDS[@]}"; do
    if xcrun simctl privacy "$udid" grant microphone "$bundle_id" >/dev/null 2>&1; then
      printf 'Granted microphone to %s on iOS simulator %s.\n' "$bundle_id" "$udid"
    else
      warn "could not grant microphone to $bundle_id on $udid (grant it manually if the dialog appears)"
    fi
  done
}

grant_android_microphone_once() {
  local serial="$1"
  local package
  for package in "${ANDROID_PACKAGES[@]}"; do
    adb -s "$serial" shell pm path "$package" >/dev/null 2>&1 || continue
    adb -s "$serial" shell pm grant "$package" android.permission.RECORD_AUDIO >/dev/null 2>&1 || true
    adb -s "$serial" shell appops set "$package" RECORD_AUDIO allow >/dev/null 2>&1 || true
  done
}

# Re-entrant background mode: keep granting RECORD_AUDIO while the suite runs,
# because `flutter test` reinstalls the app/test packages and resets grants.
run_android_watchdog() {
  local serial="$1"
  local max_seconds="$2"
  local deadline=$((SECONDS + max_seconds))
  while (( SECONDS < deadline )); do
    grant_android_microphone_once "$serial"
    sleep "$ANDROID_WATCHDOG_INTERVAL_SECONDS"
  done
}

# Runs `flutter test`, streaming its output live, but kills it if the output
# goes silent for longer than STALL_TIMEOUT_SECONDS. A silent stall means the
# suite is wedged on something the test harness cannot drive (classically the
# native microphone permission dialog); without this guard the run hangs until
# someone notices hours later. Returns flutter's exit code, or 124 on timeout.
run_flutter_with_stall_guard() {
  local device_id="$1"
  shift
  local -a targets=("$@")

  local progress_log
  progress_log="$(mktemp -t wrait-inttest)"

  flutter test -d "$device_id" "${targets[@]}" >"$progress_log" 2>&1 &
  local flutter_pid="$!"

  # Mirror the log to our stdout while flutter runs.
  tail -f "$progress_log" &
  local tail_pid="$!"

  # Stall watchdog: kill flutter if the log stops growing.
  (
    while kill -0 "$flutter_pid" 2>/dev/null; do
      sleep 15
      local last_mtime now
      last_mtime="$(stat -f %m "$progress_log" 2>/dev/null || echo 0)"
      now="$(date +%s)"
      if (( now - last_mtime > STALL_TIMEOUT_SECONDS )); then
        printf '\nerror: no test output for %ss on %s; assuming a stuck native dialog and killing the run.\n' \
          "$STALL_TIMEOUT_SECONDS" "$device_id" >&2
        kill -9 "$flutter_pid" 2>/dev/null || true
        break
      fi
    done
  ) &
  local stall_pid="$!"

  local exit_code=0
  wait "$flutter_pid" || exit_code=$?

  kill "$tail_pid" "$stall_pid" >/dev/null 2>&1 || true
  wait "$tail_pid" "$stall_pid" >/dev/null 2>&1 || true
  rm -f "$progress_log"

  # 137 = SIGKILL (128+9), which is what the stall watchdog sends.
  if (( exit_code == 137 )); then
    return 124
  fi
  return "$exit_code"
}

run_tests_on_device() {
  local device_id="$1"
  shift
  local extra_args=("$@")

  local platform
  platform="$(device_platform "$device_id")"
  [[ -n "$platform" ]] || fail "device not found or offline: $device_id"

  local watchdog_pid=""
  if [[ "$platform" == android* ]]; then
    require_command adb
    printf 'Preparing Android emulator %s (microphone grant watchdog)...\n' "$device_id"
    grant_android_microphone_once "$device_id"
    "$0" --android-record-audio-watchdog "$device_id" "$ANDROID_WATCHDOG_MAX_SECONDS" &
    watchdog_pid="$!"
  elif [[ "$platform" == ios ]]; then
    require_command xcrun
    printf 'Preparing iOS simulator %s (microphone grant)...\n' "$device_id"
    # Up-front grant only. Not looped: `simctl privacy` restarts the app to
    # apply, so the real-recording tests inject a granted permission service
    # instead (see microphone_test_overrides.dart).
    grant_ios_microphone "$device_id"
  else
    fail "unsupported platform '$platform' for device $device_id (only android/ios simulators)"
  fi

  local -a targets
  if (( ${#extra_args[@]} > 0 )); then
    targets=("${extra_args[@]}")
  else
    targets=(integration_test)
  fi

  local exit_code=0
  printf 'Running integration tests on %s...\n' "$device_id"
  run_flutter_with_stall_guard "$device_id" "${targets[@]}" || exit_code=$?

  if [[ -n "$watchdog_pid" ]]; then
    kill "$watchdog_pid" >/dev/null 2>&1 || true
    wait "$watchdog_pid" >/dev/null 2>&1 || true
  fi

  return "$exit_code"
}

main() {
  cd "$ROOT_DIR"
  require_command flutter
  require_command python3

  local devices=()
  local extra_args=()
  local parsing_extra=false
  local arg
  for arg in "$@"; do
    if [[ "$parsing_extra" == true ]]; then
      extra_args+=("$arg")
    elif [[ "$arg" == "--" ]]; then
      parsing_extra=true
    else
      devices+=("$arg")
    fi
  done

  if (( ${#devices[@]} == 0 )); then
    while IFS= read -r line; do
      [[ -n "$line" ]] && devices+=("$line")
    done < <(discover_mobile_devices)
  fi

  (( ${#devices[@]} > 0 )) || fail "no mobile simulators/emulators found; boot one or pass a device id"

  printf 'Target devices: %s\n' "${devices[*]}"

  local overall_exit=0
  local failures=()
  local device_id
  for device_id in "${devices[@]}"; do
    if run_tests_on_device "$device_id" ${extra_args[@]+"${extra_args[@]}"}; then
      printf 'PASS: %s\n' "$device_id"
    else
      overall_exit=1
      failures+=("$device_id")
      printf 'FAIL: %s\n' "$device_id"
    fi
  done

  printf '\n== Integration test summary ==\n'
  for device_id in "${devices[@]}"; do
    if [[ " ${failures[*]:-} " == *" $device_id "* ]]; then
      printf '  %s: FAIL\n' "$device_id"
    else
      printf '  %s: PASS\n' "$device_id"
    fi
  done

  exit "$overall_exit"
}

if [[ "${1:-}" == "--android-record-audio-watchdog" ]]; then
  shift
  run_android_watchdog "$@"
  exit 0
fi

main "$@"

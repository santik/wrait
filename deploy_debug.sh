#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBUG_LOCAL_PROPERTIES_PATH="${DEPLOY_DEBUG_LOCAL_PROPERTIES_PATH:-$ROOT_DIR/android/local.properties}"
DEBUG_APK_PATH="${DEPLOY_DEBUG_APK_PATH:-$ROOT_DIR/build/app/outputs/flutter-apk/app-debug.apk}"
PROFILE_APK_PATH="${DEPLOY_PROFILE_APK_PATH:-$ROOT_DIR/build/app/outputs/flutter-apk/app-profile.apk}"
FLUTTER_PACKAGE="com.wrait.flutter.dev"
FLUTTER_NAMESPACE="com.wrait.flutter"
FLUTTER_TEST_PACKAGE="${FLUTTER_PACKAGE}.test"
AUTOMATION_LOCKSCREEN_MODE_SETTING="${FLUTTER_PACKAGE}.automation_lockscreen_mode"
NATIVE_WRAIT_PACKAGE="com.wrait.app"
MAIN_ACTIVITY_SHORT_COMPONENT="$FLUTTER_PACKAGE/.MainActivity"
MAIN_ACTIVITY_FULL_COMPONENT="$FLUTTER_PACKAGE/$FLUTTER_NAMESPACE.MainActivity"
RUNTIME_PERMISSION_WATCHDOG_MAX_SECONDS="${DEPLOY_RUNTIME_PERMISSION_WATCHDOG_MAX_SECONDS:-900}"
RUNTIME_PERMISSION_WATCHDOG_PID_FILE="${TMPDIR:-/tmp}/wrait-runtime-permission-watchdog.pid"
RUNTIME_PERMISSION_WATCHDOG_PID=""
CLEANUP_PHONE_SERIAL=""
ORIGINAL_STAY_AWAKE_SETTING=""
ORIGINAL_AUTOMATION_LOCKSCREEN_MODE_SETTING=""
RESOLVED_PROXY_SECRET=""
RESOLVED_WIREDASH_PROJECT_ID=""
RESOLVED_WIREDASH_SECRET=""
RESOLVED_WIREDASH_ENVIRONMENT=""
RESOLVED_DEBUG_DEVICE_ID=""

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

validate_positive_integer() {
  local name="$1"
  local value="$2"

  [[ "$value" =~ ^[1-9][0-9]*$ ]] || fail "$name must be a positive integer"
}

validate_proxy_secret() {
  local value="$1"
  local collapsed="${value//[[:space:]]/}"

  [[ -n "$collapsed" ]] || fail "PROXY_SECRET must not be blank or whitespace only"
  [[ "$value" == "$collapsed" ]] || fail "PROXY_SECRET must not contain whitespace"
  (( ${#value} >= 8 )) || fail "PROXY_SECRET must be at least 8 characters long"
}

validate_wiredash_project_id() {
  local value="$1"

  [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{2,127}$ ]] || fail \
    "WIREDASH_PROJECT_ID must be 3-128 characters using letters, numbers, dots, underscores, or hyphens"
}

validate_wiredash_secret() {
  local value="$1"

  [[ "$value" != *[[:space:]]* ]] || fail \
    "WIREDASH_SECRET must not contain whitespace"
  (( ${#value} >= 8 )) || fail "WIREDASH_SECRET must be at least 8 characters long"
}

validate_wiredash_config() {
  local project_id="$RESOLVED_WIREDASH_PROJECT_ID"
  local secret="$RESOLVED_WIREDASH_SECRET"
  local environment="$RESOLVED_WIREDASH_ENVIRONMENT"

  if [[ -n "$project_id" || -n "$secret" || -n "$environment" ]]; then
    [[ -n "$project_id" && -n "$secret" ]] || fail \
      "WIREDASH_PROJECT_ID and WIREDASH_SECRET must be supplied together in $DEBUG_LOCAL_PROPERTIES_PATH"
    validate_wiredash_project_id "$project_id"
    validate_wiredash_secret "$secret"
    [[ "$environment" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || fail \
      "WIREDASH_ENVIRONMENT must be 1-64 characters using letters, numbers, dots, underscores, or hyphens"
  fi
}

trim_value() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

read_property_from_file() {
  local file_path="$1"
  local property_name="$2"

  awk -v key="$property_name" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      line = $0
      separator_index = index(line, "=")
      if (separator_index == 0) {
        next
      }

      current_key = substr(line, 1, separator_index - 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", current_key)
      if (current_key == key) {
        print substr(line, separator_index + 1)
        found = 1
        exit
      }
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$file_path"
}

require_readable_file() {
  local file_path="$1"
  local description="$2"

  [[ -f "$file_path" ]] || fail "$description is missing: $file_path"
  [[ -r "$file_path" ]] || fail "$description is not readable: $file_path"
}

require_non_blank_property() {
  local file_path="$1"
  local property_name="$2"
  local value
  local trimmed

  value="$(read_property_from_file "$file_path" "$property_name" 2>/dev/null || true)"
  value="${value%$'\r'}"
  trimmed="$(trim_value "$value")"
  [[ -n "$trimmed" ]] || fail "$property_name is missing or blank in $file_path"
  printf '%s\n' "$trimmed"
}

optional_trimmed_property() {
  local file_path="$1"
  local property_name="$2"
  local value

  value="$(read_property_from_file "$file_path" "$property_name" 2>/dev/null || true)"
  value="${value%$'\r'}"
  trim_value "$value"
}

load_and_validate_debug_config() {
  require_readable_file "$DEBUG_LOCAL_PROPERTIES_PATH" "debug config"

  RESOLVED_PROXY_SECRET="$(
    require_non_blank_property "$DEBUG_LOCAL_PROPERTIES_PATH" "PROXY_SECRET"
  )"
  RESOLVED_WIREDASH_PROJECT_ID="$(
    optional_trimmed_property "$DEBUG_LOCAL_PROPERTIES_PATH" "WIREDASH_PROJECT_ID"
  )"
  RESOLVED_WIREDASH_SECRET="$(
    optional_trimmed_property "$DEBUG_LOCAL_PROPERTIES_PATH" "WIREDASH_SECRET"
  )"
  RESOLVED_WIREDASH_ENVIRONMENT="$(
    optional_trimmed_property "$DEBUG_LOCAL_PROPERTIES_PATH" "WIREDASH_ENVIRONMENT"
  )"
  RESOLVED_DEBUG_DEVICE_ID="$(
    optional_trimmed_property "$DEBUG_LOCAL_PROPERTIES_PATH" "DEBUG_DEVICE_ID"
  )"
  if [[ -n "$RESOLVED_DEBUG_DEVICE_ID" && ! "$RESOLVED_DEBUG_DEVICE_ID" =~ ^[0-9a-f]{64}$ ]]; then
    warn "DEBUG_DEVICE_ID is not a valid SHA-256 hex hash (expected 64 lowercase hex characters)"
  fi

  validate_proxy_secret "$RESOLVED_PROXY_SECRET"
  validate_wiredash_config
}

configure_java() {
  # Some editors inject a Java runtime path that no longer exists.
  unset VSCODE_JAVA_EXEC || true

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
}

find_connected_phone() {
  local line serial state
  local devices_output
  local phone_serials=()
  local unavailable_phone_lines=()

  if ! devices_output="$(adb devices)"; then
    fail "adb devices failed; ensure Android platform tools can access the ADB daemon"
  fi

  while IFS= read -r line; do
    [[ -z "$line" || "$line" == "List of devices attached" ]] && continue

    read -r serial state _ <<<"$line"
    [[ -z "${serial:-}" ]] && continue

    # US-027 targets a physical Android phone and intentionally ignores emulators.
    if [[ "$serial" == emulator-* ]]; then
      continue
    fi

    if [[ "${state:-}" == "device" ]]; then
      phone_serials+=("$serial")
    else
      unavailable_phone_lines+=("$serial ${state:-unknown}")
    fi
  done <<<"$devices_output"

  if (( ${#phone_serials[@]} == 1 )); then
    printf '%s\n' "${phone_serials[0]}"
    return 0
  fi

  if (( ${#phone_serials[@]} > 1 )); then
    fail "expected one connected Android phone, found ${#phone_serials[@]}; disconnect extra phones and retry"
  fi

  if (( ${#unavailable_phone_lines[@]} > 0 )); then
    printf 'error: Android phone is connected but unavailable:\n' >&2
    printf '  %s\n' "${unavailable_phone_lines[@]}" >&2
    printf 'Authorize the phone for USB debugging, wait for it to come online, then retry.\n' >&2
    exit 1
  fi

  fail "no connected Android phone found; connect and authorize one phone, then retry"
}

package_installed() {
  local phone_serial="$1"
  local package_name="$2"
  adb -s "$phone_serial" shell pm path "$package_name" >/dev/null 2>&1
}

grant_runtime_permission_if_possible() {
  local phone_serial="$1"
  local package_name="$2"
  local permission_name="$3"
  local app_op_name="${4:-}"

  package_installed "$phone_serial" "$package_name" || return 1

  adb -s "$phone_serial" shell pm grant "$package_name" "$permission_name" >/dev/null 2>&1 || return 1

  if [[ -n "$app_op_name" ]]; then
    if ! adb -s "$phone_serial" shell appops set "$package_name" "$app_op_name" allow >/dev/null 2>&1; then
      warn "failed to set app op $app_op_name=allow for $package_name on $phone_serial after granting $permission_name"
    fi
  fi

  return 0
}

ensure_phone_connected() {
  local phone_serial="$1"
  local state

  state="$(adb -s "$phone_serial" get-state 2>/dev/null || true)"
  [[ "$state" == "device" ]] || fail "Android phone $phone_serial is no longer connected and ready"
}

ensure_phone_ready_for_phase() {
  local phone_serial="$1"
  local phase_description="$2"
  local state

  state="$(adb -s "$phone_serial" get-state 2>/dev/null || true)"
  [[ "$state" == "device" ]] || fail \
    "Android phone $phone_serial is not ready for $phase_description"
}

force_stop_package() {
  local phone_serial="$1"
  local package_name="$2"

  adb -s "$phone_serial" shell am force-stop "$package_name" >/dev/null 2>&1 || true
}

read_stay_awake_setting() {
  local phone_serial="$1"
  local setting

  setting="$(adb -s "$phone_serial" shell settings get global stay_on_while_plugged_in 2>/dev/null || true)"
  setting="${setting//$'\r'/}"
  printf '%s\n' "$setting"
}

enable_stay_awake() {
  local phone_serial="$1"

  if [[ -z "$ORIGINAL_STAY_AWAKE_SETTING" ]]; then
    ORIGINAL_STAY_AWAKE_SETTING="$(read_stay_awake_setting "$phone_serial")"
  fi

  adb -s "$phone_serial" shell svc power stayon usb >/dev/null 2>&1 || fail \
    "failed to keep Android phone $phone_serial awake over USB"
  printf 'Keeping Android phone %s awake over USB while deploy_debug.sh runs.\n' "$phone_serial"
}

restore_stay_awake() {
  local phone_serial="${1:-$CLEANUP_PHONE_SERIAL}"

  [[ -n "$phone_serial" ]] || return 0
  [[ -n "$ORIGINAL_STAY_AWAKE_SETTING" ]] || return 0

  case "$ORIGINAL_STAY_AWAKE_SETTING" in
    ""|null|0)
      if ! adb -s "$phone_serial" shell svc power stayon false >/dev/null 2>&1; then
        warn "failed to restore stay-awake mode to false on $phone_serial"
      fi
      ;;
    *)
      if ! adb -s "$phone_serial" shell settings put global stay_on_while_plugged_in \
        "$ORIGINAL_STAY_AWAKE_SETTING" >/dev/null 2>&1; then
        warn "failed to restore stay_on_while_plugged_in=$ORIGINAL_STAY_AWAKE_SETTING on $phone_serial"
      fi
      ;;
  esac
}

read_global_setting() {
  local phone_serial="$1"
  local setting_name="$2"
  local setting

  setting="$(adb -s "$phone_serial" shell settings get global "$setting_name" 2>/dev/null || true)"
  setting="${setting//$'\r'/}"
  printf '%s\n' "$setting"
}

set_global_setting() {
  local phone_serial="$1"
  local setting_name="$2"
  local setting_value="$3"
  local confirmed_value

  adb -s "$phone_serial" shell settings put global "$setting_name" "$setting_value" >/dev/null 2>&1 || fail \
    "failed to set Android global setting $setting_name=$setting_value on $phone_serial"

  confirmed_value="$(read_global_setting "$phone_serial" "$setting_name")"
  [[ "$confirmed_value" == "$setting_value" ]] || fail \
    "Android global setting $setting_name did not stick on $phone_serial; expected $setting_value but read $confirmed_value"
}

enable_automation_lockscreen_mode() {
  local phone_serial="$1"

  if [[ -z "$ORIGINAL_AUTOMATION_LOCKSCREEN_MODE_SETTING" ]]; then
    ORIGINAL_AUTOMATION_LOCKSCREEN_MODE_SETTING="$(
      read_global_setting "$phone_serial" "$AUTOMATION_LOCKSCREEN_MODE_SETTING"
    )"
  fi

  set_global_setting "$phone_serial" "$AUTOMATION_LOCKSCREEN_MODE_SETTING" "1"
  printf 'Enabled Android debug lock-screen automation mode on %s.\n' "$phone_serial"
}

restore_automation_lockscreen_mode() {
  local phone_serial="${1:-$CLEANUP_PHONE_SERIAL}"

  [[ -n "$phone_serial" ]] || return 0
  [[ -n "$ORIGINAL_AUTOMATION_LOCKSCREEN_MODE_SETTING" ]] || return 0

  case "$ORIGINAL_AUTOMATION_LOCKSCREEN_MODE_SETTING" in
    ""|null)
      set_global_setting "$phone_serial" "$AUTOMATION_LOCKSCREEN_MODE_SETTING" "0"
      ;;
    *)
      set_global_setting \
        "$phone_serial" \
        "$AUTOMATION_LOCKSCREEN_MODE_SETTING" \
        "$ORIGINAL_AUTOMATION_LOCKSCREEN_MODE_SETTING"
      ;;
  esac

  ORIGINAL_AUTOMATION_LOCKSCREEN_MODE_SETTING=""
}

cleanup_on_exit() {
  stop_background_watchdog
  restore_automation_lockscreen_mode
  restore_stay_awake
}

prepare_phone_for_automation() {
  local phone_serial="$1"
  local phase_description="$2"

  printf 'Preparing Android phone %s for %s...\n' "$phone_serial" "$phase_description"
  ensure_phone_ready_for_phase "$phone_serial" "$phase_description"

  adb -s "$phone_serial" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || fail \
    "failed to wake Android phone $phone_serial for $phase_description"

  if adb -s "$phone_serial" shell wm dismiss-keyguard >/dev/null 2>&1; then
    printf 'Prepared Android phone %s for %s.\n' "$phone_serial" "$phase_description"
  else
    printf 'Android phone %s refused non-interactive keyguard dismissal for %s; continuing with debug locked-screen launch support.\n' \
      "$phone_serial" "$phase_description"
  fi

  ensure_phone_ready_for_phase "$phone_serial" "$phase_description"
}

clear_runtime_permission_watchdog_pid_file() {
  rm -f "$RUNTIME_PERMISSION_WATCHDOG_PID_FILE"
}

clear_stale_runtime_permission_watchdog() {
  local stale_pid
  local command_line

  [[ -f "$RUNTIME_PERMISSION_WATCHDOG_PID_FILE" ]] || return 0

  stale_pid="$(tr -d '[:space:]' <"$RUNTIME_PERMISSION_WATCHDOG_PID_FILE" 2>/dev/null || true)"
  [[ "$stale_pid" =~ ^[0-9]+$ ]] || {
    clear_runtime_permission_watchdog_pid_file
    return 0
  }

  if ! kill -0 "$stale_pid" >/dev/null 2>&1; then
    clear_runtime_permission_watchdog_pid_file
    return 0
  fi

  command_line="$(ps -p "$stale_pid" -o command= 2>/dev/null || true)"
  if [[ "$command_line" == *"--watch-runtime-permissions"* ]]; then
    kill "$stale_pid" >/dev/null 2>&1 || warn \
      "failed to stop stale runtime-permission watchdog process $stale_pid"
  fi

  clear_runtime_permission_watchdog_pid_file
}

grant_automation_audio_recording_permissions() {
  local phone_serial="$1"
  grant_runtime_permission_if_possible \
    "$phone_serial" \
    "$FLUTTER_PACKAGE" \
    "android.permission.RECORD_AUDIO" \
    "RECORD_AUDIO"
}

run_runtime_permission_watchdog() {
  local phone_serial="$1"
  local max_seconds="$2"
  local deadline=$((SECONDS + max_seconds))
  local announced_flutter_package=false

  while (( SECONDS < deadline )); do
    if grant_runtime_permission_if_possible \
      "$phone_serial" \
      "$FLUTTER_PACKAGE" \
      "android.permission.RECORD_AUDIO" \
      "RECORD_AUDIO"; then
      if [[ "$announced_flutter_package" == false ]]; then
        printf 'Granted android.permission.RECORD_AUDIO to %s for automated tests.\n' "$FLUTTER_PACKAGE"
        announced_flutter_package=true
      fi
    fi

    # `flutter test` can reinstall both the app and the companion test package.
    grant_runtime_permission_if_possible \
      "$phone_serial" \
      "$FLUTTER_TEST_PACKAGE" \
      "android.permission.RECORD_AUDIO" \
      "RECORD_AUDIO" || true
    sleep 0.5
  done
}

start_runtime_permission_watchdog() {
  local phone_serial="$1"

  clear_stale_runtime_permission_watchdog
  "$0" --watch-runtime-permissions "$phone_serial" "$RUNTIME_PERMISSION_WATCHDOG_MAX_SECONDS" &
  RUNTIME_PERMISSION_WATCHDOG_PID="$!"
  printf '%s\n' "$RUNTIME_PERMISSION_WATCHDOG_PID" >"$RUNTIME_PERMISSION_WATCHDOG_PID_FILE"
}

stop_background_watchdog() {
  local watchdog_pid="${1:-$RUNTIME_PERMISSION_WATCHDOG_PID}"

  [[ -n "$watchdog_pid" ]] || return 0

  if kill -0 "$watchdog_pid" >/dev/null 2>&1; then
    kill "$watchdog_pid" >/dev/null 2>&1 || true
  fi

  wait "$watchdog_pid" >/dev/null 2>&1 || true
  RUNTIME_PERMISSION_WATCHDOG_PID=""
  clear_runtime_permission_watchdog_pid_file
}

read_first_matching_line() {
  local text="$1"
  local pattern="$2"
  local line

  while IFS= read -r line; do
    if [[ "$line" =~ $pattern ]]; then
      printf '%s\n' "$line"
      return 0
    fi
  done <<<"$text"

  return 1
}

line_references_main_activity() {
  local line="$1"
  [[ "$line" == *"$MAIN_ACTIVITY_FULL_COMPONENT"* || "$line" == *"$MAIN_ACTIVITY_SHORT_COMPONENT"* ]]
}

flutter_app_is_foreground() {
  local phone_serial="$1"
  local activity_output
  local resumed_line
  local window_output
  local focused_line

  activity_output="$(adb -s "$phone_serial" shell dumpsys activity activities 2>/dev/null || true)"
  resumed_line="$(read_first_matching_line "$activity_output" 'ResumedActivity:')" || true
  if [[ -n "$resumed_line" ]] && line_references_main_activity "$resumed_line"; then
    return 0
  fi

  window_output="$(adb -s "$phone_serial" shell dumpsys window 2>/dev/null || true)"
  focused_line="$(read_first_matching_line "$window_output" 'mCurrentFocus=')" || true
  [[ -n "$focused_line" ]] && line_references_main_activity "$focused_line"
}

launch_flutter_app() {
  local phone_serial="$1"
  local output

  output="$(
    adb -s "$phone_serial" shell am start -W \
      -n "$MAIN_ACTIVITY_FULL_COMPONENT" 2>&1
  )" || fail "failed to launch $FLUTTER_PACKAGE after install"

  printf '%s\n' "$output"

  if [[ "$output" == *"Status: timeout"* ]]; then
    if flutter_app_is_foreground "$phone_serial"; then
      printf '%s launch reported timeout, but foreground verification succeeded.\n' "$FLUTTER_PACKAGE"
      return 0
    fi

    fail "$FLUTTER_PACKAGE launch timed out after install and foreground verification failed; force-stop the app and inspect device logs"
  fi

  [[ "$output" == *"Activity: $MAIN_ACTIVITY_FULL_COMPONENT"* || "$output" == *"Activity: $MAIN_ACTIVITY_SHORT_COMPONENT"* ]] || fail \
    "$FLUTTER_PACKAGE launch verification did not report MainActivity"
}

prepare_apk_output() {
  local apk_path="$1"

  mkdir -p "$(dirname "$apk_path")"
  rm -f "$apk_path"
}

verify_built_apk() {
  local apk_path="$1"
  local artifact_label="$2"

  [[ -f "$apk_path" ]] || fail "$artifact_label was not created at $apk_path"
  [[ -s "$apk_path" ]] || fail "$artifact_label at $apk_path is empty"
}

handle_watchdog_mode() {
  local phone_serial="$1"
  local max_seconds="$2"

  validate_positive_integer "DEPLOY_RUNTIME_PERMISSION_WATCHDOG_MAX_SECONDS" "$max_seconds"
  run_runtime_permission_watchdog "$phone_serial" "$max_seconds"
}

main() {
  cd "$ROOT_DIR"
  configure_java
  require_command adb
  require_command flutter
  load_and_validate_debug_config
  validate_positive_integer "DEPLOY_RUNTIME_PERMISSION_WATCHDOG_MAX_SECONDS" \
    "$RUNTIME_PERMISSION_WATCHDOG_MAX_SECONDS"

  local phone_serial
  phone_serial="$(find_connected_phone)"
  CLEANUP_PHONE_SERIAL="$phone_serial"
  trap cleanup_on_exit EXIT
  local native_wrait_was_installed=false
  local flutter_build_args=(
    "--dart-define=PROXY_SECRET=$RESOLVED_PROXY_SECRET"
  )
  if [[ -n "$RESOLVED_WIREDASH_PROJECT_ID" ]]; then
    flutter_build_args+=(
      "--dart-define=WIREDASH_PROJECT_ID=$RESOLVED_WIREDASH_PROJECT_ID"
      "--dart-define=WIREDASH_SECRET=$RESOLVED_WIREDASH_SECRET"
      "--dart-define=WIREDASH_ENVIRONMENT=$RESOLVED_WIREDASH_ENVIRONMENT"
    )
  fi
  if [[ -n "$RESOLVED_DEBUG_DEVICE_ID" ]]; then
    flutter_build_args+=(
      "--dart-define=DEBUG_DEVICE_ID=$RESOLVED_DEBUG_DEVICE_ID"
    )
  fi

  printf 'Building Flutter debug APK...\n'
  prepare_apk_output "$DEBUG_APK_PATH"
  flutter build apk --debug "${flutter_build_args[@]}"

  verify_built_apk "$DEBUG_APK_PATH" "debug APK"

  enable_stay_awake "$phone_serial"
  enable_automation_lockscreen_mode "$phone_serial"
  prepare_phone_for_automation "$phone_serial" "Flutter integration tests"
  grant_automation_audio_recording_permissions "$phone_serial" || true
  start_runtime_permission_watchdog "$phone_serial"
  printf 'Running Flutter integration tests on %s...\n' "$phone_serial"
  if ! flutter test --no-pub -d "$phone_serial" integration_test; then
    stop_background_watchdog
    return 1
  fi
  stop_background_watchdog

  printf 'Building Flutter profile APK for the final installed app...\n'
  prepare_apk_output "$PROFILE_APK_PATH"
  flutter build apk --profile "${flutter_build_args[@]}"
  verify_built_apk "$PROFILE_APK_PATH" "profile APK"

  printf 'Stopping any stale Flutter app task before install...\n'
  force_stop_package "$phone_serial" "$FLUTTER_PACKAGE"

  if package_installed "$phone_serial" "$NATIVE_WRAIT_PACKAGE"; then
    native_wrait_was_installed=true
    printf 'Detected existing native Wrait app (%s); it will be left installed.\n' "$NATIVE_WRAIT_PACKAGE"
  else
    printf 'Native Wrait app (%s) was not installed before deployment.\n' "$NATIVE_WRAIT_PACKAGE"
  fi

  ensure_phone_connected "$phone_serial"
  printf 'Installing profile APK on %s...\n' "$phone_serial"
  adb -s "$phone_serial" install -r "$PROFILE_APK_PATH"

  package_installed "$phone_serial" "$FLUTTER_PACKAGE" || fail "$FLUTTER_PACKAGE was not found after install"

  if [[ "$native_wrait_was_installed" == true ]]; then
    package_installed "$phone_serial" "$NATIVE_WRAIT_PACKAGE" || fail \
      "$NATIVE_WRAIT_PACKAGE was installed before deployment but is missing after install"
    printf 'Verified %s remains installed.\n' "$NATIVE_WRAIT_PACKAGE"
  fi

  printf 'Stopping Flutter app before final launch verification...\n'
  force_stop_package "$phone_serial" "$FLUTTER_PACKAGE"
  restore_automation_lockscreen_mode "$phone_serial"
  prepare_phone_for_automation "$phone_serial" "final installed app launch"
  printf 'Launching %s on %s...\n' "$FLUTTER_PACKAGE" "$phone_serial"
  launch_flutter_app "$phone_serial"

  printf 'Installed and launched %s on %s.\n' "$FLUTTER_PACKAGE" "$phone_serial"

  trap - EXIT
  cleanup_on_exit
}

if [[ "${1:-}" == "--watch-runtime-permissions" ]]; then
  shift
  handle_watchdog_mode "$@"
  exit 0
fi

main "$@"

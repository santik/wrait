#!/usr/bin/env bash
set -euo pipefail

# Usage: ./deploy_release.sh
# Prerequisites:
# - exactly one connected physical Android phone
# - release-signing keys and runtime values present in android/local.properties
# - release-signing passwords present in android/local.properties or supplied
#   through transient WRAIT_RELEASE_* environment variables
# - release-signing passwords stay in-memory for build/keytool validation

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_APK_PATH="${DEPLOY_RELEASE_APK_PATH:-$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk}"
SOURCE_LOCAL_PROPERTIES_PATH="${DEPLOY_RELEASE_SOURCE_LOCAL_PROPERTIES_PATH:-$ROOT_DIR/android/local.properties}"
TARGET_LOCAL_PROPERTIES_PATH="${DEPLOY_RELEASE_TARGET_LOCAL_PROPERTIES_PATH:-$ROOT_DIR/android/local.properties}"
FLUTTER_PACKAGE="com.wrait.flutter"
FLUTTER_NAMESPACE="com.wrait.flutter"
DEBUG_FLUTTER_PACKAGE="com.wrait.flutter.dev"
NATIVE_WRAIT_PACKAGE="com.wrait.app"
MAIN_ACTIVITY_SHORT_COMPONENT="$FLUTTER_PACKAGE/.MainActivity"
MAIN_ACTIVITY_FULL_COMPONENT="$FLUTTER_PACKAGE/$FLUTTER_NAMESPACE.MainActivity"
RELEASE_KEYSTORE_PASSWORD_ENV="WRAIT_RELEASE_KEYSTORE_PASSWORD"
RELEASE_KEY_PASSWORD_ENV="WRAIT_RELEASE_KEY_PASSWORD"

RESOLVED_KEYSTORE_PATH=""
RESOLVED_KEYSTORE_PASSWORD=""
RESOLVED_KEY_ALIAS=""
RESOLVED_KEY_PASSWORD=""
RESOLVED_BACKEND_URL=""
RESOLVED_PROXY_SECRET=""
RESOLVED_RECORDING_HARD_CAP_MS=""
RESOLVED_WIREDASH_PROJECT_ID=""
RESOLVED_WIREDASH_SECRET=""
RESOLVED_WIREDASH_ENVIRONMENT=""
RESOLVED_DEBUG_DEVICE_ID=""
SYNCED_TARGET_LOCAL_PROPERTIES=false

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

validate_wiredash_environment() {
  local value="$1"

  [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || fail \
    "WIREDASH_ENVIRONMENT must be 1-64 characters using letters, numbers, dots, underscores, or hyphens"
}

validate_backend_url() {
  local value="$1"
  local remainder
  local authority
  local host

  case "$value" in
    http://*)
      remainder="${value#http://}"
      ;;
    https://*)
      remainder="${value#https://}"
      ;;
    *)
      fail "BACKEND_URL must be an absolute http or https URL in $SOURCE_LOCAL_PROPERTIES_PATH"
      ;;
  esac

  authority="${remainder%%/*}"
  authority="${authority%%\?*}"
  authority="${authority%%\#*}"
  [[ -n "$authority" ]] || fail \
    "BACKEND_URL must include a host in $SOURCE_LOCAL_PROPERTIES_PATH"
  [[ "$authority" != *[[:space:]]* ]] || fail \
    "BACKEND_URL must not contain whitespace in $SOURCE_LOCAL_PROPERTIES_PATH"

  if [[ "$authority" == \[*\] || "$authority" == \[*\]:* ]]; then
    host="${authority#\[}"
    host="${host%%]*}"
  else
    host="${authority%%:*}"
  fi

  [[ -n "$host" ]] || fail \
    "BACKEND_URL must include a host in $SOURCE_LOCAL_PROPERTIES_PATH"
}

configure_java() {
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

ensure_phone_connected() {
  local phone_serial="$1"
  local state

  state="$(adb -s "$phone_serial" get-state 2>/dev/null || true)"
  [[ "$state" == "device" ]] || fail "Android phone $phone_serial is no longer connected and ready"
}

force_stop_package() {
  local phone_serial="$1"
  local package_name="$2"

  adb -s "$phone_serial" shell am force-stop "$package_name" >/dev/null 2>&1 || true
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

    fail "$FLUTTER_PACKAGE launch timed out after install and foreground verification failed; unlock the phone and inspect device logs"
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

install_release_apk() {
  local phone_serial="$1"
  local apk_path="$2"
  local output

  if output="$(adb -s "$phone_serial" install -r "$apk_path" 2>&1)"; then
    printf '%s\n' "$output"
    return 0
  fi

  printf '%s\n' "$output" >&2

  if [[ "$output" == *"INSTALL_FAILED_UPDATE_INCOMPATIBLE"* ]]; then
    fail \
      "existing $FLUTTER_PACKAGE on $phone_serial is signed with a different key than this release build; verify KEYSTORE_PATH/KEY_ALIAS in $SOURCE_LOCAL_PROPERTIES_PATH or manually uninstall $FLUTTER_PACKAGE if you intentionally want a fresh install"
  fi

  fail "failed to install release APK on $phone_serial"
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

resolve_source_relative_path() {
  local source_file="$1"
  local configured_path="$2"
  local source_dir

  # Relative KEYSTORE_PATH values are interpreted relative to the canonical
  # source config file that defines them.
  source_dir="$(cd "$(dirname "$source_file")" && pwd)"
  if [[ "$configured_path" = /* ]]; then
    printf '%s\n' "$configured_path"
  else
    printf '%s\n' "$source_dir/$configured_path"
  fi
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

require_first_non_blank_property() {
  local file_path="$1"
  shift
  local property_name
  local value

  for property_name in "$@"; do
    value="$(optional_trimmed_property "$file_path" "$property_name")"
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  done

  fail "$* is missing or blank in $file_path"
}

absolute_path_for_compare() {
  local path="$1"
  local dir
  local base

  dir="$(dirname "$path")"
  base="$(basename "$path")"
  if [[ -d "$dir" ]]; then
    printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$base"
  else
    printf '%s\n' "$path"
  fi
}

local_properties_paths_match() {
  [[ "$(absolute_path_for_compare "$SOURCE_LOCAL_PROPERTIES_PATH")" == \
    "$(absolute_path_for_compare "$TARGET_LOCAL_PROPERTIES_PATH")" ]]
}

sync_target_local_properties() {
  local target_dir
  local filtered_tmpfile
  local final_tmpfile

  if local_properties_paths_match; then
    return 0
  fi

  target_dir="$(dirname "$TARGET_LOCAL_PROPERTIES_PATH")"
  [[ -d "$target_dir" ]] || fail "Flutter app-local config directory is missing: $target_dir"
  [[ -w "$target_dir" ]] || fail "Flutter app-local config directory is not writable: $target_dir"

  filtered_tmpfile="$(mktemp "${TMPDIR:-/tmp}/deploy-release-local-properties-filtered.XXXXXX")"
  final_tmpfile="$(mktemp "${TMPDIR:-/tmp}/deploy-release-local-properties-final.XXXXXX")"

  if [[ -f "$TARGET_LOCAL_PROPERTIES_PATH" ]]; then
    awk '
      BEGIN {
        managed["KEYSTORE_PATH"] = 1
        managed["KEY_ALIAS"] = 1
        managed["BACKEND_URL"] = 1
        managed["PROXY_SECRET"] = 1
        managed["RECORDING_HARD_CAP_MS"] = 1
        managed["WIREDASH_PROJECT_ID"] = 1
        managed["WIREDASH_ENVIRONMENT"] = 1
        managed["WIREDASH_SECRET"] = 1
        managed["KEYSTORE_PASSWORD"] = 1
        managed["KEY_PASSWORD"] = 1
        managed["WRAIT_RELEASE_KEYSTORE_PASSWORD"] = 1
        managed["WRAIT_RELEASE_KEY_PASSWORD"] = 1
      }
      {
        line = $0
        separator_index = index(line, "=")
        if (separator_index > 0) {
          current_key = substr(line, 1, separator_index - 1)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", current_key)
          if (current_key in managed) {
            next
          }
        }
        print line
      }
    ' "$TARGET_LOCAL_PROPERTIES_PATH" >"$filtered_tmpfile"
  else
    : >"$filtered_tmpfile"
  fi

  {
    cat "$filtered_tmpfile"
    printf 'KEYSTORE_PATH=%s\n' "$RESOLVED_KEYSTORE_PATH"
    printf 'KEY_ALIAS=%s\n' "$RESOLVED_KEY_ALIAS"
    printf 'BACKEND_URL=%s\n' "$RESOLVED_BACKEND_URL"
    printf 'PROXY_SECRET=%s\n' "$RESOLVED_PROXY_SECRET"
    printf 'RECORDING_HARD_CAP_MS=%s\n' "$RESOLVED_RECORDING_HARD_CAP_MS"
    printf 'WIREDASH_PROJECT_ID=%s\n' "$RESOLVED_WIREDASH_PROJECT_ID"
    printf 'WIREDASH_SECRET=%s\n' "$RESOLVED_WIREDASH_SECRET"
    printf 'WIREDASH_ENVIRONMENT=%s\n' "$RESOLVED_WIREDASH_ENVIRONMENT"
  } >"$final_tmpfile"

  mv "$final_tmpfile" "$TARGET_LOCAL_PROPERTIES_PATH"
  rm -f "$filtered_tmpfile"
  SYNCED_TARGET_LOCAL_PROPERTIES=true
}

validate_release_keystore() {
  local csr_tmpfile

  csr_tmpfile="$(mktemp "${TMPDIR:-/tmp}/deploy-release-keystore-check.XXXXXX")"

  if ! keytool \
    -list \
    -keystore "$RESOLVED_KEYSTORE_PATH" \
    -storepass "$RESOLVED_KEYSTORE_PASSWORD" \
    -alias "$RESOLVED_KEY_ALIAS" \
    >/dev/null 2>&1; then
    rm -f "$csr_tmpfile"
    fail \
      "release keystore validation failed; verify KEYSTORE_PATH, KEY_ALIAS, and KEYSTORE_PASSWORD or WRAIT_RELEASE_KEYSTORE_PASSWORD in $SOURCE_LOCAL_PROPERTIES_PATH"
  fi

  if ! keytool \
    -certreq \
    -keystore "$RESOLVED_KEYSTORE_PATH" \
    -storepass "$RESOLVED_KEYSTORE_PASSWORD" \
    -alias "$RESOLVED_KEY_ALIAS" \
    -keypass "$RESOLVED_KEY_PASSWORD" \
    -file "$csr_tmpfile" \
    >/dev/null 2>&1; then
    rm -f "$csr_tmpfile"
    fail \
      "release key validation failed; verify KEY_ALIAS and KEY_PASSWORD or WRAIT_RELEASE_KEY_PASSWORD in $SOURCE_LOCAL_PROPERTIES_PATH"
  fi

  rm -f "$csr_tmpfile"
}

load_and_validate_private_config() {
  local raw_keystore_path

  require_readable_file "$SOURCE_LOCAL_PROPERTIES_PATH" "private source config"

  RESOLVED_KEYSTORE_PATH="$(
    require_non_blank_property "$SOURCE_LOCAL_PROPERTIES_PATH" "KEYSTORE_PATH"
  )"
  RESOLVED_KEYSTORE_PASSWORD="${WRAIT_RELEASE_KEYSTORE_PASSWORD:-}"
  if [[ -z "$RESOLVED_KEYSTORE_PASSWORD" ]]; then
    RESOLVED_KEYSTORE_PASSWORD="$(
      require_first_non_blank_property \
        "$SOURCE_LOCAL_PROPERTIES_PATH" \
        "KEYSTORE_PASSWORD" \
        "WRAIT_RELEASE_KEYSTORE_PASSWORD"
    )"
  fi
  RESOLVED_KEY_ALIAS="$(
    require_non_blank_property "$SOURCE_LOCAL_PROPERTIES_PATH" "KEY_ALIAS"
  )"
  RESOLVED_KEY_PASSWORD="${WRAIT_RELEASE_KEY_PASSWORD:-}"
  if [[ -z "$RESOLVED_KEY_PASSWORD" ]]; then
    RESOLVED_KEY_PASSWORD="$(
      require_first_non_blank_property \
        "$SOURCE_LOCAL_PROPERTIES_PATH" \
        "KEY_PASSWORD" \
        "WRAIT_RELEASE_KEY_PASSWORD"
    )"
  fi
  RESOLVED_BACKEND_URL="$(
    require_non_blank_property "$SOURCE_LOCAL_PROPERTIES_PATH" "BACKEND_URL"
  )"
  RESOLVED_PROXY_SECRET="$(
    require_non_blank_property "$SOURCE_LOCAL_PROPERTIES_PATH" "PROXY_SECRET"
  )"
  RESOLVED_RECORDING_HARD_CAP_MS="$(
    require_non_blank_property "$SOURCE_LOCAL_PROPERTIES_PATH" "RECORDING_HARD_CAP_MS"
  )"
  RESOLVED_WIREDASH_PROJECT_ID="$(
    require_non_blank_property "$SOURCE_LOCAL_PROPERTIES_PATH" "WIREDASH_PROJECT_ID"
  )"
  RESOLVED_WIREDASH_SECRET="$(
    require_non_blank_property "$SOURCE_LOCAL_PROPERTIES_PATH" "WIREDASH_SECRET"
  )"
  RESOLVED_WIREDASH_ENVIRONMENT="$(
    require_non_blank_property "$SOURCE_LOCAL_PROPERTIES_PATH" "WIREDASH_ENVIRONMENT"
  )"
  RESOLVED_DEBUG_DEVICE_ID="$(
    optional_trimmed_property "$SOURCE_LOCAL_PROPERTIES_PATH" "DEBUG_DEVICE_ID"
  )"
  if [[ -n "$RESOLVED_DEBUG_DEVICE_ID" && ! "$RESOLVED_DEBUG_DEVICE_ID" =~ ^[0-9a-f]{64}$ ]]; then
    warn "DEBUG_DEVICE_ID is not a valid SHA-256 hex hash (expected 64 lowercase hex characters)"
  fi

  raw_keystore_path="$RESOLVED_KEYSTORE_PATH"
  RESOLVED_KEYSTORE_PATH="$(resolve_source_relative_path "$SOURCE_LOCAL_PROPERTIES_PATH" "$raw_keystore_path")"

  [[ -f "$RESOLVED_KEYSTORE_PATH" ]] || fail \
    "KEYSTORE_PATH does not point to a file reachable from $SOURCE_LOCAL_PROPERTIES_PATH"
  [[ -r "$RESOLVED_KEYSTORE_PATH" ]] || fail \
    "KEYSTORE_PATH is not readable: $RESOLVED_KEYSTORE_PATH"

  validate_backend_url "$RESOLVED_BACKEND_URL"
  validate_proxy_secret "$RESOLVED_PROXY_SECRET"
  validate_positive_integer "RECORDING_HARD_CAP_MS" "$RESOLVED_RECORDING_HARD_CAP_MS"
  validate_wiredash_project_id "$RESOLVED_WIREDASH_PROJECT_ID"
  validate_wiredash_secret "$RESOLVED_WIREDASH_SECRET"
  validate_wiredash_environment "$RESOLVED_WIREDASH_ENVIRONMENT"
  validate_release_keystore
}

main() {
  cd "$ROOT_DIR"
  configure_java
  require_command adb
  require_command flutter
  require_command keytool
  load_and_validate_private_config
  sync_target_local_properties

  local phone_serial
  local native_wrait_was_installed=false
  local debug_flutter_was_installed=false
  local flutter_build_args=(
    "--dart-define=BACKEND_URL=$RESOLVED_BACKEND_URL"
    "--dart-define=PROXY_SECRET=$RESOLVED_PROXY_SECRET"
    "--dart-define=RECORDING_HARD_CAP_MS=$RESOLVED_RECORDING_HARD_CAP_MS"
    "--dart-define=WIREDASH_PROJECT_ID=$RESOLVED_WIREDASH_PROJECT_ID"
    "--dart-define=WIREDASH_SECRET=$RESOLVED_WIREDASH_SECRET"
    "--dart-define=WIREDASH_ENVIRONMENT=$RESOLVED_WIREDASH_ENVIRONMENT"
  )
  if [[ -n "$RESOLVED_DEBUG_DEVICE_ID" ]]; then
    flutter_build_args+=(
      "--dart-define=DEBUG_DEVICE_ID=$RESOLVED_DEBUG_DEVICE_ID"
    )
  fi

  phone_serial="$(find_connected_phone)"

  if [[ "$SYNCED_TARGET_LOCAL_PROPERTIES" == true ]]; then
    printf 'Synchronized release signing and runtime config into %s.\n' "$TARGET_LOCAL_PROPERTIES_PATH"
  else
    printf 'Using release signing and runtime config from %s.\n' "$SOURCE_LOCAL_PROPERTIES_PATH"
  fi
  printf 'Building Flutter release APK...\n'
  prepare_apk_output "$RELEASE_APK_PATH"
  env \
    "$RELEASE_KEYSTORE_PASSWORD_ENV=$RESOLVED_KEYSTORE_PASSWORD" \
    "$RELEASE_KEY_PASSWORD_ENV=$RESOLVED_KEY_PASSWORD" \
    flutter build apk --release "${flutter_build_args[@]}"
  verify_built_apk "$RELEASE_APK_PATH" "release APK"

  printf 'Stopping any stale Flutter release app task before install...\n'
  force_stop_package "$phone_serial" "$FLUTTER_PACKAGE"

  if package_installed "$phone_serial" "$NATIVE_WRAIT_PACKAGE"; then
    native_wrait_was_installed=true
    printf 'Detected existing native Wrait app (%s); it will be left installed.\n' "$NATIVE_WRAIT_PACKAGE"
  else
    printf 'Native Wrait app (%s) was not installed before deployment.\n' "$NATIVE_WRAIT_PACKAGE"
  fi

  if package_installed "$phone_serial" "$DEBUG_FLUTTER_PACKAGE"; then
    debug_flutter_was_installed=true
    printf 'Detected existing debug Flutter app (%s); it must remain installed.\n' "$DEBUG_FLUTTER_PACKAGE"
  fi

  ensure_phone_connected "$phone_serial"
  printf 'Installing release APK on %s...\n' "$phone_serial"
  install_release_apk "$phone_serial" "$RELEASE_APK_PATH"

  package_installed "$phone_serial" "$FLUTTER_PACKAGE" || fail "$FLUTTER_PACKAGE was not found after install"

  if [[ "$native_wrait_was_installed" == true ]]; then
    package_installed "$phone_serial" "$NATIVE_WRAIT_PACKAGE" || fail \
      "$NATIVE_WRAIT_PACKAGE was installed before deployment but is missing after install"
    printf 'Verified %s remains installed.\n' "$NATIVE_WRAIT_PACKAGE"
  fi

  if [[ "$debug_flutter_was_installed" == true ]]; then
    package_installed "$phone_serial" "$DEBUG_FLUTTER_PACKAGE" || fail \
      "$DEBUG_FLUTTER_PACKAGE was installed before deployment but is missing after install"
    printf 'Verified %s remains installed.\n' "$DEBUG_FLUTTER_PACKAGE"
  fi

  printf 'Stopping Flutter release app before final launch verification...\n'
  force_stop_package "$phone_serial" "$FLUTTER_PACKAGE"
  printf 'Launching %s on %s...\n' "$FLUTTER_PACKAGE" "$phone_serial"
  launch_flutter_app "$phone_serial"

  printf 'Installed and launched %s on %s.\n' "$FLUTTER_PACKAGE" "$phone_serial"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

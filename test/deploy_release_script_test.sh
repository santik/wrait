#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$file" || fail "expected '$expected' in $file"
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fq -- "$unexpected" "$file"; then
    fail "did not expect '$unexpected' in $file"
  fi
}

assert_file_contains_line() {
  local file="$1"
  local expected="$2"
  grep -Fxq -- "$expected" "$file" || fail "expected line '$expected' in $file"
}

write_fakes() {
  mkdir -p "$TMP_DIR/bin"
  mkdir -p "$TMP_DIR/fake-java/bin"

  cat >"$TMP_DIR/bin/adb" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  devices)
    printf 'List of devices attached\n'
    case "${DEPLOY_TEST_SCENARIO:-}" in
      no_phone)
        ;;
      emulator_only)
        printf 'emulator-5554\tdevice\n'
        ;;
      unauthorized_phone)
        printf 'PHONE123\tunauthorized\n'
        ;;
      offline_phone)
        printf 'PHONE123\toffline\n'
        ;;
      disconnect_before_install|adb_failure|one_phone|native_absent|native_removed_after_install|debug_removed_after_install|build_no_apk|zero_size_apk|launch_timeout|install_update_incompatible)
        if [[ "${DEPLOY_TEST_SCENARIO:-}" == "adb_failure" ]]; then
          printf 'adb failed\n' >&2
          exit 1
        fi
        printf 'PHONE123\tdevice\n'
        ;;
      *)
        printf 'PHONE123\tdevice\n'
        ;;
    esac
    ;;
  -s)
    printf 'adb %s\n' "$*" >>"$DEPLOY_TEST_LOG"
    if [[ "${3:-}" == "get-state" ]]; then
      if [[ "${DEPLOY_TEST_SCENARIO:-}" == "disconnect_before_install" && -f "$DEPLOY_TEST_STATE_DIR/build-complete" ]]; then
        printf 'offline\n'
      else
        printf 'device\n'
      fi
      exit 0
    fi
    if [[ "${3:-}" == "shell" && "${4:-}" == "pm" && "${5:-}" == "path" ]]; then
      package_name="${6:-}"
      install_marker="$DEPLOY_TEST_STATE_DIR/install-complete"
      case "$package_name" in
        com.wrait.app)
          if [[ "${DEPLOY_TEST_SCENARIO:-}" == "native_absent" ]]; then
            exit 1
          fi
          if [[ "${DEPLOY_TEST_SCENARIO:-}" == "native_removed_after_install" && -f "$install_marker" ]]; then
            exit 1
          fi
          printf 'package:/data/app/com.wrait.app/base.apk\n'
          ;;
        com.wrait.flutter)
          [[ -f "$install_marker" ]] || exit 1
          printf 'package:/data/app/com.wrait.flutter/base.apk\n'
          ;;
        com.wrait.flutter.dev)
          if [[ -f "$DEPLOY_TEST_STATE_DIR/debug-present" ]]; then
            if [[ "${DEPLOY_TEST_SCENARIO:-}" == "debug_removed_after_install" && -f "$install_marker" ]]; then
              exit 1
            fi
            printf 'package:/data/app/com.wrait.flutter.dev/base.apk\n'
          else
            exit 1
          fi
          ;;
        *)
          exit 1
          ;;
      esac
      exit 0
    fi
    if [[ "${3:-}" == "shell" && "${4:-}" == "dumpsys" && "${5:-}" == "activity" && "${6:-}" == "activities" ]]; then
      if [[ "${DEPLOY_TEST_SCENARIO:-}" == "launch_timeout" ]]; then
        cat <<'EOT'
ResumedActivity: ActivityRecord{123 u0 com.example.other/.OtherActivity t1}
EOT
      else
        cat <<'EOT'
ResumedActivity: ActivityRecord{123 u0 com.wrait.flutter/com.wrait.flutter.MainActivity t1}
EOT
      fi
      exit 0
    fi
    if [[ "${3:-}" == "shell" && "${4:-}" == "dumpsys" && "${5:-}" == "window" ]]; then
      if [[ "${DEPLOY_TEST_SCENARIO:-}" == "launch_timeout" ]]; then
        cat <<'EOT'
mCurrentFocus=Window{123 u0 com.example.other/.OtherActivity}
EOT
      else
        cat <<'EOT'
mCurrentFocus=Window{123 u0 com.wrait.flutter/com.wrait.flutter.MainActivity}
EOT
      fi
      exit 0
    fi
    if [[ "${3:-}" == "shell" && "${4:-}" == "am" && "${5:-}" == "start" && "${6:-}" == "-W" ]]; then
      if [[ "${DEPLOY_TEST_SCENARIO:-}" == "launch_timeout" ]]; then
        cat <<'EOT'
Starting: Intent { cmp=com.wrait.flutter/com.wrait.flutter.MainActivity }
Warning: Activity not started, its current task has been brought to the front
Status: timeout
LaunchState: UNKNOWN (-1)
Activity: com.wrait.flutter/com.wrait.flutter.MainActivity
WaitTime: 10034
Complete
EOT
      else
        cat <<'EOT'
Starting: Intent { cmp=com.wrait.flutter/com.wrait.flutter.MainActivity }
Status: ok
LaunchState: UNKNOWN (0)
Activity: com.wrait.flutter/com.wrait.flutter.MainActivity
WaitTime: 3026
Complete
EOT
      fi
      exit 0
    fi
    if [[ "${4:-}" == "install" || "${3:-}" == "install" ]]; then
      if [[ "${DEPLOY_TEST_SCENARIO:-}" == "install_update_incompatible" ]]; then
        printf 'Performing Streamed Install\n' >&2
        printf 'adb: failed to install %s: Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE: Existing package com.wrait.flutter signatures do not match newer version; ignoring!]\n' "${@: -1}" >&2
        exit 1
      fi
      mkdir -p "$DEPLOY_TEST_STATE_DIR"
      touch "$DEPLOY_TEST_STATE_DIR/install-complete"
      exit 0
    fi
    ;;
  *)
    printf 'adb %s\n' "$*" >>"$DEPLOY_TEST_LOG"
    ;;
esac
EOF

  cat >"$TMP_DIR/bin/flutter" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'flutter %s\n' "$*" >>"$DEPLOY_TEST_LOG"

case "$*" in
  build\ apk\ --release*)
    [[ -n "${WRAIT_RELEASE_KEYSTORE_PASSWORD:-}" ]] || {
      printf 'missing WRAIT_RELEASE_KEYSTORE_PASSWORD\n' >&2
      exit 1
    }
    [[ -n "${WRAIT_RELEASE_KEY_PASSWORD:-}" ]] || {
      printf 'missing WRAIT_RELEASE_KEY_PASSWORD\n' >&2
      exit 1
    }
    mkdir -p "$DEPLOY_TEST_STATE_DIR"
    touch "$DEPLOY_TEST_STATE_DIR/build-complete"
    case "${DEPLOY_TEST_SCENARIO:-}" in
      build_no_apk)
        ;;
      zero_size_apk)
        mkdir -p "$(dirname "$DEPLOY_TEST_RELEASE_APK_PATH")"
        : >"$DEPLOY_TEST_RELEASE_APK_PATH"
        ;;
      *)
        mkdir -p "$(dirname "$DEPLOY_TEST_RELEASE_APK_PATH")"
        printf 'fake release apk\n' >"$DEPLOY_TEST_RELEASE_APK_PATH"
        ;;
    esac
    ;;
esac
EOF

  cat >"$TMP_DIR/bin/keytool" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

subcommand="${1:-}"
shift || true

redacted_args=()
while (($# > 0)); do
  case "$1" in
    -storepass|-keypass)
      redacted_args+=("$1" "<redacted>")
      shift 2
      ;;
    *)
      redacted_args+=("$1")
      shift
      ;;
  esac
done

printf 'keytool %s %s\n' "$subcommand" "${redacted_args[*]}" >>"$DEPLOY_TEST_LOG"

case "${DEPLOY_TEST_SCENARIO:-}" in
  invalid_keystore_password)
    [[ "$subcommand" == "-list" ]] && exit 1
    ;;
  invalid_key_password)
    [[ "$subcommand" == "-certreq" ]] && exit 1
    ;;
esac

if [[ "$subcommand" == "-certreq" ]]; then
  output_file=""
  for ((i = 0; i < ${#redacted_args[@]}; i += 1)); do
    case "${redacted_args[i]}" in
      -file)
        output_file="${redacted_args[i + 1]:-}"
        ;;
    esac
  done

  if [[ -n "$output_file" ]]; then
    printf 'fake csr\n' >"$output_file"
  fi
fi
EOF

  chmod +x "$TMP_DIR/bin/adb" "$TMP_DIR/bin/flutter" "$TMP_DIR/bin/keytool"
  cp "$TMP_DIR/bin/keytool" "$TMP_DIR/fake-java/bin/keytool"
}

write_default_source_config() {
  local source_path="$1"

  cat >"$source_path" <<EOF
sdk.dir=/tmp/ignored-sdk
KEYSTORE_PATH=release-key.jks
KEYSTORE_PASSWORD=release-keystore-password
KEY_ALIAS=release-key-alias
KEY_PASSWORD=release-key-password
BACKEND_URL=https://release.example.test
PROXY_SECRET=release-proxy-secret
RECORDING_HARD_CAP_MS=180000
WIREDASH_PROJECT_ID=release-wiredash-project
WIREDASH_SECRET=release-wiredash-secret
WIREDASH_ENVIRONMENT=production
EOF
}

write_default_target_config() {
  local target_path="$1"

  cat >"$target_path" <<'EOF'
sdk.dir=/tmp/android-sdk
flutter.sdk=/tmp/flutter-sdk
flutter.buildMode=release
flutter.versionName=1.0.0
flutter.versionCode=1
EXISTING_KEY=keep-me
KEYSTORE_PATH=stale-path
PROXY_SECRET=stale-secret
WIREDASH_SECRET=stale-wiredash-secret
WRAIT_RELEASE_KEYSTORE_PASSWORD=stale-release-keystore-password
WRAIT_RELEASE_KEY_PASSWORD=stale-release-key-password
EOF
}

prepare_config_files() {
  local scenario_dir="$1"
  local source_dir="$scenario_dir/private-config"
  local target_dir="$scenario_dir/android"

  mkdir -p "$source_dir" "$target_dir"
  write_default_source_config "$source_dir/local.properties"
  write_default_target_config "$target_dir/local.properties"
  printf 'fake keystore\n' >"$source_dir/release-key.jks"
}

run_script() {
  local scenario="$1"
  local scenario_dir="$TMP_DIR/$scenario"
  local output="$TMP_DIR/$scenario.out"
  local log="$TMP_DIR/$scenario.log"
  local release_apk_path="$scenario_dir/app-release.apk"
  local state_dir="$scenario_dir/state"
  local source_path="$scenario_dir/private-config/local.properties"
  local target_path="$scenario_dir/android/local.properties"
  : >"$log"

  prepare_config_files "$scenario_dir"

  case "$scenario" in
    missing_source_config)
      rm -f "$source_path"
      ;;
    unreadable_source_config)
      chmod 000 "$source_path"
      ;;
    missing_target_config_dir)
      rm -rf "$scenario_dir/android"
      target_path="$scenario_dir/android/local.properties"
      ;;
    missing_keystore_path)
      cat >"$source_path" <<'EOF'
KEYSTORE_PASSWORD=release-keystore-password
KEY_ALIAS=release-key-alias
KEY_PASSWORD=release-key-password
BACKEND_URL=https://release.example.test
PROXY_SECRET=release-proxy-secret
RECORDING_HARD_CAP_MS=180000
WIREDASH_PROJECT_ID=release-wiredash-project
WIREDASH_SECRET=release-wiredash-secret
WIREDASH_ENVIRONMENT=production
EOF
      ;;
    blank_key_alias)
      cat >"$source_path" <<'EOF'
KEYSTORE_PATH=release-key.jks
KEYSTORE_PASSWORD=release-keystore-password
KEY_ALIAS=
KEY_PASSWORD=release-key-password
BACKEND_URL=https://release.example.test
PROXY_SECRET=release-proxy-secret
RECORDING_HARD_CAP_MS=180000
WIREDASH_PROJECT_ID=release-wiredash-project
WIREDASH_SECRET=release-wiredash-secret
WIREDASH_ENVIRONMENT=production
EOF
      ;;
    invalid_backend_url)
      cat >"$source_path" <<'EOF'
KEYSTORE_PATH=release-key.jks
KEYSTORE_PASSWORD=release-keystore-password
KEY_ALIAS=release-key-alias
KEY_PASSWORD=release-key-password
BACKEND_URL=not-a-url
PROXY_SECRET=release-proxy-secret
RECORDING_HARD_CAP_MS=180000
WIREDASH_PROJECT_ID=release-wiredash-project
WIREDASH_SECRET=release-wiredash-secret
WIREDASH_ENVIRONMENT=production
EOF
      ;;
    blank_proxy_secret)
      cat >"$source_path" <<'EOF'
KEYSTORE_PATH=release-key.jks
KEYSTORE_PASSWORD=release-keystore-password
KEY_ALIAS=release-key-alias
KEY_PASSWORD=release-key-password
BACKEND_URL=https://release.example.test
PROXY_SECRET=
RECORDING_HARD_CAP_MS=180000
WIREDASH_PROJECT_ID=release-wiredash-project
WIREDASH_SECRET=release-wiredash-secret
WIREDASH_ENVIRONMENT=production
EOF
      ;;
    invalid_recording_cap)
      cat >"$source_path" <<'EOF'
KEYSTORE_PATH=release-key.jks
KEYSTORE_PASSWORD=release-keystore-password
KEY_ALIAS=release-key-alias
KEY_PASSWORD=release-key-password
BACKEND_URL=https://release.example.test
PROXY_SECRET=release-proxy-secret
RECORDING_HARD_CAP_MS=0
WIREDASH_PROJECT_ID=release-wiredash-project
WIREDASH_SECRET=release-wiredash-secret
WIREDASH_ENVIRONMENT=production
EOF
      ;;
    missing_wiredash_project)
      sed -i.bak '/^WIREDASH_PROJECT_ID=/d' "$source_path"
      rm -f "$source_path.bak"
      ;;
    blank_wiredash_secret)
      sed -i.bak 's/^WIREDASH_SECRET=.*/WIREDASH_SECRET=/' "$source_path"
      rm -f "$source_path.bak"
      ;;
    invalid_wiredash_project)
      sed -i.bak 's/^WIREDASH_PROJECT_ID=.*/WIREDASH_PROJECT_ID=../' "$source_path"
      rm -f "$source_path.bak"
      ;;
    invalid_wiredash_secret)
      sed -i.bak 's/^WIREDASH_SECRET=.*/WIREDASH_SECRET=short/' "$source_path"
      rm -f "$source_path.bak"
      ;;
    invalid_wiredash_environment)
      sed -i.bak 's/^WIREDASH_ENVIRONMENT=.*/WIREDASH_ENVIRONMENT=../' "$source_path"
      rm -f "$source_path.bak"
      ;;
    invalid_keystore_password|invalid_key_password)
      ;;
    wrait_password_property)
      sed -i.bak \
        -e 's/^KEYSTORE_PASSWORD=.*/WRAIT_RELEASE_KEYSTORE_PASSWORD=release-keystore-password/' \
        -e 's/^KEY_PASSWORD=.*/WRAIT_RELEASE_KEY_PASSWORD=release-key-password/' \
        "$source_path"
      rm -f "$source_path.bak"
      ;;
    same_file_config)
      source_path="$target_path"
      write_default_source_config "$source_path"
      printf 'fake keystore\n' >"$scenario_dir/android/release-key.jks"
      ;;
    missing_keystore_file)
      rm -f "$scenario_dir/private-config/release-key.jks"
      ;;
    one_phone|debug_removed_after_install)
      mkdir -p "$state_dir"
      touch "$state_dir/debug-present"
      ;;
  esac

  (
    cd "$ROOT_DIR"
    PATH="$TMP_DIR/bin:$PATH" \
      JAVA_HOME="$TMP_DIR/fake-java" \
      DEPLOY_TEST_SCENARIO="$scenario" \
      DEPLOY_TEST_LOG="$log" \
      DEPLOY_TEST_RELEASE_APK_PATH="$release_apk_path" \
      DEPLOY_TEST_STATE_DIR="$state_dir" \
      DEPLOY_RELEASE_APK_PATH="$release_apk_path" \
      DEPLOY_RELEASE_SOURCE_LOCAL_PROPERTIES_PATH="$source_path" \
      DEPLOY_RELEASE_TARGET_LOCAL_PROPERTIES_PATH="$target_path" \
      ./deploy_release.sh
  ) >"$output" 2>&1
}

run_script_expect_failure() {
  local scenario="$1"
  if run_script "$scenario"; then
    fail "expected $scenario to fail"
  fi
}

run_script_expect_success() {
  local scenario="$1"
  run_script "$scenario" || fail "expected $scenario to succeed"
}

write_fakes

if grep -Eq '(^|[[:space:]])(adb|flutter)[[:space:]].*\buninstall\b' "$ROOT_DIR/deploy_release.sh"; then
  fail "deploy_release.sh must never uninstall any package"
fi

if grep -Eq '(^|[[:space:]])adb[[:space:]].*\b(pm[[:space:]]+clear|cmd[[:space:]]+package[[:space:]]+clear)\b' "$ROOT_DIR/deploy_release.sh"; then
  fail "deploy_release.sh must never clear package data"
fi

run_script_expect_failure missing_source_config
assert_contains "$TMP_DIR/missing_source_config.out" "private source config is missing"
assert_not_contains "$TMP_DIR/missing_source_config.log" "flutter build"
assert_not_contains "$TMP_DIR/missing_source_config.log" "install"

run_script_expect_failure unreadable_source_config
assert_contains "$TMP_DIR/unreadable_source_config.out" "private source config is not readable"
assert_not_contains "$TMP_DIR/unreadable_source_config.log" "flutter build"
assert_not_contains "$TMP_DIR/unreadable_source_config.log" "install"

run_script_expect_failure missing_target_config_dir
assert_contains "$TMP_DIR/missing_target_config_dir.out" "Flutter app-local config directory is missing"
assert_not_contains "$TMP_DIR/missing_target_config_dir.log" "flutter build"
assert_not_contains "$TMP_DIR/missing_target_config_dir.log" "install"

run_script_expect_failure missing_keystore_path
assert_contains "$TMP_DIR/missing_keystore_path.out" "KEYSTORE_PATH is missing or blank"
assert_not_contains "$TMP_DIR/missing_keystore_path.log" "flutter build"

run_script_expect_failure blank_key_alias
assert_contains "$TMP_DIR/blank_key_alias.out" "KEY_ALIAS is missing or blank"
assert_not_contains "$TMP_DIR/blank_key_alias.log" "flutter build"

run_script_expect_failure invalid_backend_url
assert_contains "$TMP_DIR/invalid_backend_url.out" "BACKEND_URL must be an absolute http or https URL"
assert_not_contains "$TMP_DIR/invalid_backend_url.log" "flutter build"

run_script_expect_failure blank_proxy_secret
assert_contains "$TMP_DIR/blank_proxy_secret.out" "PROXY_SECRET is missing or blank"
assert_not_contains "$TMP_DIR/blank_proxy_secret.log" "flutter build"

run_script_expect_failure invalid_recording_cap
assert_contains "$TMP_DIR/invalid_recording_cap.out" "RECORDING_HARD_CAP_MS must be a positive integer"
assert_not_contains "$TMP_DIR/invalid_recording_cap.log" "flutter build"

run_script_expect_failure missing_wiredash_project
assert_contains "$TMP_DIR/missing_wiredash_project.out" \
  "WIREDASH_PROJECT_ID is missing or blank"
assert_not_contains "$TMP_DIR/missing_wiredash_project.log" "flutter build"

run_script_expect_failure blank_wiredash_secret
assert_contains "$TMP_DIR/blank_wiredash_secret.out" \
  "WIREDASH_SECRET is missing or blank"
assert_not_contains "$TMP_DIR/blank_wiredash_secret.log" "flutter build"

run_script_expect_failure invalid_wiredash_project
assert_contains "$TMP_DIR/invalid_wiredash_project.out" \
  "WIREDASH_PROJECT_ID must be 3-128 characters"
assert_not_contains "$TMP_DIR/invalid_wiredash_project.log" "flutter build"

run_script_expect_failure invalid_wiredash_secret
assert_contains "$TMP_DIR/invalid_wiredash_secret.out" \
  "WIREDASH_SECRET must be at least 8 characters long"
assert_not_contains "$TMP_DIR/invalid_wiredash_secret.log" "flutter build"

run_script_expect_failure invalid_wiredash_environment
assert_contains "$TMP_DIR/invalid_wiredash_environment.out" \
  "WIREDASH_ENVIRONMENT must be 1-64 characters"
assert_not_contains "$TMP_DIR/invalid_wiredash_environment.log" "flutter build"

run_script_expect_failure missing_keystore_file
assert_contains "$TMP_DIR/missing_keystore_file.out" "KEYSTORE_PATH does not point to a file reachable"
assert_not_contains "$TMP_DIR/missing_keystore_file.log" "flutter build"

run_script_expect_failure invalid_keystore_password
assert_contains "$TMP_DIR/invalid_keystore_password.out" "release keystore validation failed"
assert_not_contains "$TMP_DIR/invalid_keystore_password.log" "flutter build"

run_script_expect_failure invalid_key_password
assert_contains "$TMP_DIR/invalid_key_password.out" "release key validation failed"
assert_not_contains "$TMP_DIR/invalid_key_password.log" "flutter build"

run_script_expect_failure adb_failure
assert_contains "$TMP_DIR/adb_failure.out" "adb devices failed"
assert_not_contains "$TMP_DIR/adb_failure.log" "install"

run_script_expect_failure no_phone
assert_contains "$TMP_DIR/no_phone.out" "no connected Android phone found"
assert_not_contains "$TMP_DIR/no_phone.log" "install"

run_script_expect_failure emulator_only
assert_contains "$TMP_DIR/emulator_only.out" "no connected Android phone found"
assert_not_contains "$TMP_DIR/emulator_only.log" "install"

run_script_expect_failure unauthorized_phone
assert_contains "$TMP_DIR/unauthorized_phone.out" "Android phone is connected but unavailable"
assert_contains "$TMP_DIR/unauthorized_phone.out" "PHONE123 unauthorized"
assert_not_contains "$TMP_DIR/unauthorized_phone.log" "install"

run_script_expect_failure offline_phone
assert_contains "$TMP_DIR/offline_phone.out" "Android phone is connected but unavailable"
assert_contains "$TMP_DIR/offline_phone.out" "PHONE123 offline"
assert_not_contains "$TMP_DIR/offline_phone.log" "install"

run_script_expect_failure build_no_apk
assert_contains "$TMP_DIR/build_no_apk.out" "release APK was not created"
assert_contains "$TMP_DIR/build_no_apk.log" "flutter build apk --release --dart-define=BACKEND_URL=https://release.example.test --dart-define=PROXY_SECRET=release-proxy-secret --dart-define=RECORDING_HARD_CAP_MS=180000"
assert_contains "$TMP_DIR/build_no_apk.log" "--dart-define=WIREDASH_PROJECT_ID=release-wiredash-project --dart-define=WIREDASH_SECRET=release-wiredash-secret --dart-define=WIREDASH_ENVIRONMENT=production"
assert_not_contains "$TMP_DIR/build_no_apk.log" "install"

run_script_expect_failure zero_size_apk
assert_contains "$TMP_DIR/zero_size_apk.out" "release APK at $TMP_DIR/zero_size_apk/app-release.apk is empty"
assert_not_contains "$TMP_DIR/zero_size_apk.log" "install"

run_script_expect_failure disconnect_before_install
assert_contains "$TMP_DIR/disconnect_before_install.out" "Android phone PHONE123 is no longer connected and ready"
assert_not_contains "$TMP_DIR/disconnect_before_install.log" "adb -s PHONE123 install -r"

run_script_expect_failure launch_timeout
assert_contains "$TMP_DIR/launch_timeout.out" "com.wrait.flutter launch timed out after install and foreground verification failed"
assert_contains "$TMP_DIR/launch_timeout.log" "adb -s PHONE123 shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity"
assert_contains "$TMP_DIR/launch_timeout.log" "adb -s PHONE123 shell dumpsys activity activities"

run_script_expect_failure install_update_incompatible
assert_contains "$TMP_DIR/install_update_incompatible.out" "existing com.wrait.flutter on PHONE123 is signed with a different key than this release build"
assert_contains "$TMP_DIR/install_update_incompatible.out" "verify KEYSTORE_PATH/KEY_ALIAS"
assert_contains "$TMP_DIR/install_update_incompatible.log" "adb -s PHONE123 install -r $TMP_DIR/install_update_incompatible/app-release.apk"

run_script_expect_failure native_removed_after_install
assert_contains "$TMP_DIR/native_removed_after_install.out" "com.wrait.app was installed before deployment but is missing after install"
assert_contains "$TMP_DIR/native_removed_after_install.log" "adb -s PHONE123 install -r $TMP_DIR/native_removed_after_install/app-release.apk"

run_script_expect_failure debug_removed_after_install
assert_contains "$TMP_DIR/debug_removed_after_install.out" "com.wrait.flutter.dev was installed before deployment but is missing after install"
assert_contains "$TMP_DIR/debug_removed_after_install.log" "adb -s PHONE123 install -r $TMP_DIR/debug_removed_after_install/app-release.apk"

run_script_expect_success native_absent
assert_contains "$TMP_DIR/native_absent.out" "Native Wrait app (com.wrait.app) was not installed before deployment."
assert_contains "$TMP_DIR/native_absent.out" "Installed and launched com.wrait.flutter on PHONE123."

run_script_expect_success wrait_password_property
assert_contains "$TMP_DIR/wrait_password_property.out" "Synchronized release signing and runtime config into $TMP_DIR/wrait_password_property/android/local.properties."
assert_contains "$TMP_DIR/wrait_password_property.log" "flutter build apk --release --dart-define=BACKEND_URL=https://release.example.test --dart-define=PROXY_SECRET=release-proxy-secret"
assert_not_contains "$TMP_DIR/wrait_password_property/android/local.properties" "WRAIT_RELEASE_KEYSTORE_PASSWORD="
assert_not_contains "$TMP_DIR/wrait_password_property/android/local.properties" "WRAIT_RELEASE_KEY_PASSWORD="

run_script_expect_success same_file_config
assert_contains "$TMP_DIR/same_file_config.out" "Using release signing and runtime config from $TMP_DIR/same_file_config/android/local.properties."
assert_contains "$TMP_DIR/same_file_config.log" "flutter build apk --release --dart-define=BACKEND_URL=https://release.example.test --dart-define=PROXY_SECRET=release-proxy-secret"
assert_file_contains_line "$TMP_DIR/same_file_config/android/local.properties" "KEYSTORE_PASSWORD=release-keystore-password"
assert_file_contains_line "$TMP_DIR/same_file_config/android/local.properties" "KEY_PASSWORD=release-key-password"

run_script_expect_success one_phone
assert_contains "$TMP_DIR/one_phone.out" "Synchronized release signing and runtime config into $TMP_DIR/one_phone/android/local.properties."
assert_contains "$TMP_DIR/one_phone.out" "Detected existing native Wrait app (com.wrait.app); it will be left installed."
assert_contains "$TMP_DIR/one_phone.out" "Verified com.wrait.app remains installed."
assert_contains "$TMP_DIR/one_phone.out" "Detected existing debug Flutter app (com.wrait.flutter.dev); it must remain installed."
assert_contains "$TMP_DIR/one_phone.out" "Verified com.wrait.flutter.dev remains installed."
assert_contains "$TMP_DIR/one_phone.out" "Installed and launched com.wrait.flutter on PHONE123."
assert_contains "$TMP_DIR/one_phone.log" "flutter build apk --release --dart-define=BACKEND_URL=https://release.example.test --dart-define=PROXY_SECRET=release-proxy-secret --dart-define=RECORDING_HARD_CAP_MS=180000 --dart-define=WIREDASH_PROJECT_ID=release-wiredash-project --dart-define=WIREDASH_SECRET=release-wiredash-secret --dart-define=WIREDASH_ENVIRONMENT=production"
assert_contains "$TMP_DIR/one_phone.log" "keytool -list -keystore $TMP_DIR/one_phone/private-config/release-key.jks -storepass <redacted> -alias release-key-alias"
assert_contains "$TMP_DIR/one_phone.log" "keytool -certreq -keystore $TMP_DIR/one_phone/private-config/release-key.jks -storepass <redacted> -alias release-key-alias -keypass <redacted>"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell am force-stop com.wrait.flutter"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell pm path com.wrait.app"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 install -r $TMP_DIR/one_phone/app-release.apk"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell pm path com.wrait.flutter"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell pm path com.wrait.flutter.dev"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity"
assert_not_contains "$TMP_DIR/one_phone.log" "flutter test --no-pub"
assert_not_contains "$TMP_DIR/one_phone.log" "release-keystore-password"
assert_not_contains "$TMP_DIR/one_phone.log" "release-key-password"
assert_not_contains "$TMP_DIR/one_phone.out" "release-wiredash-secret"
assert_file_contains_line "$TMP_DIR/one_phone/android/local.properties" "sdk.dir=/tmp/android-sdk"
assert_file_contains_line "$TMP_DIR/one_phone/android/local.properties" "flutter.sdk=/tmp/flutter-sdk"
assert_file_contains_line "$TMP_DIR/one_phone/android/local.properties" "flutter.buildMode=release"
assert_file_contains_line "$TMP_DIR/one_phone/android/local.properties" "flutter.versionName=1.0.0"
assert_file_contains_line "$TMP_DIR/one_phone/android/local.properties" "flutter.versionCode=1"
assert_file_contains_line "$TMP_DIR/one_phone/android/local.properties" "EXISTING_KEY=keep-me"
assert_file_contains_line "$TMP_DIR/one_phone/android/local.properties" "KEYSTORE_PATH=$TMP_DIR/one_phone/private-config/release-key.jks"
assert_file_contains_line "$TMP_DIR/one_phone/android/local.properties" "KEY_ALIAS=release-key-alias"
assert_file_contains_line "$TMP_DIR/one_phone/android/local.properties" "BACKEND_URL=https://release.example.test"
assert_file_contains_line "$TMP_DIR/one_phone/android/local.properties" "PROXY_SECRET=release-proxy-secret"
assert_file_contains_line "$TMP_DIR/one_phone/android/local.properties" "RECORDING_HARD_CAP_MS=180000"
assert_file_contains_line "$TMP_DIR/one_phone/android/local.properties" "WIREDASH_PROJECT_ID=release-wiredash-project"
assert_file_contains_line "$TMP_DIR/one_phone/android/local.properties" "WIREDASH_ENVIRONMENT=production"
assert_not_contains "$TMP_DIR/one_phone/android/local.properties" "KEYSTORE_PATH=stale-path"
assert_not_contains "$TMP_DIR/one_phone/android/local.properties" "KEYSTORE_PASSWORD="
assert_not_contains "$TMP_DIR/one_phone/android/local.properties" "KEY_PASSWORD="
assert_not_contains "$TMP_DIR/one_phone/android/local.properties" "WRAIT_RELEASE_KEYSTORE_PASSWORD="
assert_not_contains "$TMP_DIR/one_phone/android/local.properties" "WRAIT_RELEASE_KEY_PASSWORD="
assert_not_contains "$TMP_DIR/one_phone/android/local.properties" "PROXY_SECRET=stale-secret"
assert_file_contains_line "$TMP_DIR/one_phone/android/local.properties" "WIREDASH_SECRET=release-wiredash-secret"

printf 'deploy_release_script_test.sh: all tests passed\n'

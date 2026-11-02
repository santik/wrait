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

assert_file_contents() {
  local file="$1"
  local expected="$2"
  [[ -f "$file" ]] || fail "expected file $file to exist"
  local actual
  actual="$(tr -d '\r\n' <"$file")"
  [[ "$actual" == "$expected" ]] || fail "expected $file to contain '$expected' but found '$actual'"
}

write_fakes() {
  mkdir -p "$TMP_DIR/bin"

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
      disconnect_before_install)
        printf 'PHONE123\tdevice\n'
        ;;
      adb_failure)
        printf 'adb failed\n' >&2
        exit 1
        ;;
      one_phone|one_phone_custom_state|locked_phone|keyguard_dismiss_refused|wake_failure|native_absent|native_removed_after_install|test_failure|build_no_apk|zero_size_apk|launch_timeout|wiredash_configured|partial_wiredash_config)
        printf 'PHONE123\tdevice\n'
        ;;
      *)
        printf 'unknown scenario: %s\n' "${DEPLOY_TEST_SCENARIO:-}" >&2
        exit 2
        ;;
    esac
    ;;
  -s)
    printf 'adb %s\n' "$*" >>"$DEPLOY_TEST_LOG"
    if [[ "${3:-}" == "get-state" ]]; then
      if [[ "${DEPLOY_TEST_SCENARIO:-}" == "disconnect_before_install" && -f "$DEPLOY_TEST_STATE_DIR/tests-complete" ]]; then
        printf 'offline\n'
      else
        printf 'device\n'
      fi
      exit 0
    fi
    if [[ "${3:-}" == "shell" && "${4:-}" == "settings" && "${5:-}" == "get" && "${6:-}" == "global" ]]; then
      setting_name="${7:-}"
      state_file="$DEPLOY_TEST_STATE_DIR/global-${setting_name}"
      if [[ -f "$state_file" ]]; then
        cat "$state_file"
      else
        case "$setting_name" in
          stay_on_while_plugged_in)
            printf '%s\n' "${DEPLOY_TEST_INITIAL_STAY_AWAKE_SETTING:-0}"
            ;;
          *)
            printf '%s\n' "${DEPLOY_TEST_INITIAL_AUTOMATION_LOCKSCREEN_MODE_SETTING:-0}"
            ;;
        esac
      fi
      exit 0
    fi
    if [[ "${3:-}" == "shell" && "${4:-}" == "settings" && "${5:-}" == "put" && "${6:-}" == "global" ]]; then
      setting_name="${7:-}"
      setting_value="${8:-}"
      mkdir -p "$DEPLOY_TEST_STATE_DIR"
      printf '%s\n' "$setting_value" >"$DEPLOY_TEST_STATE_DIR/global-${setting_name}"
      exit 0
    fi
    if [[ "${3:-}" == "shell" && "${4:-}" == "svc" && "${5:-}" == "power" && "${6:-}" == "stayon" ]]; then
      mkdir -p "$DEPLOY_TEST_STATE_DIR"
      printf '%s\n' "${7:-}" >"$DEPLOY_TEST_STATE_DIR/stay-awake-mode"
      exit 0
    fi
    if [[ "${3:-}" == "shell" && "${4:-}" == "pm" && "${5:-}" == "path" ]]; then
      package_name="${6:-}"
      install_marker="$DEPLOY_TEST_STATE_DIR/install-complete"
      test_install_marker="$DEPLOY_TEST_STATE_DIR/test-install-complete"
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
        com.wrait.flutter.dev)
          [[ -f "$install_marker" || -f "$test_install_marker" ]] || exit 1
          printf 'package:/data/app/com.wrait.flutter.dev/base.apk\n'
          ;;
        com.wrait.flutter.dev.test)
          [[ -f "$test_install_marker" ]] || exit 1
          printf 'package:/data/app/com.wrait.flutter.dev.test/base.apk\n'
          ;;
        *)
          exit 1
          ;;
      esac
      exit 0
    fi
    if [[ "${3:-}" == "shell" && "${4:-}" == "pm" && "${5:-}" == "grant" ]]; then
      package_name="${6:-}"
      permission_name="${7:-}"
      install_marker="$DEPLOY_TEST_STATE_DIR/install-complete"
      test_install_marker="$DEPLOY_TEST_STATE_DIR/test-install-complete"
      case "$package_name" in
        com.wrait.flutter.dev)
          [[ -f "$install_marker" || -f "$test_install_marker" ]] || exit 1
          ;;
        com.wrait.flutter.dev.test)
          [[ -f "$test_install_marker" ]] || exit 1
          ;;
        *)
          exit 1
          ;;
      esac
      [[ "$permission_name" == "android.permission.RECORD_AUDIO" ]] || exit 1
      touch "$DEPLOY_TEST_STATE_DIR/${package_name##*.}-record-audio-granted"
      exit 0
    fi
    if [[ "${3:-}" == "shell" && "${4:-}" == "appops" && "${5:-}" == "set" ]]; then
      package_name="${6:-}"
      app_op_name="${7:-}"
      app_op_state="${8:-}"
      [[ "$package_name" == "com.wrait.flutter.dev" || "$package_name" == "com.wrait.flutter.dev.test" ]] || exit 1
      [[ "$app_op_name" == "RECORD_AUDIO" ]] || exit 1
      [[ "$app_op_state" == "allow" ]] || exit 1
      touch "$DEPLOY_TEST_STATE_DIR/${package_name##*.}-record-audio-appops-allow"
      exit 0
    fi
    if [[ "${3:-}" == "shell" && "${4:-}" == "input" && "${5:-}" == "keyevent" && "${6:-}" == "KEYCODE_WAKEUP" ]]; then
      if [[ "${DEPLOY_TEST_SCENARIO:-}" == "wake_failure" ]]; then
        printf 'wake failed\n' >&2
        exit 1
      fi
      exit 0
    fi
    if [[ "${3:-}" == "shell" && "${4:-}" == "wm" && "${5:-}" == "dismiss-keyguard" ]]; then
      if [[ "${DEPLOY_TEST_SCENARIO:-}" == "keyguard_dismiss_refused" ]]; then
        printf 'dismiss denied\n' >&2
        exit 1
      fi
      exit 0
    fi
    if [[ "${3:-}" == "shell" && "${4:-}" == "dumpsys" && "${5:-}" == "activity" && "${6:-}" == "activities" ]]; then
      if [[ "${DEPLOY_TEST_SCENARIO:-}" == "launch_timeout" ]]; then
        cat <<'EOT'
ResumedActivity: ActivityRecord{123 u0 com.example.other/.OtherActivity t1}
EOT
      else
        cat <<'EOT'
ResumedActivity: ActivityRecord{123 u0 com.wrait.flutter.dev/com.wrait.flutter.MainActivity t1}
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
mCurrentFocus=Window{123 u0 com.wrait.flutter.dev/com.wrait.flutter.MainActivity}
EOT
      fi
      exit 0
    fi
    if [[ "${3:-}" == "shell" && "${4:-}" == "am" && "${5:-}" == "start" && "${6:-}" == "-W" ]]; then
      if [[ "${DEPLOY_TEST_SCENARIO:-}" == "launch_timeout" ]]; then
        cat <<'EOT'
Starting: Intent { cmp=com.wrait.flutter.dev/com.wrait.flutter.MainActivity }
Warning: Activity not started, its current task has been brought to the front
Status: timeout
LaunchState: UNKNOWN (-1)
Activity: com.wrait.flutter.dev/com.wrait.flutter.MainActivity
WaitTime: 10034
Complete
EOT
      else
        cat <<'EOT'
Starting: Intent { cmp=com.wrait.flutter.dev/com.wrait.flutter.MainActivity }
Status: ok
LaunchState: UNKNOWN (0)
Activity: com.wrait.flutter.dev/com.wrait.flutter.MainActivity
WaitTime: 3026
Complete
EOT
      fi
      exit 0
    fi
    if [[ "${4:-}" == "install" || "${3:-}" == "install" ]]; then
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
  build\ apk\ --debug*)
    case "${DEPLOY_TEST_SCENARIO:-}" in
      build_no_apk)
        ;;
      zero_size_apk)
        mkdir -p "$(dirname "$DEPLOY_TEST_DEBUG_APK_PATH")"
        : >"$DEPLOY_TEST_DEBUG_APK_PATH"
        ;;
      *)
        mkdir -p "$(dirname "$DEPLOY_TEST_DEBUG_APK_PATH")"
        printf 'fake debug apk\n' >"$DEPLOY_TEST_DEBUG_APK_PATH"
        ;;
    esac
    ;;
  build\ apk\ --profile*)
    case "${DEPLOY_TEST_SCENARIO:-}" in
      build_no_apk)
        ;;
      zero_size_apk)
        mkdir -p "$(dirname "$DEPLOY_TEST_PROFILE_APK_PATH")"
        : >"$DEPLOY_TEST_PROFILE_APK_PATH"
        ;;
      *)
        mkdir -p "$(dirname "$DEPLOY_TEST_PROFILE_APK_PATH")"
        printf 'fake profile apk\n' >"$DEPLOY_TEST_PROFILE_APK_PATH"
        ;;
    esac
    ;;
  "test --no-pub -d PHONE123 integration_test")
    mkdir -p "$DEPLOY_TEST_STATE_DIR"
    touch "$DEPLOY_TEST_STATE_DIR/test-install-complete"
    if [[ "${DEPLOY_TEST_SCENARIO:-}" == "test_failure" ]]; then
      sleep 1.2
      exit 42
    fi
    touch "$DEPLOY_TEST_STATE_DIR/tests-complete"
    sleep 1.2
    ;;
esac
EOF

  chmod +x "$TMP_DIR/bin/adb" "$TMP_DIR/bin/flutter"
}

write_debug_config() {
  local config_path="$1"
  local proxy_secret="$2"
  local wiredash_project_id="${3:-}"
  local wiredash_secret="${4:-}"
  local wiredash_environment="${5:-}"

  mkdir -p "$(dirname "$config_path")"
  {
    printf 'PROXY_SECRET=%s\n' "$proxy_secret"
    if [[ -n "$wiredash_project_id" ]]; then
      printf 'WIREDASH_PROJECT_ID=%s\n' "$wiredash_project_id"
    fi
    if [[ -n "$wiredash_secret" ]]; then
      printf 'WIREDASH_SECRET=%s\n' "$wiredash_secret"
    fi
    if [[ -n "$wiredash_environment" ]]; then
      printf 'WIREDASH_ENVIRONMENT=%s\n' "$wiredash_environment"
    fi
  } >"$config_path"
}

run_script() {
  local scenario="$1"
  local initial_stay_awake_setting="${2:-0}"
  local initial_automation_setting="${3:-0}"
  local output="$TMP_DIR/$scenario.out"
  local log="$TMP_DIR/$scenario.log"
  local debug_apk_path="$TMP_DIR/$scenario/app-debug.apk"
  local profile_apk_path="$TMP_DIR/$scenario/app-profile.apk"
  local state_dir="$TMP_DIR/$scenario/state"
  local config_path="$TMP_DIR/$scenario/android/local.properties"
  local wiredash_project_id=""
  local wiredash_secret=""
  local wiredash_environment=""
  : >"$log"

  case "$scenario" in
    wiredash_configured)
      wiredash_project_id="test-wiredash-project"
      wiredash_secret="test-wiredash-secret"
      wiredash_environment="staging"
      ;;
    partial_wiredash_config)
      wiredash_project_id="test-wiredash-project"
      ;;
    invalid_wiredash_project)
      wiredash_project_id=".."
      wiredash_secret="test-wiredash-secret"
      wiredash_environment="staging"
      ;;
    invalid_wiredash_secret)
      wiredash_project_id="test-wiredash-project"
      wiredash_secret="short"
      wiredash_environment="staging"
      ;;
    invalid_wiredash_environment)
      wiredash_project_id="test-wiredash-project"
      wiredash_secret="test-wiredash-secret"
      wiredash_environment=".."
      ;;
  esac

  write_debug_config \
    "$config_path" \
    "test-proxy-secret" \
    "$wiredash_project_id" \
    "$wiredash_secret" \
    "$wiredash_environment"

  if [[ "$scenario" == "build_no_apk" ]]; then
    mkdir -p "$(dirname "$debug_apk_path")"
    printf 'stale apk\n' >"$debug_apk_path"
    mkdir -p "$(dirname "$profile_apk_path")"
    printf 'stale profile apk\n' >"$profile_apk_path"
  fi

  (
    cd "$ROOT_DIR"
    PATH="$TMP_DIR/bin:$PATH" \
      DEPLOY_TEST_SCENARIO="$scenario" \
      DEPLOY_TEST_LOG="$log" \
      DEPLOY_TEST_ROOT="$ROOT_DIR" \
      DEPLOY_TEST_INITIAL_STAY_AWAKE_SETTING="$initial_stay_awake_setting" \
      DEPLOY_TEST_INITIAL_AUTOMATION_LOCKSCREEN_MODE_SETTING="$initial_automation_setting" \
      DEPLOY_TEST_DEBUG_APK_PATH="$debug_apk_path" \
      DEPLOY_TEST_PROFILE_APK_PATH="$profile_apk_path" \
      DEPLOY_TEST_STATE_DIR="$state_dir" \
      DEPLOY_DEBUG_LOCAL_PROPERTIES_PATH="$config_path" \
      DEPLOY_DEBUG_APK_PATH="$debug_apk_path" \
      DEPLOY_PROFILE_APK_PATH="$profile_apk_path" \
      ./deploy_debug.sh
  ) >"$output" 2>&1
}

run_script_expect_failure() {
  local scenario="$1"
  shift
  if run_script "$scenario" "$@"; then
    fail "expected $scenario to fail"
  fi
}

run_script_expect_success() {
  local scenario="$1"
  shift
  run_script "$scenario" "$@" || fail "expected $scenario to succeed"
}

run_script_without_proxy_secret_expect_failure() {
  local output="$TMP_DIR/missing_proxy_secret.out"
  local log="$TMP_DIR/missing_proxy_secret.log"
  local debug_apk_path="$TMP_DIR/missing_proxy_secret/app-debug.apk"
  local profile_apk_path="$TMP_DIR/missing_proxy_secret/app-profile.apk"
  local state_dir="$TMP_DIR/missing_proxy_secret/state"
  local config_path="$TMP_DIR/missing_proxy_secret/android/local.properties"
  : >"$log"
  mkdir -p "$(dirname "$config_path")"
  printf 'WIREDASH_PROJECT_ID=test-wiredash-project\n' >"$config_path"

  if (
    cd "$ROOT_DIR"
    PATH="$TMP_DIR/bin:$PATH" \
      DEPLOY_TEST_SCENARIO="one_phone" \
      DEPLOY_TEST_LOG="$log" \
      DEPLOY_TEST_ROOT="$ROOT_DIR" \
      DEPLOY_TEST_DEBUG_APK_PATH="$debug_apk_path" \
      DEPLOY_TEST_PROFILE_APK_PATH="$profile_apk_path" \
      DEPLOY_TEST_STATE_DIR="$state_dir" \
      DEPLOY_DEBUG_LOCAL_PROPERTIES_PATH="$config_path" \
      DEPLOY_DEBUG_APK_PATH="$debug_apk_path" \
      DEPLOY_PROFILE_APK_PATH="$profile_apk_path" \
      ./deploy_debug.sh
  ) >"$output" 2>&1; then
    fail "expected missing_proxy_secret to fail"
  fi
}

run_script_with_proxy_secret_expect_failure() {
  local scenario="$1"
  local proxy_secret="$2"
  local output="$TMP_DIR/$scenario.out"
  local log="$TMP_DIR/$scenario.log"
  local debug_apk_path="$TMP_DIR/$scenario/app-debug.apk"
  local profile_apk_path="$TMP_DIR/$scenario/app-profile.apk"
  local state_dir="$TMP_DIR/$scenario/state"
  local config_path="$TMP_DIR/$scenario/android/local.properties"
  : >"$log"
  write_debug_config "$config_path" "$proxy_secret"

  if (
    cd "$ROOT_DIR"
    PATH="$TMP_DIR/bin:$PATH" \
      DEPLOY_TEST_SCENARIO="one_phone" \
      DEPLOY_TEST_LOG="$log" \
      DEPLOY_TEST_ROOT="$ROOT_DIR" \
      DEPLOY_TEST_DEBUG_APK_PATH="$debug_apk_path" \
      DEPLOY_TEST_PROFILE_APK_PATH="$profile_apk_path" \
      DEPLOY_TEST_STATE_DIR="$state_dir" \
      DEPLOY_DEBUG_LOCAL_PROPERTIES_PATH="$config_path" \
      DEPLOY_DEBUG_APK_PATH="$debug_apk_path" \
      DEPLOY_PROFILE_APK_PATH="$profile_apk_path" \
      ./deploy_debug.sh
  ) >"$output" 2>&1; then
    fail "expected $scenario to fail"
  fi
}

write_fakes

if grep -Eq '(^|[[:space:]])(adb|flutter)[[:space:]].*\buninstall\b' "$ROOT_DIR/deploy_debug.sh"; then
  fail "deploy_debug.sh must never uninstall any package"
fi

if grep -Eq '(^|[[:space:]])adb[[:space:]].*\b(pm[[:space:]]+clear|cmd[[:space:]]+package[[:space:]]+clear)\b' "$ROOT_DIR/deploy_debug.sh"; then
  fail "deploy_debug.sh must never clear package data"
fi

run_script_expect_failure no_phone
assert_contains "$TMP_DIR/no_phone.out" "no connected Android phone found"
assert_not_contains "$TMP_DIR/no_phone.log" "flutter build"
assert_not_contains "$TMP_DIR/no_phone.log" "install"

run_script_without_proxy_secret_expect_failure
assert_contains "$TMP_DIR/missing_proxy_secret.out" "PROXY_SECRET is missing or blank"
assert_not_contains "$TMP_DIR/missing_proxy_secret.log" "flutter build"
assert_not_contains "$TMP_DIR/missing_proxy_secret.log" "install"

run_script_with_proxy_secret_expect_failure short_proxy_secret "short"
assert_contains "$TMP_DIR/short_proxy_secret.out" "PROXY_SECRET must be at least 8 characters long"
assert_not_contains "$TMP_DIR/short_proxy_secret.log" "flutter build"

run_script_with_proxy_secret_expect_failure whitespace_proxy_secret "  secret value  "
assert_contains "$TMP_DIR/whitespace_proxy_secret.out" "PROXY_SECRET must not contain whitespace"
assert_not_contains "$TMP_DIR/whitespace_proxy_secret.log" "flutter build"

run_script_expect_failure partial_wiredash_config
assert_contains "$TMP_DIR/partial_wiredash_config.out" \
  "WIREDASH_PROJECT_ID and WIREDASH_SECRET must be supplied together"
assert_not_contains "$TMP_DIR/partial_wiredash_config.log" "flutter build"

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

run_script_expect_success wiredash_configured
assert_contains "$TMP_DIR/wiredash_configured.log" \
  "flutter build apk --debug --dart-define=PROXY_SECRET=test-proxy-secret --dart-define=WIREDASH_PROJECT_ID=test-wiredash-project --dart-define=WIREDASH_SECRET=test-wiredash-secret --dart-define=WIREDASH_ENVIRONMENT=staging"
assert_contains "$TMP_DIR/wiredash_configured.log" \
  "flutter build apk --profile --dart-define=PROXY_SECRET=test-proxy-secret --dart-define=WIREDASH_PROJECT_ID=test-wiredash-project --dart-define=WIREDASH_SECRET=test-wiredash-secret --dart-define=WIREDASH_ENVIRONMENT=staging"
assert_not_contains "$TMP_DIR/wiredash_configured.out" "test-wiredash-secret"

run_script_expect_failure adb_failure
assert_contains "$TMP_DIR/adb_failure.out" "adb devices failed"
assert_not_contains "$TMP_DIR/adb_failure.log" "flutter build"
assert_not_contains "$TMP_DIR/adb_failure.log" "install"

run_script_expect_failure emulator_only
assert_contains "$TMP_DIR/emulator_only.out" "no connected Android phone found"
assert_not_contains "$TMP_DIR/emulator_only.log" "flutter build"
assert_not_contains "$TMP_DIR/emulator_only.log" "install"

run_script_expect_failure unauthorized_phone
assert_contains "$TMP_DIR/unauthorized_phone.out" "Android phone is connected but unavailable"
assert_contains "$TMP_DIR/unauthorized_phone.out" "PHONE123 unauthorized"
assert_not_contains "$TMP_DIR/unauthorized_phone.log" "flutter build"
assert_not_contains "$TMP_DIR/unauthorized_phone.log" "install"

run_script_expect_failure offline_phone
assert_contains "$TMP_DIR/offline_phone.out" "Android phone is connected but unavailable"
assert_contains "$TMP_DIR/offline_phone.out" "PHONE123 offline"
assert_not_contains "$TMP_DIR/offline_phone.log" "flutter build"
assert_not_contains "$TMP_DIR/offline_phone.log" "install"

run_script_expect_failure test_failure
assert_contains "$TMP_DIR/test_failure.log" "flutter build apk --debug"
assert_contains "$TMP_DIR/test_failure.log" "adb -s PHONE123 shell svc power stayon usb"
assert_contains "$TMP_DIR/test_failure.log" "adb -s PHONE123 shell settings put global com.wrait.flutter.dev.automation_lockscreen_mode 1"
assert_contains "$TMP_DIR/test_failure.log" "adb -s PHONE123 shell input keyevent KEYCODE_WAKEUP"
assert_contains "$TMP_DIR/test_failure.log" "adb -s PHONE123 shell pm grant com.wrait.flutter.dev android.permission.RECORD_AUDIO"
assert_contains "$TMP_DIR/test_failure.log" "adb -s PHONE123 shell appops set com.wrait.flutter.dev RECORD_AUDIO allow"
assert_contains "$TMP_DIR/test_failure.log" "adb -s PHONE123 shell pm grant com.wrait.flutter.dev.test android.permission.RECORD_AUDIO"
assert_contains "$TMP_DIR/test_failure.log" "flutter test --no-pub -d PHONE123 integration_test"
assert_contains "$TMP_DIR/test_failure.log" "adb -s PHONE123 shell settings put global com.wrait.flutter.dev.automation_lockscreen_mode 0"
assert_contains "$TMP_DIR/test_failure.log" "adb -s PHONE123 shell svc power stayon false"
assert_file_contents "$TMP_DIR/test_failure/state/global-com.wrait.flutter.dev.automation_lockscreen_mode" "0"
assert_file_contents "$TMP_DIR/test_failure/state/stay-awake-mode" "false"
assert_not_contains "$TMP_DIR/test_failure.log" "install"

run_script_expect_failure build_no_apk
assert_contains "$TMP_DIR/build_no_apk.out" "debug APK was not created"
assert_not_contains "$TMP_DIR/build_no_apk.log" "install"

run_script_expect_failure zero_size_apk
assert_contains "$TMP_DIR/zero_size_apk.out" "debug APK at $TMP_DIR/zero_size_apk/app-debug.apk is empty"
assert_not_contains "$TMP_DIR/zero_size_apk.log" "install"

run_script_expect_failure wake_failure
assert_contains "$TMP_DIR/wake_failure.out" "failed to wake Android phone PHONE123 for Flutter integration tests"
assert_contains "$TMP_DIR/wake_failure.log" "adb -s PHONE123 shell input keyevent KEYCODE_WAKEUP"
assert_file_contents "$TMP_DIR/wake_failure/state/global-com.wrait.flutter.dev.automation_lockscreen_mode" "0"
assert_file_contents "$TMP_DIR/wake_failure/state/stay-awake-mode" "false"
assert_not_contains "$TMP_DIR/wake_failure.log" "flutter test --no-pub -d PHONE123 integration_test"
assert_not_contains "$TMP_DIR/wake_failure.log" "install"

run_script_expect_failure disconnect_before_install
assert_contains "$TMP_DIR/disconnect_before_install.out" "Android phone PHONE123 is no longer connected and ready"
assert_file_contents "$TMP_DIR/disconnect_before_install/state/global-com.wrait.flutter.dev.automation_lockscreen_mode" "0"
assert_file_contents "$TMP_DIR/disconnect_before_install/state/stay-awake-mode" "false"
assert_not_contains "$TMP_DIR/disconnect_before_install.log" "adb -s PHONE123 install -r"

run_script_expect_failure launch_timeout
assert_contains "$TMP_DIR/launch_timeout.out" "com.wrait.flutter.dev launch timed out after install and foreground verification failed"
assert_contains "$TMP_DIR/launch_timeout.log" "adb -s PHONE123 shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity"
assert_contains "$TMP_DIR/launch_timeout.log" "adb -s PHONE123 shell dumpsys activity activities"
assert_file_contents "$TMP_DIR/launch_timeout/state/global-com.wrait.flutter.dev.automation_lockscreen_mode" "0"
assert_file_contents "$TMP_DIR/launch_timeout/state/stay-awake-mode" "false"

run_script_expect_failure native_removed_after_install
assert_contains "$TMP_DIR/native_removed_after_install.out" "com.wrait.app was installed before deployment but is missing after install"
assert_contains "$TMP_DIR/native_removed_after_install.log" "adb -s PHONE123 shell pm path com.wrait.app"
assert_contains "$TMP_DIR/native_removed_after_install.log" "flutter build apk --profile --dart-define=PROXY_SECRET=test-proxy-secret"
assert_contains "$TMP_DIR/native_removed_after_install.log" "adb -s PHONE123 install -r $TMP_DIR/native_removed_after_install/app-profile.apk"

run_script_expect_success native_absent
assert_contains "$TMP_DIR/native_absent.out" "Native Wrait app (com.wrait.app) was not installed before deployment."
assert_contains "$TMP_DIR/native_absent.out" "Installed and launched com.wrait.flutter.dev on PHONE123."

run_script_expect_success keyguard_dismiss_refused
assert_contains "$TMP_DIR/keyguard_dismiss_refused.out" "refused non-interactive keyguard dismissal for Flutter integration tests"
assert_contains "$TMP_DIR/keyguard_dismiss_refused.out" "refused non-interactive keyguard dismissal for final installed app launch"
assert_contains "$TMP_DIR/keyguard_dismiss_refused.log" "adb -s PHONE123 shell pm grant com.wrait.flutter.dev android.permission.RECORD_AUDIO"
assert_contains "$TMP_DIR/keyguard_dismiss_refused.out" "Installed and launched com.wrait.flutter.dev on PHONE123."

run_script_expect_success locked_phone
assert_contains "$TMP_DIR/locked_phone.out" "Preparing Android phone PHONE123 for Flutter integration tests..."
assert_contains "$TMP_DIR/locked_phone.out" "Preparing Android phone PHONE123 for final installed app launch..."
assert_contains "$TMP_DIR/locked_phone.out" "Granted android.permission.RECORD_AUDIO to com.wrait.flutter.dev for automated tests."
assert_contains "$TMP_DIR/locked_phone.log" "adb -s PHONE123 shell svc power stayon usb"
assert_contains "$TMP_DIR/locked_phone.log" "adb -s PHONE123 shell settings put global com.wrait.flutter.dev.automation_lockscreen_mode 1"
assert_contains "$TMP_DIR/locked_phone.log" "adb -s PHONE123 shell input keyevent KEYCODE_WAKEUP"
assert_contains "$TMP_DIR/locked_phone.log" "adb -s PHONE123 shell wm dismiss-keyguard"
assert_contains "$TMP_DIR/locked_phone.log" "adb -s PHONE123 shell pm grant com.wrait.flutter.dev android.permission.RECORD_AUDIO"
assert_contains "$TMP_DIR/locked_phone.log" "adb -s PHONE123 shell appops set com.wrait.flutter.dev RECORD_AUDIO allow"
assert_contains "$TMP_DIR/locked_phone.log" "adb -s PHONE123 shell pm grant com.wrait.flutter.dev.test android.permission.RECORD_AUDIO"
assert_contains "$TMP_DIR/locked_phone.log" "adb -s PHONE123 shell settings put global com.wrait.flutter.dev.automation_lockscreen_mode 0"
assert_contains "$TMP_DIR/locked_phone.log" "adb -s PHONE123 shell svc power stayon false"
assert_file_contents "$TMP_DIR/locked_phone/state/global-com.wrait.flutter.dev.automation_lockscreen_mode" "0"
assert_file_contents "$TMP_DIR/locked_phone/state/stay-awake-mode" "false"
assert_contains "$TMP_DIR/locked_phone.out" "Installed and launched com.wrait.flutter.dev on PHONE123."

run_script_expect_success one_phone
assert_contains "$TMP_DIR/one_phone.log" "flutter build apk --debug --dart-define=PROXY_SECRET=test-proxy-secret"
assert_contains "$TMP_DIR/one_phone.log" "flutter build apk --profile --dart-define=PROXY_SECRET=test-proxy-secret"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell svc power stayon usb"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell settings put global com.wrait.flutter.dev.automation_lockscreen_mode 1"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell input keyevent KEYCODE_WAKEUP"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell wm dismiss-keyguard"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell pm grant com.wrait.flutter.dev android.permission.RECORD_AUDIO"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell appops set com.wrait.flutter.dev RECORD_AUDIO allow"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell pm grant com.wrait.flutter.dev.test android.permission.RECORD_AUDIO"
assert_contains "$TMP_DIR/one_phone.log" "flutter test --no-pub -d PHONE123 integration_test"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell am force-stop com.wrait.flutter.dev"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell pm path com.wrait.app"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 get-state"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 install -r $TMP_DIR/one_phone/app-profile.apk"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell pm path com.wrait.flutter.dev"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell settings put global com.wrait.flutter.dev.automation_lockscreen_mode 0"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell svc power stayon false"
assert_file_contents "$TMP_DIR/one_phone/state/global-com.wrait.flutter.dev.automation_lockscreen_mode" "0"
assert_file_contents "$TMP_DIR/one_phone/state/stay-awake-mode" "false"
assert_contains "$TMP_DIR/one_phone.out" "Detected existing native Wrait app (com.wrait.app); it will be left installed."
assert_contains "$TMP_DIR/one_phone.out" "Verified com.wrait.app remains installed."
assert_contains "$TMP_DIR/one_phone.out" "Installed and launched com.wrait.flutter.dev on PHONE123."

run_script_expect_success one_phone_custom_state 7 9
assert_contains "$TMP_DIR/one_phone_custom_state.log" "adb -s PHONE123 shell settings put global com.wrait.flutter.dev.automation_lockscreen_mode 9"
assert_contains "$TMP_DIR/one_phone_custom_state.log" "adb -s PHONE123 shell settings put global stay_on_while_plugged_in 7"
assert_file_contents "$TMP_DIR/one_phone_custom_state/state/global-com.wrait.flutter.dev.automation_lockscreen_mode" "9"
assert_file_contents "$TMP_DIR/one_phone_custom_state/state/global-stay_on_while_plugged_in" "7"

printf 'deploy_debug_script_test.sh: all tests passed\n'

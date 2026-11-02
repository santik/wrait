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

printf 'adb should not be called by deploy_bundle.sh\n' >&2
exit 99
EOF

  cat >"$TMP_DIR/bin/flutter" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'flutter %s\n' "$*" >>"$DEPLOY_TEST_LOG"

case "$*" in
  build\ appbundle\ --release*)
    [[ -n "${WRAIT_RELEASE_KEYSTORE_PASSWORD:-}" ]] || {
      printf 'missing WRAIT_RELEASE_KEYSTORE_PASSWORD\n' >&2
      exit 1
    }
    [[ -n "${WRAIT_RELEASE_KEY_PASSWORD:-}" ]] || {
      printf 'missing WRAIT_RELEASE_KEY_PASSWORD\n' >&2
      exit 1
    }
    case "${DEPLOY_TEST_SCENARIO:-}" in
      build_no_bundle)
        ;;
      zero_size_bundle)
        mkdir -p "$(dirname "$DEPLOY_TEST_RELEASE_BUNDLE_PATH")"
        : >"$DEPLOY_TEST_RELEASE_BUNDLE_PATH"
        ;;
      *)
        mkdir -p "$(dirname "$DEPLOY_TEST_RELEASE_BUNDLE_PATH")"
        printf 'fake release bundle\n' >"$DEPLOY_TEST_RELEASE_BUNDLE_PATH"
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
  shift
  local scenario_dir="$TMP_DIR/$scenario"
  local output="$TMP_DIR/$scenario.out"
  local log="$TMP_DIR/$scenario.log"
  local release_bundle_path="$scenario_dir/app-release.aab"
  local source_path="$scenario_dir/private-config/local.properties"
  local target_path="$scenario_dir/android/local.properties"
  : >"$log"

  prepare_config_files "$scenario_dir"

  case "$scenario" in
    missing_source_config)
      rm -f "$source_path"
      ;;
    missing_target_config_dir)
      rm -rf "$scenario_dir/android"
      target_path="$scenario_dir/android/local.properties"
      ;;
    invalid_backend_url)
      sed -i.bak 's|^BACKEND_URL=.*|BACKEND_URL=not-a-url|' "$source_path"
      rm -f "$source_path.bak"
      ;;
    blank_proxy_secret)
      sed -i.bak 's/^PROXY_SECRET=.*/PROXY_SECRET=/' "$source_path"
      rm -f "$source_path.bak"
      ;;
    invalid_wiredash_secret)
      sed -i.bak 's/^WIREDASH_SECRET=.*/WIREDASH_SECRET=short/' "$source_path"
      rm -f "$source_path.bak"
      ;;
    invalid_keystore_password|invalid_key_password|build_no_bundle|zero_size_bundle)
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
  esac

  (
    cd "$ROOT_DIR"
    PATH="$TMP_DIR/bin:$PATH" \
      JAVA_HOME="$TMP_DIR/fake-java" \
      DEPLOY_TEST_SCENARIO="$scenario" \
      DEPLOY_TEST_LOG="$log" \
      DEPLOY_TEST_RELEASE_BUNDLE_PATH="$release_bundle_path" \
      DEPLOY_BUNDLE_PATH="$release_bundle_path" \
      DEPLOY_BUNDLE_SOURCE_LOCAL_PROPERTIES_PATH="$source_path" \
      DEPLOY_BUNDLE_TARGET_LOCAL_PROPERTIES_PATH="$target_path" \
      ./deploy_bundle.sh "$@"
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

write_fakes

if grep -Eq '(^|[[:space:]])adb[[:space:]]' "$ROOT_DIR/deploy_bundle.sh"; then
  fail "deploy_bundle.sh must not call adb; use deploy_release.sh for device install validation"
fi

if grep -Eq '(^|[[:space:]])(adb|flutter)[[:space:]].*\buninstall\b' "$ROOT_DIR/deploy_bundle.sh"; then
  fail "deploy_bundle.sh must never uninstall any package"
fi

run_script_expect_failure missing_source_config
assert_contains "$TMP_DIR/missing_source_config.out" "private source config is missing"
assert_not_contains "$TMP_DIR/missing_source_config.log" "flutter build"

run_script_expect_failure missing_target_config_dir
assert_contains "$TMP_DIR/missing_target_config_dir.out" "Flutter app-local config directory is missing"
assert_not_contains "$TMP_DIR/missing_target_config_dir.log" "flutter build"

run_script_expect_failure invalid_backend_url
assert_contains "$TMP_DIR/invalid_backend_url.out" "BACKEND_URL must be an absolute http or https URL"
assert_not_contains "$TMP_DIR/invalid_backend_url.log" "flutter build"

run_script_expect_failure blank_proxy_secret
assert_contains "$TMP_DIR/blank_proxy_secret.out" "PROXY_SECRET is missing or blank"
assert_not_contains "$TMP_DIR/blank_proxy_secret.log" "flutter build"

run_script_expect_failure invalid_wiredash_secret
assert_contains "$TMP_DIR/invalid_wiredash_secret.out" \
  "WIREDASH_SECRET must be at least 8 characters long"
assert_not_contains "$TMP_DIR/invalid_wiredash_secret.log" "flutter build"

run_script_expect_failure invalid_build_name --build-name 1.2
assert_contains "$TMP_DIR/invalid_build_name.out" \
  "--build-name must use MAJOR.MINOR.PATCH format"
assert_not_contains "$TMP_DIR/invalid_build_name.log" "flutter build"

run_script_expect_failure invalid_build_number --build-number 0
assert_contains "$TMP_DIR/invalid_build_number.out" \
  "--build-number must be a positive integer"
assert_not_contains "$TMP_DIR/invalid_build_number.log" "flutter build"

run_script_expect_failure invalid_keystore_password
assert_contains "$TMP_DIR/invalid_keystore_password.out" "release keystore validation failed"
assert_not_contains "$TMP_DIR/invalid_keystore_password.log" "flutter build"

run_script_expect_failure invalid_key_password
assert_contains "$TMP_DIR/invalid_key_password.out" "release key validation failed"
assert_not_contains "$TMP_DIR/invalid_key_password.log" "flutter build"

run_script_expect_failure build_no_bundle
assert_contains "$TMP_DIR/build_no_bundle.out" "release app bundle was not created"
assert_contains "$TMP_DIR/build_no_bundle.log" "flutter build appbundle --release --dart-define=BACKEND_URL=https://release.example.test --dart-define=PROXY_SECRET=release-proxy-secret --dart-define=RECORDING_HARD_CAP_MS=180000"
assert_contains "$TMP_DIR/build_no_bundle.log" "--dart-define=WIREDASH_PROJECT_ID=release-wiredash-project --dart-define=WIREDASH_SECRET=release-wiredash-secret --dart-define=WIREDASH_ENVIRONMENT=production"

run_script_expect_failure zero_size_bundle
assert_contains "$TMP_DIR/zero_size_bundle.out" "release app bundle at $TMP_DIR/zero_size_bundle/app-release.aab is empty"

run_script_expect_success wrait_password_property
assert_contains "$TMP_DIR/wrait_password_property.out" "Synchronized release signing and runtime config into $TMP_DIR/wrait_password_property/android/local.properties."
assert_contains "$TMP_DIR/wrait_password_property.log" "flutter build appbundle --release --dart-define=BACKEND_URL=https://release.example.test --dart-define=PROXY_SECRET=release-proxy-secret"
assert_not_contains "$TMP_DIR/wrait_password_property/android/local.properties" "WRAIT_RELEASE_KEYSTORE_PASSWORD="
assert_not_contains "$TMP_DIR/wrait_password_property/android/local.properties" "WRAIT_RELEASE_KEY_PASSWORD="

run_script_expect_success same_file_config
assert_contains "$TMP_DIR/same_file_config.out" "Using release signing and runtime config from $TMP_DIR/same_file_config/android/local.properties."
assert_contains "$TMP_DIR/same_file_config.log" "flutter build appbundle --release --dart-define=BACKEND_URL=https://release.example.test --dart-define=PROXY_SECRET=release-proxy-secret"
assert_file_contains_line "$TMP_DIR/same_file_config/android/local.properties" "KEYSTORE_PASSWORD=release-keystore-password"
assert_file_contains_line "$TMP_DIR/same_file_config/android/local.properties" "KEY_PASSWORD=release-key-password"

run_script_expect_success one_bundle
assert_contains "$TMP_DIR/one_bundle.out" "Synchronized release signing and runtime config into $TMP_DIR/one_bundle/android/local.properties."
assert_contains "$TMP_DIR/one_bundle.out" "Created release app bundle at $TMP_DIR/one_bundle/app-release.aab"
assert_contains "$TMP_DIR/one_bundle.log" "flutter build appbundle --release --dart-define=BACKEND_URL=https://release.example.test --dart-define=PROXY_SECRET=release-proxy-secret --dart-define=RECORDING_HARD_CAP_MS=180000 --dart-define=WIREDASH_PROJECT_ID=release-wiredash-project --dart-define=WIREDASH_SECRET=release-wiredash-secret --dart-define=WIREDASH_ENVIRONMENT=production"
assert_contains "$TMP_DIR/one_bundle.log" "keytool -list -keystore $TMP_DIR/one_bundle/private-config/release-key.jks -storepass <redacted> -alias release-key-alias"
assert_contains "$TMP_DIR/one_bundle.log" "keytool -certreq -keystore $TMP_DIR/one_bundle/private-config/release-key.jks -storepass <redacted> -alias release-key-alias -keypass <redacted>"
assert_not_contains "$TMP_DIR/one_bundle.log" "adb "
assert_not_contains "$TMP_DIR/one_bundle.log" "release-keystore-password"
assert_not_contains "$TMP_DIR/one_bundle.log" "release-key-password"
assert_not_contains "$TMP_DIR/one_bundle.out" "release-wiredash-secret"
assert_file_contains_line "$TMP_DIR/one_bundle/android/local.properties" "sdk.dir=/tmp/android-sdk"
assert_file_contains_line "$TMP_DIR/one_bundle/android/local.properties" "flutter.sdk=/tmp/flutter-sdk"
assert_file_contains_line "$TMP_DIR/one_bundle/android/local.properties" "flutter.buildMode=release"
assert_file_contains_line "$TMP_DIR/one_bundle/android/local.properties" "flutter.versionName=1.0.0"
assert_file_contains_line "$TMP_DIR/one_bundle/android/local.properties" "flutter.versionCode=1"
assert_file_contains_line "$TMP_DIR/one_bundle/android/local.properties" "EXISTING_KEY=keep-me"
assert_file_contains_line "$TMP_DIR/one_bundle/android/local.properties" "KEYSTORE_PATH=$TMP_DIR/one_bundle/private-config/release-key.jks"
assert_file_contains_line "$TMP_DIR/one_bundle/android/local.properties" "KEY_ALIAS=release-key-alias"
assert_file_contains_line "$TMP_DIR/one_bundle/android/local.properties" "BACKEND_URL=https://release.example.test"
assert_file_contains_line "$TMP_DIR/one_bundle/android/local.properties" "PROXY_SECRET=release-proxy-secret"
assert_file_contains_line "$TMP_DIR/one_bundle/android/local.properties" "RECORDING_HARD_CAP_MS=180000"
assert_file_contains_line "$TMP_DIR/one_bundle/android/local.properties" "WIREDASH_PROJECT_ID=release-wiredash-project"
assert_file_contains_line "$TMP_DIR/one_bundle/android/local.properties" "WIREDASH_ENVIRONMENT=production"
assert_not_contains "$TMP_DIR/one_bundle/android/local.properties" "KEYSTORE_PATH=stale-path"
assert_not_contains "$TMP_DIR/one_bundle/android/local.properties" "KEYSTORE_PASSWORD="
assert_not_contains "$TMP_DIR/one_bundle/android/local.properties" "KEY_PASSWORD="
assert_not_contains "$TMP_DIR/one_bundle/android/local.properties" "WRAIT_RELEASE_KEYSTORE_PASSWORD="
assert_not_contains "$TMP_DIR/one_bundle/android/local.properties" "WRAIT_RELEASE_KEY_PASSWORD="
assert_not_contains "$TMP_DIR/one_bundle/android/local.properties" "PROXY_SECRET=stale-secret"
assert_file_contains_line "$TMP_DIR/one_bundle/android/local.properties" "WIREDASH_SECRET=release-wiredash-secret"

run_script_expect_success custom_version --build-name=2.3.4 --build-number=7
assert_contains "$TMP_DIR/custom_version.out" \
  "Using build-name=2.3.4 and build-number=7."
assert_contains "$TMP_DIR/custom_version.log" \
  "flutter build appbundle --release --dart-define=BACKEND_URL=https://release.example.test --dart-define=PROXY_SECRET=release-proxy-secret --dart-define=RECORDING_HARD_CAP_MS=180000 --dart-define=WIREDASH_PROJECT_ID=release-wiredash-project --dart-define=WIREDASH_SECRET=release-wiredash-secret --dart-define=WIREDASH_ENVIRONMENT=production --build-name=2.3.4 --build-number=7"
assert_file_contains_line "$TMP_DIR/custom_version/android/local.properties" "flutter.versionName=1.0.0"
assert_file_contains_line "$TMP_DIR/custom_version/android/local.properties" "flutter.versionCode=1"

printf 'deploy_bundle_script_test.sh: all tests passed\n'

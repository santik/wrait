#!/usr/bin/env bash
set -euo pipefail

# Usage: ./deploy_bundle.sh [--build-name VERSION] [--build-number NUMBER]
# Prerequisites:
# - release-signing keys and runtime values present in android/local.properties
# - release-signing passwords present in android/local.properties or supplied
#   through transient WRAIT_RELEASE_* environment variables
# - release-signing passwords stay in-memory for build/keytool validation
#
# This script creates the Android App Bundle artifact intended for Play Console
# upload. Use ./deploy_release.sh separately when you need physical-phone APK
# install and launch validation.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Reuse the release script's config parsing, validation, local.properties sync,
# Java setup, and keystore checks. deploy_release.sh is guarded so sourcing it
# does not install or launch the app.
source "$ROOT_DIR/deploy_release.sh"

RELEASE_BUNDLE_PATH="${DEPLOY_BUNDLE_PATH:-$ROOT_DIR/build/app/outputs/bundle/release/app-release.aab}"
SOURCE_LOCAL_PROPERTIES_PATH="${DEPLOY_BUNDLE_SOURCE_LOCAL_PROPERTIES_PATH:-$ROOT_DIR/android/local.properties}"
TARGET_LOCAL_PROPERTIES_PATH="${DEPLOY_BUNDLE_TARGET_LOCAL_PROPERTIES_PATH:-$ROOT_DIR/android/local.properties}"
SYNCED_TARGET_LOCAL_PROPERTIES=false
BUILD_NAME="${DEPLOY_BUNDLE_BUILD_NAME:-}"
BUILD_NUMBER="${DEPLOY_BUNDLE_BUILD_NUMBER:-}"

usage() {
  cat <<'EOF'
Usage: ./deploy_bundle.sh [options]

Build options:
  --build-name VERSION   Override the user-facing version for this bundle.
  --build-number NUMBER  Override the Android build number for this bundle.
  -h, --help             Show this help text.

Without build options, Flutter uses the version from pubspec.yaml.
EOF
}

validate_build_name() {
  local value="$1"

  [[ "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail \
    "--build-name must use MAJOR.MINOR.PATCH format"
}

parse_bundle_args() {
  while (($# > 0)); do
    case "$1" in
      --build-name)
        (($# >= 2)) || fail "--build-name requires a version value"
        [[ "$2" != -* ]] || fail "--build-name requires a version value"
        BUILD_NAME="$2"
        shift 2
        ;;
      --build-name=*)
        BUILD_NAME="${1#*=}"
        shift
        ;;
      --build-number)
        (($# >= 2)) || fail "--build-number requires a positive integer"
        [[ "$2" != -* ]] || fail "--build-number requires a positive integer"
        BUILD_NUMBER="$2"
        shift 2
        ;;
      --build-number=*)
        BUILD_NUMBER="${1#*=}"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "unknown option: $1"
        ;;
    esac
  done

  if [[ -n "$BUILD_NAME" ]]; then
    validate_build_name "$BUILD_NAME"
  fi
  if [[ -n "$BUILD_NUMBER" ]]; then
    validate_positive_integer "--build-number" "$BUILD_NUMBER"
  fi
}

prepare_bundle_output() {
  local bundle_path="$1"

  mkdir -p "$(dirname "$bundle_path")"
  rm -f "$bundle_path"
}

verify_built_bundle() {
  local bundle_path="$1"

  [[ -f "$bundle_path" ]] || fail "release app bundle was not created at $bundle_path"
  [[ -s "$bundle_path" ]] || fail "release app bundle at $bundle_path is empty"
}

main_bundle() {
  parse_bundle_args "$@"
  cd "$ROOT_DIR"
  configure_java
  require_command flutter
  require_command keytool
  load_and_validate_private_config
  sync_target_local_properties

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

  if [[ -n "$BUILD_NAME" ]]; then
    flutter_build_args+=("--build-name=$BUILD_NAME")
  fi
  if [[ -n "$BUILD_NUMBER" ]]; then
    flutter_build_args+=("--build-number=$BUILD_NUMBER")
  fi

  if [[ "$SYNCED_TARGET_LOCAL_PROPERTIES" == true ]]; then
    printf 'Synchronized release signing and runtime config into %s.\n' "$TARGET_LOCAL_PROPERTIES_PATH"
  else
    printf 'Using release signing and runtime config from %s.\n' "$SOURCE_LOCAL_PROPERTIES_PATH"
  fi

  if [[ -n "$BUILD_NAME" || -n "$BUILD_NUMBER" ]]; then
    printf 'Using build-name=%s and build-number=%s.\n' \
      "${BUILD_NAME:-pubspec.yaml}" "${BUILD_NUMBER:-pubspec.yaml}"
  else
    printf 'Using app version from pubspec.yaml.\n'
  fi

  printf 'Building Flutter release app bundle...\n'
  prepare_bundle_output "$RELEASE_BUNDLE_PATH"
  env \
    "$RELEASE_KEYSTORE_PASSWORD_ENV=$RESOLVED_KEYSTORE_PASSWORD" \
    "$RELEASE_KEY_PASSWORD_ENV=$RESOLVED_KEY_PASSWORD" \
    flutter build appbundle --release "${flutter_build_args[@]}"
  verify_built_bundle "$RELEASE_BUNDLE_PATH"

  printf 'Created release app bundle at %s.\n' "$RELEASE_BUNDLE_PATH"
}

main_bundle "$@"

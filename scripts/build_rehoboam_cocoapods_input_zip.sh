#!/usr/bin/env bash
set -euo pipefail

COMPONENT_NAME="AgoraAgentClientToolkit"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${WORKSPACE:-$ROOT_DIR/VoiceAgent.xcworkspace}"
SCHEME="${SCHEME:-$COMPONENT_NAME}"
CONFIGURATION="${CONFIGURATION:-Release}"
PODSPEC_TEMPLATE="${PODSPEC_TEMPLATE:-$ROOT_DIR/AgoraAgentClientToolkit/$COMPONENT_NAME.binary.podspec.template}"
XCODE_WORK_ROOT="${XCODE_WORK_ROOT:-/private/tmp/$COMPONENT_NAME-internal-cocoapods-xcode}"
PACKAGE_WORK_ROOT="${PACKAGE_WORK_ROOT:-/private/tmp/$COMPONENT_NAME-cocoapods-package}"
CLEAN_DERIVED_DATA="${CLEAN_DERIVED_DATA:-1}"
KEEP_STAGING="${KEEP_STAGING:-0}"
VERSION="${VERSION:-}"

if [[ -z "$VERSION" ]]; then
  echo "Unable to resolve version. Pass VERSION=2.9.0-rc.1." >&2
  exit 1
fi

if [[ "$VERSION" == *"-SNAPSHOT" ]]; then
  echo "Rehoboam CocoaPods input zip requires a non-SNAPSHOT version: $VERSION" >&2
  exit 1
fi

if [[ ! -d "$ROOT_DIR/Pods/Pods.xcodeproj" ]]; then
  echo "Pods project is missing. Run 'pod install' before building the Rehoboam CocoaPods input zip." >&2
  exit 1
fi

if [[ ! -f "$PODSPEC_TEMPLATE" ]]; then
  echo "Missing binary podspec template: $PODSPEC_TEMPLATE" >&2
  exit 1
fi

RUN_ID="$(date +%Y%m%d%H%M%S)"
RUN_ROOT="${RUN_ROOT:-$ROOT_DIR/build/internal-cocoapods/$COMPONENT_NAME-$VERSION-$RUN_ID}"
ARCHIVES_DIR="${ARCHIVES_DIR:-$XCODE_WORK_ROOT/$RUN_ID/archives}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$XCODE_WORK_ROOT/$RUN_ID/DerivedData}"
STAGING_ROOT="${STAGING_ROOT:-$PACKAGE_WORK_ROOT/$RUN_ID/staging}"
SDK_DIR="$STAGING_ROOT/sdk"
ZIP_PATH="${ZIP_PATH:-$RUN_ROOT/$COMPONENT_NAME-$VERSION.zip}"

DEVICE_ARCHIVE="$ARCHIVES_DIR/$COMPONENT_NAME-iOS.xcarchive"
SIMULATOR_ARCHIVE="$ARCHIVES_DIR/$COMPONENT_NAME-iOS-Simulator.xcarchive"
XCFRAMEWORK_PATH="$SDK_DIR/$COMPONENT_NAME.xcframework"
STAGED_PODSPEC="$STAGING_ROOT/$COMPONENT_NAME.podspec"

cleanup() {
  if [[ "$KEEP_STAGING" != "1" ]]; then
    rm -rf "$STAGING_ROOT"
  fi
}
trap cleanup EXIT

rm -rf "$STAGING_ROOT"
if [[ "$CLEAN_DERIVED_DATA" == "1" ]]; then
  rm -rf "$DERIVED_DATA_PATH"
fi
mkdir -p "$ARCHIVES_DIR" "$SDK_DIR" "$(dirname "$ZIP_PATH")" "$DERIVED_DATA_PATH"
rm -rf "$XCFRAMEWORK_PATH" "$ZIP_PATH"

archive_framework() {
  local destination="$1"
  local archive_path="$2"

  xcodebuild archive \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$destination" \
    -archivePath "$archive_path" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SWIFT_ENABLE_EXPLICIT_MODULES=NO \
    CODE_SIGNING_ALLOWED=NO \
    -quiet
}

echo "Archiving $COMPONENT_NAME for iOS..."
archive_framework "generic/platform=iOS" "$DEVICE_ARCHIVE"

echo "Archiving $COMPONENT_NAME for iOS Simulator..."
archive_framework "generic/platform=iOS Simulator" "$SIMULATOR_ARCHIVE"

echo "Creating $COMPONENT_NAME.xcframework..."
xcodebuild -create-xcframework \
  -framework "$DEVICE_ARCHIVE/Products/Library/Frameworks/$COMPONENT_NAME.framework" \
  -framework "$SIMULATOR_ARCHIVE/Products/Library/Frameworks/$COMPONENT_NAME.framework" \
  -output "$XCFRAMEWORK_PATH"

cp "$PODSPEC_TEMPLATE" "$STAGED_PODSPEC"
VERSION="$VERSION" /usr/bin/ruby -0pi -e 'gsub(/s\.version\s*=\s*['"'"'"][^'"'"'"]+['"'"'"]/, "s.version = " + ENV.fetch("VERSION").dump)' "$STAGED_PODSPEC"
VERSION="$VERSION" /usr/bin/ruby -e "spec = File.read(ARGV[0]); expected = ENV.fetch('VERSION'); actual = spec[/s\\.version\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]/, 1]; abort(\"Staged podspec version mismatch: expected #{expected}, got #{actual || 'nil'}\") unless actual == expected" "$STAGED_PODSPEC"

if [[ -n "${FILE_URL:-}" ]]; then
  FILE_URL="$FILE_URL" /usr/bin/ruby -0pi -e "gsub('REPLACE_WITH_BINARY_ZIP_URL', ENV.fetch('FILE_URL'))" "$STAGED_PODSPEC"
else
  echo "FILE_URL is not set; staged podspec keeps REPLACE_WITH_BINARY_ZIP_URL." >&2
fi

echo "Creating Rehoboam CocoaPods input zip..."
(
  cd "$STAGING_ROOT"
  /usr/bin/zip -qry "$ZIP_PATH" "$COMPONENT_NAME.podspec" sdk
)

echo "Rehoboam CocoaPods input zip: $ZIP_PATH"
echo "Zip contents:"
/usr/bin/unzip -l "$ZIP_PATH"

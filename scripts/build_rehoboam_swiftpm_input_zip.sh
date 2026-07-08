#!/usr/bin/env bash
set -euo pipefail

COMPONENT_NAME="AgoraAgentClientToolkit"
PACKAGE_NAME="agent-client-toolkit-swift"
PACKAGE_BASENAME="agora-agent-client-toolkit"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${WORKSPACE:-$ROOT_DIR/VoiceAgent.xcworkspace}"
SCHEME="${SCHEME:-$PACKAGE_NAME}"
CONFIGURATION="${CONFIGURATION:-Release}"
CLEAN_DERIVED_DATA="${CLEAN_DERIVED_DATA:-1}"
EXISTING_XCFRAMEWORK="${EXISTING_XCFRAMEWORK:-}"
RUN_ID="$(date +%Y%m%d%H%M%S)"

VERSION="${VERSION:-}"
if [[ -z "$VERSION" ]]; then
  echo "Unable to resolve version. Pass VERSION=2.9.0-rc.1." >&2
  exit 1
fi

if [[ "$VERSION" == *"-SNAPSHOT" ]]; then
  echo "Rehoboam SwiftPM input zip requires a non-SNAPSHOT version: $VERSION" >&2
  exit 1
fi

RUN_ROOT="${RUN_ROOT:-$ROOT_DIR/build/internal-spm/$PACKAGE_BASENAME-$VERSION-swiftpm-$RUN_ID}"
XCODE_WORK_ROOT="${XCODE_WORK_ROOT:-/private/tmp/$PACKAGE_BASENAME-spm-rehoboam-xcode}"
ARCHIVES_DIR="${ARCHIVES_DIR:-$XCODE_WORK_ROOT/$RUN_ID/archives}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$XCODE_WORK_ROOT/$RUN_ID/DerivedData}"
INPUT_ROOT="$RUN_ROOT/input"
INPUT_ZIP="$RUN_ROOT/$PACKAGE_BASENAME-$VERSION-swiftpm-rehoboam-input.zip"
XCFRAMEWORK_PATH="$INPUT_ROOT/swiftpm_template/sdk/$COMPONENT_NAME/$COMPONENT_NAME.xcframework"
DEVICE_ARCHIVE="$ARCHIVES_DIR/$COMPONENT_NAME-iOS.xcarchive"
SIMULATOR_ARCHIVE="$ARCHIVES_DIR/$COMPONENT_NAME-iOS-Simulator.xcarchive"

if [[ ! -d "$ROOT_DIR/swiftpm_template" ]]; then
  echo "Missing swiftpm_template directory." >&2
  exit 1
fi

rm -rf "$INPUT_ROOT" "$INPUT_ZIP"
mkdir -p "$INPUT_ROOT"
cp -R "$ROOT_DIR/swiftpm_template" "$INPUT_ROOT/"
rm -rf "$XCFRAMEWORK_PATH"

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

if [[ -n "$EXISTING_XCFRAMEWORK" ]]; then
  if [[ ! -d "$EXISTING_XCFRAMEWORK" ]]; then
    echo "EXISTING_XCFRAMEWORK does not exist: $EXISTING_XCFRAMEWORK" >&2
    exit 1
  fi
  echo "Using existing $COMPONENT_NAME.xcframework: $EXISTING_XCFRAMEWORK"
  cp -R "$EXISTING_XCFRAMEWORK" "$XCFRAMEWORK_PATH"
else
  if [[ ! -d "$ROOT_DIR/Pods/Pods.xcodeproj" ]]; then
    echo "Pods project is missing. Run 'pod install' before building the Rehoboam SwiftPM input zip." >&2
    exit 1
  fi

  if [[ "$CLEAN_DERIVED_DATA" == "1" ]]; then
    rm -rf "$DERIVED_DATA_PATH"
  fi
  mkdir -p "$ARCHIVES_DIR" "$DERIVED_DATA_PATH"

  echo "Archiving $COMPONENT_NAME for iOS..."
  archive_framework "generic/platform=iOS" "$DEVICE_ARCHIVE"

  echo "Archiving $COMPONENT_NAME for iOS Simulator..."
  archive_framework "generic/platform=iOS Simulator" "$SIMULATOR_ARCHIVE"

  echo "Creating $COMPONENT_NAME.xcframework..."
  xcodebuild -create-xcframework \
    -framework "$DEVICE_ARCHIVE/Products/Library/Frameworks/$COMPONENT_NAME.framework" \
    -framework "$SIMULATOR_ARCHIVE/Products/Library/Frameworks/$COMPONENT_NAME.framework" \
    -output "$XCFRAMEWORK_PATH"
fi

if [[ ! -d "$XCFRAMEWORK_PATH" ]]; then
  echo "Missing generated xcframework: $XCFRAMEWORK_PATH" >&2
  exit 1
fi

(
  cd "$INPUT_ROOT"
  /usr/bin/zip -qry "$INPUT_ZIP" swiftpm_template
)

echo "Rehoboam SwiftPM input zip: $INPUT_ZIP"

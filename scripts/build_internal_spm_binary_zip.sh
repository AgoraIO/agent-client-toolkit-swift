#!/usr/bin/env bash
set -euo pipefail

COMPONENT_NAME="AgoraAgentClientToolkit"
RTC_VERSION="${RTC_VERSION:-4.5.1}"
RTM_VERSION="${RTM_VERSION:-2.2.8}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PODSPEC_PATH="$ROOT_DIR/AgoraAgentClientToolkit/AgoraAgentClientToolkit.podspec"
WORKSPACE="${WORKSPACE:-$ROOT_DIR/VoiceAgent.xcworkspace}"
SCHEME="${SCHEME:-$COMPONENT_NAME}"
CONFIGURATION="${CONFIGURATION:-Release}"
XCODE_WORK_ROOT="${XCODE_WORK_ROOT:-/private/tmp/$COMPONENT_NAME-internal-spm-xcode}"
PACKAGE_WORK_ROOT="${PACKAGE_WORK_ROOT:-/private/tmp/$COMPONENT_NAME-spm-binary-package}"
CLEAN_DERIVED_DATA="${CLEAN_DERIVED_DATA:-1}"
KEEP_STAGING="${KEEP_STAGING:-0}"

if [[ ! -d "$ROOT_DIR/Pods/Pods.xcodeproj" ]]; then
  echo "Pods project is missing. Run 'pod install' before building the internal SwiftPM binary zip." >&2
  exit 1
fi

VERSION="${VERSION:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/bin/ruby -e "spec = File.read(ARGV[0]); puts spec[/s\\.version\\s*=\\s*['\\\"]([^'\\\"]+)/, 1]" "$PODSPEC_PATH")"
fi
if [[ -z "$VERSION" ]]; then
  echo "Unable to resolve version. Pass VERSION=1.0.0." >&2
  exit 1
fi

RUN_ID="$(date +%Y%m%d%H%M%S)"
RUN_ROOT="${RUN_ROOT:-$ROOT_DIR/build/internal-spm/$COMPONENT_NAME-$VERSION-binary-$RUN_ID}"
ARCHIVES_DIR="${ARCHIVES_DIR:-$XCODE_WORK_ROOT/$RUN_ID/archives}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$XCODE_WORK_ROOT/$RUN_ID/DerivedData}"
STAGING_ROOT="${STAGING_ROOT:-$PACKAGE_WORK_ROOT/$RUN_ID/staging}"
PACKAGE_ROOT="$STAGING_ROOT"
DEPENDENCIES_TARGET_NAME="${DEPENDENCIES_TARGET_NAME:-${COMPONENT_NAME}Dependencies}"
SOURCES_DIR="$PACKAGE_ROOT/Sources/$DEPENDENCIES_TARGET_NAME"
ZIP_PATH="${ZIP_PATH:-$RUN_ROOT/$COMPONENT_NAME-$VERSION-spm-binary.zip}"

DEVICE_ARCHIVE="$ARCHIVES_DIR/$COMPONENT_NAME-iOS.xcarchive"
SIMULATOR_ARCHIVE="$ARCHIVES_DIR/$COMPONENT_NAME-iOS-Simulator.xcarchive"
XCFRAMEWORK_PATH="$PACKAGE_ROOT/$COMPONENT_NAME.xcframework"

cleanup() {
  if [[ "$KEEP_STAGING" != "1" ]]; then
    rm -rf "$STAGING_ROOT"
  fi
}
trap cleanup EXIT

rm -rf "$STAGING_ROOT" "$ZIP_PATH"
if [[ "$CLEAN_DERIVED_DATA" == "1" ]]; then
  rm -rf "$DERIVED_DATA_PATH"
fi
mkdir -p "$ARCHIVES_DIR" "$SOURCES_DIR" "$(dirname "$ZIP_PATH")" "$DERIVED_DATA_PATH"

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

if [[ ! -d "$XCFRAMEWORK_PATH" ]]; then
  echo "Missing generated xcframework: $XCFRAMEWORK_PATH" >&2
  exit 1
fi

cat > "$PACKAGE_ROOT/Package.swift" <<EOF
// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "agent-client-toolkit-swift",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "$COMPONENT_NAME",
            targets: ["$COMPONENT_NAME", "$DEPENDENCIES_TARGET_NAME"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/AgoraIO/AgoraRtcEngine_iOS.git", .exact("$RTC_VERSION")),
        .package(url: "https://github.com/AgoraIO/AgoraRTM_iOS.git", .exact("$RTM_VERSION"))
    ],
    targets: [
        .binaryTarget(
            name: "$COMPONENT_NAME",
            path: "$COMPONENT_NAME.xcframework"
        ),
        .target(
            name: "$DEPENDENCIES_TARGET_NAME",
            dependencies: [
                .product(name: "RtcBasic", package: "AgoraRtcEngine_iOS"),
                .product(name: "AgoraRTM", package: "AgoraRTM_iOS")
            ],
            path: "Sources/$DEPENDENCIES_TARGET_NAME"
        )
    ]
)
EOF

if [[ -f "$ROOT_DIR/README.md" ]]; then
  cp "$ROOT_DIR/README.md" "$PACKAGE_ROOT/README.md"
fi

cat > "$SOURCES_DIR/$DEPENDENCIES_TARGET_NAME.swift" <<EOF
import AgoraRtcKit
import AgoraRtmKit

public enum $DEPENDENCIES_TARGET_NAME {
    public static let rtcModule = "AgoraRtcKit"
    public static let rtmModule = "AgoraRtmKit"
}
EOF

echo "Creating internal SwiftPM binary zip..."
(
  cd "$PACKAGE_ROOT"
  /usr/bin/zip -qry "$ZIP_PATH" .
)

echo "Internal SwiftPM binary zip: $ZIP_PATH"
echo "Zip contents:"
/usr/bin/unzip -l "$ZIP_PATH"

ZIP_ENTRIES="$(/usr/bin/unzip -Z1 "$ZIP_PATH")"

if ! grep -Fxq "Package.swift" <<< "$ZIP_ENTRIES"; then
  echo "SwiftPM binary zip is missing root Package.swift." >&2
  exit 1
fi
if ! grep -Eq "^$COMPONENT_NAME\\.xcframework/" <<< "$ZIP_ENTRIES"; then
  echo "SwiftPM binary zip is missing root $COMPONENT_NAME.xcframework." >&2
  exit 1
fi

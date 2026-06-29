#!/usr/bin/env bash
set -euo pipefail

COMPONENT_NAME="AgoraAgentClientToolkit"
RTC_VERSION="${RTC_VERSION:-4.5.1}"
RTM_VERSION="${RTM_VERSION:-2.2.8}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PODSPEC_PATH="$ROOT_DIR/AgoraAgentClientToolkit/AgoraAgentClientToolkit.podspec"
TEMPLATE_PACKAGE_DIR="$ROOT_DIR/swiftpm_template/sdk/$COMPONENT_NAME"
TEMPLATE_PACKAGE_SWIFT="$TEMPLATE_PACKAGE_DIR/Package.swift"
WORKSPACE="${WORKSPACE:-$ROOT_DIR/VoiceAgent.xcworkspace}"
SCHEME="${SCHEME:-$COMPONENT_NAME}"
CONFIGURATION="${CONFIGURATION:-Release}"
XCODE_WORK_ROOT="${XCODE_WORK_ROOT:-/private/tmp/$COMPONENT_NAME-internal-spm-xcode}"
PACKAGE_WORK_ROOT="${PACKAGE_WORK_ROOT:-/private/tmp/$COMPONENT_NAME-spm-binary-package}"
CLEAN_DERIVED_DATA="${CLEAN_DERIVED_DATA:-1}"
KEEP_STAGING="${KEEP_STAGING:-0}"
ARTIFACT_BASE_URL="${ARTIFACT_BASE_URL:-https://download.agora.io/swiftpm/agent-client-toolkit-swift}"
ARTIFACT_URL="${ARTIFACT_URL:-}"
EXISTING_XCFRAMEWORK="${EXISTING_XCFRAMEWORK:-}"

if [[ ! -d "$ROOT_DIR/Pods/Pods.xcodeproj" ]]; then
  echo "Pods project is missing. Run 'pod install' before building the internal SwiftPM binary zip." >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE_PACKAGE_SWIFT" ]]; then
  echo "Missing SwiftPM template manifest: $TEMPLATE_PACKAGE_SWIFT" >&2
  exit 1
fi

VERSION="${VERSION:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/bin/ruby -e "spec = File.read(ARGV[0]); puts spec[/s\\.version\\s*=\\s*['\\\"]([^'\\\"]+)/, 1]" "$PODSPEC_PATH")"
fi
if [[ -z "$VERSION" ]]; then
  echo "Unable to resolve version. Pass VERSION=2.9.0." >&2
  exit 1
fi

RUN_ID="$(date +%Y%m%d%H%M%S)"
RUN_ROOT="${RUN_ROOT:-$ROOT_DIR/build/internal-spm/$COMPONENT_NAME-$VERSION-binary-$RUN_ID}"
ARCHIVES_DIR="${ARCHIVES_DIR:-$XCODE_WORK_ROOT/$RUN_ID/archives}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$XCODE_WORK_ROOT/$RUN_ID/DerivedData}"
STAGING_ROOT="${STAGING_ROOT:-$PACKAGE_WORK_ROOT/$RUN_ID/staging}"
PACKAGE_ROOT="$STAGING_ROOT/sdk/$COMPONENT_NAME"
DIST_DIR="$STAGING_ROOT/dist"
DEPENDENCIES_TARGET_NAME="${DEPENDENCIES_TARGET_NAME:-${COMPONENT_NAME}Dependencies}"
SOURCES_DIR="$PACKAGE_ROOT/Sources/$DEPENDENCIES_TARGET_NAME"
ZIP_PATH="${ZIP_PATH:-$DIST_DIR/$COMPONENT_NAME.zip}"
DIST_PACKAGE_SWIFT="$DIST_DIR/Package.swift"
DIST_SOURCES_DIR="$DIST_DIR/Sources"
RUN_ZIP_PATH="$RUN_ROOT/$COMPONENT_NAME.zip"
RUN_PACKAGE_SWIFT="$RUN_ROOT/Package.swift"
RUN_SOURCES_DIR="$RUN_ROOT/Sources"

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
mkdir -p "$ARCHIVES_DIR" "$SOURCES_DIR" "$DIST_DIR" "$RUN_ROOT" "$DERIVED_DATA_PATH"

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

cp "$TEMPLATE_PACKAGE_SWIFT" "$PACKAGE_ROOT/Package.swift"
cp "$PACKAGE_ROOT/Package.swift" "$DIST_PACKAGE_SWIFT"

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
rm -rf "$DIST_SOURCES_DIR"
cp -R "$PACKAGE_ROOT/Sources" "$DIST_SOURCES_DIR"

echo "Creating internal SwiftPM binary zip..."
(
  cd "$PACKAGE_ROOT"
  /usr/bin/zip -qry "$ZIP_PATH" "$COMPONENT_NAME.xcframework"
)

CHECKSUM="$(swift package compute-checksum "$ZIP_PATH")"
if [[ -z "$ARTIFACT_URL" ]]; then
  ARTIFACT_URL="$ARTIFACT_BASE_URL/$VERSION/$COMPONENT_NAME.zip"
fi
if [[ "$ARTIFACT_URL" != https://* ]]; then
  echo "SwiftPM binaryTarget artifact URL must use https: $ARTIFACT_URL" >&2
  exit 1
fi
/usr/bin/python3 - "$DIST_PACKAGE_SWIFT" "$ARTIFACT_URL" "$CHECKSUM" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
url = sys.argv[2]
checksum = sys.argv[3]
text = path.read_text()
text = text.replace("{AgoraAgentClientToolkit_url}", url)
text = text.replace("{AgoraAgentClientToolkit_checksum}", checksum)
path.write_text(text)
PY

cp "$ZIP_PATH" "$RUN_ZIP_PATH"
cp "$DIST_PACKAGE_SWIFT" "$RUN_PACKAGE_SWIFT"
rm -rf "$RUN_SOURCES_DIR"
cp -R "$DIST_SOURCES_DIR" "$RUN_SOURCES_DIR"

echo "Internal SwiftPM binary zip: $RUN_ZIP_PATH"
echo "Internal SwiftPM Package.swift: $RUN_PACKAGE_SWIFT"
echo "Zip contents:"
/usr/bin/unzip -l "$RUN_ZIP_PATH"

ZIP_ENTRIES="$(/usr/bin/unzip -Z1 "$RUN_ZIP_PATH")"

if ! grep -Fxq "$COMPONENT_NAME.xcframework/Info.plist" <<< "$ZIP_ENTRIES"; then
  echo "SwiftPM binary zip is missing root $COMPONENT_NAME.xcframework/Info.plist." >&2
  exit 1
fi
if grep -Eq '^[^/]+/[^/]+\.xcframework/' <<< "$ZIP_ENTRIES"; then
  echo "SwiftPM binary zip must not wrap $COMPONENT_NAME.xcframework in a parent directory." >&2
  exit 1
fi
/usr/bin/python3 - "$RUN_PACKAGE_SWIFT" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
for match in re.finditer(r"\.binaryTarget\s*\((.*?)\)", text, re.DOTALL):
    if re.search(r"\bpath\s*:", match.group(1)):
        print("SwiftPM Package.swift must not use binaryTarget path:.", file=sys.stderr)
        sys.exit(1)
PY
if ! grep -Eq 'url:[[:space:]]*"https://' "$RUN_PACKAGE_SWIFT"; then
  echo "SwiftPM Package.swift must contain a resolved binaryTarget URL." >&2
  exit 1
fi
if ! grep -Eq 'checksum:[[:space:]]*"[a-fA-F0-9]{64}"' "$RUN_PACKAGE_SWIFT"; then
  echo "SwiftPM Package.swift must contain a resolved 64-character checksum." >&2
  exit 1
fi

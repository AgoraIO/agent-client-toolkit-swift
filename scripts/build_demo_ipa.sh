#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${WORKSPACE:-$ROOT_DIR/VoiceAgent.xcworkspace}"
SCHEME="${SCHEME:-VoiceAgent}"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-generic/platform=iOS}"
EXPORT_METHOD="${EXPORT_METHOD:-debugging}"
SIGNING_STYLE="${SIGNING_STYLE:-automatic}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-1}"
ALLOW_PROVISIONING_DEVICE_REGISTRATION="${ALLOW_PROVISIONING_DEVICE_REGISTRATION:-0}"
INSTALL_PODS="${INSTALL_PODS:-1}"
CLEAN_DERIVED_DATA="${CLEAN_DERIVED_DATA:-1}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d%H%M%S)}"
FLAVOR_PREFIX="${FLAVOR_PREFIX:-Agora_Agent_Client_Toolkit_Demo_for_iOS}"

RUN_ROOT="${RUN_ROOT:-$ROOT_DIR/build/ipa/$SCHEME-$RUN_ID}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build/ipa}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$RUN_ROOT/$SCHEME.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$RUN_ROOT/export}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$RUN_ROOT/DerivedData}"

if [[ -n "${EXPORT_OPTIONS_PLIST:-}" ]]; then
  GENERATED_EXPORT_OPTIONS=0
else
  EXPORT_OPTIONS_PLIST="$RUN_ROOT/ExportOptions.plist"
  GENERATED_EXPORT_OPTIONS=1
fi

if [[ ! -d "$WORKSPACE" ]]; then
  echo "Missing workspace: $WORKSPACE" >&2
  exit 1
fi

if [[ ! -d "$ROOT_DIR/Pods/Pods.xcodeproj" ]]; then
  if [[ "$INSTALL_PODS" == "1" ]]; then
    echo "Pods project is missing. Running pod install..."
    (cd "$ROOT_DIR" && pod install)
  else
    echo "Pods project is missing. Run 'pod install' or set INSTALL_PODS=1." >&2
    exit 1
  fi
fi

mkdir -p "$RUN_ROOT" "$OUTPUT_DIR"
if [[ "$CLEAN_DERIVED_DATA" == "1" ]]; then
  rm -rf "$DERIVED_DATA_PATH"
fi
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

echo "Resolving build settings..."
BUILD_SETTINGS="$(
  xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -showBuildSettings
)"

setting_value() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value = $2
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' <<< "$BUILD_SETTINGS"
}

BUNDLE_ID="$(setting_value PRODUCT_BUNDLE_IDENTIFIER)"
MARKETING_VERSION="$(setting_value MARKETING_VERSION)"
TEAM_ID="${TEAM_ID:-$(setting_value DEVELOPMENT_TEAM)}"

if [[ -z "$BUNDLE_ID" ]]; then
  echo "Unable to resolve PRODUCT_BUNDLE_IDENTIFIER for $SCHEME." >&2
  exit 1
fi
if [[ -z "$MARKETING_VERSION" ]]; then
  echo "Unable to resolve MARKETING_VERSION for $SCHEME." >&2
  exit 1
fi

PACKAGE_NAME="${BUNDLE_ID//./_}"
IPA_NAME="${IPA_NAME:-${FLAVOR_PREFIX}_${PACKAGE_NAME}_v${MARKETING_VERSION}_${RUN_ID}.ipa}"
FINAL_IPA_PATH="$OUTPUT_DIR/$IPA_NAME"

if [[ "$GENERATED_EXPORT_OPTIONS" == "1" ]]; then
  cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>$EXPORT_METHOD</string>
    <key>signingStyle</key>
    <string>$SIGNING_STYLE</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
PLIST
  if [[ -n "$TEAM_ID" ]]; then
    cat >> "$EXPORT_OPTIONS_PLIST" <<PLIST
    <key>teamID</key>
    <string>$TEAM_ID</string>
PLIST
  fi
  cat >> "$EXPORT_OPTIONS_PLIST" <<'PLIST'
</dict>
</plist>
PLIST
fi

ARCHIVE_ARGS=(
  xcodebuild archive
  -workspace "$WORKSPACE"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "$DESTINATION"
  -archivePath "$ARCHIVE_PATH"
  -derivedDataPath "$DERIVED_DATA_PATH"
)
EXPORT_ARGS=(
  xcodebuild -exportArchive
  -archivePath "$ARCHIVE_PATH"
  -exportPath "$EXPORT_PATH"
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
)

if [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
  ARCHIVE_ARGS+=(-allowProvisioningUpdates)
  EXPORT_ARGS+=(-allowProvisioningUpdates)
fi
if [[ "$ALLOW_PROVISIONING_DEVICE_REGISTRATION" == "1" ]]; then
  ARCHIVE_ARGS+=(-allowProvisioningDeviceRegistration)
  EXPORT_ARGS+=(-allowProvisioningDeviceRegistration)
fi

echo "Archiving $SCHEME..."
"${ARCHIVE_ARGS[@]}"

echo "Exporting IPA..."
"${EXPORT_ARGS[@]}"

EXPORTED_IPA="$(find "$EXPORT_PATH" -maxdepth 1 -name "*.ipa" -print -quit)"
if [[ -z "$EXPORTED_IPA" ]]; then
  echo "No IPA was exported under $EXPORT_PATH." >&2
  exit 1
fi

rm -f "$FINAL_IPA_PATH"
cp "$EXPORTED_IPA" "$FINAL_IPA_PATH"

echo "Demo IPA: $FINAL_IPA_PATH"
echo "Archive: $ARCHIVE_PATH"

#!/usr/bin/env bash
set -euo pipefail

COMPONENT_NAME="AgoraAgentClientToolkit"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="${SCHEME:-$COMPONENT_NAME}"
DESTINATION="${DESTINATION:-generic/platform=iOS Simulator}"
SDK="${SDK:-iphonesimulator}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/spm-derived-data}"
PACKAGE_WORK_ROOT="${PACKAGE_WORK_ROOT:-/private/tmp/$COMPONENT_NAME-spm-package}"
PACKAGE_ROOT="$PACKAGE_WORK_ROOT/root"

cd "$ROOT_DIR"

if [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
  echo "Missing Package.swift." >&2
  exit 1
fi

echo "Validating Package.swift..."
swift package dump-package >/dev/null

rm -rf "$PACKAGE_ROOT"
mkdir -p "$PACKAGE_ROOT"
ln -s "$ROOT_DIR/Package.swift" "$PACKAGE_ROOT/Package.swift"
ln -s "$ROOT_DIR/$COMPONENT_NAME" "$PACKAGE_ROOT/$COMPONENT_NAME"

echo "Resolving Swift package dependencies..."
(
  cd "$PACKAGE_ROOT"
  xcodebuild -resolvePackageDependencies \
    -scheme "$SCHEME" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -quiet
)

echo "Building $SCHEME for $DESTINATION..."
(
  cd "$PACKAGE_ROOT"
  xcodebuild build \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -sdk "$SDK" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet
)

echo "SPM verification succeeded."

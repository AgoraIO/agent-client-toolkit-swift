#!/usr/bin/env bash
set -euo pipefail

COMPONENT_NAME="AgoraAgentClientToolkit"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_WORK_ROOT="${PACKAGE_WORK_ROOT:-/private/tmp/$COMPONENT_NAME-spm-source-package}"
KEEP_STAGING="${KEEP_STAGING:-0}"

cd "$ROOT_DIR"

if [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
  echo "Missing Package.swift." >&2
  exit 1
fi

VERSION="${VERSION:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/bin/ruby -e "spec = File.read('AgoraAgentClientToolkit/AgoraAgentClientToolkit.podspec'); puts spec[/s\\.version\\s*=\\s*['\\\"]([^'\\\"]+)/, 1]")"
fi
if [[ -z "$VERSION" ]]; then
  echo "Unable to resolve version. Pass VERSION=1.0.0." >&2
  exit 1
fi

RUN_ID="$(date +%Y%m%d%H%M%S)"
RUN_ROOT="${RUN_ROOT:-$ROOT_DIR/build/internal-spm/$COMPONENT_NAME-$VERSION-$RUN_ID}"
STAGING_ROOT="${STAGING_ROOT:-$PACKAGE_WORK_ROOT/$RUN_ID/staging}"
PACKAGE_ROOT="$STAGING_ROOT/$COMPONENT_NAME-$VERSION"
ZIP_PATH="${ZIP_PATH:-$RUN_ROOT/$COMPONENT_NAME-$VERSION-spm-source.zip}"

cleanup() {
  if [[ "$KEEP_STAGING" != "1" ]]; then
    rm -rf "$STAGING_ROOT"
  fi
}
trap cleanup EXIT

rm -rf "$STAGING_ROOT" "$ZIP_PATH"
mkdir -p "$PACKAGE_ROOT" "$(dirname "$ZIP_PATH")"

cp "$ROOT_DIR/Package.swift" "$PACKAGE_ROOT/Package.swift"
if [[ -f "$ROOT_DIR/Package.resolved" ]]; then
  cp "$ROOT_DIR/Package.resolved" "$PACKAGE_ROOT/Package.resolved"
fi

mkdir -p "$PACKAGE_ROOT/$COMPONENT_NAME"
cp -R "$ROOT_DIR/$COMPONENT_NAME/AgoraAgentClientToolkit" "$PACKAGE_ROOT/$COMPONENT_NAME/"
for file in README.md README.zh.md; do
  if [[ -f "$ROOT_DIR/$COMPONENT_NAME/$file" ]]; then
    cp "$ROOT_DIR/$COMPONENT_NAME/$file" "$PACKAGE_ROOT/$COMPONENT_NAME/$file"
  fi
done

echo "Creating internal SwiftPM source zip..."
(
  cd "$STAGING_ROOT"
  /usr/bin/zip -qry "$ZIP_PATH" "$COMPONENT_NAME-$VERSION"
)

echo "Internal SwiftPM source zip: $ZIP_PATH"
echo "Zip contents:"
/usr/bin/unzip -l "$ZIP_PATH"

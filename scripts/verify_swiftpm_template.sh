#!/usr/bin/env bash
set -euo pipefail

COMPONENT_NAME="AgoraAgentClientToolkit"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_ROOT="$ROOT_DIR/swiftpm_template"
PACKAGE_DIR="$TEMPLATE_ROOT/sdk/$COMPONENT_NAME"
PACKAGE_SWIFT="$PACKAGE_DIR/Package.swift"
BUILD_YAML="$TEMPLATE_ROOT/ci/build.yaml"

if [[ ! -f "$PACKAGE_SWIFT" ]]; then
  echo "Missing SwiftPM template manifest: $PACKAGE_SWIFT" >&2
  exit 1
fi

if [[ ! -f "$BUILD_YAML" ]]; then
  echo "Missing SwiftPM template CI config: $BUILD_YAML" >&2
  exit 1
fi

if ! grep -Eq 'name:[[:space:]]*"AgoraAgentClientToolkit"' "$PACKAGE_SWIFT"; then
  echo "Package.swift must declare binary target name AgoraAgentClientToolkit." >&2
  exit 1
fi

if ! grep -Eq 'url:[[:space:]]*"\{AgoraAgentClientToolkit_url\}"' "$PACKAGE_SWIFT"; then
  echo "Package.swift binary target must use {AgoraAgentClientToolkit_url}." >&2
  exit 1
fi

if ! grep -Eq 'checksum:[[:space:]]*"\{AgoraAgentClientToolkit_checksum\}"' "$PACKAGE_SWIFT"; then
  echo "Package.swift binary target must use {AgoraAgentClientToolkit_checksum}." >&2
  exit 1
fi

/usr/bin/python3 - "$PACKAGE_SWIFT" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
for match in re.finditer(r"\.binaryTarget\s*\((.*?)\)", text, re.DOTALL):
    if re.search(r"\bpath\s*:", match.group(1)):
        print("Package.swift binary target must not use path:.", file=sys.stderr)
        sys.exit(1)
PY

if ! grep -Fq -- '--src {src[name]} --working-directory {src[parent]}' "$BUILD_YAML"; then
  echo "build.yaml must zip each xcframework from its parent directory." >&2
  exit 1
fi

if ! grep -Fq -- '--dest {env[cwd]}/dist/{src[stem]}.zip' "$BUILD_YAML"; then
  echo "build.yaml must write dist/{src[stem]}.zip." >&2
  exit 1
fi

WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/swiftpm-template-verify.XXXXXX")"
trap 'rm -rf "$WORK_ROOT"' EXIT

mkdir -p "$WORK_ROOT/sdk/$COMPONENT_NAME/$COMPONENT_NAME.xcframework"
cp "$PACKAGE_SWIFT" "$WORK_ROOT/sdk/$COMPONENT_NAME/Package.swift"
cp -R "$PACKAGE_DIR/Sources" "$WORK_ROOT/sdk/$COMPONENT_NAME/Sources"
cat > "$WORK_ROOT/sdk/$COMPONENT_NAME/$COMPONENT_NAME.xcframework/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
PLIST

mkdir -p "$WORK_ROOT/dist"
(
  cd "$WORK_ROOT/sdk/$COMPONENT_NAME"
  /usr/bin/zip -qry "$WORK_ROOT/dist/$COMPONENT_NAME.zip" "$COMPONENT_NAME.xcframework"
)

ZIP_ENTRIES="$(/usr/bin/unzip -Z1 "$WORK_ROOT/dist/$COMPONENT_NAME.zip")"
if ! grep -Fxq "$COMPONENT_NAME.xcframework/Info.plist" <<< "$ZIP_ENTRIES"; then
  echo "SwiftPM artifact zip must contain root $COMPONENT_NAME.xcframework/Info.plist." >&2
  exit 1
fi

if grep -Eq '^[^/]+/[^/]+\.xcframework/' <<< "$ZIP_ENTRIES"; then
  echo "SwiftPM artifact zip must not wrap the xcframework in a parent directory." >&2
  exit 1
fi

cp "$PACKAGE_SWIFT" "$WORK_ROOT/dist/Package.swift"
cp -R "$WORK_ROOT/sdk/$COMPONENT_NAME/Sources" "$WORK_ROOT/dist/Sources"
/usr/bin/python3 - "$WORK_ROOT/dist/Package.swift" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
text = text.replace("{AgoraAgentClientToolkit_url}", "https://example.com/swiftpm/agent-client-toolkit-swift/1.0.0-rc.1/AgoraAgentClientToolkit.zip")
text = text.replace("{AgoraAgentClientToolkit_checksum}", "0" * 64)
path.write_text(text)
PY

(
  cd "$WORK_ROOT/dist"
  swift package dump-package >/dev/null
)

echo "SwiftPM template verification succeeded."

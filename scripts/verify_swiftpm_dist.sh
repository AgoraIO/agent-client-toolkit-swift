#!/usr/bin/env bash
set -euo pipefail

COMPONENT_NAME="AgoraAgentClientToolkit"
PACKAGE_DIR="${1:-dist}"
ZIP_PATH="$PACKAGE_DIR/$COMPONENT_NAME.zip"
PACKAGE_SWIFT="$PACKAGE_DIR/Package.swift"
DEPENDENCIES_SOURCE="$PACKAGE_DIR/Sources/${COMPONENT_NAME}Dependencies/${COMPONENT_NAME}Dependencies.swift"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Missing SwiftPM artifact zip: $ZIP_PATH" >&2
  exit 1
fi

if [[ ! -f "$PACKAGE_SWIFT" ]]; then
  echo "Missing SwiftPM Package.swift: $PACKAGE_SWIFT" >&2
  exit 1
fi

if [[ ! -f "$DEPENDENCIES_SOURCE" ]]; then
  echo "Missing SwiftPM dependency wrapper source: $DEPENDENCIES_SOURCE" >&2
  exit 1
fi

echo "Checking zip structure..."
/usr/bin/unzip -l "$ZIP_PATH" | head

ZIP_ENTRIES="$(/usr/bin/unzip -Z1 "$ZIP_PATH")"
if ! grep -Fxq "$COMPONENT_NAME.xcframework/Info.plist" <<< "$ZIP_ENTRIES"; then
  echo "Expected $COMPONENT_NAME.xcframework/Info.plist at the zip root." >&2
  exit 1
fi

if grep -Eq '(^Info\.plist$|^[^/]+/[^/]+\.xcframework/)' <<< "$ZIP_ENTRIES"; then
  echo "SwiftPM artifact zip has an invalid root layout." >&2
  exit 1
fi

echo "Checking Package.swift binaryTarget..."
grep -n "binaryTarget" -A5 "$PACKAGE_SWIFT"

/usr/bin/python3 - "$PACKAGE_SWIFT" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
binary_targets = list(re.finditer(r"\.binaryTarget\s*\((.*?)\)", text, re.DOTALL))
if not binary_targets:
    print("Package.swift does not contain a binaryTarget.", file=sys.stderr)
    sys.exit(1)

for match in binary_targets:
    body = match.group(1)
    if re.search(r"\bpath\s*:", body):
        print("Package.swift binaryTarget must not use path:.", file=sys.stderr)
        sys.exit(1)
    if "{AgoraAgentClientToolkit_url}" in body or "{AgoraAgentClientToolkit_checksum}" in body:
        print("Package.swift still contains SwiftPM placeholder values.", file=sys.stderr)
        sys.exit(1)
    if not re.search(r'\burl\s*:\s*"https://[^"]+/AgoraAgentClientToolkit\.zip"', body):
        print("Package.swift binaryTarget must contain the HTTPS artifact URL.", file=sys.stderr)
        sys.exit(1)
    if not re.search(r'\bchecksum\s*:\s*"[a-fA-F0-9]{64}"', body):
        print("Package.swift binaryTarget must contain a 64-character checksum.", file=sys.stderr)
        sys.exit(1)
PY

echo "Resolving Swift package..."
(
  cd "$PACKAGE_DIR"
  swift package resolve
)

echo "SwiftPM dist verification succeeded."

# Publishing

This document is for maintainers who need to package the iOS library for CocoaPods and Swift Package Manager publishing.

## Artifact Names

```text
CocoaPods: AgoraAgentClientToolkit
SwiftPM package identity: agent-client-toolkit-swift
SwiftPM product: AgoraAgentClientToolkit
```

The release version comes from `AgoraAgentClientToolkit/AgoraAgentClientToolkit.podspec`:

```ruby
s.version = '2.9.0'
```

You can override the version for a local packaging run with:

```bash
VERSION=<version> scripts/build_internal_cocoapods_zip.sh
VERSION=<version> scripts/build_internal_spm_source_zip.sh
VERSION=<version> scripts/build_internal_spm_binary_zip.sh
```

## Package the CocoaPods Release Zip

Install demo workspace dependencies first:

```bash
pod install
```

Run:

```bash
VERSION=2.9.0 scripts/build_internal_cocoapods_zip.sh
```

The generated zip is written under:

```text
build/internal-cocoapods/AgoraAgentClientToolkit-<version>-<timestamp>/AgoraAgentClientToolkit-<version>.zip
```

The zip contains:

```text
AgoraAgentClientToolkit.podspec
sdk/
`-- AgoraAgentClientToolkit.xcframework/
```

## Package the SwiftPM Source Zip

Run:

```bash
VERSION=2.9.0 scripts/build_internal_spm_source_zip.sh
```

The generated zip is written under:

```text
build/internal-spm/AgoraAgentClientToolkit-<version>-<timestamp>/AgoraAgentClientToolkit-<version>-spm-source.zip
```

The zip contains:

```text
AgoraAgentClientToolkit-<version>/
|-- Package.swift
|-- Package.resolved
`-- AgoraAgentClientToolkit/
    |-- README.md
    `-- AgoraAgentClientToolkit/
        `-- Classes/
```

`Package.resolved` is included only when it exists in the repository.

## Package the SwiftPM Binary Zip

Use this package shape when the publishing pipeline expects a SwiftPM binary
artifact. The Rehoboam input is under `swiftpm_template/sdk/AgoraAgentClientToolkit/`.
The template `Package.swift` must use the `url` / `checksum` placeholders for
the binary target; do not use a local `path:` binary target in this template.

```swift
.binaryTarget(
    name: "AgoraAgentClientToolkit",
    url: "{AgoraAgentClientToolkit_url}",
    checksum: "{AgoraAgentClientToolkit_checksum}"
)
```

The CI input shape must be:

```text
sdk/
`-- AgoraAgentClientToolkit/
    |-- Package.swift
    |-- Sources/
    |   `-- AgoraAgentClientToolkitDependencies/
    `-- AgoraAgentClientToolkit.xcframework/
```

The artifact uploaded for SwiftPM must be a zip whose top-level entry is the
xcframework directory itself:

```text
AgoraAgentClientToolkit.zip
`-- AgoraAgentClientToolkit.xcframework/
    |-- Info.plist
    `-- ...
```

The final GitHub repository should contain the rewritten `Package.swift` and
the `Sources/AgoraAgentClientToolkitDependencies/` wrapper target. It should
not contain the `.xcframework` directory or the zip artifact.

Install demo workspace dependencies first:

```bash
pod install
```

Run:

```bash
VERSION=2.9.0 scripts/build_internal_spm_binary_zip.sh
```

The generated zip is written under:

```text
build/internal-spm/AgoraAgentClientToolkit-<version>-binary-<timestamp>/AgoraAgentClientToolkit.zip
```

The generated manifest is written under:

```text
build/internal-spm/AgoraAgentClientToolkit-<version>-binary-<timestamp>/Package.swift
```

The binary manifest keeps `AgoraAgentClientToolkit` as the public product and
adds an internal dependency anchor target so SwiftPM resolves Agora RTC and RTM
alongside the binary framework.

The binary package pins SwiftPM dependencies by default:

```text
AgoraRtcEngine_iOS == 4.5.1
AgoraRTM_iOS == 2.2.8
```

Override them only for a deliberate compatibility test:

```bash
RTC_VERSION=4.5.1 RTM_VERSION=2.2.8 VERSION=2.9.0 scripts/build_internal_spm_binary_zip.sh
```

Override the rewritten artifact URL when validating a concrete release path:

```bash
ARTIFACT_URL=https://.../swiftpm/agent-client-toolkit-swift/2.9.0/AgoraAgentClientToolkit.zip \
  VERSION=2.9.0 scripts/build_internal_spm_binary_zip.sh
```

SwiftPM binary target URLs must use `https://`.

Reuse an existing generated xcframework without archiving again:

```bash
EXISTING_XCFRAMEWORK=/path/to/AgoraAgentClientToolkit.xcframework \
  VERSION=2.9.0 scripts/build_internal_spm_binary_zip.sh
```

Validate the generated binary package from a clean extraction directory:

```bash
cd build/internal-spm/AgoraAgentClientToolkit-2.9.0-binary-<timestamp>
unzip -l AgoraAgentClientToolkit.zip | head
grep -n "binaryTarget" -A5 Package.swift
swift package resolve
```

Or run the same checks through the repository helper:

```bash
scripts/verify_swiftpm_dist.sh build/internal-spm/AgoraAgentClientToolkit-2.9.0-binary-<timestamp>
```

The zip listing must include:

```text
AgoraAgentClientToolkit.xcframework/Info.plist
```

## Validate SwiftPM

Run:

```bash
scripts/verify_spm.sh
scripts/verify_swiftpm_template.sh
scripts/verify_swiftpm_dist.sh <generated-dist-dir>
```

`verify_spm.sh` validates the source manifest, resolves package dependencies,
and builds the `AgoraAgentClientToolkit` scheme for iOS Simulator.
`verify_swiftpm_template.sh` validates the Rehoboam SwiftPM binary template,
including the placeholder manifest and expected artifact zip structure.
`verify_swiftpm_dist.sh` validates the rewritten SwiftPM binary package before
publishing.

## Pre-Publish Checklist

1. The release version is a non-SNAPSHOT release version.
2. `Package.swift` uses package identity `agent-client-toolkit-swift`.
3. The SwiftPM product is `AgoraAgentClientToolkit`.
4. The CocoaPods pod name and Swift module name are `AgoraAgentClientToolkit`.
5. CocoaPods dependencies are `AgoraRtcEngine_iOS >= 4.5.1` and `AgoraRtm/RtmKit >= 2.2.3`.
6. SwiftPM source dependencies are `AgoraRtcEngine_iOS >= 4.5.1` and `AgoraRTM_iOS >= 2.2.8`.
7. The CocoaPods zip includes `AgoraAgentClientToolkit.podspec` and `AgoraAgentClientToolkit.xcframework`.
8. The SwiftPM source zip includes `Package.swift` and component source files.
9. `swiftpm_template/sdk/AgoraAgentClientToolkit/Package.swift` uses `.binaryTarget(name:url:checksum:)` placeholders, not `path:`.
10. The SwiftPM binary artifact zip contains root `AgoraAgentClientToolkit.xcframework/Info.plist`.
11. The rewritten SwiftPM binary `Package.swift` contains the artifact URL and SHA-256 checksum, not placeholders and not `path:`.
12. `swift package resolve` passes from the rewritten SwiftPM binary package directory.
13. SwiftPM binary dependencies are pinned to `AgoraRtcEngine_iOS == 4.5.1` and `AgoraRTM_iOS == 2.2.8`.
14. Public README files contain only developer-facing installation and usage instructions.

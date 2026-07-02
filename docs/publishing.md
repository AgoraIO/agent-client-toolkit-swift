# Publishing

This document is for maintainers who need to prepare Rehoboam upload packages for the iOS CocoaPods and Swift Package Manager releases.

## Artifact Names

```text
CocoaPods: AgoraAgentClientToolkit
SwiftPM package identity: agent-client-toolkit-swift
SwiftPM product: AgoraAgentClientToolkit
```

For Rehoboam packaging, pass the version explicitly:

```bash
VERSION=<version> scripts/build_rehoboam_cocoapods_input_zip.sh
VERSION=<version> scripts/build_rehoboam_swiftpm_input_zip.sh
```

## SemVer and Changelog Gate

Every release must update `CHANGELOG.md`.

- Patch releases are for compatible fixes, parser hardening, documentation corrections, and packaging metadata fixes.
- Minor releases may add optional APIs, optional event fields, new callbacks with optional/default behavior, or new supported protocol events.
- Major releases are required for source or binary incompatible public API changes, changed defaults, changed callback timing, changed package identity, or higher minimum platform baselines that exclude existing consumers.

Release candidates must include changelog entries. Do not promote an RC to final until package validation and sample or clean-app validation pass.

## Package the Rehoboam CocoaPods Input Zip

Install demo workspace dependencies first:

```bash
pod install
```

Run:

```bash
VERSION=2.9.0-rc.1 scripts/build_rehoboam_cocoapods_input_zip.sh
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

Upload this zip to Rehoboam as the CocoaPods release input. For the Rehoboam
flow, leave `FILE_URL` unset unless the platform request explicitly asks for a
prefilled binary URL; the staged podspec otherwise keeps the
`REPLACE_WITH_BINARY_ZIP_URL` placeholder for the platform-side rewrite.

## Package the Rehoboam SwiftPM Input Zip

SwiftPM is also published through Rehoboam. The maintainer-facing command is:

```bash
VERSION=2.9.0-rc.1 scripts/build_rehoboam_swiftpm_input_zip.sh
```

The script prints the generated Rehoboam upload file:

```text
build/internal-spm/AgoraAgentClientToolkit-<version>-rehoboam-<timestamp>/AgoraAgentClientToolkit-<version>-rehoboam-input.zip
```

Upload that zip to Rehoboam for the SwiftPM release.

Internally, the uploaded zip contains `swiftpm_template/`. Rehoboam uses
`swiftpm_template/sdk/AgoraAgentClientToolkit/Package.swift` as the input
manifest, and that manifest must use `url` / `checksum` placeholders for the
binary target:

```swift
.binaryTarget(
    name: "AgoraAgentClientToolkit",
    url: "{AgoraAgentClientToolkit_url}",
    checksum: "{AgoraAgentClientToolkit_checksum}"
)
```

The CI input shape must be:

```text
swiftpm_template/
|-- ci/
|   `-- build.yaml
`-- sdk/
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

The binary manifest keeps `AgoraAgentClientToolkit` as the public product and
adds an internal dependency anchor target so SwiftPM resolves Agora RTC and RTM
alongside the binary framework.

The binary package pins SwiftPM dependencies by default:

```text
AgoraRtcEngine_iOS == 4.5.1
AgoraRTM_iOS == 2.2.8
```

Rehoboam validates the uploaded package and the generated SwiftPM package. Its
platform-side release checks must include the following checks; run them locally
only when debugging generated Rehoboam output:

```bash
unzip -l dist/AgoraAgentClientToolkit.zip | head
grep -n "binaryTarget" -A5 dist/Package.swift
cd dist
swift package resolve
```

The zip listing must include:

```text
AgoraAgentClientToolkit.xcframework/Info.plist
```

## Pre-Publish Checklist

1. `CHANGELOG.md` has a release entry for the version being packaged. The first public release must establish the compatibility baseline.
2. Public API changes in `AgoraAgentClientToolkit/AgoraAgentClientToolkit/Classes/ConversationalAIAPI.swift` and `ConversationalAIAPIImpl.swift` have been reviewed for SemVer impact.
3. Public README files are aligned with the API surface and contain only developer-facing installation and usage instructions.
4. The release version is a non-SNAPSHOT version, for example `2.9.0-rc.1` or `2.9.0`.
5. The same version is used for both CocoaPods and SwiftPM Rehoboam input packages when they are released together.
6. The staged CocoaPods podspec inside the generated zip has the expected `s.version`.
7. The CocoaPods zip includes `AgoraAgentClientToolkit.podspec` and `AgoraAgentClientToolkit.xcframework`.
8. The CocoaPods pod name and Swift module name are `AgoraAgentClientToolkit`.
9. CocoaPods dependencies are `AgoraRtcEngine_iOS >= 4.5.1` and `AgoraRtm/RtmKit >= 2.2.3`.
10. `swiftpm_template/sdk/AgoraAgentClientToolkit/Package.swift` uses `.binaryTarget(name:url:checksum:)` placeholders, not `path:`.
11. The SwiftPM binary artifact zip generated by Rehoboam contains root `AgoraAgentClientToolkit.xcframework/Info.plist`.
12. The rewritten SwiftPM binary `Package.swift` contains the artifact URL and SHA-256 checksum, not placeholders and not `path:`.
13. Rehoboam `swift package resolve` passes from the rewritten SwiftPM binary package directory.
14. SwiftPM binary dependencies are pinned to `AgoraRtcEngine_iOS == 4.5.1` and `AgoraRTM_iOS == 2.2.8`.

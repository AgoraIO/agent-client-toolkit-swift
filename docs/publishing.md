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
VERSION=<version> scripts/build_rehoboam_swiftpm_input_zip.sh
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

## Package the SwiftPM Rehoboam Input Zip

Use this package when uploading a SwiftPM release input file to Rehoboam. The
maintainer-facing command is:

```bash
VERSION=2.9.0-rc.1 scripts/build_rehoboam_swiftpm_input_zip.sh
```

The script prints the generated upload file:

```text
build/internal-spm/AgoraAgentClientToolkit-<version>-rehoboam-<timestamp>/AgoraAgentClientToolkit-<version>-rehoboam-input.zip
```

Upload that zip to the internal CDN, then paste the uploaded URL into the
Rehoboam SwiftPM `File URL` field.

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
release checks must include:

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

## Validate SwiftPM

Run:

```bash
scripts/verify_spm.sh
```

`verify_spm.sh` validates the source manifest, resolves package dependencies,
and builds the `AgoraAgentClientToolkit` scheme for iOS Simulator.

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

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
s.version = '1.0.0'
```

You can override the version for a local packaging run with:

```bash
VERSION=<version> scripts/build_internal_cocoapods_zip.sh
VERSION=<version> scripts/build_internal_spm_source_zip.sh
```

## Package the CocoaPods Release Zip

Install demo workspace dependencies first:

```bash
pod install
```

Run:

```bash
VERSION=1.0.0 scripts/build_internal_cocoapods_zip.sh
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
VERSION=1.0.0 scripts/build_internal_spm_source_zip.sh
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

## Validate SwiftPM

Run:

```bash
scripts/verify_spm.sh
```

This validates the manifest, resolves package dependencies, and builds the `AgoraAgentClientToolkit` scheme for iOS Simulator.

## Pre-Publish Checklist

1. The release version is a non-SNAPSHOT release version.
2. `Package.swift` uses package identity `agent-client-toolkit-swift`.
3. The SwiftPM product is `AgoraAgentClientToolkit`.
4. The CocoaPods pod name and Swift module name are `AgoraAgentClientToolkit`.
5. CocoaPods dependencies are `AgoraRtcEngine_iOS >= 4.5.1` and `AgoraRtm/RtmKit >= 2.2.3`.
6. SwiftPM dependencies are `AgoraRtcEngine_iOS >= 4.5.1` and `AgoraRTM_iOS >= 2.2.8`.
7. The CocoaPods zip includes `AgoraAgentClientToolkit.podspec` and `AgoraAgentClientToolkit.xcframework`.
8. The SwiftPM zip includes `Package.swift` and component source files.
9. Public README files contain only developer-facing installation and usage instructions.

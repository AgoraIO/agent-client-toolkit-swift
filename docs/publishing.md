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
VERSION=<version> scripts/build_internal_spm_binary_zip.sh
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

## Package the SwiftPM Binary Zip

Use this package shape when the publishing pipeline expects a SwiftPM binary
artifact. The zip root contains `Package.swift` and the binary framework
directly, matching the internal release guide.

Install demo workspace dependencies first:

```bash
pod install
```

Run:

```bash
VERSION=1.0.0 scripts/build_internal_spm_binary_zip.sh
```

The generated zip is written under:

```text
build/internal-spm/AgoraAgentClientToolkit-<version>-binary-<timestamp>/AgoraAgentClientToolkit-<version>-spm-binary.zip
```

The zip contains:

```text
Package.swift
README.md
Sources/
`-- AgoraAgentClientToolkitDependencies/
AgoraAgentClientToolkit.xcframework/
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
RTC_VERSION=4.5.1 RTM_VERSION=2.2.8 VERSION=1.0.0 scripts/build_internal_spm_binary_zip.sh
```

Validate the generated binary package from a clean extraction directory:

```bash
rm -rf /private/tmp/AgoraAgentClientToolkit-spm-binary-verify
mkdir -p /private/tmp/AgoraAgentClientToolkit-spm-binary-verify
unzip -q build/internal-spm/AgoraAgentClientToolkit-1.0.0-binary-<timestamp>/AgoraAgentClientToolkit-1.0.0-spm-binary.zip \
  -d /private/tmp/AgoraAgentClientToolkit-spm-binary-verify
cd /private/tmp/AgoraAgentClientToolkit-spm-binary-verify
swift package dump-package >/dev/null
xcodebuild build \
  -scheme agent-client-toolkit-swift \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/AgoraAgentClientToolkit-spm-binary-verify/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -quiet
```

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
6. SwiftPM source dependencies are `AgoraRtcEngine_iOS >= 4.5.1` and `AgoraRTM_iOS >= 2.2.8`.
7. The CocoaPods zip includes `AgoraAgentClientToolkit.podspec` and `AgoraAgentClientToolkit.xcframework`.
8. The SwiftPM source zip includes `Package.swift` and component source files.
9. The SwiftPM binary zip includes root `Package.swift` and root `AgoraAgentClientToolkit.xcframework`.
10. SwiftPM binary dependencies are pinned to `AgoraRtcEngine_iOS == 4.5.1` and `AgoraRTM_iOS == 2.2.8`.
11. Public README files contain only developer-facing installation and usage instructions.

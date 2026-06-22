# Internal Component Publishing Notes

## Current Scope

This repository keeps CocoaPods metadata for internal distribution, but it does not use the public CocoaPods trunk release flow.

The internal iOS component metadata is:

| Field | Value |
| --- | --- |
| Pod name | `AgoraAgentClientToolkit` |
| Swift module name | `AgoraAgentClientToolkit` |
| Minimum iOS version | `15.0` |
| Swift version | `5.0` |
| Package shape | `static_framework = true` |
| Bitcode | `ENABLE_BITCODE = NO` |

## What Can Be Removed

Public CocoaPods publishing steps are not required for the internal release path:

- `pod trunk push`
- CocoaPods trunk account setup
- Public trunk release documentation
- Public repository or public tag assumptions for release automation

## What Must Stay

The `.podspec` must stay because the internal publishing path still needs component metadata.

The podspec is the source of truth for:

- pod name
- Swift module name
- version
- iOS deployment target
- Swift version
- static framework packaging
- bitcode setting
- source file mapping
- RTC and RTM dependencies

## Internal CocoaPods Zip Release

The internal binary release flow expects a CocoaPods release zip to contain a podspec and the binary framework set. This repository keeps one source podspec and one binary podspec template for different jobs:

| File | Purpose |
| --- | --- |
| `AgoraAgentClientToolkit.podspec` | Source pod used by local sample development through `pod 'AgoraAgentClientToolkit', :path => './AgoraAgentClientToolkit'` |
| `AgoraAgentClientToolkit.binary.podspec.template` | Binary podspec template copied into the release zip as `AgoraAgentClientToolkit.podspec` |

Build the internal CocoaPods zip with:

```bash
scripts/build_internal_cocoapods_zip.sh
```

If the final Jenkins-accessible zip URL is already known, pass it into the staged podspec:

```bash
FILE_URL="https://example.com/AgoraAgentClientToolkit-0.0.1.zip" scripts/build_internal_cocoapods_zip.sh
```

The generated zip is written under `build/internal-cocoapods/`. Package staging is created under `/private/tmp` and removed automatically, so `build/internal-cocoapods/` only needs to expose the final zip.

Each build run uses an isolated Xcode `DerivedData` directory under `/private/tmp` and cleans it by default to avoid stale module-cache dependency-scanning failures.

The zip has this structure:

```text
AgoraAgentClientToolkit-0.0.1.zip
|-- AgoraAgentClientToolkit.podspec
`-- sdk/
    `-- AgoraAgentClientToolkit.xcframework/
```

To keep the temporary staging directory for troubleshooting, run:

```bash
KEEP_STAGING=1 scripts/build_internal_cocoapods_zip.sh
```

Use these release form fields:

| Field | Value |
| --- | --- |
| Release Channel | `CocoaPods` |
| Artifacts Version / Version | Same as `s.version` in the podspec |
| File Link / File URL | Jenkins-accessible URL for the generated zip |
| Pods Repository | `AgoraAgentClientToolkit` |
| Part Release List / SO_LIST | Leave empty for a full release, or use `AgoraAgentClientToolkit.xcframework` only if the release form requires a partial-release file list |
| Subspec Publish | Off |

The binary podspec uses `s.vendored_frameworks = 'sdk/AgoraAgentClientToolkit.xcframework'` and keeps RTC/RTM as CocoaPods dependencies instead of bundling their frameworks in this zip.

## Internal Source Placeholder

`AgoraAgentClientToolkit.podspec` uses `REPLACE_WITH_INTERNAL_SOURCE_URL` as the source URL placeholder.

Replace that value with the internal source URL or artifact URL required by source-pod packaging. Do not replace it with a public CocoaPods trunk release step.

`AgoraAgentClientToolkit.binary.podspec.template` uses `REPLACE_WITH_BINARY_ZIP_URL` as the binary zip URL placeholder. The build script replaces it when `FILE_URL` is provided.

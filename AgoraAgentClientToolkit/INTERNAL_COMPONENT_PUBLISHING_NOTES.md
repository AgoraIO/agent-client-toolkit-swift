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

The `.podspec` must stay because the internal `rehoaban` publishing path still needs component metadata.

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

## Rehoaban Source Placeholder

`AgoraAgentClientToolkit.podspec` uses `REPLACE_WITH_INTERNAL_REHOABAN_SOURCE_URL` as the source URL placeholder.

Replace that value with the internal source URL or artifact URL required by `rehoaban` during packaging. Do not replace it with a public CocoaPods trunk release step.

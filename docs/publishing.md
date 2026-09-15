# Releasing

This is the public maintainer checklist for preparing and verifying iOS SDK
releases. Publishing credentials and service-specific operations belong in
private maintainer documentation.

## Source and Distribution

| Purpose | Branch or tag |
|---------|---------------|
| Source development and release PRs | `source/main` |
| Validated source release | `source/vX.Y.Z` |
| SwiftPM binary distribution | `main` |
| SwiftPM consumer version | `X.Y.Z` on the distribution history |

The CocoaPods name is `agent-client-toolkit-swift`; the Swift module and
SwiftPM product remain `AgoraAgentClientToolkit`. Release CocoaPods and
SwiftPM with the same version when shipping them together. Replace `X.Y.Z`
in every example with the intended unused stable SemVer version.

Source tags record the code used to build a release and trigger CI to build
downloadable release inputs. They do not publish CocoaPods or SwiftPM packages.
Do not create an `X.Y.Z` distribution tag on a
source commit. Never move a release tag or overwrite a published version;
prepare a new version for fixes after publication.

## Prepare the Release PR

1. Confirm that the source tag, SwiftPM version tag, and CocoaPods version
   are unused. Inspect the public tags and CocoaPods spec repository used
   by consumers:

   ```bash
   git ls-remote --tags https://github.com/AgoraIO/agent-client-toolkit-swift.git refs/tags/source/vX.Y.Z refs/tags/X.Y.Z
   pod spec which agent-client-toolkit-swift --version=X.Y.Z
   ```

   `pod spec which` searches installed spec repositories. Refresh those
   repositories with `pod repo update` or inspect their upstream index before
   deciding that a missing version is available. Network failures do not
   prove that a version is unused.

2. Synchronize every SDK version location:

   | Location | Value |
   |----------|-------|
   | `AgoraAgentClientToolkit/agent-client-toolkit-swift.podspec` | `s.version` |
   | `AgoraAgentClientToolkit/agent-client-toolkit-swift.binary.podspec.template` | `s.version` |
   | `AgoraAgentClientToolkit/AgoraAgentClientToolkit/Classes/ConversationalAIAPIImpl.swift` | `ConversationalAIAPIImpl.version` |
   | `AgoraAgentClientToolkit/AgoraAgentClientToolkit/Classes/Transcript/TranscriptController.swift` | `TranscriptController.version` |

   All four values must be `X.Y.Z`. An explicit packaging version does not
   update compiled diagnostic constants. Keep the root README, component
   README, and published-dependency example in `Podfile` aligned. Run
   `pod install` after changing the local podspec and include the resulting
   `Podfile.lock` update. The demo's app version is independent of the SDK.

3. Add a dated entry to [CHANGELOG.md](../CHANGELOG.md). Review public APIs,
   default behavior, callback timing, package identity, and minimum platform
   changes for compatibility. Use patch versions for compatible fixes, minor
   versions for compatible additions, and major versions for breaking
   changes. Document behavior changes, the compatibility rationale, and any
   required migration or opt-in settings in the release notes.

4. Open the release PR against `source/main`. All backend, Swift, iOS demo
   build, and Docker PR checks must pass. Use Python 3.10+, Xcode 16+, and
   CocoaPods 1.16.2 to reproduce the source checks locally:

   ```bash
   python3 -m venv server/.venv
   server/.venv/bin/python -m pip install -r server/requirements.txt -r server/requirements-dev.txt
   server/.venv/bin/python -m pytest server/tests -q
   ./scripts/test_swift.sh
   pod _1.16.2_ install --deployment
   xcodebuild -workspace VoiceAgent.xcworkspace -scheme VoiceAgent \
     -configuration Debug -sdk iphonesimulator \
     -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
   ```

   Validate voice startup, transcripts, agent state, messaging, interrupt,
   mute, manual SOS/EOS, and cleanup on a physical iPhone.

## Tag the Validated Source

The source of truth for automated checks is
[Source CI](../.github/workflows/ci.yml). It runs on PRs targeting `source/main`,
pushes to `source/main`, and source tags matched by `source/**`. The artifact
job accepts only stable `source/vX.Y.Z` tags and runs after backend and iOS
source checks pass. It has no package publishing or GitHub Release creation job.
[Docker checks](../.github/workflows/docker.yml) run on PRs only.

After merging the release PR, verify successful `source/main` CI for the
exact merged commit. The source tag then starts another run against that tag.

**Distribution tags do not build artifacts.** Tags such as `X.Y.Z`, including
those created by publication automation, do not match `source/**`. Pushes to
the binary distribution branch `main` also do not match `source/main`. The
workflow has read-only repository permissions and does not push tags or call
the publisher, so publishing a binary distribution cannot start a build loop.

Use a clean checkout. These examples assume `upstream` points to
`AgoraIO/agent-client-toolkit-swift` and that you have tag push permission:

```bash
git fetch upstream source/main
git switch --detach upstream/source/main
git status --short
git rev-parse HEAD
```

Confirm that the checkout has no changes and the printed SHA is the commit
whose source CI passed. Then create and push the source tag:

```bash
git tag source/vX.Y.Z
git push upstream refs/tags/source/vX.Y.Z
```

Wait for the tag run's `release-artifacts` job, then download
`toolkit-ios-X.Y.Z` from its Artifacts section. Extract the Actions download
to obtain the two input zips, `manifest.json`, and `SHA256SUMS`. Both input
zips contain the same XCFramework binaries. The manifest records the source
tag/commit, build Xcode/Swift versions, and archive checksums. The separate
`toolkit-ios-validation-X.Y.Z` artifact contains binary consumer logs.

Artifacts are retained for 30 days; move validated inputs to release storage
before expiry. Actions artifact download URLs are not public package URLs.
Complete consumer and device validation, then use the maintainer publishing
process with those same inputs. Publication and the SwiftPM distribution tag
are separate from the source-tag step.

## Binary Build Toolchain

Release CI uses `macos-15` and explicitly selects Xcode **16.1** through
`DEVELOPER_DIR`. It fails if that version is unavailable and never silently
uses the runner default. This preserves the tested build baseline after a
developer removes older Xcode installations locally. Review the
[runner's installed Xcode versions](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md#xcode)
when updating the workflow.

CI archives once with library evolution enabled and reuses the XCFramework
for both package formats. Before uploading release artifacts, a minimal binary
consumer must import and link the device arm64 and simulator arm64/x86_64
slices under both Xcode 16.1 and 26.3. This uses the Podfile's locked RTC 4.5.1
and RTM 2.2.3 dependencies. SwiftPM's final dependency resolution and runtime
validation remain separate checks described below.

To reproduce the packaging step locally without changing the global Xcode:

```bash
pod _1.16.2_ install --deployment
DEVELOPER_DIR=/Applications/Xcode_16.1.app/Contents/Developer \
  python3 scripts/build_release_artifacts.py source/vX.Y.Z
DEVELOPER_DIR=/Applications/Xcode_16.1.app/Contents/Developer \
  python3 scripts/verify_xcframework.py \
    build/release/X.Y.Z/AgoraAgentClientToolkit.xcframework \
    --output build/release/X.Y.Z/validation/xcode-16.1
```

The builder checks the source tag format, both podspecs, and both SDK version
constants before packaging. `--check` validates versions only. It does not
create or push the supplied tag. Before raising the build Xcode version,
repeat binary consumer validation against the supported minimum toolchain;
source builds alone do not prove precompiled package compatibility.

## Validate the Distribution Artifacts

- CocoaPods: the final spec must declare `agent-client-toolkit-swift` at
  `X.Y.Z`, module `AgoraAgentClientToolkit`, an accessible binary download,
  and a matching `vendored_frameworks` path. Inspect the XCFramework's device
  and simulator slices. The current spec declares `AgoraRtcEngine_iOS >= 4.5.1`
  and `AgoraRtm/RtmKit >= 2.2.3`.
- SwiftPM: the package at distribution tag `X.Y.Z` must contain a binary
  `Package.swift` and the `Sources/AgoraAgentClientToolkitDependencies/`
  wrapper target. The public product stays `AgoraAgentClientToolkit`. Its
  binary target must use a real HTTPS URL and SHA-256 checksum, with no
  unresolved placeholders or local `path:`. The current package pins
  `AgoraRtcEngine_iOS == 4.5.1` and `AgoraRTM_iOS == 2.2.8`.
- The SwiftPM download must contain
  `AgoraAgentClientToolkit.xcframework/Info.plist` at the archive root. Keep
  the binary archive available at the manifest's URL. The distribution
  repository contains the manifest and wrapper sources; binaries are
  downloaded separately.

Compare the checksum of the downloaded archive with the binary manifest:

```bash
swift package compute-checksum /path/to/AgoraAgentClientToolkit.zip
```

## Verify the Published Release

Verify CocoaPods and SwiftPM separately. The source tag or GitHub Release
alone is not evidence that both package formats are available.

1. In a clean CocoaPods consumer app, configure the specs source intended for
   consumers and pin the version:

   ```ruby
   pod 'agent-client-toolkit-swift', 'X.Y.Z'
   ```

   Run `pod install --repo-update`, check `Podfile.lock` for the exact version,
   then build the app and import `AgoraAgentClientToolkit`. Use the published
   pod instead of the sample's local `:path` dependency.

2. In a separate SwiftPM consumer app, select exact version `X.Y.Z` in Xcode,
   or declare:

   ```swift
   .package(url: "https://github.com/AgoraIO/agent-client-toolkit-swift.git", .exact("X.Y.Z"))
   ```

   Add the `AgoraAgentClientToolkit` product, resolve dependencies, and build
   the app. Check `Package.resolved`, the binary download, and its checksum.
   Resolution alone does not verify that the app can compile and link.

3. Repeat the physical-device smoke checks with each published package format.
   Confirm SDK diagnostics report `X.Y.Z`. Record the source SHA and tag,
   distribution tag, package versions, and validation results in the release
   record. If GitHub Releases are created, label source and binary releases
   clearly and describe each package's actual publication status.

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

Source tags record the code used to build a release. They do not publish
CocoaPods or SwiftPM packages. Do not create an `X.Y.Z` distribution tag on a
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
[Source CI](../.github/workflows/ci.yml). It runs on PRs targeting `source/main`
and pushes to `source/main`. Its current tag filter is `*`, which excludes
`/` and therefore does **not** match `source/vX.Y.Z`. See the
[GitHub filter rules](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#filter-pattern-cheat-sheet).
The workflow has no package publishing or GitHub Release creation job.
[Docker checks](../.github/workflows/docker.yml) run on PRs only.

After merging the release PR, verify successful `source/main` CI for the
exact merged commit. Until the tag filter is updated, use that branch run as
the source validation record; do not expect a source tag to start a new run.

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

Build both package formats from that tagged source in a clean checkout.
Validate the final binary artifacts and consumer integration before
publication using the maintainer release process. Publication and the
SwiftPM distribution tag are separate from the source-tag step.

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

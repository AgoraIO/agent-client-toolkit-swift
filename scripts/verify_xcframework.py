#!/usr/bin/env python3
"""Compile and link an XCFramework consumer with the selected Xcode and SDKs."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shlex
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent


def framework_slice(xcframework, platform, arch):
    info = plistlib.loads((xcframework / "Info.plist").read_bytes())
    matches = [entry for entry in info["AvailableLibraries"]
               if entry["SupportedPlatform"] == "ios"
               and entry.get("SupportedPlatformVariant", "device") == platform
               and arch in entry["SupportedArchitectures"]]
    if len(matches) != 1:
        raise ValueError(f"Expected one {platform}/{arch} slice in {xcframework}")
    entry = matches[0]
    return xcframework / entry["LibraryIdentifier"] / entry["LibraryPath"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("xcframework", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    source = output / "main.swift"
    source.write_text("import AgoraAgentClientToolkit\nprint(ConversationalAIAPIImpl.version)\n")
    frameworks = [args.xcframework.resolve(),
                  ROOT / "Pods/AgoraRtcEngine_iOS/AgoraRtcKit.xcframework",
                  ROOT / "Pods/AgoraRtm/AgoraRtmKit.xcframework"]
    compiler = Path(subprocess.check_output(["xcrun", "--find", "swiftc"], text=True).strip())
    report = {"xcode": subprocess.check_output(["xcodebuild", "-version"], text=True).strip(),
              "swift": subprocess.check_output([compiler, "--version"], stderr=subprocess.STDOUT, text=True).strip(), "checks": []}
    cases = [("device", "iphoneos", "arm64", "arm64-apple-ios15.0"),
             ("simulator", "iphonesimulator", "arm64", "arm64-apple-ios15.0-simulator"),
             ("simulator", "iphonesimulator", "x86_64", "x86_64-apple-ios15.0-simulator")]
    for platform, sdk_name, arch, target in cases:
        sdk = subprocess.check_output(["xcrun", "--sdk", sdk_name, "--show-sdk-path"], text=True).strip()
        case = output / f"{platform}-{arch}"
        case.mkdir(exist_ok=True)
        slices = [framework_slice(framework, platform, arch) for framework in frameworks]
        common = [compiler, "-target", target, "-sdk", sdk, "-tools-directory", compiler.parent]
        for framework in slices:
            common += ["-F", framework.parent]
        env = dict(os.environ, SDKROOT=sdk)
        results = {}
        # Isolate module caches between toolchains and repeated validations.
        with tempfile.TemporaryDirectory(prefix="module-cache-") as cache:
            common += ["-module-cache-path", cache]
            commands = {"import": common + ["-typecheck", source],
                        "link": common + ["-v", source, "-o", case / "consumer",
                                          "-framework", "AgoraAgentClientToolkit",
                                          "-framework", "AgoraRtcKit", "-framework", "AgoraRtmKit"]}
            for stage, command in commands.items():
                with (case / f"{stage}.log").open("w") as log:
                    log.write(shlex.join([str(item) for item in command]) + "\n")
                    log.flush()
                    results[stage] = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT).returncode
                if results[stage] != 0:
                    print((case / f"{stage}.log").read_text()[-4000:])
                    break
        binary = slices[0] / "AgoraAgentClientToolkit"
        report["checks"].append({"platform": platform, "architecture": arch, "sdk": sdk,
                                 "sha256": hashlib.sha256(binary.read_bytes()).hexdigest(), **results})
        print(f"{platform}/{arch}: {results}")
    (output / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    if any(c.get("import") != 0 or c.get("link") != 0 for c in report["checks"]):
        raise SystemExit(1)


if __name__ == "__main__":
    main()

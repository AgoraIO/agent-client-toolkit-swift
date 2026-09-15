#!/usr/bin/env python3
"""Build CocoaPods and SwiftPM input archives from one XCFramework; do not publish."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parent.parent
BUILD_XCODE = "16.1"


def release_version(tag):
    match = re.fullmatch(r"source/v((?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))", tag)
    if not match:
        raise ValueError("Only source/vX.Y.Z stable tags build artifacts; distribution tags must not rebuild them")
    return match[1]


def validate_versions(root, version):
    component = "AgoraAgentClientToolkit/"
    classes = component + "AgoraAgentClientToolkit/Classes/"
    checks = {
        component + "agent-client-toolkit-swift.podspec": r"s\.version\s*=\s*['\"]([^'\"]+)['\"]",
        component + "agent-client-toolkit-swift.binary.podspec.template": r"s\.version\s*=\s*['\"]([^'\"]+)['\"]",
        classes + "ConversationalAIAPIImpl.swift": r'version:\s*String\s*=\s*"([^"]+)"',
        classes + "Transcript/TranscriptController.swift": r'version:\s*String\s*=\s*"([^"]+)"',
    }
    for name, pattern in checks.items():
        match = re.search(pattern, (root / name).read_text())
        if not match or match[1] != version:
            raise ValueError(f"{name}: expected version {version}, found {match[1] if match else 'no version'}")


def validate_archive(archive, framework, version):
    expected = {}
    for slice_dir in framework.iterdir():
        binary = slice_dir / "AgoraAgentClientToolkit.framework/AgoraAgentClientToolkit"
        if binary.is_file():
            info = plistlib.loads((binary.parent / "Info.plist").read_bytes())
            if info.get("CFBundleShortVersionString") != version or info.get("DTXcode") != "1610":
                raise ValueError(f"Unexpected binary version or build toolchain: {binary}")
            expected[str(binary.relative_to(framework))] = binary.read_bytes()
    if set(expected) != {
        "ios-arm64/AgoraAgentClientToolkit.framework/AgoraAgentClientToolkit",
        "ios-arm64_x86_64-simulator/AgoraAgentClientToolkit.framework/AgoraAgentClientToolkit",
    }:
        raise ValueError("Expected device arm64 and universal simulator slices")
    with zipfile.ZipFile(archive) as package:
        if package.testzip() is not None:
            raise ValueError(f"Corrupt archive: {archive}")
        for suffix, contents in expected.items():
            names = [n for n in package.namelist() if n.endswith("AgoraAgentClientToolkit.xcframework/" + suffix)]
            if len(names) != 1 or package.read(names[0]) != contents:
                raise ValueError(f"Archive does not contain the validated binary: {suffix}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag", help="Source release tag, e.g. source/v2.10.1")
    parser.add_argument("--check", action="store_true", help="Validate the tag and source versions only")
    args = parser.parse_args()
    version = release_version(args.tag)
    validate_versions(ROOT, version)
    if args.check:
        print(version)
        return

    xcode = subprocess.check_output(["xcodebuild", "-version"], text=True).strip()
    if xcode.splitlines()[0] != "Xcode " + BUILD_XCODE:
        raise ValueError(f"Build with Xcode {BUILD_XCODE} via DEVELOPER_DIR; selected toolchain is {xcode}")
    output = ROOT / "build/release" / version
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="release-build-", dir=ROOT / "build") as directory:
        work = Path(directory)
        env = dict(os.environ, VERSION=version, RUN_ROOT=str(work / "cocoapods"),
                   STAGING_ROOT=str(work / "staging"), KEEP_STAGING="1",
                   XCODE_WORK_ROOT=str(work / "xcode"), PACKAGE_WORK_ROOT=str(work / "package"))
        subprocess.run(["bash", "scripts/build_rehoboam_cocoapods_input_zip.sh"], cwd=ROOT, env=env, check=True)
        framework = work / "staging/sdk/AgoraAgentClientToolkit.xcframework"
        env.update(RUN_ROOT=str(work / "swiftpm"), EXISTING_XCFRAMEWORK=str(framework))
        subprocess.run(["bash", "scripts/build_rehoboam_swiftpm_input_zip.sh"], cwd=ROOT, env=env, check=True)

        hashes = {}
        for kind in ["cocoapods", "swiftpm"]:
            name = f"agora-agent-client-toolkit-{version}-{kind}-rehoboam-input.zip"
            archive = work / kind / name
            validate_archive(archive, framework, version)
            shutil.copy2(archive, output / name)
            hashes[name] = hashlib.sha256(archive.read_bytes()).hexdigest()
        destination = output / framework.name
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(framework, destination)

    manifest = {
        "version": version,
        "source_tag": args.tag,
        "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "xcode": xcode,
        "swift": subprocess.check_output(["xcrun", "swiftc", "--version"], stderr=subprocess.STDOUT, text=True).strip(),
        "archives": hashes,
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (output / "SHA256SUMS").write_text("".join(f"{digest}  {name}\n" for name, digest in hashes.items()))
    print(f"Release artifacts: {output}")


if __name__ == "__main__":
    main()

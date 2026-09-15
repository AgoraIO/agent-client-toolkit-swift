import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
import zipfile


SPEC = importlib.util.spec_from_file_location("release", Path(__file__).resolve().parents[1] / "build_release_artifacts.py")
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class ReleaseArtifactsTests(unittest.TestCase):
    def test_stable_source_tags(self):
        for version in ["0.0.1", "2.10.1", "12.30.400"]:
            self.assertEqual(version, release.release_version("source/v" + version))

    def test_publisher_tags_and_non_release_refs_are_rejected(self):
        for tag in ["2.10.1", "v2.10.1", "source/main", "main", "source/v2.10.1-rc.1", "source/v2.10.1+build", "source/v02.10.1", "source/v2.10.1/other"]:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                release.release_version(tag)

    def test_all_source_versions_must_match_tag(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            files = {
                "AgoraAgentClientToolkit/agent-client-toolkit-swift.podspec": "s.version = '2.10.1'",
                "AgoraAgentClientToolkit/agent-client-toolkit-swift.binary.podspec.template": "s.version = '2.10.1'",
                "AgoraAgentClientToolkit/AgoraAgentClientToolkit/Classes/ConversationalAIAPIImpl.swift": 'public static let version: String = "2.10.1"',
                "AgoraAgentClientToolkit/AgoraAgentClientToolkit/Classes/Transcript/TranscriptController.swift": 'public static let version: String = "2.10.1"',
            }
            for name, contents in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(contents)
            release.validate_versions(root, "2.10.1")
            for name, contents in files.items():
                (root / name).write_text(contents.replace("2.10.1", "2.10.0"))
                with self.subTest(name=name), self.assertRaises(ValueError):
                    release.validate_versions(root, "2.10.1")
                (root / name).write_text(contents)

    def test_both_formats_must_contain_the_same_validated_binaries(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            framework = root / "AgoraAgentClientToolkit.xcframework"
            for name in ["ios-arm64", "ios-arm64_x86_64-simulator"]:
                path = framework / name / "AgoraAgentClientToolkit.framework"
                path.mkdir(parents=True)
                (path / "AgoraAgentClientToolkit").write_bytes(name.encode())
                (path / "Info.plist").write_bytes(plistlib.dumps({"CFBundleShortVersionString": "2.10.1", "DTXcode": "1610"}))
            for prefix in ["sdk/", "swiftpm_template/sdk/AgoraAgentClientToolkit/"]:
                for corrupt in [False, True]:
                    archive = root / "package.zip"
                    with zipfile.ZipFile(archive, "w") as package:
                        for binary in framework.glob("*/AgoraAgentClientToolkit.framework/AgoraAgentClientToolkit"):
                            package.writestr(prefix + str(binary.relative_to(root)), b"wrong build" if corrupt else binary.read_bytes())
                    if corrupt:
                        with self.assertRaises(ValueError):
                            release.validate_archive(archive, framework, "2.10.1")
                    else:
                        release.validate_archive(archive, framework, "2.10.1")

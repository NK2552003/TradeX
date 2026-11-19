"""Regression tests for AlphaJournal's database-free update manifest."""

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
import generate_app_update_manifest as updates


class AppUpdateManifestTests(unittest.TestCase):
    def test_pubspec_version_parser_supports_build_numbers(self):
        self.assertEqual(
            updates.read_pubspec_version("name: alphajournal\nversion: 2.4.1+37\n"),
            ("2.4.1", 37),
        )
        with self.assertRaises(ValueError):
            updates.read_pubspec_version("version: release+one\n")
        with self.assertRaises(ValueError):
            updates.read_pubspec_version("version: 1.02.3+1\n")
        with self.assertRaises(ValueError):
            updates.read_pubspec_version("version: 1.2.3-rc.01+1\n")

    def test_generation_updates_only_selected_platform(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pubspec = root / "pubspec.yaml"
            manifest = root / "app-update.json"
            pubspec.write_text("version: 1.2.3+9\n", encoding="utf-8")
            manifest.write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "platforms": {
                            "web": {"enabled": True},
                            "android": {
                                "enabled": True,
                                "latest_version": "1.0.0",
                                "latest_build_number": 1,
                            },
                        },
                    }
                ),
                encoding="utf-8",
            )
            with patch.object(updates, "PUBSPEC", pubspec), patch.object(
                updates, "MANIFEST", manifest
            ):
                generated = updates.generate_manifest(platforms=("web",))
                self.assertTrue(updates.manifest_matches_pubspec(("web",)))
                self.assertFalse(updates.manifest_matches_pubspec(("android",)))

            self.assertEqual(
                generated["platforms"]["web"]["latest_version"], "1.2.3"
            )
            self.assertEqual(
                generated["platforms"]["web"]["latest_build_number"], 9
            )
            self.assertEqual(
                generated["platforms"]["android"]["latest_version"], "1.0.0"
            )

    def test_unknown_platform_is_rejected(self):
        with self.assertRaises(ValueError):
            updates.generate_manifest(platforms=("browser-os",), write=False)

    def test_impossible_minimum_release_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pubspec = root / "pubspec.yaml"
            manifest = root / "app-update.json"
            pubspec.write_text("version: 1.2.3+9\n", encoding="utf-8")
            manifest.write_text(
                json.dumps({"schema_version": 1, "platforms": {}}),
                encoding="utf-8",
            )
            with patch.object(updates, "PUBSPEC", pubspec), patch.object(
                updates, "MANIFEST", manifest
            ):
                with self.assertRaises(ValueError):
                    updates.generate_manifest(
                        platforms=("web",),
                        minimum_version="2.0.0",
                    )
                with self.assertRaises(ValueError):
                    updates.generate_manifest(
                        platforms=("web",),
                        minimum_build_number=-1,
                    )


if __name__ == "__main__":
    unittest.main()

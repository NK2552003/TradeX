#!/usr/bin/env python3
"""Generate the public, database-free AlphaJournal update manifest."""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / "pubspec.yaml"
MANIFEST = ROOT / "web" / "app-update.json"
PLATFORMS = ("web", "android", "ios", "macos", "windows", "linux")
VERSION_PATTERN = re.compile(r"^version:\s*([^\s#]+)", re.MULTILINE)
SEMANTIC_VERSION_PATTERN = re.compile(
    r"^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$"
)


def semantic_version_key(version: str) -> tuple:
    match = SEMANTIC_VERSION_PATTERN.fullmatch(version)
    if match is None:
        raise ValueError(f"Unsupported semantic version: {version}")
    prerelease = match.group(4)
    core_parts = match.group(1), match.group(2), match.group(3)
    if any(len(part) > 1 and part.startswith("0") for part in core_parts):
        raise ValueError(f"Unsupported semantic version: {version}")
    prerelease_parts = (prerelease or "").split(".")
    if prerelease is not None and any(
        not part or (part.isdigit() and len(part) > 1 and part.startswith("0"))
        for part in prerelease_parts
    ):
        raise ValueError(f"Unsupported semantic version: {version}")
    prerelease_key = tuple(
        (0, int(part)) if part.isdigit() else (1, part)
        for part in prerelease_parts
        if part
    )
    return (
        int(core_parts[0]),
        int(core_parts[1]),
        int(core_parts[2]),
        1 if prerelease is None else 0,
        prerelease_key,
    )


def read_pubspec_version(source: str) -> tuple[str, int]:
    match = VERSION_PATTERN.search(source)
    if match is None:
        raise ValueError("pubspec.yaml is missing a version field")
    raw = match.group(1)
    version, separator, build = raw.partition("+")
    semantic_version_key(version)
    if separator and not build.isdigit():
        raise ValueError(f"Build number must be numeric: {build}")
    return version, int(build or "0")


def _read_manifest() -> dict:
    if not MANIFEST.exists():
        return {"schema_version": 1, "platforms": {}}
    value = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("app-update.json must contain an object")
    if value.get("schema_version") != 1:
        raise ValueError("app-update.json has an unsupported schema_version")
    if not isinstance(value.get("platforms"), dict):
        raise ValueError("app-update.json must contain a platforms object")
    return value


def generate_manifest(
    *,
    platforms: Iterable[str],
    minimum_version: str | None = None,
    minimum_build_number: int | None = None,
    write: bool = True,
) -> dict:
    selected = tuple(dict.fromkeys(platforms))
    unknown = sorted(set(selected) - set(PLATFORMS))
    if unknown:
        raise ValueError(f"Unsupported platforms: {', '.join(unknown)}")

    version, build_number = read_pubspec_version(
        PUBSPEC.read_text(encoding="utf-8"),
    )
    if minimum_version is not None:
        semantic_version_key(minimum_version)
    if minimum_build_number is not None and minimum_build_number < 0:
        raise ValueError("Minimum build number must be non-negative")
    manifest = _read_manifest()
    releases = manifest["platforms"]
    for platform in selected:
        release = releases.get(platform)
        if not isinstance(release, dict):
            release = {"enabled": True}
            releases[platform] = release
        release["latest_version"] = version
        release["latest_build_number"] = build_number
        release.setdefault("minimum_supported_version", version)
        release.setdefault("minimum_build_number", build_number)
        if minimum_version is not None:
            release["minimum_supported_version"] = minimum_version
        if minimum_build_number is not None:
            release["minimum_build_number"] = minimum_build_number
        release_minimum_version = release["minimum_supported_version"]
        release_minimum_build = release["minimum_build_number"]
        if not isinstance(release_minimum_version, str):
            raise ValueError(
                f"{platform} minimum_supported_version must be a string"
            )
        if not isinstance(release_minimum_build, int) or release_minimum_build < 0:
            raise ValueError(
                f"{platform} minimum_build_number must be non-negative"
            )
        minimum_key = semantic_version_key(release_minimum_version)
        latest_key = semantic_version_key(version)
        if minimum_key > latest_key or (
            minimum_key == latest_key and release_minimum_build > build_number
        ):
            raise ValueError(
                f"{platform} minimum supported release exceeds latest release"
            )

    manifest["generated_at"] = (
        datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    )
    if write:
        MANIFEST.write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    return manifest


def manifest_matches_pubspec(platforms: Iterable[str]) -> bool:
    version, build_number = read_pubspec_version(
        PUBSPEC.read_text(encoding="utf-8"),
    )
    manifest = _read_manifest()
    for platform in platforms:
        release = manifest["platforms"].get(platform)
        if not isinstance(release, dict):
            return False
        if release.get("latest_version") != version:
            return False
        if release.get("latest_build_number") != build_number:
            return False
    return True


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Synchronize app-update.json with pubspec.yaml",
    )
    parser.add_argument(
        "--platform",
        action="append",
        choices=PLATFORMS,
        dest="platforms",
        help="Platform to publish. Repeat for multiple platforms.",
    )
    parser.add_argument(
        "--all-platforms",
        action="store_true",
        help="Publish the pubspec version for every platform.",
    )
    parser.add_argument("--minimum-version")
    parser.add_argument("--minimum-build-number", type=int)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Verify selected platform versions without writing.",
    )
    args = parser.parse_args(argv)
    selected = PLATFORMS if args.all_platforms else tuple(args.platforms or ("web",))
    if args.check:
        if manifest_matches_pubspec(selected):
            print("app-update.json matches pubspec.yaml")
            return 0
        print("app-update.json is stale for: " + ", ".join(selected))
        return 1

    generate_manifest(
        platforms=selected,
        minimum_version=args.minimum_version,
        minimum_build_number=args.minimum_build_number,
    )
    print(
        "Published AlphaJournal version metadata for: " + ", ".join(selected),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

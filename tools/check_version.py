#!/usr/bin/env python3
"""Checks that the game version is consistent across project files.

Usage:
    python tools/check_version.py            # project.godot vs export presets
    python tools/check_version.py v0.1.0     # additionally require tag == version
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot" / "project.godot"
PRESETS = ROOT / "godot" / "export_presets.cfg"


def read_values(path: Path, key: str) -> list[str]:
    pattern = re.compile(r'^' + re.escape(key) + r'="([^"]*)"\s*$', re.MULTILINE)
    return pattern.findall(path.read_text(encoding="utf-8"))


def main() -> int:
    errors = []
    project_versions = read_values(PROJECT, "config/version")
    if len(project_versions) != 1 or not project_versions[0]:
        print(f"VERSION CHECK FAILED\n - {PROJECT.name}: expected exactly one config/version")
        return 1
    version = project_versions[0]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        errors.append(f"config/version '{version}' is not MAJOR.MINOR.PATCH")

    # Every preset that carries a version key must match; at least one must carry it,
    # otherwise a renamed/removed key would silently disable this check.
    for key in ("application/file_version", "application/product_version"):
        values = read_values(PRESETS, key)
        if not values:
            errors.append(f"{PRESETS.name}: {key} not found")
        for value in values:
            if value != version:
                errors.append(f"{PRESETS.name}: {key}='{value}' != config/version '{version}'")
    # The Android preset carries its own version name; it must follow the game version too.
    for value in read_values(PRESETS, "version/name"):
        if value != version:
            errors.append(f"{PRESETS.name}: version/name='{value}' != config/version '{version}'")

    if len(sys.argv) > 1:
        tag = sys.argv[1]
        if tag.removeprefix("v") != version:
            errors.append(f"tag '{tag}' != config/version '{version}'")

    if errors:
        print("VERSION CHECK FAILED")
        for error in errors:
            print(" -", error)
        return 1
    print(f"VERSION OK: {version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

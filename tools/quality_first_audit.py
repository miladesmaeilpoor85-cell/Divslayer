#!/usr/bin/env python3
"""Enforce quality-first, lossless Godot imports for this 2D game's artwork."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

IMAGE_IMPORT_SUFFIXES = tuple(
    f"{extension}.import"
    for extension in (".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga", ".svg")
)


def _setting(contents: str, key: str) -> int | None:
    match = re.search(rf"(?m)^{re.escape(key)}=(-?\d+)\s*$", contents)
    return int(match.group(1)) if match else None


def audit_2d_image_imports(root: Path) -> dict[str, object]:
    root = root.resolve()
    files = sorted(
        path
        for path in root.rglob("*.import")
        if path.is_file() and path.name.lower().endswith(IMAGE_IMPORT_SUFFIXES)
    )
    errors: list[str] = []

    for path in files:
        relative = path.relative_to(root).as_posix()
        try:
            contents = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            errors.append(f"{relative}: cannot read import settings: {exc}")
            continue

        mode = _setting(contents, "compress/mode")
        if mode != 0:
            errors.append(
                f"{relative}: compress/mode={mode}; 2D artwork must use 0 (Lossless)"
            )

        detect_3d_mode = _setting(contents, "detect_3d/compress_to")
        if detect_3d_mode != 0:
            errors.append(
                f"{relative}: detect_3d/compress_to={detect_3d_mode}; detected 3D usage must keep Lossless quality"
            )

        size_limit = _setting(contents, "process/size_limit")
        if size_limit != 0:
            errors.append(
                f"{relative}: process/size_limit={size_limit}; hidden downscaling is not allowed"
            )

    return {
        "files_checked": len(files),
        "files_passed": len(files) - len(errors),
        "errors": errors,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()

    report = audit_2d_image_imports(args.root)
    print(f"2D image import settings checked: {report['files_checked']}")
    print(f"Lossless / no-size-limit checks passed: {report['files_passed']}")
    for error in report["errors"]:
        print(f"ERROR: {error}", file=sys.stderr)

    if report["errors"] or report["files_checked"] == 0:
        print("QUALITY_FIRST_IMPORT_AUDIT_FAILED")
        return 1

    print("QUALITY_FIRST_IMPORT_AUDIT_PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

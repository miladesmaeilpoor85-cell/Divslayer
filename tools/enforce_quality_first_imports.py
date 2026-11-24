#!/usr/bin/env python3
"""Apply Lossless, no-downscale settings to every imported image in the project."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

IMAGE_IMPORT_SUFFIXES = tuple(
    f"{extension}.import"
    for extension in (".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga", ".svg")
)
SETTINGS = {
    "compress/mode": "0",
    "detect_3d/compress_to": "0",
    "process/size_limit": "0",
}


def normalize_import_text(contents: str) -> tuple[str, bool]:
    if "[params]" not in contents:
        raise ValueError("image import sidecar has no [params] section")

    lines = contents.splitlines()
    changed = False
    params_index = lines.index("[params]")

    for key, value in SETTINGS.items():
        prefix = f"{key}="
        matching_indices = [
            index for index, line in enumerate(lines) if line.startswith(prefix)
        ]
        if len(matching_indices) > 1:
            raise ValueError(f"duplicate import setting: {key}")
        if matching_indices:
            index = matching_indices[0]
            expected = f"{prefix}{value}"
            if lines[index] != expected:
                lines[index] = expected
                changed = True
        else:
            params_index += 1
            lines.insert(params_index, f"{prefix}{value}")
            changed = True

    trailing_newline = contents.endswith(("\n", "\r"))
    normalized = "\n".join(lines) + ("\n" if trailing_newline else "")
    return normalized, changed


def iter_image_imports(root: Path):
    for path in root.rglob("*.import"):
        if path.is_file() and path.name.lower().endswith(IMAGE_IMPORT_SUFFIXES):
            if any(part in {".git", ".godot", "build", ".venv", "node_modules"} for part in path.relative_to(root).parts):
                continue
            yield path


def process_import(path: Path, check_only: bool = False) -> tuple[bool, str | None]:
    try:
        original = path.read_text(encoding="utf-8")
        normalized, changed = normalize_import_text(original)
        if changed and not check_only:
            path.write_text(normalized, encoding="utf-8", newline="\n")
        return changed, None
    except (OSError, UnicodeError, ValueError) as exc:
        return False, f"{path}: {exc}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="project root (defaults to the repository root)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify policy without modifying import sidecars",
    )
    args = parser.parse_args()
    root = args.root.resolve()

    files = list(iter_image_imports(root))
    if not files:
        print("ERROR: no image import sidecars found.", file=sys.stderr)
        return 1

    changed = 0
    errors: list[str] = []
    for path in files:
        needs_change, error = process_import(path, check_only=args.check)
        if error:
            errors.append(error)
        elif needs_change:
            changed += 1

    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)

    if errors:
        return 1
    if args.check and changed:
        print(
            f"ERROR: {changed} image import(s) still require quality-first settings.",
            file=sys.stderr,
        )
        return 1

    action = "verified" if args.check else "enforced"
    print(
        f"QUALITY_FIRST_IMPORTS_{action.upper()}: "
        f"scanned={len(files)} changed={changed} "
        "compress=Lossless detect_3d=Lossless size_limit=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

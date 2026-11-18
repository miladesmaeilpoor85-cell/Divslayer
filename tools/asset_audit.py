#!/usr/bin/env python3
"""Dependency-free integrity/provenance coverage audit for Divslayer assets.

Checks basic image/audio container headers and verifies that every artwork file
has exactly one record in docs/ASSET_RIGHTS_REGISTER.csv. It never approves
ownership, copyright, or commercial-use rights.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import struct
import sys
from collections import Counter, defaultdict
from pathlib import Path, PurePosixPath
from typing import Any

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
AUDIO_EXTENSIONS = {".ogg", ".wav", ".mp3", ".flac"}
ART_ROOT = Path("assets/art")
AUDIO_ROOT = Path("assets/audio")
REGISTER = Path("docs/ASSET_RIGHTS_REGISTER.csv")
LARGE_FILE_BYTES = 8 * 1024 * 1024
LARGE_IMAGE_PIXELS = 64_000_000


def _png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        head = stream.read(24)
        if len(head) != 24 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
            raise ValueError("invalid or truncated PNG header")
        width, height = struct.unpack(">II", head[16:24])
        stream.seek(0, 2)
        if stream.tell() < 45:
            raise ValueError("PNG is too small to contain required chunks")
        stream.seek(-8, 2)
        if stream.read(4) != b"IEND":
            raise ValueError("PNG is missing its final IEND chunk")
        if width < 1 or height < 1:
            raise ValueError("PNG has zero dimensions")
        return width, height


def _jpeg_dimensions(path: Path) -> tuple[int, int]:
    sof = {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}
    with path.open("rb") as stream:
        if stream.read(2) != b"\xff\xd8":
            raise ValueError("invalid JPEG SOI marker")
        while True:
            byte = stream.read(1)
            if not byte:
                break
            if byte != b"\xff":
                continue
            marker_byte = stream.read(1)
            while marker_byte == b"\xff":
                marker_byte = stream.read(1)
            if not marker_byte:
                break
            marker = marker_byte[0]
            if marker == 0xD9:
                break
            if marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
                continue
            raw_length = stream.read(2)
            if len(raw_length) != 2:
                break
            length = int.from_bytes(raw_length, "big")
            if length < 2:
                raise ValueError("invalid JPEG segment length")
            if marker in sof:
                frame = stream.read(5)
                if len(frame) != 5:
                    raise ValueError("truncated JPEG frame header")
                height = int.from_bytes(frame[1:3], "big")
                width = int.from_bytes(frame[3:5], "big")
                if not width or not height:
                    raise ValueError("JPEG has zero dimensions")
                return width, height
            stream.seek(length - 2, 1)
    raise ValueError("JPEG dimensions could not be found")


def _webp_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        head = stream.read(30)
        if len(head) < 30 or head[:4] != b"RIFF" or head[8:12] != b"WEBP":
            raise ValueError("invalid or truncated WebP container")
        declared_size = int.from_bytes(head[4:8], "little") + 8
        stream.seek(0, 2)
        if declared_size > stream.tell():
            raise ValueError("truncated WebP RIFF payload")
        chunk, size, data = head[12:16], int.from_bytes(head[16:20], "little"), head[20:]
        if chunk == b"VP8X" and size >= 10 and len(data) >= 10:
            width = 1 + int.from_bytes(data[4:7], "little")
            height = 1 + int.from_bytes(data[7:10], "little")
        elif chunk == b"VP8 " and size >= 10 and len(data) >= 10 and data[3:6] == b"\x9d\x01\x2a":
            width = int.from_bytes(data[6:8], "little") & 0x3FFF
            height = int.from_bytes(data[8:10], "little") & 0x3FFF
        elif chunk == b"VP8L" and size >= 5 and len(data) >= 5 and data[0] == 0x2F:
            b1, b2, b3, b4 = data[1:5]
            width = 1 + b1 + ((b2 & 0x3F) << 8)
            height = 1 + ((b2 >> 6) & 0x03) + (b3 << 2) + ((b4 & 0x0F) << 10)
        else:
            raise ValueError("unsupported or truncated WebP image header")
        if not width or not height:
            raise ValueError("WebP has zero dimensions")
        return width, height


def image_dimensions(path: Path) -> tuple[int, int]:
    suffix = path.suffix.lower()
    if suffix == ".png":
        return _png_dimensions(path)
    if suffix in {".jpg", ".jpeg"}:
        return _jpeg_dimensions(path)
    if suffix == ".webp":
        return _webp_dimensions(path)
    raise ValueError(f"unsupported image extension: {suffix}")


def _check_audio(path: Path) -> None:
    with path.open("rb") as stream:
        head = stream.read(32)
    suffix = path.suffix.lower()
    if suffix == ".ogg":
        valid = len(head) >= 27 and head[:4] == b"OggS" and head[4] == 0
    elif suffix == ".wav":
        valid = len(head) >= 12 and head[:4] == b"RIFF" and head[8:12] == b"WAVE"
    elif suffix == ".flac":
        valid = len(head) >= 4 and head[:4] == b"fLaC"
    else:
        valid = head[:3] == b"ID3" or (len(head) >= 2 and head[0] == 0xFF and (head[1] & 0xE0) == 0xE0)
    if not valid:
        raise ValueError(f"invalid {suffix[1:].upper()} file header")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def audit_repository(root: Path) -> dict[str, Any]:
    root = root.resolve()
    errors: list[str] = []
    warnings: list[str] = []
    art_dir = root / ART_ROOT
    images = sorted(p for p in art_dir.rglob("*") if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS) if art_dir.is_dir() else []
    if not art_dir.is_dir():
        errors.append(f"missing artwork directory: {ART_ROOT.as_posix()}")

    registry_path = root / REGISTER
    rows: dict[str, str] = {}
    rights_counts: Counter[str] = Counter()
    if not registry_path.is_file():
        errors.append(f"missing rights register: {REGISTER.as_posix()}")
    else:
        try:
            with registry_path.open("r", encoding="utf-8-sig", newline="") as stream:
                reader = csv.DictReader(stream)
                if not {"asset_path", "commercial_use_status"}.issubset(set(reader.fieldnames or [])):
                    errors.append("rights register must contain asset_path and commercial_use_status columns")
                else:
                    for line, row in enumerate(reader, start=2):
                        rel = (row.get("asset_path") or "").strip().replace("\\", "/")
                        status = (row.get("commercial_use_status") or "").strip() or "(blank)"
                        rights_counts[status] += 1
                        candidate = PurePosixPath(rel)
                        if not rel:
                            errors.append(f"rights register line {line}: empty asset_path")
                        elif not rel.startswith("assets/art/") or candidate.is_absolute() or ".." in candidate.parts:
                            errors.append(f"rights register line {line}: unsafe or out-of-scope path: {rel}")
                        elif rel in rows:
                            errors.append(f"duplicate rights register entry: {rel}")
                        else:
                            target = root.joinpath(*candidate.parts)
                            try:
                                target.resolve().relative_to(root)
                            except ValueError:
                                errors.append(f"rights register line {line}: path escapes repository: {rel}")
                                continue
                            if not target.is_file():
                                errors.append(f"rights register points to a missing file: {rel}")
                            else:
                                rows[rel] = status
        except (OSError, csv.Error, UnicodeError) as exc:
            errors.append(f"could not read rights register: {exc}")

    actual = {p.relative_to(root).as_posix() for p in images}
    for rel in sorted(actual - set(rows)):
        errors.append(f"artwork file is not registered: {rel}")
    for rel in sorted(set(rows) - actual):
        errors.append(f"registered artwork is not a supported image file: {rel}")

    unverified = sum(value.upper() == "UNVERIFIED" for value in rows.values())
    blank = rights_counts.get("(blank)", 0)
    if unverified:
        warnings.append(f"{unverified} artwork rights records remain UNVERIFIED; this is a provenance warning, not an integrity failure")
    if blank:
        warnings.append(f"{blank} artwork rights records have a blank commercial_use_status")

    dimensions: dict[str, list[int]] = {}
    hashes: dict[str, list[str]] = defaultdict(list)
    for path in images:
        rel = path.relative_to(root).as_posix()
        try:
            width, height = image_dimensions(path)
            dimensions[rel] = [width, height]
            if width * height > LARGE_IMAGE_PIXELS:
                warnings.append(f"very large image dimensions ({width}x{height}): {rel}")
            if path.stat().st_size > LARGE_FILE_BYTES:
                warnings.append(f"large artwork file ({path.stat().st_size} bytes): {rel}")
            hashes[_sha256(path)].append(rel)
        except (OSError, ValueError) as exc:
            errors.append(f"invalid artwork file {rel}: {exc}")

    duplicate_groups = [sorted(paths) for paths in hashes.values() if len(paths) > 1]
    for group in duplicate_groups:
        warnings.append("identical artwork files: " + ", ".join(group))

    audio_dir = root / AUDIO_ROOT
    audio_files = sorted(p for p in audio_dir.rglob("*") if p.is_file() and p.suffix.lower() in AUDIO_EXTENSIONS) if audio_dir.is_dir() else []
    for path in audio_files:
        rel = path.relative_to(root).as_posix()
        try:
            if path.stat().st_size == 0:
                raise ValueError("file is empty")
            _check_audio(path)
        except (OSError, ValueError) as exc:
            errors.append(f"invalid audio file {rel}: {exc}")

    return {
        "artwork_files": len(images),
        "registered_artwork_files": len(rows),
        "artwork_rights_status_counts": dict(sorted(rights_counts.items())),
        "audio_files_checked": len(audio_files),
        "image_dimensions": dimensions,
        "identical_image_groups": duplicate_groups,
        "errors": errors,
        "warnings": warnings,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1], help="repository root")
    parser.add_argument("--json", action="store_true", help="print a machine-readable report")
    args = parser.parse_args()
    report = audit_repository(args.root)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print("Divslayer asset audit")
        print(f"Artwork: {report['artwork_files']} files; {report['registered_artwork_files']} registered")
        print(f"Audio files checked: {report['audio_files_checked']}")
        print("Rights statuses: " + (", ".join(f"{k}={v}" for k, v in report["artwork_rights_status_counts"].items()) or "no records"))
        print(f"Exact-duplicate image groups: {len(report['identical_image_groups'])}")
        for message in report["warnings"]:
            print(f"WARNING: {message}")
        for message in report["errors"]:
            print(f"ERROR: {message}")
        print("ASSET_AUDIT_PASSED" if not report["errors"] else "ASSET_AUDIT_FAILED")
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())

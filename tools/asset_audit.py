"""Dependency-free integrity/provenance coverage audit for Divslayer assets.

Checks basic image/audio container headers and verifies that every tracked image
has exactly one record in docs/ASSET_RIGHTS_REGISTER.csv. It never approves
ownership, copyright, or commercial-use rights.
"""
from __future__ import annotations

import argparse
import base64
import csv
import hashlib
import json
import re
import struct
import sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from pathlib import Path, PurePosixPath
from typing import Any

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".svg"}
AUDIO_EXTENSIONS = {".ogg", ".wav", ".mp3", ".flac"}
AUDIO_ROOT = Path("assets/audio")
REGISTER = Path("docs/ASSET_RIGHTS_REGISTER.csv")
ATLAS_PAYLOAD_ROOT = Path("assets/art/Heroes/attack_atlas_data")
BASE64_ARTWORK_GROUPS = {
    Path("assets/art/Enemies/alborzwarden"): {
        "parts": ("part_00.b64", "part_01.b64", "part_02.b64", "part_03.b64", "part_04.b64", "part_05a.b64", "part_05b.b64"),
        "dimensions": (544, 156),
    },
    Path("assets/art/Portraits/alborz_scout"): {
        "parts": ("part_00.b64", "part_01.b64", "part_02.b64", "part_03.b64"),
        "dimensions": (256, 256),
    },
}
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


def _webp_dimensions_from_bytes(payload: bytes) -> tuple[int, int]:
    if len(payload) < 30 or payload[:4] != b"RIFF" or payload[8:12] != b"WEBP":
        raise ValueError("invalid or truncated WebP container")
    declared_size = int.from_bytes(payload[4:8], "little") + 8
    if declared_size != len(payload):
        raise ValueError("WebP RIFF payload size does not match the decoded bytes")
    chunk = payload[12:16]
    size = int.from_bytes(payload[16:20], "little")
    data = payload[20:30]
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


def _webp_dimensions(path: Path) -> tuple[int, int]:
    return _webp_dimensions_from_bytes(path.read_bytes())


def _svg_dimensions(path: Path) -> tuple[int, int]:
    """Read a passive SVG canvas size; reject active embedded content."""
    raw = path.read_text(encoding="utf-8")
    if "<!DOCTYPE" in raw.upper() or "<!ENTITY" in raw.upper():
        raise ValueError("SVG document types and entities are not allowed")
    root = ET.fromstring(raw)
    if root.tag.split("}")[-1] != "svg":
        raise ValueError("document root is not an SVG element")
    for node in root.iter():
        if node.tag.split("}")[-1] in {"script", "foreignObject"}:
            raise ValueError("active SVG content is not allowed")

    def dimension(value: str | None) -> int | None:
        if value is None:
            return None
        match = re.fullmatch(r"\s*(\d+(?:\.\d+)?)(?:px)?\s*", value)
        return round(float(match.group(1))) if match else None

    width = dimension(root.get("width"))
    height = dimension(root.get("height"))
    if width is None or height is None:
        view_box = re.split(r"[\s,]+", (root.get("viewBox") or "").strip())
        if len(view_box) != 4:
            raise ValueError("SVG needs numeric width/height or a four-value viewBox")
        try:
            view_width = round(float(view_box[2]))
            view_height = round(float(view_box[3]))
        except ValueError as exc:
            raise ValueError("SVG viewBox dimensions are invalid") from exc
        width = width or view_width
        height = height or view_height
    if width < 1 or height < 1:
        raise ValueError("SVG has zero dimensions")
    return width, height


def image_dimensions(path: Path) -> tuple[int, int]:
    suffix = path.suffix.lower()
    if suffix == ".png":
        return _png_dimensions(path)
    if suffix in {".jpg", ".jpeg"}:
        return _jpeg_dimensions(path)
    if suffix == ".webp":
        return _webp_dimensions(path)
    if suffix == ".svg":
        return _svg_dimensions(path)
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


def audit_atlas_payloads(root: Path) -> tuple[list[Path], int, list[str]]:
    """Validate ordered Base64 PNG parts used by metadata-driven attack atlases."""
    payload_root = root / ATLAS_PAYLOAD_ROOT
    if not payload_root.is_dir():
        return [], 0, []
    payload_files = sorted(path for path in payload_root.rglob("*.b64") if path.is_file())
    groups: dict[str, list[Path]] = defaultdict(list)
    for path in payload_files:
        groups[path.parent.relative_to(root).as_posix()].append(path)

    errors: list[str] = []
    checked = 0
    for group, paths in sorted(groups.items()):
        indexed: list[tuple[int, Path]] = []
        for path in paths:
            match = re.fullmatch(r"part_(\d{2})\.b64", path.name)
            if match is None:
                errors.append(f"invalid atlas payload part name: {path.relative_to(root).as_posix()}")
                continue
            indexed.append((int(match.group(1)), path))
        indexed.sort(key=lambda item: item[0])
        actual_indices = [index for index, _ in indexed]
        if actual_indices != list(range(len(indexed))):
            errors.append(f"atlas payload parts are missing or out of order in {group}: {actual_indices}")
            continue
        try:
            encoded = "".join(path.read_text(encoding="ascii").strip() for _, path in indexed)
            decoded = base64.b64decode(encoded, validate=True)
        except (OSError, UnicodeError, ValueError) as exc:
            errors.append(f"invalid Base64 atlas payload in {group}: {exc}")
            continue
        if (len(decoded) < 45 or decoded[:8] != b"\x89PNG\r\n\x1a\n"
                or decoded[12:16] != b"IHDR" or decoded[-8:-4] != b"IEND"):
            errors.append(f"atlas payload does not reassemble into a complete PNG: {group}")
            continue
        width, height = struct.unpack(">II", decoded[16:24])
        if (width, height) != (640, 468):
            errors.append(f"atlas payload has unexpected dimensions {width}x{height} in {group}; expected 640x468")
            continue
        checked += 1
    return payload_files, checked, errors



def audit_base64_artwork_payloads(root: Path) -> tuple[list[Path], int, list[str]]:
    """Validate ordered Base64 WebP image parts used by dedicated game artwork."""
    payload_files: list[Path] = []
    checked = 0
    errors: list[str] = []
    for relative_dir, spec in BASE64_ARTWORK_GROUPS.items():
        directory = root / relative_dir
        if not directory.is_dir():
            continue
        actual = {path.name: path for path in directory.glob("*.b64") if path.is_file()}
        payload_files.extend(actual.values())
        expected_parts = tuple(spec["parts"])
        if set(actual) != set(expected_parts):
            missing = sorted(set(expected_parts) - set(actual))
            unexpected = sorted(set(actual) - set(expected_parts))
            errors.append(
                f"Base64 artwork parts are missing or unexpected in {relative_dir.as_posix()}: "
                f"missing={missing}, unexpected={unexpected}"
            )
            continue
        try:
            encoded = "".join(
                (directory / name).read_text(encoding="ascii").strip()
                for name in expected_parts
            )
            decoded = base64.b64decode(encoded, validate=True)
            dimensions = _webp_dimensions_from_bytes(decoded)
        except (OSError, UnicodeError, ValueError) as exc:
            errors.append(f"invalid Base64 WebP artwork payload in {relative_dir.as_posix()}: {exc}")
            continue
        expected_dimensions = tuple(spec["dimensions"])
        if dimensions != expected_dimensions:
            errors.append(
                f"Base64 WebP artwork has unexpected dimensions {dimensions[0]}x{dimensions[1]} "
                f"in {relative_dir.as_posix()}; expected {expected_dimensions[0]}x{expected_dimensions[1]}"
            )
            continue
        checked += 1
    return payload_files, checked, errors

def audit_repository(root: Path) -> dict[str, Any]:
    root = root.resolve()
    errors: list[str] = []
    warnings: list[str] = []
    excluded_dirs = {".git", ".godot", ".venv", "build", "dist", "__pycache__"}
    images = sorted(
        p for p in root.rglob("*")
        if p.is_file()
        and p.suffix.lower() in IMAGE_EXTENSIONS
        and not excluded_dirs.intersection(p.relative_to(root).parts)
    )
    atlas_payload_files, atlas_payloads_checked, atlas_payload_errors = audit_atlas_payloads(root)
    base64_art_files, base64_art_assets_checked, base64_art_errors = audit_base64_artwork_payloads(root)
    errors.extend(atlas_payload_errors)
    errors.extend(base64_art_errors)

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
                        elif candidate.is_absolute() or ".." in candidate.parts:
                            errors.append(f"rights register line {line}: unsafe path: {rel}")
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

    image_paths = {p.relative_to(root).as_posix() for p in images}
    atlas_payload_paths = {p.relative_to(root).as_posix() for p in atlas_payload_files}
    base64_art_paths = {p.relative_to(root).as_posix() for p in base64_art_files}
    payload_paths = atlas_payload_paths | base64_art_paths
    actual = image_paths | payload_paths
    for rel in sorted(actual - set(rows)):
        label = "atlas payload part" if rel in payload_paths else "artwork file"
        errors.append(f"{label} is not registered: {rel}")
    for rel in sorted(set(rows) - actual):
        if rel.startswith(ATLAS_PAYLOAD_ROOT.as_posix() + "/"):
            errors.append(f"registered atlas payload part is missing: {rel}")
        elif any(rel.startswith(directory.as_posix() + "/") for directory in BASE64_ARTWORK_GROUPS):
            errors.append(f"registered Base64 artwork part is missing: {rel}")
        else:
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
        "registered_artwork_files": len(set(rows) & image_paths),
        "atlas_payload_parts": len(atlas_payload_files),
        "atlas_payloads_checked": atlas_payloads_checked,
        "base64_art_parts": len(base64_art_files),
        "base64_art_assets_checked": base64_art_assets_checked,
        "registered_atlas_payload_parts": len(set(rows) & atlas_payload_paths),
        "registered_base64_art_parts": len(set(rows) & base64_art_paths),
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
        print(f"Artwork: {report['artwork_files']} images; {report['registered_artwork_files']} registered")
        print(f"Attack atlas payloads: {report['atlas_payloads_checked']} PNGs from {report['atlas_payload_parts']} parts")
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

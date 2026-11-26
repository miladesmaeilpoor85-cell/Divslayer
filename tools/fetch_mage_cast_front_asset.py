#!/usr/bin/env python3
"""Validate the committed, user-supplied Mage casting atlas before Godot import."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

EXPECTED_BYTES = 546846
EXPECTED_SHA256 = "85ca84160b6a8b157023759604e0ffa4e0dd34efdf105fbf964430e566e61f60"
TARGET = Path(__file__).resolve().parents[1] / "assets/art/Heroes/mage_starter_cast_front.webp"
ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "creative/animation/mage_starter_cast_front.json"
EXPECTED_ATLAS = {
    "format": "webp",
    "width": 640,
    "height": 855,
    "columns": 4,
    "rows": 3,
    "cellWidth": 160,
    "cellHeight": 285,
    "frameCount": 12,
    "fps": 8,
    "loop": False,
}

def main() -> None:
    if not TARGET.is_file():
        raise FileNotFoundError(f"Committed Mage casting atlas is missing: {TARGET}")
    payload = TARGET.read_bytes()
    if len(payload) != EXPECTED_BYTES:
        raise ValueError(f"Mage casting atlas size mismatch: expected {EXPECTED_BYTES}, got {len(payload)}")
    if payload[:4] != b"RIFF" or payload[8:12] != b"WEBP":
        raise ValueError("Mage casting atlas is not a WebP image")
    digest = hashlib.sha256(payload).hexdigest()
    if digest != EXPECTED_SHA256:
        raise ValueError(f"Mage casting atlas SHA-256 mismatch: {digest}")
    if not MANIFEST.is_file():
        raise FileNotFoundError(f"Mage casting atlas manifest is missing: {MANIFEST}")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("asset") != TARGET.relative_to(ROOT).as_posix():
        raise ValueError("Mage casting atlas manifest points to a different runtime asset")
    if manifest.get("bytes") != len(payload):
        raise ValueError(f"Mage casting atlas manifest byte count mismatch: {manifest.get('bytes')}")
    if manifest.get("sha256") != digest:
        raise ValueError(f"Mage casting atlas manifest SHA-256 mismatch: {manifest.get('sha256')}")
    atlas = manifest.get("atlas", {})
    for key, expected in EXPECTED_ATLAS.items():
        if atlas.get(key) != expected:
            raise ValueError(f"Mage casting atlas manifest {key} mismatch: expected {expected}, got {atlas.get(key)}")
    print(
        f"Committed Mage casting atlas verified: {TARGET} "
        f"(640x855, {len(payload)} bytes, SHA-256 {digest}; manifest matches)"
    )

if __name__ == "__main__":
    main()

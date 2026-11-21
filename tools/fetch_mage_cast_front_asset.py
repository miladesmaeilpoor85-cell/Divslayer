#!/usr/bin/env python3
"""Materialize the pinned Mage cast-front atlas from repository-owned text parts.

RGB is high-quality lossy WebP (quality 90); the ALPH plane is retained exactly.
The source PNG master is delivered separately for lossless archival/reprocessing.
"""
from __future__ import annotations

import base64
import hashlib
import os
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PARTS_DIR = ROOT / "assets/art/Heroes/mage_cast_front_data"
EXPECTED_PARTS = 32
TARGET = ROOT / "assets/art/Heroes/mage_starter_cast_front.webp"
EXPECTED_BYTES = 215480
EXPECTED_SHA256 = "3f2b1fd3084b5c8344c113ae125a5bd151f90d14553bab820eb4ca67d28cbf60"
EXPECTED_DIMENSIONS = (640, 855)


def validate_payload(payload: bytes) -> None:
    if len(payload) != EXPECTED_BYTES:
        raise ValueError(
            f"Mage casting atlas size mismatch: expected {EXPECTED_BYTES}, got {len(payload)}"
        )
    if payload[:4] != b"RIFF" or payload[8:12] != b"WEBP":
        raise ValueError("Mage casting atlas is not a WebP image")
    if payload[12:16] != b"VP8X" or len(payload) < 30:
        raise ValueError("Mage casting atlas must use the extended WebP container")
    flags = payload[20]
    if not (flags & 0x10):
        raise ValueError("Mage casting atlas must declare alpha transparency")
    if b"ALPH" not in payload or b"VP8 " not in payload:
        raise ValueError("Mage casting atlas is missing its alpha or image payload")
    width = 1 + int.from_bytes(payload[24:27], "little")
    height = 1 + int.from_bytes(payload[27:30], "little")
    if (width, height) != EXPECTED_DIMENSIONS:
        raise ValueError(
            f"Mage casting atlas dimensions mismatch: expected {EXPECTED_DIMENSIONS}, got {(width, height)}"
        )
    digest = hashlib.sha256(payload).hexdigest()
    if digest != EXPECTED_SHA256:
        raise ValueError(f"Mage casting atlas SHA-256 mismatch: {digest}")


def main() -> None:
    parts = sorted(PARTS_DIR.glob("part_*.b64"))
    if len(parts) != EXPECTED_PARTS:
        raise FileNotFoundError(
            f"Expected {EXPECTED_PARTS} Mage atlas parts in {PARTS_DIR}, found {len(parts)}"
        )
    encoded = "".join(part.read_text(encoding="ascii").strip() for part in parts)
    try:
        payload = base64.b64decode(encoded, validate=True)
    except ValueError as exc:
        raise ValueError("Embedded Mage casting atlas base64 is invalid") from exc
    validate_payload(payload)

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    if TARGET.is_file():
        try:
            validate_payload(TARGET.read_bytes())
        except ValueError:
            pass
        else:
            print(f"Verified Mage casting atlas already present: {TARGET}")
            return

    fd, tmp_name = tempfile.mkstemp(prefix=".mage-cast-", suffix=".webp", dir=TARGET.parent)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
        os.replace(tmp_name, TARGET)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)
    print(
        f"Materialized Mage casting atlas: {TARGET} "
        f"({EXPECTED_DIMENSIONS[0]}x{EXPECTED_DIMENSIONS[1]}, {EXPECTED_BYTES} bytes)"
    )


if __name__ == "__main__":
    main()

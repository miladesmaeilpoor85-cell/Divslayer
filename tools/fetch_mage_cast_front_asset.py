#!/usr/bin/env python3
"""Materialize the pinned lossless Mage Starter cast-front atlas from the repository.

The encoded source is checked in so imports do not depend on an external media URL.
This script uses only the Python standard library and fails closed on changed bytes.
"""
from __future__ import annotations

import base64
import hashlib
import os
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENCODED_PARTS_DIR = ROOT / "assets/art/Heroes/mage_cast_front_data"
EXPECTED_PARTS = 25
TARGET = ROOT / "assets/art/Heroes/mage_starter_cast_front.webp"
EXPECTED_BYTES = 546846
EXPECTED_SHA256 = "85ca84160b6a8b157023759604e0ffa4e0dd34efdf105fbf964430e566e61f60"
EXPECTED_DIMENSIONS = (640, 855)


def validate_payload(payload: bytes) -> None:
    if len(payload) != EXPECTED_BYTES:
        raise ValueError(
            f"Mage casting atlas size mismatch: expected {EXPECTED_BYTES}, got {len(payload)}"
        )
    if payload[:4] != b"RIFF" or payload[8:12] != b"WEBP":
        raise ValueError("Mage casting atlas is not a WebP image")
    if payload[12:16] != b"VP8L" or len(payload) < 25 or payload[20] != 0x2F:
        raise ValueError("Mage casting atlas must be encoded as lossless WebP")
    # VP8L stores width/height minus one in packed 14-bit fields.
    h = payload[21:25]
    width = 1 + h[0] + ((h[1] & 0x3F) << 8)
    height = 1 + (h[1] >> 6) + (h[2] << 2) + ((h[3] & 0x0F) << 10)
    if (width, height) != EXPECTED_DIMENSIONS:
        raise ValueError(
            f"Mage casting atlas dimensions mismatch: expected {EXPECTED_DIMENSIONS}, got {(width, height)}"
        )
    if not (h[3] & 0x10):
        raise ValueError("Mage casting atlas does not declare alpha transparency")
    digest = hashlib.sha256(payload).hexdigest()
    if digest != EXPECTED_SHA256:
        raise ValueError(f"Mage casting atlas SHA-256 mismatch: {digest}")


def main() -> None:
    parts = sorted(ENCODED_PARTS_DIR.glob("part_*.b64"))
    if len(parts) != EXPECTED_PARTS:
        raise FileNotFoundError(
            f"Expected {EXPECTED_PARTS} embedded Mage atlas parts in {ENCODED_PARTS_DIR}, found {len(parts)}"
        )
    text = "".join(part.read_text(encoding="ascii").strip() for part in parts)
    try:
        payload = base64.b64decode(text, validate=True)
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
        f"Materialized lossless RGBA Mage casting atlas: {TARGET} "
        f"({EXPECTED_DIMENSIONS[0]}x{EXPECTED_DIMENSIONS[1]}, {EXPECTED_BYTES} bytes)"
    )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Validate the committed, user-supplied Mage casting atlas before Godot import."""
from __future__ import annotations

import hashlib
from pathlib import Path

EXPECTED_BYTES = 546846
EXPECTED_SHA256 = "85ca84160b6a8b157023759604e0ffa4e0dd34efdf105fbf964430e566e61f60"
TARGET = Path(__file__).resolve().parents[1] / "assets/art/Heroes/mage_starter_cast_front.webp"

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
    print(f"Committed Mage casting atlas verified: {TARGET} ({len(payload)} bytes, SHA-256 {digest})")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Fetch the pinned, user-approved Mage casting atlas for reproducible game builds.

The source is hosted in the owner's Higgsfield media workspace. Its byte count and
SHA-256 are pinned so a changed or replaced remote file fails closed.
"""
from __future__ import annotations

import hashlib
import os
import tempfile
import urllib.request
from pathlib import Path

ASSET_URL = "https://d2ol7oe51mr4n9.cloudfront.net/user_3MQ8TO8qFTeYUMz2ubrOoeLu1S0/40f6cdaa-2637-42f5-a2e1-eadda77d2a89.webp"
EXPECTED_BYTES = 123750
EXPECTED_SHA256 = "0935ef2c14ad89b12c8ee0a9417e1e464021e81d54c0f00b62f3a0e9ce314518"
TARGET = Path(__file__).resolve().parents[1] / "assets/art/Heroes/mage_starter_cast_front.webp"


def validate_payload(payload: bytes) -> None:
    if len(payload) != EXPECTED_BYTES:
        raise ValueError(f"Mage casting atlas size mismatch: expected {EXPECTED_BYTES}, got {len(payload)}")
    if payload[:4] != b"RIFF" or payload[8:12] != b"WEBP":
        raise ValueError("Mage casting atlas is not a WebP image")
    digest = hashlib.sha256(payload).hexdigest()
    if digest != EXPECTED_SHA256:
        raise ValueError(f"Mage casting atlas SHA-256 mismatch: {digest}")


def main() -> None:
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    if TARGET.is_file():
        existing = TARGET.read_bytes()
        try:
            validate_payload(existing)
        except ValueError:
            pass
        else:
            print(f"Mage casting atlas already verified: {TARGET}")
            return

    request = urllib.request.Request(
        ASSET_URL,
        headers={"User-Agent": "Divslayer-asset-fetch/1.0"},
    )
    with urllib.request.urlopen(request, timeout=45) as response:
        payload = response.read(EXPECTED_BYTES + 1)
    validate_payload(payload)

    fd, tmp_name = tempfile.mkstemp(prefix=".mage-cast-", suffix=".webp", dir=TARGET.parent)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
        os.replace(tmp_name, TARGET)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)
    print(f"Fetched and verified Mage casting atlas: {TARGET}")


if __name__ == "__main__":
    main()

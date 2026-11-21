# Mage Starter cast-front atlas — technical audit

**Status: lossless runtime candidate installed for validation. Visual approval and commercial-use rights remain pending.**

## Asset inspected
- Runtime file: `assets/art/Heroes/mage_starter_cast_front.webp`
- Encoded size: 640 × 855 px, RGBA, 546,846 bytes
- Layout: 4 columns × 3 rows
- Cell size: 160 × 285 px (12 frames)
- Encoding: lossless WebP VP8L with alpha
- SHA-256: `85ca84160b6a8b157023759604e0ffa4e0dd34efdf105fbf964430e566e61f60`

## Runtime contract
- 12 temporal samples from source frames 16, 24, 32, 40, 48, 56, 64, 72, 80, 92, 104, 120.
- 4 columns × 3 rows; each cell 160 × 285 px.
- 8 FPS; non-looping one-shot.
- Feet pivot offset: `Vector2(-80, -270)`.
- Display scale: `0.612`.

## Verification status
The binary is pinned by byte count, WebP signature and SHA-256 in `tools/fetch_mage_cast_front_asset.py`. The original source videos have been uploaded to the repository root, but their frame contents have not yet been independently decoded in this environment. The two PNG uploads likewise require visual inspection at native resolution; filename and file size alone do not establish artistic quality, alpha integrity, or intended use.

The atlas metadata and sampling contract are carried forward from the local reconstruction audit. CI import/export and Android runtime tests must still validate the actual committed bytes. The PNG/video visual review remains an explicit outstanding item.

## Rights
The animation derives from user-provided media, but provider/model provenance and applicable commercial-use terms remain unverified. Technical validation does not establish commercial rights.

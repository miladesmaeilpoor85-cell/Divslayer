# Mage Starter cast-front atlas — source rebuild audit

**Status: lossless source rebuild completed; visual in-game acceptance is still pending.**

## Source inspected

- Uploaded video: 1000078750.mp4
- Video codec: H.264 / MP4
- Resolution: 480×854
- Frame rate: 24 FPS
- Video stream: 121 frames, 5.041667 seconds
- Container duration: 5.056 seconds
- Chosen frame indices: 16, 24, 32, 40, 48, 56, 64, 72, 80, 92, 104, 120

The selected samples preserve the front-facing cast sequence: idle/anticipation, staff and free-hand movement, channeling with the cyan magical glow, then recovery.

## Output assets

| Asset | Dimensions | Format | Purpose |
|---|---:|---|---|
| Runtime atlas | 640×855 | Lossless WebP RGBA | Godot texture, 4×3 cells |
| Runtime cell | 160×285 | Lossless WebP RGBA | One frame per cell |
| Full source master | 2112×2706 | PNG RGBA | 4×3 native-resolution samples, 528×902 cells |
| Runtime PNG copy | 640×855 | PNG RGBA | Standalone preview/inspection copy |

- Runtime WebP: 546,846 bytes; SHA-256 85ca84160b6a8b157023759604e0ffa4e0dd34efdf105fbf964430e566e61f60
- Runtime PNG: 729,619 bytes; SHA-256 faf038963ca2068edb3bbaeabddbe4af9f12ffd607dd4aee9e6a38af9fb47ff1
- Full master PNG: 650,557 bytes; SHA-256 522c573b4e02fb9288eb7866a5ed613b2731ba6be52a39386683b574d1c43ee8

## Alpha-bound audit

Margins are measured on the 160×285 runtime cell after background extraction, edge fade and downsampling. Bounding boxes use half-open coordinates.

| Atlas frame | Source frame | Left | Top | Right | Bottom | Opaque pixels on cell edge |
|---:|---:|---:|---:|---:|---:|---|
| 0 | 16 | 27 | 39 | 24 | 15 | none |
| 1 | 24 | 29 | 39 | 25 | 15 | none |
| 2 | 32 | 29 | 38 | 24 | 15 | none |
| 3 | 40 | 29 | 39 | 24 | 15 | none |
| 4 | 48 | 28 | 39 | 24 | 15 | none |
| 5 | 56 | 28 | 39 | 24 | 15 | none |
| 6 | 64 | 27 | 33 | 13 | 15 | none |
| 7 | 72 | 25 | 32 | 12 | 15 | none |
| 8 | 80 | 18 | 31 | 11 | 15 | none |
| 9 | 92 | 16 | 32 | 12 | 15 | none |
| 10 | 104 | 27 | 32 | 12 | 15 | none |
| 11 | 120 | 27 | 38 | 23 | 15 | none |

All twelve runtime frames have fully transparent outer cell edges. The minimum measured margin is 11 px on the right of frame 8; the staff crystal remains inside the frame. Feet remain aligned at the same baseline (row 270).

## Matte and edge treatment

- Green removal is limited to saturated green pixels connected to the video-frame exterior, with a two-pixel anti-aliased fringe.
- The background colour is sampled from the frame border, rather than assuming a fixed chroma RGB value.
- Semi-transparent edge pixels are unmixed against the sampled green screen to reduce green spill on hair, cape and trousers.
- The cyan magical flare reaches source-image edges in frames 7–10. A 48 px boundary fade removes abrupt rectangular edge contact while retaining the interior glow. No off-frame image content is invented or reconstructed.

## Runtime contract updated together

- Atlas: 4 columns × 3 rows
- Cell: 160×285
- Frames: 12
- FPS: 8
- Loop: false
- Foot pivot offset: (-80, -270)
- Player display scale: 0.612

The embedded lossless WebP is materialized by tools/fetch_mage_cast_front_asset.py. Godot import and Android emulator QA must pass before the rebuilt atlas is accepted in-game.

## Rights

The MP4 was supplied by the project owner. The model/provider provenance and applicable commercial-use terms were not independently established, so the asset remains UNVERIFIED. A successful extraction, build or emulator test is not rights clearance.

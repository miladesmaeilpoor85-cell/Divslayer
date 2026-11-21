# Mage Starter cast-front atlas — technical edge audit

**Status: diagnostic only. The current runtime atlas is not approved as the high-resolution production master.**

## Asset inspected

- Runtime file: `assets/art/Heroes/mage_starter_cast_front.webp`
- Encoded size: 384 × 513 px, RGBA, 123,750 bytes
- Layout: 4 columns × 3 rows
- Cell size: 96 × 171 px (12 frames)
- Encoding: lossy WebP. The alpha channel is present, but the RGB image data is not a lossless master.

## Per-frame alpha bounds

Coordinates are local to each cell and use Pillow's half-open bounding-box convention `(left, top, right, bottom)`.

| Frame | Alpha bbox | Left margin | Top margin | Right margin | Bottom margin | Alpha on cell edge |
|---:|---|---:|---:|---:|---:|---|
| 0 | (9, 4, 89, 168) | 9 | 4 | 7 | 3 | none |
| 1 | (11, 4, 88, 168) | 11 | 4 | 8 | 3 | none |
| 2 | (11, 4, 88, 168) | 11 | 4 | 8 | 3 | none |
| 3 | (11, 4, 89, 168) | 11 | 4 | 7 | 3 | none |
| 4 | (10, 4, 89, 168) | 10 | 4 | 7 | 3 | none |
| 5 | (10, 4, 89, 168) | 10 | 4 | 7 | 3 | none |
| 6 | (9, 4, 89, 168) | 9 | 4 | 7 | 3 | none |
| 7 | (10, 3, 92, 168) | 10 | 3 | 4 | 3 | none |
| 8 | (10, 0, 96, 168) | 10 | 0 | 0 | 3 | top: 5 pixels; right: 1 pixel |
| 9 | (10, 2, 93, 168) | 10 | 2 | 3 | 3 | none |
| 10 | (10, 3, 89, 168) | 10 | 3 | 7 | 3 | none |
| 11 | (9, 4, 87, 168) | 9 | 4 | 9 | 3 | none |

## Visual review

Frames 0–7 and 9–11 retain transparent space at every cell edge. Frame 8 visibly brings the staff finial to the top boundary; its alpha bounds confirm that the cutout touches the top edge and has one opaque/partially opaque pixel on the right boundary. This is an actual edge-contact warning, not merely a low margin estimate.

Frame 9 is close to the top and right boundaries (2 px and 3 px respectively), so it also needs a wider crop/padding check against the original frame.

## Rebuild decision

Do **not** upscale the current WebP and call it a higher-quality master. Upscaling cannot recover detail lost by the 96 × 171 px lossy source.

The original Seedance clip used for sampling (reported as 480 × 854 px, 24 FPS, 121 frames) and the lossless 1920 × 2562 PNG master are not present in the current conversation files, the accessible Library listing, or the accessible Higgsfield project workspace. Without the source clip/master, missing pixels at frame 8 cannot be reconstructed faithfully and the original cutout/matte cannot be revalidated.

To complete the rebuild, restore the original MP4 or the lossless master, then:
1. Re-extract the twelve approved frame indices from the original source.
2. Preserve the cutout as true RGBA in PNG, not lossy WebP.
3. Add safe transparent padding and verify all twelve per-cell alpha bounds against the cell edges.
4. Review frames 8 and 9 at native resolution, then update the cell-size, pivot/offset and runtime import contract together.
5. Re-run Android QA and inspect the resulting in-game cast at gameplay scale.

**Current decision:** retain the existing runtime file unchanged for diagnostic testing only; do not promote it as a high-resolution, edge-approved atlas.

# Class-card artwork integration — 20 November 2026

## What changed

The New Game class-selection screen now uses four user-provided character portraits in place of the legacy animated mid-tier sprite previews.

| Class | Selected identity | Source reference |
|---|---|---|
| Warrior | Male | User-provided Warrior turnaround |
| Mage | Female | User-provided final female Mage turnaround |
| Rogue | Female | User-provided final female Rogue turnaround |
| Paladin | Male | User-provided Paladin turnaround |

The four optimized WebP crops are stored in `assets/art/ClassCards/` and loaded by `scripts/menu.gd`.

## Scope and limitations

- This commit changes the **class-selection UI only**.
- It does not replace the live player sprite atlases registered in `data/art_manifest.json`.
- The four six-pose combat sheets remain visual references for future class-specific animation work; they are not sequential animation frames and are not loaded as runtime clips.
- The source turnarounds have studio backgrounds and are not approved transparent gameplay sprites.
- The existing Godot hero atlas, frame dimensions, pivots, combat timing and gameplay mechanics remain unchanged.

## Next gameplay-art stage

To make the two female identities visible during actual gameplay, create genuine transparent, hand-painted 2D sprite atlases for Mage and Rogue that follow the current hero atlas contract (three directions, 160×156 px cells, 800×468 px sheet) and test import, pivots and device-scale readability. The combat pose sheets can guide gesture and effects, but each real animation frame must contain a distinct pose.

## Rights and provenance

The four class-card files are recorded in `docs/ASSET_RIGHTS_REGISTER.csv` as `UNVERIFIED`. The user supplied the generated images, but the exact generation provider, creation date and applicable terms have not been established here. Do not mark these assets commercially cleared until the applicable provider terms are checked.

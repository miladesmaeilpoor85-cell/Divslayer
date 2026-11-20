# Warrior starter sprite pilot

**Status:** candidate integration on `art/warrior-starter-sprite-pilot`; not merged to `main`.

## Files

| Path | Purpose |
|---|---|
| `assets/art/Heroes/warrior_starter_source.webp` | Compact 5×3 source atlas, 160×93 px |
| `assets/art/Heroes/warrior_starter_mask.png` | Compact 1-bit greyscale cloth mask, 160×93 px |
| `scripts/generated/warrior_starter_art.gd` | Cell-by-cell runtime atlas expander/cache |
| `data/hero_masks.json` | Warrior starter shader key = 0.237 |

## Runtime layout

The source image stores 15 independent transparent cells: five columns (`walk0`–`walk3`, `attack`) and three rows (`down`, `up`, `side`). The source cell size is 32×31. The helper expands each cell separately to 160×156 using nearest-neighbour interpolation, producing the exact 800×468 atlas expected by the existing `data/art_manifest.json`. `scripts/sheets.gd` selects this generated runtime texture only for `heroes/warrior_starter`; all other hero sheets and the original Warrior PNG fallback remain unchanged.

The source art is a low-resolution pixel-oriented interpretation of the approved Warrior identity: male Persian heroic fighter, bronze/gold equipment, crimson cape, and curved sword. It is a prototype bridge from the uploaded concept art to the project's compact 2D sprite scale, not a final high-detail hand-drawn sprite.

## Recolouring

The compact 1-bit greyscale mask has the same aspect ratio and cell layout as the compact source atlas; white pixels mark the crimson cloth. The wardrobe shader samples its red/green channels and clamps the mask intensity. The key is 0.237. The existing mask path and shader are retained.

## Explicit limitations

- Only the Warrior **starter** look is affected.
- No separate heavy attack, hurt/stagger, block, dodge, death, or other new combat clips are included.
- There is still only one attack pose per direction; four walk cells are the only looping frames.
- The generated art has not yet passed in-game native-scale review or physical-device review.
- Other Warrior tiers and Mage, Rogue, and Paladin in-game sprites are unchanged.
- The original Warrior starter PNG remains as a rollback fallback.

## Verification gates

1. Godot 4.7.2 resource import and all headless tests.
2. Frame grid, transparency, bottom-centre pivot, and side-flip inspection.
3. Wardrobe recolour checks on default and non-default looks.
4. Actual-scale gameplay review and Android QA export/emulator launch.
5. Physical Android device review before the change is considered fully approved.

## Provenance

The source art and derived mask are recorded in `docs/ASSET_RIGHTS_REGISTER.csv`. Provider terms have not been independently reviewed; commercial-use status remains `UNVERIFIED`.

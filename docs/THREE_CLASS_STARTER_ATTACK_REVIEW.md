# Three-class Starter Attack Atlas Review

Date: 2026-11-20  
Scope: Mage Starter, Rogue Starter, Paladin Starter  
Source: Three 1536 × 1147 image files supplied in the project conversation (provider/creator not stated).

## Processing and technical checks

Each source was normalized to an exact 4-column × 3-row atlas (1536 × 1152). The 384 × 384 source cells were uniformly reduced to 338 × 338 and centered inside each cell to preserve weapon tips and avoid boundary clipping. The importer then exported four frames per direction, three directions, 160 × 156 pixels per transparent frame, plus a 640 × 468 packed atlas.

| Class | Exact duplicate pairs | Lowest adjacent changed-pixel ratio | Import status |
|---|---:|---:|---|
| Mage | 0 | 28.90% | Passed |
| Rogue | 0 | 20.89% | Passed |
| Paladin | 0 | 22.89% | Passed |

The importer found no exact duplicate frames and no low-motion warnings (warning threshold: 2.5%). It removed edge-connected magenta background, magenta spill around transparency edges, and enclosed chroma-key regions. Enclosed-key cleanup was particularly important for the Rogue's white slash arcs. All exported frames share the same bottom baseline.

## Visual review

### Mage Starter
- The same blue-robed Mage and hooked staff remain recognizable in front, back, and side rows.
- Staff placement changes through anticipation and wind-up; the contact pose carries the small flame accent at the staff tip; recovery returns to a guarded staff position.
- No missing staff, extra limbs, or exact duplicate frames were observed.
- The small flame and a few staff-tip particles are present only in the contact pose, as intended.

### Rogue Starter
- The hood, green/brown costume, back-mounted quiver, and dual daggers are consistent across the three directions.
- The contact column uses the paired slash arcs. The back-facing row shows both daggers; in side view, the far dagger is naturally occluded by the body in some poses.
- No extra arm or exact duplicate frame was observed.
- The generated slash gaps were cleaned of enclosed magenta pixels before transparency export.

### Paladin Starter
- Sword, round shield, red headband, and armour remain consistent across the three directions.
- The shield remains on the same character-side across poses, changing screen side appropriately with the view. Sword and shield are both present in each direction.
- Rear-facing anticipation and wind-up are visually similar, and side-view contact/recovery are also relatively close, but they are not exact duplicates and changed-pixel ratios remain well above the warning threshold.
- This is acceptable for the Starter pass; a future art-polish pass could make those two transitions more expressive.

## Runtime registration

The three packed atlases are registered through `attackSheet`, each with:
- `attackFrames: 4`
- `attackFps: 24`
- `attackImpactFrame: 2` (zero-based contact frame)

The existing `scripts/sheets.gd` implementation loads a separate attack atlas without changing walk/idle sheets. Existing player combat code delays the hit to the configured contact frame. For a four-frame 24 FPS light attack, visual clip length is 0.1667 seconds (the previous minimum was 0.16 seconds); the heavy-attack minimum of 0.26 seconds remains unchanged. Damage, reach, cooldown, combo, and skills are not intentionally changed by this art import.

## Rights and release status

The images were supplied by the user, but the creator and generation provider were not identified in the supplied files. Their provenance and provider terms have not been independently verified. The three assets are therefore recorded as `UNVERIFIED` in `docs/ASSET_RIGHTS_REGISTER.csv`. This is not a conclusion that the assets lack rights; it means commercial-use status must not be assumed until the source/provider terms are confirmed.

## Validation gate

This review records importer output and manual visual inspection. The feature branch must still pass the repository's Godot 4.7.2 and Android QA workflows before merge. Successful CI is required before calling the runtime integration complete.

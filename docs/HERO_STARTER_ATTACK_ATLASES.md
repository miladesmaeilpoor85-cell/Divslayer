# Rogue and Paladin starter attack atlases

## Runtime integration

This branch activates four-frame starter attacks for Mage, Rogue and Paladin. Each 640 × 468 PNG atlas contains a 4 × 3 grid of 160 × 156 cells. Rows are `down`, `up`, and `side`; columns are `anticipation`, `windup`, `contact`, and `recovery`. All three entries use 24 FPS and zero-based impact frame 2.

To keep the binary assets export-safe through the existing repository workflow, each PNG is stored as ordered text-safe Base64 parts under `assets/art/Heroes/attack_atlas_data/{rogue,paladin}/`. `scripts/sheets.gd` concatenates the declared parts, decodes the PNG at runtime, and creates the existing `SpriteFrames`. The Android QA export preset includes `*.b64` in the PCK. The source PNG is 128-colour indexed with retained per-pixel alpha.

## Art source and validation

The imported source sheets were user-supplied in this conversation:
- Rogue: `1000078728.png`
- Paladin: `1000078727.png`

The source sheets were 1536 × 1147 px and were padded to 1536 × 1152 px (five rows added at the bottom; no source art was cropped). Each importer output contains 12 frames, aligned their feet, used premultiplied-alpha resizing, removed connected magenta matte spill, and set an 8 px minimum top margin.

No exact duplicate frames were found. All adjacent frame changes exceed the 2.5% low-motion threshold. The following source-edge review warnings are retained rather than hidden:

| Class | Direction / phase | Minimum source margin |
|---|---|---:|
| Mage | up / contact, up / recovery, side / contact | 0 px (isolated effect pixels touch source cell boundary; inspect preview) |
| Rogue | down / contact | 2 px |
| Rogue | up / contact | 7 px |
| Rogue | side / recovery | 7 px |
| Paladin | side / windup | 7 px |
| Paladin | side / contact | 1 px |
| Paladin | side / recovery | 2 px |

These are review warnings, not proof of cropping. The final output gives each pose an 8 px top margin and a common bottom/foot baseline. Review the GIF previews and screenshots in the CI artifact before merging.

## Scope and limitations

- All three Starter atlases are activated; Mage retains source-edge warnings for small effect pixels as listed above.
- Warrior is unchanged; its existing four-frame Starter sequence remains registered.
- This change does not alter damage, hit count, attack cooldown, stun, invulnerability, or ultimate logic.
- All three new class atlases remain `UNVERIFIED` for commercial use. The source creator/provider and license evidence were not independently recorded, so technical integration is not legal clearance.

## Test requirements

The PR must pass Python/Ruff and artwork tests, all four Godot 4.7.2 headless test shards, and Android QA APK export plus emulator launch. Do not merge if a runtime asset-loading error, script parse error, or emulator startup failure is reported.

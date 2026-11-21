# Rogue Starter attack atlas

## Runtime integration

This branch activates a four-frame Rogue Starter attack. The 640 × 468 PNG atlas is encoded into ten ordered Base64 text parts under `assets/art/Heroes/attack_atlas_data/rogue/`. The rows are `down`, `up`, and `side`; the columns are `anticipation`, `windup`, `contact`, and `recovery`. The manifest uses 24 FPS and zero-based impact frame 2.

`scripts/sheets.gd` concatenates the declared parts, decodes the PNG at runtime, and creates the existing `SpriteFrames`. The Android QA export preset includes `*.b64` in the PCK.

## Art source and validation

The Rogue source atlas was supplied in this conversation as `1000078728.png`. It was padded to a 4 × 3 grid before extraction; source pixels were not cropped. The importer creates 12 transparent 160 × 156 frames, aligns the feet, uses premultiplied-alpha resizing, supports connected magenta matte cleanup, and keeps an 8 px top margin.

No exact duplicate frames were found. All adjacent frame changes exceed the 2.5% low-motion threshold. Three source cells remain flagged for edge review:
- down/contact: 2 px source margin
- up/contact: 7 px source margin
- side/recovery: 7 px source margin

These are warnings, not proof of cropping. They remain visible in the importer report and should be checked at native pixel size on the Android build.

## Scope and limitations

- Rogue Starter is the only class activated by this PR.
- Mage and Paladin remain on their existing runtime attacks until complete source atlases have been transferred and verified.
- Warrior is unchanged; its existing four-frame Starter sequence remains registered.
- This change does not alter damage, hit count, attack cooldown, stun, invulnerability, or ultimate logic.
- Commercial use for the Rogue atlas remains `UNVERIFIED`; the creator/provider and license evidence have not been independently recorded.

## Test requirements

The PR must pass Python/Ruff and artwork tests, all four Godot 4.7.2 headless test shards, and Android QA APK export plus emulator launch. Do not merge if a runtime asset-loading error, script parse error, or emulator startup failure is reported.

# Warrior animation review scene | بازبینی انیمیشن جنگجوی دیوکش

**Status:** isolated review candidate — the production Warrior starter now has a separate four-frame attack atlas, but this scene remains a read-only review harness and is not a replacement for in-game combat.

## Open the scene

From the project root:

```sh
godot --path . res://scenes/dev/warrior_animation_review.tscn
```

On the review screen, tap **روبه‌رو**, **پشت**, or **نیم‌رخ** to preview the four-frame walk cycle for each direction. Tap **حمله** or press Space to see the current side-attack pose with a short, timed sword-slash arc. Keyboard shortcuts: `1` front/down, `2` back/up, `3` side/right, `Space` attack.

## Sprite layout and import contract

The review scene deliberately loads the existing `assets/art/Heroes/warrior_starter.png` atlas read-only and reads cell dimensions, row ordering, and foot pivot from `data/art_manifest.json`. The expected project layout is 800 × 468 pixels: five 160 × 156 cells per row, with rows `down`, `up`, `side`; columns 0–3 are walk frames and column 4 is the single-frame attack pose. The scene does not replace the production sheet, edit `data/art_manifest.json`, change `scripts/sheets.gd`, or alter the pivot, class IDs, or main scene.

The production Warrior starter attack now uses `assets/art/Heroes/warrior_starter_attack.png`, a separate 4-column × 3-direction atlas aligned to the existing 160 × 156 cell grid. The playable attack animation reads its four frames through the metadata-driven loader in `scripts/sheets.gd`; walk frames remain unchanged. This review scene intentionally continues to use the original 5-column atlas read-only and its own Godot-drawn slash arc, so it can compare the established production walk poses without changing combat state.

## Checks

`tests/warriorreviewtest.gd` verifies the scene loads, all three directional walk animations contain four frames, all idle/attack poses exist, atlas cells match 160 × 156, and the attack effect returns to the selected walk animation. It is included in `tools/run_all_tests.sh`.

The image has real alpha transparency and passed local 800 × 468 / 15-cell bounds checks. GitHub CI must still perform a clean Godot 4.7.2 import and headless test run. A human must inspect the result in Krita and the owner must test the review scene on Android before any runtime promotion.

## Provenance and rights

The original review-scene walk sheet remains the already-tracked production sprite. The separate four-frame attack atlas is an AI-generated candidate, aligned to the same 160 × 156 cells and stored separately so the walk sheet is not overwritten. Its generation provenance is recorded in `docs/ASSET_RIGHTS_REGISTER.csv`.

**Commercial-use / rights status: UNVERIFIED.** Generation and successful technical import do not by themselves prove authorship, exclusivity, or commercial-use clearance. This candidate must remain a review-only resource until the service terms and project release requirements are checked. Do not copy it over `assets/art/Heroes/warrior_starter.png` without a separate reviewed PR and Android test.

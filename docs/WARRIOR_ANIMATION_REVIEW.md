# Warrior animation review scene | بازبینی انیمیشن جنگجوی دیوکش

**Status:** isolated review candidate — not connected to the playable character and not a production-approved replacement.

## Open the scene

From the project root:

```sh
godot --path . res://scenes/dev/warrior_animation_review.tscn
```

On the review screen, tap **روبه‌رو**, **پشت**, or **نیم‌رخ** to preview the four-frame walk cycle for each direction. Tap **حمله** or press Space to see the current side-attack pose with a short, timed sword-slash arc. Keyboard shortcuts: `1` front/down, `2` back/up, `3` side/right, `Space` attack.

## Sprite layout and import contract

The review scene deliberately loads the existing `assets/art/Heroes/warrior_starter.png` atlas read-only and reads cell dimensions, row ordering, and foot pivot from `data/art_manifest.json`. The expected project layout is 800 × 468 pixels: five 160 × 156 cells per row, with rows `down`, `up`, `side`; columns 0–3 are walk frames and column 4 is the single-frame attack pose. The scene does not replace the production sheet, edit `data/art_manifest.json`, change `scripts/sheets.gd`, or alter the pivot, class IDs, or main scene.

The separate ImageGen concept pack contains 12 distinct walk poses (four per direction), rather than hop/squash transformations. That new atlas is not loaded by this review scene and is not yet promoted to the repository. The review scene is intentionally a safe harness for the current atlas and adds a separate Godot-drawn slash arc with a 0.34-second preparation/contact/fade window. It is an effect prototype, not a complete multi-frame body-attack animation and not combat hitbox logic.

## Checks

`tests/warriorreviewtest.gd` verifies the scene loads, all three directional walk animations contain four frames, all idle/attack poses exist, atlas cells match 160 × 156, and the attack effect returns to the selected walk animation. It is included in `tools/run_all_tests.sh`.

The image has real alpha transparency and passed local 800 × 468 / 15-cell bounds checks. GitHub CI must still perform a clean Godot 4.7.2 import and headless test run. A human must inspect the result in Krita and the owner must test the review scene on Android before any runtime promotion.

## Provenance and rights

The separate walk-cycle concept sheet was created with ChatGPT ImageGen on 19 November 2026 using the accepted Divslayer warrior turnaround as visual guidance. Its printed checkerboard and divider lines were removed during local processing before alignment to the current atlas grid. The concept sheet is delivered outside the runtime asset tree for review; the GitHub scene uses the already-tracked production sprite.

**Commercial-use / rights status: UNVERIFIED.** Generation and successful technical import do not by themselves prove authorship, exclusivity, or commercial-use clearance. This candidate must remain a review-only resource until the service terms and project release requirements are checked. Do not copy it over `assets/art/Heroes/warrior_starter.png` without a separate reviewed PR and Android test.

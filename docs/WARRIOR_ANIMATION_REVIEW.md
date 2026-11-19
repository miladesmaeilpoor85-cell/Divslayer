# Warrior animation review scene | بازبینی انیمیشن جنگجوی دیوکش

**Status:** isolated review candidate — not connected to the playable character and not a production-approved replacement.

## Open the scene

From the project root:

```sh
godot --path . res://scenes/dev/warrior_animation_review.tscn
```

On the review screen, tap **روبه‌رو**, **پشت**, or **نیم‌رخ** to preview the four-frame walk cycle for each direction. Tap **حمله** or press Space to see the current side-attack pose with a short, timed sword-slash arc. Keyboard shortcuts: `1` front/down, `2` back/up, `3` side/right, `Space` attack.

## Sprite layout and import contract

The review sheet is decoded from the text-safe WebP payload at `assets/art/Heroes/review/warrior_starter_walkcycle.webp.b64`. It is 800 × 468 pixels, preserving the project's existing 5-column × 3-row atlas contract: 160 × 156 pixels per cell; rows `down`, `up`, `side`; columns 0–3 are walk frames and column 4 is the existing single-frame attack pose. The original runtime `warrior_starter.png`, `data/art_manifest.json`, `scripts/sheets.gd`, pivot, class IDs, and main scene are untouched.

The 12 walk poses are distinct ImageGen-generated frames (four per direction), not the older hop/squash transformations. The attack column remains a single pose, because no consistent multi-frame body-attack sequence has been approved. The demo therefore adds a separate Godot-drawn slash arc with a 0.34-second preparation/contact/fade window. It is an effect prototype, not a complete hand-drawn multi-frame attack animation and not combat hitbox logic.

## Checks

`tests/warriorreviewtest.gd` verifies the scene loads, all three directional walk animations contain four frames, all idle/attack poses exist, atlas cells match 160 × 156, and the attack effect returns to the selected walk animation. It is included in `tools/run_all_tests.sh`.

The image has real alpha transparency and passed local 800 × 468 / 15-cell bounds checks. GitHub CI must still perform a clean Godot 4.7.2 import and headless test run. A human must inspect the result in Krita and the owner must test the review scene on Android before any runtime promotion.

## Provenance and rights

Created with ChatGPT ImageGen on 19 November 2026 using the accepted Divslayer warrior turnaround as visual guidance. The generated image contained a printed checkerboard and divider lines; those were removed in the local processing step before the frames were aligned to the existing atlas grid. The compact WebP payload is stored as base64 text solely so the review scene can decode it in Godot without altering the production art inventory.

**Commercial-use / rights status: UNVERIFIED.** Generation and successful technical import do not by themselves prove authorship, exclusivity, or commercial-use clearance. This candidate must remain a review-only resource until the service terms and project release requirements are checked. Do not copy it over `assets/art/Heroes/warrior_starter.png` without a separate reviewed PR and Android test.

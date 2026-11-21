# Mage Starter front casting animation

## Scope
This is an optional one-shot visual overlay for the Mage Starter calling. It is not a replacement for the shared three-direction hero sheet. The overlay plays only after a successful spell cast while the Mage is stationary and facing down/front. Movement, attacks, blocking, dodging, stealth, death, or a change of hero tier cancels the overlay and restores the existing animation.

## Processing pipeline
- Source: user-provided Mage casting video, 480×854, 24 FPS, 5.056 seconds.
- Twelve temporal samples: source frames 16, 24, 32, 40, 48, 56, 64, 72, 80, 92, 104, 120.
- Background processing: edge-connected green-key removal with conservative green despill, followed by premultiplied-alpha resizing.
- Atlas: `assets/art/Heroes/mage_starter_cast_front.webp`, 4 columns × 3 rows, 160×285 pixels per cell, 8 FPS, one-shot.
- The 12 frames represent consecutive temporal samples from a single front-facing casting sequence. Atlas rows are not down/up/side directions.

## Build dependency
The lossless WebP atlas is committed at `assets/art/Heroes/mage_starter_cast_front.webp`. CI runs `python3 tools/fetch_mage_cast_front_asset.py` to verify the committed file byte count, WebP signature, and SHA-256 before Godot import/export; no external asset download is required.

## Godot integration
`scripts/sheets.gd` builds a separate non-looping `cast_front` SpriteFrames resource. `scripts/player.gd` displays it as a temporary overlay after `caster.cast_done` for Mage Starter only. Runtime contract: 4×3 atlas, 160×285 px per cell, 12 frames, 8 FPS, loop=false, feet pivot offset `(-80, -270)`, display scale `0.612`. Existing walk, idle, attack, damage, cooldown and spell logic remain unchanged.

## Rights
The animation derives from user-provided media, but the applicable video-generation provider terms and commercial-use evidence have not been independently verified. The new atlas remains `UNVERIFIED` in the asset rights register. Do not treat a successful technical import as rights clearance.

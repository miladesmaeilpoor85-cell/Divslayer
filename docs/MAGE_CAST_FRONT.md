# Mage Starter front casting animation

## Scope
This is an optional one-shot visual overlay for the Mage Starter calling. It is not a replacement for the shared three-direction hero sheet. The overlay plays only after a successful spell cast while the Mage is stationary and facing down/front. Movement, attacks, blocking, dodging, stealth, death, or a change of hero tier cancels the overlay and restores the existing animation.

## Processing pipeline
- Source: user-provided Mage casting video, 480×854, 24 FPS, 5.056 seconds.
- Twelve temporal samples: source frames 16, 24, 32, 40, 48, 56, 64, 72, 80, 92, 104, 120.
- Background processing: edge-connected green-key removal with conservative green despill, followed by premultiplied-alpha resizing.
- Atlas: `assets/art/Heroes/mage_starter_cast_front.webp`, 4 columns × 3 rows, 96×171 pixels per cell, 8 FPS, one-shot.
- The 12 frames represent consecutive temporal samples from a single front-facing casting sequence. Atlas rows are not down/up/side directions.

## Build dependency
The atlas is hosted in the owner's Higgsfield workspace and is fetched by `python3 tools/fetch_mage_cast_front_asset.py` before Godot import/export in CI. The script verifies the exact byte count, WebP signature, and SHA-256 and fails closed if the hosted asset disappears or changes. Run the same command before opening/importing the project locally. This remote-host dependency is intentional for this PR because the original binary was produced outside the game engine and could not be committed directly through the available repository file channel.

## Godot integration
`scripts/sheets.gd` builds a separate non-looping `cast_front` SpriteFrames resource. `scripts/player.gd` displays it as a temporary overlay after `caster.cast_done` for Mage Starter only. Existing walk, idle, attack, damage, cooldown and spell logic remain unchanged.

## Rights
The animation derives from user-provided media, but the applicable video-generation provider terms and commercial-use evidence have not been independently verified. The new atlas remains `UNVERIFIED` in the asset rights register. Do not treat a successful technical import as rights clearance.

# Mage Starter front casting animation

## Scope

This is an optional one-shot visual overlay for the Mage Starter calling. It is not a replacement for the shared three-direction hero sheet. The overlay plays only after a successful spell cast while the Mage is stationary and facing down/front. Movement, attacks, blocking, dodging, stealth, death, or a change of hero tier cancels the overlay and restores the existing animation.

## Source and extraction

- Source: MP4 supplied by the project owner in this conversation; H.264, 480×854, 24 FPS, 121 frames, 5.041667 s video stream.
- Twelve temporal samples at 8 FPS: source frames 16, 24, 32, 40, 48, 56, 64, 72, 80, 92, 104, 120.
- Green-screen removal uses an edge-connected chroma mask. Cyan/blue magical light is preserved; semi-transparent boundary pixels are unmixed against the sampled screen colour to reduce green spill.
- The magical flare in samples 64–104 reaches the source-video border. A 48 px edge fade makes those flare boundaries transition to transparency rather than leaving a hard rectangular cut. This does not synthesize missing off-frame pixels.
- The whole source frame is fitted into each output cell. All cells keep consistent feet alignment and transparent safety margins.

## Atlas and runtime

- Runtime texture: assets/art/Heroes/mage_starter_cast_front.webp — lossless WebP with alpha.
- Layout: 4 columns × 3 rows; twelve sequential frames, not directional rows.
- Runtime cell: 160×285 px; atlas: 640×855 px.
- Playback: 8 FPS, non-looping.
- Godot pivot: Vector2(-80, -270).
- Display scale: 0.612, selected to retain the previous on-screen size while using the higher-resolution cells.
- Full sampled-resolution RGBA PNG master: 2112×2706 px, with 528×902 px cells and 24 px external transparent padding. It is delivered separately from the runtime asset.

## Reproducible build input

The lossless WebP source bytes are stored as ASCII base64 in assets/art/Heroes/mage_starter_cast_front_lossless.webp.b64. Run python3 tools/fetch_mage_cast_front_asset.py before opening/importing the project. The script uses only Python's standard library and verifies exact byte count, SHA-256, lossless WebP encoding, alpha presence and image dimensions. Builds no longer download the earlier lossy atlas from an external URL.

## Godot integration

scripts/sheets.gd builds a separate non-looping cast_front SpriteFrames resource. scripts/player.gd displays it as a temporary overlay after caster.cast_done for Mage Starter only. Existing walk, idle, attack, damage, cooldown and spell logic remain unchanged.

## Rights

The video is the file supplied by the project owner. The generation provider/model and associated commercial-use terms were not independently verified. The asset therefore remains UNVERIFIED in the asset rights register. Technical processing and successful Android tests do not constitute commercial-rights clearance.

# Divslayer animation pipeline and audit

## Audit scope

This review is based on the current `main` branch source, `data/art_manifest.json`,
`scripts/sheets.gd`, `scripts/player.gd`, `scripts/enemy.gd`, and
`tools/sprite_sheet.py`. It is a code/metadata audit; it is not a visual sign-off
on every frame and does not replace an Android device test.

## Current animation inventory

- The manifest contains **12 hero appearance sheets**: Warrior, Mage, Rogue, and
  Paladin, each with starter, mid, and endgame equipment looks.
- The 12 legacy hero appearance sheets still use a **5-column × 3-direction**
  atlas with **160 × 156 px** cells (800 × 468 px total): four walk poses and
  one legacy attack pose per direction.
- This feature branch adds a separate four-frame attack sequence for Warrior
  Starter only: 12 individual transparent 160 × 156 PNGs, grouped as down, up
  and side. The legacy walk sheet remains unchanged; the other 11 appearances
  keep their existing one-pose attacks.
- The runtime uses the first walk pose as the one-frame idle animation. Breathing,
  squash, foot dust, dodge spin, and hit tint are added procedurally by the
  player controller.
- The enemy manifest contains **41 sprite-backed entries** plus Wisp, which is
  intentionally drawn procedurally and has no sprite-sheet dimensions. Of the
  41 sprite-backed entries, 32 declare four frames, five declare two frames,
  and four declare one frame. One- and two-frame designs need per-creature review;
  a low frame count is not automatically a defect for static props or wing cycles.
- Enemies use one looping animation per variant row. Their hit reaction is mainly
  implemented through flash, squash, knockback, and rotation. Bosses inherit this
  enemy sprite framework; their move identity is currently communicated largely
  through attack telegraphs and effects rather than separate attack sprite clips.

## Confirmed limitations

1. **Hero attack coverage is still mostly one pose per direction.** This
   feature branch supplies four distinct poses for Warrior Starter in three
   directions (3 of 36 attack clips); the remaining 33 clips still have one
   authored pose.
2. **No dedicated hero hurt, stagger, block, dodge, or death atlas clips are
   declared.** Several of these states are represented by controller-driven
   transforms and effects instead of new character poses.
3. **The still-to-sheet generator is synthetic motion.** `tools/sprite_sheet.py`
   creates walk cycles by moving, rotating, and squashing a source drawing. It
   can prepare a sheet quickly, but it cannot invent genuine changes in limb,
   weapon, or cloth pose. A separate strike drawing improves the attack pose,
   but still does not supply a full attack sequence.
4. **Clip timing must match gameplay timing.** The normal player attack window is
   0.16 s and the heavy window is 0.26 s. Four attack frames at 24 FPS take about
   0.167 s, so the normal attack's final frame may be cut slightly short unless
   the gameplay animation window is adjusted. The preview builder now supports
   independent per-clip FPS values, but this does not change runtime combat timing.
5. **Impact frames are data-driven and backward compatible.** Hero sheet metadata
   may define a zero-based `attackImpactFrame` (and optional
   `heavyImpactFrame`). The player schedules target checks, object strikes,
   hit-stop and damage for the beginning of that frame. Missing metadata defaults
   to frame 0, so the current one-frame attacks still hit immediately. A delayed
   impact is canceled if the player dodges, raises a block, dies, or changes maps.
   GIF stores frame delays in 10 ms increments, so its reported effective FPS can
   differ slightly from the requested value (for example, 24 FPS is previewed at
   25 FPS using a 40 ms frame delay).

## Changes in this update

- The character-sheet loader reads named atlas columns from the existing
  `cols` metadata and supports both embedded multi-frame attack columns and an
  optional separate attack atlas.
- The player computes attack duration from the selected clip and schedules combat
  impact from the optional zero-based `attackImpactFrame` / `heavyImpactFrame`
  metadata. The active direction is locked through the strike, and the attack clip
  is explicitly restarted from frame zero even when the same direction is played
  twice.
- The Godot animation regression test checks all 12 current hero looks, all
  sprite-backed enemy atlases/variants, and both future multi-frame attack
  formats using synthetic in-memory sheets.
- The animation review tool exports separate directional **walk** and **attack**
  GIFs, each with its own FPS. The current Warrior review config uses 9 FPS for
  walk and 24 FPS for attack to match the Godot animation defaults. Configurations
  without per-clip FPS continue to inherit the global FPS. The current attack
  preview remains a one-frame, non-looping pose.
- CI runs the builder tests and uploads the review sheets, previews, and report
  as a temporary artifact.

## Production candidate verification — 20 November 2026

This feature branch introduces the first separately-authored multi-frame hero
attack for Warrior Starter. It does not replace or modify the legacy walk
texture:

- Twelve individual transparent PNG frame files: four frames for each of
  down, up and side.
- Every file is exactly 160 × 156 px and is loaded as a standalone Texture2D.
- Playback is 24 FPS, one-shot; the contact frame is zero-based index 2.
- The source atlas supplied by the owner was split into individual frames and
  aligned to a shared baseline. The assets are a first candidate and still
  require Godot CI, visual review at phone scale and physical-device acceptance.
- Provenance is recorded as owner-supplied/ChatGPT Images 2.6 per owner report;
  commercial-use rights remain `UNVERIFIED`.

The other eleven hero appearances retain their one-frame attacks. No final
approval or release rights are inferred from successful import or test results.

## Impact-frame authoring contract

For a reviewed multi-frame attack, add `attackImpactFrame` to that hero's entry
in `data/art_manifest.json`. The index is zero-based and identifies the first
frame in which the weapon should connect (for example, `2` means the third
frame). Set `heavyImpactFrame` separately only when the heavy attack has a
different contact frame. The index is clamped to the available clip range at
runtime; missing metadata intentionally means immediate contact for legacy
one-frame sheets. Do not set a non-zero impact frame until the matching
anticipation/contact/recovery poses have been reviewed and the attack's total
duration, target reach, and damage timing have been tested together.

## Scope boundary

**This feature branch includes one production animation candidate:**
the four-frame Warrior Starter attack in three directions, loaded as separate
PNG textures by the normal character runtime. It has not been merged into
`main` or visually signed off on a physical Android device. Dedicated
idle, hurt, block, dodge and death clips remain outstanding.

The preview artifact is a technical review aid, not a replacement APK or a
human visual approval. No commercial-use rights are inferred from a successful
build or image-generation workflow. Any new art must be provenance-reviewed,
registered in `docs/ASSET_RIGHTS_REGISTER.csv`, imported in Godot, and tested
at the real Android display scale before being promoted.

## Next production stages

1. Create and visually review a genuine multi-frame Warrior attack sequence
   for all three directions, then test the timing against the 0.16 s normal
   attack window.
2. Extend the same production contract to heavy attack, hit/stagger, block,
   dodge, and death poses.
3. Produce class-specific sequences for Mage, Rogue, and Paladin rather than
   recolouring or reusing Warrior motion.
4. Add enemy/boss-specific attack and recovery clips where they improve combat
   readability; keep telegraph timing and collision logic independent from
   decorative animation.
5. Review the final atlas at native mobile scale and on the target Android
   device before changing production assets.

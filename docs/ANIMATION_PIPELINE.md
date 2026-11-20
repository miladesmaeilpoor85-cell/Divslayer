# Divslayer animation pipeline and audit

## Audit scope

This review is based on the current `main` branch source, `data/art_manifest.json`,
`scripts/sheets.gd`, `scripts/player.gd`, `scripts/enemy.gd`, and
`tools/sprite_sheet.py`. It is a code/metadata audit; it is not a visual sign-off
on every frame and does not replace an Android device test.

## Current animation inventory

- The manifest contains **12 hero appearance sheets**: Warrior, Mage, Rogue, and
  Paladin, each with starter, mid, and endgame equipment looks.
- Every current hero sheet uses a **5-column × 3-direction** atlas with
  **160 × 156 px** cells (800 × 468 px total): four walk poses and one attack
  pose per direction.
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

1. **Hero attack coverage is one pose per direction.** There is no multi-frame
   attack sequence in any of the 12 current hero appearance sheets.
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

## Production manifest verification — 2026-11-20

The current `main` branch manifest still registers each of the 12 hero looks
with the same four walk columns and one attack column. None of the current hero
entries registers `attackSheet`, `attackFrames`, `attackImpactFrame`, or
`heavyImpactFrame`.

The loader's ability to parse a separate attack atlas or embedded attack columns
is therefore **future-facing infrastructure**, not an active multi-frame
production animation. The file
`creative/animation/warrior_starter_attack.json` is a review configuration
pointing to the existing `assets/art/Heroes/warrior_starter.png`; it is not the
missing `assets/art/Heroes/warrior_starter_attack.png` image.

The isolated review scene also reads the existing five-column sheet. It shows
the single attack pose with a Godot-drawn slash arc; that arc is a preview effect,
not additional character animation frames. The production combat hit remains
immediate while the hero's current attack metadata defaults to impact frame 0.

## Quantitative frame-quality audit — 2026-11-20

The CI artwork job now runs `tools/animation_quality_audit.py` after generating
the visual previews. It writes
`artifacts/animation-review/animation-quality-report.json` and does not edit
source art, manifests, runtime scripts, pivots, or import settings.

For each registered hero walk/attack clip and enemy variant, the report records:

- frame count and count of unique frames;
- exact duplicate frame pairs, comparing frames composited over a neutral
  background so hidden RGB values under fully transparent pixels do not cause
  false differences;
- adjacent changed-pixel ratios using a conservative per-pixel threshold;
- visible-alpha ratio and bottom-of-silhouette range across frames;
- review flags for single-pose attacks, two-frame loops, duplicate frames,
  and very low pixel motion.

The current inventory has 12 hero appearance sheets, each with three walk
directions and one attack pose per direction. Unless a separate attack atlas is
registered, this means 36 hero attack clips with one authored pose each. The
enemy manifest contains 41 sprite-backed entries; the existing inventory is
32 four-frame, five two-frame, and four one-frame sheets, while Wisp is
procedural. The report re-measures these facts from the actual sheets rather
than assuming the manifest is correct.

Interpretation limits: pixel-difference scores are triage signals, not an
artistic quality score. Low movement may be correct for a hovering creature,
and two frames can be enough for a simple wing beat. Likewise, a high changed
pixel ratio can indicate jitter or inconsistent registration rather than good
animation. The bottom-of-silhouette range is informational only: a walking
character naturally lifts one foot, so this value must not be treated as pivot
or foot-placement error. Check the GIF/PNG previews and gameplay silhouette
before an asset is labelled defective.

The audit recognises a separate hero attack atlas when `attackSheet` and
`attackFrames` are present in the manifest. Its expected layout is one
horizontal frame strip with one row per `rows` direction, matching the
existing loader contract. The report is quality-assurance evidence only; it
does not create new animation or change combat timing.

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

**No new production animation art is added by this update.** The current
`warrior_starter.png` remains the source of the preview and stays unchanged.
The one-frame attack is still one frame in the playable game. The new loader is
infrastructure for adding reviewed multi-frame art later; it does not create
new poses from nothing and does not make the current game animation richer by
itself.

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

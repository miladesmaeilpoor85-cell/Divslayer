# Character animation production plan

**Scope:** actual, distinct production poses for Warrior, Mage, Rogue, and Paladin. This is an authoring and integration contract; it does not claim that new sprite art has already been drawn.

## Verified current state

The current manifest contains 12 hero appearance sheets: four classes, each with starter, mid-tier, and endgame looks. Each base sheet is 800 × 468 pixels, arranged as 5 columns × 3 facing rows, with 160 × 156 pixel cells. The four first columns are walk poses; the fifth column is the legacy attack pose. The runtime uses the first walk pose for idle and adds restrained procedural motion.

Two Starter appearances now have separate four-frame, three-direction light-attack sequences: Warrior Starter uses 12 transparent PNGs registered through `attackFrameFiles`, and Rogue Starter uses a four-frame attack atlas assembled from base64 parts. Both play at 24 FPS and use contact frame index 2. The other 30 of the 36 registered directional attack clips remain single-pose. Mage Starter/Mid/Endgame, Rogue Mid/Endgame, Paladin Starter/Mid/Endgame, and Warrior Mid/Endgame still need authored multi-frame attack art.

The runtime can delay gameplay contact until a configured frame while preserving immediate-hit behaviour for legacy one-frame clips. The isolated Warrior review scene is a read-only art preview; it does not replace the live gameplay sprites.

## Non-negotiable production rule

A real frame must show a new pose: changed limb positions, weapon/shield/staff orientation, torso balance, cloth motion, and/or contact posture. Translating, rotating, recolouring, scaling, or squashing one still image does not count as a new authored frame.

Keep the existing character identity, silhouette, equipment, palette, pixel dimensions, transparency, foot pivot, and facing-row convention unless an explicit reviewed change is approved.

## First production batch

Start with the starter look of all four classes. This validates the full art-to-runtime path before duplicating the work across mid-tier and endgame gear.

For each class, author front/down, back/up, and side-facing views. The side view may be mirrored by the runtime only after the weapon hand, shield side, and asymmetrical costume details have been checked.

| Clip | Suggested distinct poses | Required visual beats |
|---|---:|---|
| Idle | 3–4 | weight shift, breathing, cloth/weapon settling |
| Light attack | 4–6 | anticipation, strike/contact, follow-through, recovery |
| Heavy attack | 6–8 | stronger wind-up, committed contact, recoil/recovery |
| Hit/stagger | 2–3 | impact compression, balance recovery |
| Block | 2–3 | guard raised, sustained guard/recoil |
| Dodge | 4–6 | crouch/launch, travel, landing/recovery |
| Death | 5–8 | loss of balance, fall, settled final pose |

These are art targets, not a claim about current runtime timing. Set each clip's FPS and frame count only after review. Configure `attackImpactFrame` / `heavyImpactFrame` to the actual contact frame and test the hit window against the clip duration.

## Class-specific motion identity

- **Warrior:** grounded weight, readable sword arc, clear shoulder/hip rotation, visible wind-up and recovery. Heavy attacks should feel committed rather than merely faster.
- **Mage:** staff/orb focus, casting gesture, hand and robe motion, readable spell-release pose. A projectile animation must not be mistaken for melee contact.
- **Rogue:** compact stance, low centre of gravity, fast dagger/dual-blade motion, quick recovery, clear stealth and dodge silhouettes.
- **Paladin:** shield-first guard, planted stance, hammer/sword strike, defensive recoil, and a distinct holy/counterattack pose.

Do not reuse Warrior poses with palette swaps. Each class needs its own authored movement and weapon handling.

## Asset and manifest contract

- Preserve the existing 160 × 156 cell size unless a reviewed scale change is made.
- Prefer a separate attack atlas for the first genuine attack sequence so the legacy 5-column walk sheet remains backward compatible.
- Register every real asset in `data/art_manifest.json` with frame count, row/direction mapping, pivot, and clip metadata.
- Add the source, provider/tool, creation date, terms, commercial-use status, and private proof reference to `docs/ASSET_RIGHTS_REGISTER.csv` before production inclusion.
- Never set a non-zero impact frame before the contact pose and animation timing are approved.
- Keep the review scene read-only. Production assets must be loaded by the normal game path, not only by a developer preview.

## Verification gates

1. Inspect every frame at native size and at the phone's actual rendered scale; verify silhouette, feet alignment, transparent edges, and no clipping.
2. Confirm each direction has the right hand/weapon orientation and consistent frame spacing.
3. Test light/heavy attacks, combo transitions, contact timing, hit-stop, cancellation by dodge/block/death/map change, and target reach.
4. Test all four classes and all three gear tiers before marking the batch complete.
5. Run the animation builder tests, manifest checks, full Godot test suite, Android export, and physical-device gameplay review.

## Current status — Warrior Starter sprite pilot

The original Warrior Starter pilot is now integrated into `main`. It preserves the original PNG as a safe fallback while loading the generated runtime atlas when the source assets are available.

- Source atlas: `assets/art/Heroes/warrior_starter_source.webp` (160 × 93 px, transparent).
- The source atlas stores 15 cells in five columns by three directional rows. Each cell is 32 × 31 pixels and is expanded independently to 160 × 156 with nearest-neighbour sampling at runtime.
- Runtime atlas: 800 × 468 px, preserving the existing `data/art_manifest.json` contract (`down`, `up`, `side`; `walk0`–`walk3`, `attack`; bottom-centre feet pivot).
- `scripts/generated/warrior_starter_art.gd` builds and caches the runtime `ImageTexture`; `scripts/sheets.gd` uses it only for `heroes/warrior_starter` and retains the old PNG fallback.
- `assets/art/Heroes/warrior_starter_mask.png` is a compact 160×93 one-bit greyscale cloth mask aligned to the source atlas; its shader luminance key is recorded as 0.237 in `data/hero_masks.json`.

This remains a Starter-tier pilot. It does not add separate heavy attack, hurt/stagger, block, dodge, or death clips. A four-frame light-attack sequence per direction was integrated separately below; Mid/Endgame Warrior and the Mage, Rogue, and Paladin gameplay atlases still need their own class- and gear-specific animation batches. Physical-device review and source/provider rights verification remain required.

## Warrior Starter multi-frame attack — integration candidate

- [x] Integrate four distinct attack frames per direction (down/up/side) for the Starter Warrior while retaining the existing 5×3 walk atlas and bottom-centre pivot.
- [x] Register the 12 individual transparent 160×156 attack frames in `data/art_manifest.json` using `attackFrameFiles`; playback runs at 24 FPS and contact is frame index 2.
- [x] Resolve damage and impact effects on the configured contact frame; preserve immediate-hit behaviour for legacy one-frame hero attacks.
- [x] Keep Rogue sneak active during the attack wind-up and end it on the contact frame.
- [ ] Verify the updated code and all gameplay regression tests on the current `main` base; the previously passing CI belongs to the earlier feature-branch commit and is not proof for this integration.
- [ ] Review the attack poses at native Android scale and confirm hit timing/left-right mirroring on a physical device.
- [ ] Verify the source image provider terms; asset rights remain `UNVERIFIED` pending owner-side evidence and review.

This is an animation improvement for Warrior Starter only; Mid/Endgame Warrior and the Mage, Rogue and Paladin attack atlases are still unchanged.

## Combat VFX integration — 20 November 2026

- [x] Distinguish the existing melee arc and successful-hit response for Warrior, Mage, Rogue and Paladin with lightweight class-specific procedural effects.
- [x] Keep the effect bound to the existing confirmed hit location and contact frame; no damage or hitbox changes.
- [x] Add regression assertions for class tags, distinct palettes and a contact response for all four classes.
- [ ] Produce and integrate unique attack-frame art for Mage, Rogue and Paladin; image-generation uploads are currently blocked by the connected Fal account's empty credit balance.
- [ ] Review the visual result at native Android scale and on a physical device after a new APK is built.

The procedural effects in this step are a presentation improvement, not a substitute for the missing class-specific sprite poses.


## Frame-level animation audit — 20 November 2026

- [x] Add a read-only image audit for duplicate frames, adjacent pixel-motion ratios, visible alpha, and bottom-edge drift.
- [x] Measure both embedded/atlas attack clips and separately registered `attackFrameFiles` (including the Warrior Starter production sequence).
- [x] Report frame counts, FPS, contact-frame index and contact time when the manifest provides them.
- [x] Run unit tests and publish a JSON quality report from the artwork CI job.
- [ ] Review the generated report and native-scale contact sheets; pixel-difference metrics identify review candidates but do not grade acting or artistic quality.

**Manifest-based baseline:** 12 hero looks create 36 directional attack clips. Warrior Starter and Rogue Starter each have three four-frame directional attack clips (six multi-frame clips total); the other 30 clips still use one pose each. This count describes registered frame data, not an artistic quality score.


## Ultimate VFX pass — 20 November 2026

- [x] Warrior Whirlwind begins with a grounded bronze impact cue that feeds into the existing steel vortex.
- [x] Mage Arcane Tempest gains a restrained lapis/amber ritual cue before its existing meteor telegraphs.
- [x] Rogue Shadow Dance leaves a directional emerald afterimage and receives the paired-dagger contact response on each strike.
- [x] Paladin Farr Smite gains an additional solar pulse and upward sparks around the existing pillar and healing burst.
- [x] Regression tests verify the class-specific visual cues while preserving the existing damage, hit-count, invulnerability and meteor assertions.
- [ ] Review all four ultimates at native Android display scale and compare low/high FX settings on a physical device.

These additions are presentation-only; ultimate duration, target rules, damage, stun, healing, invulnerability and meter consumption are unchanged.


## 2026-11-21 — User-supplied Shahnameh character art integration

The project owner supplied eight original artwork images for the four class identities and four story-character portraits. The images were cropped and downsampled into two native 384×384 WebP atlas resources.

- The class-selection screen now cycles six supplied action poses for Warrior, Mage, Rogue and Paladin cards at a restrained 0.18-second frame interval. Existing static card art remains the safe fallback if an atlas cannot be loaded.
- Dialogue portraits now use the supplied Rostam, Siavash, Gordafarid and Rudabeh turnarounds for their corresponding story actor keys. Existing painted portraits remain the fallback for every other actor.
- The six-pose concept panels are not directional top-down gameplay sprite sheets. They do not provide independent north/south/east/west frames, consistent gameplay pivots or per-frame hitbox alignment. They are therefore not substituted for the live combat SpriteFrames; combat animations, contact timing and hitboxes remain unchanged.
- Regression coverage checks both imported atlas resources, all four six-frame class clips, their cell dimensions and the four dialogue portrait registrations.
- Rights register entries identify the owner-supplied source files and the atlas conversion. Commercial-use status remains UNVERIFIED until the source/provider terms are separately confirmed.

The next combat-art milestone is to derive direction-consistent, transparent-background animation sheets with stable feet pivots and frame-level contact annotations from the approved character designs, then validate them at native Android scale before replacing any in-combat sheet.


## Class-specific attack anticipation — 21 November 2026

- [x] Add a short pre-contact cue when the hero begins an attack, using the same locked facing direction as the attack animation.
- [x] Give Mage an arcane focus orbit, Rogue paired dagger streaks, and Paladin a compact solar guard arc.
- [x] Give heavy attacks a longer anticipation window than light attacks.
- [x] Cancel the cue when the attack is interrupted by dodge, guard, map transition, or another pending-attack cancellation.
- [x] Keep the cue strictly cosmetic: the existing damage calculation, reach, hitbox, contact-frame scheduling, and hit-stop are unchanged.
- [ ] Produce and integrate real directional attack sprite frames for Mage, Rogue Mid/Endgame, Paladin, and the remaining Warrior gear tiers. Procedural anticipation and contact effects are not substitutes for authored poses.
- [ ] Review the result at native Android scale and on a physical device after the new APK passes emulator QA.

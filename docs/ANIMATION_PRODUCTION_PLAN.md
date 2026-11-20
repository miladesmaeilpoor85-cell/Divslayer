# Character animation production plan

**Scope:** actual, distinct production poses for Warrior, Mage, Rogue, and Paladin. This is an authoring and integration contract; it does not claim that new sprite art has already been drawn.

## Verified current state

The current manifest contains 12 hero appearance sheets: four classes, each with starter, mid-tier, and endgame looks. Each existing sheet is 800 × 468 pixels, arranged as 5 columns × 3 facing rows, with 160 × 156 pixel cells. The four first columns are walk poses; the fifth column is one attack pose. The runtime uses the first walk pose for idle and adds some visual motion procedurally.

The code can load future multi-frame attack data and can delay combat impact to a configured frame. The current production manifest does not activate a new attack atlas or non-zero impact frames. The isolated Warrior review scene is a read-only preview of the existing one-frame attack pose with a drawn slash effect.

## Measured baseline — 2026-11-20

The new CI pixel audit processed 126 clips with no missing-sheet or dimension
errors: 36 hero walk clips, 36 hero attack clips, and 54 enemy variant clips.
Wisp is excluded because it is drawn procedurally rather than from a sprite
sheet.

Measured review candidates:

- All 36 current hero attack clips contain one authored pose.
- All 12 side-facing hero walk clips have an exact duplicate between frame
  indices 1 and 3. Confirm whether this symmetry is intentional before changing
  the cycle; do not replace frames automatically.
- Wraith and Rimewraith each have one duplicated pair (indices 1 and 3).
- Eight enemy variants use two-frame cycles: Bat, Bellow Drone, three Ignarok
  variants, two Matriarch variants, and Mosquito.
- Four enemy sheets have one frame: Bog Egg, Grave Pillar, Ic eling, and
  Molten Core. Review whether each is meant to be animated or is intentionally
  static before adding frames.

These are measured inventory findings, not automatic art defects. Pixel
variation cannot judge acting, silhouette appeal, timing, or artistic quality.
The bottom-of-silhouette range is retained as information only because normal
walking lifts a foot.

## Data-driven production order

1. Author genuine 4–6-pose light-attack clips for the four starter looks
   (Warrior, Mage, Rogue, Paladin), across down/up/side. Start with the Warrior
   starter as the integration pilot, then validate the same loader contract for
   the other classes.
2. Review the repeated side-walk frames across all 12 looks. Correct them only
   where the repeated pose is visibly harming cadence; some repetition can be
   deliberate.
3. Review enemy two-frame cycles and the Wraith/Rimewraith duplicates against
   their preview loops and in-game behaviour. Keep simple wing beats and
   hovering cycles short when that is the intended motion.
4. After attacks are integrated and verified, add class-specific hit, block,
   dodge, heavy-attack, and death clips; then extend action clips to important
   enemies and bosses.

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

## Current blocker

No new production animation PNG/atlas is part of this plan. Image generation is not being used for this update. Until distinct source frames are authored and reviewed, the playable game still has one attack pose per direction for each current hero sheet.

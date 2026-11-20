# Character animation production plan

**Scope:** actual, distinct production poses for Warrior, Mage, Rogue, and Paladin. The first candidate asset—Warrior Starter attack—is now supplied on a feature branch; review and the remaining production clips are still tracked here.

## Verified current state

The current manifest contains 12 hero appearance sheets: four classes, each with starter, mid-tier, and endgame looks. Each existing sheet is 800 × 468 pixels, arranged as 5 columns × 3 facing rows, with 160 × 156 pixel cells. The four first columns are walk poses; the fifth column is one attack pose. The runtime uses the first walk pose for idle and adds some visual motion procedurally.

The runtime now supports separate frame files and data-driven impact timing. This branch activates four attack frames per direction for Warrior Starter only, at 24 FPS with contact on zero-based frame 2. The legacy walk sheet is unchanged; the other 11 hero appearances still use one attack pose per direction.

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

## Current status and remaining work

- [x] Receive a 4 × 3 Warrior Starter attack source sheet with front, back and side poses.
- [x] Extract twelve transparent 160 × 156 RGBA PNG frames with a common foot baseline.
- [x] Register the four-frame attack for each direction without replacing the walk atlas.
- [ ] Pass the updated Godot animation regression test and full CI on the feature branch.
- [ ] Review every frame at native phone scale and verify attack timing, hit registration and left/right mirroring on Android.
- [ ] Verify asset provenance and commercial-use evidence; the rights register remains UNVERIFIED.
- [ ] Produce unique attacks for Warrior Mid/Endgame and the other three classes.
- [ ] Produce distinct idle, hit/stagger, block/parry, dodge, ultimate and death clips.

This is a first production candidate, not a complete character animation package or release approval.

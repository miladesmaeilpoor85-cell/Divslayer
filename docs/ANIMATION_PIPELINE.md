# Divslayer animation pipeline and audit

**Verified against `main` on 21 November 2026.** This is a code/manifest audit, not a visual sign-off for every frame and not a substitute for Android device testing.

## Hero animation inventory

- The production manifest contains **12 hero appearances**: Warrior, Mage, Rogue, and Paladin, each with Starter, Mid, and Endgame equipment.
- Each legacy base sheet is **800 × 468 px**, arranged as five columns by three directions, with **160 × 156 px** cells. Its first four columns are walk poses; its fifth column is the legacy single-pose attack.
- **Two Starter appearances now have real multi-frame light attacks**:
  - **Warrior Starter:** four authored frames in each of the `down`, `up`, and `side` directions, registered as 12 transparent PNGs through `attackFrameFiles`.
  - **Rogue Starter:** a separate 4-column × 3-row attack atlas, loaded from ordered Base64 resource parts through `attackSheetBase64Parts`.
- Both use **24 FPS** and zero-based **contact frame 2**. That is six multi-frame directional clips out of the 36 registered hero attack clips. The other **30 clips remain one-pose attacks**.
- Mage Starter, all Paladin looks, Rogue Mid/Endgame, and Warrior Mid/Endgame still use the legacy one-pose attack.

## Runtime behaviour

The attack loader preserves the existing 5 × 3 walk sheet and accepts separately registered attack data. The canonical attack atlas layout is four columns by three rows:

| Direction row | Frame 0 | Frame 1 | Frame 2 | Frame 3 |
|---|---|---|---|---|
| 1 | Down — anticipation | Down — windup | Down — contact | Down — recovery |
| 2 | Up — anticipation | Up — windup | Up — contact | Up — recovery |
| 3 | Side — anticipation | Side — windup | Side — contact | Side — recovery |

For the two active clips, the player locks the attack direction, plays the separate four-frame sequence, and resolves the hit at the configured contact frame. Missing attack metadata preserves immediate contact for legacy one-pose attacks. Delayed attacks are canceled when interrupted by dodge, guard, death, or map transition.

Main also includes class-specific procedural contact effects and short attack-anticipation cues. These cues differ by class and are canceled when the attack is interrupted. They are **presentation effects**, not additional authored sprite frames and not a substitute for the missing Mage/Paladin animation art. They do not change reach, damage, hitboxes, cooldowns, or contact-frame scheduling.

## Confirmed limitations

1. **Only Warrior Starter and Rogue Starter have multi-frame gameplay attacks.** Thirty directional attack clips remain one-pose.
2. The hero manifest does not yet provide dedicated authored multi-frame heavy attack, hit/stagger, block, dodge, or death clips across all four classes. Several reactions are currently represented through controller-driven transforms and effects.
3. The six-pose character illustrations used in the class cards and hero folio are menu/concept art. They are not directional top-down combat sprite sheets and are not registered as live combat SpriteFrames.
4. The still-to-sheet helper in `tools/sprite_sheet.py` can arrange and transform source artwork, but moving, rotating, scaling, or squashing one still image does not create genuine new limb, weapon, or cloth poses.
5. Four frames at 24 FPS occupy about 0.167 seconds. Final per-clip timing must be reviewed against the gameplay attack window, contact index, combo transitions, hit-stop, and interruption rules.

## Audit and import tools

- `tools/animation_quality_audit.py` reads the production manifest and registered artwork. It reports frame counts, duplicate frames, adjacent pixel changes, visible alpha, footline drift, FPS, and contact-frame timing where available.
- `tools/import_animation_atlas.py` validates an externally authored 4 × 3 atlas, extracts 12 transparent 160 × 156 PNG frames, aligns feet, writes a packed review atlas, and produces a JSON report. It does not generate character poses and does not edit the runtime manifest.
- `tools/animation_review.py` exports separate directional previews and uses the production frame metadata when available.
- The animation regression suite validates loader behaviour and attack metadata. A passing automated audit does not grade acting, weapon readability, visual appeal, or commercial rights.

The accepted import layout is documented in [ANIMATION_ATLAS_IMPORT.md](ANIMATION_ATLAS_IMPORT.md). The current registered counts are also summarized in [ANIMATION_QUALITY_AUDIT.md](ANIMATION_QUALITY_AUDIT.md).

## Next production stages

1. Produce and approve genuine four-direction-compatible Starter attack art for **Mage and Paladin**, following the existing down/up/side contract. Rogue Starter and Warrior Starter are already integrated.
2. Extend class-specific light attacks to the remaining equipment tiers without recolouring or reusing another class's poses.
3. Add separate heavy attack, hit/stagger, block, dodge, and death animation sets, with frame-level timing and interruption review.
4. Inspect all accepted frames at native sprite size and actual Android display scale; check weapon/shield orientation, feet baseline, clipping, alpha edges, and hit timing.
5. Complete provenance and license evidence before registering new art. Current Warrior/Rogue attack-art commercial-use evidence remains unverified in the rights records.
6. Run importer tests, the animation audit, all Godot CI shards, Android QA export/emulator checks, and physical-device gameplay review before promoting a new batch.

## Related production references

- [Character animation production plan](ANIMATION_PRODUCTION_PLAN.md)
- [Frame-level animation quality audit](ANIMATION_QUALITY_AUDIT.md)
- [Starter attack-atlas import contract](ANIMATION_ATLAS_IMPORT.md)
- [Class visual design](CLASS_VISUAL_DESIGN.md)
- [Artwork rights register](ASSET_RIGHTS_REGISTER.csv)

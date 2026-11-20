# Warrior multi-frame attack art brief

**Purpose:** an authoring contract for genuine Warrior attack drawings. This document is not an animation asset and does not change the production manifest.

## Existing production baseline

- Source walk sheet: `assets/art/Heroes/warrior_starter.png`.
- Existing sheet: 800 × 468 px, with 160 × 156 px cells; rows are `down`, `up`, `side`.
- Four walk frames and one legacy attack pose are in each row.
- The existing foot pivot is defined in `data/art_manifest.json`; preserve it exactly.
- Left-facing movement reuses the side row with horizontal flip.
- Current rights status for the source sheet remains `UNVERIFIED`; a new source and its commercial terms must be recorded separately.

## Deliverable for the first production pass

Create a genuinely drawn, transparent attack atlas at:

`assets/art/Heroes/warrior_starter_attack.png`

| Property | Required value |
|---|---:|
| Total image size | 640 × 468 px |
| Cell size | 160 × 156 px |
| Layout | 4 columns × 3 rows |
| Row order | down, up, side |
| Frame rate | 24 FPS |
| Playback | one-shot, not looping |
| Direction | side faces right; runtime flips it for left |

Each of the twelve cells must be a separately authored pose. Do not create additional frames by shifting, rotating, recolouring, mirroring, stretching, or squashing the existing single attack pose. Keep the same character silhouette, equipment tier, weapon identity, colour palette, lighting direction, and pixel density as the starter sheet.

## Pose sequence

| Index | Pose role | Required visual information |
|---:|---|---|
| 0 | Anticipation | Weight shifts back; sword is clearly drawn away from the target; shoulders and elbows show stored motion; feet remain planted on the same pivot line. |
| 1 | Acceleration | Torso and weapon begin a readable arc toward the facing direction; the sword remains attached to the hand and does not cross the character silhouette ambiguously. |
| 2 | Contact | The blade reaches the forward strike position; the weapon edge and hand position make the hit direction unmistakable. This is the first frame allowed to deal damage. |
| 3 | Recovery | The sword completes the follow-through; the torso settles toward a recoverable guard stance without snapping back to the idle pose. |

### Direction-specific constraints

- `down`: the face/front view; keep the sword readable in front of the torso and avoid hiding both arms behind the weapon.
- `up`: the back view; the sword must still read as a forward strike away from the camera, not as an unrelated shoulder pose.
- `side`: right-facing profile; establish a clean silhouette for the sword arc and leave enough transparent margin for the weapon tip.
- All rows must share the same feet baseline and pivot. Do not let the character drift between cells.
- Preserve the current 160 × 156 cell boundary. No weapon, particles, or cloak fragments may spill into adjacent cells.
- Do not bake the review-scene slash arc or damage effects into the atlas; those remain runtime effects.

## Runtime registration after art review

Only after the PNG is created, visually reviewed at native mobile scale, and its source/licence are recorded, add these fields to `heroes.warrior_starter` in `data/art_manifest.json`:

```json
{
  "attackSheet": "warrior_starter_attack.png",
  "attackFrames": 4,
  "attackFps": 24.0,
  "attackImpactFrame": 2
}
```

`attackImpactFrame` is zero-based. Index `2` means frame 3 (the contact pose) and schedules the gameplay hit at 2/24 s ≈ 0.083 s after the attack starts. A four-frame clip at 24 FPS lasts 4/24 s ≈ 0.167 s, which is close to the current 0.16 s normal-attack window. Do not add the metadata before the matching art exists; otherwise the game would delay damage while showing only the old one-frame pose.

The current runtime can read one attack clip and separate normal/heavy impact-frame metadata. A dedicated heavy-attack pose sequence is a later pass; do not pretend the normal sequence is a complete heavy-attack animation.

## Review and acceptance checklist

- [ ] All 12 frames are original, distinct drawings with transparent backgrounds.
- [ ] Character, weapon, and armour match the existing Warrior Starter look.
- [ ] Foot pivot and cell bounds match the existing sheet at 160 × 156 px.
- [ ] Anticipation, acceleration, contact, and recovery are visually distinguishable in all three directions.
- [ ] The contact pose aligns with the runtime hitbox direction and reach.
- [ ] No frame is created by a transform-only derivative of the old attack pose.
- [ ] Atlas preview is checked at 1× mobile scale and 3× nearest-neighbour review scale.
- [ ] Source, author, licence, and commercial-use permission are recorded in `docs/ASSET_RIGHTS_REGISTER.csv`.
- [ ] Godot tests verify 4 attack frames and frame-2 impact timing.
- [ ] Normal attack, combo, Block/Dodge cancellation, death, map change, and all four classes are regression-tested.
- [ ] Android QA verifies the animation remains readable at target display scale.

## Current status

The required atlas has **not** been created. The existing production sheet remains unchanged and the production attack still uses one pose per direction. This brief prepares the asset work but does not claim completion of the art or animation.
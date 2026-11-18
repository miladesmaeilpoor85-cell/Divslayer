# Divslayer animation pipeline

## Current source-sheet review

The tracked hero sheets use a 5-column × 3-direction layout: four walk poses
and one attack pose per direction. The loader continues to support this
legacy format for all unmodified characters.

## Warrior starter multi-frame attack

The starter warrior now uses a separate attack atlas:
\`assets/art/Heroes/warrior_starter_attack.png\`.

- The original \`warrior_starter.png\` remains the source for the four walk
  frames and the idle pose in each direction.
- The new attack atlas contains 4 columns × 3 direction rows (12 frames).
- Rows are ordered \`down\`, \`up\`, \`side\`; columns are ordered from guard,
  wind-up, slash, to follow-through.
- The asset is packed into the existing 160 × 156 cell dimensions with a
  shared bottom baseline and transparent cell margins.
- Attack playback runs at 24 FPS and is one-shot. The movement/walk cycle and
  combat hit timing remain unchanged.

The loader accepts both the separate-attack-atlas format and an extended
single-sheet format with sequential \`attackN\` columns. This makes later
character upgrades possible without breaking existing art sheets.

## Reproducible review pipeline

- Source walk sheet: \`assets/art/Heroes/warrior_starter.png\`
- Attack atlas: \`assets/art/Heroes/warrior_starter_attack.png\`
- Direction/cell metadata: \`creative/animation/warrior_starter_attack.json\`
- Builder/validator: \`tools/animation_pipeline.py\`
- Unit tests: \`tools/test_animation_pipeline.py\`
- Godot regression test: \`tests/animationtest.gd\`

The review pipeline validates the current source sheet, checks every cell,
exports per-direction previews, and records source hashes and a JSON report.
The separate attack sheet is also checked for alpha bounds and frame
dimensions before it is used by the runtime loader.

## Limitations and provenance

This adds a new warrior starter attack animation. It does not yet update
warrior mid/endgame looks, mage/rogue/villager animations, enemy attacks, or
boss phase animations. A matching set must be authored and reviewed for each
of those designs separately.

The attack frames are newly generated and then cleaned/packed for game use.
Commercial-use rights must still be checked against the applicable tool and
account terms; the game's artwork registry remains the authority for release
approval. Successful technical checks do not establish commercial-use rights.

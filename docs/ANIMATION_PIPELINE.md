# Divslayer animation pipeline

## Current source-sheet review

The tracked hero sheets use a 5-column × 3-direction layout: four walk poses
and one attack pose per direction. The runtime loader continues to support
this legacy format for every existing character.

## Multi-frame attack support

The character loader now reads the ordered \`cols\` array in
\`data/art_manifest.json\` and supports two extended formats:

1. Append sequential \`attack0\`, \`attack1\`, \`attack2\`, \`attack3\` columns to
   a single character atlas.
2. Keep the walk atlas unchanged and register an optional \`attackSheet\` plus
   \`attackFrames\` in that character's manifest metadata.

The loader preserves walk/idle frames, reads each directional attack row,
applies the configured \`attackFps\`, and plays attacks once rather than looping.
Regression tests cover both atlas formats with in-memory images.

## Current integration status

The new attack artwork was generated and cleaned as a candidate, but could not
be safely committed as a verified binary asset in this change. Therefore the
starter warrior remains on its existing single-frame attack in the game.
The optional separate-atlas loader path is implemented and tested, but no
production character points to a missing image. The candidate image is
delivered separately for review; it must be placed at
\`assets/art/Heroes/warrior_starter_attack.png\`, registered in
\`data/art_manifest.json\`, and tested in Godot before it is treated as an
in-game upgrade.

## Reproducible review pipeline

- Source walk sheet: \`assets/art/Heroes/warrior_starter.png\`
- Direction/cell metadata: \`creative/animation/warrior_starter_attack.json\`
- Builder/validator: \`tools/animation_pipeline.py\`
- Unit tests: \`tools/test_animation_pipeline.py\`
- Godot regression test: \`tests/animationtest.gd\`

The review pipeline validates the current source sheet, checks every cell,
exports per-direction previews, and records source hashes and a JSON report.

## Limitations and provenance

This change does not update warrior mid/endgame looks, mage/rogue/villager
animations, enemy attacks, or boss phase animations. Each design needs matching
frames and a separate visual review.

The candidate attack frames are newly generated and then cleaned/packed for
game use. Commercial-use rights must still be checked against the applicable
tool and account terms; the game's artwork registry remains the authority for
release approval. Successful technical checks do not establish commercial-use
rights.

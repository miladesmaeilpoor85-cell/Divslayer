# Divslayer animation pipeline

## Current source-sheet review

The production project currently stores the starter warrior as a 5-column ×
3-direction sheet: four walk poses and one attack pose per direction. The
runtime loader currently builds four-frame walk, one-frame idle, and one-frame
attack animations from this sheet.

## Multi-frame attack support

The character loader now reads the ordered \`cols\` array in
\`data/art_manifest.json\`. The current format remains compatible:

- \`walk0\` … \`walk3\`: four looping walk poses
- \`attack\`: the existing single-frame, non-looping attack

An extended sheet can append \`attack0\`, \`attack1\`, \`attack2\`, and
\`attack3\` (or another number of sequential \`attackN\` columns). The loader
collects every column whose name begins with \`attack\`, keeps their declared
order, and plays the resulting attack animation once. Optional \`walkFps\` and
\`attackFps\` metadata control playback speed. The regression test exercises an
in-memory 8-column atlas so the extended format is tested without replacing
any production artwork.

This is runtime support, not a claim that new attack art has already been
connected to the game. The tracked hero sheets still use one attack frame.

## Animation editing tools

- **Pixelorama 1.2.4** is installed and smoke-tested in the cloud creative-tools
  job. It supports cels, frame timeline, tags, and onion-skin review.
- **Krita** remains the painterly frame cleanup and layered-art workspace.
- **Blender** is available for 3D/Grease Pencil studies, not yet used for
  production character animation in this pass.
- **Godot** imports the exported sprites through \`SpriteFrames\`.

## Reproducible review pipeline

- Source sheet: \`assets/art/Heroes/warrior_starter.png\`
- Direction/cell metadata: \`creative/animation/warrior_starter_attack.json\`
- Builder/validator: \`tools/animation_pipeline.py\`
- Unit tests: \`tools/test_animation_pipeline.py\`
- Godot regression test: \`tests/animationtest.gd\`

The pipeline validates the current 800 × 468 sheet, checks all 15 cells,
exports a GIF preview for each direction, creates a review image and JSON
report, and compares the copied review sheet byte-for-byte with the tracked
production source. This provides a repeatable place to inspect and edit frames
before a later, separately reviewed replacement is connected to gameplay.

## Current limitations

No new character art is connected to the game in this pass. Dedicated idle,
run, dodge, hurt, death, enemy attack, and boss phase animations still need
authored frames. The enemy currently named \`skeleton\` is visually a horned
blue-armored creature, so a new animation must preserve that design.

All existing artwork rights records remain \`UNVERIFIED\`; successful export
and technical checks do not establish commercial-use rights. A new runtime
animation must pass a human visual review and Godot/device testing before it is
described as an in-game art upgrade.

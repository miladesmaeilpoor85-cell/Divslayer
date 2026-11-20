# Generated hero attack-atlas import contract

This tool is a deterministic import/validation stage for externally authored 2D sprite atlases. It does not generate character poses, redesign a character, or automatically register output in the playable game.

## Accepted source layout

- One 4-column × 3-row atlas.
- Rows are ordered \`down\`, \`up\`, \`side\`.
- Columns are ordered \`anticipation\`, \`windup\`, \`contact\`, \`recovery\`.
- A uniform magenta chroma background (\`#ff00ff\`) is the default.
- Each source cell must be at least 32 × 32 pixels and contain one complete character.

## Import

\`\`\`bash
python tools/import_animation_atlas.py generated/mage_starter.png \\
  --output assets/art/Heroes/mage_starter_attack \\
  --prefix mage_starter_attack
\`\`\`

The importer writes twelve transparent 160 × 156 PNGs, a packed 640 × 468 review atlas, and a JSON report. It flood-fills only key-colored pixels connected to each cell edge, preserving isolated same-colored detail inside the character. It uses one scale for all twelve poses and aligns every visible foot baseline to the same output row.

## Quality gates

- Reject a missing/non-divisible 4 × 3 grid, too-small cells, absent chroma background, or a character touching cell boundaries.
- Report exact duplicate frames and warn on adjacent motion below 2.5% of pixels.
- Keep any duplicate/low-motion warning visible; never silently synthesize substitute poses.
- Inspect the packed atlas and all frame PNGs at native pixel size.
- Check direction consistency, held weapon/staff/shield, silhouette, feet, alpha edges, and actual Android scale before runtime activation.
- Keep new assets' license status as \`UNVERIFIED\` until the source/provider terms and proof are reviewed.

## Runtime integration is separate

The importer intentionally does **not** edit \`data/art_manifest.json\`. Once an atlas is approved, copy its three frame-file lists into the relevant hero entry using the existing \`attackFrameFiles\` contract, set \`attackFrames: 4\`, \`attackFps: 24\`, and \`attackImpactFrame: 2\` only after confirming the contact pose. Then run the full Godot suite and Android emulator test.

## First batch

\`creative/animation/hero_starter_attack_batch.json\` records the starter-tier Mage, Rogue and Paladin source paths, output folders and class-specific pose constraints. This is an authoring specification only; it is not proof that these art assets have been generated or accepted.

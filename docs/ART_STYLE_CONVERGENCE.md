# Art style convergence contract

## Target visual language

Use one coherent, painterly 2D fantasy language across the game: hand-painted materials, strong silhouettes, textured surfaces, controlled cinematic lighting, and a grounded palette derived from Iranian landscapes, craft, architecture, and Shahnameh-inspired motifs. Keep the actual gameplay camera top-down and preserve the existing sprite pivot and movement readability.

## Character and portrait consistency

- Portraits must depict the same costume, palette, age, equipment, and identifying features as the in-game character.
- Do not mix photorealistic portrait rendering with highly simplified chibi gameplay art as the permanent target.
- Move new portraits toward stylised painterly illustration rather than photographic realism; enrich gameplay sprites gradually with clearer material separation, costume detail, and more expressive authored poses.
- Never count menu art, portraits, recolours, or sprite transforms as gameplay animation frames.
- For legacy portraits, use a staged replacement sequence and keep the old file as fallback until the new art passes identity and Android-scale review.

## Environment consistency

- Every map needs a biome-specific ground material and route composition; grass, mud, cobble, ash, basalt, ice, water, and sand must not share one generic texture.
- The ground image supplies surface material and visual route guidance only. Collision, walls, shelters, and hazards remain defined in map data.
- Keep high-contrast gameplay lanes readable and avoid painting fake collision boundaries that disagree with the actual wall rectangles.
- Use props, foliage, stones, debris, and landmarks to create scale without obscuring the player, enemies, boss telegraphs, or touch controls.
- Keep the ground image at the authored logical-map aspect ratio and preserve the runtime `groundScale` convention.

## Review checklist

- Check the map clean preview and the full object/collision overlay.
- Inspect at native imported texture size and at the smallest target Android display scale.
- Check all exits, landmarks, NPCs, and quest clues remain visible.
- Confirm no text, watermark, UI, border, or external web resource is embedded in world art.
- Record creator/source, tool/provider, date, terms, and proof reference in `docs/ASSET_RIGHTS_REGISTER.csv`. A successful import or CI run does not prove commercial-use rights.

## Regional terrain refinement pass — 26 November 2026

- **Zabol:** retain the readable central market and radial village lanes; deepen compacted-earth grain, worn road margins, scattered cobble, herb clumps and warm market light.
- **Whispering Forest:** preserve the west–east and north–south route network; add root shelves, damp moss, fern banks, leaf litter, small fungi and restrained canopy light.
- **Ashen Peaks:** preserve the exit-connected volcanic tracks; add broken basalt strata, scree, ash fractures, scattered cinder and restrained heat blooms away from the main lanes.

The ground SVGs retain their map-sized viewBoxes and 2× authored pixel dimensions. They are environmental surface illustrations only: walls, collision, hazards, spawns, exits and quest objects remain separate map data. Their new decoration pass is a quality iteration, not final art sign-off. Use the clean and native-logical-size review renders to inspect texture readability; the final acceptance gate remains an in-game Android-scale visual review.

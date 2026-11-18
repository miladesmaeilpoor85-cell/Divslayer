# Divslayer animation pipeline

## Current first pass

The starter warrior has a new four-frame, one-shot attack atlas for each of the
three directions already used by the game:

- `attack_down`: front-facing sequence
- `attack_up`: back-facing sequence
- `attack_side`: profile sequence (the existing left-facing flip is retained)

Each direction has four frames at 24 FPS: ready, wind-up, slash, and recovery.
The atlas uses the existing 160 × 156 source-cell convention and the existing
1/3 sprite scale. The walk and idle animations remain on the original sheet.
Only `warrior_starter` uses the new attack atlas; mid- and end-game gear sheets
continue to use their existing attack frames until matching art is produced.

## Editable source and output

- Source concept: `creative/animation/warrior_starter_attack_source.webp`
- Frame regions and directions: `creative/animation/warrior_starter_attack.json`
- Runtime atlas: `assets/art/Heroes/warrior_starter_attack.png`
- Builder and preview generator: `tools/animation_pipeline.py`
- Automated tests: `tools/test_animation_pipeline.py`

Krita and Pixelorama can open the exported atlas for frame-level revision.
The builder trims each configured source region, keeps a small alpha halo,
packs frames into the game's atlas layout, and generates one GIF per direction.
The CI artifact includes a contact sheet, the directional GIFs, and a JSON
build report.

## Pixelorama and Krita responsibilities

Krita is the painterly drawing / cleanup workspace. Pixelorama 1.2.4 is used
for frame timing, cel ordering, onion-skin review, and sprite-sheet editing.
Blender remains available for 3D / Grease Pencil work and future rigged
creature studies. Godot consumes the final atlas through `SpriteFrames`.

## QA and limitations

- CI checks the atlas dimensions, non-empty frame cells, frame count, GIF
  output, and deterministic output hash.
- Godot regression tests verify all three four-frame attack animations, their
  24 FPS playback speed, one-shot playback, and that the original walk and
  skeleton animations remain intact.
- This is an initial warrior attack study, not a completed animation set.
  Idle, walk, dodge, hurt, death, enemy attack, and boss phase animations still
  need dedicated art.
- The source is AI-assisted and has not been legally cleared for commercial
  use. The art register therefore remains `UNVERIFIED`.

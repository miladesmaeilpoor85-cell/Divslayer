# Divslayer animation pipeline

## First implemented runtime animation

The starter warrior now has a dedicated four-frame sword-attack animation for
each of the three directions supported by the current character controller:

- `attack_down`: front-facing attack
- `attack_up`: back-facing attack
- `attack_side`: profile attack; the controller's existing horizontal flip is retained

Each row contains four frames (ready, wind-up, slash, recovery) at 25 FPS.
Each cell is 160 × 156 pixels, matching the existing warrior sprite-sheet
layout and the project's 1/3 runtime display scale. The normal attack's
0.16-second visual window is matched by the four-frame sequence.

Only `warrior_starter` is connected to this new sheet. The mid- and end-game
warrior sheets and the mage, rogue, and paladin sheets continue using their
existing attack frame until matching art is produced. No combat damage,
hitbox, movement, or cooldown values are changed.

## Editable source and outputs

- Source concept sheet: `creative/animation/warrior_starter_attack_source.webp`
- Frame map and timings: `creative/animation/warrior_starter_attack.json`
- Runtime atlas: `assets/art/Heroes/warrior_starter_attack.png`
- Deterministic builder: `tools/animation_pipeline.py`
- Unit tests: `tools/test_animation_pipeline.py`
- Godot regression test: `tests/animationtest.gd`

The builder crops only the twelve explicitly mapped frame regions, trims
transparent margins, preserves alpha, packs the poses into the exact Godot
atlas layout, and generates one review GIF per direction. It records file
hashes and frame geometry in a JSON report. CI rebuilds the atlas and compares
it byte-for-byte with the runtime asset so that a changed source cannot silently
leave a stale in-game export.

Krita is the painterly cleanup and layer-editing workspace. Pixelorama 1.2.4
is installed and smoke-tested in the cloud creative-tools job for cel timing,
onion-skin review, and sprite-sheet editing. Blender remains available for
3D/Grease Pencil studies. Godot consumes the result through `SpriteFrames`.

## Test coverage

- Python tests verify the 640 × 468 output, 12 occupied frame cells, three
  four-frame GIFs, and deterministic output hash.
- Godot tests verify four attack frames in all three directions, 25 FPS,
  one-shot playback, preservation of the original four-frame walk, and
  continued availability of the existing skeleton animation.
- The regular Android export workflow builds a QA APK after source changes.

## Scope and limitations

This is the first real animation upgrade, not a finished animation overhaul.
Idle, walk, dodge, hurt, and death still need dedicated art. The skeleton
sprite is not changed because its current source image is a horned blue-armored
creature rather than a conventional skeleton; a matching attack/death sequence
must preserve that creature's existing visual identity.

The animation concept is AI-assisted. Its visual quality still requires
human review in the game and on the target phone. The two related image records
remain `UNVERIFIED` in the rights register; successful technical tests do not
clear commercial-use rights.

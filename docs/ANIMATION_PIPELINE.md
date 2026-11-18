# Divslayer animation pipeline

## First implemented runtime animation

The starter warrior has a four-frame sword-attack animation for each of the
three directions supported by the current character controller:

- `attack_down`: front-facing attack
- `attack_up`: back-facing attack
- `attack_side`: profile attack; the existing horizontal flip is retained

Each row contains four frames (ready, wind-up, slash, recovery) at 25 FPS.
Each cell is 160 × 156 pixels, matching the existing warrior sprite-sheet
layout and the project's 1/3 runtime display scale. The sequence lasts 0.16
seconds, matching the existing normal attack visual window. Combat damage,
hitboxes, movement, and cooldowns are unchanged.

Only `warrior_starter` uses this new sheet. Mid- and end-game warrior sheets
and other classes retain their existing attack visuals until matching art is
available.

## Editable source and review

- Editable transparent atlas: `assets/art/Heroes/warrior_starter_attack.png`
- Frame/direction configuration: `creative/animation/warrior_starter_attack.json`
- Deterministic validator and preview exporter: `tools/animation_pipeline.py`
- Unit tests: `tools/test_animation_pipeline.py`
- Godot regression test: `tests/animationtest.gd`

The PNG atlas can be opened in Pixelorama or Krita. The CI job validates its
dimensions and every cell, exports directional GIF previews, produces a review
image and JSON report, and checks that the exported PNG matches the in-game
asset byte-for-byte. Pixelorama 1.2.4 is installed and smoke-tested in the
cloud creative-tools job; Krita remains the painterly cleanup workspace.

## Tests and scope

- Python tests verify the 640 × 468 atlas, 12 occupied cells, three
  four-frame GIFs, and deterministic output hash.
- Godot tests verify four attack frames in all directions, 25 FPS, one-shot
  playback, preservation of the original walk, and continued availability of
  the existing creature animation.
- The regular Godot CI and Android QA workflows validate the change before
  an installable build is offered.

This is the first animation pass, not a completed overhaul. Idle, walk, dodge,
hurt, death, enemy attacks, and boss phase animations still need dedicated art.
The current `skeleton.png` source depicts a horned blue-armored creature, so
its visual identity must be preserved when its animation set is redesigned.

The new animation was AI-assisted. The image rights register remains
`UNVERIFIED`; technical validation does not establish commercial-use rights.
Human review in the actual game and on the target phone is still required.

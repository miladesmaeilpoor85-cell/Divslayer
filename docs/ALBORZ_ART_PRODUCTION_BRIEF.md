# Alborz environment — dedicated art production brief

**Target:** replace the temporary reused visual assets in the Chapter IV prototype from [PR #36](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/36). This brief does not claim that final art has been produced.

## Existing playable geometry

The prototype map is 1400 × 1100 logical pixels. Its current configuration uses `groundScale: 2`, a single eastward gust zone, two shelter rectangles, collision walls, cloth-marker route cues, serpent guards, and an interactable scout.

The prototype currently reuses `frostvale_ground.jpg`, existing rock/spire props, Hesk's NPC appearance/portrait path, and the Ashen Peaks music alias. Keep these placeholders until each replacement has been imported and checked; do not remove a working fallback before the new asset is present.

## Required dedicated assets

| Asset group | Deliverable | Review criteria |
|---|---|---|
| Alborz ground | New `alborz_ground.jpg` or approved lossless equivalent | Mountain-pass composition, readable walk lanes, wind corridors, no baked-in collision cues, consistent map scale |
| Rock/shelter set | Dedicated wind-carved boulders, shelter walls, ledges, and rubble | Clear collision silhouettes and enough visual contrast to identify safe shelter |
| Route markers | Frayed cloth streamers, weathered poles, cairns | The marker direction should remain legible at mobile scale and in rain/snow |
| Scout character | A dedicated Alborz scout sprite/look plus dialogue portrait | Distinct silhouette from Hesk; consistent size, pivot, shading, and portrait identity |
| Wind environment FX | Dust/snow/ash streak textures only if procedural lines are insufficient | Avoid visual noise over enemies, telegraphs, and touch controls |
| Ambient audio | A dedicated wind bed and short gust cues | Non-fatiguing loop, no clipping, clear warning/active/rest distinction |

## Art direction

Use the project's Persian-mythology dark-fantasy identity: rugged high-altitude Alborz stone, weathered cloth, sparse alpine vegetation, cold blue/charcoal shadows, muted stone, and restrained warm highlights from distant settlements or lanterns. The pass should feel dangerous but navigable. Avoid modern equipment, sci-fi machinery, generic European castle silhouettes, anime styling, and readable text/logos embedded in artwork.

## Technical delivery requirements

- Keep the ground dimensions aligned with the map's logical size and `groundScale`. With the current 2× scale convention, validate the actual imported texture dimensions in Godot rather than resizing by assumption.
- Preserve transparency for sprite assets and include clean source files for Krita/Blender where applicable.
- Use Godot's actual collision geometry, not painted dark shapes, to define shelters and walls.
- Import the scout through the normal art manifest/NPC look path and connect its dialogue portrait; a JSON `look` label alone is not sufficient.
- Run artwork decode, map preview, asset manifest, GDScript, Godot, and Android checks after import.
- Add each delivered image/audio file to `docs/ASSET_RIGHTS_REGISTER.csv` / the audio credits with exact provenance and terms before shipping.

## Acceptance test

A tester must be able to read the path, shelters, markers, enemies, and scout at native phone scale in both languages. Shelter boundaries must align with collision. Wind streaks must remain visible without obscuring enemies or attack telegraphs. The scene must still run within the current mobile frame-time budget on the target Android device.

## Status

The assets listed above have not been delivered by this brief. PR #36 remains a prototype using temporary reused assets until its art and physical-device acceptance tests are complete.

## Draft visual implementation — 2026-11-25

A dedicated high-altitude Alborz ground texture, a separate High Eyrie summit-arena ground texture, four Alborz prop assets, one High Eyrie rock-spire asset, and a redesigned four-frame Gale Warden SVG sprite with distinct spread, upstroke, downstroke, and folded-wing poses has been added on the review branch feat/alborz-warden-dedicated-art-20261125. The map data and runtime loaders now reference these assets, and the Chapter IV test checks the dedicated grounds, props, and animated boss sheet.

This is a first integrated visual pass, not final approval. Godot import/CI, native-size visual inspection, mobile-scale readability, physical Android performance, and owner-side asset-rights review remain required. The Alborz Scout still uses the existing Hesk look; dedicated scout artwork/portrait and a bespoke gust-specific cue remain outstanding. The existing recorded wind loop (`assets/audio/amb/wind.ogg`, already listed in the audio credits) is now enabled automatically on Alborz and the High Eyrie and fades out when leaving those maps; no duplicate ambience file was added. All new vector art is registered as UNVERIFIED; no commercial-use clearance is claimed.

## Dedicated Scout integration — 2026-11-26

A separate three-direction `alborz_scout` character atlas is wired through the NPC art manifest and runtime loader. The Alborz map no longer requests Hesk for this character. The Chapter IV regression test checks the dedicated look registration and four-frame directional walk animation. The new asset remains `UNVERIFIED`; native Android-scale visual acceptance and owner-side rights review are still mandatory.

## Gale Warden attack-state animation — 2026-11-26

The four-frame Warden sprite now has a timed attack sequence: raised-wing anticipation, downstroke impact, folded-wing recovery, then return to the idle wing cycle. Each of the four signature attacks starts the sequence against its own telegraph timing. Regression checks cover the three pose transitions. This is a functional animation pass; visual review at actual mobile size remains required.

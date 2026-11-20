# Warrior animation review scene | بازبینی انیمیشن جنگجوی دیوکش

**Status:** read-only developer review harness. It previews the existing Warrior starter sheet; it does not contain or activate a new multi-frame production attack animation.

## Open the scene

From the project root:

```sh
godot --path . res://scenes/dev/warrior_animation_review.tscn
```

On the review screen, tap **روبه‌رو**, **پشت**, or **نیم‌رخ** to preview the four-frame walk cycle for each direction. Tap **حمله** or press Space to show the single attack pose with a short sword-slash arc drawn by the review scene. Keyboard shortcuts: `1` front/down, `2` back/up, `3` side/right, `Space` attack.

The slash arc is a review-scene visual effect. It is not a rendered sequence of new sword poses and does not exercise the production combat damage pipeline.

## Source sheet and import contract

The review scene loads the already tracked `assets/art/Heroes/warrior_starter.png` read-only and reads cell dimensions, row order, and foot pivot from `data/art_manifest.json`.

The current layout is 800 × 468 pixels: five 160 × 156 cells per row, with rows `down`, `up`, and `side`. Columns 0–3 are the four walk poses; column 4 is one attack pose. The review scene builds four-frame walk clips and a one-frame attack clip from those cells. It does not replace the source sheet, edit the production manifest, change the production loader, or alter the pivot, class IDs, or main scene.

## Actual production status

The current production manifest registers 12 hero appearance sheets: Warrior, Mage, Rogue, and Paladin, each with starter, mid, and endgame looks. All 12 currently use four walk columns and one attack column in each of the three directions.

As of the reviewed `main` revision:

- There is no `assets/art/Heroes/warrior_starter_attack.png` file in the repository.
- No current hero manifest entry registers an `attackSheet`, `attackFrames`, `attackImpactFrame`, or `heavyImpactFrame`.
- `scripts/sheets.gd` contains infrastructure for future embedded multi-frame attack columns or a separate attack atlas, but the current hero manifests do not activate either format.
- `scripts/player.gd` defaults a missing impact-frame setting to frame 0. Therefore the current one-frame production attacks still resolve their gameplay hit immediately; the future delayed-impact path is not active for the current hero sheets.

The similarly named `creative/animation/warrior_starter_attack.json` is a preview configuration file. It points to the existing `warrior_starter.png` source sheet; it is not a new PNG attack atlas.

## Checks

`tests/warriorreviewtest.gd` checks that the review scene loads, the three directional walk clips contain four frames, the idle and single-pose attack clips exist, the atlas cell size and foot pivot match the manifest, and the review attack effect returns to the selected walk animation.

`tests/animationtest.gd` checks the 12 existing hero looks and tests the loader's future multi-frame formats with synthetic in-memory textures. Those synthetic tests validate the loader contract; they do not prove that a real production multi-frame attack atlas exists or is used by the game.

The current `main` revision's Godot CI completed the full headless suite successfully, including 18 Warrior review checks and 291 animation checks. This is an automated resource/code check, not a human visual sign-off in Krita or an Android-device test of new attack art.

## Provenance and rights

The existing Warrior source sheet is listed in `docs/ASSET_RIGHTS_REGISTER.csv` with commercial-use status **UNVERIFIED**. This review scene adds no new image asset and makes no new provenance or licensing claim.

Any future multi-frame attack art must be created as genuinely distinct anticipation, contact, and recovery poses; checked at native mobile scale; recorded in the asset rights register with its source and applicable terms; imported through the production manifest; and tested in Godot and on Android before being treated as production-ready.

## Next steps

1. Create and visually review real multi-frame Warrior attack poses for all three directions. Do not manufacture a purported animation by merely shifting, rotating, recolouring, or squashing the existing still pose.
2. Register the reviewed atlas in the manifest, then set the impact-frame metadata only after the contact frame and combat timing have been tested together.
3. Verify normal and heavy attacks, directional locking, hitbox timing, cancellation by Dodge/Block, death, and map changes.
4. Test the production animation at native mobile size and on a physical Android device before promoting the asset.

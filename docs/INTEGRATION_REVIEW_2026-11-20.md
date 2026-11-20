# Integration review — 20 November 2026

## Current result

The changes from source PRs #25, #26, and #36 have been combined on the draft integration branch:

- Branch: `integration/next-phase-workstreams-2026-11-20`
- Combined head: `0cba9c963c460d2ed19f2d35bd77e1b6fed33677`
- Review PR: [#38](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/38) — draft, targets `main`
- Current `main` remains unchanged at `0f20e499bf17966a9edb3639a4373205be048edd`.

This was a controlled port, not three independent merges to main. The original source PRs #25, #26, and #36 remain open for reference and must not be merged separately. The temporary bridge PR #39 was merged into the integration branch; bridge PRs #40 and #41 were closed after their changes were incorporated into the combined head.

## What is included in the combined head

| Source | Imported changes | Combined validation |
|---|---|---|
| [#25](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/25) | Weather-aware drift for rain, snow, ash, leaves, embers, spores and fog; weather FX regressions; CI sharding and test-runner updates | Combined FX suite passed; current head passed all Godot shards |
| [#26](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/26) | Directional dodge trail; persistent Thornwood fight choice; regression tests | Combined FX suite: 38 checks passed; Thornwood Toll suite: 60 checks passed |
| [#36](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/36) | Alborz map, Peaks route, wind zone/shelters, wind visual cues, serpent guards, scout, save-backed chapter flow, return to Zal, audio alias, Chapter IV test | Chapter IV suite: 28/28 passed; wind suite: 31/31 passed |

## Conflict resolution

The source branches overlapped in `scripts/game.gd`, `scripts/main.gd`, `scripts/world.gd`, `tests/fxtest.gd`, `CHANGELOG.md`, workflow configuration, and `tools/run_all_tests.sh`.

The combined branch preserves:
- the quest-progress and legacy save handling from the existing gameplay branch;
- the Thornwood `fight_started` persistence guard;
- the Chapter IV `Game.Ch4` registration, Zal dialogue/objective flow, map gate, scout rescue and return reward;
- both the weather-response and directional dodge assertions in `tests/fxtest.gd`;
- both changelog entries;
- the Chapter IV test in the full test runner.

No source PR branch was force-pushed or rewritten.

## CI results on the combined head

The current combined head has passed:
- all four Godot 4.7.2 test shards, including the headless project import;
- the Chapter IV 28-check regression suite;
- the wind controller 31-check regression suite;
- the combined FX 38-check suite and Thornwood 60-check suite;
- the autotest;
- GDScript lint and Python/Ruff lint;
- artwork/map validation and audio decode/metadata validation.

Workflow evidence:
- [Godot CI run 44731912116](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44731912116)
- [Lint, asset and audio run 44731912449](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44731912449)

At the last check, the creative-app smoke test and Android QA export/emulator workflow were still in progress:
- [Creative applications run 44731912173](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44731912173)
- [Android QA run 44731912100](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44731912100)

The original PR #36 emulator validation installed and launched the APK, but its screenshot was the title screen. Neither this nor a successful headless test proves the Alborz route is playable on a physical phone.

## Required physical-device acceptance

Before promoting the combined head to `main`, test on the target Android phone:

1. Unlock Chapter IV only after Chapter III is complete and Zal has introduced the mission.
2. Enter Alborz from Ashen Peaks and verify the return route and spawn positions.
3. Observe warning, active and rest timing; walk through both shelter zones and verify collision/attenuation.
4. Fight all three guards; confirm the scout cannot be rescued before they are defeated.
5. Rescue the scout, return to Zal, claim the reward, save, quit, relaunch and confirm the completed state persists.
6. Repeat key movement and interaction checks with touch controls and all four player classes.
7. Watch for frame-time spikes, excessive particle overdraw, collision trapping, or visual telegraphs obscured by combat.

## Still not complete

- Dedicated Alborz ground, props, scout sprite/portrait and recorded wind ambience. The current map reuses Frostvale ground, Hesk's look, existing props and the Peaks music track.
- An optional eyrie route or dedicated wind boss.
- Real multi-frame hero animation artwork. Existing production hero attacks still use one pose per direction.
- Physical-phone gameplay sign-off.
- Rights evidence for the 371 registered images and 30 soundtrack tracks, legal review, and production Android identity/signing setup.

## Promotion rule

Keep [PR #38](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/38) in draft. Merge to `main` only after the remaining combined CI workflows finish successfully, physical-device gameplay passes, and the project owner approves the final diff. The current branch contains no production signing key, private export preset, app ID, API credential, or generated final artwork.

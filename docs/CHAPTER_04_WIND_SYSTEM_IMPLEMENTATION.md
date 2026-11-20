# Chapter IV wind system — implementation status

**Status checked: 20 November 2026.** This document distinguishes what is already in `main` from the separate Alborz vertical-slice proposal.

## Current implementation on `main`

The deterministic controller in `scripts/wind_gust.gd` is implemented and has automated coverage in `tests/windgusttest.gd`. It cycles through warning, active, and rest phases; carries excess time across phase boundaries; clamps durations and drift; normalizes direction; and returns a bounded velocity contribution rather than accumulating acceleration.

The generic runtime integration is also present on `main`:

- `scripts/world.gd` parses optional `windGusts` definitions from map data, validates zone and shelter rectangles, advances one controller per zone, and returns the drift at a position.
- `scripts/player.gd` adds wind drift to ordinary movement. The dodge/dash branch remains separate, and death/revive reset the wind controllers.
- Maps without `windGusts` retain their normal movement.

**Important boundary:** the current `main` map data does not yet contain an authored Alborz wind zone. The reusable controller and generic integration are implemented, but they do not by themselves create a playable wind level or show wind cues.

## Runtime contract

A map may opt in by adding a top-level `windGusts` array inside its data object. Rectangles and directions are numeric arrays:

```json
{
  "windGusts": [
    {
      "rect": [300, 240, 220, 180],
      "direction": [1, 0],
      "warning_seconds": 0.95,
      "active_seconds": 1.6,
      "rest_seconds": 1.9,
      "drift_speed": 45,
      "shelter_multiplier": 0.1,
      "shelters": [[340, 280, 70, 65]]
    }
  ]
}
```

The phases are:

1. **Warning:** readable telegraph time; no movement force.
2. **Active:** bounded drift contribution.
3. **Rest:** no movement force before the next warning.

Safety constraints enforced by the controller:

- Drift speed is clamped to 0–55 logical pixels/second.
- Each phase duration is clamped to 0.1–8 seconds.
- Shelter attenuation is clamped to 0–15% of the exposed force.
- Dodge has priority over wind.
- Reset/configure starts at warning, never in an active gust.

## Alborz playable slice — PR #36 imported to the integration branch, not yet in `main`

[PR #36](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/36) adds a first playable prototype: a 1400 × 1100 pass map, an Ashen Peaks route, one eastward gust zone, two shelter rectangles with collision support, serpent guards, a trapped scout, and a save-backed briefing/rescue/return objective sequence.

The PR also adds `scripts/fx/wind_visual.gd`, a procedural visual telegraph using Godot draw calls. That visual is not a dedicated texture or final environmental art.

The source PR reports a 37-suite / 1,575-check Godot run, 28/28 Chapter IV checks, plus Android emulator install/launch validation. The combined integration head `0cba9c963c460d2ed19f2d35bd77e1b6fed33677` includes the Alborz map, chapter flow, wind visuals, and Chapter IV regression test. Its four Godot shards passed; the Chapter IV 28-check, wind 31-check, FX 38-check and Thornwood 60-check suites passed. The latest Android QA export/emulator workflow and creative-app smoke test were still in progress at the last check. The latest PR head also has successful Godot, lint, artwork/map, audio, creative-tool, and Android QA checks. The emulator capture described in the PR is the title screen, not a gameplay visual sign-off; a physical-device playthrough of the new Alborz objectives is still required.

## Temporary assets and remaining work

The prototype currently reuses `frostvale_ground.jpg`, Hesk's existing look, existing props, and the Peaks music alias. These are explicitly temporary. Do not label the Alborz visual or audio treatment final until dedicated assets have been created, registered in the rights ledger, imported, and tested.

Remaining validation before promoting the slice:

- Play the complete route on a physical Android device: enter from Peaks, read each warning, shelter from gusts, fight the guards, rescue the scout, return to Zal, save, quit, and reload.
- Test boundaries, shelter collision, zone overlap, all four player classes, dodge priority, enemy knockback, and touch controls.
- Confirm map exits and return spawn coordinates in both directions.
- Replace reused ground, scout, and props with dedicated art and add an authored wind ambience track.
- Add the optional eyrie route and dedicated wind encounter only after the core pass is stable and readable.
- Combined Godot, GDScript/Python lint, artwork/map and audio checks have passed on the integration head. Finish the pending creative-app smoke test and Android QA export/emulator workflow, then complete the physical-phone playthrough.

## Automated coverage

`tests/windgusttest.gd` covers phase transitions, warning progress, shelter attenuation, dodge priority, repeated sampling without accumulation, reset, negative/large delta handling, safe fallback direction, clamping, and generic World integration. The Chapter IV-specific acceptance checks live in `tests/chapter4test.gd` on PR #36.

Passing automated tests is necessary but does not replace device playtesting or an art review at native mobile scale.

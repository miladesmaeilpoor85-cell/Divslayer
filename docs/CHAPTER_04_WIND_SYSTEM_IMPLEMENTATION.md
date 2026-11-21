# Chapter IV wind-gust controller

**Status (2026-11-20):** the deterministic phase controller, World/Player movement integration, procedural telegraph visuals, and a first playable Alborz pass prototype are implemented and covered by the headless test suite. The Alborz ground image and scout look are temporary reused assets; this is not final chapter content.

## Runtime contract

scripts/wind_gust.gd provides a small RefCounted controller for one gust zone. It deliberately owns no scene nodes, textures, audio streams, save data, or player references.

Example:

    const WindGust = preload("res://scripts/wind_gust.gd")
    var pass_gust = WindGust.new({
        "direction": Vector2.LEFT,
        "warning_seconds": 0.95,
        "active_seconds": 1.6,
        "rest_seconds": 1.9,
        "drift_speed": 45.0,
        "shelter_multiplier": 0.1,
    })

A map can opt in by adding a top-level windGusts array inside its data object. Rectangles and directions are stored as numeric arrays:

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

Call advance(delta) once per physics frame. The phases cycle in this order:

1. warning: a readable telegraph; no movement force is returned.
2. active: drift_velocity() returns a bounded velocity contribution.
3. rest: no movement force; the next warning begins after the rest interval.

The controller preserves unused frame time when a large delta crosses more than one phase. warning_progress() exposes a 0..1 value. The current map's procedural WindVisual draws moving streaks during warning/active phases and outlines shelter rectangles.

## Safety rules enforced by the controller

- Wind is a returned velocity contribution, not a stored acceleration; repeated sampling does not accumulate force.
- Requested direction is normalized; a zero or non-vector direction falls back to Vector2.RIGHT.
- Drift speed is clamped to 0..55 logical pixels/second.
- Shelter multiplier is clamped to 0..0.15.
- Each phase duration is clamped to 0.1..8 seconds.
- Dodge has priority: drift_velocity(sheltered, true) returns zero.
- reset() and configure() restart in warning, never in an active gust. Call reset after death, reload, or map transition rather than restoring a mid-gust impulse from a save.

## Automated coverage

tests/windgusttest.gd is included in tools/run_all_tests.sh. It checks initial warning, warning progress, phase transitions, shelter reduction, dodge priority, no accumulation, reset behavior, negative delta handling, large-delta phase carry-over, zero-direction fallback, and all configuration bounds.

## Current World/Player integration

- `scripts/world.gd` reads optional `data.windGusts` definitions during map build, creates a controller per valid zone, advances each controller in `_physics_process`, checks its shelter rectangles, and returns the drift contribution for a feet position.
- `scripts/player.gd` adds that contribution only to ordinary movement through `move_and_slide()`. The dash path remains independent. Death and revive reset the zone phases.
- `scripts/fx/wind_visual.gd` adds directional procedural streaks and shelter outlines using existing drawing primitives; no imported textures or new generated assets are required.
- Maps without `windGusts` keep their current movement and visual behavior.

## Alborz vertical-slice implementation

`data/Maps/alborz.json` now defines a 1400 × 1100 prototype map. It is connected from the north edge of Ashen Peaks; the player enters Alborz from its south edge and returns to Peaks through a south-side exit so the route is traversed rather than immediately backtracked. The pass includes one timed eastward gust zone, two shelter rectangles, and collision walls at the shelter edges. Three existing serpent guards protect an interactable scout. The save-backed chapter flow is Zal briefing → pass entry → clear guards → rescue scout → return to Zal.

The route is gated until Chapter III has reached `done` and Zal has introduced Chapter IV. Entering the Alborz map advances the objective to the scout rescue. The scout cannot be rescued while either `serpentguard` or `serpentarcher` remains alive in that map. Rescue advances the saved objective to return to Zal and the epilogue completion grants 180 gold.

The Alborz map intentionally reuses `frostvale_ground.jpg`, Hesk's existing NPC look, existing rock/spire props, and the Peaks music track alias. These are temporary compatibility placeholders, not final art or a claim that a dedicated Alborz soundtrack exists. The High Eyrie is now a connected, gated optional arena entered from the east edge of the Alborz pass. It contains the new three-phase Gale Warden, whose custom silhouette is drawn procedurally until final painted character art is supplied. The Eyrie also uses the current Peaks track alias and procedural ash/wind visuals; it does not yet have a dedicated recorded score or bespoke ground painting.

## Regression coverage and verification

`tests/chapter4test.gd` is included in `tools/run_all_tests.sh`. On 2026-11-20, the full Godot 4.7.2 CI completed with 37 suites, 1,575 assertions passed, no failures/crashes/parser errors. The original scout-rescue slice contributed 28/28 checks. The new High Eyrie route, wind boss, and crosswind telegraph checks are additional and are covered by the updated `tests/chapter4test.gd`; the new PR's complete Godot CI must be used for its final pass/fail count. Android QA exported and debug-signed the APK, installed and launched it in the API 35 emulator, and verified it remained the resumed foreground app. The captured screenshot is the title screen, not a gameplay visual sign-off; user playtesting of the new chapter is still required.

The next production tasks are final Alborz/Eyrie ground and prop art, a dedicated scout portrait, polished recorded wind ambience, a painted Gale Warden sprite/animation sheet, and encounter balance on physical Android hardware. The current boss and route are implemented as a playable coded slice; the procedural silhouette and reused terrain remain placeholders.
## Integration after main synchronization (2026-11-21)

The Chapter IV completion branch now includes `main` commit `81b63f9c09e7b862a2b95e99bbb24d7db1885ef0` as a merge parent (integration merge `134fd6566c2c63f9a348656862c4f95de6095c7c`). The synced tree retains the High Eyrie and Gale Warden work while bringing in the main-branch hero attack assets, Rogue attack atlas/runtime support, updated Android QA workflow, and production-evidence audit tooling.

The branch is no longer behind `main`. Godot headless CI and Android QA must pass on the post-sync head before PR #37 is merged. An emulator install/launch check is not a substitute for a physical-device playthrough of the Alborz route and Gale Warden encounter.

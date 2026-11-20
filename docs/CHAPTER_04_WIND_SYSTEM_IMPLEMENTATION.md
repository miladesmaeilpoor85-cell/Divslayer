# Chapter IV wind-gust controller

**Status:** the deterministic phase controller and automated unit-style tests are implemented. The controller is not yet connected to a production map or player movement.

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

The controller preserves unused frame time when a large delta crosses more than one phase. warning_progress() exposes a 0..1 value for later visual/audio telegraph work.

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

## Explicit integration boundary

This is a tested gameplay building block with generic World/Player integration. World reads optional windGusts zone definitions from map data, advances the phase controllers, checks shelter rectangles, and returns a drift contribution. Player adds that contribution only during normal move_and_slide(); the existing dash branch remains separate, and death/revive reset the zones. Maps without windGusts retain their existing movement. This is not a playable Chapter IV implementation: no alborz map, ground art, placed zones, scout rescue, or Div-e Gerdbad boss is added here. The next step is to author and test actual zone placement, wall/map-edge cases, all four classes, persistence/restart, and Android touch controls.


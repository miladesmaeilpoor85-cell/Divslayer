extends Node
## Deterministic tests for the Chapter IV wind-gust phase controller.
## Run through tools/run_all_tests.sh or:
## godot --headless --fixed-fps 60 --path . -- --test res://tests/windgusttest.gd

const WindGustController = preload("res://scripts/wind_gust.gd")

var results: Dictionary = {}
var fails: Array[String] = []


func check(label: String, ok: bool, info: Variant = null) -> void:
	results[label] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(label)
	printerr(("PASS " if ok else "FAIL ") + label + ("" if info == null else "  " + str(info)))


func run(_main: Node) -> void:
	var gust = WindGustController.new({
		"direction": Vector2(0.0, 4.0),
		"drift_speed": 45.0,
		"warning_seconds": 0.8,
		"active_seconds": 1.4,
		"rest_seconds": 1.8,
		"shelter_multiplier": 0.1,
	})

	check("starts_with_warning_not_active", gust.phase_name() == "warning" and not gust.is_active())
	check("no_force_during_warning", gust.drift_velocity() == Vector2.ZERO)
	check("warning_progress_starts_at_zero", is_zero_approx(gust.warning_progress()))
	gust.advance(0.4)
	check("warning_progress_advances", is_equal_approx(gust.warning_progress(), 0.5))
	check("warning_does_not_push_player", gust.drift_velocity() == Vector2.ZERO)
	gust.advance(0.4)
	check("warning_transitions_to_active", gust.phase_name() == "active" and gust.is_active())
	check("active_drift_uses_normalized_direction",
		gust.drift_velocity().is_equal_approx(Vector2.DOWN * 45.0), gust.drift_velocity())
	check("shelter_reduces_drift",
		gust.drift_velocity(true).is_equal_approx(Vector2.DOWN * 4.5), gust.drift_velocity(true))
	check("dodge_has_priority_over_wind", gust.drift_velocity(false, true) == Vector2.ZERO)

	var first_sample: Vector2 = gust.drift_velocity()
	for _i in 10:
		gust.drift_velocity()
	check("repeated_samples_do_not_accumulate", gust.drift_velocity() == first_sample)
	gust.advance(1.4)
	check("active_transitions_to_rest", gust.phase_name() == "rest" and not gust.is_active())
	check("rest_has_no_drift", gust.drift_velocity() == Vector2.ZERO)
	gust.advance(1.8)
	check("rest_returns_to_warning", gust.phase_name() == "warning")
	check("new_cycle_has_no_immediate_force", gust.drift_velocity() == Vector2.ZERO)

	gust.advance(0.1)
	gust.reset()
	check("reset_clears_partial_warning", gust.phase_name() == "warning"
		and is_equal_approx(gust.remaining_seconds, 0.8))
	gust.advance(-5.0)
	check("negative_delta_does_not_advance", is_equal_approx(gust.remaining_seconds, 0.8))

	gust.advance(5.0)
	check("large_delta_preserves_phase_remainder", gust.phase_name() == "warning"
		and is_equal_approx(gust.remaining_seconds, 0.6))

	gust.configure({
		"direction": Vector2.ZERO,
		"drift_speed": 900.0,
		"shelter_multiplier": 0.9,
		"warning_seconds": -2.0,
		"active_seconds": 0.0,
		"rest_seconds": 99.0,
	})
	check("zero_direction_uses_safe_fallback", gust.direction == Vector2.RIGHT)
	check("drift_speed_is_capped", is_equal_approx(gust.drift_speed, 55.0))
	check("shelter_multiplier_is_capped", is_equal_approx(gust.shelter_multiplier, 0.15))
	check("durations_are_clamped",
		is_equal_approx(gust.warning_seconds, 0.1)
		and is_equal_approx(gust.active_seconds, 0.1)
		and is_equal_approx(gust.rest_seconds, 8.0))
	check("configure_restarts_warning", gust.phase_name() == "warning"
		and is_equal_approx(gust.remaining_seconds, 0.1))

	gust.advance(0.1)
	check("capped_force_stays_bounded",
		gust.drift_velocity().is_equal_approx(Vector2.RIGHT * 55.0))
	check("capped_sheltered_force_stays_bounded",
		gust.drift_velocity(true).is_equal_approx(Vector2.RIGHT * 8.25))

	printerr("WINDGUSTTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit(1 if not fails.is_empty() else 0)

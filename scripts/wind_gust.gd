extends RefCounted
class_name WindGust
## Deterministic wind-gust cycle for top-down maps.
## Call advance(delta) once per physics frame and add drift_velocity() to ordinary
## movement only while the player is not dodging. The returned velocity is never
## accumulated by this class; reset() after death, reload, or map transition.

enum Phase { WARNING, ACTIVE, REST }

const MIN_DURATION := 0.1
const MAX_DURATION := 8.0
const MAX_DRIFT_SPEED := 55.0
const MAX_SHELTER_MULTIPLIER := 0.15

var warning_seconds: float = 0.95
var active_seconds: float = 1.6
var rest_seconds: float = 1.9
var direction: Vector2 = Vector2.RIGHT
var drift_speed: float = 45.0
var shelter_multiplier: float = 0.1

var phase: Phase = Phase.WARNING
var remaining_seconds: float = 0.95


func _init(options: Dictionary = {}) -> void:
	configure(options)


## Applies validated values and starts a fresh warning phase.
func configure(options: Dictionary = {}) -> void:
	warning_seconds = clampf(
		float(options.get("warning_seconds", warning_seconds)),
		MIN_DURATION,
		MAX_DURATION
	)
	active_seconds = clampf(
		float(options.get("active_seconds", active_seconds)),
		MIN_DURATION,
		MAX_DURATION
	)
	rest_seconds = clampf(
		float(options.get("rest_seconds", rest_seconds)),
		MIN_DURATION,
		MAX_DURATION
	)
	drift_speed = clampf(
		float(options.get("drift_speed", drift_speed)),
		0.0,
		MAX_DRIFT_SPEED
	)
	shelter_multiplier = clampf(
		float(options.get("shelter_multiplier", shelter_multiplier)),
		0.0,
		MAX_SHELTER_MULTIPLIER
	)

	var requested_direction: Variant = options.get("direction", direction)
	if requested_direction is Vector2:
		var vector: Vector2 = requested_direction
		if vector.length_squared() > 0.0001:
			direction = vector.normalized()
		else:
			direction = Vector2.RIGHT
	else:
		direction = Vector2.RIGHT

	reset()


## Restarts at the telegraph phase; no gust force is available immediately.
func reset() -> void:
	phase = Phase.WARNING
	remaining_seconds = warning_seconds


## Advances through phase boundaries, preserving excess time for large frame steps.
func advance(delta: float) -> void:
	var time_left := maxf(delta, 0.0)
	while time_left > 0.0:
		if remaining_seconds <= 0.000001:
			_advance_phase()
		var step := minf(time_left, remaining_seconds)
		remaining_seconds = maxf(0.0, remaining_seconds - step)
		time_left = maxf(0.0, time_left - step)
		if remaining_seconds <= 0.000001:
			_advance_phase()


func _advance_phase() -> void:
	match phase:
		Phase.WARNING:
			phase = Phase.ACTIVE
			remaining_seconds = active_seconds
		Phase.ACTIVE:
			phase = Phase.REST
			remaining_seconds = rest_seconds
		Phase.REST:
			phase = Phase.WARNING
			remaining_seconds = warning_seconds


func phase_name() -> String:
	match phase:
		Phase.WARNING:
			return "warning"
		Phase.ACTIVE:
			return "active"
		Phase.REST:
			return "rest"
	return "warning"


func is_active() -> bool:
	return phase == Phase.ACTIVE


## 0..1 telegraph progress for UI/FX; zero outside the warning phase.
func warning_progress() -> float:
	if phase != Phase.WARNING or warning_seconds <= 0.0:
		return 0.0
	return clampf(1.0 - remaining_seconds / warning_seconds, 0.0, 1.0)


## A bounded, non-accumulating velocity contribution in logical pixels/second.
## Dodge has priority over wind; shelter reduces the drift to at most 15%.
func drift_velocity(sheltered: bool = false, dodging: bool = false) -> Vector2:
	if phase != Phase.ACTIVE or dodging or drift_speed <= 0.0:
		return Vector2.ZERO
	var multiplier := shelter_multiplier if sheltered else 1.0
	return direction * minf(drift_speed * multiplier, MAX_DRIFT_SPEED)

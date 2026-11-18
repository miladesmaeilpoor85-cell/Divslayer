extends Camera2D
## The hero's camera (port of the HTML VIS camera): smoothed follow, a look-ahead in the direction the hero
## walks, a directional "punch" on big hits, screen shake, and the distance setting (far / normal / near).
## A map smaller than the view is never shown with empty bands: the zoom grows just enough to fill it.
## (v0.24, playtest: "the fight by the wall is fought under my thumbs") the view may slide past the map's edges by part of the
## screen — most on the right and at the bottom, where the buttons are — so a hero by a wall is not pushed under the buttons
## or the joystick. The world draws an apron there (the ground mirrored, falling into darkness).
const APRON := {"l": 0.12, "t": 0.20, "r": 0.24, "b": 0.20}   # fractions of the view (the HUD sits on top)
## (v0.26, playtest: "in the bottom-right corner of Zabol and of Arzhang's lair the hero stands exactly on the Shield
## button") in a bottom corner the view slides further down: the nearer the hero is to the columns of the buttons (right)
## or of the joystick (left), the more apron shows under him, until his feet are above them
const CORNER_B := 0.20

var hero: Node2D = null
var look := Vector2.ZERO
var kick := Vector2.ZERO
var kick_k := 0.0
var shake_amt := 0.0
var map_size := Vector2(1000, 800)
var focus := Vector2.ZERO      # (v0.24) a cinematic shift of the view (the boss's name card frames the boss)

func _ready() -> void:
	position = Vector2(0, -17)
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	Game.settings_changed.connect(_apply_zoom)

func set_map(sz: Vector2) -> void:
	map_size = sz
	look = Vector2.ZERO
	kick_k = 0.0
	_apply_zoom()
	reset_smoothing()

func _apply_zoom() -> void:
	var vis := get_viewport().get_visible_rect().size
	var z: float = Game.cam_zoom()
	z = max(z, vis.x / max(1.0, map_size.x), vis.y / max(1.0, map_size.y))
	zoom = Vector2(z, z)
	var v := vis / z
	limit_left = int(-v.x * float(APRON["l"]))
	limit_top = int(-v.y * float(APRON["t"]))
	limit_right = int(map_size.x + v.x * float(APRON["r"]))
	limit_bottom = int(map_size.y + v.y * float(APRON["b"]))

## a shove of the view along (dx, dy) that springs back (VIS.punch)
func punch(dir: Vector2, amount := 6.0) -> void:
	if not bool(Game.settings.get("shake", true)) or dir == Vector2.ZERO:
		return
	kick = dir.normalized() * amount
	kick_k = 1.0

## frame a point at once (the world may be paused): the view moves part of the way towards it
func frame(at: Vector2, k := 0.6) -> void:
	if hero == null:
		return
	focus = (at - hero.global_position) * k
	position = Vector2(0, -17) + look + focus
	reset_smoothing()
	force_update_scroll()

func unframe() -> void:
	focus = Vector2.ZERO

func shake(amount: float) -> void:
	if not bool(Game.settings.get("shake", true)):
		return
	shake_amt = max(shake_amt, amount)

func _corner_apron() -> void:
	if hero == null:
		return
	var v: Vector2 = get_viewport().get_visible_rect().size / max(0.01, zoom.x)
	var fx: float = 0.5 + (hero.global_position.x - get_screen_center_position().x) / max(1.0, v.x)
	var t: float = max(smoothstep(0.55, 0.68, fx), 1.0 - smoothstep(0.24, 0.38, fx))
	limit_bottom = int(map_size.y + v.y * (float(APRON["b"]) + CORNER_B * t))

func _physics_process(dt: float) -> void:
	if Engine.get_physics_frames() % 30 == 0:
		_apply_zoom()
	_corner_apron()
	var want := Vector2.ZERO
	if hero and hero.get("moving"):
		var f: Vector2 = hero.facing_vec()
		want = Vector2(f.x * 34.0, f.y * 28.0)
	look = look.lerp(want, 1.0 - exp(-dt * 2.6))
	if kick_k > 0.0:
		kick_k *= pow(0.86, dt * 60.0)
		if kick_k < 0.05:
			kick_k = 0.0
	var sh := Vector2.ZERO
	if shake_amt > 0.1:
		sh = Vector2(randf_range(-shake_amt, shake_amt), randf_range(-shake_amt, shake_amt))
		shake_amt = max(0.0, shake_amt - 40.0 * dt)
	# the look-ahead moves the camera itself, so the map limits still apply to it; punch and shake are
	# small offsets on top
	position = Vector2(0, -17) + look + focus
	offset = kick * kick_k + sh

extends Node2D
## (v0.20) Zabol's fountain (FOUNTAIN.json: x 452, y 432, r 40), on the cobbled ring in the middle of the village where
## the HTML game drew it in code. A round stone basin with its front wall, water that ripples and glints, a pillar with a
## bowl on top, four jets falling back into the basin, a quiet splash; a cool light at night and the sound of water close by.
## Resting by it restores health and mana and washes off poison, burns and frost. (The map already has its square wall.)
## Sits in the y-sort at the basin's front edge, so the hero walks behind it from the north and in front from the south.

const Tex = preload("res://scripts/fx/tex.gd")

var world: Node = null
var c := Vector2(452, 432)        # the basin's centre on the ground
var r := 40.0
var heal_r := 78.0                # the cobbled ring around it
var _t := 0.0
var _redraw := 0.0
var _told := false
var healing := false              # the hero is being restored now (tests read it)
var restored := 0.0               # health given back so far (tests)
var snd: AudioStreamPlayer2D
## the test runs start next to the fountain (the village start): it restores nobody there unless a test asks
static var in_tests := false

const STONE := Color(0.56, 0.53, 0.5)
const STONE_HI := Color(0.71, 0.68, 0.64)
const STONE_DK := Color(0.36, 0.34, 0.33)
const WATER := Color(0.22, 0.47, 0.66)
const WATER_HI := Color(0.55, 0.82, 0.95)

func setup(w: Node, d: Dictionary) -> void:
	world = w
	c = Vector2(float(d.get("x", 452)), float(d.get("y", 432)))
	r = float(d.get("r", 40))
	name = "Fountain"
	position = Vector2(c.x, c.y + r * 0.78)        # the front edge of the basin: the y-sort line
	w.ysort.add_child(self)
	if w.lighting:
		w.lighting.map_lights.append({"pos": c + Vector2(0, -22), "r": 120.0, "i": 0.55, "c": Color(0.55, 0.8, 1.0), "fire": false, "seed": 0.3})
	snd = AudioStreamPlayer2D.new()
	var s = load("res://assets/audio/amb/water.ogg")
	if s is AudioStreamOggVorbis:
		s.loop = true
		snd.stream = s
		snd.bus = "Ambience"
		snd.volume_db = -7.0
		snd.max_distance = 330.0
		snd.attenuation = 1.6
		add_child(snd)
		snd.play(randf() * 4.0)

func _process(dt: float) -> void:
	_t += dt
	_redraw -= dt
	if _redraw <= 0.0:
		_redraw = 1.0 / 24.0
		queue_redraw()
	_restore(dt)

## the hero on the cobbles round the basin: health and mana come back, statuses wash off
func _restore(dt: float) -> void:
	healing = false
	if Game.testing and not in_tests:
		return
	var hero = get_tree().get_first_node_in_group("player")
	if hero == null or hero.dead or hero.world != world:
		return
	if hero.global_position.distance_to(c + Vector2(0, 6)) > heal_r:
		_told = false
		return
	var full: bool = Game.hp >= Game.max_hp() and Game.mp >= Game.max_mp() and hero.statuses.is_empty()
	if full:
		return
	healing = true
	var add: float = min(Game.max_hp() - Game.hp, Game.max_hp() * 0.08 * dt)
	Game.hp += add
	restored += add
	Game.mp = min(Game.max_mp(), Game.mp + Game.max_mp() * 0.1 * dt)
	if not hero.statuses.is_empty():
		hero.clear_statuses()
	if Engine.get_process_frames() % 12 == 0:
		Game.stats_changed.emit()
		if world.fx:
			world.fx.emit("shine", hero.global_position + Vector2(randf_range(-8, 8), -8), 1, Color(0.6, 0.88, 1.0), Vector2.UP, 30.0, 40.0)
	if not _told:
		_told = true
		world.notice.emit(Game.t("The fountain's water restores you.", "آبِ چشمه جانت را برمی‌گرداند."), "droplets")

func _ell(center: Vector2, rx: float, ry: float, col: Color, n := 40) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

func _ring(center: Vector2, rx: float, ry: float, col: Color, w := 1.0, a0 := 0.0, a1 := TAU, n := 40) -> void:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, w, true)

func _draw() -> void:
	# everything is drawn from the basin's centre, lifted a little (local origin = the front edge)
	var o := Vector2(0, -r * 0.78 - 4.0)
	var rx := r
	var ry := r * 0.82
	var wall := 9.0
	# the shadow on the cobbles, the front wall (a band under the rim's lower half), its blocks
	_ell(o + Vector2(3, wall + 2), rx + 3, ry + 2, Color(0, 0, 0, 0.28))
	var front := PackedVector2Array()
	for i in 21:
		var a := PI * i / 20.0
		front.append(o + Vector2(cos(a) * rx, sin(a) * ry))
	for i in 21:
		var a := PI - PI * i / 20.0
		front.append(o + Vector2(cos(a) * rx, sin(a) * ry + wall))
	draw_colored_polygon(front, STONE_DK)
	for i in 9:
		var a := PI * (i + 0.5) / 9.0
		var p := o + Vector2(cos(a) * rx, sin(a) * ry)
		draw_line(p, p + Vector2(0, wall), Color(0.25, 0.23, 0.22, 0.8), 1.0)
	_ring(o + Vector2(0, wall * 0.5), rx, ry, Color(0.28, 0.26, 0.25, 0.6), 1.0, 0.15, PI - 0.15, 20)
	# the rim: a ring of pale stone blocks, the water inside it; dark outlines as on the game's sprites
	_ell(o, rx, ry, STONE)
	_ring(o, rx, ry, STONE_HI, 1.6, PI, TAU, 24)
	var wx := rx - 7.0
	var wy := ry - 6.0
	for i in 16:
		var a := TAU * (i + 0.5) / 16.0
		draw_line(o + Vector2(cos(a) * wx, sin(a) * wy), o + Vector2(cos(a) * rx, sin(a) * ry), Color(0.3, 0.28, 0.27, 0.7), 1.0)
	_ring(o, rx, ry, Color(0.13, 0.11, 0.1), 2.0)
	var base := PackedVector2Array()
	for i in 21:
		var a := PI * i / 20.0
		base.append(o + Vector2(cos(a) * rx, sin(a) * ry + wall))
	draw_polyline(base, Color(0.13, 0.11, 0.1), 2.0, true)
	draw_line(o + Vector2(-rx, 0), o + Vector2(-rx, wall), Color(0.13, 0.11, 0.1), 2.0)
	draw_line(o + Vector2(rx, 0), o + Vector2(rx, wall), Color(0.13, 0.11, 0.1), 2.0)
	_ell(o + Vector2(0, 1), wx, wy, Color(0.12, 0.28, 0.4))
	_ell(o + Vector2(0, 2.5), wx - 1.0, wy - 2.0, WATER)
	_ring(o + Vector2(0, 1), wx, wy, Color(0.1, 0.18, 0.25, 0.9), 1.2)
	# ripples run out from the pillar; glints drift on the surface
	for i in 3:
		var k := fmod(_t * 0.45 + i / 3.0, 1.0)
		var rr := lerpf(9.0, wx - 3.0, k)
		_ring(o + Vector2(0, 2), rr, rr * wy / wx, Color(WATER_HI, 0.45 * (1.0 - k)), 1.0)
	for i in 6:
		var a := _t * 0.35 + i * 1.7
		var d := (0.35 + 0.5 * fmod(i * 0.37, 1.0)) * wx
		var gp := o + Vector2(cos(a) * d, sin(a) * d * wy / wx + 2)
		var fl := 0.5 + 0.5 * sin(_t * 3.0 + i * 2.1)
		draw_line(gp - Vector2(2, 0), gp + Vector2(2, 0), Color(1, 1, 1, 0.55 * fl), 1.0)
	# the pillar and its bowl
	var top := o + Vector2(0, -34)
	draw_rect(Rect2(o.x - 5.5, top.y + 3, 11, 34), Color(0.13, 0.11, 0.1))
	draw_rect(Rect2(o.x - 4.5, top.y + 3, 9, 34), STONE_DK)
	draw_rect(Rect2(o.x - 4.5, top.y + 3, 3, 34), STONE_HI)
	_ell(o + Vector2(0, 2), 7.0, 3.0, Color(0.2, 0.2, 0.22, 0.6))
	_ell(top + Vector2(0, 4), 15.0, 6.5, Color(0.13, 0.11, 0.1))
	_ell(top + Vector2(0, 4), 14.0, 5.5, STONE_DK)
	_ell(top + Vector2(0, 2), 14.0, 5.0, STONE)
	_ell(top + Vector2(0, 2), 11.0, 3.6, WATER)
	_ring(top + Vector2(0, 2), 14.0, 5.0, STONE_HI, 1.2, PI, TAU, 16)
	draw_rect(Rect2(top.x - 2, top.y - 8, 4, 9), STONE_HI)
	# four jets arc from the bowl into the basin; droplets ride down each arc, a splash where they land
	# out to the left and right, and two toward the viewer that land lower in the basin
	var jets := [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(-0.5, 0.62), Vector2(0.5, 0.62)]
	for j in 4:
		var dv: Vector2 = jets[j]
		var reach := 22.0
		var drop := 26.0 + 16.0 * dv.y
		var start := top + Vector2(dv.x * 9.0, 1.0 + dv.y * 3.0)
		var pts := PackedVector2Array()
		for i in 13:
			var k := i / 12.0
			pts.append(start + Vector2(dv.x * reach * k, -6.0 * sin(k * PI) + drop * k * k))
		draw_polyline(pts, Color(0.75, 0.92, 1.0, 0.55), 2.0, true)
		draw_polyline(pts, Color(1, 1, 1, 0.35), 0.8, true)
		for m in 3:
			var k := fmod(_t * 1.6 + m / 3.0 + j * 0.13, 1.0)
			var dp := start + Vector2(dv.x * reach * k, -6.0 * sin(k * PI) + drop * k * k)
			draw_circle(dp, 1.3, Color(1, 1, 1, 0.8))
		var land := start + Vector2(dv.x * reach, drop)
		var sp := 0.5 + 0.5 * sin(_t * 9.0 + j * 1.3)
		_ring(land + Vector2(0, 1), 3.0 + sp * 2.0, 1.2 + sp * 0.8, Color(1, 1, 1, 0.5), 1.0)
	# a spout of water from the top
	var h := 5.0 + 1.5 * sin(_t * 7.0)
	draw_line(top + Vector2(0, -8), top + Vector2(0, -8 - h), Color(0.85, 0.95, 1.0, 0.7), 2.0)
	draw_circle(top + Vector2(0, -8 - h), 1.6, Color(1, 1, 1, 0.75))

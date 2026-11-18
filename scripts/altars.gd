extends Node2D
## (v0.23) The fire temple on the Slopes of Damavand (south-east): three altars (atashdan), cold for a thousand years.
## A blow strikes sparks into an altar's bowl (a plain blow 1, a heavy blow 2, a burning blade one more: three sparks
## light it); fire — a fire bolt, Ember Nova — lights it at once. A struck fire burns 6 s, a spell's fire 14 s. All three
## burning together: the temple's heart opens, its fires burn for good, and its chest (the banner's third jewel, gold,
## an epic accessory) can be opened. Saved in Game.state.c3: altars_lit, altars_done (the chest).

const Art = preload("res://scripts/fx/shrine_art.gd")
const Sheets = preload("res://scripts/sheets.gd")
const SPARKS := 3.0
const STRUCK_SEC := 6.0
const FIRE_SEC := 14.0

var world: Node = null
var altars: Array = []       # {pos, rect, heat, left, node, light}
var chest := {}              # {rect, node, seal}
var solved := false
var clock := 0.0
var _tip_t := 0.0

func setup(w: Node) -> void:
	world = w
	name = "Altars"
	var ch3: Dictionary = Game.map_data(str(w.key)).get("ch3", {})
	solved = bool(Game.Ch3.st().get("altars_lit", false))
	var i := 0
	for a in ch3.get("altars", []):
		var feet := Game._v(a)
		var n := Node2D.new()
		n.name = "Altar_%d" % i
		n.position = feet
		world.ysort.add_child(n)
		var m: Dictionary = Game.obj_sprites.get("brazier_61", {})
		if not m.is_empty():
			var spr := Sprite2D.new()
			spr.texture = load(Game.ART + "MapObjects/" + str(m.get("file", "brazier_61")) + ".png")
			spr.centered = false
			spr.offset = Vector2(-float(m["w"]) * 0.5, -float(m["h"]))
			spr.scale = Vector2.ONE * Sheets.SCALE * 1.45
			n.add_child(spr)
		# a ring of carved fire-signs on the floor round each altar: dim when cold, glowing when it burns
		var ring := Node2D.new()
		ring.position = feet
		ring.z_index = -1
		world.add_child(ring)
		var f := Node2D.new()
		f.z_index = 1
		n.add_child(f)
		var al := {"pos": feet, "rect": Rect2(feet - Vector2(20, 46), Vector2(40, 48)), "heat": 0.0, "left": 0.0, "node": f, "seed": float(i) * 1.7, "light": null, "ring": ring}
		f.draw.connect(_draw_altar.bind(al))
		ring.draw.connect(_draw_ring.bind(al))
		if world.lighting:
			var l := {"pos": feet + Vector2(0, -34), "r": 130.0, "i": 0.0, "c": Color(1, 0.62, 0.3), "fire": true, "seed": float(i)}
			world.lighting.map_lights.append(l)
			al["light"] = l
		altars.append(al)
		i += 1
	if ch3.has("chest"):
		var cp := Game._v(ch3["chest"])
		var cr := Rect2(cp - Vector2(15, 24), Vector2(30, 24))
		var cn := Node2D.new()
		cn.name = "TempleChest"
		cn.position = cp
		var tex = load(Game.ART + "Items/chest.png")
		if tex:
			var sp := Sprite2D.new()
			sp.texture = tex
			var sc: float = 34.0 / float(tex.get_width())
			sp.scale = Vector2(sc, sc)
			sp.centered = false
			sp.position = Vector2(-tex.get_width() * sc * 0.5, -tex.get_height() * sc + 2)
			cn.add_child(sp)
		var seal := Node2D.new()
		seal.z_index = 1
		cn.add_child(seal)
		seal.draw.connect(_draw_seal.bind(seal))
		world.ysort.add_child(cn)
		chest = {"rect": cr, "node": cn, "seal": seal}
		_chest_look()

func lit_count() -> int:
	var n := 0
	for a in altars:
		if solved or float(a["left"]) > 0.0:
			n += 1
	return n

func is_open() -> bool:
	return bool(Game.Ch3.st().get("altars_done", false))

## a blow from the hero's swing: sparks in the bowl
func strike(box: Rect2, _fv: Vector2, heavy: bool) -> void:
	if solved:
		return
	for a in altars:
		if not a["rect"].grow(8.0).intersects(box):
			continue
		if float(a["left"]) > 0.0:
			a["left"] = max(float(a["left"]), STRUCK_SEC)      # fanned: it burns on
			continue
		# a burning blade (weapon tier 3 and up) throws one spark more
		a["heat"] = float(a["heat"]) + (2.0 if heavy else 1.0) + (1.0 if int(Game.state.get("weapon", 1)) >= 3 else 0.0)
		Sfx.play("clank", -6.0, 0.12)
		if world.fx:
			world.fx.sparks(a["pos"] + Vector2(0, -44), 7, Color(1, 0.75, 0.35))
		if float(a["heat"]) >= SPARKS:
			light(a, STRUCK_SEC)
		elif _tip_t <= 0.0:
			_tip_t = 3.0
			world.float_text(a["pos"] + Vector2(0, -66), Game.Ch3.line("t_altar_cold"), Color(1, 0.8, 0.55))

## a spell's fire at p within r
func element(p: Vector2, r: float, status: String) -> void:
	if status != "burn" or solved:
		return
	for a in altars:
		if (a["pos"] + Vector2(0, -20)).distance_to(p) <= r + 22.0:
			light(a, FIRE_SEC)

## a spell shot at p: the altars stop it (fire lights them)
func shot_at(p: Vector2, status: String) -> bool:
	for a in altars:
		if a["rect"].has_point(p):
			if status == "burn" and not solved:
				light(a, FIRE_SEC)
			return true
	return false

func light(a: Dictionary, sec: float) -> void:
	var was := float(a["left"]) > 0.0
	a["left"] = max(float(a["left"]), sec)
	a["heat"] = 0.0
	if was:
		return
	Sfx.play("nova", -8.0)
	if world.fx:
		world.fx.embers(a["pos"] + Vector2(0, -34), 10)
		world.fx.flash_light(a["pos"] + Vector2(0, -34), 140.0, 0.9, Color(1, 0.7, 0.35), 0.4)
	var n := lit_count()
	if n >= altars.size():
		_solve()
	else:
		world.notice.emit(Game.Ch3.fmt("t_altar", [n]), "flame")

func _solve() -> void:
	solved = true
	Game.Ch3.st()["altars_lit"] = true
	Game.Ach.unlock("altars")
	Game.save_game()
	Sfx.play("phase", -2.0)
	Sfx.play("latch")
	world.shake(6.0)
	for a in altars:
		if world.fx:
			world.fx.emit("shine", a["pos"] + Vector2(0, -30), 16, Color(1, 0.8, 0.4), Vector2.UP, 40.0, 160.0)
	if not chest.is_empty() and world.fx:
		world.fx.ring(chest["rect"].get_center(), Color(1, 0.8, 0.4), 60.0, 0.8)
		world.fx.flash_light(chest["rect"].get_center(), 220.0, 1.0, Color(1, 0.75, 0.4), 0.9)
	world.notice.emit(Game.Ch3.line("t_temple"), "flame")
	_chest_look()

func _process(dt: float) -> void:
	clock += dt
	_tip_t = max(0.0, _tip_t - dt)
	for a in altars:
		if not solved and float(a["left"]) > 0.0:
			a["left"] = float(a["left"]) - dt
			if float(a["left"]) <= 0.0:
				a["left"] = 0.0
				Sfx.play("poof", -6.0)
				if world.fx:
					world.fx.smoke(a["pos"] + Vector2(0, -34), 6)
				world.float_text(a["pos"] + Vector2(0, -56), Game.Ch3.line("t_altar_out"), Color(0.8, 0.75, 0.7))
		if a["light"] != null:
			a["light"]["i"] = 0.85 if (solved or float(a["left"]) > 0.0) else 0.0
		a["node"].queue_redraw()
		a["ring"].queue_redraw()
	if not chest.is_empty():
		chest["seal"].queue_redraw()
	if chest.is_empty() or not solved or is_open():
		return
	var p = get_tree().get_first_node_in_group("player")
	if p == null or p.dead or p.world != world:
		return
	if p.global_position.distance_to(chest["rect"].get_center() + Vector2(0, 8)) < 34.0:
		open_chest()

func open_chest() -> void:
	if is_open() or not solved:
		return
	for line in Game.Ch3.temple_open():
		world.notice.emit(line, "gem")
	Sfx.play("chest")
	Sfx.play("found")
	if world.fx:
		var c: Vector2 = chest["rect"].get_center()
		world.fx.emit("shine", c, 24, Color(1, 0.85, 0.5), Vector2.UP, 60.0, 150.0)
	_chest_look()
	Game.stats_changed.emit()

func _chest_look() -> void:
	if chest.is_empty():
		return
	chest["node"].modulate = Color(0.62, 0.6, 0.58) if is_open() else Color(1, 1, 1)

func _draw_altar(a: Dictionary) -> void:
	var f: Node2D = a["node"]
	var burning: bool = solved or float(a["left"]) > 0.0
	if burning:
		var left_k: float = -1.0 if solved else clamp(float(a["left"]) / (FIRE_SEC if float(a["left"]) > STRUCK_SEC else STRUCK_SEC), 0.0, 1.0)
		f.position = Vector2.ZERO
		_flame(f, Vector2(0, -44), clock, float(a["seed"]))
		if left_k >= 0.0:
			f.draw_arc(Vector2(0, -40), 24.0, -PI * 0.5, -PI * 0.5 + TAU * left_k, 32, Color(1, 0.75, 0.3, 0.9), 3.0, true)
	else:
		f.position = Vector2.ZERO
		# embers in the bowl: one glow per spark
		for i in int(a["heat"]):
			f.draw_circle(Vector2(-6 + i * 6, -47), 2.5, Color(1, 0.55 + 0.1 * sin(clock * 9.0 + i), 0.2, 0.9))

## a flame in the altar's bowl: three layers (red, orange, a pale core) that flicker and sway, over a soft glow
func _flame(ci: CanvasItem, base: Vector2, t: float, seed: float) -> void:
	var flick := 1.0 + 0.12 * sin(t * 13.0 + seed) + 0.08 * sin(t * 21.0 + seed * 2.0)
	ci.draw_circle(base + Vector2(0, -8), 18.0, Color(1, 0.55, 0.2, 0.16))
	ci.draw_circle(base + Vector2(0, -6), 11.0, Color(1, 0.6, 0.25, 0.2))
	var layers := [[11.0, 26.0, Color(0.92, 0.3, 0.08, 0.92)], [7.5, 18.0, Color(1, 0.62, 0.18, 0.95)], [4.0, 10.0, Color(1, 0.93, 0.62)]]
	for i in layers.size():
		var w: float = layers[i][0]
		var h: float = float(layers[i][1]) * flick
		var sway := sin(t * 6.0 + seed + i) * (2.8 - i * 0.6)
		var pts := PackedVector2Array([base + Vector2(-w, 0), base + Vector2(-w * 0.62 + sway * 0.3, -h * 0.45), base + Vector2(sway, -h),
			base + Vector2(w * 0.62 + sway * 0.3, -h * 0.45), base + Vector2(w, 0), base + Vector2(0, w * 0.45)])
		ci.draw_colored_polygon(pts, layers[i][2])

func _draw_ring(a: Dictionary) -> void:
	var n: Node2D = a["ring"]
	var burning: bool = solved or float(a["left"]) > 0.0
	var k := 0.75 + 0.25 * sin(clock * 3.0 + float(a["seed"]))
	var col := Color(1, 0.6, 0.25, 0.75 * k) if burning else Color(0.55, 0.45, 0.4, 0.45)
	n.draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.45))
	n.draw_arc(Vector2.ZERO, 34.0, 0, TAU, 40, col, 3.0, true)
	n.draw_arc(Vector2.ZERO, 27.0, 0, TAU, 40, Color(col, col.a * 0.5), 1.5, true)
	for i in 6:
		var ang := float(i) / 6.0 * TAU + 0.3
		var p := Vector2.from_angle(ang) * 30.5
		n.draw_circle(p, 3.0, col)
	n.draw_set_transform(Vector2.ZERO)

## the temple's fire-seal over the chest until the three fires burn together
func _draw_seal(n: Node2D) -> void:
	if solved:
		return
	var c := Vector2(0, -12)
	var k := 0.6 + 0.2 * sin(clock * 2.0)
	n.draw_arc(c, 24.0, 0, TAU, 40, Color(1, 0.55, 0.25, 0.55 * k), 2.5, true)
	for i in 3:
		var ang := -PI * 0.5 + i * TAU / 3.0 + clock * 0.4
		var p := c + Vector2.from_angle(ang) * 24.0
		var on := i < lit_count()
		n.draw_circle(p, 4.5, Color(1, 0.7, 0.3, 0.95) if on else Color(0.35, 0.3, 0.28, 0.9))

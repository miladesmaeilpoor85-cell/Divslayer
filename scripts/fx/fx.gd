extends Node2D
## World effects in one place (port of the HTML VIS particle engine, v9 "visual overhaul"):
## pooled native particle emitters for sparks, debris, dust, smoke and embers (no node is created per
## hit), expanding shock rings, weapon swing arcs, dodge afterimages, short-lived light flashes for the
## lighting pass, and the soft contact shadows under every character.
## Glowing kinds (sparks, shine, embers) draw additively on an overlay layer above the lighting, so they
## stay bright in a dark crypt; dust, smoke and debris live in the world and darken with it.
## Damage numbers also go on the overlay so they are always readable.

const Tex = preload("res://scripts/fx/tex.gd")

## kind: texture, additive, pool size, lifetime, gravity (px/s²), damping, scale range, grow, align to velocity
const KIND := {
	"spark": {"tex": "streak", "glow": true, "pool": 10, "life": 0.34, "grav": 240.0, "damp": 260.0, "s": [0.5, 0.85], "align": true},
	"shine": {"tex": "dot", "glow": true, "pool": 10, "life": 0.55, "grav": 160.0, "damp": 70.0, "s": [0.16, 0.34]},
	"debris": {"tex": "pip", "glow": false, "pool": 10, "life": 0.5, "grav": 320.0, "damp": 50.0, "s": [0.22, 0.42]},
	"dust": {"tex": "dot", "glow": false, "pool": 8, "life": 0.45, "grav": 20.0, "damp": 140.0, "s": [0.26, 0.48], "grow": true},
	"smoke": {"tex": "dot", "glow": false, "pool": 10, "life": 1.3, "grav": -26.0, "damp": 30.0, "s": [0.45, 0.85], "grow": true},
	"ember": {"tex": "dot", "glow": true, "pool": 8, "life": 1.1, "grav": -60.0, "damp": 12.0, "s": [0.09, 0.2]},
}
## swing trail colours by weapon tier (fists .. Frostreaver)
const SWING_COL := [Color(1, 0.96, 0.86), Color(1, 0.96, 0.86), Color(0.93, 0.96, 1.0), Color(0.68, 0.94, 1.0),
	Color(1, 0.74, 0.44), Color(1, 0.56, 0.22), Color(0.62, 0.86, 1.0)]
const CLASS_SWING_COL := {
	"mage": Color(0.30, 0.84, 0.96),
	"rogue": Color(0.48, 0.84, 0.57),
	"paladin": Color(1.0, 0.82, 0.38),
}

var world: Node = null
var overlay: CanvasLayer
var glow_root: Node2D
var arcs: Node2D
var texts: Node2D
var pools := {}
var _next := {}
var rings: Array = []          # {pos, col, r, t, life}
var dashes: Array = []         # short directional energy trails from dodge rolls
var swings: Array = []         # {who, ang, t, dur, r, col, heavy}
var windups: Array = []        # short, class-specific pre-contact cues: {who, dir, class, t, dur, heavy}
var lights: Array = []         # timed light flashes read by the lighting pass: {pos, r, i, c, t, life}
var quality := 1               # 0 low (fewer particles) / 1 high
var _drew := false

func setup(w: Node) -> void:
	world = w
	name = "Fx"
	z_index = 44
	quality = int(Game.settings.get("fx", 1))
	overlay = CanvasLayer.new()
	overlay.name = "Overlay"
	overlay.layer = 3
	overlay.follow_viewport_enabled = true
	add_child(overlay)
	glow_root = Node2D.new()
	glow_root.name = "Glow"
	overlay.add_child(glow_root)
	arcs = Node2D.new()
	arcs.name = "Arcs"
	arcs.draw.connect(_draw_arcs)
	overlay.add_child(arcs)
	texts = Node2D.new()
	texts.name = "Texts"
	overlay.add_child(texts)
	for k in KIND:
		var d: Dictionary = KIND[k]
		var arr: Array = []
		for i in int(d["pool"]):
			arr.append(_make(k, d))
		pools[k] = arr
		_next[k] = 0

func _make(kind: String, d: Dictionary) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = kind
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.amount = 8
	p.lifetime = float(d["life"])
	p.lifetime_randomness = 0.45
	match str(d["tex"]):
		"streak": p.texture = Tex.streak()
		"pip": p.texture = Tex.pip()
		_: p.texture = Tex.dot()
	p.gravity = Vector2(0, float(d["grav"]))
	p.damping_min = float(d["damp"]) * 0.6
	p.damping_max = float(d["damp"])
	p.scale_amount_min = float(d["s"][0])
	p.scale_amount_max = float(d["s"][1])
	if d.get("grow", false):
		p.scale_amount_curve = Tex.curve([[0.0, 0.55], [1.0, 1.0]])
	else:
		p.scale_amount_curve = Tex.curve([[0.0, 1.0], [1.0, 0.35]])
	p.color_ramp = Tex.fade_ramp(0.35 if kind == "smoke" else 0.0)
	p.particle_flag_align_y = d.get("align", false)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 3.0
	if d["glow"]:
		p.material = Tex.add_material()
		glow_root.add_child(p)
	else:
		add_child(p)
	return p

# ---------------------------------------------------------------- particles
## n particles of `kind` at `pos` (world): colour, direction (zero = all round), spread in degrees,
## speed (px/s) and a size multiplier
func emit(kind: String, pos: Vector2, n: int, col: Color, dir := Vector2.ZERO, spread := 180.0, speed := 120.0, size := 1.0) -> void:
	if not pools.has(kind) or n <= 0:
		return
	if quality == 0:
		n = int(ceil(n * 0.5))
	var arr: Array = pools[kind]
	var i: int = _next[kind]
	_next[kind] = (i + 1) % arr.size()
	var p: CPUParticles2D = arr[i]
	p.global_position = pos
	if p.amount != n:
		p.amount = n
	p.color = col
	p.direction = dir.normalized() if dir != Vector2.ZERO else Vector2.UP
	p.spread = spread if dir != Vector2.ZERO else 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	var d: Dictionary = KIND[kind]
	p.scale_amount_min = float(d["s"][0]) * size
	p.scale_amount_max = float(d["s"][1]) * size
	p.restart()

## the classic burst: glowing motes for bright colours, falling debris for dull ones
func burst(pos: Vector2, col: Color, n := 10, speed := 120.0) -> void:
	if col.v > 0.72 and (col.s > 0.22 or col.v > 0.93):
		emit("shine", pos, n, col, Vector2.ZERO, 180.0, speed)
	else:
		emit("debris", pos, n, col, Vector2.ZERO, 180.0, speed)

## hit sparks: streaks flying away from the blow (dir), brighter and more for crits
func sparks(pos: Vector2, n: int, col: Color, dir := Vector2.ZERO) -> void:
	emit("spark", pos, n, col, dir, 55.0 if dir != Vector2.ZERO else 180.0, 420.0)

## footfall and landing dust; dir = where it blows
func dust(pos: Vector2, n := 3, dir := Vector2.ZERO, col := Color(0.62, 0.56, 0.47, 0.55)) -> void:
	emit("dust", pos, n, col, dir, 60.0, 55.0)

func smoke(pos: Vector2, n := 4, col := Color(0.6, 0.56, 0.52, 0.5), size := 1.0) -> void:
	emit("smoke", pos, n, col, Vector2.UP, 35.0, 26.0, size)

func embers(pos: Vector2, n := 4, col := Color(1, 0.6, 0.25)) -> void:
	emit("ember", pos, n, col, Vector2.UP, 40.0, 45.0)

# ---------------------------------------------------------------- rings, swings, flashes
func ring(pos: Vector2, col: Color, r := 20.0, life := 0.32) -> void:
	rings.append({"pos": pos, "col": col, "r": r, "t": life, "life": life})
	if rings.size() > 24:
		rings.pop_front()

## a weapon arc that follows `who` (the hero) for its short life (VIS.drawSwings)
func swing(who: Node2D, dir: Vector2, reach: float, heavy := false, tier := 1) -> void:
	var hero_class := str(Game.cls)
	var col: Color = SWING_COL[clampi(tier, 0, SWING_COL.size() - 1)]
	if CLASS_SWING_COL.has(hero_class):
		col = Color(CLASS_SWING_COL[hero_class]).lerp(col, 0.24)
	if heavy:
		col = col.lerp(Color(1, 0.62, 0.3), 0.55)
	swings.append({"who": who, "ang": dir.angle(), "t": 0.0, "dur": 0.26 if heavy else 0.22,
		"r": max(36.0, reach + (16.0 if heavy else 10.0)), "col": col, "heavy": heavy, "class": hero_class})
	if swings.size() > 4:
		swings.pop_front()

## A brief anticipation cue, played at attack start before the contact-frame hit is resolved.
## It only draws presentation effects; it never changes attack reach, damage, or timing.
func attack_windup(who: Node2D, dir: Vector2, hero_class: String, heavy := false) -> void:
	if not is_instance_valid(who) or dir.length_squared() < 0.0001:
		return
	var forward := dir.normalized()
	var side := forward.orthogonal()
	var duration := 0.20 if heavy else 0.12
	windups.append({
		"who": who,
		"dir": forward,
		"class": hero_class,
		"t": 0.0,
		"dur": duration,
		"heavy": heavy,
	})
	if windups.size() > 8:
		windups.pop_front()
	var anchor := who.global_position + Vector2(0, -17) + forward * (10.0 if heavy else 7.0)
	match hero_class:
		"mage":
			var col := Color(0.30, 0.84, 0.96)
			ring(anchor, col, 12.0 if heavy else 8.0, duration + 0.04)
			emit("shine", anchor, 5 if heavy else 3, col, forward, 42.0, 58.0, 0.55)
		"rogue":
			var col := Color(0.48, 0.84, 0.57, 0.78)
			dash_trail(anchor + side * 4.0, forward, col, duration, 30.0 if heavy else 22.0)
			dash_trail(anchor - side * 4.0, forward, col, duration, 30.0 if heavy else 22.0)
		"paladin":
			var col := Color(1.0, 0.82, 0.38)
			ring(anchor, col, 14.0 if heavy else 10.0, duration + 0.06)
			emit("shine", anchor, 5 if heavy else 3, col, Vector2.UP, 32.0, 62.0, 0.6)
		_:
			dust(anchor, 3 if heavy else 2, -forward, Color(0.62, 0.49, 0.34, 0.55))
	arcs.queue_redraw()

## Remove a still-active anticipation cue when the owning attack is interrupted.
func cancel_attack_windup(who: Node2D) -> void:
	windups = windups.filter(func(p): return is_instance_valid(p.get("who")) and p.get("who") != who)
	if is_instance_valid(arcs):
		arcs.queue_redraw()

## A small, class-specific contact response. Pure presentation: it never changes damage or hit geometry.
func class_impact(pos: Vector2, dir: Vector2, hero_class: String, heavy := false) -> void:
	var forward := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	var count := 9 if heavy else 6
	match hero_class:
		"mage":
			var col := Color(0.30, 0.84, 0.96)
			ring(pos, col, 16.0 if heavy else 11.0, 0.30)
			emit("shine", pos, count, col, forward, 100.0, 145.0, 0.9 if not heavy else 1.15)
			flash_light(pos, 64.0 if heavy else 46.0, 0.28 if heavy else 0.20, col, 0.22)
		"rogue":
			var col := Color(0.48, 0.84, 0.57)
			ring(pos, col, 10.0 if heavy else 7.0, 0.19)
			sparks(pos, count + 1, col, forward)
		"paladin":
			var col := Color(1.0, 0.82, 0.38)
			ring(pos, col, 18.0 if heavy else 13.0, 0.32)
			ring(pos, Color(1.0, 0.94, 0.68), 30.0 if heavy else 22.0, 0.25)
			emit("shine", pos, count, col, Vector2.UP, 80.0, 105.0, 1.0 if not heavy else 1.25)
			flash_light(pos, 76.0 if heavy else 56.0, 0.32 if heavy else 0.22, col, 0.24)
		_:
			var col := Color(0.86, 0.63, 0.36)
			ring(pos, col, 12.0 if heavy else 8.0, 0.22)
			dust(pos, 5 if heavy else 3, -forward, Color(0.62, 0.49, 0.34, 0.62))
			sparks(pos, count, col, forward)

## a light that flares and fades (crits, explosions, level-ups): read by the lighting pass
func flash_light(pos: Vector2, r: float, i: float, col: Color, life := 0.3) -> void:
	lights.append({"pos": pos, "r": r, "i": i, "c": col, "t": life, "life": life})
	if lights.size() > 12:
		lights.pop_front()

## an afterimage of an animated sprite (the dodge roll)
func ghost(spr: AnimatedSprite2D, tint := Color(0.62, 0.86, 1.0, 0.5), life := 0.28) -> void:
	if spr == null or spr.sprite_frames == null or world == null:
		return
	var tex: Texture2D = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	if tex == null:
		return
	var g := Sprite2D.new()
	g.texture = tex
	g.centered = false
	g.offset = spr.offset
	g.flip_h = spr.flip_h
	g.global_transform = spr.global_transform
	g.material = spr.material          # (v0.20) the hero's look
	g.modulate = tint
	g.z_index = -1
	world.ysort.add_child(g)
	g.global_transform = spr.global_transform
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, life)
	tw.tween_callback(g.queue_free)

## a short directional wind-cut trail emitted along a dodge roll; kept as lightweight draw data.
func dash_trail(pos: Vector2, dir: Vector2, col: Color, life := 0.18, length := 38.0) -> void:
	if dir.length_squared() < 0.0001 or life <= 0.0:
		return
	dashes.append({"pos": pos, "dir": dir.normalized(), "col": col, "t": life, "life": life, "length": length})
	if dashes.size() > 14:
		dashes.pop_front()

## a soft contact shadow under `node` (VIS.shadow): an ellipse w×h·0.32, drawn under every character
static func shadow_for(node: Node2D, w: float, h: float, alpha := 0.34) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = "Shadow"
	s.texture = Tex.shadow()
	s.z_as_relative = false
	s.z_index = -6
	var rw: float = clamp(w * 1.05, 16.0, 170.0)
	var rh: float = clamp(h * 0.34 + 4.0, 7.0, 50.0)
	s.scale = Vector2(rw / 64.0, rh / 64.0)
	s.position = Vector2(0, -1)
	s.modulate.a = alpha
	s.set_meta("base_scale", s.scale)
	s.set_meta("alpha", alpha)
	node.add_child(s)
	return s

## lift a shadow (hovering, leaping): it shrinks and fades
static func lift_shadow(s: Sprite2D, lift: float) -> void:
	if s == null:
		return
	var k: float = 1.0 - min(0.75, lift / 70.0)
	s.scale = Vector2(s.get_meta("base_scale")) * k
	s.modulate.a = float(s.get_meta("alpha")) * k

# ---------------------------------------------------------------- per frame
func _process(dt: float) -> void:
	for r in rings:
		r["t"] = float(r["t"]) - dt
	rings = rings.filter(func(r): return float(r["t"]) > 0.0)
	for s in swings:
		s["t"] = float(s["t"]) + dt
	swings = swings.filter(func(s): return float(s["t"]) < float(s["dur"]) and is_instance_valid(s["who"]))
	for p in windups:
		p["t"] = float(p["t"]) + dt
	windups = windups.filter(func(p): return float(p["t"]) < float(p["dur"]) and is_instance_valid(p["who"]))
	for l in lights:
		l["t"] = float(l["t"]) - dt
	lights = lights.filter(func(l): return float(l["t"]) > 0.0)
	for d in dashes:
		d["t"] = float(d["t"]) - dt
	dashes = dashes.filter(func(d): return float(d["t"]) > 0.0)
	if not rings.is_empty() or not swings.is_empty() or not windups.is_empty() or not dashes.is_empty() or _drew:
		arcs.queue_redraw()
	_drew = not rings.is_empty() or not swings.is_empty() or not windups.is_empty() or not dashes.is_empty()

func _draw_arcs() -> void:
	for r in rings:
		var k: float = float(r["t"]) / float(r["life"])
		var c: Color = r["col"]
		arcs.draw_arc(r["pos"], float(r["r"]) * (1.6 - k * 0.6), 0, TAU, 40, Color(c, 0.6 * k), 1.0 + 3.0 * k, true)
	for prep in windups:
		_draw_attack_windup(prep)
	for d in dashes:
		var k: float = clampf(float(d["t"]) / float(d["life"]), 0.0, 1.0)
		var dir: Vector2 = d["dir"]
		var side := dir.orthogonal()
		var at: Vector2 = d["pos"]
		var tail: Vector2 = at - dir * float(d["length"]) * (0.45 + 0.55 * k)
		var head: Vector2 = at + dir * 7.0 * (1.0 - k)
		var col: Color = d["col"]
		var fade: float = k * k
		arcs.draw_line(tail, head, Color(col, 0.2 * fade), 7.0 * fade + 0.5, true)
		arcs.draw_line(tail + side * 4.0, head + side * 2.0, Color(col, 0.34 * fade), 1.8 * fade + 0.4, true)
		arcs.draw_line(tail - side * 4.0, head - side * 2.0, Color(col, 0.34 * fade), 1.8 * fade + 0.4, true)
	for s in swings:
		_draw_swing(s)

## A small telegraph drawn just ahead of the hero's weapon hand.
## The three classes get deliberately different silhouettes, even before their contact effects.
func _draw_attack_windup(prep: Dictionary) -> void:
	var who: Node2D = prep.get("who")
	if not is_instance_valid(who):
		return
	var duration := maxf(float(prep.get("dur", 0.12)), 0.001)
	var progress := clampf(float(prep.get("t", 0.0)) / duration, 0.0, 1.0)
	var fade := 1.0 - progress
	var dir: Vector2 = prep.get("dir", Vector2.RIGHT)
	var side := dir.orthogonal()
	var heavy := bool(prep.get("heavy", false))
	var hero_class := str(prep.get("class", "warrior"))
	var anchor := who.global_position + Vector2(0, -17) + dir * (10.0 if heavy else 7.0)
	var col := Color(0.86, 0.63, 0.36)
	match hero_class:
		"mage":
			col = Color(0.30, 0.84, 0.96)
			var phase := progress * TAU
			var radius := 5.0 + progress * (4.0 if heavy else 2.0)
			arcs.draw_arc(anchor, radius, dir.angle() - 0.95, dir.angle() + 0.95, 16,
				Color(col, 0.68 * fade), 1.6 if heavy else 1.2, true)
			for rune in range(3):
				var angle := phase + TAU * float(rune) / 3.0
				var rune_pos := anchor + Vector2.from_angle(angle) * (radius + 2.0)
				arcs.draw_circle(rune_pos, 1.35, Color(0.84, 0.98, 1.0, 0.82 * fade))
		"rogue":
			col = Color(0.48, 0.84, 0.57)
			for hand in [-1.0, 1.0]:
				var start := anchor + side * hand * 3.5 - dir * (5.0 + progress * 3.0)
				var finish := anchor + side * hand * (5.5 + progress * 1.5) + dir * (8.0 + progress * 11.0)
				arcs.draw_line(start, finish, Color(col, 0.82 * fade), 2.0 if heavy else 1.25, true)
				arcs.draw_line(start + side * hand * 2.0, finish + side * hand * 2.0,
					Color(col, 0.28 * fade), 0.8, true)
		"paladin":
			col = Color(1.0, 0.82, 0.38)
			var radius := 10.0 + progress * (5.0 if heavy else 3.0)
			arcs.draw_arc(anchor, radius, dir.angle() - 0.92, dir.angle() + 0.92, 20,
				Color(col, 0.74 * fade), 2.0 if heavy else 1.4, true)
			for ray in range(3):
				var angle := dir.angle() + (float(ray) - 1.0) * 0.38
				var ray_dir := Vector2.from_angle(angle)
				arcs.draw_line(anchor + ray_dir * radius,
					anchor + ray_dir * (radius + 4.0 * fade), Color(1.0, 0.95, 0.70, 0.72 * fade), 1.2, true)
		_:
			arcs.draw_arc(anchor, 6.0 + progress * 3.0, dir.angle() - 0.7, dir.angle() + 0.7, 14,
				Color(col, 0.52 * fade), 1.1, true)

## a crescent that sweeps 115° across the facing direction, thick and bright at its head (VIS.drawSwings)
func _draw_swing(s: Dictionary) -> void:
	var who: Node2D = s["who"]
	var c: Vector2 = who.global_position + Vector2(0, -17)
	var p: float = float(s["t"]) / float(s["dur"])
	var hero_class := str(s.get("class", "warrior"))
	var sweep := 2.0 if not s["heavy"] else 2.6
	match hero_class:
		"mage":
			sweep = 2.35 if not s["heavy"] else 2.75
		"rogue":
			sweep = 1.8 if not s["heavy"] else 2.15
		"paladin":
			sweep = 2.1 if not s["heavy"] else 2.45
	var head: float = float(s["ang"]) - sweep * 0.5 + sweep * ease(p, 0.45)
	var tail: float = head - (1.0 if hero_class == "rogue" else 1.1)
	var rad: float = float(s["r"])
	var class_width := 0.72 if hero_class == "rogue" else (1.08 if hero_class == "paladin" else 1.0)
	var wmax: float = ((17.0 if s["heavy"] else 13.0) * class_width) * (1.0 - p * 0.6) + 2.0
	var col: Color = s["col"]
	var a0: float = 0.95 * (1.0 - p * p)
	var fade := 1.0 - p
	# A soft outer bloom separates the blade trail from busy or dark backgrounds.
	arcs.draw_arc(c, rad + wmax * 0.08, tail - 0.24, head + 0.08, 28,
		Color(col, 0.16 * fade), max(2.0, wmax * (1.05 if s["heavy"] else 0.82)), true)
	var n := 20
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var co := PackedColorArray()
	var ci := PackedColorArray()
	for i in n + 1:
		var u := float(i) / n
		var a: float = lerp(tail, head, u)
		var w: float = max(0.8, wmax * sin(clamp(u * 1.15, 0.0, 1.0) * PI * 0.5) * (1.0 - max(0.0, u - 0.9) * 6.0))
		var dirv := Vector2.from_angle(a)
		outer.append(c + dirv * (rad + w * 0.5))
		inner.append(c + dirv * (rad - w * 0.5))
		var cc := Color(col, a0 * pow(u, 1.4))
		co.append(cc)
		ci.append(Color(col, a0 * pow(u, 1.4) * 0.35))
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.append_array(outer)
	cols.append_array(co)
	for i in range(n, -1, -1):
		pts.append(inner[i])
		cols.append(ci[i])
	arcs.draw_polygon(pts, cols)
	# A bright inner filament makes the crescent read as a polished blade, not a flat wedge.
	arcs.draw_arc(c, rad * 0.84, tail - 0.05, head - 0.08, 24,
		Color(1.0, 0.94, 0.78, 0.34 * fade), 1.35, true)
	# Rogue's paired daggers leave a second, slimmer cut; it stays offset from the first edge.
	if hero_class == "rogue":
		arcs.draw_arc(c, rad + 7.0, tail - 0.32, head - 0.24, 20,
			Color(col, 0.48 * fade), max(1.0, wmax * 0.20), true)
	# Mage's strike carries five small star-map ticks along the arc, not a full-screen glow.
	elif hero_class == "mage":
		for tick in 5:
			var u := (float(tick) + 1.0) / 6.0
			var angle: float = lerp(tail, head, u)
			var radial := Vector2.from_angle(angle)
			var tangent_tick := radial.orthogonal()
			var anchor := c + radial * (rad + wmax * 0.22)
			arcs.draw_line(anchor - tangent_tick * 2.0, anchor + tangent_tick * 2.0,
				Color(0.78, 0.98, 1.0, 0.5 * fade), 1.0, true)
	var tip_dir := Vector2.from_angle(head)
	var tip := c + tip_dir * (rad + wmax * 0.24)
	var tangent := Vector2(-tip_dir.y, tip_dir.x)
	var glint := 0.88 * fade
	arcs.draw_circle(tip, 2.8 if s["heavy"] else 2.0, Color(1.0, 0.98, 0.86, glint))
	arcs.draw_line(tip - tangent * (6.0 if s["heavy"] else 4.0),
		tip + tangent * (6.0 if s["heavy"] else 4.0), Color(1, 1, 1, 0.72 * glint), 1.5, true)
	if hero_class == "paladin":
		# A restrained solar flare distinguishes the Farrah-aligned guard class from raw steel.
		for ray in 5:
			var angle := head + (float(ray) - 2.0) * 0.16
			var ray_dir := Vector2.from_angle(angle)
			var ray_start := c + ray_dir * (rad + wmax * 0.35)
			arcs.draw_line(ray_start, ray_start + ray_dir * (4.0 + 2.0 * fade),
				Color(1.0, 0.88, 0.52, 0.48 * fade), 1.2, true)
	if s["heavy"]:
		for i in 2:
			var back := tip - tip_dir * (10.0 + float(i) * 5.0)
			var half := 2.5 - float(i) * 0.5
			arcs.draw_line(back - tangent * half, back + tangent * half,
				Color(col, 0.62 * glint), 2.0, true)
	# A white-hot edge along the leading part, and a faint second arc inside.
	arcs.draw_arc(c, rad + wmax * 0.3, head - 0.55, head, 10, Color(1, 1, 1, 0.85 * fade), 2.0, true)
	arcs.draw_arc(c, rad * 0.68, tail - 0.2, head + 0.1, 16, Color(col, 0.3 * fade), 2.0, true)

extends Node2D
## The hero's spells in the world (v0.6): projectiles (Arcane Bolt, Ice Lance, Emberwall), lightning arcs
## (Chain Lightning), drain tethers, the mage's meteors and the paladin's pillar of light.
## One node per map, drawn additively on the effects overlay (above the darkness, like hit sparks);
## everything is plain data in arrays, no node per shot. Damage goes through the hero's caster.

const Tex = preload("res://scripts/fx/tex.gd")

var world: Node = null
var caster: Node = null          # the hero's caster (deals the damage, fills the meter)
var shots: Array = []            # {id, p, v, left, dmg, col, size, pierce, hit, status, sec, trail}
var arcs: Array = []             # {pts, t, life, col, w}
var meteors: Array = []          # {p, t, warn, dmg, r, fall}
var pillars: Array = []          # {p, t, life, col, r}
var tethers: Array = []          # {a, b, t, life, col}
var blasts: Array = []           # {p, r, t, life, col}: an expanding ring of fire, stone or light on the ground
var ground: Node2D               # telegraph circles, drawn under the glow (normal blend)

func setup(w: Node, parent: Node) -> void:
	world = w
	name = "Spells"
	material = Tex.add_material()
	parent.add_child(self)
	ground = Node2D.new()
	ground.name = "SpellGround"
	ground.draw.connect(_draw_ground)
	parent.add_child(ground)
	parent.move_child(ground, 0)

# ---------------------------------------------------------------- spawning
func shoot(id: String, from: Vector2, dir: Vector2, d: Dictionary, dmg: float) -> void:
	shots.append({"id": id, "p": from, "v": dir.normalized() * float(d.get("speed", 500.0)), "left": float(d.get("range", 400.0)),
		"dmg": dmg, "col": d.get("col", Color(1, 1, 1)), "size": float(d.get("size", 1.0)), "pierce": bool(d.get("pierce", false)),
		"hit": {}, "status": str(d.get("status", "")), "sec": float(d.get("sec", 0.0)), "trail": []})

## a jagged electric line through the given points
func lightning(pts: Array, col: Color, life := 0.28, w := 3.0) -> void:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(max(3.0, a.distance_to(b) / 18.0))
		var nrm := (b - a).orthogonal().normalized()
		for k in n:
			var f := float(k) / n
			var j := 0.0 if k == 0 else randf_range(-9.0, 9.0)
			out.append(a.lerp(b, f) + nrm * j)
	out.append(pts[pts.size() - 1])
	arcs.append({"pts": out, "t": life, "life": life, "col": col, "w": w})

func tether(a: Vector2, b: Vector2, col: Color, life := 0.45) -> void:
	tethers.append({"a": a, "b": b, "t": life, "life": life, "col": col})

func meteor(p: Vector2, dmg: float, delay := 0.0, r := 48.0) -> void:
	meteors.append({"p": p, "t": -delay, "warn": 0.55, "dmg": dmg, "r": r, "done": false})

func pillar(p: Vector2, col: Color, r := 170.0, life := 0.9) -> void:
	pillars.append({"p": p, "t": life, "life": life, "col": col, "r": r})

func blast(p: Vector2, r: float, col: Color, life := 0.42) -> void:
	blasts.append({"p": p, "r": r, "t": life, "life": life, "col": col})
	if blasts.size() > 16:
		blasts.pop_front()

func busy() -> bool:
	return not (shots.is_empty() and arcs.is_empty() and meteors.is_empty() and pillars.is_empty() and tethers.is_empty() and blasts.is_empty())

# ---------------------------------------------------------------- simulation
func _physics_process(dt: float) -> void:
	if world == null:
		return
	_step_shots(dt)
	_step_meteors(dt)
	for arr in [arcs, pillars, tethers, blasts]:
		var keep: Array = []
		for a in arr:
			a["t"] = float(a["t"]) - dt
			if float(a["t"]) > 0.0:
				keep.append(a)
		arr.assign(keep)
	queue_redraw()
	ground.queue_redraw()

func _step_shots(dt: float) -> void:
	if shots.is_empty():
		return
	var keep: Array = []
	var foes := world.get_tree().get_nodes_in_group("enemies")
	for s in shots:
		var alive := true
		# two sub-steps a frame so a fast lance never skips a small foe
		for sub in 2:
			var step: Vector2 = s["v"] * dt * 0.5
			s["p"] = s["p"] + step
			s["left"] = float(s["left"]) - step.length()
			var tr: Array = s["trail"]
			tr.push_front(s["p"])
			if tr.size() > 7:
				tr.pop_back()
			var sh = world.get("shrine")
			if sh == null:
				sh = world.get("vault")
			if sh == null:
				sh = world.get("altars")
			if sh and sh.shot_at(s["p"], str(s.get("status", ""))):
				_pop(s)
				alive = false
				break
			if float(s["left"]) <= 0.0 or world.wall_hit(Rect2(s["p"] - Vector2(3, 3), Vector2(6, 6))):
				_pop(s)
				alive = false
				break
			var hit_one := false
			for e in foes:
				if not is_instance_valid(e) or e.dead or not e.targetable() or s["hit"].has(e.get_instance_id()):
					continue
				if e.hit_rect().grow(5.0 * float(s["size"])).has_point(s["p"]):
					s["hit"][e.get_instance_id()] = true
					if caster:
						caster.hit(e, float(s["dmg"]), (s["v"] as Vector2).normalized(), str(s["status"]), float(s["sec"]))
					if world.fx:
						world.fx.emit("shine", s["p"], 6, s["col"], -(s["v"] as Vector2), 70.0, 120.0)
					hit_one = true
					if not s["pierce"]:
						break
			if hit_one and not s["pierce"]:
				_pop(s)
				alive = false
				break
		if alive:
			keep.append(s)
	shots = keep

func _pop(s: Dictionary) -> void:
	if world.fx:
		world.fx.ring(s["p"], s["col"], 10.0 * float(s["size"]), 0.22)
		world.fx.emit("shine", s["p"], 5, s["col"], Vector2.ZERO, 180.0, 90.0)
		world.fx.flash_light(s["p"], 70.0, 0.7, s["col"], 0.2)

func _step_meteors(dt: float) -> void:
	if meteors.is_empty():
		return
	var keep: Array = []
	for m in meteors:
		m["t"] = float(m["t"]) + dt
		if float(m["t"]) >= float(m["warn"]) and not m["done"]:
			m["done"] = true
			if caster:
				caster.aoe(m["p"], float(m["r"]), float(m["dmg"]), "burn", 3.0, Color(0.85, 0.6, 1.0))
			blast(m["p"], float(m["r"]) * 1.2, Color(1.0, 0.62, 0.4), 0.38)
			if world.fx:
				world.fx.ring(m["p"], Color(1, 0.75, 0.45), float(m["r"]), 0.4)
				world.fx.ring(m["p"], Color(0.85, 0.6, 1.0), float(m["r"]) * 0.6, 0.3)
				world.fx.emit("ember", m["p"], 14, Color(1, 0.6, 0.3), Vector2.UP, 70.0, 150.0)
				world.fx.smoke(m["p"], 5, Color(0.5, 0.42, 0.45, 0.5), 1.3)
				world.fx.flash_light(m["p"], 180.0, 1.0, Color(1, 0.7, 0.5), 0.45)
			world.shake(4.0)
			Sfx.play("nova", -6.0, 0.15)
		if float(m["t"]) < float(m["warn"]) + 0.3:
			keep.append(m)
	meteors = keep

# ---------------------------------------------------------------- light for the darkness pass
func lights_now() -> Array:
	var out: Array = []
	for s in shots:
		out.append([s["p"], 70.0 * float(s["size"]), 0.85, s["col"]])
	for m in meteors:
		var k: float = clamp(float(m["t"]) / float(m["warn"]), 0.0, 1.0)
		if k > 0.0:
			out.append([m["p"], 50.0 + 90.0 * k, 0.5 + 0.4 * k, Color(1, 0.65, 0.4)])
	for p in pillars:
		out.append([p["p"], float(p["r"]) * 1.4, float(p["t"]) / float(p["life"]), p["col"]])
	for b in blasts:
		out.append([b["p"], float(b["r"]) * 1.5, float(b["t"]) / float(b["life"]), b["col"]])
	if caster and caster.spin_t > 0.0:
		out.append([caster.player.global_position + Vector2(0, -17), 120.0, 0.6, Color(1, 0.8, 0.5)])
	for a in arcs:
		var pts: PackedVector2Array = a["pts"]
		out.append([pts[pts.size() - 1], 90.0, float(a["t"]) / float(a["life"]), a["col"]])
	return out

# ---------------------------------------------------------------- drawing
func _draw_ground() -> void:
	# meteor telegraphs: a ring that closes on the spot, filling as the rock comes down
	for m in meteors:
		var k: float = clamp(float(m["t"]) / float(m["warn"]), 0.0, 1.0)
		if float(m["t"]) < 0.0 or m["done"]:
			continue
		var r: float = float(m["r"])
		ground.draw_set_transform(m["p"], 0.0, Vector2(1.0, 0.55))
		ground.draw_circle(Vector2.ZERO, r, Color(0.6, 0.35, 0.9, 0.12 + 0.18 * k))
		ground.draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(0.9, 0.7, 1.0, 0.8), 2.0, true)
		ground.draw_arc(Vector2.ZERO, r * (1.0 - k) + 4.0, 0, TAU, 32, Color(1, 0.85, 0.6, 0.9), 2.5, true)
	ground.draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	var glow := Tex.glow()
	var dot := Tex.dot()
	# ground blasts: a bright ring racing outwards over a fading glow (squashed to lie on the ground)
	for b in blasts:
		var k0: float = 1.0 - float(b["t"]) / float(b["life"])
		var e: float = 1.0 - pow(1.0 - k0, 3.0)
		var rr: float = float(b["r"]) * (0.25 + 0.75 * e)
		var c0: Color = b["col"]
		draw_set_transform(b["p"], 0.0, Vector2(1.0, 0.62))
		draw_texture_rect(glow, Rect2(-Vector2(rr, rr) * 1.1, Vector2(rr, rr) * 2.2), false, Color(c0, 0.55 * (1.0 - k0)))
		draw_arc(Vector2.ZERO, rr, 0, TAU, 48, Color(c0, 0.9 * (1.0 - k0)), 10.0 * (1.0 - k0) + 2.0, true)
		draw_arc(Vector2.ZERO, rr * 0.96, 0, TAU, 48, Color(1, 1, 0.9, 0.8 * (1.0 - k0)), 2.5, true)
		draw_set_transform(Vector2.ZERO)
	# Whirlwind Strike: a vortex of steel around the hero
	if caster and caster.spin_t > 0.0:
		var hc: Vector2 = caster.player.global_position + Vector2(0, -14)
		var a0: float = caster.spin_ang
		var fade: float = clamp(caster.spin_t / 0.4, 0.0, 1.0)
		draw_set_transform(hc, 0.0, Vector2(1.0, 0.7))
		for i in 3:
			var a := a0 + i * TAU / 3.0
			draw_arc(Vector2.ZERO, 54.0, a, a + 1.5, 20, Color(1, 0.85, 0.55, 0.55 * fade), 7.0, true)
			draw_arc(Vector2.ZERO, 54.0, a + 0.7, a + 1.5, 12, Color(1, 1, 0.95, 0.85 * fade), 2.5, true)
			draw_arc(Vector2.ZERO, 36.0, -a * 1.3, -a * 1.3 + 1.0, 14, Color(1, 0.75, 0.45, 0.4 * fade), 4.0, true)
		draw_texture_rect(glow, Rect2(-Vector2(64, 64), Vector2(128, 128)), false, Color(1, 0.75, 0.45, 0.22 * fade))
		draw_set_transform(Vector2.ZERO)
	for s in shots:
		var c: Color = s["col"]
		var sz: float = float(s["size"])
		var tr: Array = s["trail"]
		for i in tr.size():
			var f := 1.0 - float(i) / tr.size()
			var r := (9.0 * f + 2.0) * sz
			draw_texture_rect(dot, Rect2(tr[i] - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c, 0.55 * f))
		var p: Vector2 = s["p"]
		draw_texture_rect(glow, Rect2(p - Vector2(22, 22) * sz, Vector2(44, 44) * sz), false, Color(c, 0.7))
		if s["id"] == "icelance":
			var d: Vector2 = (s["v"] as Vector2).normalized()
			var n := d.orthogonal()
			draw_colored_polygon(PackedVector2Array([p + d * 14.0, p + n * 4.0 - d * 6.0, p - d * 12.0, p - n * 4.0 - d * 6.0]), Color(0.85, 0.97, 1.0, 0.95))
		else:
			draw_circle(p, 4.5 * sz, Color(1, 1, 1, 0.95))
	for a in arcs:
		var k: float = float(a["t"]) / float(a["life"])
		var c2: Color = a["col"]
		draw_polyline(a["pts"], Color(c2, 0.35 * k), float(a["w"]) * 3.0, true)
		draw_polyline(a["pts"], Color(1, 1, 1, 0.9 * k), float(a["w"]), true)
	for t in tethers:
		var k2: float = float(t["t"]) / float(t["life"])
		var a2: Vector2 = t["a"]
		var b2: Vector2 = t["b"]
		var col: Color = t["col"]
		var pts := PackedVector2Array()
		for i in 13:
			var f2 := float(i) / 12.0
			var wob := sin(f2 * 9.0 + Time.get_ticks_msec() / 60.0) * 6.0 * (1.0 - absf(f2 - 0.5) * 2.0)
			pts.append(a2.lerp(b2, f2) + (b2 - a2).orthogonal().normalized() * wob)
		draw_polyline(pts, Color(col, 0.45 * k2), 7.0, true)
		draw_polyline(pts, Color(1, 1, 1, 0.8 * k2), 2.0, true)
		# motes flow from the foe to the hero
		for i in 4:
			var f3 := fmod(Time.get_ticks_msec() / 400.0 + i * 0.25, 1.0)
			var q := b2.lerp(a2, f3)
			draw_texture_rect(dot, Rect2(q - Vector2(5, 5), Vector2(10, 10)), false, Color(col, 0.9 * k2))
	for m in meteors:
		if float(m["t"]) < 0.0:
			continue
		var k3: float = clamp(float(m["t"]) / float(m["warn"]), 0.0, 1.0)
		if not m["done"]:
			# the rock streaks down from the upper left
			var from: Vector2 = m["p"] + Vector2(-140, -260)
			var at: Vector2 = from.lerp(m["p"], k3 * k3)
			draw_line(from.lerp(at, 0.6), at, Color(1, 0.6, 0.3, 0.5), 6.0, true)
			draw_texture_rect(glow, Rect2(at - Vector2(26, 26), Vector2(52, 52)), false, Color(1, 0.6, 0.35, 0.9))
			draw_circle(at, 6.0, Color(1, 0.95, 0.8))
		else:
			var f4: float = (float(m["t"]) - float(m["warn"])) / 0.3
			draw_texture_rect(glow, Rect2(m["p"] - Vector2(70, 50), Vector2(140, 100)), false, Color(1, 0.6, 0.35, 0.8 * (1.0 - f4)))
	for p2 in pillars:
		var k4: float = float(p2["t"]) / float(p2["life"])
		var c4: Color = p2["col"]
		var pos: Vector2 = p2["p"]
		var w := 46.0 * (0.6 + 0.4 * k4)
		draw_rect(Rect2(pos.x - w * 0.5, pos.y - 420.0, w, 420.0), Color(c4, 0.35 * k4))
		draw_rect(Rect2(pos.x - w * 0.18, pos.y - 420.0, w * 0.36, 420.0), Color(1, 1, 0.92, 0.6 * k4))
		draw_texture_rect(glow, Rect2(pos - Vector2(float(p2["r"]), float(p2["r"]) * 0.6), Vector2(float(p2["r"]), float(p2["r"]) * 0.6) * 2.0), false, Color(c4, 0.55 * k4))

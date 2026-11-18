extends Node2D
## Gold and experience you can see: a kill pops out a few spinning coins and blue sparks of experience,
## they hop once on the ground and then fly to the hero, each coin with a soft tick. (The gold and XP are
## counted at the kill, as in the HTML game; this is the feedback.) Drawn on the effects overlay.

const Tex = preload("res://scripts/fx/tex.gd")

var world: Node = null
var bits: Array = []        # {p, v, ground, t, kind, spin}
var _tick := 0.0
var orbs: Node2D

static func spawn(w: Node, pos: Vector2, gold: int, xp: int, big := false) -> void:
	if w == null or w.get("loot") == null:
		return
	w.loot.add(pos, gold, xp, big)

func setup(w: Node, parent: Node) -> void:
	world = w
	name = "Loot"
	parent.add_child(self)
	orbs = Node2D.new()
	orbs.material = Tex.add_material()
	orbs.draw.connect(_draw_orbs)
	add_child(orbs)

func add(pos: Vector2, gold: int, xp: int, big := false) -> void:
	var nc: int = clamp(int(round(gold / 3.0)), 1 if gold > 0 else 0, 16 if big else 7)
	var nx: int = clamp(int(round(xp / 8.0)), 1, 14 if big else 6)
	for i in nc + nx:
		var kind := "coin" if i < nc else "xp"
		var a := randf_range(-PI * 0.9, -PI * 0.1)
		var sp := randf_range(70.0, 150.0) * (1.4 if big else 1.0)
		bits.append({"p": pos, "v": Vector2.from_angle(a) * sp, "ground": pos.y + randf_range(8.0, 22.0),
			"t": randf_range(0.32, 0.5), "kind": kind, "spin": randf() * TAU, "home": false, "spd": 0.0})
	if bits.size() > 90:
		bits = bits.slice(bits.size() - 90)

func _process(dt: float) -> void:
	if bits.is_empty():
		return
	_tick -= dt
	var p = world.get_tree().get_first_node_in_group("player")
	var target: Vector2 = p.global_position + Vector2(0, -20) if p != null and p.world == world else Vector2.ZERO
	var keep: Array = []
	for b in bits:
		b["spin"] = float(b["spin"]) + dt * 9.0
		if not b["home"]:
			b["t"] = float(b["t"]) - dt
			var v: Vector2 = b["v"]
			v.y += 520.0 * dt
			var np: Vector2 = b["p"] + v * dt
			if np.y > float(b["ground"]) and v.y > 0.0:
				np.y = float(b["ground"])
				v = Vector2(v.x * 0.5, -v.y * 0.35)
			b["v"] = v
			b["p"] = np
			if float(b["t"]) <= 0.0 and target != Vector2.ZERO:
				b["home"] = true
		else:
			if target == Vector2.ZERO:
				continue
			b["spd"] = min(900.0, float(b["spd"]) + 1500.0 * dt)
			var to: Vector2 = target - b["p"]
			var d := to.length()
			if d < 12.0:
				if b["kind"] == "coin" and _tick <= 0.0:
					_tick = 0.06
					Sfx.play("coin_tick", -16.0, 0.2)
				continue
			b["p"] = b["p"] + to / d * min(d, float(b["spd"]) * dt)
		keep.append(b)
	bits = keep
	queue_redraw()
	orbs.queue_redraw()

func _draw() -> void:
	for b in bits:
		if b["kind"] != "coin":
			continue
		var c: Vector2 = b["p"]
		var sx: float = abs(cos(float(b["spin"]))) * 0.75 + 0.25
		draw_set_transform(c, 0.0, Vector2(sx, 1.0))
		draw_circle(Vector2.ZERO, 4.6, Color(0.5, 0.32, 0.06))
		draw_circle(Vector2.ZERO, 3.8, Color(1, 0.8, 0.28))
		draw_circle(Vector2.ZERO, 2.4, Color(0.93, 0.68, 0.2))
		draw_circle(Vector2(-1.1, -1.2), 1.3, Color(1, 0.97, 0.75))
	draw_set_transform(Vector2.ZERO)

func _draw_orbs() -> void:
	var g := Tex.dot()
	for b in bits:
		if b["kind"] == "coin":
			var c0: Vector2 = b["p"]
			orbs.draw_texture_rect(g, Rect2(c0 - Vector2(9, 9), Vector2(18, 18)), false, Color(1, 0.8, 0.3, 0.3))
			continue
		var c: Vector2 = b["p"]
		orbs.draw_texture_rect(g, Rect2(c - Vector2(9, 9), Vector2(18, 18)), false, Color(0.45, 0.8, 1.0, 0.8))
		orbs.draw_texture_rect(g, Rect2(c - Vector2(3.5, 3.5), Vector2(7, 7)), false, Color(0.9, 0.97, 1.0, 1.0))

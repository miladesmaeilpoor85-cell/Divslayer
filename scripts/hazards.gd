extends Node2D
## Map hazards, drawn and (for the Forge vents) ticked here — port of v15_hazards.js and FF.updateLava:
##   lava pools with rocky rims (Ashen Peaks), glossy ice sheets (Crystal Sanctum), bubbling poison (Shadowfen),
##   and the Emberforge's lava vents: cooled crust -> glowing warning -> eruption (burns while erupting).
## The map ground images were exported without these, so without this layer they were invisible.

var world: Node = null
var shapes: Array = []      # {rect, kind, poly, stones}
var vents: Array = []       # {rect, period, offset, hot, warn, tick, cracks}
var lava_t := 0.0
var clock := 0.0

func setup(w: Node, hazards: Array, ch_lava: Array) -> void:
	world = w
	name = "Hazards"
	z_index = -7
	for h in hazards:
		var r: Rect2 = h["rect"]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s:%d,%d" % [h["type"], int(r.position.x), int(r.position.y)])
		var stones := []
		for i in 14:
			var a := i / 14.0 * TAU
			stones.append([r.get_center() + Vector2(cos(a) * (r.size.x * 0.5 + 1), sin(a) * (r.size.y * 0.5 + 1)), 3.0 + rng.randf() * 3.0])
		var spots := []
		for i in 6:
			spots.append([r.get_center() + Vector2((rng.randf() - 0.5) * r.size.x * 0.6, (rng.randf() - 0.5) * r.size.y * 0.6), 4.0 + rng.randf() * 7.0])
		shapes.append({"rect": r, "kind": h["type"], "poly": _blob(r.get_center(), r.size * 0.5, rng, 14, 0.12), "stones": stones, "spots": spots, "seed": rng.randf() * 10.0})
	for v in ch_lava:
		var r := Rect2(float(v["x"]), float(v["y"]), float(v["w"]), float(v["h"]))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("vent:%d,%d" % [int(r.position.x), int(r.position.y)])
		var cracks := []
		var nc: int = max(3, int(r.size.x * r.size.y / 700.0))
		for i in nc:
			var p := r.position + Vector2(4 + rng.randf() * (r.size.x - 8), 4 + rng.randf() * (r.size.y - 8))
			var pts := PackedVector2Array([p])
			var a := rng.randf() * TAU
			for k in 4:
				a += (rng.randf() - 0.5) * 1.4
				p = (p + Vector2(cos(a), sin(a)) * (6 + rng.randf() * 8)).clamp(r.position + Vector2(2, 2), r.end - Vector2(2, 2))
				pts.append(p)
			cracks.append(pts)
		vents.append({"rect": r, "period": float(v.get("period", 3200)) / 1000.0, "offset": float(v.get("offset", 0)) / 1000.0,
			"hot": false, "warn": false, "tick": 0.0, "cracks": cracks})

## an irregular closed blob around c with radii rad (V15.blob)
static func _blob(c: Vector2, rad: Vector2, rng: RandomNumberGenerator, n: int, jitter: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := i / float(n) * TAU
		var k := 1.0 + (rng.randf() - 0.5) * 2.0 * jitter
		pts.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y) * k)
	return pts

static func _scaled(poly: PackedVector2Array, c: Vector2, k: float, off := Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(c + (p - c) * k + off)
	return out

## erupting vents burn the hero (FF.updateLava)
func _physics_process(dt: float) -> void:
	clock += dt
	if vents.is_empty():
		return
	lava_t += dt
	var p = get_tree().get_first_node_in_group("player")
	for v in vents:
		var ph: float = fmod(lava_t + float(v["offset"]), float(v["period"])) / float(v["period"])
		v["hot"] = ph > 0.72
		v["warn"] = ph > 0.55 and ph <= 0.72
		if not v["hot"] or p == null or p.dead:
			v["tick"] = 0.0
			continue
		if p.body_rect().intersects(v["rect"]):
			v["tick"] = float(v["tick"]) + dt
			if float(v["tick"]) > 0.5:
				v["tick"] = 0.0
				p.take_hit(max(3.0, round(6.0 + Game.lvl() * 0.4)))
				p.apply_status("burn", 2.5, 1.0)
		else:
			v["tick"] = 0.0
		if randf() < 15.0 * dt:
			var r: Rect2 = v["rect"]
			world.burst(r.position + Vector2(randf() * r.size.x, r.size.y * 0.6), Color(1, 0.54, 0.18), 1, 60.0)

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	for s in shapes:
		var r: Rect2 = s["rect"]
		var c := r.get_center()
		var poly: PackedVector2Array = s["poly"]
		match str(s["kind"]):
			"lava":
				draw_colored_polygon(_scaled(poly, c, 1.0 + 6.0 / r.size.y, Vector2(0, 2)), Color(0, 0, 0, 0.35))
				draw_colored_polygon(_scaled(poly, c, 1.0 + 4.0 / min(r.size.x, r.size.y) * 2.0), Color8(42, 23, 18))
				var cols := [Color8(122, 30, 8), Color8(208, 64, 15), Color8(255, 138, 42), Color8(255, 190, 100), Color8(255, 210, 122)]
				var ks := [0.94, 0.78, 0.55, 0.32, 0.14]
				for i in cols.size():
					draw_colored_polygon(_scaled(poly, c, ks[i]), cols[i])
				for sp in s["spots"]:
					draw_circle(sp[0], sp[1] * 0.6, Color(0.24, 0.08, 0.03, 0.6))
				for st in s["stones"]:
					draw_circle(st[0], st[1], Color8(74, 48, 40))
					draw_circle(st[0] - Vector2(0.8, 0.8), st[1] * 0.5, Color8(110, 78, 66))
				var t := clock + float(s["seed"])
				for i in 4:
					var ph := t / 0.9 + i * 1.7
					var b := c + Vector2(cos(ph) * r.size.x * 0.25, sin(ph * 1.3) * r.size.y * 0.2)
					draw_circle(b, 9.0 + 4.0 * sin(ph * 2.0), Color(1, 0.9, 0.55, 0.22))
				var pulse := 0.5 + 0.5 * sin(t * 2.0)
				draw_set_transform(c, 0.0, Vector2(1.0, r.size.y / r.size.x))
				draw_circle(Vector2.ZERO, r.size.x * 0.85, Color(1, 0.47, 0.12, 0.06 + 0.05 * pulse))
				draw_set_transform(Vector2.ZERO)
			"ice":
				var ring := _scaled(poly, c, 1.04)
				draw_colored_polygon(ring, Color(0.63, 0.84, 0.96, 0.75))
				draw_colored_polygon(_scaled(poly, c, 0.8, Vector2(-r.size.x * 0.06, -r.size.y * 0.06)), Color(0.88, 0.96, 1.0, 0.55))
				var outline := ring.duplicate()
				outline.append(ring[0])
				draw_polyline(outline, Color(1, 1, 1, 0.8), 1.2, true)
				for i in 3:
					var p0 := c + Vector2(-r.size.x * 0.25 + i * r.size.x * 0.12, -r.size.y * 0.2 + i * r.size.y * 0.12)
					draw_line(p0, p0 + Vector2(18, -10), Color(1, 1, 1, 0.5), 2.0)
				var sweep := fmod(clock * 25.0 + r.position.x, r.size.x + 60.0) - 30.0
				var sx := r.position.x + sweep
				if sx > r.position.x + 4 and sx < r.end.x - 4:
					draw_line(Vector2(sx, r.end.y - 6), Vector2(sx + r.size.y * 0.5, r.position.y + 6), Color(1, 1, 1, 0.16), 6.0)
			_:
				draw_colored_polygon(_scaled(poly, c, 1.06, Vector2(0, 2)), Color(0.08, 0.12, 0.04, 0.6))
				var gcols := [Color8(47, 90, 34), Color8(72, 140, 50), Color8(110, 190, 70), Color8(155, 224, 90)]
				var gks := [1.0, 0.75, 0.5, 0.22]
				for i in gcols.size():
					draw_colored_polygon(_scaled(poly, c, gks[i]), gcols[i])
				for i in 5:
					var ph := fmod(clock / 1.3 + i * 0.37 + r.position.x * 0.003, 1.0)
					var b := c + Vector2(sin(i * 2.3 + r.position.y) * r.size.x * 0.3, cos(i * 1.7 + r.position.x) * r.size.y * 0.25)
					draw_arc(b, 1.0 + ph * 5.0, 0, TAU, 12, Color(0.78, 1, 0.56, 1.0 - ph), 1.0, true)
	for v in vents:
		var r: Rect2 = v["rect"]
		draw_rect(r.grow(5), Color8(36, 20, 14))
		if v["hot"]:
			var p := 0.55 + 0.45 * sin(clock * 11.0)
			draw_rect(r, Color(1, 0.43, 0.12, 0.55 + 0.3 * p))
			draw_rect(r.grow(-4), Color(1, 0.86, 0.47, 0.25 * p + 0.15))
			var nf: int = max(2, int(r.size.x / 22.0))
			for i in nf:
				var fx: float = r.position.x + (i + 0.5) * r.size.x / nf
				var fh := 16.0 + 6.0 * sin(clock * 7.0 + i)
				var fy: float = r.position.y + r.size.y * 0.6
				draw_colored_polygon(PackedVector2Array([Vector2(fx - 6, fy), Vector2(fx, fy - fh), Vector2(fx + 6, fy)]), Color(1, 0.7, 0.25, 0.75))
		else:
			draw_rect(r, Color8(58, 30, 18))
			var warn: bool = v["warn"]
			var p2 := (0.5 + 0.5 * sin(clock * 14.0)) if warn else (0.5 + 0.5 * sin(clock * 1.4 + r.position.x))
			var cc := Color(1, 0.55, 0.16, 0.55 + 0.45 * p2) if warn else Color(0.78, 0.24, 0.08, 0.3 + 0.15 * p2)
			for pts in v["cracks"]:
				draw_polyline(pts, cc, 2.2 if warn else 1.4, true)
			if warn:
				draw_rect(r.grow(-1), Color(0.8, 0.27, 0.12, 0.18 + 0.22 * p2))
				draw_rect(r.grow(3), Color(1, 0.67, 0.27, 0.4 + 0.5 * p2), false, 2.0)

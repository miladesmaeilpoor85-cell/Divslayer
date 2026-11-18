extends Node2D
## v18 telegraph engine, in world space (port of V18.tele / waves / lobs in v18_core.js):
## circles, lanes and cones that fill up and then strike, expanding shockwaves you roll through,
## lobbed rocks, enemy bolts, temporary poison pools and delayed boss actions.
## Ground marks draw under everything; rocks in flight and bolts draw above.
## Times are seconds, distances logical pixels; HTML "px per frame" speeds are multiplied by Game.PXS.

var world: Node = null
var tele: Array = []      # {kind, pos, r | b, w | a, half, t, total, rgb, fire, en, done}
var waves: Array = []     # {pos, r, max, speed, en, mult, rgb, hit, bot}
var lobs: Array = []      # {from, to, t, total, r, en, mult, rgb, img, vol, done}
var shots: Array = []     # {pos, v, life, dmg, col, applies}
var pools: Array = []     # {rect, life, max, type}
var laters: Array = []    # {t, en, fn}
var air: Node2D
var clock := 0.0
var _pd_until := 0.0
var counts := {"tele": 0, "perfect": 0, "hits": 0}
var dmg_by := {}          # damage the hero took, by boss move (balance reports)
var cur_src := ""

func _ready() -> void:
	name = "BossFx"
	z_index = -5
	air = Node2D.new()
	air.name = "Air"
	air.z_as_relative = false
	air.z_index = 60
	air.draw.connect(_draw_air)
	add_child(air)

func player() -> Node:
	return get_tree().get_first_node_in_group("player")

func pc() -> Vector2:
	var p := player()
	return p.pc() if p else Vector2(-9999, -9999)

func busy() -> bool:
	return not (tele.is_empty() and waves.is_empty() and lobs.is_empty() and shots.is_empty())

# ---------------------------------------------------------------- shapes
func circle(pos: Vector2, r: float, sec: float, rgb: Color, fire: Callable, en: Node = null) -> Dictionary:
	var t := {"kind": "circle", "pos": pos, "r": r, "t": sec, "total": sec, "rgb": rgb, "fire": fire, "en": en, "done": false, "src": _src(en)}
	tele.append(t)
	counts["tele"] += 1
	return t

func lane(a: Vector2, b: Vector2, w: float, sec: float, rgb: Color, fire: Callable, en: Node = null) -> Dictionary:
	var t := {"kind": "lane", "pos": a, "b": b, "w": w, "t": sec, "total": sec, "rgb": rgb, "fire": fire, "en": en, "done": false, "src": _src(en)}
	tele.append(t)
	counts["tele"] += 1
	return t

func cone(pos: Vector2, r: float, ang: float, half: float, sec: float, rgb: Color, fire: Callable, en: Node = null) -> Dictionary:
	var t := {"kind": "cone", "pos": pos, "r": r, "a": ang, "half": half, "t": sec, "total": sec, "rgb": rgb, "fire": fire, "en": en, "done": false, "src": _src(en)}
	tele.append(t)
	counts["tele"] += 1
	return t

## which boss move made this effect (for the damage breakdown in balance reports)
func _src(en) -> String:
	if typeof(en) != TYPE_NIL and is_instance_valid(en) and "last_move" in en:
		return en.last_move
	return cur_src

func _book(amount: float) -> void:
	if amount > 0.0:
		var k := cur_src if cur_src != "" else "?"
		dmg_by[k] = float(dmg_by.get(k, 0.0)) + amount

func in_circle(t: Dictionary, pad := 8.0) -> bool:
	return pc().distance_to(t["pos"]) < float(t["r"]) + pad

func in_lane(t: Dictionary) -> bool:
	var p := pc()
	var a: Vector2 = t["pos"]
	var v: Vector2 = t["b"] - a
	var l2: float = max(1.0, v.length_squared())
	var k: float = clamp((p - a).dot(v) / l2, 0.0, 1.0)
	return p.distance_to(a + v * k) < float(t["w"]) * 0.5 + 8.0

func in_cone(t: Dictionary) -> bool:
	var p := pc()
	var d: float = p.distance_to(t["pos"])
	if d > float(t["r"]) + 8.0:
		return false
	var da: float = abs(angle_difference((p - t["pos"]).angle(), float(t["a"])))
	return da < float(t["half"]) or d < 26.0

func inside(t: Dictionary) -> bool:
	match str(t["kind"]):
		"circle": return in_circle(t)
		"lane": return in_lane(t)
		"cone": return in_cone(t)
	return false

# ---------------------------------------------------------------- hitting the hero
## one boss attack lands on the hero. Rolling through it as it lands is a "perfect dodge":
## no damage and the boss's stagger bar fills (V18.hit).
func hit(en: Node, mult: float, status: Array = [], graze := false) -> bool:
	var p := player()
	if p == null or p.dead:
		return false
	if not graze and p.dodge_iframes > 0.0 and en != null:
		var b: Node = en.owner_boss if "owner_boss" in en and en.owner_boss != null and is_instance_valid(en.owner_boss) else en
		if b.has_method("add_stagger") and clock >= _pd_until:
			_pd_until = clock + 0.6
			b.add_stagger(12.0)
			counts["perfect"] += 1
			world.float_text(p.global_position + Vector2(0, -48), Game.t("Perfect dodge!", "جاخالیِ بی‌نقص!"), Color(0.75, 1.0, 0.82), true)
			world.burst(p.global_position + Vector2(0, -17), Color(0.75, 1.0, 0.82), 12, 120.0)
			Sfx.play("dodge", 2.0, 0.0)
			world.tip("b_perfect", "Perfect dodge! Rolling through a boss attack as it lands fills its stagger bar.",
				"جاخالیِ بی‌نقص! اگر درست لحظهٔ فرود حمله از میانش غلت بزنی، نوار گیجیِ سرکرده پر می‌شود.")
		return false
	var h0: float = Game.hp
	var raw: float = 10.0 if en == null else float(en.dmg)
	p.take_hit(max(1.0, round(raw * mult)))
	var landed: bool = Game.hp < h0
	_book(h0 - Game.hp)
	if landed:
		counts["hits"] += 1
		if status.size() >= 2:
			p.apply_status(str(status[0]), float(status[1]), float(status[2]) if status.size() > 2 else 2.0)
	return landed

## a volley (lances, hail, boulders) hits at most once
func vol() -> Dictionary:
	return {"hit": false}

func hit_v(v: Dictionary, en: Node, mult: float, status: Array = []) -> bool:
	if v.get("hit", false):
		return false
	var r := hit(en, mult, status)
	if r:
		v["hit"] = true
	return r

func knock(v: Vector2) -> void:
	var p := player()
	if p:
		p.knock(v)

# ---------------------------------------------------------------- shockwaves, rocks, bolts, pools, delays
func wave(pos: Vector2, max_r: float, speed: float, en: Node, mult: float, rgb := Color8(255, 140, 60)) -> void:
	waves.append({"pos": pos, "r": 8.0, "max": max_r, "speed": speed * Game.PXS, "en": en, "mult": mult, "rgb": rgb, "hit": false, "src": _src(en)})

func lob(from: Vector2, to: Vector2, sec: float, r: float, en: Node, mult: float, rgb: Color, img := "", v: Dictionary = {}) -> void:
	lobs.append({"from": from, "to": to, "t": sec, "total": sec, "r": r, "en": en, "mult": mult, "rgb": rgb, "img": img, "vol": v, "done": false, "src": _src(en)})

func shoot(en: Node, n: int, speed: float, mult: float, col: Color, applies := "", off := 0.0, at = null) -> void:
	var c: Vector2 = at if at != null else en.center()
	var dmg: float = max(1.0, round(float(en.dmg) * mult))
	for i in n:
		var a := float(i) / n * TAU + off
		shots.append({"pos": c, "v": Vector2.from_angle(a) * speed * Game.PXS, "life": 1.8, "dmg": dmg, "col": col, "applies": applies, "src": _src(en) + ":bolt"})

func pool(center: Vector2, size: float, life: float, type := "poison", en: Node = null, mult := 0.0, status: Array = []) -> void:
	var damaging := en != null and mult > 0.0
	pools.append({"rect": Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)), "life": life, "max": life,
		"type": type, "tick": 0.8 if damaging else 0.0, "en": en, "mult": mult, "status": status})

func pool_at(feet: Vector2) -> String:
	for p in pools:
		if p["rect"].has_point(feet):
			return p["type"]
	return ""

## game-time delay that dies with its boss and waits while the game is paused (V18.later)
func later(en: Node, sec: float, fn: Callable) -> void:
	laters.append({"t": sec, "en": en, "fn": fn})

func clear() -> void:
	tele.clear()
	waves.clear()
	lobs.clear()
	laters.clear()

## a freed object compares equal to null in Godot 4, so test the type, not "== null"
static func _alive(en) -> bool:
	return typeof(en) == TYPE_NIL or (is_instance_valid(en) and not en.dead)

# ---------------------------------------------------------------- update
func _physics_process(dt: float) -> void:
	clock += dt
	if not laters.is_empty():
		var due := []
		for l in laters:
			l["t"] = float(l["t"]) - dt
			if float(l["t"]) <= 0.0:
				due.append(l)
		for l in due:
			laters.erase(l)
		for l in due:
			if _alive(l["en"]):
				l["fn"].call()
	if not tele.is_empty():
		for t in tele.duplicate():
			t["t"] = float(t["t"]) - dt
			if float(t["t"]) <= 0.0 and not t["done"]:
				t["done"] = true
				if _alive(t["en"]) and t["fire"].is_valid():
					cur_src = t["src"]
					t["fire"].call(t)
					cur_src = ""
		tele = tele.filter(func(x): return not x["done"])
	if not waves.is_empty():
		var p := pc()
		for w in waves:
			w["r"] = float(w["r"]) + float(w["speed"]) * dt
			var d: float = p.distance_to(w["pos"])
			if not w["hit"] and abs(d - float(w["r"])) < 16.0 and _alive(w["en"]):
				w["hit"] = true
				cur_src = w["src"]
				var landed := hit(w["en"], float(w["mult"]))
				cur_src = ""
				if landed:
					knock((p - w["pos"]) / max(1.0, d) * 16.0)
		waves = waves.filter(func(x): return float(x["r"]) < float(x["max"]))
	if not lobs.is_empty():
		for b in lobs:
			b["t"] = float(b["t"]) - dt
			if float(b["t"]) <= 0.0 and not b["done"]:
				b["done"] = true
				world.burst(b["to"], b["rgb"], 14, 140.0)
				world.shake(4.0)
				Sfx.play("trap", -4.0)
				if pc().distance_to(b["to"]) < float(b["r"]) + 8.0 and _alive(b["en"]):
					cur_src = b["src"]
					hit_v(b["vol"], b["en"], float(b["mult"]))
					cur_src = ""
		lobs = lobs.filter(func(x): return not x["done"])
	if not shots.is_empty():
		var pl := player()
		var body: Rect2 = pl.body_rect() if pl else Rect2()
		for s in shots:
			s["pos"] = s["pos"] + s["v"] * dt
			s["life"] = float(s["life"]) - dt
			if float(s["life"]) <= 0.0:
				continue
			var box := Rect2(s["pos"] - Vector2(3, 3), Vector2(6, 6))
			if world.wall_hit(box):
				s["life"] = 0.0
				world.burst(s["pos"], s["col"], 3, 60.0)
			elif pl and not pl.dead and box.intersects(body):
				s["life"] = 0.0
				var h0: float = Game.hp
				pl.take_hit(float(s["dmg"]))
				cur_src = s["src"]
				_book(h0 - Game.hp)
				cur_src = ""
				if s["applies"] != "" and Game.hp < h0:
					pl.apply_status(str(s["applies"]), float(s.get("sec", 3.0)), 1.0)
				world.burst(s["pos"], s["col"], 5, 80.0)
		shots = shots.filter(func(x): return float(x["life"]) > 0.0)
	if not pools.is_empty():
		var pool_player := player()
		for puddle in pools:
			puddle["life"] = float(puddle["life"]) - dt
			var pool_owner = puddle.get("en", null)
			if pool_owner != null and float(puddle.get("mult", 0.0)) > 0.0:
				puddle["tick"] = float(puddle.get("tick", 0.0)) - dt
				if float(puddle["tick"]) <= 0.0:
					puddle["tick"] = 0.8
					if pool_player != null and not pool_player.dead and pool_player.has_method("pc") and _alive(pool_owner) and puddle["rect"].has_point(pool_player.pc()):
						cur_src = "regional_poison_pool"
						hit(pool_owner, float(puddle["mult"]), puddle.get("status", []))
						cur_src = ""
		pools = pools.filter(func(x): return float(x["life"]) > 0.0)
	queue_redraw()
	air.queue_redraw()

# ---------------------------------------------------------------- drawing
func _ring_dashed(c: Vector2, r: float, col: Color, width: float) -> void:
	var n := int(clamp(r / 5.0, 8.0, 36.0))
	var off := fmod(clock * 1.6, TAU / n)
	for i in n:
		var a0 := off + TAU * i / n
		draw_arc(c, r, a0, a0 + TAU / n * 0.6, 6, col, width, true)

func _draw() -> void:
	for p in pools:
		var k: float = clamp(float(p["life"]) / 0.6, 0.0, 1.0) * clamp((float(p["max"]) - float(p["life"])) / 0.4, 0.0, 1.0)
		var r: Rect2 = p["rect"]
		var c := r.get_center()
		draw_set_transform(c, 0.0, Vector2(1.0, 0.62))
		draw_circle(Vector2.ZERO, r.size.x * 0.55, Color(0.35, 0.7, 0.25, 0.32 * k))
		draw_circle(Vector2.ZERO, r.size.x * 0.4, Color(0.45, 0.85, 0.3, 0.3 * k))
		for i in 3:
			var bx := Vector2(cos(clock * 1.3 + i * 2.1), sin(clock * 1.7 + i * 1.3)) * r.size.x * 0.28
			draw_circle(bx, 3.0 + 1.5 * sin(clock * 5.0 + i), Color(0.75, 1.0, 0.55, 0.55 * k))
		draw_set_transform(Vector2.ZERO)
	_draw_boss_ground()
	for t in tele:
		var k: float = clamp(1.0 - float(t["t"]) / max(0.001, float(t["total"])), 0.0, 1.0)
		var c: Color = t["rgb"]
		match str(t["kind"]):
			"circle":
				var p: Vector2 = t["pos"]
				var r: float = t["r"]
				draw_circle(p, r, Color(c, 0.13))
				var rk: float = max(1.0, r * k)
				draw_circle(p, rk, Color(c, 0.12))
				draw_circle(p, rk * 0.8, Color(c, 0.12))
				draw_circle(p, rk * 0.55, Color(c, 0.08))
				draw_arc(p, rk, 0, TAU, 32, Color(c, 0.45), 1.5, true)
				_ring_dashed(p, r, Color(c, 0.55 + 0.4 * k), 2.2)
			"lane":
				var a: Vector2 = t["pos"]
				var b: Vector2 = t["b"]
				var w: float = t["w"]
				var span := a.distance_to(b)
				draw_set_transform(a, (b - a).angle())
				var steps := 6
				for i in steps:
					var x0 := span * i / steps
					draw_rect(Rect2(x0, -w * 0.5, span / steps, w), Color(c, 0.30 - 0.22 * float(i) / steps))
				draw_rect(Rect2(0, -w * 0.5, span * k, w), Color(c, 0.14))
				draw_rect(Rect2(0, -w * 0.5, span, w), Color(c, 0.4 + 0.4 * k), false, 1.5)
				var off := fmod(clock * 166.0, 26.0)
				var d := off
				while d < span - 6.0:
					draw_colored_polygon(PackedVector2Array([Vector2(d, -w * 0.3), Vector2(d + 9, 0), Vector2(d, w * 0.3), Vector2(d + 4, 0)]), Color(c, 0.45 + 0.4 * k))
					d += 26.0
				draw_set_transform(Vector2.ZERO)
			"cone":
				var p: Vector2 = t["pos"]
				var r: float = t["r"]
				var a0: float = float(t["a"]) - float(t["half"])
				var a1: float = float(t["a"]) + float(t["half"])
				draw_colored_polygon(_fan(p, r, a0, a1), Color(c, 0.13))
				draw_colored_polygon(_fan(p, max(2.0, r * k), a0, a1), Color(c, 0.34))
				var outline := _fan(p, r, a0, a1)
				outline.append(p)
				draw_polyline(outline, Color(c, 0.5 + 0.4 * k), 2.0, true)
	for w in waves:
		var fade: float = 1.0 - float(w["r"]) / float(w["max"])
		var c: Color = w["rgb"]
		draw_arc(w["pos"], w["r"], 0, TAU, 48, Color(c, 0.85 * fade), 10.0, true)
		draw_arc(w["pos"], w["r"], 0, TAU, 48, Color(1, 0.94, 0.78, 0.6 * fade), 3.0, true)
	for b in lobs:
		var k: float = 1.0 - float(b["t"]) / float(b["total"])
		var c: Color = b["rgb"]
		var r: float = b["r"]
		draw_circle(b["to"], r, Color(c, 0.13))
		draw_circle(b["to"], max(1.0, r * k), Color(c, 0.28))
		_ring_dashed(b["to"], r, Color(c, 0.55 + 0.4 * k), 2.0)

func _fan(p: Vector2, r: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array([p])
	for i in 17:
		pts.append(p + Vector2.from_angle(a0 + (a1 - a0) * i / 16.0) * r)
	return pts

## tethers from Arzhang to his pillars, the Sorceress's shadow under the mud, the King's heat
func _draw_boss_ground() -> void:
	for en in get_tree().get_nodes_in_group("bosses"):
		if en.dead:
			continue
		en.draw_ground(self)

func _draw_air() -> void:
	for b in lobs:
		var k: float = 1.0 - float(b["t"]) / float(b["total"])
		var pos: Vector2 = b["from"].lerp(b["to"], k) - Vector2(0, sin(k * PI) * 140.0)
		if b["img"] == "ice":
			air.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -9), pos + Vector2(6, 0), pos + Vector2(0, 9), pos + Vector2(-6, 0)]), Color(0.81, 0.94, 1.0))
		else:
			air.draw_circle(pos, 11.0, Color(0.36, 0.28, 0.23))
			air.draw_circle(pos + Vector2(-3, -3), 7.0, Color(0.6, 0.54, 0.48))
			air.draw_circle(pos + Vector2(3, 2), 3.5, Color(1.0, 0.55, 0.2, 0.85))
	for s in shots:
		var c: Color = s["col"]
		air.draw_circle(s["pos"], 6.0, Color(c, 0.3))
		air.draw_circle(s["pos"], 3.5, c)
		air.draw_circle(s["pos"], 1.5, Color(1, 1, 1, 0.9))

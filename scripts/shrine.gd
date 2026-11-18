extends Node2D
## (v0.18) A puzzle shrine: the HTML game's seven V16 shrines, built from their data (V16_SHRINE_LIST: the 17×13 layout,
## the reward, the tablets, the Watchers; the map's v16objs: every piece with its cell). One per region; a stair with a
## pillar of light leads down from the region's map. Solve the room and the inner door opens; at the altar: gold, an
## accessory and the Shrine Sigil — a gift you choose, for good.
##   embers  — strike the eternal flame and your blade burns for a while: light every brazier; brambles burn; the oil
##             trail carries fire over the water to the last brazier
##   weight  — only stone weighs the plates down: walk into a block to push it one cell; the lever puts the blocks back
##   fuse    — push the powder barrel beside the cracked wall, light it, run; a blow can throw foes into the lava
##   tides   — the frost crystal chills your blade: strike the water ahead to freeze a path (it thaws); the storm crystal
##             makes the water deadly to whatever stands in it; the door wants the plate and no foe left
##   light   — strike a mirror to turn it, lead the light to the crystal; fire melts the ice in the way
##   echoes  — the mosaic tells the order of the runes; then both braziers must burn at once (they burn 9 s)
##   shadows — the Watchers see what walks in their light and hear loud steps: sneak, keep to the tall grass
## Fire and frost spells work too (Ember Nova and the fire bolts light and melt, the ice lance freezes water).

const Art = preload("res://scripts/fx/shrine_art.gd")
const Sheets = preload("res://scripts/sheets.gd")
const Gear = preload("res://scripts/gear.gd")
const Tex = preload("res://scripts/fx/tex.gd")

const CELL := 40.0
const FIRE_SEC := 10.0        # the eternal flame's fire on the blade
const FROST_SEC := 9.0        # the frost crystal's chill on the blade
const ICE_SEC := 14.0         # frozen water holds this long
const ICE_WARN := 3.5         # ... and cracks for its last seconds
const STORM_SEC := 2.6
const FUSE_SEC := 3.0
const BLAST_R := 92.0
const OIL_SPEED := 190.0
const PUSH_HOLD := 0.16       # lean on a block this long and it moves
const CONE_HALF := 0.42       # a Watcher's light: half-angle and reach
const CONE_RANGE := 178.0
const HEAR_R := 84.0
const TIMED_SEC := 9.0
const SOLID_TYPES := ["altar", "door", "cracked", "brazier", "source", "bramble", "tablet", "block", "lever", "barrel", "frost",
	"storm", "target", "mirror", "icewall", "emitter"]

var world: Node = null
var key := ""
var def := {}
var layout: Array = []
var objs: Array = []                 # every piece: {t, id, cell, rect, node, solid, ...}
var by_id := {}
var water := {}                      # Vector2i -> {kind: "deep" | "shallow", ice: s left, solid}
var sentinels: Array = []            # {pos, base, sweep, period, phase, ang, node}
var fire_t := 0.0
var frost_t := 0.0
var storm_t := 0.0
var seq := 0                          # runes stepped in the right order so far
var seq_done := false
var order: Array = []
var door_open := false
var door_k := 0.0
var target_lit := false
var beam: Array = []                  # the light's path, world points
var oil := {}                         # {pts, len, burned, lit, done, brazier}
var st := {}                          # Game.shrine(key)
var clock := 0.0
var caught := 0                       # times the Watchers sent the hero back (tests)
var floor_node: Node2D
var beam_node: Node2D
var hero: Node = null
var _push_t := 0.0
var _push_obj = null
var _push_dir := Vector2i.ZERO
var _safe := Vector2.ZERO
var _rune_on = null
var _wrong_t := 0.0
var _caught_t := 0.0
var _ember_t := 0.0
var _zap_t := 0.0
var _alarm := 0.0
var _harmony_t := 0.0

func setup(w: Node) -> void:
	world = w
	key = str(w.key)
	name = "Shrine"
	def = Game.shrine_def(key)
	layout = def.get("layout", [])
	order = def.get("order", [])
	st = Game.shrine(key)
	door_open = bool(st.get("door", false))
	door_k = 1.0 if door_open else 0.0
	floor_node = Node2D.new()
	floor_node.name = "ShrineFloor"
	floor_node.z_index = -8
	floor_node.draw.connect(_draw_floor)
	add_child(floor_node)
	beam_node = Node2D.new()
	beam_node.name = "Beam"
	beam_node.z_index = 3
	beam_node.material = Tex.add_material()
	beam_node.draw.connect(_draw_beam)
	add_child(beam_node)
	# water from the layout: deep (impassable until frozen) and shallow pools
	for y in layout.size():
		var row: String = layout[y]
		for x in row.length():
			var ch := row[x]
			if ch == "~":
				water[Vector2i(x, y)] = {"kind": "deep", "ice": 0.0, "solid": _solid(cell_rect(Vector2i(x, y)))}
			elif ch == "w":
				water[Vector2i(x, y)] = {"kind": "shallow"}
	for o in Game.map_data(key).get("v16objs", []):
		_piece(o)
	for k in def.get("sentinels", {}):
		var c: Array = str(k).split(",")
		var cc := Vector2i(int(c[0]), int(c[1]))
		var s: Dictionary = def["sentinels"][k]
		var sn := {"cell": cc, "pos": cell_rect(cc).get_center() + Vector2(0, 10), "base": float(s["base"]), "sweep": float(s["sweep"]),
			"period": float(s["period"]) / 1000.0, "phase": float(s["phase"]) / 1000.0, "ang": float(s["base"])}
		var nd := _tall(sn["pos"] + Vector2(0, 8))
		nd.draw.connect(func(): Art.watcher(nd, Art.stone(key), float(sn["ang"]), _alarm))
		sn["node"] = nd
		sn["solid"] = _solid(Rect2(sn["pos"] - Vector2(12, 12), Vector2(24, 20)))
		sentinels.append(sn)
	if def.has("oil"):
		var tr: Array = def["oil"][0] if typeof(def["oil"]) == TYPE_ARRAY and not def["oil"].is_empty() else []
		var pts := []
		for p in tr:
			pts.append(Vector2(float(p[0]), float(p[1])))
		var ln := 0.0
		for i in range(1, pts.size()):
			ln += pts[i - 1].distance_to(pts[i])
		oil = {"pts": pts, "len": ln, "burned": 0.0, "lit": false, "done": false}
	if door_open:
		_solved_look()
	# the tablet's words the first time you come in
	var tabs: Array = def.get("tablets", [])
	if not tabs.is_empty():
		world.tip("tablet_" + key, str(tabs[0][0]), str(tabs[0][1]))
	_beam()

# ---------------------------------------------------------------- grid
func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))

func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(Vector2(c) * CELL, Vector2(CELL, CELL))

func ch_at(c: Vector2i) -> String:
	if c.y < 0 or c.y >= layout.size() or c.x < 0 or c.x >= str(layout[c.y]).length():
		return "#"
	return str(layout[c.y])[c.x]

## a piece standing on a cell that blocks blocks, barrels and the light
func solid_at(c: Vector2i, skip = null) -> Variant:
	for o in objs:
		if o == skip or not SOLID_TYPES.has(o["t"]) or not o.get("on", true):
			continue
		if o.has("cell") and o["cell"] == c:
			return o
		if not o.has("cell") and o["rect"].intersects(cell_rect(c).grow(-4.0)):
			return o
	for s in sentinels:
		if s["cell"] == c:
			return s
	return null

# ---------------------------------------------------------------- building
func _solid(r: Rect2) -> Dictionary:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	cs.position = r.get_center()
	body.add_child(cs)
	add_child(body)
	world.wall_rects.append(r)
	return {"cs": cs, "wi": world.wall_rects.size() - 1, "on": true}

func _solid_set(s: Dictionary, on: bool, r := Rect2()) -> void:
	if s.is_empty():
		return
	s["on"] = on
	s["cs"].set_deferred("disabled", not on)
	if on and r.size != Vector2.ZERO:
		s["cs"].position = r.get_center()
	world.wall_rects[int(s["wi"])] = (r if r.size != Vector2.ZERO else Rect2(s["cs"].position - s["cs"].shape.size * 0.5, s["cs"].shape.size)) if on else Rect2(-9999, -9999, 1, 1)

## a standing piece: an outer node that the y-sort orders and an inner one it is drawn on. A piece right above a
## wall would be hidden by the wall's tall top, so it sorts as if it stood a cell lower ("lift") and draws back up.
func _tall(feet: Vector2) -> Node2D:
	var lift := _lift_for(cell_of(feet - Vector2(0, 2)))
	var outer := Node2D.new()
	outer.position = feet + Vector2(0, lift)
	world.ysort.add_child(outer)
	var n := Node2D.new()
	n.position = Vector2(0, -lift)
	outer.add_child(n)
	return n

func _lift_for(c: Vector2i) -> float:
	return 41.0 if ch_at(c + Vector2i(0, 1)) == "#" else 0.0

func _sprite(n: Node2D, sprite: String, mod := Color(1, 1, 1)) -> Sprite2D:
	var m: Dictionary = Game.obj_sprites.get(sprite, {})
	if m.is_empty():
		return null
	var spr := Sprite2D.new()
	spr.texture = load(Game.ART + "MapObjects/" + str(m.get("file", sprite)) + ".png")
	spr.centered = false
	spr.offset = Vector2(-float(m["w"]) * 0.5, -float(m["h"]))
	spr.scale = Vector2.ONE * Sheets.SCALE
	spr.modulate = mod
	n.add_child(spr)
	return spr

func _piece(src: Dictionary) -> void:
	var t := str(src.get("t", ""))
	if t == "water":
		return                      # the layout's "~" cells already are the water
	var o := {"t": t, "id": str(src.get("id", t + str(objs.size()))), "rect": Rect2(float(src["x"]), float(src["y"]), float(src["w"]), float(src["h"])),
		"seed": randf() * 10.0}
	if src.has("cx"):
		o["cell"] = Vector2i(int(src["cx"]), int(src["cy"]))
		o["home"] = o["cell"]
	var base := Art.stone(key)
	var feet: Vector2 = o["rect"].position + Vector2(o["rect"].size.x * 0.5, o["rect"].size.y)
	match t:
		"altar":
			var n := _tall(feet)
			n.add_to_group("npcs")
			n.set_meta("id", "altar")
			n.set_meta("name_en", "Shrine Altar")
			n.draw.connect(func(): Art.altar(n, base, altar_ready(), clock))
			_hint(n, -70.0)
			o["node"] = n
		"door", "cracked":
			o["needs"] = src.get("needs", [])
			var dr: Rect2 = cell_rect(o["cell"])
			o["rect"] = dr
			var n2 := _tall(dr.end - Vector2(CELL * 0.5, 0))
			if t == "door":
				n2.draw.connect(func(): Art.door(n2, base, door_k, _door_lit()))
			else:
				n2.draw.connect(func(): if not door_open: Art.cracked(n2, base))
			o["node"] = n2
		"brazier":
			var n3 := _tall(feet)
			_sprite(n3, "brazier_61")
			var f := Node2D.new()
			n3.add_child(f)
			f.draw.connect(func():
				if o.get("lit", false):
					Art.brazier_fire(f, clock, float(o["seed"]), (float(o["left"]) / float(o["timed"])) if o.has("timed") and not door_open else -1.0))
			o["node"] = f
			o["lit"] = false
			if src.has("timed"):
				o["timed"] = float(src["timed"]) / 1000.0
				o["left"] = 0.0
		"source":
			var n4 := _tall(feet)
			n4.draw.connect(func(): Art.eternal_flame(n4, base, clock, float(o["seed"])))
			o["node"] = n4
		"bramble":
			var n5 := _tall(cell_rect(o["cell"]).end - Vector2(CELL * 0.5, 2))
			o["burn"] = 0.0
			n5.draw.connect(func(): Art.bramble(n5, clock, float(o["seed"]), float(o["burn"])))
			o["node"] = n5
		"tablet":
			var n6 := _tall(feet)
			n6.add_to_group("npcs")
			n6.set_meta("id", "tablet")
			n6.set_meta("name_en", "Ancient Tablet")
			n6.draw.connect(func(): Art.tablet(n6, base))
			_hint(n6, -40.0)
			o["node"] = n6
		"block":
			var n7 := _tall(cell_rect(o["cell"]).end - Vector2(CELL * 0.5, 0))
			n7.draw.connect(func(): Art.block(n7, base, 1.0 if _on_heavy_plate(o) else 0.0))
			o["node"] = n7
			o["rect"] = cell_rect(o["cell"])
			o["push"] = true
		"barrel":
			var n8 := _tall(cell_rect(o["cell"]).end - Vector2(CELL * 0.5, 4))
			var spr := _sprite(n8, "barrel_12")
			o["spr"] = spr
			var fz := Node2D.new()
			n8.add_child(fz)
			fz.draw.connect(func():
				fz.draw_line(Vector2(0, -27), Vector2(3, -33), Art.OL, 2.0)
				if o.get("lit", false):
					Art._glow(fz, Vector2(3, -34), 9.0 + 3.0 * sin(clock * 30.0), Color(1, 0.7, 0.3, 0.8))
					fz.draw_circle(Vector2(3, -34), 2.5, Color(1, 0.95, 0.6)))
			o["fz"] = fz
			o["node"] = n8
			o["rect"] = cell_rect(o["cell"])
			o["push"] = true
			o["lit"] = false
		"lever":
			var n9 := _tall(feet)
			o["flip"] = 0.0
			n9.draw.connect(func(): Art.lever(n9, base, float(o["flip"])))
			o["node"] = n9
		"frost", "storm":
			var n10 := _tall(feet)
			n10.draw.connect(func():
				Art.pedestal(n10, base, 10.0)
				var col := Color(0.55, 0.9, 1.0) if t == "frost" else Color(0.85, 0.65, 1.0)
				Art._glow(n10, Vector2(0, -24), 22.0 + 3.0 * sin(clock * 3.0 + float(o["seed"])), Color(col, 0.45)))
			var cs := _sprite(n10, "smallcrystal_121", Color(0.75, 1.0, 1.25) if t == "frost" else Color(1.25, 0.85, 1.4))
			if cs:
				cs.position.y = -8
			o["node"] = n10
		"target":
			var n11 := _tall(feet)
			n11.draw.connect(func(): Art.target(n11, base, 1.0 if target_lit else 0.0, clock))
			o["node"] = n11
		"mirror":
			var n12 := _tall(cell_rect(o["cell"]).end - Vector2(CELL * 0.5, 3))
			o["o"] = int(src.get("o", 0))
			o["hit"] = 0.0
			n12.draw.connect(func(): Art.mirror(n12, base, int(o["o"]), float(o["hit"])))
			o["node"] = n12
		"icewall":
			var n13 := _tall(cell_rect(o["cell"]).end - Vector2(CELL * 0.5, 0))
			o["melt"] = 0.0
			o["rect"] = cell_rect(o["cell"])
			n13.draw.connect(func(): Art.icewall(n13, 1.0 - float(o["melt"])))
			o["node"] = n13
		"emitter":
			var n14 := _tall(feet)
			var d: Array = src.get("dir", def.get("emitDir", [1, 0]))
			o["dir"] = Vector2i(int(d[0]), int(d[1]))
			n14.draw.connect(func(): Art.emitter(n14, base, Vector2(o["dir"]), clock))
			o["node"] = n14
		"plate":
			o["heavy"] = bool(src.get("heavy", false))
		"rune":
			o["g"] = int(src.get("g", 1))
			o["n"] = int(src.get("n", 1))
			o["lit"] = false
		"mosaic":
			o["order"] = src.get("order", order)
	if SOLID_TYPES.has(t):
		var sr: Rect2 = o["rect"]
		if t in ["brazier", "source", "lever", "frost", "storm", "target", "emitter", "tablet", "altar"]:
			sr = Rect2(feet - Vector2(13, 16), Vector2(26, 16))
		elif t == "mirror":
			sr = cell_rect(o["cell"]).grow(-6.0)
		o["solid"] = _solid(sr)
	o["on"] = true
	objs.append(o)
	by_id[o["id"]] = o

func _hint(n: Node2D, y: float) -> void:
	var th := Node2D.new()
	th.name = "TalkHint"
	th.position = Vector2(0, y)
	th.z_index = 5
	th.visible = false
	th.draw.connect(world._draw_talk_hint.bind(th))
	n.add_child(th)
	world._talk_hints.append(th)

## a shrine solved before: the door stands open, its fires burn, its runes glow
func _solved_look() -> void:
	seq_done = true
	for o in objs:
		match o["t"]:
			"brazier":
				o["lit"] = true
			"rune":
				o["lit"] = true
			"bramble":
				o["burn"] = 1.0
				_off(o)
			"icewall":
				o["melt"] = 1.0
				_off(o)
			"door", "cracked":
				_off(o)
	if not oil.is_empty():
		oil["done"] = true
		oil["burned"] = oil["len"]
	if by_id.has("m0") or by_id.has("m1"):
		# the mirrors as the solution leaves them
		for o in objs:
			if o["t"] == "mirror":
				o["o"] = 1 - int(o["o"])

func _off(o: Dictionary) -> void:
	o["on"] = false
	if o.has("solid"):
		_solid_set(o["solid"], false)

# ---------------------------------------------------------------- state queries
func altar_ready() -> bool:
	return door_open and str(st.get("gift", "")) == ""

## the door's carved sigil: dark while shut, gold once it opens, and half-lit as the conditions come together
func _door_lit() -> float:
	if door_open:
		return 1.0
	var nd := needs()
	if nd.is_empty():
		return 0.0
	var n := 0
	for id in nd:
		if need_met(id):
			n += 1
	return 0.5 * float(n) / nd.size()

## what the inner door waits for (plate / brazier ids, "seq", "clear", "target"); the cracked wall wants a blast
func needs() -> Array:
	var d = by_id.get("door", null)
	if d == null or d["t"] != "door":
		return []
	return d.get("needs", [])

func need_met(id: String) -> bool:
	match id:
		"seq":
			return seq_done
		"clear":
			return alive_foes() == 0
		"target":
			return target_lit
	var o = by_id.get(id, null)
	if o == null:
		return false
	match o["t"]:
		"plate":
			return pressed(o)
		"brazier":
			return bool(o["lit"])
	return false

func alive_foes() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.world == world and not e.is_in_group("arena"):
			n += 1
	return n

func pressed(p: Dictionary) -> bool:
	for o in objs:
		if o.get("push", false) and o["cell"] == p["cell"] and o.get("on", true):
			return true
	if p.get("heavy", false):
		return false
	if hero != null and is_instance_valid(hero) and not hero.dead and p["rect"].has_point(hero.global_position + Vector2(0, -4)):
		return true
	return false

func _on_heavy_plate(b: Dictionary) -> bool:
	for o in objs:
		if o["t"] == "plate" and o["cell"] == b.get("cell", Vector2i(-1, -1)):
			return true
	return false

# ---------------------------------------------------------------- every frame
func _process(dt: float) -> void:
	clock += dt
	hero = get_tree().get_first_node_in_group("player")
	if hero != null and (hero.world != world or hero.dead):
		hero = null
	fire_t = max(0.0, fire_t - dt)
	frost_t = max(0.0, frost_t - dt)
	_wrong_t = max(0.0, _wrong_t - dt)
	_caught_t = max(0.0, _caught_t - dt)
	_alarm = max(0.0, _alarm - dt * 1.5)
	_harmony_t = max(0.0, _harmony_t - dt)
	if hero:
		_push(dt)
		_runes()
		_water_hero()
		_watchers(dt)
		_blade_fx(dt)
	_braziers(dt)
	_ice(dt)
	_storm(dt)
	_barrels(dt)
	_oil(dt)
	_lava_foes()
	_beam()
	if not door_open and door_k <= 0.0:
		var nd := needs()
		if not nd.is_empty() and nd.all(func(n): return need_met(n)):
			open_door()
	if door_open and door_k < 1.0:
		door_k = min(1.0, door_k + dt * 1.4)
	for o in objs:
		if o["t"] == "lever" and float(o["flip"]) > 0.0:
			o["flip"] = max(0.0, float(o["flip"]) - dt * 1.2)
		if o["t"] == "mirror" and float(o["hit"]) > 0.0:
			o["hit"] = max(0.0, float(o["hit"]) - dt * 2.0)
		if o["t"] == "bramble" and float(o["burn"]) > 0.0 and float(o["burn"]) < 1.0:
			o["burn"] = min(1.0, float(o["burn"]) + dt * 1.1)
		if o["t"] == "icewall" and float(o["melt"]) > 0.0 and float(o["melt"]) < 1.0:
			o["melt"] = min(1.0, float(o["melt"]) + dt * 1.6)
		if o.has("node") and is_instance_valid(o["node"]):
			o["node"].queue_redraw()
	for s in sentinels:
		s["ang"] = float(s["base"]) + float(s["sweep"]) * sin(TAU * (clock + float(s["phase"])) / float(s["period"]))
		s["node"].queue_redraw()
	floor_node.queue_redraw()
	beam_node.queue_redraw()

func open_door() -> void:
	if door_open:
		return
	door_open = true
	st["door"] = true
	for o in objs:
		if o["t"] == "door" or o["t"] == "cracked":
			_off(o)
	Sfx.play("door")
	Sfx.play("quest", -2.0)
	world.shake(4.0)
	var c := cell_rect(by_id["door"]["cell"]).get_center() if by_id.has("door") else Vector2(340, 140)
	if world.fx:
		world.fx.dust(c + Vector2(0, 16), 14, Vector2.ZERO, Color(0.6, 0.56, 0.5, 0.7))
		world.fx.flash_light(c, 160.0, 0.9, Color(1, 0.85, 0.5), 0.8)
	world.float_text(c + Vector2(0, -30), Game.t("The way is open", "راه باز شد"), Color(1, 0.88, 0.55), true)
	Game.save_game()

# ---------------------------------------------------------------- the hero's blows, spells and steps
## a melee swing: box is the blow's reach (player.attack)
func strike(box: Rect2, _fv: Vector2, _heavy: bool) -> void:
	if hero == null:
		hero = get_tree().get_first_node_in_group("player")
	for o in objs:
		if not o.get("on", true) or not o["rect"].grow(4.0).intersects(box):
			continue
		match o["t"]:
			"source":
				fire_t = FIRE_SEC
				frost_t = 0.0
				Sfx.play("nova", -12.0)
				if world.fx:
					world.fx.embers(o["rect"].get_center(), 10)
				_say(o["rect"].get_center() + Vector2(0, -40), Game.t("Your blade burns!", "تیغت شعله‌ور شد!"), Art.EMBER)
			"brazier":
				if fire_t > 0.0:
					light(o)
			"bramble":
				if fire_t > 0.0:
					burn(o)
			"barrel":
				if fire_t > 0.0:
					ignite_barrel(o)
			"icewall":
				if fire_t > 0.0:
					melt(o)
			"frost":
				frost_t = FROST_SEC
				fire_t = 0.0
				Sfx.play("ice", -4.0)
				_say(o["rect"].get_center() + Vector2(0, -40), Game.t("Your blade is frost-cold!", "تیغت یخ‌زده شد!"), Color(0.6, 0.9, 1.0))
			"storm":
				zap()
			"mirror":
				turn(o)
			"lever":
				reset_stones()
	if fire_t > 0.0 and not oil.is_empty() and not oil["lit"] and not oil["done"]:
		var p0: Vector2 = oil["pts"][0]
		if box.grow(12.0).has_point(p0):
			ignite_oil()
	if frost_t > 0.0:
		for c in water:
			var w: Dictionary = water[c]
			if w["kind"] == "deep" and float(w["ice"]) <= 0.0 and cell_rect(c).intersects(box):
				freeze(c)

## a spell's fire or frost (Ember Nova, the fire bolts, the ice lance) at p within r
func element(p: Vector2, r: float, status: String) -> void:
	if status == "burn":
		for o in objs:
			if not o.get("on", true) or o["rect"].get_center().distance_to(p) > r + 16.0:
				continue
			match o["t"]:
				"brazier":
					light(o)
				"bramble":
					burn(o)
				"barrel":
					ignite_barrel(o)
				"icewall":
					melt(o)
		if not oil.is_empty() and not oil["lit"] and not oil["done"] and (oil["pts"][0] as Vector2).distance_to(p) <= r + 12.0:
			ignite_oil()
	elif status == "freeze":
		for c in water:
			if water[c]["kind"] == "deep" and float(water[c]["ice"]) <= 0.0 and cell_rect(c).get_center().distance_to(p) <= r + 20.0:
				freeze(c)

## a shot at p: stops at the shrine's pieces, and carries its element
func shot_at(p: Vector2, status: String) -> bool:
	for o in objs:
		if o.get("on", true) and SOLID_TYPES.has(o["t"]) and o["rect"].has_point(p):
			if status != "":
				element(p, 18.0, status)
			return true
	if status == "freeze":
		var c := cell_of(p)
		if water.has(c) and water[c]["kind"] == "deep" and float(water[c]["ice"]) <= 0.0:
			freeze(c)
	return false

func light(o: Dictionary) -> void:
	if o["lit"] and not o.has("timed"):
		return
	o["lit"] = true
	if o.has("timed"):
		o["left"] = float(o["timed"])
	Sfx.play("nova", -10.0)
	if world.fx:
		world.fx.embers(o["rect"].get_center() + Vector2(0, -10), 8)
		world.fx.flash_light(o["rect"].get_center(), 120.0, 0.8, Art.EMBER, 0.4)

func burn(o: Dictionary) -> void:
	if float(o["burn"]) > 0.0:
		return
	o["burn"] = 0.01
	_off(o)
	Sfx.play("nova", -8.0)
	if world.fx:
		world.fx.smoke(o["rect"].get_center(), 8)

func melt(o: Dictionary) -> void:
	if float(o["melt"]) > 0.0:
		return
	o["melt"] = 0.01
	_off(o)
	Sfx.play("poof", -4.0)
	_say(o["rect"].get_center() + Vector2(0, -36), Game.t("Melted!"), Color(0.7, 0.9, 1.0))
	if world.fx:
		world.fx.emit("shine", o["rect"].get_center(), 12, Color(0.7, 0.92, 1.0), Vector2.UP, 90.0, 90.0)

func turn(o: Dictionary) -> void:
	o["o"] = 1 - int(o["o"])
	o["hit"] = 1.0
	Sfx.play("clank", -2.0)

func freeze(c: Vector2i) -> void:
	var w: Dictionary = water[c]
	w["ice"] = ICE_SEC
	_solid_set(w["solid"], false)
	Sfx.play("ice", -6.0, 0.15)
	if world.fx:
		world.fx.emit("shine", cell_rect(c).get_center(), 6, Color(0.8, 0.95, 1.0), Vector2.ZERO, 180.0, 60.0)

func zap() -> void:
	storm_t = STORM_SEC
	_zap_t = 0.0
	Sfx.play("bolt", -2.0)
	Sfx.play("stun", -6.0)
	world.shake(3.0)

func reset_stones() -> void:
	for o in objs:
		if o["t"] == "lever":
			o["flip"] = 1.0
	var moved := false
	for o in objs:
		if o.get("push", false) and o.get("on", true) and o["cell"] != o["home"]:
			var hr := cell_rect(o["home"])
			if hero and hero.body_rect().intersects(hr):
				continue
			if solid_at(o["home"], o) != null:
				continue
			_place(o, o["home"], false)
			moved = true
	Sfx.play("latch")
	if moved:
		_say(hero.global_position + Vector2(0, -50) if hero else Vector2(340, 300), Game.t("The stones return to their places."), Color(0.9, 0.85, 0.7))

func _say(p: Vector2, text: String, col: Color) -> void:
	world.float_text(p, text, col)

# ---------------------------------------------------------------- blocks and barrels
func _push(dt: float) -> void:
	var d: Vector2 = hero.get("move_dir") if hero.get("move_dir") != null else Vector2.ZERO
	if d.length() < 0.5 or hero.dash_t > 0.0:
		_push_t = 0.0
		_push_obj = null
		return
	var dir := Vector2i.ZERO
	if abs(d.x) > abs(d.y) * 1.4:
		dir = Vector2i(1 if d.x > 0 else -1, 0)
	elif abs(d.y) > abs(d.x) * 1.4:
		dir = Vector2i(0, 1 if d.y > 0 else -1)
	if dir == Vector2i.ZERO:
		_push_t = 0.0
		return
	var probe: Rect2 = hero.body_rect().grow(-4.0)
	probe.position += Vector2(dir) * 7.0
	var hit = null
	for o in objs:
		if o.get("push", false) and o.get("on", true) and not o.get("moving", false) and probe.intersects(o["rect"]):
			hit = o
			break
	if hit == null:
		_push_t = 0.0
		_push_obj = null
		return
	if hit != _push_obj or dir != _push_dir:
		_push_obj = hit
		_push_dir = dir
		_push_t = 0.0
	_push_t += dt
	if _push_t >= PUSH_HOLD:
		_push_t = -0.12
		push(hit, dir)

## push a block or barrel one cell; false if something is in the way
func push(o: Dictionary, dir: Vector2i) -> bool:
	var to: Vector2i = o["cell"] + dir
	if not can_enter(o, to):
		return false
	_place(o, to, true)
	Sfx.play("trap", -7.0, 0.1)
	if world.fx:
		world.fx.dust(cell_rect(o["cell"]).end - Vector2(20, 2), 5, -Vector2(dir), Color(0.6, 0.56, 0.5, 0.6))
	return true

func can_enter(o: Dictionary, to: Vector2i) -> bool:
	var ch := ch_at(to)
	if ch in ["#", "D", "K", "A", "^"] or to.y >= layout.size() - 1:
		return false                # never into the walls, the door or the way out
	if water.has(to):
		return false
	if ch == "l" and o["t"] != "barrel":
		return false
	if solid_at(to, o) != null:
		return false
	var r := cell_rect(to).grow(-3.0)
	if hero and hero.body_rect().intersects(r):
		return false
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.world == world and e.hit_rect().intersects(r):
			return false
	return true

func _place(o: Dictionary, to: Vector2i, slide: bool) -> void:
	o["cell"] = to
	var r := cell_rect(to)
	o["rect"] = r
	_solid_set(o["solid"], true, r)
	var feet := r.end - Vector2(CELL * 0.5, 4.0 if o["t"] == "barrel" else 0.0)
	var n: Node2D = o["node"]
	var outer: Node2D = n.get_parent()
	var lift := _lift_for(to)
	if slide:
		o["moving"] = true
		var tw := outer.create_tween()
		tw.set_parallel(true)
		tw.tween_property(outer, "position", feet + Vector2(0, lift), 0.16)
		tw.tween_property(n, "position", Vector2(0, -lift), 0.16)
		tw.chain().tween_callback(func():
			o["moving"] = false
			if o["t"] == "barrel" and ch_at(o["cell"]) == "l":
				explode(o))
	else:
		outer.position = feet + Vector2(0, lift)
		n.position = Vector2(0, -lift)

func ignite_barrel(o: Dictionary) -> void:
	if o.get("lit", false) or not o.get("on", true):
		return
	o["lit"] = true
	o["fuse"] = FUSE_SEC
	Sfx.play("charge", -4.0)
	_say(o["rect"].get_center() + Vector2(0, -40), Game.t("Run!", "فرار کن!"), Color(1, 0.6, 0.3))

func _barrels(dt: float) -> void:
	for o in objs:
		if o["t"] != "barrel":
			continue
		if o.get("respawn", 0.0) > 0.0:
			o["respawn"] = float(o["respawn"]) - dt
			if float(o["respawn"]) <= 0.0:
				if solid_at(o["home"], o) == null and not (hero and hero.body_rect().intersects(cell_rect(o["home"]))):
					o["on"] = true
					o["node"].visible = true
					_place(o, o["home"], false)
					o["node"].modulate = Color(1, 1, 1, 1)
				else:
					o["respawn"] = 0.5
			continue
		if not o.get("lit", false):
			continue
		o["fuse"] = float(o["fuse"]) - dt
		var blink := int(float(o["fuse"]) * (6.0 if float(o["fuse"]) > 1.0 else 14.0)) % 2 == 0
		o["node"].modulate = Color(1.5, 0.75, 0.6) if blink else Color(1, 1, 1)
		if world.fx and randf() < 0.4:
			world.fx.emit("spark", o["rect"].get_center() + Vector2(3, -14), 1, Color(1, 0.8, 0.4), Vector2.UP, 60.0, 90.0)
		if float(o["fuse"]) <= 0.0:
			explode(o)

func explode(o: Dictionary) -> void:
	if not o.get("on", true):
		return
	var c: Vector2 = o["rect"].get_center()
	o["lit"] = false
	_off(o)
	o["node"].visible = false
	o["respawn"] = 1.6
	Sfx.play("nova", 0.0)
	Sfx.play("trap", -2.0)
	world.shake(10.0)
	Game.vibrate(80, 1.0)
	if world.fx:
		world.fx.smoke(c, 14, Color(0.35, 0.3, 0.28, 0.75), 1.6)
		world.fx.emit("spark", c, 22, Color(1, 0.7, 0.3), Vector2.ZERO, 180.0, 380.0)
		world.fx.emit("debris", c, 14, Color(0.4, 0.3, 0.22), Vector2.ZERO, 180.0, 240.0)
		world.fx.ring(c, Color(1, 0.6, 0.25), BLAST_R, 0.4)
		world.fx.flash_light(c, 260.0, 1.0, Color(1, 0.65, 0.3), 0.6)
	if hero and hero.pc().distance_to(c) < BLAST_R:
		hero.take_hit(18.0)
		hero.knock((hero.pc() - c).normalized() * 30.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.world == world and e.center().distance_to(c) < BLAST_R:
			e.hurt(90.0, true, (e.center() - c).normalized() * 2.0, true)
	for w in objs:
		if w["t"] == "cracked" and w.get("on", true) and w["rect"].get_center().distance_to(c) < BLAST_R + 18.0:
			_off(w)
			if world.fx:
				world.fx.emit("debris", w["rect"].get_center(), 20, Art.stone(key).darkened(0.2), Vector2.ZERO, 180.0, 260.0)
			open_door()
	for b in objs:
		if b["t"] == "bramble" and b.get("on", true) and b["rect"].get_center().distance_to(c) < BLAST_R:
			burn(b)

# ---------------------------------------------------------------- braziers, oil, ice, storm, lava
func _braziers(dt: float) -> void:
	for o in objs:
		if o["t"] == "brazier" and o.has("timed") and o["lit"] and not door_open:
			o["left"] = float(o["left"]) - dt
			if float(o["left"]) <= 0.0:
				o["lit"] = false
				Sfx.play("poof", -10.0)
				if world.fx:
					world.fx.smoke(o["rect"].get_center() + Vector2(0, -16), 4)

func ignite_oil() -> void:
	oil["lit"] = true
	Sfx.play("nova", -8.0)

func _oil(dt: float) -> void:
	if oil.is_empty() or not oil["lit"] or oil["done"]:
		return
	oil["burned"] = float(oil["burned"]) + OIL_SPEED * dt
	if float(oil["burned"]) >= float(oil["len"]):
		oil["burned"] = oil["len"]
		oil["done"] = true
		var end: Vector2 = oil["pts"][oil["pts"].size() - 1]
		for o in objs:
			if o["t"] == "brazier" and o["rect"].get_center().distance_to(end) < 40.0:
				light(o)

func oil_front() -> Vector2:
	var left := float(oil.get("burned", 0.0))
	var pts: Array = oil.get("pts", [])
	for i in range(1, pts.size()):
		var ln: float = pts[i - 1].distance_to(pts[i])
		if left <= ln:
			return pts[i - 1].lerp(pts[i], left / ln)
		left -= ln
	return pts[pts.size() - 1] if not pts.is_empty() else Vector2.ZERO

func _ice(dt: float) -> void:
	for c in water:
		var w: Dictionary = water[c]
		if w["kind"] != "deep" or float(w["ice"]) <= 0.0:
			continue
		w["ice"] = float(w["ice"]) - dt
		if float(w["ice"]) <= 0.0:
			w["ice"] = 0.0
			if hero and cell_rect(c).has_point(hero.global_position + Vector2(0, -4)):
				splash()
			_solid_set(w["solid"], true, cell_rect(c))
			if world.fx:
				world.fx.emit("shine", cell_rect(c).get_center(), 5, Color(0.5, 0.75, 0.9), Vector2.UP, 60.0, 50.0)

## standing on thawing ice (or in the deep water some other way): out you climb where you last stood dry
func _water_hero() -> void:
	var feet: Vector2 = hero.global_position + Vector2(0, -4)
	var c := cell_of(feet)
	var wet: bool = water.has(c) and water[c]["kind"] == "deep"
	if wet and float(water[c]["ice"]) <= 0.0:
		splash()
	elif not wet and world.hazard_at(feet) == "":
		_safe = hero.global_position

func splash() -> void:
	if hero == null:
		return
	_say(hero.global_position + Vector2(0, -50), Game.t("SPLASH!", "شلپ!"), Color(0.6, 0.85, 1.0))
	Sfx.play("slime", 0.0)
	if world.fx:
		world.fx.emit("shine", hero.global_position + Vector2(0, -10), 12, Color(0.6, 0.85, 1.0), Vector2.UP, 70.0, 140.0)
	hero.global_position = _safe if _safe != Vector2.ZERO else world.start_feet()
	hero.take_hit(8.0)

func _storm(dt: float) -> void:
	if storm_t <= 0.0:
		return
	storm_t = max(0.0, storm_t - dt)
	_zap_t -= dt
	if _zap_t > 0.0:
		return
	_zap_t = 0.3
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.world != world:
			continue
		var c := cell_of(e.global_position + Vector2(0, -4))
		if water.has(c) and float(water[c].get("ice", 0.0)) <= 0.0:
			e.hurt(999.0, true, Vector2.ZERO, false)
			_say(e.global_position + Vector2(0, -40), Game.t("ZAP!", "صاعقه!"), Color(0.85, 0.75, 1.0))
	if hero:
		var hc := cell_of(hero.global_position + Vector2(0, -4))
		if water.has(hc) and water[hc]["kind"] == "shallow" and hero.invuln <= 0.0:
			hero.take_hit(12.0)

func _lava_foes() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.world != world or e.boss:
			continue
		if world.hazard_at(e.global_position + Vector2(0, -3)) == "lava":
			_say(e.global_position + Vector2(0, -40), Game.t("LAVA!", "گدازه!"), Color(1, 0.55, 0.25))
			e.hurt(9999.0, true, Vector2.ZERO, false)

# ---------------------------------------------------------------- runes
func _runes() -> void:
	var feet: Vector2 = hero.global_position + Vector2(0, -4)
	var on = null
	for o in objs:
		if o["t"] == "rune" and o["rect"].has_point(feet):
			on = o
	if on != null and on != _rune_on:
		step_rune(on)
	_rune_on = on

func step_rune(o: Dictionary) -> void:
	if seq_done or order.is_empty():
		return
	if o["lit"]:
		return
	var want := int(order[seq]) if seq < order.size() else -1
	if int(o["g"]) == want:
		o["lit"] = true
		seq += 1
		Sfx.play("shield", -2.0)
		if seq >= order.size():
			seq_done = true
			_harmony_t = 1.5
			Sfx.play("quest", -2.0)
			_say(o["rect"].get_center() + Vector2(0, -36), Game.t("The runes sing in harmony."), Color(1, 0.85, 0.5))
	else:
		for r in objs:
			if r["t"] == "rune":
				r["lit"] = false
		seq = 0
		_wrong_t = 0.8
		Sfx.play("error")
		_say(o["rect"].get_center() + Vector2(0, -36), Game.t("Wrong order — the runes go dark. Read the mosaic."), Color(1, 0.5, 0.4))

# ---------------------------------------------------------------- the Watchers
func _watchers(_dt: float) -> void:
	if sentinels.is_empty() or door_open or _caught_t > 0.0:
		return
	var feet: Vector2 = hero.global_position + Vector2(0, -6)
	for s in sentinels:
		var how := watcher_sees(s, feet, hero.sneaking, world.in_grass(hero.global_position), hero.moving)
		if how != "":
			catch(how)
			return

## "" or "saw" / "heard": a Watcher's light reaches the feet, or loud steps come close
func watcher_sees(s: Dictionary, feet: Vector2, sneaking: bool, in_grass: bool, moving: bool) -> String:
	var to: Vector2 = feet - s["pos"]
	var d := to.length()
	if d < CONE_RANGE and abs(angle_difference(float(s["ang"]), to.angle())) < CONE_HALF and not (sneaking and in_grass):
		return "saw"
	if not sneaking and moving and d < HEAR_R:
		return "heard"
	return ""

func catch(how: String) -> void:
	caught += 1
	_caught_t = 1.5
	_alarm = 1.0
	Sfx.play("error")
	Sfx.play("roar", -14.0)
	_say(hero.global_position + Vector2(0, -52), Game.t("A Watcher saw you!") if how == "saw" else Game.t("A Watcher heard your steps!"), Color(1, 0.45, 0.35))
	if world.fx:
		world.fx.ring(hero.pc(), Color(1, 0.4, 0.3), 30.0, 0.4)
	hero.global_position = world.start_feet()
	_safe = hero.global_position
	world.shake(3.0)

# ---------------------------------------------------------------- the light
## trace the light from the emitter through the mirrors (/ turns right->up, \ turns right->down)
func _beam() -> void:
	beam.clear()
	var em = null
	for o in objs:
		if o["t"] == "emitter":
			em = o
	if em == null:
		return
	var c: Vector2i = em["cell"]
	var d: Vector2i = em["dir"]
	beam.append(cell_rect(c).get_center() + Vector2(0, -14))
	var lit := false
	for i in 80:
		c += d
		var ch := ch_at(c)
		var center := cell_rect(c).get_center() + Vector2(0, -14)
		if ch == "#" or ch == "D":
			beam.append(center - Vector2(d) * CELL * 0.5)
			break
		var o = solid_at(c)
		if o != null and o.get("t", "") == "mirror":
			beam.append(center)
			d = Vector2i(-d.y, -d.x) if int(o["o"]) == 0 else Vector2i(d.y, d.x)
			o["hit"] = max(float(o["hit"]), 0.6)
			continue
		if o != null and o.get("t", "") == "target":
			beam.append(center)
			lit = true
			break
		if o != null:
			beam.append(center - Vector2(d) * CELL * 0.45)
			break
	if lit and not target_lit:
		Sfx.play("found", -4.0)
		if world.fx:
			world.fx.flash_light(beam[beam.size() - 1], 200.0, 1.0, Color(1, 0.9, 0.55), 0.6)
	target_lit = lit or (door_open and by_id.has("target"))

# ---------------------------------------------------------------- the altar
## the altar's gold and treasure (once): returns the toast lines
func claim() -> Array:
	if not door_open or bool(st.get("claimed", false)):
		return []
	st["claimed"] = true
	var g := int(round(float(def.get("gold", 100)) * Game.gold_mul()))
	Game.state["gold"] = int(Game.state.get("gold", 0)) + g
	var lines := [Game.t("+%d gold" % g, "+%s سکه" % Game.num(g))]
	Gear.grant(Gear.roll(str(def.get("acc", "rare"))))
	Sfx.play("found")
	Sfx.play("coin", -2.0)
	if world.fx:
		var c := Vector2(340, 60)
		world.fx.emit("shine", c, 24, Color(1, 0.88, 0.5), Vector2.UP, 80.0, 160.0)
		world.fx.flash_light(c, 220.0, 1.0, Color(1, 0.85, 0.5), 0.8)
	Game.stats_changed.emit()
	Game.save_game()
	return lines

# ---------------------------------------------------------------- drawing
func _draw_floor() -> void:
	var base := Art.stone(key)
	for c in water:
		var w: Dictionary = water[c]
		var r := cell_rect(c)
		if w["kind"] == "deep":
			if float(w["ice"]) > 0.0:
				Art.ice(floor_node, r, 1.0 if float(w["ice"]) < ICE_WARN else 0.0, clock)
			else:
				Art.water(floor_node, r, clock, float(c.x * 7 + c.y * 3))
		else:
			Art.shallow(floor_node, r, clock, float(c.x * 5 + c.y))
		if storm_t > 0.0 and float(w.get("ice", 0.0)) <= 0.0:
			Art.storm_arcs(floor_node, r, clock, float(c.x + c.y * 3))
	if not oil.is_empty():
		Art.oil(floor_node, oil["pts"], float(oil["burned"]) if oil["lit"] else 0.0, oil["done"], clock)
	var runes := []
	var room := Rect2(40, 160, 600, 320)
	for o in objs:
		match o["t"]:
			"plate":
				Art.plate(floor_node, o["rect"], base, bool(o["heavy"]), pressed(o))
			"rune":
				Art.rune(floor_node, o["rect"], base, int(o["g"]), 1.0 if o["lit"] or _harmony_t > 0.0 else 0.0, _wrong_t)
				runes.append({"c": o["rect"].get_center(), "g": o["g"], "n": o["n"]})
	for o in objs:
		if o["t"] == "mosaic":
			Art.mosaic(floor_node, o["rect"], base, runes, room)
	if not door_open:
		for s in sentinels:
			Art.cone(floor_node, s["pos"], float(s["ang"]), CONE_HALF, CONE_RANGE, _alarm)

func _draw_beam() -> void:
	if beam.size() < 2:
		return
	var pts := PackedVector2Array(beam)
	var p := 0.85 + 0.15 * sin(clock * 9.0)
	beam_node.draw_polyline(pts, Color(1, 0.85, 0.45, 0.25 * p), 14.0, true)
	beam_node.draw_polyline(pts, Color(1, 0.92, 0.65, 0.55 * p), 6.0, true)
	beam_node.draw_polyline(pts, Color(1, 1, 0.95, 0.9), 2.0, true)

## the hero's burning or frost-cold blade
func _blade_fx(dt: float) -> void:
	_ember_t -= dt
	if _ember_t > 0.0 or world.fx == null:
		return
	_ember_t = 0.07
	var hand: Vector2 = hero.global_position + Vector2(0, -18) + hero.facing_vec() * 10.0
	if fire_t > 0.0 and (fire_t > 2.5 or int(fire_t * 8.0) % 2 == 0):
		world.fx.embers(hand, 2)
	elif frost_t > 0.0 and (frost_t > 2.5 or int(frost_t * 8.0) % 2 == 0):
		world.fx.emit("shine", hand, 2, Color(0.7, 0.92, 1.0), Vector2.UP, 60.0, 40.0)

## lights for the light map: [pos, radius, intensity, colour]
func lights_now() -> Array:
	var out := []
	var f := 0.92 + 0.08 * sin(clock / 0.097)
	for o in objs:
		if not o.get("on", true) and o["t"] != "brazier":
			continue
		var c: Vector2 = o["rect"].get_center()
		match o["t"]:
			"brazier":
				if o["lit"]:
					out.append([c + Vector2(0, -14), 135.0 * f, 0.85, Art.EMBER])
			"source":
				out.append([c + Vector2(0, -20), 150.0 * f, 0.9, Color(1, 0.62, 0.3)])
			"frost":
				out.append([c, 70.0, 0.5, Color(0.55, 0.9, 1.0)])
			"storm":
				out.append([c, 70.0, 0.5, Color(0.85, 0.65, 1.0)])
			"emitter":
				out.append([c, 90.0, 0.7, Color(1, 0.95, 0.75)])
			"target":
				if target_lit:
					out.append([c, 160.0, 0.95, Color(1, 0.88, 0.5)])
			"barrel":
				if o.get("lit", false):
					out.append([c + Vector2(0, -16), 60.0, 0.8, Color(1, 0.7, 0.3)])
			"altar":
				if altar_ready():
					out.append([c + Vector2(0, -30), 110.0, 0.7, Color(1, 0.85, 0.5)])
			"rune":
				if o["lit"]:
					out.append([c, 60.0, 0.5, Art.EMBER])
	for i in range(0, beam.size() - 1):
		var a: Vector2 = beam[i]
		var b: Vector2 = beam[i + 1]
		var n := int(a.distance_to(b) / 80.0) + 1
		for k in n + 1:
			out.append([a.lerp(b, float(k) / n), 70.0, 0.55, Color(1, 0.92, 0.65)])
	for s in sentinels:
		out.append([s["pos"] + Vector2(0, -24), 48.0, 0.6, Color(1, 0.75, 0.35)])
	if not oil.is_empty() and oil["lit"] and not oil["done"]:
		out.append([oil_front(), 90.0 * f, 0.85, Art.EMBER])
	if hero and fire_t > 0.0:
		out.append([hero.global_position + Vector2(0, -18), 100.0 * f, 0.6, Art.EMBER])
	return out

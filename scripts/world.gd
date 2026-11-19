extends Node2D
## One map, built from the exported data: ground, y-sorted objects, wall collisions,
## map exits, hazards, villagers and enemies. Coordinates are the HTML game's logical pixels.

signal exit_reached(to: String, spawn_feet: Vector2)
signal message(text: String)
signal boss_down(text: String)
signal parley_started                # (v0.9) the Thornwood bandits want a word
signal boss_engaged(boss: Node)
signal boss_victory(boss: Node)
signal banner(big: String, small: String, col: Color, sec: float)
signal tip_shown(text: String)
signal level_up(level: int)
signal notice(text: String, icon: String)          # (v0.19) a toast with its own icon (chapter 2)
signal lore(title: String, lines: Array)           # (v0.19) a text to read (the expedition's journal pages)
signal lore_sheet(title: String, lines: Array, sheet: String)   # (v0.24) the same, with the speaker's portrait

const Sheets = preload("res://scripts/sheets.gd")
const Toll = preload("res://scripts/toll.gd")
const Trial = preload("res://scripts/trial.gd")
var trial: Node = null
const Enemy = preload("res://scripts/enemy.gd")
const Boss = preload("res://scripts/boss.gd")
const ArenaObj = preload("res://scripts/arena_obj.gd")
const BossFx = preload("res://scripts/bossfx.gd")
const Hazards = preload("res://scripts/hazards.gd")
const FloatText = preload("res://scripts/float_text.gd")
const Fx = preload("res://scripts/fx/fx.gd")
const Lighting = preload("res://scripts/fx/lighting.gd")
const Atmos = preload("res://scripts/fx/atmos.gd")
const PropsFx = preload("res://scripts/fx/props_fx.gd")
const Loot = preload("res://scripts/fx/loot.gd")
const Compass = preload("res://scripts/fx/compass.gd")
const Spells = preload("res://scripts/fx/spells.gd")
const Shrine = preload("res://scripts/shrine.gd")
const ShrineArt = preload("res://scripts/fx/shrine_art.gd")
var shrine: Node = null          # (v0.18) the puzzle of a shrine map
const Vault = preload("res://scripts/vault.gd")
var vault: Node = null           # (v0.19) Sorush's rimeglass vault (Crystal Sanctum)
const Fountain = preload("res://scripts/fx/fountain.gd")
const Terrain = preload("res://scripts/fx/terrain.gd")
const Altars = preload("res://scripts/altars.gd")
var altars: Node = null          # (v0.23) the fire temple's three altars (Slopes of Damavand)
var fountain: Node = null        # (v0.20) Zabol's fountain

const WALL_LAYER := 1
const NATURAL := ["tree", "pine", "bush", "rock", "stump", "willow", "deadtree", "reeds", "boulders"]   # (v0.35) may be mirrored
const NPC_LOOKS := ["elder", "smith", "merchant", "alchemist", "brann", "keeper", "hesk", "qaren"]
## villagers who can have news ("!" over their heads): the Elder (his quests, chapters 2 and 3), Sorush, Jamshid, Hom,
## (v0.23) Kaveh and his son Qaren
const NEWS_NPCS := ["elder", "keeper", "brann", "hesk", "smith", "qaren", "rostam"]
## (v0.24) the Shahnameh's heroes are people of the tale now: drawn from the heroes' own sheets, each in his colours
const HERO_NPCS := {"rostam": ["warrior_endgame", "npc_rostam"], "siavash": ["paladin_endgame", "npc_siavash"],
	"gordafarid": ["rogue_endgame", "npc_gordafarid"]}
const Looks = preload("res://scripts/looks.gd")
const Training = preload("res://scripts/training.gd")
var training: Node = null       # (v0.24) Rostam's yard: the post and his drills

var grass: Array[Rect2] = []   # tall-grass patches (v0.7): a sneaking hero is hard to see in them
var key := ""
var data := {}
var size := Vector2(1000, 800)
var ysort: Node2D
var hazards: Array = []
var wall_rects: Array[Rect2] = []
var bossfx: Node2D
var fx: Node2D
var lighting: CanvasLayer
var atmos: CanvasLayer
var props: Node2D
var loot: Node2D
var spells: Node2D               # the hero's spells in flight (v0.6)
var hazard_layer: Node2D
var exits_armed := false
var rush := false                # (v0.21) this map is a memory of the Boss Rush: only its boss, no way out, a cold tint
var stats := {"walls": 0, "objects": 0, "exits": 0, "npcs": 0, "enemies": 0, "hazards": 0}
var enemy_tactics_clock := 0.0
var enemy_volley_ready_at := 0.0

func build(map_key: String) -> void:
	key = map_key
	name = "World_" + map_key
	rush = not Game.rush.is_empty() and str(Game.rush.get("map", "")) == map_key
	var md: Dictionary = Game.map_data(map_key)
	data = md.get("data", {})
	size = Vector2(float(data.get("w", 1000)), float(data.get("h", 800)))

	var ground := Sprite2D.new()
	ground.name = "Ground"
	ground.centered = false
	ground.texture = load(Game.ART + "Maps/" + map_key + "_ground.jpg")
	ground.scale = Vector2.ONE / float(md.get("groundScale", 2.0))
	ground.z_index = -10
	add_child(ground)
	# (v0.35) a map with painted terrain draws its ground from tiled textures; the old picture stays (hidden) for the
	# minimap and the world map
	var terrain := Terrain.new()
	if terrain.setup(map_key, size, APRON_W):
		add_child(terrain)
		ground.visible = false
	else:
		terrain.free()
	# (v0.24) the apron past the edges, where the camera may now slide (game_camera.gd APRON)
	var apron := Node2D.new()
	apron.name = "Apron"
	apron.z_index = -11
	apron.draw.connect(_draw_apron.bind(apron, null if not ground.visible else ground.texture, float(md.get("groundScale", 2.0))))
	if not ground.visible:
		apron.z_index = -9
	add_child(apron)

	bossfx = BossFx.new()
	bossfx.world = self
	add_child(bossfx)

	ysort = Node2D.new()
	ysort.name = "YSort"
	ysort.y_sort_enabled = true
	add_child(ysort)

	fx = Fx.new()
	add_child(fx)
	fx.setup(self)
	loot = Loot.new()
	loot.setup(self, fx.overlay)
	var compass := Compass.new()
	compass.setup(self, fx.overlay)
	spells = Spells.new()
	spells.setup(self, fx.overlay)
	lighting = Lighting.new()
	add_child(lighting)
	lighting.setup(self, _arr(md.get("lights")))
	props = PropsFx.new()
	add_child(props)
	props.setup(self)

	for g in _arr(md.get("grass")):
		grass.append(Rect2(float(g["x"]), float(g["y"]), float(g["w"]), float(g["h"])))
	for o in md.get("objects", []):
		_object(o)
	for w in data.get("walls", []):
		_wall(Rect2(float(w["x"]), float(w["y"]), float(w["w"]), float(w["h"])))
	_edges()
	for hz in _arr(data.get("hazards")):
		# an untyped hazard is lava (the Ashen Peaks), exactly as in the HTML game
		var ht := str(hz.get("type", ""))
		hazards.append({"rect": Rect2(float(hz["x"]), float(hz["y"]), float(hz["w"]), float(hz["h"])), "type": ht if ht != "" else "lava", "tick": 0.0})
	stats["hazards"] = hazards.size()
	var hz_layer := Hazards.new()
	hz_layer.setup(self, hazards, _arr(data.get("chLava")))
	add_child(hz_layer)
	hazard_layer = hz_layer
	stats["vents"] = hz_layer.vents.size()
	for ex in _arr(data.get("exits")):
		_exit(ex)
		if not rush and str(ex.get("to", "")).begins_with("shrine_") and not Game.shrine_def(str(ex["to"])).is_empty():
			_shrine_gate(ex)
	if rush:
		var cm := CanvasModulate.new()
		cm.name = "Memory"
		cm.color = Color(0.8, 0.87, 1.0)
		add_child(cm)
	elif key == "village":
		_board()
		_arena_gate()
		training = Training.new()
		add_child(training)
		training.setup(self)
		fountain = Fountain.new()
		fountain.setup(self, Game.table("FOUNTAIN"))
	if key == "sanctum" and not rush:
		_ch2_sanctum()
	if key == "peaks" and not rush:
		# the Kindling door (v0.13): the road to the Emberforge, sealed until Jamshid hands over the key
		_exit({"x": 520, "y": 790, "w": 110, "h": 16, "to": "emberforge", "spawnX": 30, "spawnY": 500, "dir": "up"})
		_door_visual()
		_ch3_rubble()
	if key == "damavand" and not rush:
		_ch3_damavand()
	if key == "zahhakcave":
		_ch3_cave()
	for n in _arr(data.get("npcs")):
		if not rush:
			_npc(n)
	for s in _arr(data.get("enemySpawns")):
		if rush and str(s["type"]) != str(Game.rush.get("type", "")):
			continue
		if not rush and Game.is_boss_type(str(s["type"])) and Game.is_defeated(str(s["type"])):
			continue
		var d := Game.enemy_def(str(s["type"]))
		var feet := Vector2(float(s["x"]) + float(d.get("w", 24)) * 0.5, float(s["y"]) + float(d.get("h", 24)))
		if not Game.BOSS_CFG.has(str(s["type"])):
			feet = _clear_feet(feet, float(d.get("w", 24)) * 0.5)
		var se: Node = spawn_enemy(str(s["type"]), feet)
		if not Game.testing and Game.lvl() >= 3 and not Game.BOSS_CFG.has(str(s["type"])) and key != "village" and randf() < Game.elite_chance():
			var elite_pool: Array[String] = Game.elite_pool(key)
			se.make_elite(elite_pool[randi() % elite_pool.size()])
	if key == "trial":
		trial = Trial.new()
		trial.world = self
		add_child(trial)
	if key.begins_with("shrine_") and not Game.shrine_def(key).is_empty():
		shrine = Shrine.new()
		add_child(shrine)
		shrine.setup(self)
	if not rush:
		_camp_setup()
		_items_setup()
	_update_markers()
	Game.stats_changed.connect(_update_markers)
	atmos = Atmos.new()
	add_child(atmos)
	atmos.setup(self)
	# exits switch on a moment after arriving, so you never bounce straight back
	get_tree().create_timer(0.6).timeout.connect(_arm_exits)

## (v0.27, QA: "walk into an exit in the first 0.6 s and it never fires while you stay in it") once the exits are armed,
## a hero standing in one is taken through it as soon as he has moved from where he arrived (never on arrival itself)
var _arrived_at := Vector2.INF
func _arm_exits() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	exits_armed = not rush
	var t := Timer.new()
	t.wait_time = 0.25
	t.autostart = true
	t.timeout.connect(_exit_watch)
	add_child(t)

func _exit_watch() -> void:
	if not exits_armed or _arrived_at == Vector2.INF:
		return
	var p: Node2D = get_tree().get_first_node_in_group("player")
	if p == null or not is_ancestor_of(p) or p.global_position.distance_to(_arrived_at) < 20.0:
		return
	for a in get_tree().get_nodes_in_group("exits"):
		if a.get_parent() == self and a.overlaps_body(p):
			for c in a.body_entered.get_connections():
				c["callable"].call(p)
			return

func _arr(v) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []

func start_feet() -> Vector2:
	var s = data.get("playerStart", null)
	if typeof(s) == TYPE_DICTIONARY:
		return Vector2(float(s["x"]) + 13.0, float(s["y"]) + 34.0)
	return size * 0.5

# ---------------------------------------------------------------- pieces
func _object(o: Dictionary) -> void:
	var nm := str(o.get("sprite", ""))
	if nm == "":
		return
	var m: Dictionary = Game.obj_sprites.get(nm, {})
	if m.is_empty():
		return
	var spr := Sprite2D.new()
	# identical pictures are stored once ("file" names the shared one)
	spr.texture = load(Game.ART + "MapObjects/" + str(m.get("file", nm)) + ".png")
	spr.centered = false
	spr.offset = Vector2(-float(m["w"]) * 0.5, -float(m["h"]) * (1.0 - float(m["pivot"][1])))
	spr.scale = Vector2.ONE * Sheets.SCALE
	spr.position = Vector2(float(o["x"]), float(o["y"]))
	# (v0.35) the same tree or rock placed many times faces either way (fixed by its place, so it never changes)
	if str(o.get("kind", "")) in NATURAL and (int(o["x"]) * 7 + int(o["y"]) * 13) % 2 == 1:
		spr.flip_h = true
	ysort.add_child(spr)
	props.add_prop(o, spr, m)
	stats["objects"] += 1

func _wall(r: Rect2) -> void:
	wall_rects.append(r)
	var body := StaticBody2D.new()
	body.collision_layer = WALL_LAYER
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.position + r.size * 0.5
	body.add_child(cs)
	add_child(body)
	stats["walls"] += 1

func _edges() -> void:
	var t := 200.0
	for r in [Rect2(-t, -t, size.x + 2 * t, t), Rect2(-t, size.y, size.x + 2 * t, t), Rect2(-t, 0, t, size.y), Rect2(size.x, 0, t, size.y)]:
		_wall(r)
	stats["walls"] -= 4

func _exit(ex: Dictionary) -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(float(ex["w"]), float(ex["h"]))
	cs.shape = shape
	cs.position = Vector2(float(ex["x"]), float(ex["y"])) + shape.size * 0.5
	area.add_child(cs)
	var to := str(ex["to"])
	var spawn := Vector2(float(ex.get("spawnX", 0)) + 13.0, float(ex.get("spawnY", 0)) + 34.0)
	area.body_entered.connect(_on_exit_body.bind(to, spawn))
	area.set_meta("to", to)
	area.set_meta("rect", Rect2(cs.position - shape.size * 0.5, shape.size))
	area.add_to_group("exits")
	add_child(area)
	stats["exits"] += 1

func _on_exit_body(b: Node, to: String, spawn: Vector2) -> void:
	if not (exits_armed and b.is_in_group("player")) or is_queued_for_deletion():
		return
	# the sealed eastern path: closed until Zal sends you to the peaks
	if to == "peaks" and Game.q(2) == "not_started":
		message.emit(Game.t("A searing seal blocks the eastern path.\n(Zal may know more)", "مهری سوزان راه شرق را بسته است.\n(شاید زال چیزی بداند)"))
		Sfx.play("latch")
		var back: Vector2 = (b.global_position - Vector2(size.x * 0.5, size.y * 0.5)).normalized()
		b.global_position -= back * 40.0
		return
	if to == "emberforge" and not Game.brann_key():
		message.emit(Game.Story.line("sealed"))
		Sfx.play("latch")
		b.global_position += Vector2(0, 40)
		return
	# (v0.19) chapter 2: the rimeglass east of the Sanctum, the Wyrm's door behind the Judge's seat;
	# (v0.23) chapter 3: the rockfall on the road to Damavand, the Gate of Damavand
	var blk: String = Game.Ch2.exit_block(to)
	if blk == "":
		blk = Game.Ch3.exit_block(to)
	if blk != "":
		message.emit(blk)
		Sfx.play("latch")
		Sfx.play("ice", -8.0)
		var back2: Vector2 = (b.global_position - Vector2(size.x * 0.5, size.y * 0.5)).normalized()
		b.global_position -= back2 * 40.0
		return
	# (v0.23, playtest: a roll in Arzhang's arena carried the hero out through the shrine's door) no way out mid-fight
	for bo in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(bo) and not bo.dead and bo.engaged and bo.world == self and not rush \
				and bo.center().distance_to(b.global_position) < 400.0:
			message.emit(Game.t("%s bars the way — the fight is not over." % Game.boss_name(bo.type), "%s راه را بسته — نبرد تمام نشده." % Game.boss_name(bo.type)))
			Sfx.play("latch")
			var back3: Vector2 = (b.global_position - Vector2(size.x * 0.5, size.y * 0.5)).normalized()
			b.global_position -= back3 * 40.0
			return
	exits_armed = false
	# a door into (or out of) a crypt, a forge or a hall; a rustle of cloth on an open road
	if Game.indoor(to) or Game.indoor(key):
		Sfx.play("door")
	else:
		Sfx.play("dodge", -4.0)
	exit_reached.emit(to, spawn)

## the ground mirrored a little past each edge and corner, darkening outward: the camera may slide there (game_camera.gd)
const APRON_W := 520.0
func _draw_apron(ap: Node2D, tex: Texture2D, gs: float) -> void:
	var w := size.x
	var h := size.y
	var m: float = min(APRON_W, w, h)
	var g := gs
	# [origin, scale, dest rect in map space]: each strip is the edge of the map folded outward
	var parts := [
		[Vector2.ZERO, Vector2(-1, 1), Rect2(0, 0, m, h)], [Vector2(2 * w, 0), Vector2(-1, 1), Rect2(w - m, 0, m, h)],
		[Vector2.ZERO, Vector2(1, -1), Rect2(0, 0, w, m)], [Vector2(0, 2 * h), Vector2(1, -1), Rect2(0, h - m, w, m)],
		[Vector2.ZERO, Vector2(-1, -1), Rect2(0, 0, m, m)], [Vector2(2 * w, 0), Vector2(-1, -1), Rect2(w - m, 0, m, m)],
		[Vector2(0, 2 * h), Vector2(-1, -1), Rect2(0, h - m, m, m)], [Vector2(2 * w, 2 * h), Vector2(-1, -1), Rect2(w - m, h - m, m, m)],
	]
	# (v0.35) painted terrain runs on past the edge by itself: only the darkness is drawn here, over it
	if tex != null:
		for p in parts:
			var r: Rect2 = p[2]
			ap.draw_set_transform(p[0], 0.0, p[1])
			ap.draw_texture_rect_region(tex, r, Rect2(r.position * g, r.size * g))
		ap.draw_set_transform(Vector2.ZERO)
	# darkness falling outward from the edge
	var d := Color(0.05, 0.04, 0.035)
	# (v0.35) over painted terrain, which runs on unbroken, a step of shade at the edge reads as a drawn line: start clear
	var a0 := Color(d, 0.3 if tex != null else 0.0)       # (v0.26, playtest: "in the crypt the floor just goes on; I cannot see where the map ends")
	var a1 := Color(d, 0.97)
	var o := m
	ap.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(0, h), Vector2(-o, h + o), Vector2(-o, -o)]), PackedColorArray([a0, a0, a1, a1]))
	ap.draw_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w + o, -o), Vector2(w + o, h + o), Vector2(w, h)]), PackedColorArray([a0, a1, a1, a0]))
	ap.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-o, -o), Vector2(w + o, -o), Vector2(w, 0)]), PackedColorArray([a0, a1, a1, a0]))
	ap.draw_polygon(PackedVector2Array([Vector2(0, h), Vector2(w, h), Vector2(w + o, h + o), Vector2(-o, h + o)]), PackedColorArray([a0, a0, a1, a1]))
	# the edge itself: a thin dark seam where the map ends
	if tex != null:
		ap.draw_rect(Rect2(-1.0, -1.0, w + 2.0, h + 2.0), Color(d, 0.55), false, 2.0)

func _npc(n: Dictionary) -> void:
	var id := str(n.get("id", ""))
	var look: String = id if id in NPC_LOOKS else "merchant"
	var feet := Vector2(float(n["x"]) + float(n.get("w", 26)) * 0.5, float(n["y"]) + float(n.get("h", 34)))
	var node := Node2D.new()
	node.position = feet
	node.add_to_group("npcs")
	var hero_sheet := ""
	# (v0.30) a hero of the tale with his own painted sheet (Npcs/<id>.png) is drawn from it; until he has one, from a
	# calling's sheet in his own colours (v0.24)
	if HERO_NPCS.has(id):
		if Game.manifest.get("npcs", {}).has(id):
			look = id
		else:
			hero_sheet = str(HERO_NPCS[id][0])
	var ch: Dictionary = Sheets.character("heroes", hero_sheet) if hero_sheet != "" else Sheets.character("npcs", look)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = ch["frames"]
	spr.animation = "idle_down"
	spr.centered = false
	spr.offset = ch["offset"]
	spr.scale = Vector2.ONE * Sheets.SCALE
	spr.position.y = 2
	node.add_child(spr)
	# (v0.24) Rostam stands a head over the others
	var tall: float = 1.18 if id == "rostam" else 1.0
	spr.scale *= tall
	var lift: float = (tall - 1.0) * 48.0
	if id == "brann":
		spr.modulate = Color(0.78, 0.9, 1.0, 0.78)      # (v0.25) Jamshid is a shade: pale, half seen
	node.set_meta("lift", lift)
	if hero_sheet != "":
		Looks.apply(spr, hero_sheet, str(HERO_NPCS[id][1]))
		node.set_meta("sheet", "hero:" + hero_sheet)
	elif HERO_NPCS.has(id):
		node.set_meta("sheet", "npc:" + id)
	Fx.shadow_for(node, 26, 34, 0.34)
	# name plate: bold name on a dark pill, readable over grass and stone
	var label := Label.new()
	label.name = "NamePlate"
	label.text = Game.t(str(n.get("_en", n.get("name", id))))
	label.add_theme_font_override("font", UI.font_bold)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.64))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_stylebox_override("normal", UI.box(Color(0.06, 0.04, 0.03, 0.55), Color(UI.GOLD, 0.35), 1, 7, 6))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_child(label)
	label.reset_size()
	label.position = Vector2(-label.size.x * 0.5, -66 - lift)
	# (v0.23, playtest) the name plate follows a change of language
	if not Game.lang_changed.is_connected(_relabel_all):
		Game.lang_changed.connect(_relabel_all)
	# a speech bubble over the villager you are next to
	var th := Node2D.new()
	th.name = "TalkHint"
	th.position = Vector2(0, -80 - lift)
	th.z_index = 5
	th.visible = false
	th.draw.connect(_draw_talk_hint.bind(th))
	node.add_child(th)
	_talk_hints.append(th)
	node.set_meta("name_en", str(n.get("_en", n.get("name", id))))
	node.set_meta("id", id)
	if id in NEWS_NPCS:
		var mk := Node2D.new()
		mk.set_meta("id", id)
		mk.name = "NewsMarker"
		mk.position = Vector2(0, -84 - lift)
		mk.z_index = 5
		mk.draw.connect(_draw_marker.bind(mk))
		node.add_child(mk)
		_markers.append(mk)
	ysort.add_child(node)
	stats["npcs"] += 1

var _markers: Array = []
var _talk_hints: Array = []

## (v0.23, playtest) the villagers' name plates follow a change of language
func _relabel_all() -> void:
	if ysort == null:
		return
	for n in ysort.get_children():
		if n.is_in_group("npcs"):
			var label := n.get_node_or_null("NamePlate") as Label
			if label:
				label.text = Game.t(str(n.get_meta("name_en", "")))
				label.reset_size()
				label.position = Vector2(-label.size.x * 0.5, -66 - float(n.get_meta("lift", 0.0)))

func _draw_talk_hint(h: Node2D) -> void:
	h.draw_circle(Vector2(0, 1.5), 9.5, Color(0, 0, 0, 0.45))
	h.draw_circle(Vector2.ZERO, 9.0, Color(0.98, 0.94, 0.84))
	h.draw_colored_polygon(PackedVector2Array([Vector2(-3, 7), Vector2(3, 7), Vector2(-4, 12)]), Color(0.98, 0.94, 0.84))
	for i in 3:
		h.draw_circle(Vector2(-4 + i * 4, 0), 1.3, Color(0.3, 0.2, 0.1))

## a gold "!" bobbing over a villager who has news for you
func _draw_marker(mk: Node2D) -> void:
	var c := Vector2.ZERO
	mk.draw_circle(c + Vector2(0, 1.5), 9.5, Color(0, 0, 0, 0.45))
	mk.draw_circle(c, 9.0, UI.GOLD)
	mk.draw_circle(c, 7.0, Color(0.2, 0.12, 0.05))
	mk.draw_rect(Rect2(c + Vector2(-1.3, -5), Vector2(2.6, 6.5)), UI.GOLD_HI)
	mk.draw_circle(c + Vector2(0, 4), 1.5, UI.GOLD_HI)

func _update_markers() -> void:
	for mk in _markers:
		if is_instance_valid(mk):
			var nid := str(mk.get_meta("id", "elder"))
			if nid == "elder":
				mk.visible = Game.elder_has_news()
			elif nid == "rostam":
				mk.visible = Game.Tut.has_news()
			elif nid in ["smith", "qaren"]:
				mk.visible = Game.Ch3.has_news(nid)
			else:
				mk.visible = Game.Ch2.has_news(nid)

## (v0.27, level design: "16 foes are spawned inside a wall; one cannot be reached") a common foe whose place in the map
## data lies in a wall stands on the nearest clear ground instead
func _clear_feet(feet: Vector2, hw: float) -> Vector2:
	var walls: Array = _arr(data.get("walls"))
	var blocked := func(p: Vector2) -> bool:
		var r := Rect2(p.x - hw - 2.0, p.y - 12.0, hw * 2.0 + 4.0, 14.0)
		if r.position.x < 0.0 or r.position.y < 0.0 or r.end.x > float(data.get("w", 9999)) or r.end.y > float(data.get("h", 9999)):
			return true
		for w in walls:
			if r.intersects(Rect2(float(w["x"]), float(w["y"]), float(w["w"]), float(w["h"]))):
				return true
		return false
	if not blocked.call(feet):
		return feet
	for ring in range(1, 12):
		for k in 12:
			var p: Vector2 = feet + Vector2.RIGHT.rotated(TAU * k / 12.0) * (ring * 12.0)
			if not blocked.call(p):
				return p
	return feet

func spawn_enemy(type: String, feet: Vector2) -> Node:
	var e: Node = Boss.new() if Game.BOSS_CFG.has(type) else Enemy.new()
	e.setup(type, key, feet, self)
	ysort.add_child(e)
	stats["enemies"] += 1
	return e

## a boss arena object (grave pillar, bog egg, ice echo) standing on `feet`
func spawn_arena(type: String, feet: Vector2, opts: Dictionary) -> Node:
	var e := ArenaObj.new()
	e.setup(type, key, feet, self)
	ysort.add_child(e)
	e.configure(opts)
	return e

func count_arena(type: String) -> int:
	var n := 0
	for a in get_tree().get_nodes_in_group("arena"):
		if a.type == type and not a.dead:
			n += 1
	return n

## free floor for an object of size `sz` whose feet are at `feet` (V18.freeSpot)
func free_spot(feet: Vector2, sz: Vector2) -> bool:
	var r := Rect2(feet - Vector2(sz.x * 0.5, sz.y), sz)
	if r.position.x < 30 or r.position.y < 40 or r.end.x > size.x - 30 or r.end.y > size.y - 30:
		return false
	var grown := r.grow(6.0)
	for w in wall_rects:
		if grown.intersects(w):
			return false
	for h in hazards:
		if r.intersects(h["rect"]):
			return false
	return true

## up to n free spots on a ring around `c`, at least 70 px apart; returns feet positions (V18.ring)
func ring(c: Vector2, n: int, r_min: float, r_max: float, sz: Vector2, tries := 60) -> Array:
	var out := []
	for k in tries:
		if out.size() >= n:
			break
		var a := randf() * TAU
		var r := r_min + randf() * (r_max - r_min)
		var feet := c + Vector2(cos(a), sin(a)) * r + Vector2(0, sz.y * 0.5)
		if not free_spot(feet, sz):
			continue
		var near := false
		for o in out:
			if o.distance_to(feet) < 70.0:
				near = true
		if not near:
			out.append(feet)
	return out

func wall_hit(r: Rect2) -> bool:
	for w in wall_rects:
		if r.intersects(w):
			return true
	return false

## one-time hints (saved), shown as a toast
func tip(id: String, en: String, fa: String) -> void:
	var seen: Dictionary = Game.v18().get("tips", {})
	if seen.has(id):
		return
	seen[id] = true
	Game.v18()["tips"] = seen
	tip_shown.emit(Game.t(en, fa))

# ---------------------------------------------------------------- queries
## hazards the hero's body touches whose own tick has run out (HTML: lava 5 dmg / s, poison 4 dmg + poison / s,
## ice freezes every 0.8 s); the Sorceress's temporary pools count as poison hazards
func hazard_hits(body: Rect2, dt: float) -> Array:
	var out := []
	var all: Array = hazards + (bossfx.pools if bossfx else [])
	for h in all:
		h["tick"] = float(h.get("tick", 0.0)) - dt
		if float(h["tick"]) <= 0.0 and body.intersects(h["rect"]):
			h["tick"] = 0.8 if h["type"] == "ice" else 1.0
			out.append(h["type"])
	return out

func in_grass(feet: Vector2) -> bool:
	for g in grass:
		if g.has_point(feet):
			return true
	return false

func on_ice(body: Rect2) -> bool:
	for h in hazards:
		if h["type"] == "ice" and body.intersects(h["rect"]):
			return true
	return false

func hazard_at(feet: Vector2) -> String:
	for h in hazards:
		if h["rect"].has_point(feet):
			return h["type"]
	if bossfx:
		return bossfx.pool_at(feet)
	return ""

## (v0.23, playtest) texts born at the same spot within a moment of each other are stacked, not drawn on top of each other
var _ft_recent: Array = []

func float_text(pos: Vector2, text: String, color: Color, big := false) -> void:
	var ft := FloatText.new()
	ft.setup(text, color, big)
	var now := Time.get_ticks_msec()
	_ft_recent = _ft_recent.filter(func(r): return now - int(r[1]) < 350)
	var lift := 0.0
	for r in _ft_recent:
		if absf(r[0].x - pos.x) < 60.0 and absf(r[0].y - pos.y) < 30.0:
			lift += 15.0
	_ft_recent.append([pos, now])
	ft.position = pos - Vector2(0, lift)
	if fx and fx.texts:
		fx.texts.add_child(ft)
	else:
		add_child(ft)

# ---------------------------------------------------------------- feel: shake, punch, hit-stop, swings, particles
func _cam() -> Camera2D:
	var p = get_tree().get_first_node_in_group("player")
	if p == null or p.get("cam") == null or p.world != self:
		return null
	return p.cam

func shake(amount: float) -> void:
	var c = _cam()
	if c:
		c.shake(amount)

## a short shove of the view along dir (crits, heavy blows, getting hit)
func punch(dir: Vector2, amount := 6.0) -> void:
	var c = _cam()
	if c:
		c.punch(dir, amount)

func _process(dt: float) -> void:
	enemy_tactics_clock += dt
	_camp_tick()
	_items_tick()
	var bob := sin(Time.get_ticks_msec() / 260.0) * 3.0
	for mk in _markers:
		if is_instance_valid(mk) and mk.visible:
			mk.position.y = -84.0 + bob
	var p = get_tree().get_first_node_in_group("player")
	var near = null
	if p != null and p.world == self and is_instance_valid(p.near_npc):
		near = p.near_npc
	for h in _talk_hints:
		if not is_instance_valid(h):
			continue
		var show: bool = near == h.get_parent() and not (h.get_parent().has_node("NewsMarker") and h.get_parent().get_node("NewsMarker").visible)
		h.visible = show
		if show:
			h.position.y = -80.0 + bob * 0.7

func hitstop(sec: float) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	get_tree().create_timer(sec, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

## the hero's weapon arc (kept for older callers; the arc itself lives in Fx)
func slash(_center: Vector2, dir: Vector2, reach: float, heavy := false) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p and fx:
		fx.swing(p, dir, reach, heavy, int(Game.state.get("weapon", 1)))

func burst(pos: Vector2, color: Color, n := 10, speed := 120.0) -> void:
	if fx:
		fx.burst(pos, color, n, speed)


# ---------------------------------------------------------------- Thornwood camp: Sindokht's strongbox, Ashkbus's ledger (v0.9)
var camp_noticed := false      # someone in the camp has seen the hero
var parleying := false         # the parley box is open
var truce := false             # a deal holds: the camp lets the hero walk

func camp_foes() -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.world == self:
			out.append(e)
	return out

func varga():
	for e in camp_foes():
		if e.type == "captain":
			return e
	return null

func _camp_setup() -> void:
	if key != "camp":
		return
	for it in _arr(data.get("items")):
		var kind := str(it.get("type", ""))
		if kind == "strongbox" and Game.toll_st() != "active":
			continue
		if kind == "ledger" and bool(Game.toll().get("ledger", false)):
			continue
		_pickup(kind, it)
	# A committed fight survives leaving and re-entering the camp; restore hostility, not another parley.
	var how := str(Game.toll().get("how", ""))
	var fight_started := bool(Game.toll().get("fight_started", false))
	if fight_started:
		camp_noticed = true
		raise_alarm()
	elif Game.toll_st() == "active" and bool(Game.toll().get("truce", false)):
		_set_truce(true)
	if how == "dragon" or how == "fight" or Game.is_defeated("captain") or Game.toll_st() == "done":
		scatter(false)
	if Game.toll_st() == "done":
		tip("camp_abandoned", Toll.line("abandoned"), Toll.line("abandoned"))
	elif Game.toll_st() == "active":
		tip("camp_danger", Toll.line("low_level"), Toll.line("low_level"))

func _pickup(kind: String, it: Dictionary) -> void:
	var node := Node2D.new()
	node.position = Vector2(float(it["x"]) + float(it.get("w", 24)) * 0.5, float(it["y"]) + float(it.get("h", 20)))
	node.add_to_group("npcs")
	var tex = load("res://assets/art/Items/%s.png" % kind)
	if tex:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		var sc: float = 34.0 / float(tex.get_width())
		spr.scale = Vector2(sc, sc)
		spr.position = Vector2(-tex.get_width() * sc * 0.5, -tex.get_height() * sc + 2)
		node.add_child(spr)
	Fx.shadow_for(node, 26, 14, 0.3)
	var nm: String = Game.t("Sindokht's strongbox", "صندوقچهٔ سیندخت") if kind == "strongbox" else Toll.line("ledger_title")
	node.set_meta("id", kind)
	node.set_meta("name_en", nm)
	var th := Node2D.new()
	th.name = "TalkHint"
	th.position = Vector2(0, -50)
	th.z_index = 5
	th.visible = false
	th.draw.connect(_draw_talk_hint.bind(th))
	node.add_child(th)
	_talk_hints.append(th)
	ysort.add_child(node)
	stats["npcs"] += 1

func remove_pickup(kind: String) -> void:
	for n in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(n) and str(n.get_meta("id", "")) == kind and ysort.is_ancestor_of(n):
			_talk_hints = _talk_hints.filter(func(h): return is_instance_valid(h) and h.get_parent() != n)
			n.queue_free()

func _set_truce(on: bool) -> void:
	truce = on
	for e in camp_foes():
		e.parley = on

## A spotted hero alerts nearby allies; the Thornwood camp then applies its special parley rules.
func on_notice(source: Node) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p != null and p.world == self and not p.dead:
		var origin: Vector2 = source.global_position if is_instance_valid(source) else p.global_position
		for ally in camp_foes():
			if ally == source or ally.dead or ally.parley:
				continue
			if ally.global_position.distance_to(origin) <= 230.0 and ally.has_method("hear_alarm"):
				ally.hear_alarm(p.global_position)
	if key != "camp":
		return
	camp_noticed = true
	if Game.toll_st() == "active" and not truce and not parleying and not bool(Game.toll().get("fight_started", false)) and varga() != null and str(Game.toll().get("how", "")) == "":
		_start_parley()


## Only one nearby ranged foe may launch in a short volley window. Its shot gives
## alerted melee allies a brief, alternating flank order.
func request_enemy_volley(shooter: Node) -> bool:
	if shooter == null or not is_instance_valid(shooter) or shooter.dead:
		return false
	if enemy_tactics_clock < enemy_volley_ready_at:
		return false
	enemy_volley_ready_at = enemy_tactics_clock + 0.72
	_order_flankers(shooter)
	return true


func _order_flankers(shooter: Node) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p == null or p.dead or p.world != self:
		return
	var allies: Array = []
	for ally in camp_foes():
		if ally == shooter or ally.dead or ally.boss or ally.parley or not ally.alert:
			continue
		if not ally.shoots.is_empty():
			continue
		if ally.global_position.distance_to(p.global_position) > 250.0:
			continue
		allies.append(ally)
	allies.sort_custom(func(a, b):
		return a.global_position.distance_squared_to(p.global_position) < b.global_position.distance_squared_to(p.global_position)
	)
	var side := -1.0
	for ally in allies:
		ally.squad_pressure_t = 1.15
		ally.squad_side = side
		side *= -1.0

func _camp_tick() -> void:
	if key != "camp" or parleying or truce or bool(Game.toll().get("fight_started", false)) or Game.toll_st() != "active" or str(Game.toll().get("how", "")) != "":
		return
	var v = varga()
	var p = get_tree().get_first_node_in_group("player")
	if v != null and p != null and p.world == self and not p.dead and v.global_position.distance_to(p.global_position) < 190.0:
		camp_noticed = true
		_start_parley()

func _start_parley() -> void:
	parleying = true
	_set_truce(true)
	parley_started.emit()

## the player picked an answer: the main scene applies it and calls this to settle the camp
func parley_done(how: String) -> void:
	parleying = false
	if how == "fight":
		_set_truce(false)
		for e in camp_foes():
			e.alert = true
			e.rally = true
	elif how == "dragon":
		scatter(true)
	else:
		Game.toll()["truce"] = true     # the deal holds
		_set_truce(true)

func truce_broken() -> void:
	if not truce:
		return
	truce = false
	Game.toll()["truce"] = false
	if Game.toll_st() == "active":
		Game.toll()["how"] = ""
		# Violence breaks the deal into combat; do not invite Ashkbus to parley again.
		Game.toll()["fight_started"] = true
		Game.save_game()
	for e in camp_foes():
		e.parley = false
		e.alert = true
		e.rally = true
	float_text(get_tree().get_first_node_in_group("player").global_position + Vector2(0, -60), Toll.line("thief"), Color(1, 0.55, 0.45))

## the hero lifted the box in plain sight (not a deal, not a ghost): the whole camp turns on him
func raise_alarm() -> void:
	_set_truce(false)
	for e in camp_foes():
		e.alert = true
		e.rally = true

## the camp empties: the bandits run off and fade away
func scatter(animated := true) -> void:
	_set_truce(false)
	for e in camp_foes():
		e.parley = false
		e.dead = true
		e.remove_from_group("enemies")
		var tw: Tween = e.create_tween()
		tw.tween_property(e, "modulate:a", 0.0, 0.8 if animated else 0.01)
		tw.tween_callback(e.queue_free)
	if animated:
		float_text(get_tree().get_first_node_in_group("player").global_position + Vector2(0, -60), Toll.line("run"), Color(1, 0.9, 0.6))


# ---------------------------------------------------------------- things lying about the map (v0.10): walk over them
const PICKUP_KINDS := ["potion", "mana_potion", "greater_potion", "herb", "obsidian", "frost_scroll", "relic", "relic_frost", "relic_essence", "chest",
	"page1", "page2", "page3"]

func _items_setup() -> void:
	var arr := _arr(data.get("items"))
	var picked: Array = Game.state.get("picked", [])
	for i in arr.size():
		var it: Dictionary = arr[i]
		var kind := str(it.get("type", ""))
		if not PICKUP_KINDS.has(kind) or picked.has("%s:%d" % [key, i]):
			continue
		var node := Node2D.new()
		node.position = Vector2(float(it["x"]) + float(it.get("w", 24)) * 0.5, float(it["y"]) + float(it.get("h", 24)))
		node.add_to_group("pickups")
		node.set_meta("kind", kind)
		node.set_meta("key", "%s:%d" % [key, i])
		var tex = load("res://assets/art/Items/%s.png" % ("page" if kind.begins_with("page") else kind))
		if tex:
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.centered = false
			var sc: float = 26.0 / float(max(tex.get_width(), tex.get_height()))
			if kind == "chest":
				sc = 34.0 / float(tex.get_width())
			spr.scale = Vector2(sc, sc)
			spr.position = Vector2(-tex.get_width() * sc * 0.5, -tex.get_height() * sc + 2)
			node.add_child(spr)
		Fx.shadow_for(node, 20, 10, 0.3)
		ysort.add_child(node)

func _items_tick() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p == null or p.dead or p.world != self:
		return
	for n in get_tree().get_nodes_in_group("pickups"):
		if not is_instance_valid(n) or not ysort.is_ancestor_of(n):
			continue
		if n.global_position.distance_to(p.global_position) < 26.0:
			var kind := str(n.get_meta("kind"))
			var txt := Game.collect(kind, str(n.get_meta("key")))
			if txt != "":
				if txt != "-":
					float_text(n.global_position + Vector2(0, -26), txt, Color(1, 0.92, 0.6))
				if kind == "chest":
					Sfx.play("chest")
				if kind.begins_with("page"):
					Sfx.play("book")
					lore.emit(Game.Ch2.line("page_title"), Game.Ch2.page_lines(int(kind.substr(4))))
				else:
					Sfx.play("coin", -3.0)
				if fx:
					fx.sparks(n.global_position + Vector2(0, -10), 8, Color(1, 0.9, 0.5))
				n.remove_from_group("pickups")
				n.queue_free()


## (v0.18) the way down into a region's shrine: a stone stair with rune stones and a pillar of light that shows
## from far away (gold once the shrine is done)
func _shrine_gate(ex: Dictionary) -> void:
	var to := str(ex["to"])
	var w := float(ex["w"])
	var feet := Vector2(float(ex["x"]) + w * 0.5, float(ex["y"]) + float(ex["h"]))
	var g := Node2D.new()
	g.name = "ShrineGate_" + to
	g.position = feet
	g.z_index = -1
	g.draw.connect(func(): ShrineArt.gate(g, w, Game.shrine_done(to), Time.get_ticks_msec() / 1000.0))
	add_child(g)
	var p := Node2D.new()
	p.name = "PillarOfLight_" + to
	p.position = feet + Vector2(0, -8)
	p.z_index = 4
	p.material = load("res://scripts/fx/tex.gd").add_material()
	p.draw.connect(func(): ShrineArt.pillar_of_light(p, w + 10.0, Game.shrine_done(to), Time.get_ticks_msec() / 1000.0))
	add_child(p)
	var tw := create_tween().set_loops()
	tw.tween_callback(func():
		g.queue_redraw()
		p.queue_redraw()).set_delay(0.05)
	if lighting:
		lighting.map_lights.append({"pos": feet + Vector2(0, -20), "r": 150.0, "i": 0.75,
			"c": Color(1, 0.84, 0.45) if Game.shrine_done(to) else Color(0.7, 0.9, 1.0), "fire": false, "seed": 0.0})
	tip("shrines", "Each wild region hides an ancient shrine — look for a pillar of light.", "")

## the stone door in the Ashen Peaks: dark while sealed, ember-bright once Jamshid's key is yours
func _door_visual() -> void:
	var d := Node2D.new()
	d.position = Vector2(515, 768)
	d.z_index = 1
	d.draw.connect(func():
		var open: bool = Game.brann_key()
		d.draw_rect(Rect2(0, 0, 120, 40), Color(0.24, 0.2, 0.18))
		d.draw_rect(Rect2(6, 6, 108, 34), Color(0.1, 0.08, 0.07))
		d.draw_rect(Rect2(14, 10, 92, 30), Color(1.0, 0.55, 0.18, 0.95) if open else Color(0.04, 0.03, 0.03))
		if open:
			d.draw_rect(Rect2(14, 10, 92, 30), Color(1.0, 0.8, 0.4, 0.25))
		else:
			d.draw_circle(Vector2(60, 26), 5.0, Color(0.8, 0.25, 0.12)))
	add_child(d)
	Game.stats_changed.connect(d.queue_redraw)


## the Bounty Board in the village square (v0.15): a wooden board with notices pinned to it
func _board() -> void:
	var node := Node2D.new()
	node.position = Vector2(340, 330)
	node.add_to_group("npcs")
	node.set_meta("id", "board")
	node.set_meta("name_en", "Bounty Board")
	var art := Node2D.new()
	art.draw.connect(func():
		art.draw_rect(Rect2(-5, -8, 4, 10), Color(0.32, 0.22, 0.14))
		art.draw_rect(Rect2(21, -8, 4, 10), Color(0.32, 0.22, 0.14))
		art.draw_rect(Rect2(-12, -40, 48, 34), Color(0.42, 0.29, 0.18))
		art.draw_rect(Rect2(-9, -37, 42, 28), Color(0.55, 0.4, 0.25))
		art.draw_rect(Rect2(-5, -34, 14, 12), Color(0.93, 0.87, 0.7))
		art.draw_rect(Rect2(12, -35, 16, 14), Color(0.9, 0.82, 0.62))
		art.draw_rect(Rect2(-2, -19, 20, 9), Color(0.95, 0.9, 0.75))
		art.draw_circle(Vector2(2, -33), 1.6, Color(0.8, 0.2, 0.15))
		art.draw_circle(Vector2(20, -34), 1.6, Color(0.8, 0.2, 0.15)))
	node.add_child(art)
	Fx.shadow_for(node, 44, 12, 0.3)
	var th := Node2D.new()
	th.name = "TalkHint"
	th.position = Vector2(12, -54)
	th.z_index = 5
	th.visible = false
	th.draw.connect(_draw_talk_hint.bind(th))
	node.add_child(th)
	_talk_hints.append(th)
	ysort.add_child(node)
	stats["npcs"] += 1


## the gate of the Trial Grounds in the village (v0.16): a stone arch with a brazier
func _arena_gate() -> void:
	var node := Node2D.new()
	node.position = Vector2(760, 380)
	node.add_to_group("npcs")
	node.set_meta("id", "arena")
	node.set_meta("name_en", "Trial of Embers")
	var art := Node2D.new()
	art.draw.connect(func():
		var flick := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 140.0)
		art.draw_rect(Rect2(-26, -58, 14, 58), Color(0.34, 0.3, 0.28))
		art.draw_rect(Rect2(12, -58, 14, 58), Color(0.34, 0.3, 0.28))
		art.draw_rect(Rect2(-30, -66, 60, 12), Color(0.42, 0.37, 0.34))
		art.draw_rect(Rect2(-12, -52, 24, 52), Color(0.08, 0.05, 0.05))
		art.draw_circle(Vector2(0, -74), 7.0 + flick * 2.0, Color(1.0, 0.55, 0.15, 0.9))
		art.draw_circle(Vector2(0, -76), 3.5, Color(1.0, 0.9, 0.5, 0.95))
		art.draw_circle(Vector2(0, -74), 16.0 + flick * 4.0, Color(1.0, 0.5, 0.1, 0.12)))
	node.add_child(art)
	var tw := create_tween().set_loops()
	tw.tween_callback(art.queue_redraw).set_delay(0.08)
	Fx.shadow_for(node, 60, 14, 0.3)
	var th := Node2D.new()
	th.name = "TalkHint"
	th.position = Vector2(0, -92)
	th.z_index = 5
	th.visible = false
	th.draw.connect(_draw_talk_hint.bind(th))
	node.add_child(th)
	_talk_hints.append(th)
	ysort.add_child(node)
	stats["npcs"] += 1


# ---------------------------------------------------------------- chapter 2 in the Crystal Sanctum (v0.19)
## the Wyrm's door behind the Judge's seat (north), the rimeglass of the east passage (to the Hoarfrost Vale), the vault
func _ch2_sanctum() -> void:
	vault = Vault.new()
	add_child(vault)
	vault.setup(self)
	# the Wyrm's door: a dark arch in the north wall with an eye-shaped lock; open, cold light breathes out of it
	var d := Node2D.new()
	d.name = "WyrmDoor"
	d.position = Vector2(660, 0)
	d.z_index = -1
	d.draw.connect(func(): _draw_wyrm_door(d, Game.Ch2.door_open(), Time.get_ticks_msec() / 1000.0))
	add_child(d)
	var tw := create_tween().set_loops()
	tw.tween_callback(d.queue_redraw).set_delay(0.05)
	if lighting:
		lighting.map_lights.append({"pos": Vector2(660, 40), "r": 140.0, "i": 0.7, "c": Color(0.6, 0.85, 1.0), "fire": false, "seed": 0.0})
	# the rimeglass in the east passage: three blocks of ice that thin away once Sorush has spoken
	for i in 3:
		var n := Node2D.new()
		n.name = "EastRime_%d" % i
		n.position = Vector2(1190, 500 + i * 40)
		n.draw.connect(func():
			if not Game.Ch2.east_open():
				ShrineArt.icewall(n, 1.0))
		ysort.add_child(n)
		Game.stats_changed.connect(n.queue_redraw)

func _draw_wyrm_door(d: Node2D, open: bool, t: float) -> void:
	var w := 92.0
	var h := 58.0
	d.draw_rect(Rect2(-w * 0.5 - 8, 0, w + 16, h + 6), Color(0.1, 0.13, 0.18))
	d.draw_rect(Rect2(-w * 0.5, 0, w, h), Color(0.2, 0.27, 0.36))
	d.draw_rect(Rect2(-w * 0.5 + 8, 0, w - 16, h - 8), Color(0.03, 0.05, 0.08) if open else Color(0.15, 0.2, 0.28))
	if open:
		var k := 0.5 + 0.5 * sin(t * 2.2)
		d.draw_rect(Rect2(-w * 0.5 + 8, 0, w - 16, h - 8), Color(0.45, 0.75, 1.0, 0.18 + 0.12 * k))
		for i in 4:
			var y := 10.0 + i * 11.0
			d.draw_line(Vector2(-w * 0.5 + 14 + i * 3, y), Vector2(w * 0.5 - 14 - i * 3, y), Color(0.55, 0.8, 1.0, 0.35), 2.0)
	else:
		# the lock: a wyrm's eye in frost
		var c := Vector2(0, h * 0.45)
		d.draw_set_transform(c, 0.0, Vector2(1.0, 0.5))
		d.draw_circle(Vector2.ZERO, 15.0, Color(0.55, 0.82, 1.0, 0.85))
		d.draw_set_transform(Vector2.ZERO)
		d.draw_rect(Rect2(c - Vector2(2.5, 7), Vector2(5, 14)), Color(0.05, 0.08, 0.12))
		for i in 6:
			var a := float(i) / 6.0 * TAU + t * 0.3
			d.draw_line(c + Vector2(cos(a), sin(a) * 0.6) * 20.0, c + Vector2(cos(a), sin(a) * 0.6) * 27.0, Color(0.75, 0.92, 1.0, 0.6), 2.0)
	for sx in [-1.0, 1.0]:
		var x: float = sx * (w * 0.5 + 2)
		var pts := PackedVector2Array([Vector2(x, h + 6), Vector2(x + sx * 6, h - 10), Vector2(x - sx * 2, h - 24), Vector2(x - sx * 6, h + 6)])
		d.draw_colored_polygon(pts, Color(0.72, 0.9, 1.0, 0.9))


# ---------------------------------------------------------------- chapter 3: the Chains of Damavand (v0.23)
## the Ashen Peaks: fallen rock on the road east until Kaveh has spoken
func _ch3_rubble() -> void:
	var n := Node2D.new()
	n.name = "DamavandRubble"
	n.position = Vector2(1128, 690)
	n.draw.connect(func():
		if Game.Ch3.road_open():
			return
		var rocks := [[-6, -112, 20], [10, -92, 16], [-14, -74, 22], [6, -52, 18], [-8, -30, 24], [12, -12, 17], [-2, 4, 14]]
		for r in rocks:
			var c := Vector2(float(r[0]), float(r[1]))
			var rad := float(r[2])
			n.draw_circle(c + Vector2(0, 3), rad, Color(0, 0, 0, 0.35))
			n.draw_circle(c, rad, Color(0.16, 0.13, 0.12))
			n.draw_circle(c + Vector2(-2, -2), rad - 3.0, Color(0.36, 0.31, 0.28))
			n.draw_circle(c + Vector2(-rad * 0.3, -rad * 0.35), rad * 0.3, Color(0.5, 0.45, 0.4)))
	ysort.add_child(n)
	Game.stats_changed.connect(n.queue_redraw)

## the Slopes of Damavand: the fire temple's altars and the Gate of Damavand (open for the Derafsh-e Kaviani)
func _ch3_damavand() -> void:
	altars = Altars.new()
	add_child(altars)
	altars.setup(self)
	var ch3: Dictionary = Game.map_data(key).get("ch3", {})
	var gp := Game._v(ch3.get("gate", [760, 0]))
	var d := Node2D.new()
	d.name = "DamavandGate"
	d.position = gp
	d.z_index = -1
	d.draw.connect(func(): _draw_damavand_gate(d, Game.Ch3.gate_open(), Time.get_ticks_msec() / 1000.0))
	add_child(d)
	var tw := create_tween().set_loops()
	tw.tween_callback(d.queue_redraw).set_delay(0.05)
	if lighting:
		lighting.map_lights.append({"pos": gp + Vector2(0, 40), "r": 150.0, "i": 0.7, "c": Color(0.75, 0.5, 1.0), "fire": false, "seed": 0.0})

func _draw_damavand_gate(d: Node2D, open: bool, t: float) -> void:
	var w := 104.0
	var h := 62.0
	d.draw_rect(Rect2(-w * 0.5 - 10, 0, w + 20, h + 8), Color(0.12, 0.09, 0.09))
	d.draw_rect(Rect2(-w * 0.5, 0, w, h), Color(0.3, 0.24, 0.22))
	var inner := Rect2(-w * 0.5 + 9, 0, w - 18, h - 8)
	if open:
		d.draw_rect(inner, Color(0.03, 0.02, 0.05))
		var k := 0.5 + 0.5 * sin(t * 1.8)
		d.draw_rect(inner, Color(0.55, 0.3, 0.85, 0.16 + 0.1 * k))
		for i in 4:
			var y := 10.0 + i * 11.0
			d.draw_line(Vector2(-w * 0.5 + 15 + i * 4, y), Vector2(w * 0.5 - 15 - i * 4, y), Color(0.7, 0.5, 1.0, 0.3), 2.0)
	else:
		# two stone leaves, and the Kaviani banner carved across them: a star on a field, a spear above
		d.draw_rect(inner, Color(0.24, 0.19, 0.18))
		d.draw_line(Vector2(0, 0), Vector2(0, h - 8), Color(0.1, 0.08, 0.08), 2.0)
		var c := Vector2(0, h * 0.5)
		d.draw_line(c + Vector2(0, -26), c + Vector2(0, 20), Color(0.55, 0.45, 0.32), 2.0)
		var flag := PackedVector2Array([c + Vector2(-14, -18), c + Vector2(14, -18), c + Vector2(14, 8), c + Vector2(0, 14), c + Vector2(-14, 8)])
		d.draw_colored_polygon(flag, Color(0.55, 0.22, 0.2, 0.9))
		var star := PackedVector2Array()
		for i in 8:
			var a := -PI * 0.5 + i * PI * 0.25
			star.append(c + Vector2(0, -4) + Vector2.from_angle(a) * (8.0 if i % 2 == 0 else 3.5))
		d.draw_colored_polygon(star, Color(0.95, 0.78, 0.35))
		for i in 3:
			d.draw_circle(c + Vector2(-8 + i * 8, 11), 2.0, [Color(0.9, 0.2, 0.25), Color(0.3, 0.8, 0.5), Color(0.3, 0.5, 0.95)][i])
	for sx in [-1.0, 1.0]:
		var x: float = sx * (w * 0.5 + 4)
		d.draw_rect(Rect2(x - 7, 0, 14, h + 8), Color(0.22, 0.17, 0.16))
		d.draw_rect(Rect2(x - 5, 0, 10, h + 6), Color(0.38, 0.31, 0.28))

## the Cave of Chains: four chains from the anchor pillars to Zahhak (one breaks at each of his phases); once he is
## bound, he stands chained and still in his lair
var zh_bound: Node2D = null

func _ch3_cave() -> void:
	var ch3: Dictionary = Game.map_data(key).get("ch3", {})
	var anchors: Array = []
	for a in ch3.get("anchors", []):
		anchors.append(Game._v(a))
	var lair := Game._v(ch3.get("lair", [600, 770]))
	var n := Node2D.new()
	n.name = "Chains"
	n.z_index = -1
	n.draw.connect(func(): _draw_chains(n, anchors, lair))
	add_child(n)
	var tw := create_tween().set_loops()
	tw.tween_callback(n.queue_redraw).set_delay(0.033)
	if Game.is_defeated("zahhak") and not rush:
		var sh: Dictionary = Sheets.enemy("zahhak")
		if not sh.is_empty():
			zh_bound = Node2D.new()
			zh_bound.name = "ZahhakBound"
			zh_bound.position = lair + Vector2(0, 30)
			var spr := AnimatedSprite2D.new()
			spr.sprite_frames = sh["frames"]
			spr.animation = "v0"
			spr.centered = false
			spr.offset = sh["offset"]
			spr.scale = Vector2.ONE * Sheets.SCALE
			spr.modulate = Color(0.5, 0.46, 0.56)
			zh_bound.add_child(spr)
			ysort.add_child(zh_bound)

func _draw_chains(n: Node2D, anchors: Array, lair: Vector2) -> void:
	var zh: Node = null
	for b in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(b) and not b.dead and b.type == "zahhak":
			zh = b
	var bound := zh == null and Game.is_defeated("zahhak") and not rush
	var holding := 4 if (bound or zh == null) else int(zh.zh_chains())
	var t := Time.get_ticks_msec() / 1000.0
	for i in anchors.size():
		var a: Vector2 = anchors[i] + Vector2(0, -38)
		if i < holding and (zh != null or bound):
			var b: Vector2 = (zh.center() if zh else lair + Vector2(0, -16))
			var pts := PackedVector2Array()
			for k in 17:
				var u := k / 16.0
				var sag := sin(u * PI) * (26.0 + 4.0 * sin(t * 2.0 + i))
				pts.append(a.lerp(b, u) + Vector2(0, sag))
			_chain_line(n, pts)
		elif i < holding:
			# no Zahhak here yet (or a Boss Rush memory): the chains lie slack toward the empty lair
			var pts2 := PackedVector2Array()
			for k in 13:
				var u2 := k / 12.0
				pts2.append(a.lerp(lair, u2 * 0.7) + Vector2(0, sin(u2 * PI) * 30.0 + u2 * 34.0))
			_chain_line(n, pts2)
		else:
			# broken: a length of chain hangs from the pillar and lies on the ground
			var pts3 := PackedVector2Array([a, a + Vector2(0, 30), a + Vector2(10, 44), a + Vector2(30, 48)])
			_chain_line(n, pts3)

func _chain_line(n: Node2D, pts: PackedVector2Array) -> void:
	n.draw_polyline(pts, Color(0.05, 0.04, 0.05, 0.9), 6.0, true)
	n.draw_polyline(pts, Color(0.42, 0.4, 0.44), 3.5, true)
	var acc := 0.0
	for k in range(1, pts.size()):
		var seg := pts[k] - pts[k - 1]
		acc += seg.length()
		if acc >= 12.0:
			acc = 0.0
			var c := pts[k]
			var nrm := seg.normalized().orthogonal()
			n.draw_line(c - nrm * 3.5, c + nrm * 3.5, Color(0.62, 0.6, 0.66), 2.0)

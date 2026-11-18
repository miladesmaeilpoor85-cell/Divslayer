extends CanvasLayer
## Light and darkness (port of the HTML VIS lighting with the v12.1 "readable nights" values):
## every region has an ambient darkness, outdoor regions grow darker at dusk and night, and lights carve
## it away — the hero's own glow, the lamps, torches, braziers and campfires exported with the maps, lava,
## erupting vents, boss bolts, bosses, a faint glow on every enemy (nothing attacks out of pure black)
## and short flashes from the effects. The darkness is painted into a small offscreen light map (a third
## of the screen; soft gradients lose nothing) and multiplied over the world; bright lights also add a
## soft coloured glow. Settings: graphics (off in "light" mode) and brightness.

const Tex = preload("res://scripts/fx/tex.gd")

const LS := 0.34
## region: [darkness, colour of the dark]. A little deeper than the HTML v12.1 values (which were halved for
## phones read in sunlight): the brightness setting lifts it back for anyone who needs it.
const AMBIENT := {
	"village": [0.10, Color(0.043, 0.063, 0.125)], "forest": [0.24, Color(0.031, 0.078, 0.047)],
	"dungeon": [0.54, Color(0.02, 0.024, 0.055)], "peaks": [0.18, Color(0.078, 0.039, 0.031)],
	"shadowfen": [0.40, Color(0.024, 0.063, 0.031)], "sanctum": [0.38, Color(0.016, 0.063, 0.118)],
	"emberforge": [0.48, Color(0.086, 0.024, 0.012)], "trial": [0.30, Color(0.039, 0.031, 0.063)],
	"camp": [0.16, Color(0.035, 0.05, 0.04)],
}
const DEFAULT_AMB := [0.24, Color(0.031, 0.031, 0.063)]
const PHASE_ADD := [0.06, 0.0, 0.16, 0.34]                  # dawn, day, dusk, night (outdoors only)
const CAP := 0.68
## whole-screen tint per phase: colour, strength (warm dawn, red dusk, blue moonlight)
const TINT := [[Color(1, 0.71, 0.39), 0.10], [Color(1, 1, 1), 0.0], [Color(1, 0.47, 0.31), 0.14], [Color(0.16, 0.24, 0.51), 0.24]]
const LEVELS := [1.0, 0.72, 0.45]                           # brightness setting: how much darkness is kept
const HERO_COL := Color(1, 0.85, 0.63)

var world: Node = null
var lv: SubViewport
var base: ColorRect
var painter: Node2D
var shade: TextureRect
var glow: Node2D
var amb_a := 0.0                # darkness this frame (after brightness)
var dark := Color(1, 1, 1)      # the light map where no light falls
var tint := Color(1, 1, 1)
var weather_dark := 0.0         # set by the weather (rain clouds)
var forced_phase := -1          # the title screen shows the village at dusk
var lights: Array = []          # this frame, light-map space: [pos, radius, colour to add]
var glows: Array = []           # this frame, screen space: [pos, radius, colour]
var map_lights: Array = []      # {pos, r, i, c, fire, seed}
var _ls := Vector2(LS, LS)
var _ct := Transform2D.IDENTITY
var _vis := Vector2(854, 400)

func setup(w: Node, data_lights: Array) -> void:
	world = w
	name = "Lighting"
	layer = 1
	for l in data_lights:
		var c := Color(str(l.get("c", "#ffcf80")))
		var fire: bool = c.r > 0.9 and c.g < 0.75 and c.b < 0.5
		map_lights.append({"pos": Vector2(float(l["x"]), float(l["y"])), "r": float(l.get("r", 120)), "i": float(l.get("i", 0.8)),
			"c": c, "fire": fire, "seed": randf() * 10.0})
	lv = SubViewport.new()
	lv.name = "LightMap"
	lv.disable_3d = true
	lv.transparent_bg = false
	lv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	lv.size = Vector2i(300, 140)
	add_child(lv)
	base = ColorRect.new()
	base.size = Vector2(4096, 4096)
	base.color = Color.WHITE
	lv.add_child(base)
	painter = Node2D.new()
	painter.material = Tex.add_material()
	painter.draw.connect(_paint)
	lv.add_child(painter)
	shade = TextureRect.new()
	shade.name = "Shade"
	shade.texture = lv.get_texture()
	shade.material = Tex.mul_material()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	glow = Node2D.new()
	glow.name = "Glow"
	glow.material = Tex.add_material()
	glow.draw.connect(_paint_glow)
	add_child(glow)

func enabled() -> bool:
	return int(Game.settings.get("fx", 1)) >= 1

## darkness and tint for this region and time of day
func _ambient() -> void:
	var key: String = world.key
	var b: Array = AMBIENT.get(key, DEFAULT_AMB)
	var a: float = b[0]
	tint = Color(1, 1, 1)
	if not Game.indoor(key):
		var pb: Array = Game.phase_blend() if forced_phase < 0 else [forced_phase, forced_phase, 0.0]
		var k: float = pb[2]
		a += lerp(float(PHASE_ADD[pb[0]]), float(PHASE_ADD[pb[1]]), k) + weather_dark
		var t0: Color = Color(1, 1, 1).lerp(TINT[pb[0]][0], TINT[pb[0]][1])
		var t1: Color = Color(1, 1, 1).lerp(TINT[pb[1]][0], TINT[pb[1]][1])
		tint = t0.lerp(t1, k)
	amb_a = min(CAP, a) * float(LEVELS[clamp(int(Game.settings.get("bright", 0)), 0, 2)])
	var c: Color = b[1]
	dark = Color(1, 1, 1).lerp(c, amb_a)
	tint = Color(1, 1, 1).lerp(tint, float(LEVELS[clamp(int(Game.settings.get("bright", 0)), 0, 2)]))

func _process(_dt: float) -> void:
	if world == null or not enabled():
		if shade.visible:
			shade.visible = false
			glow.visible = false
			lv.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_ambient()
	var on := amb_a > 0.03 or tint.r < 0.99 or tint.b < 0.99
	if shade.visible != on:
		shade.visible = on
		lv.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	var vp := world.get_viewport()
	_vis = vp.get_visible_rect().size
	var want := Vector2i(int(ceil(_vis.x * LS)), int(ceil(_vis.y * LS)))
	if lv.size != want:
		lv.size = want
	_ls = Vector2(float(want.x) / _vis.x, float(want.y) / _vis.y)
	_ct = vp.get_canvas_transform()
	base.color = dark
	shade.modulate = tint
	lights.clear()
	glows.clear()
	if on:
		_collect()
	painter.queue_redraw()
	glow.visible = on and amb_a >= 0.1
	if glow.visible:
		glow.queue_redraw()

## world position and radius -> a light (culled to the screen)
func add(pos: Vector2, r: float, i: float, c: Color) -> void:
	var sp: Vector2 = _ct * pos
	var sr: float = r * _ct.get_scale().x
	if sp.x < -sr or sp.y < -sr or sp.x > _vis.x + sr or sp.y > _vis.y + sr:
		return
	var k: Color = Color(1.0 - dark.r, 1.0 - dark.g, 1.0 - dark.b) * clampf(i, 0.0, 1.0)
	lights.append([sp * _ls, sr * _ls.x, Color(k.r, k.g, k.b, 1.0)])
	if r >= 50.0:
		glows.append([sp, sr * 0.75, Color(c, (0.06 + 0.4 * amb_a) * i)])

func _collect() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var tree := world.get_tree()
	var p = tree.get_first_node_in_group("player")
	if p != null and p.world == world:
		var fl := 0.94 + 0.06 * sin(t / 0.11) + 0.03 * sin(t / 0.047)
		add(p.global_position + Vector2(0, -17), 236.0 * fl, 0.96, HERO_COL)
	for l in map_lights:
		var f := 1.0
		if l["fire"]:
			f = 0.92 + 0.08 * sin(t / 0.097 + float(l["seed"]))
		add(l["pos"], float(l["r"]) * f, float(l["i"]), l["c"])
	var n := 0
	for e in tree.get_nodes_in_group("enemies"):
		if e.dead or n >= 16 or e.world != world:
			continue
		var c: Vector2 = e.center()
		match str(e.type):
			"ignarok": add(c, 220, 0.95, Color(1, 0.44, 0.19))
			"moltencore": add(c, 76, 0.8, Color(1, 0.48, 0.19))
			"bellowdrone": add(c, 64, 0.7, Color(1, 0.82, 0.48))
			_:
				if e.boss:
					add(c, 130, 0.7, Color(1, 0.6, 0.42))
		add(c, 120.0 if e.boss else 62.0, 0.75 if e.boss else 0.62, Color(1, 1, 1))
		n += 1
	var bf = world.bossfx
	if bf:
		for s in bf.shots:
			add(s["pos"], 56, 0.8, s["col"])
	var hz = world.hazard_layer
	if hz:
		for v in hz.vents:
			if v["hot"] or v["warn"]:
				var r: Rect2 = v["rect"]
				add(r.get_center(), (150.0 if v["hot"] else 90.0) * (0.92 + 0.08 * sin(t / 0.097)), 0.9 if v["hot"] else 0.5, Color(1, 0.48, 0.18))
		for s in hz.shapes:
			if s["kind"] == "lava":
				var r2: Rect2 = s["rect"]
				add(r2.get_center(), max(r2.size.x, r2.size.y) * 0.8 + 30.0, 0.7, Color(1, 0.5, 0.2))
	var sh = world.get("shrine")
	if sh:
		for l in sh.lights_now():
			add(l[0], float(l[1]), float(l[2]), l[3])
	var sp = world.get("spells")
	if sp:
		for l in sp.lights_now():
			add(l[0], float(l[1]), float(l[2]), l[3])
	var fx = world.fx
	if fx:
		for l in fx.lights:
			var k: float = float(l["t"]) / float(l["life"])
			add(l["pos"], float(l["r"]) * (0.6 + 0.4 * k), float(l["i"]) * k, l["c"])

func _paint() -> void:
	var cut := Tex.cut()
	for l in lights:
		var r: float = max(2.0, l[1])
		painter.draw_texture_rect(cut, Rect2(l[0] - Vector2(r, r), Vector2(r, r) * 2.0), false, l[2])

func _paint_glow() -> void:
	var g := Tex.glow()
	for l in glows:
		var r: float = l[1]
		glow.draw_texture_rect(g, Rect2(l[0] - Vector2(r, r), Vector2(r, r) * 2.0), false, l[2])

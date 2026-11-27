extends Node2D
## Living props (port of the HTML V15 prop animations): the map objects were exported as still pictures,
## so torches, braziers, campfires and the Trial's fire columns had no flames and lamps no glow.
## This adds them back: flickering flames (V15.P.fire), blue flames on ice braziers, glowing lanterns,
## bubbling cauldrons, smoking vents and chimneys, pulsing glow-shrooms; and the trees, bushes and reeds
## sway in the wind (a small vertex shader). Off-screen props are not redrawn.

const Tex = preload("res://scripts/fx/tex.gd")
const SWAY_SHADER := """
shader_type canvas_item;
uniform float amp = 6.0;
uniform float speed = 1.2;
void vertex() {
	vec2 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float k = 1.0 - UV.y;
	k = k * k;
	VERTEX.x += (sin(TIME * speed + wp.x * 0.045 + wp.y * 0.03) + 0.35 * sin(TIME * speed * 2.7 + wp.x * 0.11)) * amp * k;
}
"""

static var _sway := {}

var world: Node = null
var items: Array = []        # {node, kind, pos, s, seed, cold}
var chimneys: Array = []     # {pos, t}
var clock := 0.0

## a shared sway material (amplitude in texture pixels at the top of the sprite)
static func sway_material(amp: float, speed: float) -> ShaderMaterial:
	var key := "%.1f/%.2f" % [amp, speed]
	if _sway.has(key):
		return _sway[key]
	var sh := Shader.new()
	sh.code = SWAY_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("amp", amp)
	m.set_shader_parameter("speed", speed)
	_sway[key] = m
	return m

func setup(w: Node) -> void:
	world = w
	name = "PropsFx"

## called for each map object: adds a flame / glow / bubbles / smoke node when the prop has one
func add_prop(o: Dictionary, spr: Sprite2D, meta: Dictionary) -> void:
	var kind := str(o.get("kind", ""))
	var pos := Vector2(float(o["x"]), float(o["y"]))
	match kind:
		"tree", "pine", "willow":
			spr.material = sway_material(5.5, 1.1)
		"bush":
			spr.material = sway_material(3.0, 1.6)
		"reeds":
			spr.material = sway_material(7.0, 1.9)
	# (v0.35) a painted prop says where its smoke, flame or glow is (map_object_sprites.json: smoke_at, fx_at, fx_s,
	# in map units from its base; null smoke_at: none)
	var flip := -1.0 if spr.flip_h else 1.0
	if meta.has("smoke_at"):
		if meta["smoke_at"] is Array:
			chimneys.append({"pos": pos + Vector2(float(meta["smoke_at"][0]) * flip, float(meta["smoke_at"][1])), "t": randf()})
	elif o.get("smoke") is Dictionary:
		chimneys.append({"pos": Vector2(float(o["smoke"]["x"]), float(o["smoke"]["y"])), "t": randf()})
	var spec := {}
	match kind:
		"torch": spec = {"fire": Vector2(0, -22), "s": 5.0}
		"brazier": spec = {"fire": Vector2(0, -22), "s": 8.0}
		"icebrazier": spec = {"fire": Vector2(0, -22), "s": 8.0, "cold": true}
		"campfire": spec = {"fire": Vector2(0, -9), "s": 8.0}
		"column":
			if o.get("animated", false):
				var top: float = float(meta.get("logicalH", 114)) * (1.0 - float(meta.get("pivot", [0.5, 0.0])[1]))
				spec = {"fire": Vector2(0, -top + 8.0), "s": 8.0}
		"lamp": spec = {"lamp": Vector2(0, -44)}
		"cauldron": spec = {"bubbles": Vector2(0, -22)}
		"vent": spec = {"smoke": Vector2(0, -8)}
		"glowshroom": spec = {"pulse": Vector2(0, -6), "c": Color(0.48, 1, 0.82)}
		"smallcrystal": spec = {"pulse": Vector2(0, -10), "c": Color(0.62, 0.86, 1)}
	if spec.is_empty():
		return
	if meta.get("fx_at") is Array:
		var at := Vector2(float(meta["fx_at"][0]) * flip, float(meta["fx_at"][1]))
		for k in ["fire", "lamp", "bubbles"]:
			if spec.has(k):
				spec[k] = at
	if meta.has("fx_s") and spec.has("s"):
		spec["s"] = float(meta["fx_s"])
	var n := Node2D.new()
	n.position = pos + Vector2(0, 0.5)       # sorts just after its prop
	n.z_index = 0
	if spec.has("fire") or spec.has("lamp") or spec.has("pulse"):
		n.material = Tex.add_material()
	var it := {"node": n, "spec": spec, "seed": pos.x * 0.37 + randf() * 3.0}
	n.draw.connect(_draw_item.bind(it))
	world.ysort.add_child(n)
	items.append(it)

func _process(dt: float) -> void:
	clock += dt
	var vp := get_viewport()
	var ct := vp.get_canvas_transform()
	var view := Rect2(ct.affine_inverse() * Vector2.ZERO, vp.get_visible_rect().size / ct.get_scale()).grow(80)
	for it in items:
		var n: Node2D = it["node"]
		if view.has_point(n.position):
			n.queue_redraw()
	# chimney smoke: a puff every ~0.4 s
	if world.fx:
		for c in chimneys:
			c["t"] = float(c["t"]) - dt
			if c["t"] <= 0.0 and view.has_point(c["pos"]):
				c["t"] = randf_range(0.3, 0.5)
				world.fx.smoke(c["pos"] + Vector2(randf_range(-3, 3), 0), 1, Color(0.62, 0.6, 0.58, 0.42), 1.3)

func _draw_item(it: Dictionary) -> void:
	var n: Node2D = it["node"]
	var spec: Dictionary = it["spec"]
	var t := clock
	var seed: float = it["seed"]
	if spec.has("fire"):
		fire(n, spec["fire"], float(spec["s"]), t, seed, spec.get("cold", false))
	elif spec.has("lamp"):
		# the lantern glows brighter the darker it is around it
		var p := 0.6 + 0.4 * sin(t / 0.18 + seed)
		var c: Vector2 = spec["lamp"]
		var dk: float = world.lighting.amb_a if world.lighting else 0.0
		var r: float = 18.0 + 22.0 * dk
		n.draw_texture_rect(Tex.glow(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 0.82, 0.51, (0.3 + 0.6 * dk) * p))
		n.draw_texture_rect(Tex.glow(), Rect2(c - Vector2(6, 6), Vector2(12, 12)), false, Color(1, 0.95, 0.8, 0.5 + 0.4 * dk))
	elif spec.has("bubbles"):
		var c2: Vector2 = spec["bubbles"]
		for i in 3:
			var ph: float = fmod(t / 0.7 + i / 3.0, 1.0)
			n.draw_circle(c2 + Vector2(-5 + i * 5, -ph * 12.0), 1.5 + ph * 2.0, Color(0.72, 1, 0.56, 1.0 - ph))
	elif spec.has("smoke"):
		var c3: Vector2 = spec["smoke"]
		for i in 3:
			var ph2: float = fmod(t / 1.5 + i / 3.0 + seed * 0.01, 1.0)
			n.draw_circle(c3 + Vector2(sin(ph2 * 6.0 + i) * 4.0, -ph2 * 36.0), 4.0 + ph2 * 9.0, Color(0.72, 0.67, 0.64, 0.35 * (1.0 - ph2)))
		n.draw_texture_rect(Tex.glow(), Rect2(Vector2(-10, -6), Vector2(20, 12)), false, Color(1, 0.48, 0.16, 0.25 + 0.15 * sin(t * 3.0 + seed)))
	elif spec.has("pulse"):
		var c4: Vector2 = spec["pulse"]
		var p2 := 0.55 + 0.45 * sin(t * 1.7 + seed)
		var col: Color = spec["c"]
		n.draw_texture_rect(Tex.glow(), Rect2(c4 - Vector2(12, 12), Vector2(24, 24)), false, Color(col, 0.3 * p2))

## V15.P.fire: three flickering tongues of flame (red, orange, pale yellow; blue for ice) and a soft glow
static func fire(n: CanvasItem, at: Vector2, s: float, t: float, seed: float, cold := false) -> void:
	var x := at.x
	var y := at.y
	var cols := [Color(0.35, 0.67, 1, 0.55), Color(0.63, 0.86, 1, 0.6), Color(0.92, 0.98, 1, 0.85)] if cold \
		else [Color(0.86, 0.27, 0.08, 0.55), Color(1, 0.59, 0.16, 0.65), Color(1, 0.94, 0.67, 0.9)]
	n.draw_texture_rect(Tex.glow(), Rect2(Vector2(x - s * 3.0, y - s * 4.0), Vector2(s * 6.0, s * 6.0)), false,
		Color(0.55, 0.82, 1, 0.3) if cold else Color(1, 0.59, 0.24, 0.3))
	for i in 3:
		var ph: float = t / 0.12 + i * 2.1 + seed
		var h: float = s * (1.6 + 0.4 * sin(ph))
		var w: float = s * (0.75 - i * 0.15)
		var pts := PackedVector2Array()
		var p0 := Vector2(x - w, y)
		var c1 := Vector2(x - w * 0.6 + sin(ph * 1.7) * minf(1.5, w * 0.5), y - h * 0.6)
		var p1 := Vector2(x + sin(ph) * 1.5, y - h)
		var c2 := Vector2(x + w * 0.6, y - h * 0.55)
		var p2 := Vector2(x + w, y)
		for k in 7:
			var u := k / 6.0
			pts.append(p0.lerp(c1, u).lerp(c1.lerp(p1, u), u))
		for k in range(1, 7):
			var u2 := k / 6.0
			pts.append(p1.lerp(c2, u2).lerp(c2.lerp(p2, u2), u2))
		n.draw_colored_polygon(pts, cols[i])

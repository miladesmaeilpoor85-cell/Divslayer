extends Node2D
## (v0.35) A map's ground from painted textures (data/terrain.json): instead of one baked picture of the whole map,
## which was blurry on a phone (2 px per map unit, the screen shows about 3), a few painted textures are tiled across the
## map and mixed where the map's splat map says (red: the path, green: paving, blue: a second ground). Sharp at any zoom,
## and a whole biome shares its textures. A map with no entry keeps its old picture (world.gd).

const SHADER := preload("res://scripts/fx/terrain.gdshader")
const DIR := "res://assets/art/Terrain/"
const PATH := "res://data/terrain.json"

static var _cfg := {}

var size := Vector2.ZERO
var margin := 0.0

static func cfg() -> Dictionary:
	if _cfg.is_empty() and FileAccess.file_exists(PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cfg = d if typeof(d) == TYPE_DICTIONARY else {"maps": {}}
	return _cfg

## the map's terrain entry, or {} when it has none (or a texture is missing from the build)
static func entry(key: String) -> Dictionary:
	var m: Dictionary = cfg().get("maps", {}).get(key, {})
	if m.is_empty() or not ResourceLoader.exists(DIR + "splat/" + key + ".png"):
		return {}
	for ch in ["base", "r", "g", "b"]:
		if m.has(ch) and not ResourceLoader.exists(DIR + str(cfg()["textures"][m[ch]]["file"])):
			return {}
	return m

static func has_terrain(key: String) -> bool:
	return not entry(key).is_empty()

## builds the ground for map `key` of `map_size`, drawn `apron` units past every edge; false if the map has none
func setup(key: String, map_size: Vector2, apron: float) -> bool:
	var m := entry(key)
	if m.is_empty():
		return false
	name = "Terrain"
	size = map_size
	margin = apron
	z_index = -10
	var texs: Dictionary = cfg()["textures"]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("splat", load(DIR + "splat/" + key + ".png"))
	mat.set_shader_parameter("noise", load(DIR + "noise.png"))
	mat.set_shader_parameter("map_size", map_size)
	var u := Vector4(340, 340, 340, 340)
	var gains := Vector4.ONE
	var use := Vector3.ZERO
	var slots := {"base": ["tex_base", 0], "r": ["tex_r", 1], "g": ["tex_g", 2], "b": ["tex_b", 3]}
	for ch in slots:
		var tname: String = str(m.get(ch, m["base"]))
		var t: Dictionary = texs[tname]
		mat.set_shader_parameter(slots[ch][0], load(DIR + str(t["file"])))
		u[slots[ch][1]] = float(t.get("units", 340))
		gains[slots[ch][1]] = float(t.get("gain", 1.0))
		if ch != "base" and m.has(ch):
			use[slots[ch][1] - 1] = 1.0
	mat.set_shader_parameter("units", u)
	mat.set_shader_parameter("gains", gains)
	mat.set_shader_parameter("use", use)
	for p in ["rough", "macro", "sat"]:
		if m.has(p):
			mat.set_shader_parameter(p, float(m[p]))
	if m.has("edges"):
		var e: Array = m["edges"]
		mat.set_shader_parameter("edges", Vector3(e[0], e[1], e[2]))
	if m.has("tint"):
		var tc: Array = m["tint"]
		mat.set_shader_parameter("tint", Vector3(tc[0], tc[1], tc[2]))
	# light graphics (older phones): half the texture reads
	mat.set_shader_parameter("cheap", int(Game.settings.get("fx", 1)) == 0)
	material = mat
	queue_redraw()
	return true

func _draw() -> void:
	draw_rect(Rect2(-Vector2.ONE * margin, size + Vector2.ONE * margin * 2.0), Color.WHITE)

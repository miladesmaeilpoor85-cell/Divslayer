extends Control
## The hero's round portrait: the face cropped from the current gear's sprite sheet inside a gold
## ring, with a level badge. Also used for villagers in the dialogue box (square = true).

const Sheets = preload("res://scripts/sheets.gd")
const Looks = preload("res://scripts/looks.gd")
const UserArtAtlas = preload("res://scripts/ui/user_art_atlas.gd")
const MASK := "shader_type canvas_item;\nuniform vec2 center;\nuniform float radius;\nvarying vec2 lp;\nvoid vertex() { lp = VERTEX; }\nvoid fragment() { if (distance(lp, center) > radius) { discard; } }\n"

var group := "heroes"
var sheet := ""
var level := 0
var square := false
var ring := UI.GOLD
var face: Control
var rim: Control
var _tex: Texture2D
var _src := Rect2()
static var _shader: Shader

## (v0.28) painted dialogue portraits. Key: the dialogue's sheet (or, for a hero of the tale, his look);
## value: [file in assets/art/Portraits, which way the face turns: 1 = to the viewer's right, -1 = to the left]
const ART := {
	"elder": ["zal", 1], "merchant": ["sindokht", 1], "alchemist": ["rudabeh", -1], "brann": ["jamshid", 1],
	"keeper": ["sorush", 1], "hesk": ["hom", 1], "smith": ["kavian", 1], "qaren": ["qaren", 1],
	"npc_rostam": ["rostam", 1], "npc_siavash": ["siavash", 1], "npc_gordafarid": ["gordafarid", 1]}
const ART_DIR := "res://assets/art/Portraits/%s.webp"
const USER_ART_FOLDER := "assets/art/Portraits"
const USER_ART_PARTS: Array[String] = [
	"character_portraits_2026.part_00.b64",
	"character_portraits_2026.part_01.b64",
]
const USER_ART := {
	"npc_rostam": [Vector2(0, 0), 1],
	"npc_siavash": [Vector2(192, 0), 1],
	"npc_gordafarid": [Vector2(0, 192), 1],
	"alchemist": [Vector2(192, 192), -1],
}
var art_facing := 0     # 0: no painted portrait on show
var mirror := false     # set by the dialogue box so the painted face turns toward the text

## "hero:warrior_endgame:npc_rostam" -> "npc_rostam"; "elder" -> "elder"
static func art_key(s: String) -> String:
	if s.begins_with("hero:"):
		var parts: PackedStringArray = s.split(":")
		return parts[parts.size() - 1]
	return s

static func has_art(s: String) -> bool:
	var key := art_key(s)
	if USER_ART.has(key):
		return UserArtAtlas.has_parts(USER_ART_FOLDER, USER_ART_PARTS)
	return ART.has(key) and ResourceLoader.exists(ART_DIR % ART[key][0])

## Shows the painted portrait for this sheet; false (and nothing changed) if there is none.
func show_art(s: String) -> bool:
	if not has_art(s):
		return false
	var key := art_key(s)
	if USER_ART.has(key):
		var user_spec: Array = USER_ART[key]
		_tex = UserArtAtlas.load_webp_base64(USER_ART_FOLDER, USER_ART_PARTS)
		if _tex == null or _tex.get_width() != 384 or _tex.get_height() != 384:
			return false
		_src = Rect2(user_spec[0], Vector2(192, 192))
		art_facing = int(user_spec[1])
	else:
		var a: Array = ART[key]
		_tex = load(ART_DIR % a[0])
		if _tex == null:
			return false
		_src = Rect2(Vector2.ZERO, _tex.get_size())
		art_facing = int(a[1])
	sheet = s
	if face:
		face.material = null
		face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_layout()
	return true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	face = Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.draw.connect(_draw_face)
	add_child(face)
	rim = Control.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rim.draw.connect(_draw_rim)
	add_child(rim)
	if not square:
		if _shader == null:
			_shader = Shader.new()
			_shader.code = MASK
		var m := ShaderMaterial.new()
		m.shader = _shader
		face.material = m
	resized.connect(_layout)
	_layout()

func show_sheet(g: String, s: String, look := "") -> void:
	group = g
	sheet = s
	var ch: Dictionary = Sheets.character(g, s)
	if ch.is_empty():
		return
	art_facing = 0
	mirror = false
	if face:
		face.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
	# (v0.24) a hero of Zabol in the dialogue box wears his own colours (the round hero portrait keeps its mask)
	if square and face:
		face.material = Looks.material(s, look) if g == "heroes" and look != "" else null
	var at: AtlasTexture = ch["frames"].get_frame_texture("idle_down", 0)
	_tex = at.atlas
	var reg: Rect2 = at.region
	# the head and shoulders: a square from the top of the idle frame
	# (v0.33) a painted hero's cell is wider (his strike reaches out); the face crop keeps the old 120 px cell's measure
	var w: float = minf(reg.size.x, reg.size.y * 120.0 / 156.0) * (0.8 if square else 0.62)
	_src = Rect2(reg.position + Vector2((reg.size.x - w) * 0.5, reg.size.y * (0.0 if square else 0.04)), Vector2(w, w))
	_layout()

func _layout() -> void:
	if face and face.material:
		face.material.set_shader_parameter("center", size * 0.5)
		face.material.set_shader_parameter("radius", min(size.x, size.y) * 0.5 - 2.0)
	queue_redraw()
	if face:
		face.queue_redraw()
	if rim:
		rim.queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r: float = min(size.x, size.y) * 0.5
	if square:
		draw_style_box(UI.box(Color(UI.INK2, 1), ring, 2, 10, 0, 6), Rect2(Vector2.ZERO, size))
	else:
		draw_circle(c + Vector2(0, 2), r + 1.0, Color(0, 0, 0, 0.45))
		draw_circle(c, r, UI.INK2)
		draw_circle(c, r * 0.8, Color(UI.INK3, 0.9))

func _draw_face() -> void:
	if _tex:
		var pad := 2.0 if not square else 5.0
		if art_facing != 0 and mirror:
			face.draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
		face.draw_texture_rect_region(_tex, Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0), _src)
		face.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_rim() -> void:
	if square:
		return
	var c := size * 0.5
	var r: float = min(size.x, size.y) * 0.5
	rim.draw_arc(c, r - 1.5, 0, TAU, 48, ring, 2.5, true)
	rim.draw_arc(c, r - 4.0, 0, TAU, 48, Color(0, 0, 0, 0.35), 1.0, true)

## the level badge is drawn by the HUD on top (so the mask does not clip it)
func badge_pos() -> Vector2:
	return position + size * Vector2(0.84, 0.84)

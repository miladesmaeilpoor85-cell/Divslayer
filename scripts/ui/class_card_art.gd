extends RefCounted
## Six-pose animated illustrations for the four class-selection cards.

const UserArtAtlas = preload("res://scripts/ui/user_art_atlas.gd")
const FOLDER := "assets/art/ClassCards"
const PARTS: Array[String] = [
	"class_motion_atlas.part_00.b64",
	"class_motion_atlas.part_01.b64",
	"class_motion_atlas.part_02.b64",
]
const ORIGINS := {
	"warrior": Vector2i(0, 0),
	"mage": Vector2i(192, 0),
	"rogue": Vector2i(0, 192),
	"paladin": Vector2i(192, 192),
}
static var _frame_cache: Dictionary = {}

static func frames_for(class_name: String) -> Array[Texture2D]:
	if _frame_cache.has(class_name):
		return _frame_cache[class_name] as Array[Texture2D]
	if not ORIGINS.has(class_name):
		return []
	var atlas: Texture2D = UserArtAtlas.load_webp_base64(FOLDER, PARTS)
	if atlas == null or atlas.get_width() != 384 or atlas.get_height() != 384:
		return []

	var origin: Vector2i = ORIGINS[class_name]
	var frames: Array[Texture2D] = []
	for frame in range(6):
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = atlas
		var cell := Vector2i((frame % 2) * 96, int(frame / 2) * 64)
		frame_texture.region = Rect2(Vector2(origin + cell), Vector2(96, 64))
		frames.append(frame_texture)
	_frame_cache[class_name] = frames
	return frames

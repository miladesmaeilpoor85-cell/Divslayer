extends RefCounted
## Six-pose animated illustrations for the four class-selection cards.

const ATLAS: Texture2D = preload("res://assets/art/ClassCards/class_motion_atlas.webp")
const ORIGINS := {
	"warrior": Vector2i(0, 0),
	"mage": Vector2i(192, 0),
	"rogue": Vector2i(0, 192),
	"paladin": Vector2i(192, 192),
}
static var _frame_cache: Dictionary = {}

static func frames_for(calling_name: String) -> Array[Texture2D]:
	if _frame_cache.has(calling_name):
		return _frame_cache[calling_name]
	if not ORIGINS.has(calling_name) or ATLAS == null:
		return []
	if ATLAS.get_width() != 384 or ATLAS.get_height() != 384:
		return []

	var origin: Vector2i = ORIGINS[calling_name]
	var frames: Array[Texture2D] = []
	for frame in range(6):
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = ATLAS
		var cell := Vector2i((frame % 2) * 96, int(frame / 2) * 64)
		frame_texture.region = Rect2(Vector2(origin + cell), Vector2(96, 64))
		frames.append(frame_texture)
	_frame_cache[calling_name] = frames
	return frames

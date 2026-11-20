extends RefCounted
## Builds the Warrior starter runtime atlas from its compact, transparent source image.
## Each source cell is enlarged independently so frame boundaries can never bleed into neighbours.

const SOURCE: Texture2D = preload("res://assets/art/Heroes/warrior_starter_source.webp")
const SOURCE_CELL := Vector2i(32, 31)
const RUNTIME_CELL := Vector2i(160, 156)
const COLUMNS := 5
const ROWS := 3
static var _cached_atlas: Texture2D

static func atlas_texture() -> Texture2D:
	if _cached_atlas != null:
		return _cached_atlas
	var source := SOURCE.get_image()
	if source == null or source.get_width() != SOURCE_CELL.x * COLUMNS or source.get_height() != SOURCE_CELL.y * ROWS:
		push_error("Warrior starter source atlas has invalid dimensions; using the legacy PNG fallback.")
		return null
	var output := Image.create(RUNTIME_CELL.x * COLUMNS, RUNTIME_CELL.y * ROWS, false, Image.FORMAT_RGBA8)
	for row in ROWS:
		for column in COLUMNS:
			var region := Rect2i(column * SOURCE_CELL.x, row * SOURCE_CELL.y, SOURCE_CELL.x, SOURCE_CELL.y)
			var cell := source.get_region(region)
			cell.resize(RUNTIME_CELL.x, RUNTIME_CELL.y, Image.INTERPOLATE_NEAREST)
			output.blit_rect(cell, Rect2i(0, 0, RUNTIME_CELL.x, RUNTIME_CELL.y), Vector2i(column * RUNTIME_CELL.x, row * RUNTIME_CELL.y))
	_cached_atlas = ImageTexture.create_from_image(output)
	return _cached_atlas

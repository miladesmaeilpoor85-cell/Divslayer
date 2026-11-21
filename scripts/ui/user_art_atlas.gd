extends RefCounted
## Loads compact WebP atlases stored as base64 text resources. The text parts are kept
## in the export filter so Godot can load them on desktop and Android without import files.

static var _cache: Dictionary = {}

static func has_parts(folder: String, part_names: Array) -> bool:
	if part_names.is_empty():
		return false
	for raw_name in part_names:
		var path := "res://%s/%s" % [folder, str(raw_name)]
		if not FileAccess.file_exists(path):
			return false
	return true

static func load_webp_base64(folder: String, part_names: Array) -> Texture2D:
	var cache_key := folder
	if _cache.has(cache_key):
		return _cache[cache_key] as Texture2D
	if not has_parts(folder, part_names):
		return null

	var encoded := ""
	for raw_name in part_names:
		var path := "res://%s/%s" % [folder, str(raw_name)]
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_warning("User art atlas part could not be opened: " + path)
			return null
		encoded += file.get_as_text().strip_edges()
		file.close()

	var bytes: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if bytes.is_empty():
		push_warning("User art atlas decoded to an empty byte array: " + folder)
		return null
	var image := Image.new()
	var decode_error: Error = image.load_webp_from_buffer(bytes)
	if decode_error != OK or image.is_empty():
		push_warning("User art WebP could not be decoded: " + folder)
		return null

	var texture := ImageTexture.create_from_image(image)
	_cache[cache_key] = texture
	return texture

static func forget(folder: String = "") -> void:
	if folder == "":
		_cache.clear()
	else:
		_cache.erase(folder)

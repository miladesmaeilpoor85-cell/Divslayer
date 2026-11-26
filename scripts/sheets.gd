extends RefCounted
## Turns the exported sprite sheets into SpriteFrames, using the cell sizes and pivots in art_manifest.json.

const SCALE := 1.0 / 3.0          # sprites were rendered at 3x the game's logical pixels
const DIRS := ["down", "up", "side"]
const WarriorStarterArt = preload("res://scripts/generated/warrior_starter_art.gd")

static var _cache := {}

## Load a transparent PNG atlas from text-safe Base64 parts packaged in the PCK.
## The .b64 files are included by ci/android-qa-export-presets.cfg for Android builds.
static func _load_base64_attack_sheet(folder: String, parts: Array) -> Texture2D:
	var encoded := ""
	for relative_path in parts:
		var path := Game.ART + folder + "/" + str(relative_path)
		var source := FileAccess.open(path, FileAccess.READ)
		if source == null:
			push_error("base64 attack atlas part missing from the build: " + path)
			return null
		encoded += source.get_as_text().strip_edges()
	if encoded.is_empty():
		push_error("base64 attack atlas has no encoded data")
		return null
	var bytes := Marshalls.base64_to_raw(encoded)
	if bytes.is_empty():
		push_error("base64 attack atlas could not be decoded")
		return null
	var image := Image.new()
	var error := image.load_png_from_buffer(bytes)
	if error != OK:
		push_error("base64 attack atlas is not a valid PNG (error " + str(error) + ")")
		return null
	return ImageTexture.create_from_image(image)

## Load a WebP atlas from text-safe Base64 parts packaged in the Android PCK.
static func load_base64_webp_parts(folder: String, parts: Array) -> Texture2D:
	var encoded := ""
	for relative_path in parts:
		var path := Game.ART + folder + "/" + str(relative_path)
		var source := FileAccess.open(path, FileAccess.READ)
		if source == null:
			push_error("base64 WebP asset part missing from the build: " + path)
			return null
		encoded += source.get_as_text().strip_edges()
	if encoded.is_empty():
		push_error("base64 WebP asset has no encoded data")
		return null
	var bytes := Marshalls.base64_to_raw(encoded)
	if bytes.is_empty():
		push_error("base64 WebP asset could not be decoded")
		return null
	var image := Image.new()
	var error := image.load_webp_from_buffer(bytes)
	if error != OK:
		push_error("base64 data is not a valid WebP image (error " + str(error) + ")")
		return null
	return ImageTexture.create_from_image(image)

static func _atlas(tex: Texture2D, x: float, y: float, w: float, h: float) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(x, y, w, h)
	return a

## offset that puts the sprite's pivot (bottom-centre of the feet) on the node origin
static func pivot_offset(meta: Dictionary) -> Vector2:
	var p: Array = meta.get("pivot", [0.5, 0.0])
	return Vector2(-float(meta["cellW"]) * float(p[0]), -float(meta["cellH"]) * (1.0 - float(p[1])))

## Duration of a non-looping clip, never shorter than its gameplay minimum.
## SpriteFrames stores FPS; AnimatedSprite2D.speed_scale is applied at runtime.
static func animation_duration(frames: SpriteFrames, animation: String, minimum_seconds := 0.0, playback_scale := 1.0) -> float:
	var minimum := maxf(0.0, float(minimum_seconds))
	if frames == null or not frames.has_animation(animation):
		return minimum
	var count := frames.get_frame_count(animation)
	var fps := frames.get_animation_speed(animation) * absf(float(playback_scale))
	if count <= 0 or fps <= 0.0:
		return minimum
	return maxf(minimum, float(count) / fps)

## Seconds from the animation start to the beginning of a zero-based impact frame.
## Missing clips, invalid FPS and out-of-range indices fail safely to frame zero / no delay.
static func animation_impact_time(frames: SpriteFrames, animation: String, impact_frame: int, playback_scale := 1.0) -> float:
	if frames == null or not frames.has_animation(animation):
		return 0.0
	var count := frames.get_frame_count(animation)
	var fps := frames.get_animation_speed(animation) * absf(float(playback_scale))
	if count <= 0 or fps <= 0.0:
		return 0.0
	var frame := clampi(impact_frame, 0, count - 1)
	return float(frame) / fps

## Build directional hero/villager animations from named atlas columns.
## An optional separate attack sheet keeps new combat frames independent from walk art.
static func character_frames(tex: Texture2D, meta: Dictionary, attack_texture: Texture2D = null, attack_frame_rows: Array = []) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if tex == null:
		push_error("character sheet texture is missing")
		return sf

	var cw := int(meta.get("cellW", 0))
	var ch := int(meta.get("cellH", 0))
	var cols: Array = meta.get("cols", ["walk0", "walk1", "walk2", "walk3", "attack"])
	if cw <= 0 or ch <= 0 or cols.is_empty():
		push_error("character sheet metadata has invalid cell dimensions or no columns")
		return sf

	var walk_columns: Array[int] = []
	var embedded_attack_columns: Array[int] = []
	for index in range(cols.size()):
		var label := str(cols[index])
		if label.begins_with("walk"):
			walk_columns.append(index)
		elif label.begins_with("attack"):
			embedded_attack_columns.append(index)
		else:
			push_error("unsupported character sheet column: " + label)
			return sf
	if walk_columns.is_empty():
		push_error("character sheet needs at least one walk column")
		return sf
	if tex.get_width() < cw * cols.size() or tex.get_height() < ch * DIRS.size():
		push_error("character sheet dimensions do not fit the declared column/cell layout")
		return sf

	var attack_frames := int(meta.get("attackFrames", embedded_attack_columns.size()))
	var has_attack_frame_rows := not attack_frame_rows.is_empty()
	if attack_texture == null and embedded_attack_columns.is_empty() and not has_attack_frame_rows:
		push_error("character sheet needs embedded attack columns, a separate attack atlas, or separate attack frame files")
		return sf
	if attack_frames < 1:
		push_error("attackFrames must be a positive integer")
		return sf
	if attack_texture != null:
		if attack_texture.get_width() < cw * attack_frames or attack_texture.get_height() < ch * DIRS.size():
			push_error("separate attack atlas dimensions do not fit attackFrames and character cell dimensions")
			return sf
	if has_attack_frame_rows:
		if attack_frame_rows.size() != DIRS.size():
			push_error("separate attack frame files must provide one row for each character direction")
			return sf
		for raw_row in attack_frame_rows:
			var frame_row: Array = raw_row
			if frame_row.size() != attack_frames:
				push_error("separate attack frame row does not match attackFrames")
				return sf
			for raw_frame in frame_row:
				if not (raw_frame is Texture2D):
					push_error("separate attack frame file did not load as a texture")
					return sf
				var frame_texture: Texture2D = raw_frame
				if frame_texture.get_width() != cw or frame_texture.get_height() != ch:
					push_error("separate attack frame dimensions must exactly match cellW and cellH")
					return sf

	var walk_fps := maxf(1.0, float(meta.get("walkFps", 9.0)))
	var attack_fps := maxf(1.0, float(meta.get("attackFps", 24.0)))
	for row in range(DIRS.size()):
		var direction: String = DIRS[row]
		var walk := "walk_" + direction
		sf.add_animation(walk)
		sf.set_animation_speed(walk, walk_fps)
		for column in walk_columns:
			sf.add_frame(walk, _atlas(tex, column * cw, row * ch, cw, ch))

		var idle := "idle_" + direction
		sf.add_animation(idle)
		sf.add_frame(idle, _atlas(tex, walk_columns[0] * cw, row * ch, cw, ch))

		var hit := "attack_" + direction
		sf.add_animation(hit)
		sf.set_animation_speed(hit, attack_fps)
		sf.set_animation_loop(hit, false)
		if has_attack_frame_rows:
			var frame_row: Array = attack_frame_rows[row]
			for frame_texture in frame_row:
				sf.add_frame(hit, frame_texture)
		elif attack_texture != null:
			for frame in range(attack_frames):
				sf.add_frame(hit, _atlas(attack_texture, frame * cw, row * ch, cw, ch))
		else:
			for column in embedded_attack_columns:
				sf.add_frame(hit, _atlas(tex, column * cw, row * ch, cw, ch))
	return sf

## heroes and villagers: rows down/up/side, named columns from art_manifest.json
static func character(group: String, sheet: String) -> Dictionary:
	var key := group + "/" + sheet
	if _cache.has(key):
		return _cache[key]
	var meta: Dictionary = Game.manifest.get(group, {}).get(sheet, {})
	var folder := group.capitalize()
	var tex: Texture2D = null
	if group == "heroes" and sheet == "warrior_starter":
		tex = WarriorStarterArt.atlas_texture()
	if tex == null:
		var sheet_extension := str(meta.get("extension", "png")).to_lower().trim_prefix(".")
		if sheet_extension not in ["png", "webp", "jpg", "jpeg", "svg"]:
			push_error("unsupported character sheet extension for " + group + "/" + sheet)
			return {"frames": SpriteFrames.new(), "offset": Vector2.ZERO, "meta": meta}
		tex = load(Game.ART + folder + "/" + sheet + "." + sheet_extension)
	var attack_texture: Texture2D = null
	if meta.has("attackSheetBase64Parts"):
		attack_texture = _load_base64_attack_sheet(folder, meta["attackSheetBase64Parts"])
	elif meta.has("attackSheet"):
		attack_texture = load(Game.ART + folder + "/" + str(meta["attackSheet"]))
		if attack_texture == null:
			push_error("separate attack sheet missing from the build: " + str(meta["attackSheet"]))
	var attack_frame_rows: Array = []
	if meta.has("attackFrameFiles"):
		var frame_file_rows: Array = meta["attackFrameFiles"]
		if frame_file_rows.size() != DIRS.size():
			push_error("attackFrameFiles must contain down, up and side rows")
		else:
			for row in range(DIRS.size()):
				var loaded_row: Array = []
				var frame_paths: Array = frame_file_rows[row]
				for relative_path in frame_paths:
					var frame_path := Game.ART + folder + "/" + str(relative_path)
					var frame_texture: Texture2D = load(frame_path)
					if frame_texture == null:
						push_error("separate attack frame missing from the build: " + frame_path)
					loaded_row.append(frame_texture)
				attack_frame_rows.append(loaded_row)
	var sf := character_frames(tex, meta, attack_texture, attack_frame_rows)
	var out := {"frames": sf, "offset": pivot_offset(runtime_meta), "meta": runtime_meta}
	_cache[key] = out
	return out

## (v0.27, engineering) on a map change: forget the foes' sheets, so a long session does not keep every foe met in memory
static func forget_enemies() -> void:
	for k in _cache.keys():
		if str(k).begins_with("enemies/"):
			_cache.erase(k)

## enemies: one animation per variant row ("v0", "v1" …), frames along the row
static func enemy(type: String) -> Dictionary:
	var key := "enemies/" + type
	if _cache.has(key):
		return _cache[key]
	var meta: Dictionary = Game.manifest.get("enemies", {}).get(type, {})
	if not meta.has("cellW"):
		_cache[key] = {}
		return {}
	var enemy_file := str(meta.get("file", type))
	var enemy_extension := str(meta.get("extension", "png"))
	var base64_parts: Array = meta.get("base64Parts", [])
	var tex: Texture2D = load_base64_webp_parts("Enemies", base64_parts) if not base64_parts.is_empty() else null
	var source_density := float(meta.get("pxPerUnitLogical", 3.0))
	var used_fallback := false
	if tex == null:
		# Existing SVG/PNG remains as a safe fallback with its original atlas cell geometry and density.
		tex = load(Game.ART + "Enemies/" + enemy_file + "." + enemy_extension)
		source_density = float(meta.get("fallbackPxPerUnitLogical", 3.0))
		used_fallback = true
	if tex == null:
		push_error("sheet missing from the build: Enemies/" + enemy_file + "." + enemy_extension)
		_cache[key] = {}
		return {}
	var runtime_meta: Dictionary = meta.duplicate(true)
	runtime_meta["pxPerUnitLogical"] = source_density
	if used_fallback:
		runtime_meta["cellW"] = int(meta.get("fallbackCellW", meta["cellW"]))
		runtime_meta["cellH"] = int(meta.get("fallbackCellH", meta["cellH"]))
	var sf := SpriteFrames.new()
	var cw := float(runtime_meta["cellW"])
	var ch := float(runtime_meta["cellH"])
	var fps := 7.0
	if meta.get("timedMs", null) != null:
		fps = 1000.0 / float(meta["timedMs"])
	for v in int(meta.get("variants", 1)):
		var a := "v%d" % v
		sf.add_animation(a)
		sf.set_animation_speed(a, fps)
		for f in int(meta.get("frames", 1)):
			sf.add_frame(a, _atlas(tex, f * cw, v * ch, cw, ch))
	var out := {"frames": sf, "offset": pivot_offset(meta), "meta": meta}
	_cache[key] = out
	return out

## a single still sprite (props, items, map objects) with its pivot
static func still(path: String, w: float, h: float, pivot_y: float) -> Dictionary:
	return {"texture": load(path), "offset": Vector2(-w * 0.5, -h * (1.0 - pivot_y))}

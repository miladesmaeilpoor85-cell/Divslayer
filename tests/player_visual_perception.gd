extends RefCounted
## Screenshot frame capture and strict normalization boundary for visual detections.
## Pixel perception consumes Image data and SpriteFrames-derived templates only.
## It never reads scene nodes, enemy groups, Game state, or world coordinates.

const MIN_CONFIDENCE := 0.55
const MAX_HEURISTIC_WARNING_CONFIDENCE := 0.64
const KINDS := ["player", "enemy", "boss", "telegraph", "projectile"]

static func capture_frame(viewport: Viewport) -> Dictionary:
	# Godot's --headless mode disables rendering; ViewportTexture readback has no
	# backing texture there. Real screenshot capture is exercised by the Xvfb journey.
	if DisplayServer.get_name() == "headless":
		return {}
	if viewport == null or viewport.get_texture() == null:
		return {}
	var frame := viewport.get_texture().get_image()
	if frame == null or frame.is_empty():
		return {}
	return {
		"captured_at_msec": Time.get_ticks_msec(),
		"width": frame.get_width(),
		"height": frame.get_height(),
		"image": frame
	}

## Extract an image from a SpriteFrames texture, respecting AtlasTexture regions.
## The source art is cropped to non-transparent pixels and resized with nearest-neighbour
## sampling to the scale used by the in-game AnimatedSprite2D.
static func sprite_image_from_texture(texture: Texture2D, rendered_scale := 1.0 / 3.0) -> Image:
	if texture == null or rendered_scale <= 0.0:
		return null
	var source_image: Image = null
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		if atlas_texture.atlas == null:
			return null
		var atlas_image := atlas_texture.atlas.get_image()
		if atlas_image == null or atlas_image.is_empty():
			return null
		var region := atlas_texture.region
		var left := clampi(roundi(region.position.x), 0, atlas_image.get_width())
		var top := clampi(roundi(region.position.y), 0, atlas_image.get_height())
		var right := clampi(roundi(region.end.x), left, atlas_image.get_width())
		var bottom := clampi(roundi(region.end.y), top, atlas_image.get_height())
		if right <= left or bottom <= top:
			return null
		source_image = atlas_image.get_region(Rect2i(left, top, right - left, bottom - top))
	else:
		source_image = texture.get_image()
	if source_image == null or source_image.is_empty():
		return null
	var used := source_image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	var cropped := source_image.get_region(used)
	var target_width := maxi(1, roundi(float(cropped.get_width()) * rendered_scale))
	var target_height := maxi(1, roundi(float(cropped.get_height()) * rendered_scale))
	if target_width != cropped.get_width() or target_height != cropped.get_height():
		cropped.resize(target_width, target_height, Image.INTERPOLATE_NEAREST)
	return cropped

## Build a small template bank directly from the game's actual SpriteFrames.
## Each template carries only an asset identity; it does not assert that the actor is present.
static func build_sprite_templates(
	frames: SpriteFrames,
	animations: Array,
	kind: String,
	id_prefix: String,
	rendered_scale := 1.0 / 3.0,
	max_frames_per_animation := 1
) -> Array[Dictionary]:
	var templates: Array[Dictionary] = []
	if frames == null or kind not in KINDS or id_prefix.strip_edges().is_empty():
		return templates
	var frame_limit := maxi(1, max_frames_per_animation)
	for animation_value in animations:
		var animation := str(animation_value)
		if not frames.has_animation(animation):
			continue
		var frame_count := frames.get_frame_count(animation)
		if frame_count <= 0:
			continue
		var take_count := mini(frame_limit, frame_count)
		for sample_index in range(take_count):
			var frame_index := 0
			if take_count > 1:
				frame_index = roundi(float(sample_index) * float(frame_count - 1) / float(take_count - 1))
			var texture := frames.get_frame_texture(animation, frame_index)
			var image := sprite_image_from_texture(texture, rendered_scale)
			if image == null or image.is_empty() or image.get_width() < 4 or image.get_height() < 4:
				continue
			templates.append({
				"id": "%s:%s:%d" % [id_prefix, animation, frame_index],
				"kind": kind,
				"animation": animation,
				"frame_index": frame_index,
				"image": image
			})
	return templates

## Candidate contract: {kind, confidence, rect:[x,y,w,h]} where rect is normalized
## to the screenshot dimensions. Coordinates are screen-relative, never world-relative.
static func normalize_detections(candidates: Array, frame_size: Vector2i) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if frame_size.x <= 0 or frame_size.y <= 0:
		return output
	for candidate in candidates:
		if typeof(candidate) != TYPE_DICTIONARY:
			continue
		var kind := str(candidate.get("kind", ""))
		var confidence := float(candidate.get("confidence", 0.0))
		var raw_rect: Variant = candidate.get("rect", [])
		if kind not in KINDS or confidence < MIN_CONFIDENCE or typeof(raw_rect) != TYPE_ARRAY or raw_rect.size() != 4:
			continue
		var rect := Rect2(float(raw_rect[0]), float(raw_rect[1]), float(raw_rect[2]), float(raw_rect[3]))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > 1.0 or rect.end.y > 1.0:
			continue
		var detection := {
			"kind": kind,
			"confidence": clampf(confidence, 0.0, 1.0),
			"rect": rect,
			"center": rect.get_center(),
			"frame_size": frame_size
		}
		for field in ["template_id", "method", "warning_kind"]:
			if candidate.has(field):
				detection[field] = candidate[field]
		output.append(detection)
	return output

## Exhaustive coarse pixel-template matching. Transparent pixels are ignored.
## Templates must be cropped from the game's actual SpriteFrames and scaled to their
## rendered viewport size by sprite_image_from_texture().
static func match_template(frame: Image, template: Image, kind: String, sample_step := 3, threshold := 0.78) -> Dictionary:
	if frame == null or template == null or frame.is_empty() or template.is_empty():
		return {}
	if kind not in KINDS or template.get_width() > frame.get_width() or template.get_height() > frame.get_height():
		return {}
	var step := maxi(2, sample_step)
	var max_x := frame.get_width() - template.get_width()
	var max_y := frame.get_height() - template.get_height()
	var best_coarse_score := -1.0
	var best_position := Vector2i.ZERO
	var best_score := -1.0
	var best_count := 0
	# Coarse pass keeps the scan bounded for phone-sized viewports.
	for y in range(0, max_y + 1, step):
		for x in range(0, max_x + 1, step):
			var coarse_score := _template_score_at(frame, template, Vector2i(x, y), step)
			if coarse_score > best_coarse_score:
				best_coarse_score = coarse_score
				best_position = Vector2i(x, y)
	# Pixel-accurate refinement around the best coarse location compensates for
	# camera sub-pixel movement and sprite origins that do not align to the coarse grid.
	var refine_radius := step - 1
	var refine_min_x := maxi(0, best_position.x - refine_radius)
	var refine_max_x := mini(max_x, best_position.x + refine_radius)
	var refine_min_y := maxi(0, best_position.y - refine_radius)
	var refine_max_y := mini(max_y, best_position.y + refine_radius)
	for y in range(refine_min_y, refine_max_y + 1):
		for x in range(refine_min_x, refine_max_x + 1):
			var refined_score := _template_score_at(frame, template, Vector2i(x, y), 1)
			if refined_score > best_score:
				best_score = refined_score
				best_position = Vector2i(x, y)
				best_count = template.get_width() * template.get_height()
	if best_score < threshold:
		return {}
	return {
		"kind": kind,
		"confidence": clampf(best_score, 0.0, 1.0),
		"rect": [
			float(best_position.x) / float(frame.get_width()),
			float(best_position.y) / float(frame.get_height()),
			float(template.get_width()) / float(frame.get_width()),
			float(template.get_height()) / float(frame.get_height())
		],
		"sample_count": best_count,
		"method": "sprite_pixel_template"
	}

static func _template_score_at(frame: Image, template: Image, position: Vector2i, sample_step: int) -> float:
	var error_sum := 0.0
	var count := 0
	for ty in range(0, template.get_height(), sample_step):
		for tx in range(0, template.get_width(), sample_step):
			var expected := template.get_pixel(tx, ty)
			if expected.a < 0.35:
				continue
			var actual := frame.get_pixel(position.x + tx, position.y + ty)
			error_sum += (absf(expected.r - actual.r) + absf(expected.g - actual.g) + absf(expected.b - actual.b)) / 3.0
			count += 1
	if count < 8:
		return -1.0
	return 1.0 - error_sum / float(count)

## Convert broad colour proposals to screen-normalized candidates.
## These are intentionally capped below the brain's defensive-action threshold.
static func warning_proposals(warnings: Array, frame_size: Vector2i) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if frame_size.x <= 0 or frame_size.y <= 0:
		return candidates
	for warning in warnings:
		if typeof(warning) != TYPE_DICTIONARY:
			continue
		var raw_rect: Variant = warning.get("rect", Rect2())
		if typeof(raw_rect) != TYPE_RECT2 and typeof(raw_rect) != TYPE_RECT2I:
			continue
		var pixel_rect := Rect2(raw_rect)
		if pixel_rect.size.x <= 0.0 or pixel_rect.size.y <= 0.0:
			continue
		var normalized := Rect2(
			pixel_rect.position.x / float(frame_size.x),
			pixel_rect.position.y / float(frame_size.y),
			pixel_rect.size.x / float(frame_size.x),
			pixel_rect.size.y / float(frame_size.y)
		)
		candidates.append({
			"kind": "telegraph",
			"confidence": minf(float(warning.get("confidence", 0.0)), MAX_HEURISTIC_WARNING_CONFIDENCE),
			"rect": [normalized.position.x, normalized.position.y, normalized.size.x, normalized.size.y],
			"warning_kind": str(warning.get("kind", "unknown")),
			"method": "colour_region_proposal"
		})
	return normalize_detections(candidates, frame_size)

## Match a bounded set of known Sprite-derived templates. Return one best match per
## template and suppress overlapping duplicate animation-frame matches.
static func detect_sprite_templates(frame: Image, templates: Array, sample_step := 3, threshold := 0.78) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for entry in templates:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var sprite_image: Variant = entry.get("image")
		if not (sprite_image is Image):
			continue
		var match_result := match_template(frame, sprite_image, str(entry.get("kind", "")), sample_step, threshold)
		if not match_result.is_empty():
			match_result["template_id"] = str(entry.get("id", ""))
			candidates.append(match_result)
	var normalized := normalize_detections(candidates, frame.get_size())
	var deduplicated: Array[Dictionary] = []
	for candidate in normalized:
		var duplicate_index := -1
		for index in deduplicated.size():
			var existing: Dictionary = deduplicated[index]
			if str(existing.get("kind", "")) != str(candidate.get("kind", "")):
				continue
			if _intersection_over_union(existing.get("rect", Rect2()), candidate.get("rect", Rect2())) >= 0.7:
				duplicate_index = index
				break
		if duplicate_index < 0:
			deduplicated.append(candidate)
		elif float(candidate.get("confidence", 0.0)) > float(deduplicated[duplicate_index].get("confidence", 0.0)):
			deduplicated[duplicate_index] = candidate
	return deduplicated

static func _intersection_over_union(a: Rect2, b: Rect2) -> float:
	var intersection := a.intersection(b)
	if intersection.size.x <= 0.0 or intersection.size.y <= 0.0:
		return 0.0
	var union_area := a.get_area() + b.get_area() - intersection.get_area()
	return intersection.get_area() / union_area if union_area > 0.0 else 0.0

static func observation(frame: Dictionary, candidates: Array) -> Dictionary:
	if frame.is_empty():
		return {"captured_at_msec": Time.get_ticks_msec(), "frame_size": Vector2i.ZERO, "detections": []}
	var frame_size := Vector2i(int(frame.get("width", 0)), int(frame.get("height", 0)))
	return {
		"captured_at_msec": int(frame.get("captured_at_msec", Time.get_ticks_msec())),
		"frame_size": frame_size,
		"image": frame.get("image"),
		"detections": normalize_detections(candidates, frame_size)
	}

extends RefCounted
## Screenshot frame capture and strict normalization boundary for visual detections.
## This module never reads scene nodes, enemy groups, Game state, or world coordinates.
## A detector must provide image-derived candidates; invalid/uncertain candidates are discarded.

const MIN_CONFIDENCE := 0.55
const KINDS := ["player", "enemy", "boss", "telegraph", "projectile"]

static func capture_frame(viewport: Viewport) -> Dictionary:
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
		output.append({
			"kind": kind,
			"confidence": clampf(confidence, 0.0, 1.0),
			"rect": rect,
			"center": rect.get_center(),
			"frame_size": frame_size
		})
	return output

## Exhaustive coarse pixel-template matching. Templates must be cropped from the game's
## actual SpriteFrames/AtlasTexture and scaled to their rendered viewport size by the caller.
## Transparent template pixels are ignored; matching uses RGB absolute error and refuses
## ambiguous/weak matches. This operates only on Image pixels, never on scene nodes.
static func match_template(frame: Image, template: Image, kind: String, sample_step := 3, threshold := 0.78) -> Dictionary:
	if frame == null or template == null or frame.is_empty() or template.is_empty():
		return {}
	if kind not in KINDS or template.get_width() > frame.get_width() or template.get_height() > frame.get_height():
		return {}
	var step := maxi(1, sample_step)
	var best_score := -1.0
	var best_position := Vector2i.ZERO
	var best_count := 0
	var max_x := frame.get_width() - template.get_width()
	var max_y := frame.get_height() - template.get_height()
	for y in range(0, max_y + 1, step):
		for x in range(0, max_x + 1, step):
			var error_sum := 0.0
			var count := 0
			for ty in range(0, template.get_height(), step):
				for tx in range(0, template.get_width(), step):
					var expected := template.get_pixel(tx, ty)
					if expected.a < 0.35:
						continue
					var actual := frame.get_pixel(x + tx, y + ty)
					error_sum += (absf(expected.r - actual.r) + absf(expected.g - actual.g) + absf(expected.b - actual.b)) / 3.0
					count += 1
			if count < 8:
				continue
			var score := 1.0 - error_sum / float(count)
			if score > best_score:
				best_score = score
				best_position = Vector2i(x, y)
				best_count = count
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

## Match a bounded set of known Sprite-derived templates. Return one best match per
## template; callers should supply the hero and boss/enemy frames relevant to the encounter.
static func detect_sprite_templates(frame: Image, templates: Array, sample_step := 3, threshold := 0.78) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for entry in templates:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var sprite_image: Variant = entry.get("image")
		if not (sprite_image is Image):
			continue
		var match := match_template(frame, sprite_image, str(entry.get("kind", "")), sample_step, threshold)
		if not match.is_empty():
			match["template_id"] = str(entry.get("id", ""))
			candidates.append(match)
	return normalize_detections(candidates, frame.get_size())

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

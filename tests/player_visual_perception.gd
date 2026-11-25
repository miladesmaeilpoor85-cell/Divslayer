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

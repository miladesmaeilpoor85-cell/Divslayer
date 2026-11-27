extends RefCounted
## Pixel-only perception from the rendered viewport. No scene/world/entity queries.
## Regions are candidates, not semantic truth; the brain must respect confidence and unknown labels.
const SAMPLE_STEP := 3
const MIN_WARNING_PIXELS := 5

static func capture(viewport: Viewport) -> Dictionary:
	if viewport == null or DisplayServer.get_name() == "headless":
		return {"valid": false, "size": Vector2i.ZERO, "warnings": []}
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return {"valid": false, "size": Vector2i.ZERO, "warnings": []}
	return {"valid": true, "size": image.get_size(), "captured_at_msec": Time.get_ticks_msec(), "warnings": _detect_warning_regions(image)}

## Broad colour candidates only; never infer enemy identity from colour alone.
static func _detect_warning_regions(image: Image) -> Array[Dictionary]:
	var warm := _empty_bounds()
	var cold := _empty_bounds()
	var warm_count := 0
	var cold_count := 0
	for y in range(48, image.get_height(), SAMPLE_STEP):
		for x in range(0, image.get_width(), SAMPLE_STEP):
			var c := image.get_pixel(x, y)
			if c.a < 0.65:
				continue
			if c.r > 0.68 and c.g > 0.16 and c.g < 0.68 and c.b < 0.38 and c.r > c.g * 1.25:
				_include(warm, x, y)
				warm_count += 1
			elif c.g > 0.58 and c.b > 0.62 and c.r < 0.48 and c.b > c.r * 1.35:
				_include(cold, x, y)
				cold_count += 1
	var result: Array[Dictionary] = []
	if warm_count >= MIN_WARNING_PIXELS:
		result.append(_region("warm_telegraph_candidate", warm, warm_count, image.get_size()))
	if cold_count >= MIN_WARNING_PIXELS:
		result.append(_region("cold_telegraph_candidate", cold, cold_count, image.get_size()))
	return result

static func _empty_bounds() -> Dictionary:
	return {"min_x": 2147483647, "min_y": 2147483647, "max_x": -1, "max_y": -1}

static func _include(bounds: Dictionary, x: int, y: int) -> void:
	bounds["min_x"] = mini(int(bounds["min_x"]), x)
	bounds["min_y"] = mini(int(bounds["min_y"]), y)
	bounds["max_x"] = maxi(int(bounds["max_x"]), x)
	bounds["max_y"] = maxi(int(bounds["max_y"]), y)

static func _region(kind: String, bounds: Dictionary, count: int, image_size: Vector2i) -> Dictionary:
	var rect := Rect2i(int(bounds["min_x"]), int(bounds["min_y"]), int(bounds["max_x"]) - int(bounds["min_x"]) + SAMPLE_STEP, int(bounds["max_y"]) - int(bounds["min_y"]) + SAMPLE_STEP)
	return {"kind": kind, "rect": rect, "sample_count": count, "screen_size": image_size, "confidence": clampf(float(count) / 36.0, 0.15, 0.85)}

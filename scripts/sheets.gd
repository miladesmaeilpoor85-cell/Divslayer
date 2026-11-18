extends RefCounted
## Turns the exported sprite sheets into SpriteFrames, using the cell sizes and pivots in art_manifest.json.

const SCALE := 1.0 / 3.0          # sprites were rendered at 3x the game's logical pixels
const DIRS := ["down", "up", "side"]

static var _cache := {}

static func _atlas(tex: Texture2D, x: float, y: float, w: float, h: float) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(x, y, w, h)
	return a

## offset that puts the sprite's pivot (bottom-centre of the feet) on the node origin
static func pivot_offset(meta: Dictionary) -> Vector2:
	var p: Array = meta.get("pivot", [0.5, 0.0])
	return Vector2(-float(meta["cellW"]) * float(p[0]), -float(meta["cellH"]) * (1.0 - float(p[1])))

## heroes and villagers: rows down/up/side, columns walk0-3 + attack
static func character(group: String, sheet: String) -> Dictionary:
	var key := group + "/" + sheet
	if _cache.has(key):
		return _cache[key]
	var meta: Dictionary = Game.manifest.get(group, {}).get(sheet, {})
	var folder := group.capitalize()
	var tex: Texture2D = load(Game.ART + folder + "/" + sheet + ".png")
	var sf := SpriteFrames.new()
	var cw := float(meta["cellW"])
	var ch := float(meta["cellH"])
	for r in DIRS.size():
		var d: String = DIRS[r]
		var walk := "walk_" + d
		sf.add_animation(walk)
		sf.set_animation_speed(walk, 9.0)
		for c in 4:
			sf.add_frame(walk, _atlas(tex, c * cw, r * ch, cw, ch))
		var idle := "idle_" + d
		sf.add_animation(idle)
		sf.add_frame(idle, _atlas(tex, 0, r * ch, cw, ch))
		var hit := "attack_" + d
		sf.add_animation(hit)
		sf.set_animation_loop(hit, false)
		var hit_tex := tex
		var hit_frames := 1
		var hit_fps := 0.0
		if meta.has("attackSheet"):
			hit_tex = load(Game.ART + folder + "/" + str(meta["attackSheet"]) + ".png")
			if hit_tex == null:
				push_error("attack sheet missing from the build: %s/%s.png" % [folder, meta["attackSheet"]])
				hit_tex = tex
			else:
				hit_frames = int(meta.get("attackFrames", 1))
				hit_fps = float(meta.get("attackFps", 0.0))
		if hit_fps > 0.0:
			sf.set_animation_speed(hit, hit_fps)
		if hit_frames > 1:
			for c in hit_frames:
				sf.add_frame(hit, _atlas(hit_tex, c * cw, r * ch, cw, ch))
		else:
			sf.add_frame(hit, _atlas(tex, 4 * cw, r * ch, cw, ch))
	var out := {"frames": sf, "offset": pivot_offset(meta), "meta": meta}
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
	var tex: Texture2D = load(Game.ART + "Enemies/" + type + ".png")
	if tex == null:
		push_error("sheet missing from the build: Enemies/%s.png" % type)
	var sf := SpriteFrames.new()
	var cw := float(meta["cellW"])
	var ch := float(meta["cellH"])
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

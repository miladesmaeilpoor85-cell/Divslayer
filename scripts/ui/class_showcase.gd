extends TextureRect
## A lightweight six-pose illustration loop used in the hero's pause-menu folio.
## The gameplay SpriteFrames remain the source of truth for combat and equipment.
## A short alpha blend softens pose changes without inventing in-between combat frames.

const ClassCardArt = preload("res://scripts/ui/class_card_art.gd")
const FRAME_SECONDS := 0.18
const FRAME_BLEND_SECONDS := 0.065
var _frames: Array[Texture2D] = []
var _frame := 0
var _clock := 0.0
var _blend_overlay: TextureRect

func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_blend_overlay = TextureRect.new()
	_blend_overlay.name = "FrameBlendOverlay"
	_blend_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blend_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_blend_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_blend_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_blend_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blend_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_blend_overlay)

func set_calling(class_id: String) -> void:
	_frames = ClassCardArt.frames_for(class_id)
	_frame = 0
	_clock = 0.0
	visible = _frames.size() == 6
	if visible:
		texture = _frames[0]
	else:
		texture = null
	if is_instance_valid(_blend_overlay):
		_blend_overlay.texture = null
		_blend_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)

func _process(delta: float) -> void:
	if _frames.size() != 6 or not visible:
		return
	_clock += maxf(delta, 0.0)
	if _clock >= FRAME_SECONDS:
		var steps := int(floor(_clock / FRAME_SECONDS))
		_clock -= float(steps) * FRAME_SECONDS
		_frame = (_frame + steps) % _frames.size()
		if is_instance_valid(_blend_overlay):
			_blend_overlay.texture = _frames[_frame]
			_blend_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
		else:
			texture = _frames[_frame]

	# _clock is also the elapsed time since the last pose boundary, so a
	# slow frame does not restart or exaggerate the short crossfade.
	if is_instance_valid(_blend_overlay) and _blend_overlay.texture != null:
		var blend := clampf(_clock / FRAME_BLEND_SECONDS, 0.0, 1.0)
		if blend >= 1.0:
			texture = _blend_overlay.texture
			_blend_overlay.texture = null
			_blend_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
		else:
			_blend_overlay.modulate = Color(1.0, 1.0, 1.0, blend)

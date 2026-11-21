extends TextureRect
## A lightweight six-pose illustration loop used in the hero's pause-menu folio.
## The gameplay SpriteFrames remain the source of truth for combat and equipment.

const ClassCardArt = preload("res://scripts/ui/class_card_art.gd")
const FRAME_SECONDS := 0.18
var _frames: Array[Texture2D] = []
var _frame := 0
var _clock := 0.0

func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_calling(class_id: String) -> void:
	_frames = ClassCardArt.frames_for(class_id)
	_frame = 0
	_clock = 0.0
	visible = _frames.size() == 6
	if visible:
		texture = _frames[0]
	else:
		texture = null

func _process(delta: float) -> void:
	if _frames.size() != 6 or not visible:
		return
	_clock += maxf(delta, 0.0)
	if _clock < FRAME_SECONDS:
		return
	var steps := int(floor(_clock / FRAME_SECONDS))
	_clock -= float(steps) * FRAME_SECONDS
	_frame = (_frame + steps) % _frames.size()
	texture = _frames[_frame]

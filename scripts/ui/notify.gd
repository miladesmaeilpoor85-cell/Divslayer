extends Control
## On-screen messages in one place (top centre, under the boss bar), one at a time and queued, so they
## never overlap each other, the map title or the boss banners. Hints stay longer and get a gold frame.

const Y0 := 62.0          # just under the boss bar
const BAND := [0.335, 0.815]   # the free strip of the top of the screen (fractions of its width)
var queue: Array = []
var panel: PanelContainer
var icon_r: TextureRect
var text_l: Label
var _tw: Tween
var _busy := false

func _ready() -> void:
	add_to_group("notify")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0
	add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	icon_r = UI.icon_rect("info", 16)
	h.add_child(icon_r)
	text_l = UI.label("", 13, UI.CREAM)
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(text_l)

## text, an icon name from data/icons.json, accent colour, seconds on screen
func push(text: String, icon := "info", col := UI.GOLD, sec := 2.4) -> void:
	if text == "":
		return
	for q in queue:
		if q[0] == text:
			return
	queue.append([text, icon, col, sec])
	if not _busy:
		_next()

func clear() -> void:
	queue.clear()
	if _tw:
		_tw.kill()
	panel.modulate.a = 0.0
	_busy = false

func _next() -> void:
	if queue.is_empty():
		_busy = false
		return
	_busy = true
	var q: Array = queue.pop_front()
	text_l.text = q[0]
	text_l.text_direction = Control.TEXT_DIRECTION_RTL if Game.lang == "fa" else Control.TEXT_DIRECTION_LTR
	icon_r.texture = UI.icon(q[1], 48) if UI.has_icon(q[1]) else UI.icon("info", 48)
	icon_r.modulate = q[2]
	var long: bool = float(q[3]) > 3.0
	panel.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.9), q[2] if long else Color(q[2], 0.55), 2 if long else 1, 18, 14, 6))
	# width: fit short messages on one line, wrap long ones inside the band between the hero's panel (top left) and
	# the minimap (top right) — (v0.24, playtest: a long message lay over the objective)
	var vw: float = size.x
	var band_l: float = vw * BAND[0]
	var band_w: float = vw * (BAND[1] - BAND[0])
	var f: Font = UI.font_body
	var tw: float = f.get_string_size(q[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x if f else 200.0
	var maxw: float = band_w
	var one_line: bool = tw + 64.0 <= maxw
	text_l.autowrap_mode = TextServer.AUTOWRAP_OFF if one_line else TextServer.AUTOWRAP_WORD_SMART
	text_l.custom_minimum_size = Vector2(tw + 4.0 if one_line else maxw - 64.0, 0)
	panel.size = Vector2.ZERO
	panel.reset_size()
	await get_tree().process_frame
	panel.reset_size()
	var w: float = panel.size.x
	panel.position = Vector2(band_l + max(0.0, (band_w - w) * 0.5), Y0)
	var hold: float = float(q[3]) * (0.6 if queue.size() > 1 else 1.0)
	if _tw:
		_tw.kill()
	_tw = create_tween()
	panel.position.y = Y0 - 10.0
	_tw.set_parallel(true)
	_tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	_tw.tween_property(panel, "position:y", Y0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.chain().tween_interval(hold)
	_tw.chain().tween_property(panel, "modulate:a", 0.0, 0.3)
	_tw.chain().tween_callback(_next)

func showing_text() -> String:
	return text_l.text if panel.modulate.a > 0.01 else ""

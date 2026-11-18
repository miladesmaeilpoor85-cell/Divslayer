extends Control
## Conversation box: the speaker's framed portrait and name, text that types itself out,
## a page counter and a bouncing "continue" arrow. Tap once to show the whole line, again for the next.
## Pauses the world while open.

signal finished
signal chosen(i: int)           # (v0.9) an answer was picked from the choice list

const Portrait = preload("res://scripts/ui/portrait.gd")

var lines: Array = []
var idx := 0
var speaker := ""
var look := ""                  # villager sheet for the portrait ("elder", "smith", …)
var panel: PanelContainer
var portrait: Control
var name_tab: PanelContainer
var name_l: Label
var text_l: Label
var hint_l: Label               # page counter "2 / 5"
var arrow: Control
var _block_until := 0
var _choice_box: VBoxContainer
var _chars := 0.0
const CPS := 55.0               # characters per second

static func panel_style() -> StyleBoxFlat:
	return UI.box(Color(UI.INK, 0.96), UI.GOLD, 2, 14, 16, 10)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.25)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style())
	panel.anchor_left = 0.06
	panel.anchor_right = 0.94
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -132
	panel.offset_bottom = -12
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	portrait = Portrait.new()
	portrait.square = true
	portrait.custom_minimum_size = Vector2(98, 98)    # (v0.28) 88 -> 98 for the painted portraits; the panel's inner height is ~100
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	text_l = UI.label("", 16, UI.CREAM)
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_l.custom_minimum_size = Vector2(0, 64)
	col.add_child(text_l)
	hint_l = UI.label("", 11, UI.MUTED)
	col.add_child(hint_l)
	# the name sits on a tab across the panel's top edge
	name_tab = PanelContainer.new()
	name_tab.add_theme_stylebox_override("panel", UI.box(Color(0.24, 0.17, 0.09, 1), UI.GOLD, 2, 9, 12, 4))
	name_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_tab)
	name_l = UI.label("", 14, UI.GOLD_HI)
	name_l.add_theme_font_override("font", UI.font_bold)
	name_tab.add_child(name_l)
	arrow = Control.new()
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.size = Vector2(16, 12)
	arrow.draw.connect(_draw_arrow)
	add_child(arrow)

func open(who: String, ls: Array, sheet := "") -> void:
	if ls.is_empty():
		return
	if _choice_box:
		_choice_box.visible = false
	speaker = who
	look = sheet
	lines = ls
	idx = 0
	visible = true
	get_tree().paused = true
	_block_until = Time.get_ticks_msec() + 250
	portrait.visible = sheet != ""
	if sheet != "" and portrait.show_art(sheet):
		pass                                   # (v0.28) a painted portrait
	elif sheet.begins_with("hero:"):
		# (v0.24) Rostam, Siavash, Gordafarid: "hero:<sheet>:<look>"
		var hs: PackedStringArray = sheet.substr(5).split(":")
		portrait.show_sheet("heroes", hs[0], hs[1] if hs.size() > 1 else "")
	elif sheet != "":
		portrait.show_sheet("npcs", sheet)
	# (v0.26, the critic: "his body is a shade, his portrait is alive") Jamshid's face is as pale as he stands in Zabol
	if portrait.face:
		# (v0.28) his painted portrait is a shade already: no tint on it
		portrait.face.modulate = Color(0.78, 0.9, 1.0, 0.72) if sheet == "brann" and portrait.art_facing == 0 else Color.WHITE
	_render()
	Sfx.play("talk")

func _render() -> void:
	var fa := Game.lang == "fa"
	var dir := Control.LAYOUT_DIRECTION_RTL if fa else Control.LAYOUT_DIRECTION_LTR
	panel.layout_direction = dir
	# (v0.28) a painted face turns toward the text: the portrait sits on the right in Persian, on the left in English
	portrait.mirror = portrait.art_facing == (1 if fa else -1)
	portrait.face.queue_redraw()
	text_l.text_direction = Control.TEXT_DIRECTION_RTL if fa else Control.TEXT_DIRECTION_LTR
	# (v0.27, UX: "every Persian line starts at the far left, away from the portrait") inside an RTL panel a Label's
	# LEFT/RIGHT already mean start/end: the line starts next to the portrait, the page count sits at the end
	text_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_l.text = speaker
	text_l.text = str(lines[idx])
	_chars = 0.0
	text_l.visible_characters = 0
	hint_l.text = Game.num("%d / %d" % [idx + 1, lines.size()]) if lines.size() > 1 else ""
	await get_tree().process_frame
	_place_tab()

func _place_tab() -> void:
	name_tab.reset_size()
	var pr := panel.get_rect()
	var x: float = pr.end.x - name_tab.size.x - 24.0 if Game.lang == "fa" else pr.position.x + 24.0
	name_tab.position = Vector2(x, pr.position.y - name_tab.size.y * 0.6)

func _process(dt: float) -> void:
	if not visible:
		return
	var total := text_l.get_total_character_count()
	if _chars < total:
		_chars += dt * CPS
		text_l.visible_characters = int(_chars)
	else:
		text_l.visible_characters = -1
	var pr := panel.get_rect()
	var bob := 2.5 * sin(Time.get_ticks_msec() / 160.0)
	var ax: float = pr.position.x + 20.0 if Game.lang == "fa" else pr.end.x - 36.0
	arrow.position = Vector2(ax, pr.end.y - 22.0 + bob)
	arrow.visible = typing_done()
	arrow.queue_redraw()

func typing_done() -> bool:
	return text_l.visible_characters == -1 or text_l.visible_characters >= text_l.get_total_character_count()

func _draw_arrow() -> void:
	arrow.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(8, 10)]), UI.GOLD_HI)

## the speaker says one line and the hero picks an answer. options: [{label, ok (bool), note}] -> emits chosen(i)
func choose(who: String, text: String, options: Array, sheet := "") -> void:
	open(who, [text], sheet)
	_chars = 99999.0
	text_l.visible_characters = -1
	if _choice_box == null:
		_choice_box = VBoxContainer.new()
		_choice_box.add_theme_constant_override("separation", 5)
		_choice_box.anchor_left = 0.06
		_choice_box.anchor_right = 0.94
		_choice_box.anchor_top = 1.0
		_choice_box.anchor_bottom = 1.0
		_choice_box.offset_bottom = -164        # (v0.27, UX) above the speaker's name tab, not over it
		_choice_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
		add_child(_choice_box)
	for c in _choice_box.get_children():
		c.queue_free()
	_choice_box.layout_direction = Control.LAYOUT_DIRECTION_RTL if Game.lang == "fa" else Control.LAYOUT_DIRECTION_LTR
	for i in options.size():
		var o: Dictionary = options[i]
		var b := Button.new()
		var ok: bool = bool(o.get("ok", true))
		b.text = str(o.get("label", "")) + ("" if ok or str(o.get("note", "")) == "" else "  —  " + str(o["note"]))
		b.disabled = not ok
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_stylebox_override("normal", UI.box(Color(UI.INK, 0.96), UI.GOLD if ok else Color(UI.MUTED, 0.5), 2, 10, 12, 6))
		b.add_theme_stylebox_override("hover", UI.box(Color(0.25, 0.18, 0.1, 0.98), UI.GOLD_HI, 2, 10, 12, 6))
		b.add_theme_stylebox_override("pressed", UI.box(Color(0.35, 0.25, 0.12, 1.0), UI.GOLD_HI, 2, 10, 12, 6))
		b.add_theme_stylebox_override("disabled", UI.box(Color(0.08, 0.06, 0.05, 0.9), Color(UI.MUTED, 0.5), 1, 10, 12, 6))
		b.add_theme_color_override("font_color", UI.CREAM)
		b.add_theme_color_override("font_disabled_color", UI.MUTED)
		b.pressed.connect(_pick.bind(i))
		_choice_box.add_child(b)
	_choice_box.visible = true
	arrow.visible = false

func _pick(i: int) -> void:
	if Time.get_ticks_msec() < _block_until:
		return
	_choice_box.visible = false
	visible = false
	get_tree().paused = false
	Sfx.play("ui")
	chosen.emit(i)

func choosing() -> bool:
	return _choice_box != null and _choice_box.visible

func advance() -> void:
	if choosing():
		return
	if Time.get_ticks_msec() < _block_until:
		return
	_block_until = Time.get_ticks_msec() + 160
	if not typing_done():
		_chars = 99999.0
		text_l.visible_characters = -1
		return
	idx += 1
	if idx >= lines.size():
		visible = false
		get_tree().paused = false
		finished.emit()
		return
	Sfx.play("talk")
	_render()

## tests and scripted scenes: jump straight to the next line
func skip_typing() -> void:
	_chars = 99999.0
	text_l.visible_characters = -1

func _gui_input(ev: InputEvent) -> void:
	if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed):
		advance()
		accept_event()

func _unhandled_input(ev: InputEvent) -> void:
	if visible and (ev.is_action_pressed("attack") or ev.is_action_pressed("interact")):
		advance()
		get_viewport().set_input_as_handled()

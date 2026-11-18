extends Control
## The cinematic name card the first time you meet a story boss (V18.intro): letterbox bars slide in,
## the boss's title and name fade up over a coloured line. The world pauses for 2.8 s; tap to skip.

signal done

var top_bar: ColorRect
var bot_bar: ColorRect
var title_l: Label
var name_l: Label
var line: ColorRect
var skip_l: Label
var on := false
var _tw: Tween
var _paused_by_me := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	top_bar = ColorRect.new()
	top_bar.color = Color.BLACK
	top_bar.anchor_right = 1.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)
	bot_bar = ColorRect.new()
	bot_bar.color = Color.BLACK
	bot_bar.anchor_right = 1.0
	bot_bar.anchor_top = 1.0
	bot_bar.anchor_bottom = 1.0
	bot_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot_bar)
	var box := VBoxContainer.new()
	box.anchor_right = 1.0
	box.anchor_top = 0.6
	box.anchor_bottom = 0.6
	box.offset_bottom = 90
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	title_l = _label(14, Color(0.85, 0.78, 0.66))
	box.add_child(title_l)
	name_l = _label(32, Color(1, 1, 1))
	name_l.add_theme_constant_override("outline_size", 9)
	box.add_child(name_l)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 6)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder)
	line = ColorRect.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	skip_l = _label(11, Color(0.75, 0.75, 0.75, 0.85))
	skip_l.anchor_left = 0.0
	skip_l.anchor_right = 1.0
	skip_l.anchor_top = 0.15
	skip_l.anchor_bottom = 0.15
	skip_l.offset_left = 14
	skip_l.offset_right = -14
	add_child(skip_l)

func _label(fs: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func play(type: String) -> void:
	var c: Dictionary = Game.boss_cfg(type)
	var col: Color = c.get("rgb", Color(1, 0.8, 0.5))
	title_l.text = Game.boss_title(type)
	name_l.text = Game.boss_name(type)
	name_l.add_theme_font_override("font", UI.display_font())
	name_l.add_theme_font_size_override("font_size", 36)
	# (v0.23, playtest) a pale boss (the White Div, Akvan) on a pale arena: the outline stays dark enough to read
	name_l.add_theme_color_override("font_outline_color", Color(col.r * 0.22, col.g * 0.22, col.b * 0.3, 0.98))
	name_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	name_l.add_theme_constant_override("shadow_offset_y", 3)
	name_l.add_theme_constant_override("shadow_outline_size", 12)
	line.color = col
	skip_l.text = Game.t("tap to skip", "برای رد شدن بزن")
	skip_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if Game.lang == "fa" else HORIZONTAL_ALIGNMENT_RIGHT
	var h := get_viewport_rect().size.y * 0.13
	top_bar.offset_bottom = 0
	bot_bar.offset_top = 0
	title_l.modulate.a = 0.0
	name_l.modulate.a = 0.0
	line.custom_minimum_size.x = 0
	visible = true
	on = true
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_me = true
	Sfx.play("roar")
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.set_parallel(true)
	_tw.tween_property(top_bar, "offset_bottom", h, 0.45).set_trans(Tween.TRANS_SINE)
	_tw.tween_property(bot_bar, "offset_top", -h, 0.45).set_trans(Tween.TRANS_SINE)
	_tw.tween_property(title_l, "modulate:a", 1.0, 0.6).set_delay(0.25)
	_tw.tween_property(name_l, "modulate:a", 1.0, 0.6).set_delay(0.35)
	_tw.tween_property(line, "custom_minimum_size:x", min(get_viewport_rect().size.x * 0.6, 420.0), 0.8).set_delay(0.4)
	get_tree().create_timer(2.8, true, false, true).timeout.connect(finish)

func finish() -> void:
	if not on:
		return
	on = false
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.set_parallel(true)
	_tw.tween_property(top_bar, "offset_bottom", 0.0, 0.35)
	_tw.tween_property(bot_bar, "offset_top", 0.0, 0.35)
	_tw.tween_property(title_l, "modulate:a", 0.0, 0.25)
	_tw.tween_property(name_l, "modulate:a", 0.0, 0.25)
	_tw.chain().tween_callback(func(): visible = false)
	if _paused_by_me:
		_paused_by_me = false
		get_tree().paused = false
	done.emit()

func _gui_input(ev: InputEvent) -> void:
	if on and ((ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed)):
		finish()
		accept_event()

func _unhandled_input(ev: InputEvent) -> void:
	if on and (ev.is_action_pressed("attack") or ev.is_action_pressed("interact")):
		finish()
		get_viewport().set_input_as_handled()

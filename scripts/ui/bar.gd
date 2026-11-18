extends Control
## A rounded meter (health, stamina, XP, boss health): smooth fill, a pale "damage trail" that
## catches up a moment later, a top highlight and optional centred text.

var value := 1.0            # 0..1
var fill := UI.HP
var fill_hi := UI.HP_HI
var back := Color(0.06, 0.04, 0.03, 0.9)
var border := Color(0, 0, 0, 0.6)
var trail_col := Color(1, 0.9, 0.7, 0.85)
var text := ""
var text_size := 10
var radius := 4.0
var trail := true
var glow := 0.0             # 0..1: pulse (stagger bar full, low health)
var _shown := 1.0
var _trail := 1.0
var _sb_back: StyleBoxFlat
var _sb_fill: StyleBoxFlat
var _sb_trail: StyleBoxFlat
var _sb_hi: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sb_back = UI.box(back, border, 1, radius, 0)
	_sb_fill = UI.box(fill, Color(0, 0, 0, 0), 0, radius, 0)
	_sb_trail = UI.box(trail_col, Color(0, 0, 0, 0), 0, radius, 0)
	_sb_hi = UI.box(Color(1, 1, 1, 0.16), Color(0, 0, 0, 0), 0, radius, 0)
	_shown = value
	_trail = value

func set_value(v: float, instant := false) -> void:
	value = clamp(v, 0.0, 1.0)
	if instant:
		_shown = value
		_trail = value
	queue_redraw()

func _process(dt: float) -> void:
	var changed := false
	if abs(_shown - value) > 0.0005:
		_shown = move_toward(_shown, value, max(0.02, abs(value - _shown)) * dt * 10.0)
		changed = true
	if _trail > _shown + 0.0005:
		_trail = max(_shown, _trail - dt * 0.45)
		changed = true
	elif _trail < _shown:
		_trail = _shown
		changed = true
	if changed or glow > 0.0:
		queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	_sb_back.bg_color = back
	draw_style_box(_sb_back, r)
	var inner := r.grow(-1.0)
	if trail and _trail > _shown:
		draw_style_box(_sb_trail, Rect2(inner.position, Vector2(inner.size.x * _trail, inner.size.y)))
	if _shown > 0.001:
		var fr := Rect2(inner.position, Vector2(max(inner.size.x * _shown, min(inner.size.y, inner.size.x * _shown * 4.0)), inner.size.y))
		var c := fill
		if glow > 0.0:
			c = fill.lerp(Color(1, 1, 1), glow * (0.25 + 0.25 * sin(Time.get_ticks_msec() / 90.0)))
		_sb_fill.bg_color = c
		draw_style_box(_sb_fill, fr)
		if fr.size.y >= 6.0:
			_sb_hi.bg_color = Color(fill_hi, 0.55)
			draw_style_box(_sb_hi, Rect2(fr.position, Vector2(fr.size.x, fr.size.y * 0.45)))
	if text != "":
		var f: Font = UI.font_bold if UI.font_bold else ThemeDB.fallback_font
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		var pos := Vector2((size.x - tw) * 0.5, (size.y + text_size * 0.72) * 0.5)
		draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, 3, Color(0, 0, 0, 0.85))
		draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1, 0.97, 0.9))

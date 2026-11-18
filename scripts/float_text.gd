extends Node2D
## Damage numbers and short messages: bold, outlined, they pop in, drift up and fade.
## Digits follow the language (Persian digits in Persian).

var _big := false

func setup(text: String, color: Color, big := false) -> void:
	_big = big
	var l := Label.new()
	l.text = Game.num(text)
	l.add_theme_font_override("font", UI.font_bold if UI.font_bold else ThemeDB.fallback_font)
	l.add_theme_font_size_override("font_size", 16 if big else 12)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(200, 24)
	l.position = Vector2(-100, -12)
	add_child(l)
	z_index = 50

func _ready() -> void:
	scale = Vector2.ONE * (1.45 if _big else 1.3)
	position.x += randf_range(-5.0, 5.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y - 28.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.45)
	tw.chain().tween_callback(queue_free)

extends Node2D
## Isolated review scene for the ImageGen warrior walk-cycle candidate.
## Run with: godot --path . res://scenes/dev/warrior_animation_review.tscn

const SHEET_B64_PATH := "res://assets/art/Heroes/review/warrior_starter_walkcycle.webp.b64"
const CELL_SIZE := Vector2(160.0, 156.0)
const WALK_DIRECTIONS := ["down", "up", "side"]
const SLASH_DURATION := 0.34

@onready var actor: AnimatedSprite2D = $Actor

var _walk_animation := "walk_side"
var _attack_lock := 0.0
var _slash_time := 0.0
var _status_label: Label


func _ready() -> void:
	var texture := _load_review_texture()
	if texture == null:
		push_error("Warrior review atlas could not be loaded")
		return
	actor.sprite_frames = _build_frames(texture)
	actor.play(_walk_animation)
	_build_ui()
	queue_redraw()


func _load_review_texture() -> Texture2D:
	if not FileAccess.file_exists(SHEET_B64_PATH):
		push_error("Missing review atlas data: " + SHEET_B64_PATH)
		return null
	var encoded := FileAccess.get_file_as_string(SHEET_B64_PATH).strip_edges()
	var bytes := Marshalls.base64_to_raw(encoded)
	var image := Image.new()
	var error := image.load_webp_from_buffer(bytes)
	if error != OK:
		push_error("Could not decode the WebP review atlas: %s" % error)
		return null
	if image.get_width() != 800 or image.get_height() != 468:
		push_error("Unexpected review atlas size: %dx%d" % [image.get_width(), image.get_height()])
		return null
	return ImageTexture.create_from_image(image)


func _build_frames(texture: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for animation_name in frames.get_animation_names():
		frames.remove_animation(animation_name)
	for row in WALK_DIRECTIONS.size():
		var direction: String = WALK_DIRECTIONS[row]
		var walk_name := "walk_" + direction
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, 9.0)
		frames.set_animation_loop(walk_name, true)
		for column in 4:
			frames.add_frame(walk_name, _atlas_frame(texture, column, row))

		var idle_name := "idle_" + direction
		frames.add_animation(idle_name)
		frames.add_frame(idle_name, _atlas_frame(texture, 0, row))

		var attack_name := "attack_" + direction
		frames.add_animation(attack_name)
		frames.set_animation_speed(attack_name, 8.0)
		frames.set_animation_loop(attack_name, false)
		frames.add_frame(attack_name, _atlas_frame(texture, 4, row))
	return frames


func _atlas_frame(texture: Texture2D, column: int, row: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2(column * CELL_SIZE.x, row * CELL_SIZE.y), CELL_SIZE)
	return atlas


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ReviewUI"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var title := Label.new()
	title.text = "دیوکش | بازبینی انیمیشن جنگجو"
	title.position = Vector2(18, 12)
	title.add_theme_font_size_override("font_size", 22)
	_apply_review_font(title)
	root.add_child(title)

	var help := Label.new()
	help.text = "انتخاب نما: روبه‌رو، پشت یا نیم‌رخ  •  حمله: دکمه یا Space  •  صفحه‌کلید: 1 / 2 / 3"
	help.position = Vector2(18, 44)
	help.add_theme_font_size_override("font_size", 13)
	_apply_review_font(help)
	root.add_child(help)

	_status_label = Label.new()
	_status_label.text = "حالت فعلی: نیم‌رخ / راه‌رفتن"
	_status_label.position = Vector2(18, 72)
	_status_label.add_theme_font_size_override("font_size", 15)
	_apply_review_font(_status_label)
	root.add_child(_status_label)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -328
	panel.offset_right = 328
	panel.offset_top = -62
	panel.offset_bottom = -8
	root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	_add_button(row, "روبه‌رو ↓", _show_walk.bind("down"))
	_add_button(row, "پشت ↑", _show_walk.bind("up"))
	_add_button(row, "نیم‌رخ →", _show_walk.bind("side"))
	_add_button(row, "حمله ⚔", _play_attack)


func _apply_review_font(control: Control) -> void:
	if UI.font_body != null:
		control.add_theme_font_override("font", UI.font_body)


func _add_button(parent: HBoxContainer, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(150, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	_apply_review_font(button)
	button.pressed.connect(callback)
	parent.add_child(button)


func _show_walk(direction: String) -> void:
	if _attack_lock > 0.0:
		return
	if not WALK_DIRECTIONS.has(direction):
		return
	_walk_animation = "walk_" + direction
	actor.flip_h = false
	actor.play(_walk_animation)
	if _status_label != null:
		_status_label.text = "حالت فعلی: %s / راه‌رفتن" % _direction_label(direction)


func _play_attack() -> void:
	actor.flip_h = false
	actor.play("attack_side")
	_attack_lock = SLASH_DURATION
	_slash_time = SLASH_DURATION
	if _status_label != null:
		_status_label.text = "حمله: آماده‌سازی → برخورد → بازیابی"
	queue_redraw()


func _direction_label(direction: String) -> String:
	match direction:
		"down":
			return "روبه‌رو"
		"up":
			return "پشت"
		_:
			return "نیم‌رخ"


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_show_walk("down")
		KEY_2:
			_show_walk("up")
		KEY_3:
			_show_walk("side")
		KEY_SPACE:
			_play_attack()


func _process(delta: float) -> void:
	var needs_redraw := false
	if _attack_lock > 0.0:
		_attack_lock = maxf(0.0, _attack_lock - delta)
		if _attack_lock == 0.0:
			actor.play(_walk_animation)
			if _status_label != null:
				_status_label.text = "حالت فعلی: %s / راه‌رفتن" % _direction_label(_walk_animation.trim_prefix("walk_"))
	if _slash_time > 0.0:
		_slash_time = maxf(0.0, _slash_time - delta)
		needs_redraw = true
	if needs_redraw:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(854, 400)), Color("#151a25"))
	draw_rect(Rect2(0, 308, 854, 92), Color("#27232a"))
	draw_line(Vector2(0, 308), Vector2(854, 308), Color("#96784e"), 2.0)
	for x in range(28, 854, 92):
		draw_line(Vector2(x, 308), Vector2(x + 30, 286), Color(0.45, 0.36, 0.27, 0.42), 2.0)
	if _slash_time > 0.0:
		var progress := 1.0 - _slash_time / SLASH_DURATION
		var alpha := clampf(sin(progress * PI), 0.0, 1.0)
		var start_angle := -1.35 + progress * 0.55
		var end_angle := start_angle + 1.1 + progress * 0.28
		draw_arc(Vector2(506, 225), 70.0, start_angle, end_angle, 28,
			Color(0.45, 0.82, 1.0, alpha), 7.0, true)
		draw_arc(Vector2(506, 225), 58.0, start_angle + 0.12, end_angle - 0.12, 22,
			Color(0.95, 0.81, 0.54, alpha * 0.72), 2.5, true)
		if progress > 0.42 and progress < 0.72:
			var impact := Vector2(560, 198)
			for ray in 7:
				var angle := TAU * float(ray) / 7.0
				draw_line(impact, impact + Vector2.from_angle(angle) * 18.0,
					Color(1.0, 0.89, 0.62, alpha), 2.2)

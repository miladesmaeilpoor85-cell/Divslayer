extends Control
## "You have fallen" overlay. During a boss fight it offers a Rematch right at the arena
## (gold refunded, potions back — V18 retry); otherwise, or by choice, respawn in Zabol.

signal rematch
signal respawn

var title_l: Label
var text_l: Label
var re_btn: Button
var home_btn: Button
var story_btn: Button          # (v0.24, playtest: "a player who keeps losing never learns there is a Story difficulty")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.09, 0.045, 0.035, 0.97), Color(0.78, 0.32, 0.24), 2, 14, 20, 12))
	panel.anchor_left = 0.18
	panel.anchor_right = 0.82
	panel.anchor_top = 0.18
	panel.anchor_bottom = 0.18
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var sk := UI.icon_rect("skull", 34, Color(0.95, 0.45, 0.38))
	sk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(sk)
	title_l = UI.label("", 26, Color(1, 0.55, 0.45), 0)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title_l)
	text_l = UI.label("", 14, UI.CREAM)
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_l.custom_minimum_size = Vector2(400, 0)
	v.add_child(text_l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	re_btn = UI.button("", "swords", true, 48)
	re_btn.pressed.connect(_on_rematch)
	row.add_child(re_btn)
	home_btn = UI.button("", "house", false, 48)
	home_btn.pressed.connect(_on_respawn)
	row.add_child(home_btn)
	story_btn = UI.button("", "feather", false, 40)
	story_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	story_btn.pressed.connect(_on_story)
	v.add_child(story_btn)

func open(lost: int, boss_type: String) -> void:
	title_l.text = Game.t("You have fallen", "از پا افتادی")
	title_l.add_theme_font_override("font", UI.display_font())
	home_btn.text = "  " + Game.t("Respawn in Zabol", "زنده شدن در زابل") + "  "
	if boss_type != "":
		re_btn.visible = true
		# a second fall to the same boss: the gentler way is offered, and the fight goes on at once
		story_btn.visible = int(Game.fight.get("retries", 0)) >= 1 and Game.diff() != "story"
		story_btn.text = "  " + Game.t("Story difficulty — then fight again", "سختی را «داستانی» کن و دوباره بجنگ") + "  "
		re_btn.text = "  " + Game.t("Rematch — %s" % Game.boss_name(boss_type), "نبردِ دوباره با %s" % Game.boss_name(boss_type)) + "  "
		text_l.text = Game.t("Fight again right here — no gold lost, your potions come back. Or respawn in Zabol and lose %d gold." % lost,
			"همین‌جا دوباره بجنگ — سکه‌ای از دست نمی‌دهی و معجون‌هایت برمی‌گردند. یا در زابل زنده شو و %s سکه از دست بده." % Game.num(lost))
	else:
		re_btn.visible = false
		story_btn.visible = false
		text_l.text = Game.t("You lost %d gold." % lost, "%s سکه از دست دادی." % Game.num(lost))
	text_l.text_direction = Control.TEXT_DIRECTION_RTL if Game.lang == "fa" else Control.TEXT_DIRECTION_LTR
	visible = true
	get_tree().paused = true

func _on_rematch() -> void:
	_close()
	rematch.emit()

func _on_story() -> void:
	Game.set_setting("diff", "story")
	_close()
	rematch.emit()

func _on_respawn() -> void:
	_close()
	respawn.emit()

func _close() -> void:
	visible = false
	get_tree().paused = false

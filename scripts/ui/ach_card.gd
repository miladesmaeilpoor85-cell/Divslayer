extends Control
## (v0.20) The card an achievement brings: slides in from the left under the quest tracker (clear of the touch buttons,
## the hero in the middle and the messages at the top), with a medal, its name, what it was for and the look it earned,
## if any. Several at once wait their turn.

const Ach = preload("res://scripts/achievements.gd")
const Looks = preload("res://scripts/looks.gd")

var queue: Array = []
var panel: PanelContainer
var medal: Control
var cap_l: Label
var name_l: Label
var desc_l: Label
var look_l: Label
var _busy := false
var _icon := "trophy"
var _t := 0.0
var shown := 0                 # cards shown so far (tests)
var anchor: Control = null     # the quest tracker: the card sits under it

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.94), UI.GOLD_HI, 2, 16, 14, 8))
	panel.modulate.a = 0.0
	add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	medal = Control.new()
	medal.custom_minimum_size = Vector2(46, 46)
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medal.draw.connect(_draw_medal)
	h.add_child(medal)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	cap_l = UI.label("", 11, UI.GOLD)
	v.add_child(cap_l)
	name_l = UI.label("", 16, UI.GOLD_HI)
	name_l.add_theme_font_override("font", UI.font_bold)
	v.add_child(name_l)
	desc_l = UI.label("", 11, UI.MUTED)
	v.add_child(desc_l)
	look_l = UI.label("", 11, UI.CREAM)
	v.add_child(look_l)
	Game.achieved.connect(push)

func push(id: String) -> void:
	queue.append(id)
	if not _busy:
		_next()

func _process(dt: float) -> void:
	_t += dt
	if panel.modulate.a > 0.0:
		medal.queue_redraw()

func _next() -> void:
	if queue.is_empty() or not is_inside_tree():
		_busy = false
		return
	_busy = true
	# (v0.23, playtest: cards over the target box in the middle of a boss fight) a card waits for the fight to end
	var waited := 0.0
	while (not Game.fight.is_empty() or Time.get_ticks_msec() - Game.victory_at < 3200) and Game.rush.is_empty() \
			and waited < 90.0 and is_inside_tree():
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if not is_inside_tree():
		_busy = false
		return
	var id: String = queue.pop_front()
	shown += 1
	_icon = Ach.icon(id)
	var fa := Game.lang == "fa"
	panel.layout_direction = Control.LAYOUT_DIRECTION_RTL if fa else Control.LAYOUT_DIRECTION_LTR
	cap_l.text = Game.t("Achievement unlocked", "دستاورد به دست آمد")
	name_l.text = Ach.title(id)
	desc_l.text = Ach.desc(id)
	var looks := Looks.earned_by(id)
	look_l.visible = not looks.is_empty()
	if not looks.is_empty():
		look_l.text = Game.t("New look: ", "ظاهرِ تازه: ") + Looks.title(looks[0]) + Game.t("  (Menu → Hero → Looks)", "  (فهرست ← قهرمان ← ظاهرها)")
		var c: Color = Looks.colors(looks[0])[2]
		look_l.add_theme_color_override("font_color", c.lightened(0.25))
	for l in [cap_l, name_l, desc_l, look_l]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if fa else HORIZONTAL_ALIGNMENT_LEFT
	Sfx.play("achieve")
	Game.vibrate(40, 0.6)
	panel.size = Vector2.ZERO
	panel.reset_size()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	panel.reset_size()
	var w: float = panel.size.x
	var y1 := 96.0
	if anchor and anchor.visible:
		y1 = anchor.position.y + anchor.size.y * anchor.scale.y + 8.0
	panel.position = Vector2(-w, y1)
	_t = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(panel, "position:x", 10.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(3.2 if queue.is_empty() else 2.2)
	tw.chain().tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(_next)

## a gold medal with the achievement's icon, a ring of light running round it
func _draw_medal() -> void:
	var c := medal.size * 0.5
	var k := clampf(_t / 0.5, 0.0, 1.0)
	medal.draw_circle(c, 22.0, Color(0, 0, 0, 0.5))
	medal.draw_circle(c, 20.0, Color(0.42, 0.3, 0.12))
	medal.draw_circle(c, 17.0, Color(0.62, 0.45, 0.16))
	medal.draw_arc(c, 20.0, 0, TAU, 40, UI.GOLD_HI, 2.0, true)
	var a0 := _t * 3.0
	medal.draw_arc(c, 23.5, a0, a0 + PI * 0.6 * k, 20, Color(1, 0.95, 0.7, 0.9), 2.0, true)
	var tex := UI.icon(_icon, 48)
	if tex:
		medal.draw_texture_rect(tex, Rect2(c - Vector2(12, 12), Vector2(24, 24)), false, Color(1, 0.96, 0.85))

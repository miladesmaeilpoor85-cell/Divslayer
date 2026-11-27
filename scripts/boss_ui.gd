extends Control
## Boss HUD (v18): a framed bar at the top centre (skull, name, health with a damage trail, the
## stagger meter that glows when full, phase pips, the King's armour state) and the big banners
## ("Phase II", "VANQUISHED", "Again!"). Hints go to the HUD's message queue. Never takes input.

const Bar = preload("res://scripts/ui/bar.gd")
const W := 320.0

var boss: Node = null
var bar: PanelContainer
var name_l: Label
var hp: Control
var stag: Control
var pips: Control
var banner_box: VBoxContainer
var banner_a: Label
var banner_b: Label
var banner_orn: Control
var banner_tw: Tween
var _col := UI.GOLD

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	bar = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.86), Color(UI.GOLD, 0.8), 2, 10, 10, 6))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.offset_left = -W * 0.5
	bar.offset_right = W * 0.5
	bar.offset_top = 6
	bar.visible = false
	add_child(bar)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(v)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	top.add_child(UI.icon_rect("skull", 14, UI.GOLD))
	name_l = UI.label("", 13, UI.GOLD_HI, 3)
	top.add_child(name_l)
	hp = Bar.new()
	hp.custom_minimum_size = Vector2(0, 12)
	hp.radius = 4.0
	v.add_child(hp)
	var low := HBoxContainer.new()
	low.add_theme_constant_override("separation", 8)
	low.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(low)
	stag = Bar.new()
	stag.custom_minimum_size = Vector2(0, 5)
	stag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stag.fill = Color(1, 0.8, 0.38)
	stag.fill_hi = Color(1, 0.95, 0.7)
	stag.trail = false
	stag.radius = 2.0
	low.add_child(stag)
	pips = Control.new()
	pips.custom_minimum_size = Vector2(42, 10)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(_draw_pips)
	low.add_child(pips)

	banner_box = VBoxContainer.new()
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.anchor_left = 0.0
	banner_box.anchor_right = 1.0
	banner_box.anchor_top = 0.23
	banner_box.anchor_bottom = 0.23
	banner_box.offset_bottom = 70
	banner_box.add_theme_constant_override("separation", 2)
	banner_box.modulate.a = 0.0
	add_child(banner_box)
	banner_a = UI.label("", 28, Color(1, 0.97, 0.9), 8)
	banner_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(banner_a)
	banner_orn = Control.new()
	banner_orn.custom_minimum_size = Vector2(0, 10)
	banner_orn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_orn.draw.connect(_draw_orn)
	banner_box.add_child(banner_orn)
	banner_b = UI.label("", 14, Color(0.93, 0.87, 0.74), 4)
	banner_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(banner_b)

func showing() -> bool:
	return bar.visible

## a banner is on screen (or about to be)
func banner_showing() -> bool:
	return banner_box.modulate.a > 0.02 or (banner_tw != null and banner_tw.is_valid() and banner_tw.is_running())

func track(b: Node) -> void:
	boss = b
	var c: Color = b.rgb
	hp.fill = Color(c.r * 0.5 + 0.42, c.g * 0.38 + 0.12, c.b * 0.32 + 0.1)
	hp.fill_hi = hp.fill.lightened(0.35)
	hp.set_value(clamp(b.hp / b.max_hp, 0.0, 1.0), true)
	name_l.add_theme_font_override("font", UI.display_font())
	bar.visible = true

## (v0.26, the critic: "«سطح ۱۵!» shows through the victory message") a banner is never under a tall toast: it sits just
## below whatever the message bar is showing
func _banner_clear() -> void:
	var hud := get_parent().get_parent()
	var dy := 0.0
	if hud and hud.get("notify") != null and hud.notify.panel.modulate.a > 0.05:
		var bottom: float = (get_global_transform().affine_inverse() * hud.notify.panel.get_global_rect().end).y
		dy = max(0.0, bottom + 6.0 - size.y * 0.23)
	if not is_equal_approx(banner_box.offset_top, dy):
		banner_box.offset_top = dy
		banner_box.offset_bottom = 70.0 + dy

func _process(_dt: float) -> void:
	_banner_clear()
	if boss == null or not is_instance_valid(boss) or boss.dead:
		if bar.visible:
			bar.visible = false
		boss = null
		return
	hp.set_value(clamp(boss.hp / boss.max_hp, 0.0, 1.0))
	var full: bool = boss.staggered > 0.0
	stag.set_value(1.0 if full else boss.stag / 100.0)
	stag.glow = 1.0 if full else 0.0
	pips.queue_redraw()
	var nm := Game.boss_name(boss.type)
	if boss.type == "boss2" and boss.heat >= 0.0:
		if boss.vent > 0.0:
			nm += Game.t("  · core exposed", "، هستهٔ باز")
		elif boss.armor:
			nm += Game.t("  · magma armour", "، زرهِ مذاب")
	# (v0.23, playtest: "Shielded" and nobody knew why) the shield and what breaks it, on the bar itself
	if int(boss.get("shield")) > 0:
		nm += Game.t("  · shielded: break the pillars (%d)" % int(boss.shield), "، سپر دارد: ستون‌ها را بشکن (%s)" % Game.num(int(boss.shield)))
	elif boss.type == "boss" and full:
		nm += Game.t("  · Strike now", "، اکنون ضربه بزن")
	elif boss.type == "zahhak" and boss.has_method("zh_chains") and boss.zh_chains() > 0:
		nm += Game.t("  · chains %d" % boss.zh_chains(), "، زنجیرها %s" % Game.num(boss.zh_chains()))
	if not Game.rush.is_empty():
		# (v0.21) the Boss Rush: which memory, and the clock
		nm += Game.sep() + "%s/%s" % [Game.num(int(Game.rush.get("i", 0)) + 1), Game.num(Game.Rush.ORDER.size())] + Game.sep() + Game.Rush.clock(float(Game.rush.get("elapsed", 0.0)))
	if name_l.text != nm:
		name_l.text = nm

func _draw_pips() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var n: int = boss.cfg.get("phases", []).size() + 1 if boss.cfg.has("phases") else 0
	for i in n:
		var c := Vector2(6 + i * 14, 5)
		var pts := PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)])
		pips.draw_colored_polygon(pts, UI.GOLD_HI if i < boss.ph else Color(1, 1, 1, 0.15))
		var outline := pts.duplicate()
		outline.append(pts[0])
		pips.draw_polyline(outline, Color(UI.GOLD, 0.8), 1.0, true)

func _draw_orn() -> void:
	var w := banner_orn.size.x
	var mid := Vector2(w * 0.5, 5)
	for i in 12:
		var a := 1.0 - float(i) / 12.0
		var x0 := 150.0 * float(i) / 12.0
		var x1 := 150.0 * float(i + 1) / 12.0
		banner_orn.draw_line(mid + Vector2(8 + x0, 0), mid + Vector2(8 + x1, 0), Color(_col, a), 2.0)
		banner_orn.draw_line(mid - Vector2(8 + x0, 0), mid - Vector2(8 + x1, 0), Color(_col, a), 2.0)
	banner_orn.draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -5), mid + Vector2(5, 0), mid + Vector2(0, 5), mid + Vector2(-5, 0)]), _col.lightened(0.3))

func banner(a: String, b: String, col: Color, sec := 1.8) -> void:
	_col = col
	banner_a.text = a
	banner_b.text = b
	banner_a.add_theme_font_override("font", UI.display_font())
	banner_a.add_theme_color_override("font_outline_color", Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.95))
	banner_orn.queue_redraw()
	if banner_tw:
		banner_tw.kill()
	banner_box.scale = Vector2(1.08, 1.08)
	banner_box.pivot_offset = Vector2(banner_box.size.x * 0.5, 30)
	banner_tw = create_tween()
	banner_tw.set_parallel(true)
	banner_tw.tween_property(banner_box, "modulate:a", 1.0, 0.25)
	banner_tw.tween_property(banner_box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tw.chain().tween_interval(sec)
	banner_tw.chain().tween_property(banner_box, "modulate:a", 0.0, 0.4)

## hints go through the HUD's message queue
func tip(text: String) -> void:
	var hud := get_parent().get_parent()
	if hud and hud.has_method("hint"):
		hud.hint(text)

## a new map: last map's banners go
func clear_msgs() -> void:
	if banner_tw:
		banner_tw.kill()
	banner_box.modulate.a = 0.0

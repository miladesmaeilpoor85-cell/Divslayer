extends CanvasLayer
## The in-game HUD: hero portrait with level badge, health / stamina / XP bars, gold and potion chips,
## status icons, the quest tracker, the menu button, the map title, on-screen messages, a low-health
## vignette, screen fades, and the touch controls, dialogue, shop, death, pause and boss layers.

const TouchPad = preload("res://scripts/touch_pad.gd")
const Dialogue = preload("res://scripts/dialogue.gd")
const Shop = preload("res://scripts/shop.gd")
const Craft = preload("res://scripts/craft.gd")
const Forge = preload("res://scripts/forge.gd")
const BossUi = preload("res://scripts/boss_ui.gd")
const BossIntro = preload("res://scripts/boss_intro.gd")
const DeathPanel = preload("res://scripts/death_panel.gd")
const Ending = preload("res://scripts/ui/ending.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const Bar = preload("res://scripts/ui/bar.gd")
const Portrait = preload("res://scripts/ui/portrait.gd")
const Notify = preload("res://scripts/ui/notify.gd")
const Minimap = preload("res://scripts/ui/minimap.gd")
const AchCard = preload("res://scripts/ui/ach_card.gd")

signal quit_to_title

var player: Node = null
var root: Control
var portrait: Control
var badge: Control
var name_l: Label
var hp_bar: Control
var st_bar: Control
var mp_bar: Control
var xp_bar: Control
var menu_dot: Control            # a gold dot on the menu button while talent points wait
var gold_chip: HBoxContainer
var pot_chip: HBoxContainer
var status_row: HBoxContainer
var quest: PanelContainer
var quest_l: Label
var objective_l: Label          # kept for older callers: the quest text
var menu_btn: Button
var minimap: Control
var sky: HBoxContainer           # time of day + weather, under the minimap
var _sky_key := ""
var title: Control
var title_l: Label
var title_tw: Tween
var notify: Control
var ach_card: Control          # (v0.20) the achievement cards
var vignette: TextureRect
var fade: ColorRect
var pad: Control
var dialogue: Control
var shop: Control
var craft: Control
var forge: Control
var boss_ui: Control
var intro: Control
var death: Control
var ending: Control           # (v0.19) the end of chapter 2
var pause: Control
var _level := -1
var _sheet := ""

const CLASS_FA := {"warrior": "جنگجو", "mage": "فرزانه", "rogue": "شبگرد", "paladin": "سوگندوَر"}
const STATUS_ICON := {"poison": ["droplets", Color(0.45, 0.85, 0.4)], "burn": ["flame", Color(1, 0.55, 0.3)], "freeze": ["snowflake", Color(0.55, 0.88, 1)],
	"roar": ["crown", Color(1, 0.55, 0.35)]}
const MANA := Color(0.36, 0.56, 1.0)
const Skills = preload("res://scripts/skills.gd")

func build(p: Node) -> void:
	player = p
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "HudRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	vignette = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.6, 0, 0, 0))
	g.set_color(1, Color(0.6, 0, 0, 0.75))
	g.add_point(0.55, Color(0.6, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 128
	gt.height = 64
	vignette.texture = gt
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	root.add_child(vignette)

	_build_status_block()
	_build_quest()
	_build_title()

	menu_btn = Button.new()
	menu_btn.icon = UI.icon("menu", 60)
	menu_btn.add_theme_constant_override("icon_max_width", 22)
	menu_btn.focus_mode = Control.FOCUS_NONE
	menu_btn.add_theme_stylebox_override("normal", UI.box(Color(UI.INK, 0.72), Color(UI.GOLD, 0.7), 2, 22, 8))
	menu_btn.add_theme_stylebox_override("hover", UI.box(Color(UI.INK2, 0.9), UI.GOLD, 2, 22, 8))
	menu_btn.add_theme_stylebox_override("pressed", UI.box(Color(UI.INK, 1), UI.GOLD_HI, 2, 22, 8))
	menu_btn.anchor_left = 1.0
	menu_btn.anchor_right = 1.0
	menu_btn.offset_left = -54
	menu_btn.offset_right = -10
	menu_btn.offset_top = 10
	menu_btn.offset_bottom = 54
	menu_btn.pressed.connect(open_pause)
	root.add_child(menu_btn)
	menu_dot = Control.new()
	menu_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_dot.position = Vector2(30, -4)
	menu_dot.size = Vector2(16, 16)
	menu_dot.draw.connect(func():
		var k := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 180.0)
		menu_dot.draw_circle(Vector2(8, 8), 7.5, Color(0, 0, 0, 0.6))
		menu_dot.draw_circle(Vector2(8, 8), 6.0, Color(UI.GOLD_HI, k))
		menu_dot.draw_circle(Vector2(8, 8), 2.5, Color(1, 1, 1, k)))
	menu_btn.add_child(menu_dot)
	Game.ult_ready.connect(_on_ult_ready)

	minimap = Minimap.new()
	minimap.player = p
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -150
	minimap.offset_right = -10
	minimap.offset_top = 62
	minimap.offset_bottom = 156
	minimap.opened.connect(func(): open_pause("map"))
	root.add_child(minimap)
	sky = HBoxContainer.new()
	sky.anchor_left = 1.0
	sky.anchor_right = 1.0
	sky.offset_left = -150
	sky.offset_right = -10
	sky.offset_top = 158
	sky.offset_bottom = 176
	sky.alignment = BoxContainer.ALIGNMENT_END
	sky.add_theme_constant_override("separation", 5)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sky)

	boss_ui = BossUi.new()
	root.add_child(boss_ui)
	notify = Notify.new()
	root.add_child(notify)
	ach_card = AchCard.new()
	ach_card.anchor = quest
	root.add_child(ach_card)
	pad = TouchPad.new()
	pad.player = p
	root.add_child(pad)
	dialogue = Dialogue.new()
	root.add_child(dialogue)
	shop = Shop.new()
	root.add_child(shop)
	craft = Craft.new()
	root.add_child(craft)
	forge = Forge.new()
	root.add_child(forge)
	death = DeathPanel.new()
	root.add_child(death)
	ending = Ending.new()
	root.add_child(ending)
	pause = PauseMenu.new()
	pause.hud = self
	root.add_child(pause)
	pause.quit_requested.connect(func(): quit_to_title.emit())

	var cine := CanvasLayer.new()
	cine.layer = 20
	cine.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cine)
	intro = BossIntro.new()
	cine.add_child(intro)
	intro.visibility_changed.connect(func(): root.modulate.a = 0.0 if intro.visible else 1.0)
	fade = ColorRect.new()
	fade.color = Color(0.03, 0.02, 0.015, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.modulate.a = 0.0
	cine.add_child(fade)

	Game.stats_changed.connect(refresh)
	Game.lang_changed.connect(_on_lang)
	Game.settings_changed.connect(apply_layout)
	get_viewport().size_changed.connect(apply_layout)
	apply_layout()
	refresh()

# ---------------------------------------------------------------- layout: UI size and the phone's safe area
func apply_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s: float = Game.ui_scale()
	var inset := Rect2(Vector2.ZERO, vp)
	if OS.has_feature("mobile"):
		var ws := Vector2(DisplayServer.window_get_size())
		var sa := DisplayServer.get_display_safe_area()
		if ws.x > 0 and sa.size.x > 0:
			var k := vp / ws
			inset = Rect2(Vector2(sa.position) * k, Vector2(sa.size) * k)
			inset = inset.intersection(Rect2(Vector2.ZERO, vp))
	root.position = inset.position
	root.scale = Vector2(s, s)
	root.size = inset.size / s
	# (v0.27, UX: "with the Large interface the Ultimate overlaps the minimap and the day label sits inside it") the pad's
	# top ring stands 209 above the foot of the screen: the minimap and its day line end above it
	if minimap and sky:
		var room: float = root.size.y - 209.0 - 8.0
		var foot: float = clamp(room - 18.0, 112.0, 156.0)
		minimap.offset_bottom = foot
		sky.offset_top = foot + 2.0
		sky.offset_bottom = foot + 20.0

# ---------------------------------------------------------------- the hero block (top left)
func _build_status_block() -> void:
	var back := Panel.new()
	back.add_theme_stylebox_override("panel", UI.box(Color(0.04, 0.03, 0.02, 0.42), Color(0, 0, 0, 0), 0, 16, 0))
	back.position = Vector2(4, 4)
	back.size = Vector2(262, 78)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)
	portrait = Portrait.new()
	portrait.position = Vector2(10, 10)
	portrait.size = Vector2(54, 54)
	root.add_child(portrait)
	badge = Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size = Vector2(22, 22)
	badge.position = Vector2(46, 46)
	badge.draw.connect(_draw_badge)
	root.add_child(badge)
	name_l = UI.label("", 13, UI.GOLD_HI, 4)
	name_l.add_theme_font_override("font", UI.font_bold)
	name_l.position = Vector2(72, 7)
	name_l.size = Vector2(190, 16)
	root.add_child(name_l)
	hp_bar = Bar.new()
	hp_bar.name = "HealthMeter"
	hp_bar.position = Vector2(72, 25)
	hp_bar.size = Vector2(180, 15)
	hp_bar.radius = 5.0
	hp_bar.text_size = 12
	root.add_child(hp_bar)
	mp_bar = Bar.new()
	mp_bar.name = "ManaMeter"
	mp_bar.position = Vector2(72, 43)
	mp_bar.size = Vector2(180, 8)
	mp_bar.fill = MANA
	mp_bar.fill_hi = Color(0.62, 0.78, 1)
	mp_bar.trail = false
	mp_bar.radius = 3.0
	root.add_child(mp_bar)
	st_bar = Bar.new()
	st_bar.name = "StaminaMeter"
	st_bar.position = Vector2(72, 54)
	st_bar.size = Vector2(180, 5)
	st_bar.fill = UI.STAM
	st_bar.fill_hi = Color(0.7, 1, 0.75)
	st_bar.trail = false
	st_bar.radius = 2.5
	root.add_child(st_bar)
	xp_bar = Bar.new()
	xp_bar.position = Vector2(72, 61)
	xp_bar.size = Vector2(180, 3)
	xp_bar.fill = UI.XP
	xp_bar.fill_hi = Color(0.75, 0.92, 1)
	xp_bar.trail = false
	xp_bar.radius = 2.0
	root.add_child(xp_bar)
	var chips := HBoxContainer.new()
	chips.position = Vector2(72, 65)
	chips.add_theme_constant_override("separation", 12)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chips)
	gold_chip = UI.chip("coins", UI.GOLD_HI)
	chips.add_child(gold_chip)
	pot_chip = UI.chip("flask-conical", Color(1, 0.45, 0.55))
	pot_chip.name = "PotionChip"
	chips.add_child(pot_chip)
	status_row = HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_child(status_row)

func _draw_badge() -> void:
	var c := badge.size * 0.5
	badge.draw_circle(c + Vector2(0, 1), 11.0, Color(0, 0, 0, 0.5))
	badge.draw_circle(c, 10.5, UI.GOLD)
	badge.draw_circle(c, 8.5, Color(0.2, 0.13, 0.07))
	var f: Font = UI.font_bold
	var t := Game.num(Game.lvl())
	var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	badge.draw_string(f, c + Vector2(-tw * 0.5, 4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.GOLD_HI)

func _build_quest() -> void:
	quest = PanelContainer.new()
	quest.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.7), Color(UI.GOLD, 0.35), 1, 8, 8))
	quest.position = Vector2(10, 88)
	quest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(quest)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest.add_child(h)
	h.add_child(UI.icon_rect("scroll-text", 14, UI.GOLD))
	quest_l = UI.label("", 12, UI.CREAM)
	quest_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_l.custom_minimum_size = Vector2(230, 0)
	quest_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if Game.lang == "fa" else HORIZONTAL_ALIGNMENT_LEFT
	h.add_child(quest_l)
	objective_l = quest_l

func _build_title() -> void:
	title = Control.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	# the map's name fades in at the top centre (between the hero block and the minimap), clear of the hero
	title.anchor_top = 0.0
	title.anchor_bottom = 0.0
	title.offset_top = 6
	title.offset_bottom = 58
	title.modulate.a = 0.0
	root.add_child(title)
	# (v0.24, playtest: "the region's name lies on Zal's head") a soft dark band behind the name: it reads as a sign
	# over the scene, not as something in it
	var back := Control.new()
	back.name = "TitleBack"
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	back.offset_bottom = 52
	back.draw.connect(func(): _draw_title_back(back))
	title.add_child(back)
	title_l = UI.label("", 24, UI.GOLD_HI, 6)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_l.offset_bottom = 40
	title.add_child(title_l)
	var orn := Control.new()
	orn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orn.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	orn.offset_top = 42
	orn.offset_bottom = 52
	orn.draw.connect(func(): _draw_ornament(orn))
	title.add_child(orn)

func _draw_title_back(c: Control) -> void:
	var w: float = float(c.get_meta("w", 200.0)) + 120.0
	var cx := c.size.x * 0.5
	var ink := Color(0.04, 0.03, 0.02)
	var steps := 14
	for i in steps:
		# a band that fades out towards both ends
		var x0: float = cx - w * 0.5 + w * float(i) / steps
		var k: float = 1.0 - abs((float(i) + 0.5) / steps * 2.0 - 1.0)
		c.draw_rect(Rect2(x0, 2, w / steps + 1.0, 48), Color(ink, 0.55 * pow(k, 0.6)))

## a gold rule with a diamond in the middle, fading out at both ends
func _draw_ornament(c: Control) -> void:
	var w := c.size.x
	var mid := Vector2(w * 0.5, 5)
	var half := 100.0
	for i in 12:
		var a := 1.0 - float(i) / 12.0
		var x0 := half * float(i) / 12.0
		var x1 := half * float(i + 1) / 12.0
		c.draw_line(mid + Vector2(10 + x0, 0), mid + Vector2(10 + x1, 0), Color(UI.GOLD, a), 1.5)
		c.draw_line(mid - Vector2(10 + x0, 0), mid - Vector2(10 + x1, 0), Color(UI.GOLD, a), 1.5)
	c.draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -5), mid + Vector2(5, 0), mid + Vector2(0, 5), mid + Vector2(-5, 0)]), UI.GOLD_HI)

# ---------------------------------------------------------------- updates
func _on_lang() -> void:
	if quest_l:
		quest_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if Game.lang == "fa" else HORIZONTAL_ALIGNMENT_LEFT
	refresh()
	if pad:
		pad.queue_redraw()
	if badge:
		badge.queue_redraw()        # (v0.23, playtest) the level in Persian or Latin digits

func refresh() -> void:
	if hp_bar == null:
		return
	var mx: float = Game.max_hp()
	hp_bar.set_value(Game.hp / mx)
	hp_bar.text = Game.num("%d / %d" % [int(ceil(max(Game.hp, 0.0))), int(mx)])
	hp_bar.queue_redraw()
	var xn: float = max(1.0, float(Game.state.get("xp_next", 40)))
	xp_bar.set_value(float(Game.state.get("xp", 0)) / xn)
	var cname: String = Game.hero_role()          # (v0.24) the Ember-bearer's calling
	name_l.text = cname
	if Game.ng() > 0:
		name_l.text += Game.t("  · NG+%d" % Game.ng(), "، نو+%s" % Game.num(Game.ng()))     # (v0.21) New Game+
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	gold_chip.get_node("Value").text = Game.num(int(Game.state.get("gold", 0)))
	pot_chip.get_node("Value").text = Game.num(int(Game.state.get("potions", 0)))
	quest_l.text = Game.objective()
	quest_l.text_direction = Control.TEXT_DIRECTION_RTL if Game.lang == "fa" else Control.TEXT_DIRECTION_LTR
	quest.reset_size()
	if player and player.sheet != _sheet:
		_sheet = player.sheet
		portrait.show_sheet("heroes", _sheet)
	if _level != Game.lvl():
		_level = Game.lvl()
		badge.queue_redraw()
	menu_dot.visible = Game.talent_points() > 0 or not Game.Ach.unseen().is_empty()
	if pad:
		pad.queue_redraw()

var _status_key := ""

func _process(_dt: float) -> void:
	if player == null or st_bar == null:
		return
	if _pending_level >= 0 and not boss_ui.banner_showing():
		_show_level_up()
	st_bar.set_value(player.stamina / Game.max_stamina())
	mp_bar.set_value(Game.mp / max(1.0, Game.max_mp()))
	if menu_dot.visible:
		menu_dot.queue_redraw()
	st_bar.back = Color(0.25, 0.06, 0.04, 0.9) if player.stamina < 30.0 else Color(0.06, 0.04, 0.03, 0.9)
	# status icons with seconds left
	var key := ""
	var shown := {}
	for k in player.statuses:
		shown[k] = float(player.statuses[k]["t"])
	if player.caster and player.caster.roar_t > 0.0:
		shown["roar"] = player.caster.roar_t
	for k in shown:
		key += "%s%d," % [k, int(ceil(shown[k]))]
	if key != _status_key:
		_status_key = key
		for c in status_row.get_children():
			c.queue_free()
		for k in shown:
			var info: Array = STATUS_ICON.get(k, ["info", UI.CREAM])
			var ch := UI.chip(info[0], info[1])
			ch.get_node("Value").text = Game.num(int(ceil(shown[k])))
			status_row.add_child(ch)
	# danger vignette below 30% health
	var f: float = Game.hp / max(1.0, Game.max_hp())
	var want: float = 0.0
	if f < 0.3 and not player.dead:
		want = (0.3 - f) / 0.3 * 0.75 + 0.25 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0))
	vignette.modulate.a = move_toward(vignette.modulate.a, want, _dt * 2.0)
	# a heartbeat below 30% health, quicker below 15%
	if want > 0.0 and not get_tree().paused:
		_heart_t -= _dt
		if _heart_t <= 0.0:
			_heart_t = 0.7 if f < 0.15 else 0.95
			Sfx.play("heart", -3.0, 0.0)
	else:
		_heart_t = 0.0
	hp_bar.glow = 1.0 if f < 0.3 else 0.0
	quest.visible = not boss_ui.showing() and quest_l.text != ""
	_update_sky()

## time of day (sun, sunset, moon) and the weather under the minimap
func _update_sky() -> void:
	var w = player.world if player else null
	if w == null:
		return
	var ph: int = Game.phase()
	var wt: String = w.atmos.weather if w.atmos else ""
	var key := "%d|%s|%s|%s" % [ph, wt, Game.lang, str(Game.indoor(w.key))]
	if key == _sky_key:
		return
	_sky_key = key
	for c in sky.get_children():
		c.queue_free()
	if not Game.indoor(w.key):
		var icons := ["sunset", "sun", "sunset", "moon"]
		var cols := [Color(1, 0.75, 0.45), Color(1, 0.88, 0.45), Color(1, 0.6, 0.4), Color(0.75, 0.82, 1)]
		var ch := UI.chip(icons[ph], cols[ph])
		ch.get_node("Value").text = Game.phase_name(ph)
		ch.get_node("Value").add_theme_font_size_override("font_size", 11)
		sky.add_child(ch)
	var wi := {"rain": ["cloud-rain", Color(0.7, 0.85, 1)], "snow": ["cloud-snow", Color(0.9, 0.95, 1)], "fog": ["cloud-fog", Color(0.8, 0.82, 0.85)], "ash": ["wind", Color(1, 0.65, 0.4)]}
	if wi.has(wt):
		sky.add_child(UI.icon_rect(wi[wt][0], 14, wi[wt][1]))

func show_title(text: String) -> void:
	title_l.text = text
	title_l.add_theme_font_override("font", UI.display_font())
	# top centre when it fits between the hero block and the minimap (wide phones); lower on narrow screens
	var tw_px: float = UI.display_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var gap: float = root.size.x - 2.0 * 276.0
	var top: float = 6.0 if tw_px + 16.0 <= gap else root.size.y * 0.2
	title.offset_top = top
	title.offset_bottom = top + 52.0
	var back := title.get_node_or_null("TitleBack")
	if back:
		back.set_meta("w", tw_px)
		back.queue_redraw()
	if title_tw:
		title_tw.kill()
	title.modulate.a = 0.0
	title_tw = create_tween()
	title_tw.tween_property(title, "modulate:a", 1.0, 0.45)
	title_tw.tween_interval(1.8)
	title_tw.tween_property(title, "modulate:a", 0.0, 0.8)

## a short message (top centre, queued); icon names come from data/icons.json
func toast(text: String, icon := "info", col := UI.GOLD) -> void:
	notify.push(text, icon, col, 2.4)

func hint(text: String) -> void:
	notify.push(text, "sparkles", UI.GOLD_HI, 5.0)

## boss banners ("Phase II", "VANQUISHED", "Again!") use the spot where the map title fades in: the banner wins
func banner(a: String, b: String, col: Color, sec := 1.8) -> void:
	if title_tw:
		title_tw.kill()
	title.modulate.a = 0.0
	boss_ui.banner(a, b, col, sec)

## the level-up banner: the new level and what grew (as the HTML level formula: +8 health, +2 attack, +1 defence)
## a boss banner ("VANQUISHED", a phase) on screen is never covered: the level-up waits for it
func level_up(lv: int) -> void:
	_pending_level = lv
	refresh()

var _pending_level := -1
var _heart_t := 0.0

func _show_level_up() -> void:
	var lv := _pending_level
	_pending_level = -1
	var a := Game.t("Level %d!" % lv, "سطح %s!" % Game.num(lv))
	var b := Game.t("Health +8 · Attack +2 · Mana +2 · Talent point +1", "جان +%s، حمله +%s، مانا +%s، امتیاز استعداد +%s" % [Game.num(8), Game.num(2), Game.num(2), Game.num(1)])
	banner(a, b, UI.GOLD_HI, 2.0)
	for id in Skills.learned_at(lv):
		toast(Game.t("Skill learned: ", "مهارت آموختی: ") + Skills.spell_name(id), Skills.spell_icon(id), Skills.spell_col(id))
	if Game.talent_points() > 0 and not Game.v18().get("tips", {}).has("talents"):
		var tips: Dictionary = Game.v18().get("tips", {})
		tips["talents"] = true
		Game.v18()["tips"] = tips
		hint(Game.t("Spend talent points from the Menu — every level gives one.", "امتیاز استعداد را از فهرست خرج کن؛ هر سطح یک امتیاز می‌دهد."))

func _on_ult_ready() -> void:
	if player == null or player.dead:
		return
	toast(Game.t("Ultimate ready: ", "ضربهٔ نهایی آماده است: ") + Skills.ult_name(), Skills.ult()["icon"], Skills.ult()["col"])
	Sfx.play("charge", -4.0, 0.0)

func clear_msgs() -> void:
	notify.clear()
	boss_ui.clear_msgs()

func open_pause(tab := "") -> void:
	if get_tree().paused or death.visible or (player and is_instance_valid(player) and player.dead):
		return
	pad.release_all()
	if tab != "":
		pause.tab = tab
	pause.open()

## fade to black and back (map changes)
func fade_out(sec := 0.18) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, sec)
	await tw.finished

func fade_in(sec := 0.3) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 0.0, sec)

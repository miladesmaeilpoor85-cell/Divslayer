extends Control
## Rudabeh the Alchemist's cauldron (v0.11): herbs, essence and a few coins become potions and scrolls.
## Pauses the world while open. The recipes are the HTML game's (data/Tables/RECIPES.json).

signal closed

const Portrait = preload("res://scripts/ui/portrait.gd")

var panel: PanelContainer
var portrait: Control
var title_l: Label
var info_l: Label
var herb_l: Label
var ess_l: Label
var gold_l: Label
var list: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# (v0.27, UX) a tap outside the panel closes it, as phone sheets do
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e):
		# the release of the tap that opened the panel must not close it again
		if (e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT)) and not e.pressed \
				and Time.get_ticks_msec() - int(get_meta("opened_at", 0)) > 400:
			close())
	add_child(dim)
	panel = PanelContainer.new()
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 0.07
	panel.anchor_bottom = 0.93
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	portrait = Portrait.new()
	portrait.square = true
	portrait.custom_minimum_size = Vector2(56, 56)
	head.add_child(portrait)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(tv)
	title_l = UI.label("", 20, UI.GOLD_HI)
	tv.add_child(title_l)
	info_l = UI.label("", 12, UI.MUTED)
	info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(info_l)
	var purse := PanelContainer.new()
	purse.add_theme_stylebox_override("panel", UI.box(Color(0.06, 0.045, 0.035, 0.9), UI.GOLD_DIM, 1, 18, 12, 4))
	purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(purse)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 6)
	purse.add_child(ph)
	ph.add_child(UI.icon_rect("leaf", 16, Color(0.55, 0.85, 0.5)))
	herb_l = UI.label("", 15, UI.CREAM)
	ph.add_child(herb_l)
	ph.add_child(UI.icon_rect("sparkles", 16, Color(0.6, 0.7, 1.0)))
	ess_l = UI.label("", 15, UI.CREAM)
	ph.add_child(ess_l)
	ph.add_child(UI.icon_rect("coins", 16, UI.GOLD_HI))
	gold_l = UI.label("", 15, UI.GOLD_HI)
	ph.add_child(gold_l)
	var close_btn := Button.new()
	close_btn.theme_type_variation = "FlatButton"
	close_btn.icon = UI.icon("x", 60)
	close_btn.add_theme_constant_override("icon_max_width", 22)
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	var rule := ColorRect.new()
	rule.color = Color(UI.GOLD, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	v.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

func open() -> void:
	set_meta("opened_at", Time.get_ticks_msec())
	visible = true
	get_tree().paused = true
	portrait.show_sheet("npcs", "alchemist")
	_render()
	# (v0.27.1, side-quest test: reopened, the list kept its old scroll and the first recipe was off-screen)
	if list and list.get_parent() is ScrollContainer:
		(list.get_parent() as ScrollContainer).scroll_vertical = 0
	Sfx.play("ui")

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _render(flash_id := "") -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	panel.layout_direction = Control.LAYOUT_DIRECTION_RTL if Game.lang == "fa" else Control.LAYOUT_DIRECTION_LTR
	title_l.text = Game.t("Rudabeh the Healer", "رودابهٔ درمانگر")
	title_l.add_theme_font_override("font", UI.display_font())
	info_l.text = Game.t("Bogbloom and essence, a few coins, and I will brew anything.", "گلِ مرداب و عصاره و چند سکه بیاور، هر چه بخواهی دم می‌کنم.")
	herb_l.text = Game.num(Game.herbs())
	ess_l.text = Game.num(Game.essence())
	gold_l.text = Game.num(int(Game.state.get("gold", 0)))
	for r in Game.recipes():
		list.add_child(_row(r, str(r["id"]) == flash_id))

func _cost_text(r: Dictionary) -> String:
	var parts := []
	var c: Dictionary = r["cost"]
	if c.has("herb"):
		parts.append("%s %s" % [Game.num(int(c["herb"])), Game.t("Bogbloom", "گلِ مرداب")])
	if c.has("essence"):
		parts.append("%s %s" % [Game.num(int(c["essence"])), Game.t("essence", "عصاره")])
	parts.append("%s %s" % [Game.num(int(r.get("gold", 0))), Game.t("gold", "سکه")])
	return Game.sep(true).join(parts)

func _row(r: Dictionary, flash: bool) -> Control:
	var why := Game.craft_block(str(r["id"]))
	var pan := PanelContainer.new()
	pan.add_theme_stylebox_override("panel", UI.box(Color(UI.INK2, 0.95), UI.GOLD if flash else (UI.GOLD_DIM if why == "" else Color(UI.MUTED, 0.4)), 2 if flash else 1, 12, 12, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	pan.add_child(h)
	var scroll_kind := str(r["result"]["type"]).ends_with("_scroll")
	h.add_child(UI.icon_rect("scroll-text" if scroll_kind else "flask-conical", 22, Color(0.7, 0.8, 1.0) if scroll_kind else Color(0.95, 0.5, 0.6)))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", -1)
	h.add_child(v)
	v.add_child(UI.label(Game.craft_name(r), 15, UI.CREAM))
	var d := UI.label(Game.craft_desc(r), 11, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	v.add_child(UI.label(_cost_text(r), 12, UI.GOLD if why == "" else Color(1, 0.55, 0.45)))
	var own := UI.label(Game.t("have ", "داری ") + Game.num(Game.craft_owned(r)), 11, UI.MUTED)
	h.add_child(own)
	var b := UI.button(Game.t("Brew", "دم کن"), "", why == "", 38)
	b.name = "Brew_" + str(r["id"])
	b.disabled = why != ""
	b.pressed.connect(func():
		if Game.craft(str(r["id"])):
			Sfx.play("potion")
			_render(str(r["id"])))
	h.add_child(b)
	return pan

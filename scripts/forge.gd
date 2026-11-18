extends Control
## The Forge (v0.12): Kavian the Smith refines the weapon and the armour you carry, up to +5 each.
## Herbs and essence for every level, obsidian from +4, a few coins. Pauses the world while open.

signal closed

const Portrait = preload("res://scripts/ui/portrait.gd")

var panel: PanelContainer
var portrait: Control
var title_l: Label
var info_l: Label
var herb_l: Label
var ess_l: Label
var obs_l: Label
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
	ph.add_child(UI.icon_rect("gem", 16, Color(0.75, 0.55, 0.95)))
	obs_l = UI.label("", 15, UI.CREAM)
	ph.add_child(obs_l)
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
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	v.add_child(list)

func open() -> void:
	set_meta("opened_at", Time.get_ticks_msec())
	visible = true
	get_tree().paused = true
	portrait.show_sheet("npcs", "smith")
	_render()
	Sfx.play("ui")

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _render(flash := "") -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	panel.layout_direction = Control.LAYOUT_DIRECTION_RTL if Game.lang == "fa" else Control.LAYOUT_DIRECTION_LTR
	title_l.text = Game.t("The Forge", "کورهٔ آهنگری")
	title_l.add_theme_font_override("font", UI.display_font())
	info_l.text = Game.t("Kavian can refine what you already carry.", "کاویان می‌تواند همان چیزی را که داری تقویت کند.")
	herb_l.text = Game.num(Game.herbs())
	ess_l.text = Game.num(Game.essence())
	obs_l.text = Game.num(int(Game.state.get("obsidian", 0)))
	gold_l.text = Game.num(int(Game.state.get("gold", 0)))
	list.add_child(_row("w", flash == "w"))
	list.add_child(_row("a", flash == "a"))

func _cost_text(c: Dictionary) -> String:
	var parts := []
	if int(c["herb"]) > 0:
		parts.append("%s %s" % [Game.num(int(c["herb"])), Game.t("Bogbloom", "گلِ مرداب")])
	if int(c["essence"]) > 0:
		parts.append("%s %s" % [Game.num(int(c["essence"])), Game.t("essence", "عصاره")])
	if int(c["obsidian"]) > 0:
		parts.append("%s %s" % [Game.num(int(c["obsidian"])), Game.t("obsidian", "شَبَه")])
	parts.append("%s %s" % [Game.num(int(c["gold"])), Game.t("gold", "سکه")])
	return Game.t("Cost: ", "هزینه: ") + Game.sep(true).join(parts)

func _row(kind: String, flash: bool) -> Control:
	var why := Game.forge_block(kind)
	var lv := Game.forge_level(kind)
	var pan := PanelContainer.new()
	pan.add_theme_stylebox_override("panel", UI.box(Color(UI.INK2, 0.95), UI.GOLD if flash else (UI.GOLD_DIM if why == "" else Color(UI.MUTED, 0.4)), 2 if flash else 1, 12, 14, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	pan.add_child(h)
	h.add_child(UI.icon_rect("sword" if kind == "w" else "shield", 28, Color(1.0, 0.7, 0.4)))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var nm := UI.label(Game.forge_item_name(kind) + ("  +%d" % lv if lv > 0 else ""), 17, UI.CREAM)
	v.add_child(nm)
	var per: String = (Game.t("+%d ATK per level", "+%s حمله در هر سطح") if kind == "w" else Game.t("+%d DEF per level", "+%s دفاع در هر سطح"))
	var amt := int(Game.FORGE_ATK if kind == "w" else Game.FORGE_DEF)
	v.add_child(UI.label((per % amt) if Game.lang != "fa" else (per % Game.num(amt)), 12, UI.MUTED))
	if why == "max":
		v.add_child(UI.label(Game.t("Maximum refinement — ", "بیشترین حد — ") + "+%d" % Game.FORGE_MAX, 13, UI.GOLD_HI))
	else:
		v.add_child(UI.label(_cost_text(Game.forge_cost(kind)), 12, UI.GOLD if why == "" else Color(1, 0.55, 0.45)))
		# (v0.23, playtest: "I never found a herb or an essence and nothing told me where they come from")
		var where := {"herb": Game.t("Bogbloom: foes drop it now and then, most often in the Shadowfen.",
				"گلِ مرداب: دشمن‌ها گاهی می‌اندازند (بیشتر در مردابِ سایه) — رودابه هم با گلِ مرداب کار می‌کند."),
			"essence": Game.t("Essence: every boss you defeat leaves some.", "عصاره: هر سرکرده‌ای که شکست می‌دهی کمی جا می‌گذارد."),
			"obsidian": Game.t("Obsidian: shards lie about the Emberforge (and the slopes of Damavand).", "شَبَه: تکه‌هایش در آهنگرخانهٔ اخگر (و دامنهٔ دماوند) افتاده‌اند.")}
		if where.has(why):
			var hint := UI.label(where[why], 11, UI.MUTED)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(hint)
	var b := UI.button(Game.t("Max", "کامل") if why == "max" else Game.t("Upgrade", "ارتقا"), "", why == "", 40)
	b.name = "Forge_" + kind
	b.disabled = why != ""
	b.pressed.connect(func():
		if Game.forge_upgrade(kind):
			Sfx.play("clank", -2.0)
			Sfx.play("quest", -6.0)
			_render(kind))
	h.add_child(b)
	return pan

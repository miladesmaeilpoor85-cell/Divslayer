extends Control
## Sindokht's blades and Kavian's armour as item cards: the whole ladder of tiers (owned, the next one
## to buy, locked ones), what each adds over your current gear, the price in gold (red when you are
## short) and your purse in the header. Pauses the world while open.

signal closed
signal bought

const Portrait = preload("res://scripts/ui/portrait.gd")
const ItemIcon = preload("res://scripts/ui/item_icon.gd")

var vendor := ""
var panel: PanelContainer
var portrait: Control
var title_l: Label
var info_l: Label
var gold_l: Label
var grid: GridContainer
var close_btn: Button

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
	ph.add_child(UI.icon_rect("coins", 18, UI.GOLD_HI))
	gold_l = UI.label("", 16, UI.GOLD_HI)
	gold_l.add_theme_font_override("font", UI.font_bold)
	ph.add_child(gold_l)
	close_btn = Button.new()
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
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

func open(v: String) -> void:
	set_meta("opened_at", Time.get_ticks_msec())
	vendor = v
	visible = true
	get_tree().paused = true
	portrait.show_sheet("npcs", v if v in ["merchant", "hesk"] else "smith")
	_render()
	Sfx.play("ui")

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

static func desc_fa(d: String) -> String:
	return d.replace("max HP", "بیشینهٔ جان").replace("ATK", "حمله").replace("DEF", "دفاع").replace("HP", "جان").replace("MP", "مانا").replace(",", "،")

func _render(flash_id := "") -> void:
	for c in grid.get_children():
		c.queue_free()
	var fa := Game.lang == "fa"
	panel.layout_direction = Control.LAYOUT_DIRECTION_RTL if fa else Control.LAYOUT_DIRECTION_LTR
	var shop: Dictionary = Game.table("SHOPS").get(vendor, {})
	var titles := {"hesk": "انبارِ هوم"}
	title_l.text = Game.t(str(shop.get("title", vendor)), titles.get(vendor, ""))
	title_l.add_theme_font_override("font", UI.display_font())
	var greets := {"merchant": "تیغ و توشه برای راه!", "smith": "آهنی که در کورهٔ کاوه تافته شود، نمی‌شکند.", "hesk": "قیمتِ منصفانه، دست‌های یخ‌زده."}
	info_l.text = Game.t(str(shop.get("greet", "")), greets.get(vendor, ""))
	gold_l.text = Game.num(int(Game.state.get("gold", 0)))
	grid.columns = 3 if get_viewport_rect().size.x / max(1.0, get_viewport_rect().size.y) < 1.6 and size.x > 900 else 2
	for it in Game.shop_catalog(vendor):
		grid.add_child(_card(it, str(it.get("id", "")) == flash_id))

func _card(it: Dictionary, flash: bool) -> Control:
	var st := str(it.get("state", "buy"))
	var price := int(it.get("price", 0))
	var gold := int(Game.state.get("gold", 0))
	var afford := gold >= price
	var buyable := (st == "buy" or st == "next")
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 88)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var edge := UI.GOLD if (buyable and afford) else UI.GOLD_DIM
	if st == "owned":
		edge = Color(UI.GOOD, 0.5)
	var bg := Color(UI.INK2, 0.95) if buyable else Color(UI.INK, 0.8)
	b.add_theme_stylebox_override("normal", UI.box(bg, edge, 2, 12, 10))
	b.add_theme_stylebox_override("hover", UI.box(Color(UI.INK3, 0.98), UI.GOLD_HI if buyable else edge, 2, 12, 10))
	b.add_theme_stylebox_override("pressed", UI.box(Color(0.08, 0.06, 0.045), UI.GOLD_HI, 2, 12, 10))
	b.add_theme_stylebox_override("disabled", UI.box(bg, edge, 2, 12, 10))
	b.disabled = not buyable
	if buyable:
		b.pressed.connect(_tap.bind(it))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.layout_direction = Control.LAYOUT_DIRECTION_RTL if Game.lang == "fa" else Control.LAYOUT_DIRECTION_LTR
	b.add_child(h)
	# the item's picture on a tile framed in its rarity colour
	var tier := int(it.get("tier", 0))
	var kind := "potion"
	if str(it.get("icon", "")) == "sword":
		kind = "weapon"
	elif str(it.get("icon", "")) == "shield":
		kind = "armor"
	elif str(it.get("id", "")) == "mp_potion":
		kind = "mpotion"
	var pic := ItemIcon.new()
	pic.setup(kind, tier if kind != "potion" and kind != "mpotion" else 1)
	pic.custom_minimum_size = Vector2(62, 62)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.dim = st == "locked"
	h.add_child(pic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var ncol: Color = ItemIcon.rarity_color(kind, tier).lightened(0.25) if kind != "potion" and kind != "mpotion" else UI.CREAM
	var n := UI.label(Game.t(str(it.get("name", ""))), 15, ncol if buyable or st == "owned" else UI.MUTED)
	n.add_theme_font_override("font", UI.font_bold)
	v.add_child(n)
	var d := str(it.get("desc", ""))
	var stat := UI.label(Game.num(desc_fa(d)) if Game.lang == "fa" else d, 12, UI.MUTED)
	if it.has("tier") and st != "owned":
		var gain := _gain(it)
		if gain > 0:
			var what := Game.t("ATK", "حمله") if vendor == "merchant" else Game.t("DEF", "دفاع")
			stat.text = Game.num("+%d %s" % [gain, what]) + Game.t("  (vs. now)", "  (نسبت به اکنون)")
			stat.add_theme_color_override("font_color", UI.GOOD if st == "next" else UI.MUTED)
	v.add_child(stat)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 5)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	match st:
		"owned":
			foot.add_child(UI.icon_rect("check", 14, UI.GOOD))
			foot.add_child(UI.label(Game.t("Owned", "داری"), 12, UI.GOOD))
		"locked":
			foot.add_child(UI.icon_rect("lock", 13, UI.MUTED))
			foot.add_child(UI.label(Game.t("Buy the previous tier first", "اول ردهٔ قبلی را بخر"), 11, UI.MUTED))
		_:
			foot.add_child(UI.icon_rect("coins", 14, UI.GOLD_HI if afford else UI.BAD))
			var pl := UI.label(Game.num(price), 14, UI.GOLD_HI if afford else UI.BAD)
			pl.add_theme_font_override("font", UI.font_bold)
			foot.add_child(pl)
			if it.get("id", "") == "hp_potion":
				foot.add_child(UI.label(Game.t("  you have ", "  داری: ") + Game.num(int(Game.state.get("potions", 0))), 11, UI.MUTED))
			elif it.get("id", "") == "mp_potion":
				foot.add_child(UI.label(Game.t("  you have ", "  داری: ") + Game.num(int(Game.state.get("mana_potions", 0))), 11, UI.MUTED))
			elif it.get("id", "") == "greater_potion":
				foot.add_child(UI.label(Game.t("  you have ", "  داری: ") + Game.num(int(Game.state.get("greater", 0))), 11, UI.MUTED))
	if flash:
		b.modulate = Color(1.6, 1.5, 1.1)
		var tw := b.create_tween()
		tw.tween_property(b, "modulate", Color(1, 1, 1), 0.45)
	return b

## how much this tier adds over what the hero carries now
func _gain(it: Dictionary) -> int:
	var tier := str(int(it.get("tier", 0)))
	if vendor == "merchant":
		var now: Dictionary = Game.table("WEAPON_TIERS").get(str(int(Game.state.get("weapon", 0))), {})
		var next: Dictionary = Game.table("WEAPON_TIERS").get(tier, {})
		return int(next.get("atkBonus", 0)) - int(now.get("atkBonus", 0))
	var now_a: Dictionary = Game.table("ARMOR_TIERS").get(str(int(Game.state.get("armor", 0))), {})
	var next_a: Dictionary = Game.table("ARMOR_TIERS").get(tier, {})
	return int(next_a.get("def", 0)) - int(now_a.get("def", 0))

## (v0.23, playtest: "one tap took my 45 coins") a blade or a suit of armour asks for a second tap; potions do not
var _armed := ""
var _armed_at := 0

func _tap(it: Dictionary) -> void:
	var id := str(it.get("id", ""))
	# (v0.24, playtest) what you cannot afford says so at once — no "tap again" first
	var can_pay: bool = int(Game.state.get("gold", 0)) >= int(it.get("price", 0))
	if it.has("tier") and can_pay and (id != _armed or Time.get_ticks_msec() - _armed_at > 4000):
		_armed = id
		_armed_at = Time.get_ticks_msec()
		Sfx.play("ui")
		info_l.text = Game.t("Tap again to buy %s for %d gold." % [Game.t(str(it.get("name", ""))), int(it.get("price", 0))],
			"برای خریدِ %s به %s سکه، دوباره بزن." % [Game.t(str(it.get("name", ""))), Game.num(int(it.get("price", 0)))])
		info_l.add_theme_color_override("font_color", UI.GOLD_HI)
		return
	_armed = ""
	_buy(it)

func _buy(it: Dictionary) -> void:
	var msg := Game.buy(vendor, it)
	if msg == "":
		Sfx.play("error")
		info_l.text = Game.t("Not enough gold!", "سکه‌ات کافی نیست!")
		info_l.add_theme_color_override("font_color", UI.BAD)
		return
	Sfx.play("coin")
	if it.has("tier"):
		Sfx.play("equip", -2.0)       # a new blade or new armour: the clink of buckles
	bought.emit()
	_render(str(it.get("id", "")))
	info_l.text = msg
	info_l.add_theme_color_override("font_color", UI.GOOD)

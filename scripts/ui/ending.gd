extends Control
## (v0.19) The end of a chapter (2, and from v0.23 also 3): a card over the world — the chapter's title, a few lines of epilogue, what the hero did
## (level, bosses slain, shrines, elites, contracts), thanks, and Continue (the world stays open to play on).

var title_l: Label
var sub_l: Label
var text_l: Label
var stats_box: GridContainer
var thanks_l: Label
var next_l: Label              # (v0.21) what waits now: Sorush's Boss Rush and New Game+
var go_btn: Button
var _k := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.07, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "EndingPanel"
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.07, 0.1, 0.97), Color(0.55, 0.8, 1.0), 2, 14, 22, 14))
	panel.anchor_left = 0.14
	panel.anchor_right = 0.86
	panel.anchor_top = 0.06
	panel.anchor_bottom = 0.06
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var ic := UI.icon_rect("crown", 30, UI.GOLD_HI)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	title_l = UI.label("", 26, UI.GOLD_HI, 0)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title_l)
	sub_l = UI.label("", 15, Color(0.7, 0.88, 1.0))
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub_l)
	text_l = UI.label("", 13, UI.CREAM)
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_l.custom_minimum_size = Vector2(420, 0)
	v.add_child(text_l)
	stats_box = GridContainer.new()           # (v0.21) two columns: the card fits the screen with the larger interface
	stats_box.columns = 2
	stats_box.add_theme_constant_override("h_separation", 24)
	stats_box.add_theme_constant_override("v_separation", 2)
	stats_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(stats_box)
	thanks_l = UI.label("", 13, UI.GOLD)
	thanks_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(thanks_l)
	next_l = UI.label("", 12, Color(0.7, 0.88, 1.0))
	next_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(next_l)
	go_btn = UI.button("", "check", true, 44)
	go_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go_btn.pressed.connect(close)
	v.add_child(go_btn)

## what the hero did, as label lines
static func stats() -> Array:
	var kills: Dictionary = Game.v18().get("kills", {})
	var bosses := 0
	for k in kills:
		bosses += int(kills[k])
	var out := []
	out.append(Game.t("%s · %s · level %d" % [Game.hero_name(), Game.hero_role(), Game.lvl()], "%s، %s، سطح %s" % [Game.hero_name(), Game.hero_role(), Game.num(Game.lvl())]))
	out.append(Game.t("Bosses slain: %d" % bosses, "سرکرده‌های از پا درآمده: %s" % Game.num(bosses)))
	out.append(Game.t("Shrines cleansed: %d of %d" % [Game.shrines_done(), Game.SHRINE_ORDER.size()],
		"زیارتگاه‌های پاک‌شده: %s از %s" % [Game.num(Game.shrines_done()), Game.num(Game.SHRINE_ORDER.size())]))
	out.append(Game.t("Elites slain: %d · Contracts: %d" % [Game.elites_slain(), Game.contracts_done()],
		"نخبگانِ کشته‌شده: %s، قراردادها: %s" % [Game.num(Game.elites_slain()), Game.num(Game.contracts_done())]))
	return out

## chapter: 2 (the Sleeper Beneath) or 3 (v0.23, the Chains of Damavand)
var chapter := 2

func open(ch := 2) -> void:
	chapter = ch
	var C = Game.Ch3 if ch == 3 else Game.Ch2
	title_l.text = C.line("end_title")
	title_l.add_theme_font_override("font", UI.display_font())
	sub_l.text = C.line("title")
	text_l.text = C.line("end_text")
	thanks_l.text = Game.Ch2.line("end_thanks")
	if ch == 3:
		next_l.text = Game.t("The Derafsh-e Kaviani stays with you. Sorush's Boss Rush and New Game+ wait in the Crystal Sanctum.",
			"درفشِ کاویانی پیشِ تو می‌ماند. «نبردهای به‌یادمانده» و «بازیِ نو+» در معبد بلورین منتظرند.")
	else:
		next_l.text = Game.t("Sorush in the Crystal Sanctum now offers the Boss Rush — and New Game+. Kavian the Smith has news for you.",
			"سروش در معبد بلورین حالا «نبردهای به‌یادمانده» و «بازیِ نو+» را پیشنهاد می‌کند. کاویانِ آهنگر هم خبری برایت دارد.")
	go_btn.text = "  " + Game.Ch2.line("end_go") + "  "
	for c in stats_box.get_children():
		c.queue_free()
	for s in stats():
		var l := UI.label(str(s), 13, UI.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_box.add_child(l)
	visible = true
	modulate.a = 0.0
	get_tree().paused = true
	Music.set_moment("ending")          # (v0.31) the second take of the main theme plays over the end card
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.6)

func close() -> void:
	Sfx.play("ui")
	Music.set_moment("")
	visible = false
	get_tree().paused = false

extends Control
## The menu behind the top-right button: Resume; the Hero sheet (the hero in his current gear, turning on a
## pedestal, his stats, his equipment drawn as items, quests); Skills (v0.6: the spells, which two sit on
## the spell buttons, the class ultimate, and the talent tree); the Map (this region up close and the world's
## regions joined by their roads); Settings (display: language, interface size, camera, graphics, brightness;
## sound and feel: sound, music, their volumes, vibration, screen shake, quest arrow; how to play; credits); Save & quit.

signal quit_requested

const Portrait = preload("res://scripts/ui/portrait.gd")
const Bar = preload("res://scripts/ui/bar.gd")
const ItemIcon = preload("res://scripts/ui/item_icon.gd")
const Credits = preload("res://scripts/ui/credits.gd")
const WorldMap = preload("res://scripts/ui/world_map.gd")
const Minimap = preload("res://scripts/ui/minimap.gd")
const Sheets = preload("res://scripts/sheets.gd")
const Tex = preload("res://scripts/fx/tex.gd")
const Skills = preload("res://scripts/skills.gd")

var hud: Node = null
var panel: PanelContainer
var nav: VBoxContainer
var body: VBoxContainer
var tab := "hero"
var sub := "spells"            # the Skills tab: "spells" or "talents"
var hsub := "sheet"            # (v0.20) the Hero tab: "sheet", "ach" (achievements) or "looks"
var _shown := ""
var _tabs := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	panel = PanelContainer.new()
	panel.anchor_left = 0.06
	panel.anchor_right = 0.94
	panel.anchor_top = 0.05
	panel.anchor_bottom = 0.95
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	# (v0.23, playtest) the column scrolls: with the large interface "Save & quit" fell off the bottom of the panel
	var nav_scroll := ScrollContainer.new()
	nav_scroll.name = "NavScroll"
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	nav_scroll.custom_minimum_size = Vector2(176, 0)
	row.add_child(nav_scroll)
	nav = VBoxContainer.new()
	nav.custom_minimum_size = Vector2(176, 0)
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_theme_constant_override("separation", 4)
	nav_scroll.add_child(nav)
	var sep := ColorRect.new()
	sep.color = Color(UI.GOLD, 0.3)
	sep.custom_minimum_size = Vector2(1, 0)
	row.add_child(sep)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

func open() -> void:
	visible = true
	get_tree().paused = true
	Sfx.play("book")
	_build_nav()
	_show(tab)

func close() -> void:
	_shown = ""
	visible = false
	get_tree().paused = false
	tab = "hero"

func _build_nav() -> void:
	for c in nav.get_children():
		c.queue_free()
	_tabs.clear()
	var fa := Game.lang == "fa"
	panel.layout_direction = Control.LAYOUT_DIRECTION_RTL if fa else Control.LAYOUT_DIRECTION_LTR
	# the title gives its room to the buttons unless the interface is small, so "Save & quit" shows without scrolling
	# (v0.24, playtest: it was cut off at the normal size on a phone); the large interface also slims the buttons
	if int(Game.settings.get("ui", 1)) < 1:
		var t := UI.title(Game.t("Paused", "مکث"), 20)
		nav.add_child(t)
	var resume := UI.button(Game.t("Resume", "ادامهٔ بازی"), "play", true, 40)
	resume.pressed.connect(close)
	nav.add_child(resume)
	for k in [["hero", "user", "Hero", "قهرمان"], ["skills", "sparkles", "Skills", "مهارت‌ها"], ["gear", "gem", "Gear", "تجهیزات"], ["map", "map", "Map", "نقشه"], ["settings", "settings", "Settings", "تنظیمات"]]:
		var b := UI.button(Game.t(k[2], k[3]), k[1], false, 36)
		b.toggle_mode = true
		b.pressed.connect(_show.bind(k[0]))
		nav.add_child(b)
		_tabs[k[0]] = b
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	if Game.talent_points() > 0 and _tabs.has("skills"):
		_tabs["skills"].text += "  •"
	var quit := UI.button(Game.t("Save & quit", "ذخیره و خروج"), "door-open", false, 36)
	quit.pressed.connect(_quit)
	nav.add_child(quit)
	for b in nav.get_children():
		if b is Button:
			b.alignment = HORIZONTAL_ALIGNMENT_RIGHT if fa else HORIZONTAL_ALIGNMENT_LEFT
			if int(Game.settings.get("ui", 1)) >= 2:
				_compact(b)

## (v0.24, playtest: "Save & quit" was cut off at the foot of the menu on a phone) the menu's buttons a little slimmer
func _compact(b: Button) -> void:
	b.custom_minimum_size.y = 34.0
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var sb: StyleBox = b.get_theme_stylebox(st)
		if sb == null:
			continue
		var c: StyleBox = sb.duplicate()
		c.content_margin_top = 4.0
		c.content_margin_bottom = 4.0
		b.add_theme_stylebox_override(st, c)

func _show(which: String) -> void:
	# re-drawing the same page (a spell bound, a talent learned) keeps where you had scrolled to
	var sc := body.get_parent() as ScrollContainer
	var keep := 0
	if sc and which == _shown:
		keep = sc.scroll_vertical
	_shown = which
	tab = which
	if sc:
		sc.set_deferred("scroll_vertical", keep)
		get_tree().process_frame.connect(func(): sc.scroll_vertical = keep, CONNECT_ONE_SHOT)
	for k in _tabs:
		_tabs[k].button_pressed = k == which
	for c in body.get_children():
		c.queue_free()
	match which:
		"settings": _settings()
		"map": _map()
		"skills": _skills()
		"gear": _gear()
		_: _hero()
	_pass_drags(body)

## (v0.23, playtest) a finger that lands on a card or a button and slides must scroll the page: the controls pass the
## drag on to the ScrollContainer (a tap still presses them)
func _pass_drags(n: Node) -> void:
	for c in n.get_children():
		if c is Control and (c as Control).mouse_filter == Control.MOUSE_FILTER_STOP and not (c is ScrollContainer) and not (c is Slider):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		_pass_drags(c)

func _quit() -> void:
	Game.save_game()
	close()
	quit_requested.emit()

# ---------------------------------------------------------------- hero sheet
func _hero() -> void:
	# (v0.20) three pages: the hero sheet, the achievements, the looks
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 6)
	body.add_child(seg)
	var news: Array = Game.Ach.unseen()
	var look_new := false
	for id in news:
		if not Game.Looks.earned_by(str(id)).is_empty():
			look_new = true
	for o in [["sheet", "user", Game.t("Hero", "قهرمان")],
			["ach", "trophy", Game.t("Achievements", "دستاوردها") + "  %s/%s" % [Game.num(Game.Ach.count()), Game.num(Game.Ach.total())] + ("  •" if not news.is_empty() else "")],
			["looks", "shirt", Game.t("Looks", "ظاهرها") + ("  •" if look_new else "")]]:
		var b := UI.button(o[2], o[1], hsub == o[0], 36)
		b.name = "Hero_" + o[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			hsub = o[0]
			_shown = ""
			Sfx.play("ui")
			_show("hero"))
		seg.add_child(b)
	match hsub:
		"ach":
			_achievements()
		"looks":
			_looks()
		_:
			_hero_sheet()

func _hero_sheet() -> void:
	var fa := Game.lang == "fa"
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	body.add_child(top)
	top.add_child(_hero_view())
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 6)
	top.add_child(tv)
	var cname: String = Game.hero_name() + Game.sep(true) + Game.hero_role()
	var nl := UI.label(cname + Game.sep(true) + Game.t("Level ", "سطح ") + Game.num(Game.lvl()) + (Game.t("  ·  New Game+ %d" % Game.ng(), "، بازیِ نو+ %s" % Game.num(Game.ng())) if Game.ng() > 0 else ""), 19, UI.GOLD_HI)
	nl.add_theme_font_override("font", UI.font_bold)
	tv.add_child(nl)
	var xpb := Bar.new()
	xpb.custom_minimum_size = Vector2(0, 14)
	xpb.fill = UI.XP
	xpb.fill_hi = Color(0.75, 0.92, 1)
	xpb.trail = false
	var xn: float = max(1.0, float(Game.state.get("xp_next", 40)))
	xpb.value = float(Game.state.get("xp", 0)) / xn
	xpb.text = Game.num("%d / %d " % [int(Game.state.get("xp", 0)), int(xn)]) + Game.t("XP", "تجربه")
	tv.add_child(xpb)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	tv.add_child(grid)
	var stats := [
		["heart", UI.HP_HI, Game.t("Health", "جان"), "%d / %d" % [int(ceil(Game.hp)), int(Game.max_hp())]],
		["sword", UI.GOLD_HI, Game.t("Attack", "حمله"), "%d" % int(Game.atk())],
		["shield", Color(0.62, 0.78, 0.95), Game.t("Defence", "دفاع"), "%d" % int(Game.defense())],
		["footprints", UI.STAM, Game.t("Speed", "سرعت"), Game.dec(Game.speed() / Game.PXS)],
		["zap", Color(1, 0.85, 0.4), Game.t("Critical", "ضربهٔ کاری"), Game.num("%d%%" % int(Game.crit_chance() * 100.0))],
		["coins", UI.GOLD_HI, Game.t("Gold", "سکه"), "%d" % int(Game.state.get("gold", 0))],
		["droplets", Color(0.5, 0.7, 1.0), Game.t("Mana", "مانا"), "%d / %d" % [int(Game.mp), int(Game.max_mp())]],
		["star", UI.GOLD_HI, Game.t("Talent points", "امتیاز استعداد"), "%d" % Game.talent_points()],
	]
	for s in stats:
		grid.add_child(_stat(s[0], s[1], s[2], Game.num(s[3])))
	body.add_child(_section(Game.t("Equipment", "تجهیزات")))
	var gear := HBoxContainer.new()
	gear.add_theme_constant_override("separation", 10)
	body.add_child(gear)
	var wt := int(Game.state.get("weapon", 0))
	var at := int(Game.state.get("armor", 0))
	var w: Dictionary = Game.table("WEAPON_TIERS").get(str(wt), {})
	var a: Dictionary = Game.table("ARMOR_TIERS").get(str(at), {})
	gear.add_child(_gear_card("weapon", wt, Game.t(str(w.get("name", "—"))), Game.num("+%d " % int(w.get("atkBonus", 0))) + Game.t("attack", "حمله")))
	if at > 0:
		gear.add_child(_gear_card("armor", at, Game.t(str(a.get("name", "—"))), Game.num("+%d " % int(a.get("def", 0))) + Game.t("defence", "دفاع")))
	else:
		gear.add_child(_gear_card("armor", 0, Game.t("No armour", "بی‌زره"), Game.t("Kavian sells some", "کاویان زره می‌فروشد")))
	gear.add_child(_gear_card("potion", 1, Game.t("Potions", "معجون‌ها"),
		Game.t("health ×%d · mana ×%d" % [int(Game.state.get("potions", 0)), int(Game.state.get("mana_potions", 0))],
			"جان ×%s، مانا ×%s" % [Game.num(int(Game.state.get("potions", 0))), Game.num(int(Game.state.get("mana_potions", 0)))])))
	body.add_child(_section(Game.t("Quests", "مأموریت‌ها")))
	var names := [["The Sunken Crypt", "سردابِ فرورفته"], ["The King of Mazandaran", "شاه مازندران"], ["The Shadowfen", "مردابِ سایه"]]
	for i in 3:
		var st := Game.q(i + 1)
		if st == "not_started":
			continue
		var done := st == "done" or st == "complete"
		var label: String = Game.t("done", "انجام شد") if st == "done" else (Game.t("return to Zal", "نزد زال برگرد") if st == "complete" else Game.t("in progress", "در جریان"))
		body.add_child(_line("check" if done else "scroll-text", Game.t(names[i][0], names[i][1]), label, UI.GOOD if done else UI.GOLD))
	var bst: String = Game.brann_sync()
	if bst != "none":
		var bl: String = Game.t("in progress", "در جریان")
		if bst == "done":
			bl = Game.t("done", "انجام شد")
		elif ["core", "anvil_done", "ignarok_done"].has(bst):
			bl = Game.t("return to Jamshid", "نزد جمشید برگرد")
		body.add_child(_line("check" if bst == "done" else "scroll-text", Game.Story.line("title"), bl, UI.GOOD if bst == "done" else UI.GOLD))
	var shd := Game.shrines_done()
	var sh_seen := false
	for k in Game.SHRINE_ORDER:
		if Game.state.get("visited", {}).has(k):
			sh_seen = true
	if shd > 0 or sh_seen:
		var sl: String = Game.t("%d of %d" % [shd, Game.SHRINE_ORDER.size()], "%s از %s" % [Game.num(shd), Game.num(Game.SHRINE_ORDER.size())])
		body.add_child(_line("check" if shd >= Game.SHRINE_ORDER.size() else "scroll-text", Game.t("The Ancient Shrines", "زیارتگاه‌های کهن"), sl, UI.GOOD if shd >= Game.SHRINE_ORDER.size() else UI.GOLD))
		var gifts := []
		for id in Game.SIGILS:
			if Game.sigil(id) > 0:
				var g: Dictionary = Game.SIGILS[id]
				gifts.append(Game.t(g["name"][0], g["name"][1]) + " ×" + Game.num(Game.sigil(id)))
		if not gifts.is_empty():
			body.add_child(_line("sparkles", Game.t("Sigils", "نشان‌ها"), "، ".join(gifts) if Game.lang == "fa" else ", ".join(gifts), UI.GOLD_HI))
	# (v0.19) chapter 2, Jamshid's frost-steel, Hom's two quests
	for ql in Game.Ch2.log_lines():
		body.add_child(_line(str(ql[0]), str(ql[1]), str(ql[2]), UI.GOOD if bool(ql[3]) else UI.GOLD))
	# (v0.23) chapter 3, Qaren's serpent guards, the banner
	for ql in Game.Ch3.log_lines():
		body.add_child(_line(str(ql[0]), str(ql[1]), str(ql[2]), UI.GOOD if bool(ql[3]) else UI.GOLD))
	if Game.toll_st() != "none":
		var tl: String = Game.t("in progress", "در جریان")
		if Game.toll_st() == "done":
			tl = Game.t("done", "انجام شد")
		elif Game.toll_st() == "box":
			tl = Game.t("return to Sindokht", "نزد سیندخت برگرد")
		body.add_child(_line("check" if Game.toll_st() == "done" else "scroll-text", Game.Toll.line("quest_title"), tl, UI.GOOD if Game.toll_st() == "done" else UI.GOLD))
	if Game.contracts_done() > 0 or not Game.contracts()["list"].is_empty():
		var cl: Array = Game.contracts()["list"]
		for c in cl:
			var prog := "%s/%s" % [Game.num(int(c["have"])), Game.num(int(c["need"]))]
			body.add_child(_line("check" if Game.contract_done(c) else "target", Game.contract_label(c), prog, UI.GOOD if Game.contract_done(c) else UI.GOLD))
		body.add_child(UI.label(Game.t("Contracts completed: ", "قراردادهای انجام‌شده: ") + Game.num(Game.contracts_done()), 12, UI.MUTED))
	if int(Game.trial().get("best", 0)) > 0 or Game.elites_slain() > 0:
		body.add_child(UI.label(Game.t("Best trial wave: ", "بهترین موج آزمون: ") + Game.num(int(Game.trial().get("best", 0))) + Game.sep(true) + Game.t("Elites slain: ", "نخبگان کشته‌شده: ") + Game.num(Game.elites_slain()), 12, UI.MUTED))
	var now := UI.label(Game.t("Now: ", "اکنون: ") + Game.objective(), 12, UI.MUTED)
	now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(now)

## the hero in his gear on a little pedestal, walking on the spot and turning every few seconds
func _hero_view() -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(116, 132)
	box.draw.connect(func():
		var c := Vector2(58, 112)
		box.draw_texture_rect(Tex.glow(), Rect2(c - Vector2(60, 110), Vector2(120, 130)), false, Color(UI.GOLD, 0.18))
		box.draw_set_transform(c, 0.0, Vector2(1.0, 0.32))
		box.draw_circle(Vector2.ZERO, 40.0, Color(0, 0, 0, 0.45))
		box.draw_circle(Vector2(0, -6), 40.0, Color(0.3, 0.24, 0.18))
		box.draw_arc(Vector2(0, -6), 40.0, 0, TAU, 40, UI.GOLD, 3.0, true)
		box.draw_set_transform(Vector2.ZERO))
	if hud == null or hud.player == null:
		return box
	var spr := _figure(hud.player.sheet, Game.Looks.current(), 0.78)
	spr.position = Vector2(58, 108)
	box.add_child(spr)
	var dirs := ["walk_down", "walk_side", "walk_up", "walk_side"]
	var tw := spr.create_tween().set_loops()
	for i in 4:
		tw.tween_interval(1.8)
		tw.tween_callback(func():
			spr.play(dirs[(i + 1) % 4])
			spr.flip_h = (i + 1) % 4 == 3)
	return box

## the hero walking on the spot in a look (the Hero page, the wardrobe), with the look's crown
func _figure(sheet: String, look_id: String, sc: float) -> AnimatedSprite2D:
	var ch: Dictionary = Sheets.character("heroes", sheet)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = ch["frames"]
	spr.centered = false
	spr.offset = ch["offset"]
	spr.scale = Vector2(sc, sc)
	spr.play("walk_down")
	Game.Looks.apply(spr, sheet, look_id)
	if Game.Looks.crown(look_id):
		var cr := Node2D.new()
		cr.position = Vector2(0, -float(Game.Looks.HEAD.get(Game.cls, 46.0)) * 3.0 - 9.0)
		cr.scale = Vector2(3, 3)
		cr.draw.connect(func():
			var pts := PackedVector2Array([Vector2(-9, 0), Vector2(-10, -8), Vector2(-5, -4), Vector2(0, -10), Vector2(5, -4), Vector2(10, -8), Vector2(9, 0)])
			cr.draw_colored_polygon(pts, Color(1.0, 0.84, 0.36))
			var line := pts.duplicate()
			line.append(pts[0])
			cr.draw_polyline(line, Color(0.55, 0.38, 0.1), 1.2, true)
			cr.draw_circle(Vector2(0, -3), 1.8, Color(0.85, 0.2, 0.25)))
		spr.add_child(cr)
	return spr

# ---------------------------------------------------------------- achievements (v0.20)
func _achievements() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	body.add_child(head)
	head.add_child(UI.icon_rect("trophy", 20, UI.GOLD_HI))
	var n := Game.Ach.count()
	var tl := UI.label(Game.t("%d of %d earned" % [n, Game.Ach.total()], "%s از %s به دست آمده" % [Game.num(n), Game.num(Game.Ach.total())]), 15, UI.GOLD_HI)
	tl.add_theme_font_override("font", UI.font_bold)
	head.add_child(tl)
	var pb := Bar.new()
	pb.custom_minimum_size = Vector2(0, 10)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.fill = UI.GOLD
	pb.fill_hi = UI.GOLD_HI
	pb.trail = false
	pb.value = float(n) / float(max(1, Game.Ach.total()))
	head.add_child(pb)
	var note := UI.label(Game.t("Achievements stay with you through a new game. Some earn a new look for your hero.",
		"دستاوردها با شروعِ بازیِ تازه هم می‌مانند. بعضی‌شان ظاهرِ تازه‌ای برای قهرمانت می‌آورند."), 11, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	var news: Array = Game.Ach.unseen().duplicate()
	for id in Game.Ach.ids():
		grid.add_child(_ach_card(str(id), str(id) in news))
	Game.Ach.mark_seen()
	if hud:
		hud.refresh()

func _ach_card(id: String, is_new: bool) -> Control:
	var got := Game.Ach.has(id)
	var p := PanelContainer.new()
	p.name = "Ach_" + id
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UI.box(Color(UI.INK2, 0.92 if got else 0.6), Color(UI.GOLD_HI, 0.8) if got else Color(UI.GOLD, 0.18), 2 if got else 1, 10, 7))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(_spell_tile(Game.Ach.icon(id) if got else "lock", UI.GOLD_HI if got else UI.MUTED, got))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var nl := UI.label(Game.Ach.title(id), 13, UI.GOLD_HI if got else UI.CREAM)
	nl.add_theme_font_override("font", UI.font_bold)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nl)
	if is_new:
		top.add_child(UI.label(Game.t("NEW", "تازه"), 10, UI.GOOD))
	var d := UI.label(Game.Ach.desc(id), 11, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var looks: Array = Game.Looks.earned_by(id)
	if not looks.is_empty():
		var c: Color = Game.Looks.colors(str(looks[0]))[2]
		v.add_child(UI.label(Game.t("Look: ", "ظاهر: ") + Game.Looks.title(str(looks[0])), 10, c.lightened(0.3) if got else Color(c, 0.6)))
	if not got:
		var pr: Array = Game.Ach.progress(id)
		if int(pr[1]) > 1:
			var bar := Bar.new()
			bar.custom_minimum_size = Vector2(0, 9)
			bar.fill = UI.GOLD
			bar.fill_hi = UI.GOLD_HI
			bar.trail = false
			bar.value = float(pr[0]) / float(pr[1])
			bar.text = Game.num("%d / %d" % [int(pr[0]), int(pr[1])])
			v.add_child(bar)
	else:
		p.modulate = Color(1, 1, 1)
	return p

# ---------------------------------------------------------------- looks (v0.20)
func _looks() -> void:
	var note := UI.label(Game.t("Looks are earned with achievements. A look recolours your hero's clothes; some add an aura, a trail of light or a crown. Tap one to wear it.",
		"ظاهرها با دستاوردها به دست می‌آیند. هر ظاهر رنگِ جامهٔ قهرمانت را عوض می‌کند و بعضی هاله، ردِ نور یا تاج هم دارند. برای پوشیدن رویش بزن."), 11, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	var sheet: String = hud.player.sheet if hud and hud.player else Game.cls + "_starter"
	for id in Game.Looks.ORDER:
		grid.add_child(_look_card(str(id), sheet))

func _look_card(id: String, sheet: String) -> Control:
	var open: bool = Game.Looks.unlocked(id)
	var worn: bool = Game.Looks.current() == id
	var tint: Color = Game.Looks.colors(id)[0]
	var card := PanelContainer.new()
	card.name = "Look_" + id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UI.box(Color(UI.INK2, 0.94 if open else 0.6), UI.GOLD_HI if worn else (Color(tint, 0.6) if open else Color(UI.GOLD, 0.15)), 2 if worn or open else 1, 10, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 74)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.clip_contents = true
	var ac: Color = Game.Looks.aura(id)
	stage.draw.connect(func():
		var c := Vector2(stage.size.x * 0.5, 66)
		if ac.a > 0.0 and open:
			stage.draw_texture_rect(Tex.glow(), Rect2(c - Vector2(30, 12), Vector2(60, 24)), false, Color(ac, 0.5))
		stage.draw_set_transform(c, 0.0, Vector2(1.0, 0.3))
		stage.draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.4))
		stage.draw_set_transform(Vector2.ZERO))
	v.add_child(stage)
	var spr := _figure(sheet, id, 0.42)
	spr.modulate = Color(1, 1, 1) if open else Color(0.45, 0.42, 0.4)
	stage.add_child(spr)
	stage.resized.connect(func(): spr.position = Vector2(stage.size.x * 0.5, 66))
	spr.position = Vector2(40, 66)
	if not open:
		var lk := UI.icon_rect("lock", 18, UI.MUTED)
		lk.position = Vector2(4, 4)
		stage.add_child(lk)
	var nl := UI.label(Game.Looks.title(id), 11, tint.lightened(0.35) if open else UI.MUTED)
	nl.add_theme_font_override("font", UI.font_bold)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nl)
	var sl := UI.label(Game.t("Wearing", "بر تن") if worn else (Game.t("Tap to wear", "بزن تا بپوشی") if open else Game.Looks.earn_text(id)), 9, UI.GOOD if worn else UI.MUTED)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	var b := Button.new()
	b.name = "Tap"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.disabled = not open or worn
	b.pressed.connect(func():
		if Game.Looks.wear(id):
			Sfx.play("equip")
			if hud and hud.player:
				hud.player.refresh_look()
			_show("hero"))
	card.add_child(b)
	return card

func _gear_card(kind: String, tier: int, nm: String, sub: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(UI.INK2, 0.9), Color(ItemIcon.rarity_color(kind, max(1, tier)), 0.55), 1, 10, 8))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var ic := ItemIcon.new()
	ic.setup(kind, max(1, tier))
	ic.dim = tier <= 0
	ic.custom_minimum_size = Vector2(48, 48)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var n := UI.label(nm, 13, ItemIcon.rarity_color(kind, tier).lightened(0.3) if tier > 0 and kind != "potion" else UI.CREAM)
	n.add_theme_font_override("font", UI.font_bold)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(n)
	v.add_child(UI.label(sub, 11, UI.MUTED))
	return p

func _stat(icon: String, col: Color, label: String, value: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(UI.icon_rect(icon, 18, col))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	h.add_child(v)
	v.add_child(UI.label(label, 11, UI.MUTED))
	var l := UI.label(value, 16, UI.CREAM)
	l.add_theme_font_override("font", UI.font_bold)
	v.add_child(l)
	return h

func _section(t: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UI.label(t, 14, UI.GOLD)
	l.add_theme_font_override("font", UI.font_bold)
	h.add_child(l)
	var line := ColorRect.new()
	line.color = Color(UI.GOLD, 0.25)
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(line)
	return h

func _line(icon: String, left: String, right: String, col := UI.GOLD) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(UI.icon_rect(icon, 16, col))
	var l := UI.label(left, 14, UI.CREAM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UI.label(right, 13, UI.MUTED))
	return h

# ---------------------------------------------------------------- skills (v0.6)
func _skills() -> void:
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 6)
	body.add_child(seg)
	for o in [["spells", "sparkles", Game.t("Spells", "جادوها")], ["talents", "crown", Game.t("Talents", "استعدادها") + ("  (%s)" % Game.num(Game.talent_points()) if Game.talent_points() > 0 else "")]]:
		var b := UI.button(o[2], o[1], sub == o[0], 38)
		b.name = "Sub_" + o[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			sub = o[0]
			_shown = ""
			Sfx.play("ui")
			_show("skills"))
		seg.add_child(b)
	if sub == "talents":
		_talents()
	else:
		_spells()

func _spells() -> void:
	# mana and potions
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	body.add_child(head)
	head.add_child(UI.icon_rect("droplets", 18, Color(0.5, 0.7, 1.0)))
	var ml := UI.label(Game.t("Mana %d / %d  ·  +%.1f a second" % [int(Game.mp), int(Game.max_mp()), Game.mp_regen()],
		"مانا %s / %s، +%s در ثانیه" % [Game.num(int(Game.mp)), Game.num(int(Game.max_mp())), Game.dec(Game.mp_regen())]), 13, UI.CREAM)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ml)
	head.add_child(UI.label(Game.t("Mana potions: ", "معجون مانا: ") + Game.num(int(Game.state.get("mana_potions", 0))), 12, UI.MUTED))
	# (v0.27, UX: "the page's main job, binding spells, is below the fold") the spells first
	var hint := UI.label(Game.t("Two buttons, any two spells: tap 1 or 2 to bind.", "دو دکمه برای دو جادویی که بخواهی: هر جادو را با زدنِ ۱ یا ۲ روی یکی از دو دکمه بگذار."), 12, UI.GOLD)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for id in Skills.ORDER:
		grid.add_child(_spell_card(id))
	# the ultimate
	var u := Skills.ult()
	var up := PanelContainer.new()
	up.add_theme_stylebox_override("panel", UI.box(Color(UI.INK2, 0.92), Color(u["col"], 0.7), 2, 10, 8))
	body.add_child(up)
	var uh := HBoxContainer.new()
	uh.add_theme_constant_override("separation", 10)
	up.add_child(uh)
	uh.add_child(_spell_tile(u["icon"], u["col"], true))
	var uv := VBoxContainer.new()
	uv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uv.add_theme_constant_override("separation", 2)
	uh.add_child(uv)
	var un := UI.label(Game.t("Ultimate · ", "ضربهٔ نهایی: ") + Skills.ult_name(), 14, u["col"].lightened(0.2))
	un.add_theme_font_override("font", UI.font_bold)
	uv.add_child(un)
	var ud := UI.label(Skills.ult_desc(), 11, UI.MUTED)
	ud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	uv.add_child(ud)
	var ub := Bar.new()
	ub.custom_minimum_size = Vector2(0, 10)
	ub.fill = u["col"]
	ub.fill_hi = Color(1, 1, 1)
	ub.trail = false
	ub.value = Game.ult() / 100.0
	uv.add_child(ub)
	# (v0.26) the calling's own move
	var sg: Dictionary = Skills.sig()
	var sp2 := PanelContainer.new()
	sp2.add_theme_stylebox_override("panel", UI.box(Color(UI.INK2, 0.92), Color(sg["col"], 0.7), 2, 10, 8))
	body.add_child(sp2)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 10)
	sp2.add_child(sh)
	sh.add_child(_spell_tile(sg["icon"], sg["col"], true))
	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_theme_constant_override("separation", 2)
	sh.add_child(sv)
	var sn := UI.label(Game.hero_path() + ": " + Skills.sig_name(), 14, (sg["col"] as Color).lightened(0.2))
	sn.add_theme_font_override("font", UI.font_bold)
	sv.add_child(sn)
	var sd := UI.label(Skills.sig_desc(), 11, UI.MUTED)
	sd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(sd)

func _spell_tile(icon: String, col: Color, on: bool) -> Control:
	var t := Control.new()
	t.custom_minimum_size = Vector2(44, 44)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.draw.connect(func():
		var c := t.size * 0.5
		t.draw_style_box(UI.box(Color(0.06, 0.045, 0.035, 0.95), Color(col, 0.9 if on else 0.3), 2, 10, 0), Rect2(Vector2.ZERO, t.size))
		t.draw_texture_rect(Tex.glow(), Rect2(c - Vector2(20, 20), Vector2(40, 40)), false, Color(col, 0.3 if on else 0.05))
		var ic := UI.icon(icon, 64, 2.2)
		if ic:
			t.draw_texture_rect(ic, Rect2(c - Vector2(13, 13), Vector2(26, 26)), false, Color(col.lightened(0.35), 1.0 if on else 0.4)))
	return t

func _spell_card(id: String) -> Control:
	var known := Skills.known(id)
	var col := Skills.spell_col(id)
	var sl: Array = Game.slots()
	var p := PanelContainer.new()
	p.name = "Spell_" + id
	var bound := sl.has(id)
	p.add_theme_stylebox_override("panel", UI.box(Color(UI.INK2, 0.9 if known else 0.6), Color(col, 0.75) if bound else Color(UI.GOLD, 0.2), 2 if bound else 1, 10, 7))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(_spell_tile(Skills.spell_icon(id), col, known))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var n := UI.label(Skills.spell_name(id), 13, col.lightened(0.3) if known else UI.MUTED)
	n.add_theme_font_override("font", UI.font_bold)
	v.add_child(n)
	var meta := Game.t("%d mana · %.1f s" % [Skills.cost(id), Skills.cooldown(id)], "%s مانا، %s ثانیه" % [Game.num(Skills.cost(id)), Game.dec(Skills.cooldown(id))])
	if not known:
		meta = Game.t("Jamshid's gift", "هدیهٔ جمشید") if Skills.is_gift(id) else Game.t("Unlocks at level ", "در سطح ") + Game.num(Skills.spell_level(id)) + Game.t("", " باز می‌شود")
	v.add_child(UI.label(meta, 11, Color(0.6, 0.75, 1.0) if known else UI.MUTED))
	var d := UI.label(Skills.spell_desc(id), 11, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	if known:
		var bx := HBoxContainer.new()
		bx.add_theme_constant_override("separation", 6)
		bx.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(bx)
		for i in 2:
			var on: bool = str(sl[i]) == id
			var b := UI.button(Game.num(i + 1), "", on, 44)
			b.name = "Bind%d_%s" % [i, id]
			b.custom_minimum_size = Vector2(44, 44)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.pressed.connect(func():
				Game.bind_slot(i, id)
				Sfx.play("ui")
				_show("skills"))
			bx.add_child(b)
	else:
		p.modulate.a = 0.75
	return p

func _talents() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	body.add_child(head)
	head.add_child(UI.icon_rect("star", 18, UI.GOLD_HI))
	var pts := Game.talent_points()
	var pl := UI.label(Game.t("Talent points: ", "امتیاز استعداد: ") + Game.num(pts), 15, UI.GOLD_HI if pts > 0 else UI.CREAM)
	pl.add_theme_font_override("font", UI.font_bold)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(pl)
	if Game.talent_spent() > 0:
		var rb := UI.button(Game.t("Reset", "بازنشانی"), "circle-minus", false, 34)
		rb.name = "TalentReset"
		rb.pressed.connect(func():
			Game.reset_talents()
			Sfx.play("ui")
			_show("skills"))
		head.add_child(rb)
	var note := UI.label(Game.t("One point per level. Tap a talent to learn a rank; resetting is free.", "هر سطح یک امتیاز. برای گرفتن یک رتبه روی استعداد بزن؛ بازنشانی رایگان است."), 11, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 8)
	body.add_child(cols)
	for tr in Skills.TREES:
		var col: Color = Skills.TREE_COL[tr]
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 6)
		cols.add_child(v)
		var th := HBoxContainer.new()
		th.add_theme_constant_override("separation", 6)
		th.add_child(UI.icon_rect(Skills.TREE_ICON[tr], 16, col))
		var tl := UI.label(Skills.tree_name(tr), 14, col)
		tl.add_theme_font_override("font", UI.font_bold)
		th.add_child(tl)
		v.add_child(th)
		for n in Skills.tree_nodes(tr):
			v.add_child(_talent_card(str(n["id"]), int(n.get("max", 1)), col))

func _talent_card(id: String, mx: int, col: Color) -> Control:
	var rank := Game.talent(id)
	var why := Game.talent_block(id)
	var lit := rank > 0
	# a panel that grows with its text, and an invisible button over it for the tap
	var card := PanelContainer.new()
	card.name = "Talent_" + id
	var open := why == ""
	card.add_theme_stylebox_override("panel", UI.box(Color(UI.INK2, 0.92 if open or lit else 0.6), Color(col, 0.85) if lit else (Color(UI.GOLD_HI, 0.55) if open else Color(UI.GOLD, 0.15)), 2 if lit or open else 1, 9, 7))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var n := UI.label(Skills.talent_name(id), 12, col.lightened(0.3) if lit or open else UI.MUTED)
	n.add_theme_font_override("font", UI.font_bold)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(n)
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(mx * 10 + 2, 12)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(func():
		for i in mx:
			var c := Vector2(6 + i * 10, 6)
			pips.draw_circle(c, 4.0, Color(0, 0, 0, 0.5))
			pips.draw_circle(c, 3.2, col if i < rank else Color(0.3, 0.25, 0.2)))
	top.add_child(pips)
	var d := UI.label(Skills.talent_desc(id), 10, UI.CREAM if lit or open else UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	if why != "" and rank < mx and why != Game.t("No points", "امتیاز نداری"):
		var w := UI.label(why, 10, Color(1, 0.62, 0.5))
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(w)
	var b := Button.new()
	b.name = "Tap"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.disabled = not open
	b.pressed.connect(func():
		if Game.learn_talent(id):
			Sfx.play("levelup", -8.0)
			_show("skills"))
	card.add_child(b)
	return card

# ---------------------------------------------------------------- map
func _map() -> void:
	var w = hud.player.world if hud and hud.player else null
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	body.add_child(head)
	head.add_child(UI.icon_rect("map-pin", 18, UI.GOLD_HI))
	var title := UI.label(Game.map_title(w.key) if w else "", 17, UI.GOLD_HI)
	title.add_theme_font_override("font", UI.display_font())
	head.add_child(title)
	var obj := UI.label(Game.objective(), 12, UI.MUTED)
	obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(obj)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	# this region, large
	var local := Control.new()
	local.custom_minimum_size = Vector2(150, 200)
	local.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	local.size_flags_stretch_ratio = 0.8
	local.draw.connect(func():
		local.draw_style_box(UI.box(Color(0.05, 0.035, 0.025, 0.9), Color(UI.GOLD, 0.5), 1, 10, 0), Rect2(Vector2.ZERO, local.size))
		if w:
			Minimap.draw_region(local, w, Rect2(Vector2(6, 6), local.size - Vector2(12, 12)), hud.player))
	row.add_child(local)
	var wm := WorldMap.new()
	wm.here = wm.region_of(str(w.key)) if w else ""
	wm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wm.size_flags_stretch_ratio = 1.3
	row.add_child(wm)
	# legend
	var lg := HBoxContainer.new()
	lg.add_theme_constant_override("separation", 14)
	body.add_child(lg)
	for e in [[Color(1, 1, 1), Game.t("You", "تو")], [Color(0.96, 0.83, 0.49), Game.t("Exits", "راه‌ها")], [Color(1, 0.86, 0.45), Game.t("Villagers", "مردم")], [Color(0.95, 0.3, 0.25), Game.t("Enemies", "دشمن‌ها")]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		var dot := ColorRect.new()
		dot.color = e[0]
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(dot)
		h.add_child(UI.label(e[1], 11, UI.MUTED))
		lg.add_child(h)

# ---------------------------------------------------------------- settings
func _settings() -> void:
	var on_off := [[true, Game.t("On", "روشن")], [false, Game.t("Off", "خاموش")]]
	body.add_child(_section(Game.t("Display", "نمایش")))
	body.add_child(_choice("languages", Game.t("Language", "زبان"), [["fa", "فارسی"], ["en", "English"]], Game.lang, func(v): _set_lang(v)))
	body.add_child(_choice("user", Game.t("Interface size", "اندازهٔ رابط"), [[0, Game.t("Small", "کوچک")], [1, Game.t("Normal", "معمولی")], [2, Game.t("Large", "بزرگ")]], int(Game.settings["ui"]), func(v): Game.set_setting("ui", v)))
	body.add_child(_choice("zoom-in", Game.t("Camera", "دوربین"), [[0, Game.t("Far", "دور")], [1, Game.t("Normal", "معمولی")], [2, Game.t("Near", "نزدیک")]], int(Game.settings.get("cam", 1)), func(v): Game.set_setting("cam", v)))
	body.add_child(_choice("sparkles", Game.t("Graphics", "گرافیک"), [[1, Game.t("Full", "کامل")], [0, Game.t("Light", "سبک")]], int(Game.settings.get("fx", 1)), func(v): Game.set_setting("fx", v)))
	var levels := [[0, Game.t("Normal", "معمولی")], [1, Game.t("Bright", "روشن")], [2, Game.t("Brightest", "خیلی روشن")]]
	body.add_child(_choice("sun", Game.t("Brightness", "روشنایی"), levels, int(Game.settings.get("bright", 0)), func(v): Game.set_setting("bright", v)))
	body.add_child(_choice("user", Game.t("Left-handed controls", "کنترل چپ‌دست"), on_off, bool(Game.settings.get("left_hand", false)), func(v): Game.set_setting("left_hand", v)))
	body.add_child(_section(Game.t("Difficulty", "درجهٔ سختی")))
	var diffs := []
	for id in ["story", "normal", "hard", "nightmare"]:
		diffs.append([id, Game.diff_name(id)])
	body.add_child(_choice("skull", Game.t("Foes", "دشمنان"), diffs, Game.diff(), func(v): Game.set_setting("diff", v)))
	var dn := UI.label(Game.t("Story: gentler foes, for the tale. Harder foes have more health and hit harder, and give more XP and gold. It changes at once for damage taken and for foes you meet from now on.",
		"داستانی: دشمنانِ نرم‌تر، برای خودِ داستان. دشمنان سخت‌تر جان بیشتر دارند و محکم‌تر می‌زنند، و تجربه و سکهٔ بیشتری می‌دهند. آسیبی که می‌خوری همین الان و دشمنانی که از این پس می‌بینی تغییر می‌کنند."), 11, UI.MUTED)
	dn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(dn)
	body.add_child(_section(Game.t("Sound and feel", "صدا و حس")))
	body.add_child(_choice("volume-2", Game.t("Sound", "صدا"), on_off, Game.settings["sound"], func(v): Game.set_setting("sound", v)))
	body.add_child(_choice("music", Game.t("Music", "موسیقی"), on_off, Game.settings.get("music", true), func(v): Game.set_setting("music", v)))
	var vols := [[0, Game.t("Quiet", "آرام")], [1, Game.t("Normal", "معمولی")], [2, Game.t("Loud", "بلند")]]
	body.add_child(_choice("music", Game.t("Music volume", "بلندی موسیقی"), vols, int(Game.settings.get("mvol", 1)), func(v): Game.set_setting("mvol", v)))
	body.add_child(_choice("volume-2", Game.t("Sound volume", "بلندی صداها"), vols, int(Game.settings.get("svol", 1)), func(v):
		Game.set_setting("svol", v)
		Sfx.play("hit")))
	body.add_child(_choice("vibrate", Game.t("Vibration", "لرزش گوشی"), on_off, Game.settings.get("haptics", true), func(v): Game.set_setting("haptics", v)))
	body.add_child(_choice("zap", Game.t("Screen shake", "لرزش صفحه"), on_off, Game.settings["shake"], func(v): Game.set_setting("shake", v)))
	body.add_child(_choice("navigation", Game.t("Quest arrow", "پیکان مأموریت"), [[1, Game.t("On", "روشن")], [0, Game.t("Off", "خاموش")]], int(Game.settings.get("compass", 1)), func(v): Game.set_setting("compass", v)))
	if int(Game.settings.get("fx", 1)) == 0:
		var note := UI.label(Game.t("Light graphics: no dynamic light, weather or ambient particles — for older phones.",
			"گرافیک سبک: بدون نور پویا، آب‌وهوا و ذرات محیط — برای گوشی‌های قدیمی‌تر."), 11, UI.MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(note)
	body.add_child(_section(Game.t("How to play", "راهنمای بازی")))
	var move_hint := Game.t("Drag anywhere on the left half to move.", "برای حرکت، هر جای نیمهٔ چپ صفحه را بکش.")
	if bool(Game.settings.get("left_hand", false)):
		move_hint = Game.t("Drag anywhere on the right half to move.", "برای حرکت، هر جای نیمهٔ راست صفحه را بکش.")
	var help := [
		["footprints", move_hint],
		["sword", Game.t("Tap Attack to strike; hold it for a heavy blow.", "برای ضربه حمله را بزن؛ نگه داری ضربهٔ سنگین می‌زنی.")],
		["wind", Game.t("Roll through attacks — right as they land is a perfect dodge.", "از میان حمله‌ها غلت بزن — درست لحظهٔ فرود، جاخالیِ بی‌نقص است.")],
		["skull", Game.t("Bosses telegraph every attack on the ground. Fill their stagger bar.", "سرکرده‌ها هر حمله را روی زمین نشان می‌دهند. نوار گیجی‌شان را پر کن.")],
		["sparkles", Game.t("The two spell buttons cast the spells you bind in Menu → Skills. Out of mana, a mana potion is drunk for you.", "دو دکمهٔ جادو، جادوهایی را می‌زنند که در فهرست ← مهارت‌ها بسته‌ای. اگر مانا تمام شود، معجون مانا خودکار نوشیده می‌شود.")],
		[str(Game.Skills.ult()["icon"]), Game.t("Fighting fills the ultimate button (top right, a ring fills round it): when it glows, unleash your calling's ultimate.",
			"جنگیدن دکمهٔ ضربهٔ نهایی را پر می‌کند (بالا سمت راست؛ حلقه‌ای دورش پر می‌شود): وقتی درخشید، ضربهٔ نهاییِ راهت را رها کن.")],
		["crown", Game.t("Every level gives a talent point — spend it in Menu → Skills → Talents.", "هر سطح یک امتیاز استعداد می‌دهد — در فهرست ← مهارت‌ها ← استعدادها خرجش کن.")],
		["navigation", Game.t("The gold arrow by your hero points to your next goal; tap the minimap for the full map.", "پیکان طلایی کنار قهرمان، هدف بعدی را نشان می‌دهد؛ برای نقشهٔ کامل روی نقشهٔ کوچک بزن.")],
	]
	for hl in help:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(UI.icon_rect(hl[0], 16, UI.GOLD))
		var l := UI.label(hl[1], 13, UI.CREAM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		body.add_child(h)
	body.add_child(_section(Game.t("Credits", "سازندگان")))
	body.add_child(Credits.build())

func _set_lang(v: String) -> void:
	Game.set_lang(v)
	_build_nav()
	_show("settings")

## a row: icon, name, and a segmented choice
func _choice(icon: String, label: String, opts: Array, current, on_pick: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(UI.icon_rect(icon, 18, UI.GOLD))
	var l := UI.label(label, 14, UI.CREAM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 4)
	h.add_child(seg)
	for o in opts:
		var b := UI.button(str(o[1]), "", o[0] == current, 38)
		b.custom_minimum_size.x = 74
		b.pressed.connect(_pick.bind(on_pick, o[0]))
		seg.add_child(b)
	return h

func _pick(on_pick: Callable, v) -> void:
	on_pick.call(v)
	_show(tab)


# ---------------------------------------------------------------- gear (v0.10): four slots, the bag, selling
func _gear() -> void:
	var Gear = Game.Gear
	body.add_child(_section(Game.t("Worn", "پوشیده")))
	for slot in Gear.SLOTS:
		var it = Gear.eq().get(slot, null)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UI.icon_rect(Gear.SLOT_ICON[slot], 18, UI.GOLD if it != null else UI.MUTED))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", -2)
		row.add_child(v)
		var sn: Array = Gear.SLOT_NAME[slot]
		if it == null:
			v.add_child(UI.label(Game.t(sn[0], sn[1]) + "  —  " + Game.t("empty", "خالی"), 13, UI.MUTED))
		else:
			var nm := UI.label(Gear.item_name(it), 14, Gear.rarity_col(it))
			nm.add_theme_font_override("font", UI.font_bold)
			v.add_child(nm)
			var sub := Gear.stat_label(it)
			var d: String = Gear.desc_of(it)
			v.add_child(UI.label(sub + ("  •  " + d if d != "" else ""), 11, UI.MUTED))
			var b := UI.button(Game.t("Remove", "درآوردن"), "", false, 32)
			b.name = "Unequip_" + slot
			b.pressed.connect(func():
				Gear.unequip(slot)
				Sfx.play("ui")
				_show("gear"))
			row.add_child(b)
		body.add_child(row)
	body.add_child(_section(Game.t("Bag", "کوله") + "  (%s)" % Game.num(Gear.bag().size())))
	if Gear.bag().is_empty():
		body.add_child(UI.label(Game.t("Empty. Elites and bosses drop accessories.", "خالی است. هیولاها و غول‌های نخبه آیتم می‌اندازند."), 12, UI.MUTED))
	var bag: Array = Gear.bag()
	for i in bag.size():
		var it: Dictionary = bag[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(UI.icon_rect(Gear.SLOT_ICON[str(it["slot"])], 16, Gear.rarity_col(it)))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", -2)
		row.add_child(v)
		v.add_child(UI.label(Gear.item_name(it), 13, Gear.rarity_col(it)))
		v.add_child(UI.label(Gear.stat_label(it), 11, UI.MUTED))
		var eb := UI.button(Game.t("Wear", "بپوش"), "", true, 32)
		eb.name = "Wear_%d" % i
		eb.pressed.connect(func():
			Gear.equip(i)
			Sfx.play("equip")
			_show("gear"))
		row.add_child(eb)
		var g: int = int(Gear.SELL.get(str(it.get("rarity", "common")), 8))
		var sb := UI.button(Game.t("Sell", "فروش") + " %s" % Game.num(g), "", false, 32)
		sb.name = "Sell_%d" % i
		sb.pressed.connect(func():
			Gear.sell(i)
			Sfx.play("coin")
			_show("gear"))
		row.add_child(sb)
		body.add_child(row)

	# (v0.11) materials and scrolls: the scroll button casts the one marked Ready
	body.add_child(_section(Game.t("Materials", "مواد")))
	body.add_child(UI.label(Game.t("Bogbloom", "گلِ مرداب") + " %s" % Game.num(Game.herbs()) + Game.sep(true) + Game.t("Essence", "عصاره") + " %s" % Game.num(Game.essence()) + Game.sep(true) + Game.t("Obsidian", "شَبَه") + " %s" % Game.num(int(Game.state.get("obsidian", 0))), 13, UI.CREAM))
	body.add_child(_section(Game.t("Scrolls", "طومارها")))
	var any := false
	for sid in Game.SCROLL_IDS:
		var n := Game.scroll_count(sid)
		if n <= 0:
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UI.icon_rect("scroll-text", 18, Color(0.7, 0.8, 1.0)))
		var lbl := UI.label("%s  ×%s" % [Game.scroll_name(sid), Game.num(n)], 14, UI.CREAM)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var ready: bool = Game.scroll_sel() == sid
		var rb := UI.button(Game.t("Ready", "آماده") if ready else Game.t("Choose", "انتخاب"), "", not ready, 32)
		rb.name = "Scroll_" + sid
		rb.disabled = ready
		rb.pressed.connect(func():
			Game.state["scroll_sel"] = sid
			Sfx.play("ui")
			_show("gear"))
		row.add_child(rb)
		body.add_child(row)
	if not any:
		body.add_child(UI.label(Game.t("No scrolls. Rudabeh brews them from Bogbloom and essence.", "طومار نداری. رودابه آن‌ها را از گلِ مرداب و عصاره دم می‌کند."), 12, UI.MUTED))

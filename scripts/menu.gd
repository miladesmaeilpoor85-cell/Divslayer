extends Control
## Title screen over the living village (main.gd pans a camera across it): the logo, Continue (with the
## saved hero's class, level and place), New game -> choose a path (four illustrated class cards with
## stat bars), Settings, language. Emits start_game(class, continue_save).

signal start_game(cls: String, continue_save: bool)

const Sheets = preload("res://scripts/sheets.gd")
const Bar = preload("res://scripts/ui/bar.gd")
const Tex = preload("res://scripts/fx/tex.gd")
const ORDER := ["warrior", "mage", "rogue", "paladin"]
const CARDS := {
	# (v0.24) the Ember-bearer's four callings, each the way of one of the Shahnameh's heroes (Game.HEROES)
	"warrior": ["Pahlavan", "پهلوان", "The way of Rostam: the most health and the hardest blows.", "راهِ رستم: بیشترین جان و سنگین‌ترین ضربه‌ها.", "swords", Color(0.85, 0.36, 0.26)],
	"mage": ["Sage", "فرزانه", "The way of Zal and the Simorgh: fragile; spells cost half and hit hardest.", "راهِ زال و دانشِ سیمرغ: تنی شکننده، جادوهایی ارزان و کاری.", "sparkles", Color(0.36, 0.55, 0.95)],
	"rogue": ["Ayyar", "عیّار", "The way of Gordafarid: fast, the longest dodge, the most critical hits.", "راهِ گردآفرید: چابک، با بلندترین جاخالی و بیشترین ضربهٔ کاری.", "footprints", Color(0.3, 0.75, 0.55)],
	"paladin": ["Oathbearer", "سوگندوَر", "The way of Siavash, who rode through fire unharmed: the strongest armour, steady and safe.", "راهِ سیاوش که بی‌گزند از آتش گذشت: قوی‌ترین زره، محکم و مطمئن.", "shield", Color(0.92, 0.75, 0.3)],
}

var view := "title"
var picked := "warrior"
var content: Control
var _anim_t := 0.0
var _card_faces := {}
var _embers: CPUParticles2D
var _logo: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Game.lang_changed.connect(_build)

func _build() -> void:
	for c in get_children():
		c.queue_free()
	_card_faces.clear()
	layout_direction = Control.LAYOUT_DIRECTION_RTL if Game.lang == "fa" else Control.LAYOUT_DIRECTION_LTR
	# darken the village behind: strongest where the text sits
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.02, 0.015, 0.97))
	g.set_color(1, Color(0.03, 0.02, 0.015, 0.45))
	g.add_point(0.45, Color(0.03, 0.02, 0.015, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 8
	gt.fill_from = Vector2(1, 0) if Game.lang == "fa" else Vector2(0, 0)
	gt.fill_to = Vector2(0, 0) if Game.lang == "fa" else Vector2(1, 0)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	if view == "classes":
		var dim := ColorRect.new()
		dim.color = Color(0.03, 0.02, 0.015, 0.55)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
	# embers rising from the bottom of the screen, as from a forge below
	_embers = CPUParticles2D.new()
	_embers.local_coords = true
	_embers.amount = 36
	_embers.lifetime = 7.0
	_embers.preprocess = 6.0
	_embers.texture = Tex.dot()
	_embers.material = Tex.add_material()
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(500, 6)
	_embers.direction = Vector2(0.15, -1)
	_embers.spread = 18.0
	_embers.gravity = Vector2(6, -6)
	_embers.initial_velocity_min = 22.0
	_embers.initial_velocity_max = 60.0
	_embers.scale_amount_min = 0.08
	_embers.scale_amount_max = 0.2
	_embers.color = Color(1, 0.62, 0.25, 0.85)
	_embers.color_ramp = Tex.pulse_ramp()
	add_child(_embers)
	var ver := UI.label(Game.t("v", "نسخهٔ ") + Game.num(Game.VERSION), 10, Color(UI.MUTED, 0.7))
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_top = -20
	ver.offset_left = 12
	ver.offset_right = 160
	add_child(ver)
	match view:
		"classes": _classes()
		"settings": _settings()
		_: _title()

func _go(v: String) -> void:
	view = v
	Sfx.play("ui", -4.0)
	_build()

# ---------------------------------------------------------------- title
func _title() -> void:
	var col := VBoxContainer.new()
	col.anchor_top = 0.0
	col.anchor_bottom = 1.0
	col.anchor_left = 0.0
	col.anchor_right = 0.0
	col.offset_left = 48
	col.offset_right = 48 + 330
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	add_child(col)       # in Persian the RTL layout mirrors it to the right
	var big := UI.label(Game.t("Divslayer", "دیوکُش"), 46, UI.GOLD_HI, 8)
	_logo = big
	big.add_theme_font_override("font", UI.display_font())
	big.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.04, 0.95))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(big)
	var sub := UI.label(Game.t("دیوکُش", "DIVSLAYER"), 15, UI.GOLD, 3)
	sub.add_theme_font_override("font", UI.font_display_en if Game.lang == "fa" else UI.font_bold)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var orn := Control.new()
	orn.custom_minimum_size = Vector2(0, 14)
	orn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orn.draw.connect(func(): _orn(orn))
	col.add_child(orn)
	var tag := UI.label(Game.t("An epic from Zabol to Damavand", "حماسه‌ای از زابل تا دماوند"), 13, UI.CREAM, 3)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	col.add_child(gap)
	if Game.has_save():
		var cont := UI.button("", "play", true, 58)
		cont.name = "Continue"
		cont.pressed.connect(func(): start_game.emit("", true))
		var cv := VBoxContainer.new()
		cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", -2)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cont.add_child(cv)
		var cl := UI.label(Game.t("Continue", "ادامه"), 17, Color(0.14, 0.09, 0.05))
		cl.add_theme_font_override("font", UI.font_bold)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(cl)
		var il := UI.label(_save_info(), 11, Color(0.25, 0.16, 0.08))
		il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(il)
		col.add_child(cont)
	var newg := UI.button(Game.t("New game", "بازی تازه"), "sparkles", not Game.has_save(), 46)
	newg.name = "NewGame"
	newg.pressed.connect(_go.bind("classes"))
	col.add_child(newg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var st := UI.button(Game.t("Settings", "تنظیمات"), "settings", false, 42)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.pressed.connect(_go.bind("settings"))
	row.add_child(st)
	var lang := UI.button("English" if Game.lang == "fa" else "فارسی", "languages", false, 42)
	lang.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang.pressed.connect(func(): Game.set_lang("en" if Game.lang == "fa" else "fa"))
	row.add_child(lang)

## (v0.27) Android Back: from a sub-page back to the title; on the title it is not handled (the game quits)
func back() -> bool:
	if view == "title":
		return false
	_go("title")
	return true

func _save_info() -> String:
	var d = Game.read_safe(Game.SAVE_PATH)
	if typeof(d) != TYPE_DICTIONARY or not d.has("state"):
		return ""
	var c: String = str(d.get("cls", "warrior"))
	var cname: String = CARDS.get(c, CARDS["warrior"])[1 if Game.lang == "fa" else 0]
	var where := Game.map_title(str(d["state"].get("map", "village")))
	return cname + Game.sep() + "%s %s" % [Game.t("Level", "سطح"), Game.num(int(d["state"].get("level", 1)))] + Game.sep() + where

func _orn(c: Control) -> void:
	var mid := Vector2(c.size.x * 0.5, 7)
	for i in 12:
		var a := 1.0 - float(i) / 12.0
		var x0 := 120.0 * float(i) / 12.0
		var x1 := 120.0 * float(i + 1) / 12.0
		c.draw_line(mid + Vector2(9 + x0, 0), mid + Vector2(9 + x1, 0), Color(UI.GOLD, a), 1.5)
		c.draw_line(mid - Vector2(9 + x0, 0), mid - Vector2(9 + x1, 0), Color(UI.GOLD, a), 1.5)
	c.draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -5), mid + Vector2(5, 0), mid + Vector2(0, 5), mid + Vector2(-5, 0)]), UI.GOLD_HI)

# ---------------------------------------------------------------- choose your path
func _classes() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 20
	v.offset_right = -20
	v.offset_top = 14
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(UI.title(Game.t("You are no hero — choose your calling", "قهرمان نیستی؛ فقط اخگر به دستت افتاده — راهت را برگزین"), 24))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	var mx := {"hp": 0.0, "atk": 0.0, "def": 0.0, "speed": 0.0, "mp": 0.0}
	for c in ORDER:
		var d: Dictionary = Game.table("CLASSES").get(c, {})
		for k in mx:
			mx[k] = max(float(mx[k]), float(d.get(k, 0)))
	for c in ORDER:
		row.add_child(_card(c, mx))
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 12)
	v.add_child(foot)
	var back := UI.button(Game.t("Back", "بازگشت"), "chevron-right" if Game.lang == "fa" else "chevron-left", false, 46)
	back.custom_minimum_size.x = 140
	back.pressed.connect(_go.bind("title"))
	foot.add_child(back)
	var warn := Game.has_save()
	var go := UI.button((Game.t("Replace saved hero & begin", "آغاز — قهرمانِ پیشین پاک می‌شود") if warn else Game.t("Begin the adventure", "آغاز ماجرا")), "play", true, 46)
	go.name = "Begin"
	go.custom_minimum_size.x = 240
	go.pressed.connect(func(): start_game.emit(picked, false))
	foot.add_child(go)

func _card(c: String, mx: Dictionary) -> Control:
	var info: Array = CARDS[c]
	var d: Dictionary = Game.table("CLASSES").get(c, {})
	var sel := c == picked
	var b := Button.new()
	b.name = "Card_" + c
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(186, 0)
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var accent: Color = info[5]
	b.add_theme_stylebox_override("normal", UI.box(Color(UI.INK, 0.94), accent if sel else UI.GOLD_DIM, 3 if sel else 2, 14, 10, 8 if sel else 0))
	b.add_theme_stylebox_override("hover", UI.box(Color(UI.INK2, 0.96), accent, 3 if sel else 2, 14, 10))
	b.add_theme_stylebox_override("pressed", UI.box(Color(UI.INK2, 1), accent, 3, 14, 10))
	b.pressed.connect(_pick.bind(c))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 8
	v.offset_bottom = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var face := TextureRect.new()
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(0, 70)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(face)
	_card_faces[c] = face
	var nh := HBoxContainer.new()
	nh.alignment = BoxContainer.ALIGNMENT_CENTER
	nh.add_theme_constant_override("separation", 6)
	nh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nh)
	nh.add_child(UI.icon_rect(info[4], 18, accent))
	var n := UI.label(info[1] if Game.lang == "fa" else info[0], 19, UI.GOLD_HI if sel else UI.CREAM)
	n.add_theme_font_override("font", UI.display_font())
	nh.add_child(n)
	var role := UI.label("", 11, accent.lightened(0.25))
	role.visible = false              # (v0.27, UX) the heading already says "Ember-bearer", in both languages
	role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nh.add_child(role)
	# (v0.27, UX: "the one screen with a permanent choice is the hardest to read") larger, lighter, the same height on
	# every card so the names and bars line up
	var desc := UI.label(info[3] if Game.lang == "fa" else info[2], 11, Color(UI.CREAM, 0.82))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(160, 46)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	v.add_child(desc)
	for s in [["heart", "hp", UI.HP], ["sword", "atk", UI.GOLD_HI], ["shield", "def", Color(0.62, 0.78, 0.95)], ["droplets", "mp", Color(0.4, 0.6, 1.0)], ["footprints", "speed", UI.STAM]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(UI.icon_rect(s[0], 11, s[2]))
		var bar := Bar.new()
		bar.custom_minimum_size = Vector2(0, 5)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.fill = s[2]
		bar.fill_hi = s[2].lightened(0.3)
		bar.trail = false
		bar.radius = 3.0
		bar.value = float(d.get(s[1], 0)) / max(0.01, float(mx[s[1]]))
		h.add_child(bar)
		v.add_child(h)
	# (v0.26, the critic: "the cards name the final blows, not the four new moves") the calling's own move, from the first minute
	var sg: Dictionary = preload("res://scripts/skills.gd").SIG[c]
	var sh := HBoxContainer.new()
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.add_theme_constant_override("separation", 5)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.add_child(UI.icon_rect(sg["icon"], 13, sg["col"]))
	var sl := UI.label(Game.t(sg["name"][0], sg["name"][1]), 11, Color(sg["col"]).lightened(0.2))
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.add_child(sl)
	v.add_child(sh)
	# the class's ultimate (v0.6)
	var u: Dictionary = preload("res://scripts/skills.gd").ult(c)
	var uh := HBoxContainer.new()
	uh.alignment = BoxContainer.ALIGNMENT_CENTER
	uh.add_theme_constant_override("separation", 5)
	uh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	uh.add_child(UI.icon_rect(u["icon"], 13, u["col"]))
	var ul := UI.label(Game.t(u["name"][0], u["name"][1]), 11, u["col"].lightened(0.2))
	ul.mouse_filter = Control.MOUSE_FILTER_IGNORE
	uh.add_child(ul)
	v.add_child(uh)
	return b

func _pick(c: String) -> void:
	picked = c
	Sfx.play("ui", -4.0)
	_build()

func _process(dt: float) -> void:
	if _embers and is_instance_valid(_embers):
		_embers.position = Vector2(size.x * 0.5, size.y + 8)
		_embers.emission_rect_extents = Vector2(size.x * 0.5, 6)
	if _logo and is_instance_valid(_logo):
		# the title glows like iron in a forge
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 900.0)
		_logo.modulate = Color(1.0 + 0.12 * k, 1.0 + 0.06 * k, 1.0)
	if _card_faces.is_empty():
		return
	_anim_t += dt
	for c in _card_faces:
		var ch: Dictionary = Sheets.character("heroes", c + "_mid")
		if ch.is_empty():
			continue
		var anim := "walk_down" if c == picked else "idle_down"
		var sf: SpriteFrames = ch["frames"]
		var n := sf.get_frame_count(anim)
		_card_faces[c].texture = sf.get_frame_texture(anim, int(_anim_t * 7.0) % max(1, n))

# ---------------------------------------------------------------- settings
func _settings() -> void:
	var p := PanelContainer.new()
	p.anchor_left = 0.14
	p.anchor_right = 0.86
	p.anchor_top = 0.06
	p.anchor_bottom = 0.94
	add_child(p)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	p.add_child(outer)
	outer.add_child(UI.title(Game.t("Settings", "تنظیمات"), 24))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	var on_off := [[true, Game.t("On", "روشن")], [false, Game.t("Off", "خاموش")]]
	v.add_child(_row("volume-2", Game.t("Sound", "صدا"), "sound", on_off))
	v.add_child(_row("music", Game.t("Music", "موسیقی"), "music", on_off))
	var vols := [[0, Game.t("Quiet", "آرام")], [1, Game.t("Normal", "معمولی")], [2, Game.t("Loud", "بلند")]]
	v.add_child(_row("music", Game.t("Music volume", "بلندی موسیقی"), "mvol", vols))
	v.add_child(_row("volume-2", Game.t("Sound volume", "بلندی صداها"), "svol", vols))
	v.add_child(_row("vibrate", Game.t("Vibration", "لرزش گوشی"), "haptics", on_off))
	v.add_child(_row("zap", Game.t("Screen shake", "لرزش صفحه"), "shake", on_off))
	v.add_child(_row("user", Game.t("Interface size", "اندازهٔ رابط"), "ui", [[0, Game.t("Small", "کوچک")], [1, Game.t("Normal", "معمولی")], [2, Game.t("Large", "بزرگ")]]))
	v.add_child(_row("user", Game.t("Left-handed controls", "کنترل چپ‌دست"), "left_hand", on_off))
	v.add_child(_row("zoom-in", Game.t("Camera", "دوربین"), "cam", [[0, Game.t("Far", "دور")], [1, Game.t("Normal", "معمولی")], [2, Game.t("Near", "نزدیک")]]))
	v.add_child(_row("sparkles", Game.t("Graphics", "گرافیک"), "fx", [[1, Game.t("Full", "کامل")], [0, Game.t("Light", "سبک")]]))
	v.add_child(_row("sun", Game.t("Brightness", "روشنایی"), "bright", [[0, Game.t("Normal", "معمولی")], [1, Game.t("Bright", "روشن")], [2, Game.t("Brightest", "خیلی روشن")]]))
	var ct := UI.label(Game.t("Credits", "سازندگان"), 14, UI.GOLD)
	ct.add_theme_font_override("font", UI.font_bold)
	v.add_child(ct)
	v.add_child(preload("res://scripts/ui/credits.gd").build())
	var back := UI.button(Game.t("Back", "بازگشت"), "check", true, 46)
	back.pressed.connect(_go.bind("title"))
	outer.add_child(back)

func _row(icon: String, label: String, key: String, opts: Array) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(UI.icon_rect(icon, 18, UI.GOLD))
	var l := UI.label(label, 15, UI.CREAM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	for o in opts:
		var b := UI.button(str(o[1]), "", o[0] == Game.settings.get(key), 40)
		b.custom_minimum_size.x = 80
		b.pressed.connect(_apply.bind(key, o[0]))
		h.add_child(b)
	return h

func _apply(key: String, v) -> void:
	Game.set_setting(key, v)
	_build()

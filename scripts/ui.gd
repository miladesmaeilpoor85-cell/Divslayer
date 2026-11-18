extends Node
## Ember & Iron's UI kit (autoload "UI"): the palette, fonts and the global Theme that every panel and
## button uses (dark wood, gold trim — the HTML edition's look), line icons rendered at runtime from
## Lucide SVG paths (data/icons.json: ~8 KB for the whole set, sharp at any size) and small factories.

# ---------------------------------------------------------------- palette
const INK := Color(0.105, 0.078, 0.062)        # panel background
const INK2 := Color(0.16, 0.12, 0.094)         # raised surfaces, buttons
const INK3 := Color(0.22, 0.165, 0.125)        # hover
const GOLD := Color(0.79, 0.64, 0.29)          # trim
const GOLD_HI := Color(0.97, 0.83, 0.48)       # highlights, titles
const GOLD_DIM := Color(0.48, 0.38, 0.19)      # quiet borders
const CREAM := Color(0.95, 0.91, 0.82)         # body text
const MUTED := Color(0.68, 0.62, 0.53)         # secondary text
const HP := Color(0.83, 0.25, 0.2)
const HP_HI := Color(0.97, 0.45, 0.35)
const STAM := Color(0.44, 0.8, 0.5)
const XP := Color(0.42, 0.76, 0.92)
const GOOD := Color(0.55, 0.9, 0.5)
const BAD := Color(1.0, 0.45, 0.4)
const SHADOW := Color(0, 0, 0, 0.55)

var theme: Theme
var font_body: Font
var font_bold: Font
var font_display_en: Font
var _icons := {}
var _icon_tex := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fonts()
	_icons = _read_icons()
	theme = _build_theme()
	# a theme set on a Window or Control does not reach Controls under a CanvasLayer (the HUD, menus),
	# so the kit is merged into the engine's default theme: every Control in the game uses it
	ThemeDB.get_default_theme().merge_with(theme)
	get_tree().root.theme = theme

# ---------------------------------------------------------------- fonts
func _fonts() -> void:
	var latin = load("res://assets/fonts/vazir_latin.woff2")
	var arabic = load("res://assets/fonts/vazir_arabic.woff2")
	var latin_b = load("res://assets/fonts/vazir_latin_bold.woff2")
	var arabic_b = load("res://assets/fonts/vazir_arabic_bold.woff2")
	if latin is FontFile and arabic is FontFile:
		var fb: Array[Font] = [arabic]
		latin.fallbacks = fb
		font_body = latin
	if latin_b is FontFile and arabic_b is FontFile:
		var fbb: Array[Font] = [arabic_b]
		latin_b.fallbacks = fbb
		font_bold = latin_b
	var cz = load("res://assets/fonts/cinzel.woff2")
	if cz is FontFile:
		var v := FontVariation.new()
		v.base_font = cz
		v.variation_opentype = {"wght": 700}
		var fbd: Array[Font] = [font_bold if font_bold else font_body]
		v.fallbacks = fbd
		font_display_en = v
	if font_body:
		ThemeDB.fallback_font = font_body
		ThemeDB.fallback_font_size = 14

## headings: Cinzel in English (the HTML edition's titles), Vazirmatn Bold in Persian
func display_font() -> Font:
	if Game.lang != "fa" and font_display_en:
		return font_display_en
	return font_bold if font_bold else font_body

# ---------------------------------------------------------------- theme
func box(bg: Color, border: Color, bw := 2.0, radius := 12.0, margin := 12.0, shadow := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(int(bw))
	sb.set_corner_radius_all(int(radius))
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.6
	sb.content_margin_bottom = margin * 0.6
	sb.anti_aliasing = true
	if shadow > 0.0:
		sb.shadow_color = SHADOW
		sb.shadow_size = int(shadow)
		sb.shadow_offset = Vector2(0, 3)
	return sb

func _build_theme() -> Theme:
	var t := Theme.new()
	if font_body:
		t.default_font = font_body
	t.default_font_size = 14
	# panels
	t.set_stylebox("panel", "PanelContainer", box(Color(INK, 0.96), GOLD, 2, 14, 16, 10))
	t.set_stylebox("panel", "Panel", box(Color(INK, 0.96), GOLD, 2, 14, 16, 10))
	# buttons
	t.set_stylebox("normal", "Button", box(Color(INK2, 0.96), GOLD_DIM, 2, 10, 14))
	t.set_stylebox("hover", "Button", box(Color(INK3, 0.98), GOLD, 2, 10, 14))
	t.set_stylebox("pressed", "Button", box(Color(0.09, 0.065, 0.05, 1), GOLD_HI, 2, 10, 14))
	t.set_stylebox("disabled", "Button", box(Color(INK2, 0.6), Color(GOLD_DIM, 0.5), 2, 10, 14))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", GOLD_HI)
	t.set_color("font_pressed_color", "Button", GOLD_HI)
	t.set_color("font_focus_color", "Button", CREAM)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_color("icon_normal_color", "Button", GOLD)
	t.set_color("icon_hover_color", "Button", GOLD_HI)
	t.set_color("icon_pressed_color", "Button", GOLD_HI)
	t.set_constant("h_separation", "Button", 8)
	t.set_font_size("font_size", "Button", 15)
	# the gold call-to-action button
	t.add_type("PrimaryButton")
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", box(Color(0.83, 0.67, 0.32), GOLD_HI, 2, 10, 18, 6))
	t.set_stylebox("hover", "PrimaryButton", box(Color(0.92, 0.76, 0.4), Color(1, 0.92, 0.7), 2, 10, 18, 6))
	t.set_stylebox("pressed", "PrimaryButton", box(Color(0.7, 0.55, 0.24), GOLD_HI, 2, 10, 18, 2))
	t.set_color("font_color", "PrimaryButton", Color(0.14, 0.09, 0.05))
	t.set_color("font_hover_color", "PrimaryButton", Color(0.1, 0.06, 0.03))
	t.set_color("font_pressed_color", "PrimaryButton", Color(0.1, 0.06, 0.03))
	t.set_color("icon_normal_color", "PrimaryButton", Color(0.14, 0.09, 0.05))
	t.set_color("icon_hover_color", "PrimaryButton", Color(0.1, 0.06, 0.03))
	t.set_color("icon_pressed_color", "PrimaryButton", Color(0.1, 0.06, 0.03))
	# a flat icon-only button (close X, tabs)
	t.add_type("FlatButton")
	t.set_type_variation("FlatButton", "Button")
	for st in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(st, "FlatButton", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 10, 6))
	t.set_color("icon_normal_color", "FlatButton", MUTED)
	# labels
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "Label", 0)
	t.add_type("HudLabel")
	t.set_type_variation("HudLabel", "Label")
	t.set_constant("outline_size", "HudLabel", 4)
	t.add_type("TitleLabel")
	t.set_type_variation("TitleLabel", "Label")
	t.set_color("font_color", "TitleLabel", GOLD_HI)
	t.set_font_size("font_size", "TitleLabel", 22)
	t.add_type("MutedLabel")
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", MUTED)
	t.set_font_size("font_size", "MutedLabel", 12)
	# scrolling
	var grab := box(Color(GOLD, 0.55), Color(0, 0, 0, 0), 0, 4, 0)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(GOLD, Color(0, 0, 0, 0), 0, 4, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(GOLD_HI, Color(0, 0, 0, 0), 0, 4, 0))
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 0, 4, 0))
	return t

# ---------------------------------------------------------------- icons
func _read_icons() -> Dictionary:
	var p := "res://data/icons.json"
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if typeof(d) == TYPE_DICTIONARY else {}

func has_icon(icon_name: String) -> bool:
	return _icons.has(icon_name)

## a white line icon rendered at `px` pixels (tint it with modulate / icon colours); cached
func icon(icon_name: String, px := 48, stroke := 2.0) -> Texture2D:
	var key := "%s@%d/%s" % [icon_name, px, stroke]
	if _icon_tex.has(key):
		return _icon_tex[key]
	var body: String = _icons.get(icon_name, "")
	if body == "":
		return null
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [stroke, body]
	var img := Image.new()
	if img.load_svg_from_string(svg, px / 24.0) != OK:
		return null
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_icon_tex[key] = tex
	return tex

# ---------------------------------------------------------------- factories
func label(text := "", size := 14, col := CREAM, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func title(text := "", size := 22) -> Label:
	var l := label(text, size, GOLD_HI, 0)
	l.add_theme_font_override("font", display_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func icon_rect(icon_name: String, size := 20.0, col := GOLD) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = icon(icon_name, int(max(32.0, size * 3.0)))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(size, size)
	tr.modulate = col
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func button(text: String, icon_name := "", primary := false, min_h := 44.0) -> Button:
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = icon(icon_name, 60)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 20)
	if primary:
		b.theme_type_variation = "PrimaryButton"
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Sfx.play("ui", -4.0))
	return b

## a small rounded "chip": icon + value (gold, potions, statuses)
func chip(icon_name: String, col := GOLD) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon_rect(icon_name, 14, col))
	var l := label("", 12, CREAM, 3)
	l.name = "Value"
	h.add_child(l)
	return h

func rtl() -> bool:
	return Game.lang == "fa"

func dir_of(l: Control) -> void:
	l.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl() else Control.LAYOUT_DIRECTION_LTR

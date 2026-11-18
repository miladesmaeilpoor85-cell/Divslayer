extends RefCounted
## (v0.17) The credits block shown under Settings (in the game menu and on the title screen): every recorded track
## by region, and the authors of the ambience and the sound effects, read from data/audio_credits.json (written by
## tools/build_audio.py). All the audio is CC0 — no credit is required — but the people who made it are named anyway.

const PATH := "res://data/audio_credits.json"

static func data() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return d if typeof(d) == TYPE_DICTIONARY else {}

static func use_name(use: String) -> String:
	if use.ends_with("_2"):
		return use_name(use.trim_suffix("_2")) + Game.t(" (second take)", " (نسخهٔ دوم)")
	if use == "boss_b":
		return Game.t("Boss fights, chapters 2 and 3", "نبرد با سرکرده‌ها، فصل‌های ۲ و ۳")
	if use.begins_with("boss_"):
		return Game.boss_name(use.substr(5))
	match use:
		"title": return Game.t("Title screen", "صفحهٔ آغاز")
		"boss": return Game.t("Boss fights", "نبرد با سرکرده‌ها")
		"shrine": return Game.t("Shrines", "زیارتگاه‌ها")
		"trial": return Game.t("The Trial", "آزمون")
		"ending": return Game.t("A chapter's end", "پایانِ فصل")
	return Game.map_title(use)

## a left-to-right run inside Persian text (Unicode isolates: LRI ... PDI)
static func ltr(t: String) -> String:
	return String.chr(0x2066) + t + String.chr(0x2069) if Game.lang == "fa" else t

## the lines of the block: [text, size, colour]
static func lines() -> Array:
	var d := data()
	var out := []
	# (v0.31) the game's own music, made with Suno, comes first; everything else is CC0
	out.append([Game.t("Music made for this game (with Suno):", "موسیقی‌هایی که برای همین بازی ساخته شده‌اند (با Suno):"), 12, UI.CREAM])
	for c in d.get("music", []):
		if str(c.get("license", "")).begins_with("Suno"):
			out.append(["• " + use_name(str(c.get("use", ""))) + " — " + ltr("\"" + str(c.get("title", "")) + "\""), 11, UI.MUTED])
	var cc0_music: bool = (d.get("music", []) as Array).any(func(c): return not str(c.get("license", "")).begins_with("Suno"))
	if cc0_music:
		out.append([Game.t("The other music, the ambience and the sound effects are CC0 (public domain), from OpenGameArt.org and Kenney.nl. Thank you to:",
			"باقیِ موسیقی‌ها، صداهای محیط و جلوه‌های صوتی CC0 (مالکیت عمومی) هستند، از OpenGameArt.org و Kenney.nl. سپاس از:"), 12, UI.CREAM])
	else:
		# (v0.31) every track is the game's own now; the ambience and the sound effects stay CC0
		out.append([Game.t("The ambience and the sound effects are CC0 (public domain), from OpenGameArt.org and Kenney.nl. Thank you to:",
			"صداهای محیط و جلوه‌های صوتی CC0 (مالکیت عمومی) هستند، از OpenGameArt.org و Kenney.nl. سپاس از:"), 12, UI.CREAM])
	for c in d.get("music", []):
		if str(c.get("license", "")).begins_with("Suno"):
			continue
		# (v0.23, playtest) the English title and author are isolated left-to-right, so their quotes stay put in Persian
		out.append(["• " + use_name(str(c.get("use", ""))) + " — " + ltr("\"" + str(c.get("title", "")) + "\" — " + str(c.get("author", ""))), 11, UI.MUTED])
	var amb := []
	for c in d.get("ambience", []):
		var a := str(c.get("author", ""))
		if not a in amb:
			amb.append(a)
	if not amb.is_empty():
		out.append([Game.t("Ambience: ", "صداهای محیط: ") + ", ".join(amb), 11, UI.MUTED])
	var fx := []
	for c in d.get("sfx", []):
		var a := str(c.get("author", "")).replace(" (www.kenney.nl)", "")
		if not a in fx:
			fx.append(a)
	if not fx.is_empty():
		out.append([Game.t("Sound effects: ", "جلوه‌های صوتی: ") + ", ".join(fx), 11, UI.MUTED])
	# (v0.27, publishing: the store page names the makers, so the game must too; ISC and OFL want their notices kept)
	# (v0.35) the green region's ground and objects are painted now; the other regions follow
	out.append([Game.t("The maps: laid out and drawn for this game; the ground and the objects of Zabol, the Whispering Forest and the Thornwood camp are made with AI image generation (ChatGPT Images).",
		"نقشه‌ها: برای همین بازی چیده و کشیده شده‌اند؛ زمین و اشیای زابل، جنگل نجواگر و اردوگاه خارزار با هوش مصنوعیِ تصویرساز (ChatGPT Images) ساخته شده‌اند."), 11, UI.MUTED])
	# (v0.28) said openly, as Steam asks of AI-made content
	# (v0.34) the common foes are painted too, so they join this line
	out.append([Game.t("The hero, the people of the tale, the bosses, the foes, dialogue portraits and the app icon: made with AI image generation (ChatGPT Images), directed, chosen and retouched for this game; their motion is made by the game.",
		"قهرمان، اهالیِ داستان، سرکرده‌ها، دشمنان، چهره‌های گفت‌وگو و آیکونِ بازی: با هوش مصنوعیِ تصویرساز (ChatGPT Images) ساخته و برای همین بازی هدایت، برگزیده و پرداخت شده‌اند؛ حرکتشان را خودِ بازی می‌سازد."), 11, UI.MUTED])
	out.append([Game.t("Fonts: ", "قلم‌ها: ") + ltr("Vazirmatn — Saber Rastikerdar; Cinzel — Natanael Gama (SIL Open Font License 1.1)"), 11, UI.MUTED])
	out.append([Game.t("Icons: ", "آیکون‌ها: ") + ltr("Lucide — Copyright (c) Lucide Icons and Contributors (ISC License)"), 11, UI.MUTED])
	return out

static func build() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = "Credits"
	v.add_theme_constant_override("separation", 3)
	for l in lines():
		var lb: Label = UI.label(str(l[0]), int(l[1]), l[2])
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(lb)
	return v

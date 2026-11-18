extends Node

const Toll = preload("res://scripts/toll.gd")
const Gear = preload("res://scripts/gear.gd")
const Ch2 = preload("res://scripts/chapter2.gd")   # (v0.19) chapter 2: The Sleeper Beneath
const Ach = preload("res://scripts/achievements.gd")   # (v0.20) achievements, kept in the profile
const Looks = preload("res://scripts/looks.gd")        # (v0.20) hero looks earned by achievements
const Rush = preload("res://scripts/rush.gd")          # (v0.21) the Boss Rush, hosted by Sorush
const Ch3 = preload("res://scripts/chapter3.gd")       # (v0.23) chapter 3: The Chains of Damavand
const Tut = preload("res://scripts/tutorial.gd")       # (v0.24) Rostam's training in Zabol
## Global state: data tables, language, the hero's progress, saving, input setup.

signal lang_changed
signal stats_changed
signal settings_changed
signal phase_changed(p: int)
signal ult_ready
signal item_found(text: String, col: Color)   # (v0.10) an accessory or relic was found
signal achieved(id: String)                    # (v0.20) an achievement was earned (the HUD shows its card)

const Skills = preload("res://scripts/skills.gd")

const VERSION := "0.35.0"      # shown on the title screen; keep with export_presets.cfg version/name
const DATA := "res://data/"
const ART := "res://assets/art/"
const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
## the HTML game moves things "per 16 ms frame"; one such unit is 62.5 px per second
const PXS := 62.5

var tables := {}
var manifest := {}
var obj_sprites := {}
var strings := {}
var lang := "fa"
## player settings (saved apart from the hero): sound, music, screen shake, phone vibration, UI size 0/1/2,
## camera distance 0 far / 1 normal / 2 near, graphics 0 light / 1 full (lighting, weather, particles),
## brightness 0 normal / 1 bright / 2 brightest (how dark nights and caves get)
var settings := {"sound": true, "music": true, "mvol": 1, "svol": 1, "shake": true, "haptics": true, "ui": 1, "cam": 1, "fx": 1, "bright": 0, "compass": 1}
const UI_SCALES := [0.88, 1.0, 1.15]
const CAM_ZOOMS := [1.0, 1.15, 1.32]
var cls := "warrior"
var state := {}
var hp := 1.0
var mp := 0.0          # mana (saved with the hero, like hp)
var args := PackedStringArray()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	manifest = _json(DATA + "art_manifest.json")
	obj_sprites = _json(DATA + "map_object_sprites.json")
	for p in _json(DATA + "strings_en_fa.json"):
		strings[p["en"]] = p["fa"]
	_setup_font()
	_setup_input()
	args = OS.get_cmdline_user_args()
	_load_settings()
	stats_changed.connect(func(): Ach.check())

func has_arg(a: String) -> bool:
	return a in args

# ---------------------------------------------------------------- data
func _json(path: String):
	if not FileAccess.file_exists(path):
		push_error("missing data file: " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("bad json: " + path)
		return {}
	return parsed

func table(table_name: String):
	if not tables.has(table_name):
		tables[table_name] = _json(DATA + "Tables/" + table_name + ".json")
	return tables[table_name]

func map_data(key: String) -> Dictionary:
	return _json(DATA + "Maps/" + key + ".json")

func enemy_def(type: String) -> Dictionary:
	return table("ENEMY_TYPES").get(type, {})

# ---------------------------------------------------------------- language
func t(en: String, fa: String = "") -> String:
	if lang != "fa":
		return en
	if fa != "":
		return fa
	return strings.get(en, en)

## numbers in Persian digits when the game is in Persian
## (v0.24, the critic: in this font "·" reads as the Persian zero "۰") the mark between items: " · " in English, "، " in Persian
func sep(wide := false) -> String:
	return t("  ·  " if wide else " · ", "، ")

func num(n) -> String:
	var s := str(n)
	if lang != "fa":
		return s
	var out := ""
	for ch in s:
		var c := ch.unicode_at(0)
		if c >= 48 and c <= 57:
			out += String.chr(0x06F0 + c - 48)
		elif ch == "%":
			out += "٪"          # (v0.23) the Persian percent sign
		else:
			out += ch
	return out

## a decimal number with one digit after the point (Persian digits and the Persian decimal sign in Persian)
func dec(x: float) -> String:
	var s := "%.1f" % x
	return num(s).replace(".", "٫") if lang == "fa" else s

func set_lang(l: String) -> void:
	lang = l
	_save_settings()
	lang_changed.emit()

func map_title(key: String) -> String:
	var names: Dictionary = table("CH_MAPNAME")
	if names.has(key):
		return names[key][1] if lang == "fa" else names[key][0]
	var sd := shrine_def(key)
	if not sd.is_empty() and sd.has("en"):
		return str(sd.get("fa", sd["en"])) if lang == "fa" else str(sd["en"])
	var md := map_data(key)
	var n: String = md.get("data", {}).get("name", key)
	return t(n)

func enemy_name(type: String) -> String:
	var en: String = enemy_def(type).get("name", type)
	if lang == "fa":
		return table("V12_ENEMY").get(en, strings.get(en, en))
	return en

## v18: names, titles, phase thresholds, colour and weaknesses of every "bossy" enemy
## a name inside a sentence: "the echo of the White Div", not "of The White Div"
static func no_the(n: String) -> String:
	return "the " + n.substr(4) if n.begins_with("The ") else n

## (v0.25) the foes Rostam once slew walk again as echoes; (v0.26) the game says so wherever it names them
static func is_echo(type: String) -> bool:
	return bool(BOSS_CFG.get(type, {}).get("echo", false))

const BOSS_CFG := {
	"boss": {
		"echo": true,
		"name": ["Arzhang the Div", "ارژنگ دیو"],
		"title": ["Echo of the Sixth Labour", "پژواکِ خوانِ ششم"],
		"phases": [0.66, 0.33],
		"rework": true,
		"rgb": Color8(170, 110, 255),
	},
	"boss2": {
		"echo": true,
		"name": ["The King of Mazandaran", "شاه مازندران"],
		"title": ["Echo of the Stone King", "پژواکِ شاهِ سنگ‌شده"],
		"phases": [0.66, 0.33],
		"rework": true,
		"rgb": Color8(255, 120, 40),
		"weak": {"freeze": 1.6},
	},
	"matriarch": {
		"echo": true,
		"name": ["The Sorceress", "زنِ جادو"],
		"title": ["Echo of the Fourth Labour", "پژواکِ خوانِ چهارم"],
		"phases": [0.66, 0.33],
		"rework": true,
		"rgb": Color8(120, 220, 90),
		"weak": {"burn": 1.4, "stun": 1.4},
	},
	"arbiter": {
		"echo": true,
		"name": ["The White Div", "دیو سپید"],
		"title": ["Echo of the Seventh Labour", "پژواکِ خوانِ هفتم"],
		"phases": [0.66, 0.33],
		"rework": true,
		"rgb": Color8(150, 210, 255),
		"weak": {"burn": 1.8},
	},
	"ignarok": {
		"name": ["Puladvand, the First Flame", "پولادوند، نخستین شعله"],
		"title": ["Lord of the Emberforge", "سالارِ آهنگرخانهٔ اخگر"],
		"rgb": Color8(255, 110, 40),
		"weak": {"freeze": 1.6},
	},
	"ancientwyrm": {
		"name": ["The Dragon of Kashaf", "اژدهای کشف‌رود"],
		"title": ["Sleeper beneath the Sanctum", "خفتهٔ زیر معبد"],
		"phases": [0.66, 0.33],
		"rework": true,
		"rgb": Color8(90, 200, 230),
		"weak": {"burn": 1.5, "stun": 1.2},
	},
	# (v0.19) the Hoarfrost Vale's warden: one shard of the Wyrm Key in its chest
	"glaciertitan": {
		"echo": true,
		"name": ["Akvan the Div", "اکوان دیو"],
		"title": ["Echo in the Hoarfrost Vale", "پژواکِ درهٔ یخ‌بندان"],
		"phases": [0.5],
		"mini": true,
		"rework": true,
		"rgb": Color8(120, 190, 255),
		"weak": {"burn": 1.6},
	},
	"toadking": {
		"name": ["Bid the Div", "دیو بید"],
		"title": ["The toad-shaped Div", "دیوِ وزغ‌پیکر"],
		"mini": true,
		"rgb": Color8(140, 210, 90),
		"weak": {"stun": 1.4},
	},
	"anvilward": {
		"name": ["Pulad of Ghandi", "پولادِ غندی"],
		"title": ["Keeper of the Forge Gate", "دربانِ دروازهٔ آهنگرخانه"],
		"mini": true,
		"rgb": Color8(255, 150, 60),
		"weak": {"freeze": 1.4},
	},
	# (v0.23) chapter 3 on Mount Damavand: Zahhak's steward, and Zahhak in his chains
	"kondrow": {
		"name": ["Kondrow", "کُندرو"],
		"title": ["Steward of Zahhak", "پیشکارِ ضحاک"],
		"mini": true,
		"rgb": Color8(170, 110, 220),
		"weak": {"burn": 1.3},
	},
	"zahhak": {
		"name": ["Zahhak", "ضحاک"],
		"title": ["The serpent-shouldered king", "شاهِ ماردوش"],
		"phases": [0.66, 0.33],
		"rework": true,
		"rgb": Color8(130, 220, 110),
		"weak": {"burn": 1.3},
	},
	"captain": {
		"name": ["Ashkbus of Kushan", "اشکبوسِ کشانی"],
		"title": ["Chief of the Turanian Raiders", "سردستهٔ راهزنانِ تورانی"],
		"mini": true,
		"rgb": Color8(230, 80, 60),
	},
}

func boss_cfg(type: String) -> Dictionary:
	return BOSS_CFG.get(type, {})

func boss_name(type: String) -> String:
	var c: Dictionary = boss_cfg(type)
	return t(c["name"][0], c["name"][1]) if not c.is_empty() else enemy_name(type)

func boss_title(type: String) -> String:
	var c: Dictionary = boss_cfg(type)
	return t(c["title"][0], c["title"][1]) if not c.is_empty() else ""

func v18() -> Dictionary:
	if not state.has("v18") or typeof(state["v18"]) != TYPE_DICTIONARY:
		state["v18"] = {"seen": {}, "kills": {}}
	return state["v18"]

## the boss fight in progress (for "Rematch"): type, map, where the hero stood, potions; not saved
var fight := {}
var victory_at := -100000           # (v0.24) ms of the last boss victory: cards wait for its banner

# ---------------------------------------------------------------- time of day (HTML: dawn, day, dusk, night; 3 min each)
const PHASE_SEC := 180.0
const PHASES := ["dawn", "day", "dusk", "night"]
## regions under a roof: no day and night there (V12.LIGHT.INDOOR, plus the puzzle shrines)
const INDOOR := {"dungeon": true, "sanctum": true, "emberforge": true, "trial": true, "wyrmhollow": true, "zahhakcave": true}

static func indoor(map_key: String) -> bool:
	return INDOOR.has(map_key) or map_key.begins_with("shrine_")

func day_t() -> float:
	return float(state.get("day_t", 0.3))

func tick_day(dt: float) -> void:
	var before := phase()
	state["day_t"] = fmod(day_t() + dt / (PHASE_SEC * 4.0), 1.0)
	if phase() != before:
		phase_changed.emit(phase())

## 0 dawn, 1 day, 2 dusk, 3 night
func phase() -> int:
	return int(day_t() * 4.0) % 4

## [phase now, next phase, k]: the last 8 seconds of a phase fade into the next one
func phase_blend() -> Array:
	var x := day_t() * 4.0
	var p := int(x) % 4
	var f: float = x - floor(x)
	var edge: float = 8.0 / PHASE_SEC
	return [p, (p + 1) % 4, clamp((f - (1.0 - edge)) / edge, 0.0, 1.0)]

func phase_name(p := -1) -> String:
	if p < 0:
		p = phase()
	var en := ["Dawn", "Day", "Dusk", "Night"]
	var fa := ["سپیده‌دم", "روز", "غروب", "شب"]
	return t(en[p], fa[p])

## a short vibration on phones (setting "haptics"); ms and strength 0..1
func vibrate(ms: int, strength := 0.6) -> void:
	if not bool(settings.get("haptics", true)) or not OS.has_feature("mobile"):
		return
	Input.vibrate_handheld(ms, strength)

# ---------------------------------------------------------------- the hero
## (v0.24) the hero has no name of his own: he is the Ember-bearer, and the class is his calling — each the way of one of the
## Shahnameh's heroes, who are people of the tale (Rostam trains you, Zal sends you, Siavash keeps the Trial, Gordafarid the
## bounties). "name" is how the tale addresses him; "role" is the calling shown on the HUD and the cards; "path" whose way it is.
const HEROES := {
	"warrior": {"name": ["Ember-bearer", "اخگردار"], "role": ["Pahlavan", "پهلوان"], "path": ["the way of Rostam", "راهِ رستم"]},
	"mage": {"name": ["Ember-bearer", "اخگردار"], "role": ["Sage", "فرزانه"], "path": ["the way of Zal", "راهِ زال"]},
	"rogue": {"name": ["Ember-bearer", "اخگردار"], "role": ["Ayyar", "عیّار"], "path": ["the way of Gordafarid", "راهِ گردآفرید"]},
	"paladin": {"name": ["Ember-bearer", "اخگردار"], "role": ["Oathbearer", "سوگندوَر"], "path": ["the way of Siavash", "راهِ سیاوش"]},
}

func hero_name(c := "") -> String:
	var h: Dictionary = HEROES.get(c if c != "" else cls, HEROES["warrior"])
	return t(h["name"][0], h["name"][1])

func hero_name_en(c := "") -> String:
	var h: Dictionary = HEROES.get(c if c != "" else cls, HEROES["warrior"])
	return str(h["name"][0])

func hero_role(c := "") -> String:
	var h: Dictionary = HEROES.get(c if c != "" else cls, HEROES["warrior"])
	return t(h["role"][0], h["role"][1])

func hero_path(c := "") -> String:
	var h: Dictionary = HEROES.get(c if c != "" else cls, HEROES["warrior"])
	return t(h["path"][0], h["path"][1])

func class_def() -> Dictionary:
	return table("CLASSES").get(cls, {})

const START_PURSE := 40

func new_game(c: String) -> void:
	cls = c
	fight = {}
	DirAccess.remove_absolute(SAVE_PATH + ".bak")     # (code review) the hero before this one is not a fallback for it
	var cdef := class_def()
	# (v0.23, playtest: "the first visit to the shops is window-shopping") Zabol's purse: 40 gold more to start with
	state = {"level": 1, "xp": 0, "xp_next": 40, "gold": int(cdef.get("startGold", 0)) + START_PURSE,
		"potions": int(cdef.get("startPotions", 1)) + 1, "weapon": 1, "armor": 0,
		"map": "village", "x": 420.0, "y": 490.0, "v18": {"seen": {}, "kills": {}},
		"talents": {}, "slots": ["bolt", "nova"], "ult": 0.0, "mana_potions": 1}
	hp = max_hp()
	mp = max_mp()

func lvl() -> int:
	return int(state.get("level", 1))

## test hooks: the balance bot can give the hero the exact HTML stats (which include talents)
var test_hp := -1.0
var test_atk := -1.0

func max_hp() -> float:
	if test_hp > 0.0:
		return test_hp
	return float(class_def().get("hp", 30)) + 8.0 * (lvl() - 1) + 10.0 * talent("vit1") + 20.0 * talent("vit2") + Gear.sum("hpMax") + sigil_bonus("vit")

func atk() -> float:
	if test_atk > 0.0:
		return test_atk
	var w: Dictionary = table("WEAPON_TIERS").get(str(int(state.get("weapon", 0))), {})
	var a := float(class_def().get("atk", 5)) + 2.0 * (lvl() - 1) + float(w.get("atkBonus", 0)) + talent("str1") + 2.0 * talent("str2") + Gear.sum("atk") + FORGE_ATK * forge_level("w") + sigil_bonus("might")
	if Gear.uniq("vengeance") and hp < 0.4 * max_hp():
		a *= 1.4        # Dragon of Kashaf's relic: +40% ATK below 40% HP
	return a

func defense() -> float:
	var a: Dictionary = table("ARMOR_TIERS").get(str(int(state.get("armor", 0))), {})
	return float(class_def().get("def", 1)) + (lvl() - 1) + float(a.get("def", 0)) + talent("def1") + Gear.sum("def") + FORGE_DEF * forge_level("a") + sigil_bonus("guard")

func speed() -> float:
	return (float(class_def().get("speed", 2.7)) * (1.0 + 0.05 * talent("swift")) + Gear.sum("speed")) * PXS

func crit_chance() -> float:
	return float(class_def().get("critChance", 0.18)) + 0.05 * talent("crit") + Gear.sum("crit")

# ---------------------------------------------------------------- mana, the ultimate meter (v0.6)
func max_mp() -> float:
	return float(class_def().get("mp", 10)) + Skills.MP_PER_LEVEL * (lvl() - 1) + Gear.sum("mpMax") + sigil_bonus("focus")

func mp_regen() -> float:
	return Skills.MP_REGEN + (float(table("V12_BAL").get("MAGE_REGEN_EXTRA", 1)) if cls == "mage" else 0.0) + Gear.sum("mpRegen")

func max_stamina() -> float:
	return 100.0 + Gear.sum("stamMax")

func ult() -> float:
	return float(state.get("ult", 0.0))

## fighting fills the ultimate: blows that land, spells that hit, hits you take, kills
func add_ult(n: float) -> void:
	var before := ult()
	if n > 0.0:
		n *= 1.0 + Gear.sum("ultCharge")
	state["ult"] = clamp(before + n, 0.0, 100.0)
	if before < 100.0 and ult() >= 100.0:
		ult_ready.emit()

func slots() -> Array:
	var s = state.get("slots", null)
	if typeof(s) != TYPE_ARRAY or s.size() < 2:
		s = ["bolt", "nova"]
		state["slots"] = s
	return s

## bind a spell to spell button 0 or 1 (a spell sits on one button only: binding it again swaps)
func bind_slot(i: int, id: String) -> void:
	var s := slots()
	var other := 1 - i
	if s[other] == id:
		s[other] = s[i]
	s[i] = id
	state["slots"] = s
	save_game()
	stats_changed.emit()

# ---------------------------------------------------------------- talents (v0.6): one point per level
func talents() -> Dictionary:
	var t = state.get("talents", null)
	if typeof(t) != TYPE_DICTIONARY:
		t = {}
		state["talents"] = t
	return t

func talent(id: String) -> int:
	return int(talents().get(id, 0))

func talent_spent() -> int:
	var n := 0
	for k in talents():
		n += int(talents()[k])
	return n

## points earned: one per level after the first (plus any bonus points)
func talent_points() -> int:
	return max(0, lvl() - 1 + int(state.get("bonus_talents", 0)) - talent_spent())

## "" when the node can take a point now, else why not
func talent_block(id: String) -> String:
	var n: Dictionary = Skills.node(id)
	if n.is_empty():
		return "?"
	if talent(id) >= int(n.get("max", 1)):
		return t("Maxed", "کامل")
	if n.has("requires") and talent(str(n["requires"])) < int(n.get("reqRank", 1)):
		return t("Needs %s (rank %d)" % [Skills.talent_name(str(n["requires"])), int(n.get("reqRank", 1))],
			"نیاز: %s (رتبهٔ %s)" % [Skills.talent_name(str(n["requires"])), num(int(n.get("reqRank", 1)))])
	if talent_points() <= 0:
		return t("No points", "امتیاز نداری")
	return ""

func learn_talent(id: String) -> bool:
	if talent_block(id) != "":
		return false
	var hp0 := max_hp()
	talents()[id] = talent(id) + 1
	hp += max_hp() - hp0          # more health: the new part comes filled
	save_game()
	stats_changed.emit()
	return true

func reset_talents() -> void:
	state["talents"] = {}
	hp = min(hp, max_hp())
	save_game()
	stats_changed.emit()

func heavy_mul() -> float:
	return 1.25 if talent("power_atk") > 0 else 1.0

func ult_mul() -> float:
	return 1.3 if talent("ult_pwr") > 0 else 1.0

func atk_speed_mul() -> float:
	return 0.9 if talent("haste") > 0 else 1.0

func xp_mul() -> float:
	return (1.0 + 0.2 * talent("scholar")) * diff_mul("reward")

func gold_mul() -> float:
	return (1.25 if talent("treasure") > 0 else 1.0) * diff_mul("reward")

func melee_mul() -> float:
	return float(class_def().get("meleeBonus", 1.0))

## damage the hero takes: region scale and percentage armour, as in the HTML balance pass.
## poison/burn ticks are not region-scaled and count half (V12.BAL.STATUS_MULT)
func incoming(dmg: float, area: String, from_status := false) -> int:
	var area_d: Dictionary = area_scale(area)
	var d := defense()
	var mit: float = min(0.6, d / (d + 60.0))
	var m: float = 0.5 if from_status else float(area_d.get("dmg", 1)) * diff_mul("dmg")
	if not from_status and talent("block_mastery") > 0:
		m *= 0.85
	if not from_status and Gear.uniq("voidward"):
		m *= 0.9        # Arzhang's Bulwark: take 10% less damage
	return max(1, int(round(dmg * m * (1.0 - mit))))

## enemy health and damage after region and boss scaling.
## NOTE: the exported V12_BAL.BOSS table was captured after v18 had already multiplied the four story
## bosses by V18_HP at load time (4.6 x 2.3 = 10.58 for Arzhang), so it must not be applied again.
func enemy_stats(type: String, area: String) -> Dictionary:
	var e := enemy_def(type)
	var bal: Dictionary = table("V12_BAL")
	var area_d: Dictionary = area_scale(area)
	var boss_d = bal.get("BOSS", {}).get(type, null)
	var hpm := float(area_d.get("hp", 1))
	var dmg := float(e.get("dmg", 5))
	if boss_d != null:
		hpm *= float(boss_d.get("hp", 1))
		dmg = round(dmg * float(boss_d.get("dmg", 1)))
	var out := {"hp": round(float(e.get("hp", 10)) * hpm * diff_mul("hp")), "dmg": dmg, "speed": float(e.get("speed", 1)) * PXS, "knock": float(e.get("knockMult", 1.0)),
		"xp": int(e.get("xp", 5)), "gold": int(e.get("gold", 1)), "w": float(e.get("w", 24)), "h": float(e.get("h", 24)),
		"boss": e.get("boss", false) or boss_d != null}
	if not rush.is_empty() and type == str(rush.get("type", "")):
		out["hp"] = round(float(rush.get("hp", out["hp"])) * diff_mul("hp"))
	elif ng() > 0 and rush.is_empty():
		# (v0.21) New Game+: foes are stronger, so they give more: XP by how much tougher the region got, gold half as much again per cycle
		var base_hp := float(bal.get("AREA", {}).get(area, {"hp": 1}).get("hp", 1))
		out["xp"] = int(round(float(out["xp"]) * max(1.0, float(area_d["hp"]) / max(0.1, base_hp))))
		out["gold"] = int(round(float(out["gold"]) * (1.0 + 0.5 * ng())))
	return out

# ---------------------------------------------------------------- New Game+ and the Boss Rush (v0.21)
## the Boss Rush in progress (not saved): {i, type, hp, dmg, elapsed, ...} — see scripts/rush.gd
var rush := {}

## the New Game+ cycle: 0 = the first time through
func ng() -> int:
	return int(state.get("ng", 0))

## in New Game+ every region (but the village and the Trial, which has its own climb) is at least as tough as the Hoarfrost
## Vale, and more so each cycle: health +35% and damage +20% a cycle on top
const NG_FLOOR := {"hp": 6.4, "dmg": 1.9}
const NG_HP := 0.35
const NG_DMG := 0.2

## a region's health and damage scaling: the HTML game's table (V12_BAL.AREA), raised in New Game+; in the Boss Rush the
## damage is the memory's own
func area_scale(area: String) -> Dictionary:
	var a: Dictionary = table("V12_BAL").get("AREA", {}).get(area, {"hp": 1, "dmg": 1})
	var hp := float(a.get("hp", 1))
	var dmg := float(a.get("dmg", 1))
	if not rush.is_empty():
		return {"hp": hp, "dmg": float(rush.get("dmg", dmg))}
	var n := ng()
	if n > 0 and area != "village" and area != "trial":
		hp = max(hp, float(NG_FLOOR["hp"])) * (1.0 + NG_HP * n)
		dmg = max(dmg, float(NG_FLOOR["dmg"])) * (1.0 + NG_DMG * n)
	return {"hp": hp, "dmg": dmg}

## the share of ordinary foes that come as elites: more in New Game+
func elite_chance() -> float:
	return elite_rate + min(0.13, 0.04 * ng())

## the story begins again: the hero keeps his level, gear, gold, skills, talents, sigils and forge; the quests, the
## bosses, the Toll, chapter 2 and the things lying about the maps come back. Achievements and looks are the profile's.
const NG_RESET := ["q1", "q2", "q3", "defeated", "brann", "toll", "c2", "c3", "picked"]

func start_ng() -> void:
	state["ng"] = ng() + 1
	for k in NG_RESET:
		state.erase(k)
	Ch2.told = "-"
	Ch3.told = "-"
	Ch3.e_told = "-"
	fight = {}
	rush = {}
	state["map"] = "village"
	state["x"] = 420.0
	state["y"] = 490.0
	hp = max_hp()
	mp = max_mp()
	Ach.unlock("ng_start")
	save_game()
	stats_changed.emit()

func add_xp(n: int) -> bool:
	state["xp"] = int(state["xp"]) + n
	var up := false
	while int(state["xp"]) >= int(state["xp_next"]):
		state["xp"] = int(state["xp"]) - int(state["xp_next"])
		state["level"] = lvl() + 1
		state["xp_next"] = int(floor(int(state["xp_next"]) * 1.35))
		up = true
	if up:
		hp = max_hp()
		mp = max_mp()
	stats_changed.emit()
	return up

# ---------------------------------------------------------------- quests (Zal's main line)
const BOSS_QUEST := {"boss": 1, "boss2": 2, "matriarch": 3}

func q(n: int) -> String:
	return str(state.get("q%d" % n, "not_started"))

func set_q(n: int, v: String) -> void:
	state["q%d" % n] = v
	stats_changed.emit()

func is_defeated(type: String) -> bool:
	return state.get("defeated", {}).has(type)

func is_boss_type(type: String) -> bool:
	return bool(enemy_def(type).get("boss", false)) or table("V12_BAL").get("BOSS", {}).has(type)

## lines Zal says now; talking also starts the next quest, exactly as in the HTML game
func elder_lines() -> Array:
	var lines := []
	if q(1) == "not_started":
		set_q(1, "active")
		# (v0.24) Zal, lord of Zabol, Rostam's father: he knows whom he speaks to
		lines = [t("Welcome to Zabol, ember-bearer. I am Zal, son of Sam.", "به زابل خوش آمدی، اخگردار. من زالم، پسرِ سام."),
			# (v0.29) not a chosen one: the ember fell to a sell-sword, and every echo can smell it on him
			t("That mark on your hand... a spark of Jamshid's farr. The tale said it would seek a hero of royal blood. It found a sell-sword — and now every echo can smell it on you.",
				"آن نشانِ روی دستت... اخگری از فرّهٔ جمشید. افسانه می‌گفت دستِ پهلوانی از تخمهٔ کیان را می‌جوید؛ دستِ یک مزدور را یافت — و حالا هر پژواکی بویش را از تو می‌شنود."),
			# (v0.25, the critic: "the hero does Rostam's own labours while Rostam watches") the foes of chapter 1 are echoes of
			# the ones Rostam slew; his blade passes through them, only the ember unmakes them
			t("Since the day the chains of Damavand cracked, old evils walk again as echoes. The echo of Arzhang the Div — the one my son slew in Mazandaran — weaves shadow in the Sunken Crypt beyond the northern forest.",
				"از آن روز که زنجیرهای دماوند ترک برداشت، بدی‌های کهن چون پژواک بازگشته‌اند. پژواکِ ارژنگ دیو — همان که پسرم در مازندران کشت — آن سوی جنگلِ شمالی در سردابِ فرورفته سایه می‌بافد."),
			t("Rostam's blade passes through an echo like mist; only the ember can return it to dust. Sindokht sells blades and provisions, Kavian forges armour, and Rostam will teach you what he can.",
				"تیغِ رستم از پژواک می‌گذرد، چنان‌که از مه؛ تنها اخگر آن را به خاک برمی‌گرداند. سیندخت تیغ و توشه می‌فروشد، کاویان زره می‌سازد، و رستم هر چه بتواند یادت می‌دهد.")]
	elif q(1) == "active":
		lines = [t("The Crypt lies north, past the Whispering Forest.", "سرداب در شمال است، آن سوی جنگلِ نجواگر.")]
	elif q(1) == "complete":
		# (v0.24, critic: Rostam slew the white elephant as a child — no one in Zabol was "quicker at your age")
		lines = [t("Arzhang's echo is dust! Take this gold, ember-bearer. Sam himself would be glad of this news.", "پژواکِ ارژنگ خاک شد! این سکه‌ها را بگیر، اخگردار. سام هم اگر بود، از این خبر شاد می‌شد."),
			t("Yet... as it fell, an ancient seal cracked with it.", "اما... با افتادنش، مُهری کهن هم ترک برداشت."),
			t("Rest well. Come speak with me again soon.", "خوب بیاسا. به‌زودی دوباره نزدم بیا.")]
	elif q(2) == "not_started":
		set_q(2, "active")
		lines = [t("The seal east of the forest is broken. Ash chokes the wind.", "مُهرِ شرقِ جنگل شکسته است. خاکستر نفسِ باد را بند آورده."),
			t("The echo of the King of Mazandaran has risen in the Ashen Peaks.", "پژواکِ شاهِ مازندران در قله‌های خاکستر سر برآورده است."),
			t("Before Rostam's eyes that sorcerer-king once turned himself to stone; his echo is stone and fire. Kavian's armour may save your life. Go!",
				"آن شاهِ جادوگر روزی پیشِ چشمِ رستم خود را سنگ کرد؛ پژواکش سنگ و آتش است. شاید زرهِ کاویان جانت را نجات دهد. برو!")]
	elif q(2) == "active":
		lines = [t("The eastern path through the forest leads to the Ashen Peaks.", "راهِ شرقیِ جنگل به قله‌های خاکستر می‌رسد.")]
	elif q(2) == "complete":
		lines = [t("The mountain falls silent... Zabol is truly safe.", "کوه خاموش شد... زابل به‌راستی در امان است."),
			t("Zabol pays its debts, ember-bearer. Take your wage!", "زابل وامش را می‌پردازد، اخگردار. مزدت را بگیر!")]
	elif q(3) == "not_started":
		set_q(3, "active")
		lines = [t("Whispers spread of a deeper darkness — the Shadowfen Bog west of the peaks.", "زمزمهٔ تاریکیِ ژرف‌تری پیچیده — مردابِ سایه، غربِ قله‌ها."),
			t("The Sorceress's echo poisons the land, and Bid the Div haunts the bog in the shape of a toad.", "پژواکِ زنِ جادو زمین را زهرآگین می‌کند، و دیو بید به پیکرِ وزغ در مرداب می‌گردد."),
			t("Rudabeh, my wife, brews potions and scrolls from herbs. The day Rostam was born, a feather of the Simorgh saved her life — she has known the herbs ever since. Speak with her! Then hunt the Sorceress.",
				"رودابه، همسرم، از گیاه معجون و طومار دم می‌کند. روزی که رستم زاده شد، پرِ سیمرغ جانش را خرید و از آن روز گیاهان را می‌شناسد. با او سخن بگو! بعد زنِ جادو را شکار کن.")]
	elif q(3) == "active":
		lines = [t("The Shadowfen lies west through the Ashen Peaks. Beware its poison.", "مردابِ سایه در غرب است، از میانِ قله‌های خاکستر. از زهرش بپرهیز.")]
	elif q(3) == "complete":
		lines = [t("The Sorceress's echo is dust! The bog is cleansed.", "پژواکِ زنِ جادو خاک شد! مرداب پاک شد."),
			t("The ember burns hotter on your hand. Whatever you are, it has not let you go. Take this last reward!", "اخگر روی دستت داغ‌تر می‌سوزد. هر که باشی، رهایت نکرده است. این پاداشِ آخر را بگیر!")]
	else:
		# (v0.19) chapter 2 speaks through the Elder once his three quests are done
		var c2: Array = Ch2.elder_lines()
		if not c2.is_empty():
			save_game()
			return c2
		var c3: Array = Ch3.elder_lines()        # (v0.23) chapter 3's epilogue is his to tell
		if not c3.is_empty():
			save_game()
			return c3
		lines = [t("The bards will sing of Rostam, not of you. Zabol will remember all the same, ember-bearer.", "خنیاگران از رستم خواهند خواند، نه از تو. اما زابل فراموشت نمی‌کند، اخگردار.")]
	save_game()
	return lines

## does Zal have something new to say (a quest to give, a reward to pay)? -> the "!" marker
func elder_has_news() -> bool:
	if q(1) == "not_started":
		return true
	for n in [1, 2, 3]:
		if q(n) == "complete":
			return true
	return (q(1) == "done" and q(2) == "not_started") or (q(2) == "done" and q(3) == "not_started") or Ch2.has_news("elder") or Ch3.has_news("elder")

## rewards are paid when the conversation ends; returns a message to show, or ""
func elder_dialog_done() -> String:
	var rewards := {1: 100, 2: 300, 3: 500}
	for n in [1, 2, 3]:
		if q(n) == "complete":
			set_q(n, "done")
			state["gold"] = int(state.get("gold", 0)) + rewards[n]
			save_game()
			return t("+%d Gold Reward!" % rewards[n], "+%s سکه پاداش!" % num(rewards[n]))
	return ""

## a boss falls: remember it, finish its quest, pay the bounty
func boss_defeated(type: String) -> String:
	if not rush.is_empty():
		Ach.on_boss(type)          # (v0.21) a memory: no bounty, no relic, no quest — the Boss Rush goes on
		return ""
	var d: Dictionary = state.get("defeated", {})
	d[type] = true
	state["defeated"] = d
	var msg := t("%s defeated!" % enemy_def(type).get("name", type), "%s شکست خورد!" % enemy_name(type))
	# (v0.26, the critic: "no card, banner or message says echo") an echo does not lose: it goes back to dust
	if is_echo(type):
		msg = t("The echo of %s is dust again!" % no_the(str(enemy_def(type).get("name", type))), "پژواکِ %s به خاک برگشت!" % enemy_name(type))
	if type == "boss" and brann() == "none":
		brann_set("core")
		msg += "\n" + Story.line("core_got")
	elif type == "anvilward" and brann() == "anvil":
		brann_set("anvil_done")
		msg += "\n" + Story.line("o_anvil_back")
	elif type == "ignarok" and (brann() == "ignarok" or brann() == "anvil_done"):
		brann_set("ignarok_done" if brann() == "ignarok" else "anvil_done")
		msg += "\n" + Story.line("ign_out")
	var ess := 2 if BOSS_QUEST.has(type) or bool(enemy_def(type).get("boss", false)) else 1
	state["essence"] = essence() + ess
	msg += "\n" + t("+%d Essence" % ess, "+%s عصارهٔ مانا" % num(ess))
	var rel: Dictionary = Gear.relic(type)
	if not rel.is_empty() and not Gear.has_relic(str(rel["uniq"])):
		Gear.grant(rel)
		msg += "\n" + t("Relic obtained: ", "یادگار به دست آمد: ") + Gear.item_name(rel)
	if type == "captain" and toll_st() == "active" and str(toll().get("how", "")) in ["", "pay", "fame", "oath", "hand", "ledger", "ghost"]:
		toll()["how"] = "fight"        # a deal that is broken ends the old way
	var c2m: String = Ch2.on_boss(type)
	if c2m != "":
		msg += "\n" + c2m
	var c3m: String = Ch3.on_boss(type)
	if c3m != "":
		msg += "\n" + c3m
	Ach.on_boss(type)
	if type == "ancientwyrm" and ng() > 0:
		Ach.unlock("ng_wyrm")
	if BOSS_QUEST.has(type):
		var n: int = BOSS_QUEST[type]
		if q(n) != "done":
			set_q(n, "complete")
			state["gold"] = int(state.get("gold", 0)) + [0, 30, 60, 80][n]
			msg += "\n" + t("Return to Zal.", "نزد زال برگرد.")
	save_game()
	stats_changed.emit()
	return msg

## the current objective for the HUD
func objective() -> String:
	if not rush.is_empty():
		return Rush.objective()
	var tut := Tut.objective()          # (v0.24) Rostam's training, while it is offered or under way
	if tut != "":
		return tut
	# (v0.24, playtest: after Arzhang the compass sent the hero to Jamshid first) Zal's reward and the tale lead
	if q(1) == "complete" or q(2) == "complete" or q(3) == "complete":
		return t("Return to Zal", "نزد زال برگرد")
	var bo := brann_objective()
	if bo != "" and ["core", "anvil_done", "ignarok_done"].has(brann()):
		return bo
	if q(1) == "not_started":
		return t("Speak with Zal in the village", "با زال در دهکده صحبت کن")
	if q(1) == "active":
		return t("Defeat the echo of Arzhang the Div in the Sunken Crypt (north of the forest)", "پژواکِ ارژنگ دیو را در سردابِ فرورفته شکست بده (شمالِ جنگل)")
	if q(1) == "complete" or q(2) == "complete" or q(3) == "complete":
		return t("Return to Zal", "نزد زال برگرد")
	if q(2) == "not_started":
		return t("Speak with Zal", "با زال صحبت کن")
	if q(2) == "active":
		return t("Defeat the echo of the King of Mazandaran in the Ashen Peaks (east of the forest)", "پژواکِ شاهِ مازندران را در قله‌های خاکستر شکست بده (شرقِ جنگل)")
	if q(3) == "not_started":
		return t("Speak with Zal", "با زال صحبت کن")
	if q(3) == "active":
		return t("Hunt the Sorceress's echo in the Shadowfen (west of the peaks)", "پژواکِ زنِ جادو را در مردابِ سایه شکار کن (غربِ قله‌ها)")
	var c2o: String = Ch2.objective()
	if c2o != "":
		return c2o
	# (v0.23) chapter 3 under way leads; its first nudge ("speak with Kaveh") waits behind a side quest in progress
	var c3o: String = Ch3.objective()
	if c3o != "" and Ch3.step() != "":
		return c3o
	if bo != "":
		return bo
	if toll_st() == "active":
		return Toll.line("obj_camp")
	if toll_st() == "box":
		return Toll.line("obj_back")
	if c3o != "":
		return c3o
	if shrines_done() < SHRINE_ORDER.size():
		return t("Seek the ancient shrines — a pillar of light marks each one (%d/%d)" % [shrines_done(), SHRINE_ORDER.size()],
			"زیارتگاه‌های کهن را پیدا کن — ستونی از نور هر کدام را نشان می‌دهد (%s/%s)" % [num(shrines_done()), num(SHRINE_ORDER.size())])
	return t("Explore — the Crystal Sanctum and the Forge await", "کاوش کن — معبد بلورین و آهنگرخانه منتظرند")

# ---------------------------------------------------------------- the seven shrines (v0.18)
## the puzzle shrines, one in every region (V16_SHRINE_LIST), in the order the compass suggests them
const SHRINE_ORDER := ["shrine_shadows", "shrine_embers", "shrine_weight", "shrine_fuse", "shrine_tides", "shrine_light", "shrine_echoes"]
## the Shrine Sigil's gifts, one per shrine, for good. Vitality and Focus are the HTML game's; Might and Guard are mine.
const SIGILS := {
	"vit": {"name": ["Vitality", "سرزندگی"], "label": ["+12 Max HP", "+۱۲ حداکثر جان"], "val": 12.0, "icon": "heart"},
	"focus": {"name": ["Focus", "تمرکز"], "label": ["+6 Max MP", "+۶ حداکثر مانا"], "val": 6.0, "icon": "sparkles"},
	"might": {"name": ["Might", "نیرو"], "label": ["+2 ATK", "+۲ حمله"], "val": 2.0, "icon": "sword"},
	"guard": {"name": ["Guard", "پایداری"], "label": ["+1 DEF", "+۱ دفاع"], "val": 1.0, "icon": "shield"},
}

func shrine_def(map_key: String) -> Dictionary:
	for s in table("V16_SHRINE_LIST"):
		if str(s.get("key", "")) == map_key:
			return s
	return {}

## state.shrines[key] = {door: the inner door stands open, claimed: the altar's gold and treasure taken, gift: the sigil chosen}
func shrine(map_key: String) -> Dictionary:
	if not state.has("shrines") or typeof(state["shrines"]) != TYPE_DICTIONARY:
		state["shrines"] = {}
	var all: Dictionary = state["shrines"]
	if not all.has(map_key) or typeof(all[map_key]) != TYPE_DICTIONARY:
		all[map_key] = {"door": false, "claimed": false, "gift": ""}
	return all[map_key]

func shrine_done(map_key: String) -> bool:
	var all = state.get("shrines", {})
	return typeof(all) == TYPE_DICTIONARY and all.has(map_key) and str(all[map_key].get("gift", "")) != ""

func shrines_done() -> int:
	var n := 0
	for k in SHRINE_ORDER:
		if shrine_done(k):
			n += 1
	return n

## how many times a sigil gift was chosen, and what it adds
func sigil(id: String) -> int:
	var d = state.get("sigils", {})
	return int(d.get(id, 0)) if typeof(d) == TYPE_DICTIONARY else 0

func sigil_bonus(id: String) -> float:
	return float(SIGILS.get(id, {}).get("val", 0.0)) * sigil(id)

## the altar's sigil: the gift is kept for good; the shrine is done
func take_sigil(map_key: String, id: String) -> String:
	if not SIGILS.has(id):
		return ""
	var sh := shrine(map_key)
	if str(sh.get("gift", "")) != "":
		return ""
	var before_hp := max_hp()
	if typeof(state.get("sigils", null)) != TYPE_DICTIONARY:
		state["sigils"] = {}
	state["sigils"][id] = sigil(id) + 1
	sh["gift"] = id
	if id == "vit":
		hp = min(max_hp(), hp + (max_hp() - before_hp))
	elif id == "focus":
		mp = min(max_mp(), mp + float(SIGILS["focus"]["val"]))
	stats_changed.emit()
	save_game()
	var g: Dictionary = SIGILS[id]
	return t(g["name"][0], g["name"][1]) + ": " + t(g["label"][0], g["label"][1])

## a region you can walk into now (the seals of the story)
func region_open(map_key: String) -> bool:
	match map_key:
		"peaks", "shadowfen", "sanctum":
			return q(2) != "not_started"
		"emberforge":
			return brann_key()
	return true

## where the compass points for the shrines: the altar inside an unfinished shrine, else the nearest unfinished
## shrine whose region is open (fewest regions away)
func shrine_target() -> Dictionary:
	var here := str(state.get("map", "village"))
	if here.begins_with("shrine_") and not shrine_done(here):
		return {"map": here, "pos": Vector2(340, 70), "kind": "npc"}
	var best := {}
	var best_d := 999
	for k in SHRINE_ORDER:
		if shrine_done(k):
			continue
		var d := shrine_def(k)
		var parent := str(d.get("parent", ""))
		if parent == "" or not region_open(parent):
			continue
		var hops := _hops(here, parent)
		if hops < best_d:
			best_d = hops
			var ex := _shrine_exit(parent, k)
			best = {"map": parent, "pos": ex, "kind": "npc"}
	return best

## the middle of the exit from `parent` into the shrine
func _shrine_exit(parent: String, shrine_key: String) -> Vector2:
	for e in world_graph().get(parent, {}).get("exits", []):
		if str(e["to"]) == shrine_key:
			var r: Array = e["r"]
			return Vector2(float(r[0]) + float(r[2]) * 0.5, float(r[1]) + float(r[3]) * 0.5)
	return _v(shrine_def(shrine_key).get("at", [0, 0]))

## regions between two maps on the shortest walk (999 if there is no road)
func _hops(from: String, to: String) -> int:
	if from == to:
		return 0
	var g := world_graph()
	var dist := {from: 0}
	var queue := [from]
	while not queue.is_empty():
		var m: String = queue.pop_front()
		for e in g.get(m, {}).get("exits", []):
			var n := str(e["to"])
			if dist.has(n):
				continue
			dist[n] = int(dist[m]) + 1
			if n == to:
				return int(dist[n])
			queue.append(n)
	return 999

# ---------------------------------------------------------------- the Trial and elites (v0.16)
var testing := false           # set by the test runner: no random elites on the maps
var elite_rate := 0.07         # the share of ordinary foes that are elites (from level 3, outside the tests)

## state.trial = {best: most waves cleared in one run, runs: how many runs}
func trial() -> Dictionary:
	var d = state.get("trial", null)
	if typeof(d) != TYPE_DICTIONARY:
		d = {"best": 0, "runs": 0}
		state["trial"] = d
	return d

func elites_slain() -> int:
	return int(state.get("elites", 0))

func elite_def(id: String) -> Dictionary:
	return table("V16_EL").get(id, {})

func elite_name(id: String) -> String:
	var d := elite_def(id)
	return t(str(d.get("en", id)), str(d.get("fa", id)))

# ---------------------------------------------------------------- the Bounty Board (v0.15): three contracts, finish one and another appears
## state.contracts = {list: [{type, need, have, gold, xp}], claimed: n}. The pool of foes is the HTML game's (CH_HUNT_POOL);
## the amounts and the level gates are mine.
const MAP_LEVEL := {"forest": 1, "dungeon": 1, "peaks": 3, "shadowfen": 5, "sanctum": 7}

func contracts() -> Dictionary:
	var d = state.get("contracts", null)
	if typeof(d) != TYPE_DICTIONARY:
		d = {"list": [], "claimed": 0}
		state["contracts"] = d
	if typeof(d.get("list", null)) != TYPE_ARRAY:
		d["list"] = []
	return d

func contracts_done() -> int:
	return int(contracts().get("claimed", 0))

## foes a contract may ask for at the hero's level
func contract_pool() -> Array:
	var out := []
	for h in table("CH_HUNT_POOL"):
		var gate := 99
		for m in h["maps"]:
			# (v0.27.1, side-quest test: a contract sent the hero to a region the story had not opened yet)
			if region_open(str(m)):
				gate = mini(gate, int(MAP_LEVEL.get(m, 99)))
		if gate <= lvl():
			out.append(str(h["type"]))
	return out

## where the foes of a contract live (the first open region of the pool)
func contract_where(ty: String) -> String:
	for h in table("CH_HUNT_POOL"):
		if str(h["type"]) == ty:
			for m in h["maps"]:
				if region_open(str(m)):
					return map_title(str(m))
	return ""

func contract_new(avoid: Array = []) -> Dictionary:
	var pool := contract_pool()
	var cands := pool.filter(func(x): return not avoid.has(x))
	if cands.is_empty():
		cands = pool
	if cands.is_empty():
		cands = ["slime"]
	var ty: String = cands[randi() % cands.size()]
	var e := enemy_def(ty)
	var need := 5 + randi() % 6
	return {"type": ty, "need": need, "have": 0,
		"gold": need * maxi(2, int(e.get("gold", 2))) * 2 + 15,
		"xp": int(round(need * maxf(4.0, float(e.get("xp", 5))) * 1.5))}

## three contracts, always
func contract_fill() -> void:
	var c := contracts()
	var list: Array = c["list"]
	while list.size() < 3:
		var taken := []
		for x in list:
			taken.append(x["type"])
		list.append(contract_new(taken))

## a foe of this type fell: returns the text to float when a contract just finished ("" otherwise)
func contract_progress(ty: String) -> String:
	var list: Array = contracts()["list"]
	var txt := ""
	for c in list:
		if str(c["type"]) == ty and int(c["have"]) < int(c["need"]):
			c["have"] = int(c["have"]) + 1
			if int(c["have"]) >= int(c["need"]):
				txt = t("Contract complete — claim it at the board.", "قرارداد کامل شد — از تابلو دریافت کن.")
	return txt

func contract_done(c: Dictionary) -> bool:
	return int(c["have"]) >= int(c["need"])

func contract_label(c: Dictionary) -> String:
	# (v0.27.1, side-quest test: "a contract names the foe but not where it lives")
	var where := contract_where(str(c["type"]))
	if lang == "fa":
		return "%s %s را بکش" % [num(int(c["need"])), enemy_name(str(c["type"]))] + ("" if where == "" else " (%s)" % where)
	return "Slay " + enemy_name(str(c["type"])) + " ×" + str(int(c["need"])) + ("" if where == "" else " (" + where + ")")

## pay a finished contract and put a new one in its place. Returns false when it is not finished
func contract_claim(i: int) -> bool:
	var list: Array = contracts()["list"]
	if i < 0 or i >= list.size() or not contract_done(list[i]):
		return false
	var c: Dictionary = list[i]
	var g := int(round(float(c["gold"]) * gold_mul()))
	var x := int(round(float(c["xp"]) * xp_mul()))
	state["gold"] = int(state.get("gold", 0)) + g
	add_xp(x)
	contracts()["claimed"] = contracts_done() + 1
	var taken := []
	for k in list.size():
		if k != i:
			taken.append(list[k]["type"])
	list[i] = contract_new(taken)
	save_game()
	stats_changed.emit()
	return true

# ---------------------------------------------------------------- difficulty (v0.14): Normal, Hard, Nightmare
## a global setting. Foes have more health and hit harder; the rewards grow with them. The numbers are mine:
## the HTML game kept only the three names (data/Tables/V12_DIFF.json).
## (v0.23, playtest) "Story": for players who came for the tale — gentler foes, a little less reward
const DIFFS := {
	"story": {"hp": 0.7, "dmg": 0.65, "reward": 0.85},
	"normal": {"hp": 1.0, "dmg": 1.0, "reward": 1.0},
	"hard": {"hp": 1.5, "dmg": 1.3, "reward": 1.25},
	"nightmare": {"hp": 2.2, "dmg": 1.75, "reward": 1.6},
}

func diff() -> String:
	var d := str(settings.get("diff", "normal"))
	return d if DIFFS.has(d) else "normal"

func diff_mul(key: String) -> float:
	return float(DIFFS[diff()][key])

func diff_name(id: String) -> String:
	var fa: Dictionary = table("V12_DIFF")
	return t({"story": "Story", "normal": "Normal", "hard": "Hard", "nightmare": "Nightmare"}.get(id, id), str(fa.get(id, id)))

# ---------------------------------------------------------------- Jamshid the Exile (v0.13): the Warden Core, the Kindling Key, the Forge
## state.brann: none -> core (Warden Core in hand) -> anvil (key given, the Forge door open) -> anvil_done -> ignarok -> ignarok_done -> done
const Story = preload("res://scripts/story.gd")

func brann() -> String:
	return str(state.get("brann", "none"))

func brann_set(st: String) -> void:
	state["brann"] = st
	save_game()
	stats_changed.emit()

## the world moves ahead of the questline now and then (old saves, a boss killed early): catch up
func brann_sync() -> String:
	var st := brann()
	if st == "none" and is_defeated("boss"):
		st = "core"
	if st == "anvil" and is_defeated("anvilward"):
		st = "anvil_done"
	if st == "ignarok" and is_defeated("ignarok"):
		st = "ignarok_done"
	if st != brann():
		state["brann"] = st
	return st

## the Kindling Key opens the Peaks door
func brann_key() -> bool:
	return ["anvil", "anvil_done", "ignarok", "ignarok_done", "done"].has(brann_sync())

## "" when there is nothing to do with the questline right now
func brann_objective() -> String:
	match brann_sync():
		"core":
			return Story.line("o_core")
		"anvil":
			return Story.line("o_anvil")
		"anvil_done", "ignarok_done":
			return Story.line("o_anvil_back")
		"ignarok":
			return Story.line("o_ign")
	return ""

func brann_target() -> Dictionary:
	var g := world_graph()
	match brann_sync():
		"core", "anvil_done", "ignarok_done":
			return {"map": "village", "pos": _v(g.get("village", {}).get("npcs", {}).get("brann", [213, 504])), "kind": "npc"}
		"anvil":
			return {"map": "emberforge", "pos": _v(g.get("emberforge", {}).get("bosses", {}).get("anvilward", [643, 950])), "kind": "boss"}
		"ignarok":
			return {"map": "emberforge", "pos": _v(g.get("emberforge", {}).get("bosses", {}).get("ignarok", [656, 234])), "kind": "boss"}
	return {}

## Jamshid's turn-in: what he says, and (done afterwards) what he gives. Returns the lines, or [] when he has nothing new
func brann_lines() -> Array:
	var ids := []
	match brann_sync():
		"core":
			ids = ["d_core1", "d_core2", "d_core3", "d_core4"]
		"anvil":
			ids = ["d_anvil"]
		"anvil_done":
			ids = ["d_ab1", "d_ab2", "d_ab3"]
		"ignarok":
			ids = ["d_ign"]
		"ignarok_done":
			ids = ["d_ib1", "d_ib2", "d_ib3"]
		"done":
			ids = ["d_done"]
	var out := []
	for id in ids:
		out.append(Story.line(id))
	return out

## the reward for the step just spoken. Returns the toast text ("" when none)
func brann_step() -> String:
	match brann_sync():
		"core":
			brann_set("anvil")
			return Story.line("key_got")
		"anvil_done":
			state["gold"] = int(state.get("gold", 0)) + 350
			forge()["w"] = maxi(forge_level("w"), 1)
			forge()["a"] = maxi(forge_level("a"), 1)
			brann_set("ignarok")
			return Story.line("reward1")
		"ignarok_done":
			forge()["w"] = mini(FORGE_MAX, forge_level("w") + 2)
			forge()["a"] = mini(FORGE_MAX, forge_level("a") + 2)
			state["bonus_talents"] = int(state.get("bonus_talents", 0)) + 3
			brann_set("done")
			return Story.line("reward2")
	return ""

# ---------------------------------------------------------------- the forge (v0.12): Kavian refines what you carry
const FORGE_MAX := 5
const FORGE_ATK := 2.0          # per weapon level
const FORGE_DEF := 1.0          # per armor level

func forge() -> Dictionary:
	var d = state.get("forge", null)
	if typeof(d) != TYPE_DICTIONARY:
		d = {"w": 0, "a": 0}
		state["forge"] = d
	return d

func forge_level(kind: String) -> int:
	return int(forge().get(kind, 0))

## what the next level of "w" (weapon) or "a" (armor) costs; {} at the maximum
func forge_cost(kind: String) -> Dictionary:
	var lv := forge_level(kind) + 1
	if lv > FORGE_MAX:
		return {}
	return {"herb": lv, "essence": (lv + 1) / 2, "obsidian": maxi(0, lv - 3), "gold": 40 * lv}

## "" when the upgrade can be paid, else "max" or what is missing
func forge_block(kind: String) -> String:
	var c := forge_cost(kind)
	if c.is_empty():
		return "max"
	if herbs() < int(c["herb"]):
		return "herb"
	if essence() < int(c["essence"]):
		return "essence"
	if int(state.get("obsidian", 0)) < int(c["obsidian"]):
		return "obsidian"
	if int(state.get("gold", 0)) < int(c["gold"]):
		return "gold"
	return ""

func forge_upgrade(kind: String) -> bool:
	if forge_block(kind) != "":
		return false
	var c := forge_cost(kind)
	state["herbs"] = herbs() - int(c["herb"])
	state["essence"] = essence() - int(c["essence"])
	state["obsidian"] = int(state.get("obsidian", 0)) - int(c["obsidian"])
	state["gold"] = int(state.get("gold", 0)) - int(c["gold"])
	forge()[kind] = forge_level(kind) + 1
	save_game()
	stats_changed.emit()
	return true

func forge_item_name(kind: String) -> String:
	if kind == "w":
		var w: Dictionary = table("WEAPON_TIERS").get(str(int(state.get("weapon", 0))), {})
		return t(str(w.get("name", "Fists")), t_tier_fa(str(w.get("name", "Fists"))))
	var a: Dictionary = table("ARMOR_TIERS").get(str(int(state.get("armor", 0))), {})
	return t(str(a.get("name", "None")), t_tier_fa(str(a.get("name", "None"))))

func t_tier_fa(en: String) -> String:
	return t(en)

# ---------------------------------------------------------------- alchemy (v0.11): herbs, essence, brewing, scrolls
const SCROLL_IDS := ["fire", "ice", "regen", "frost", "haste"]

func herbs() -> int:
	return int(state.get("herbs", 0))

func essence() -> int:
	return int(state.get("essence", 0))

func scrolls() -> Dictionary:
	var d = state.get("scrolls", null)
	if typeof(d) != TYPE_DICTIONARY:
		d = {}
		state["scrolls"] = d
	return d

func scroll_count(id: String) -> int:
	return int(scrolls().get(id, 0))

## the scroll the button casts: the one picked in the Gear tab, or the first one you own
func scroll_sel() -> String:
	var sel := str(state.get("scroll_sel", ""))
	if sel != "" and scroll_count(sel) > 0:
		return sel
	for id in SCROLL_IDS:
		if scroll_count(id) > 0:
			return id
	return ""

func scroll_name(id: String) -> String:
	var r := recipe(id + "_scroll")
	return craft_name(r) if not r.is_empty() else id

func recipes() -> Array:
	return table("RECIPES")

func recipe(id: String) -> Dictionary:
	for r in recipes():
		if str(r["id"]) == id:
			return r
	return {}

func craft_name(r: Dictionary) -> String:
	var f: Array = table("V12_CRAFT").get(str(r["id"]), [])
	return t(str(r["name"]), str(f[0]) if f.size() > 0 else str(r["name"]))

func craft_desc(r: Dictionary) -> String:
	var f: Array = table("V12_CRAFT").get(str(r["id"]), [])
	return t(str(r["desc"]).strip_edges(), str(f[1]) if f.size() > 1 else str(r["desc"]))

func craft_owned(r: Dictionary) -> int:
	var ty := str(r["result"]["type"])
	match ty:
		"potion":
			return int(state.get("potions", 0))
		"mana_potion":
			return int(state.get("mana_potions", 0))
		"greater_potion":
			return int(state.get("greater", 0))
	return scroll_count(ty.trim_suffix("_scroll"))

## "" when the recipe can be brewed, else what is missing: herb, essence or gold
func craft_block(id: String) -> String:
	var r := recipe(id)
	if r.is_empty():
		return "none"
	var c: Dictionary = r["cost"]
	if herbs() < int(c.get("herb", 0)):
		return "herb"
	if essence() < int(c.get("essence", 0)):
		return "essence"
	if int(state.get("gold", 0)) < int(r.get("gold", 0)):
		return "gold"
	return ""

func craft(id: String) -> bool:
	if craft_block(id) != "":
		return false
	var r := recipe(id)
	var c: Dictionary = r["cost"]
	state["herbs"] = herbs() - int(c.get("herb", 0))
	state["essence"] = essence() - int(c.get("essence", 0))
	state["gold"] = int(state.get("gold", 0)) - int(r.get("gold", 0))
	var n := int(r["result"].get("n", 1))
	var ty := str(r["result"]["type"])
	match ty:
		"potion":
			state["potions"] = int(state.get("potions", 0)) + n
		"mana_potion":
			state["mana_potions"] = int(state.get("mana_potions", 0)) + n
		"greater_potion":
			state["greater"] = int(state.get("greater", 0)) + n
		_:
			var sid := ty.trim_suffix("_scroll")
			scrolls()[sid] = scroll_count(sid) + n
	Ach.add("crafts")
	save_game()
	stats_changed.emit()
	return true

## a scroll was read: false when there is none
func spend_scroll(id: String) -> bool:
	if scroll_count(id) <= 0:
		return false
	scrolls()[id] = scroll_count(id) - 1
	save_game()
	stats_changed.emit()
	return true

## swamp and forest creatures sometimes leave a herb behind
func herb_drop(map_key: String) -> bool:
	var chance: float = {"shadowfen": 0.12, "forest": 0.05}.get(map_key, 0.02)
	if randf() < chance:
		state["herbs"] = herbs() + 1
		return true
	return false

# ---------------------------------------------------------------- things lying about the maps (v0.10)
## the hero walked over one: returns the toast text ("" when nothing happened). `key` = "map:index", remembered so it is not found twice
func collect(kind: String, key: String) -> String:
	var picked: Array = state.get("picked", [])
	if picked.has(key):
		return ""
	picked.append(key)
	state["picked"] = picked
	var txt := ""
	match kind:
		"potion":
			state["potions"] = int(state.get("potions", 0)) + 1
			txt = t("+1 Health Potion", "+۱ معجون جان")
		"mana_potion":
			state["mana_potions"] = int(state.get("mana_potions", 0)) + 1
			txt = t("+1 Mana Potion", "+۱ معجون مانا")
		"greater_potion":
			state["greater"] = int(state.get("greater", 0)) + 1
			txt = t("+1 Greater Potion", "+۱ معجون بزرگ")
		"herb":
			state["herbs"] = int(state.get("herbs", 0)) + 1
			txt = t("+1 Bogbloom", "+۱ گلِ مرداب")
		"obsidian":
			state["obsidian"] = int(state.get("obsidian", 0)) + 1
			txt = t("+1 Obsidian shard", "+۱ تکه شَبَه")
		"frost_scroll":
			scrolls()["frost"] = scroll_count("frost") + 1
			txt = t("+1 Scroll: Frost Lance", "+۱ طومار: نیزهٔ سرما")
		"relic":
			Gear.grant(Gear.roll("rare"))
			txt = "-"
		"relic_frost", "relic_essence":
			Gear.grant(Gear.roll("epic"))
			txt = "-"
		"page1", "page2", "page3":
			txt = Ch2.take_page(int(kind.substr(4)))
		"chest":
			var g := int(round(120.0 * gold_mul()))
			state["gold"] = int(state.get("gold", 0)) + g
			Gear.grant(Gear.roll("rare"))
			txt = t("The chest holds %d gold!" % g, "صندوق %s سکه داشت!" % num(g))
		_:
			picked.erase(key)
			return ""
	save_game()
	stats_changed.emit()
	return txt

# ---------------------------------------------------------------- side quest: Thornwood Toll (Sindokht's strongbox, v0.9)
## state.toll = {st: none | active | box | done, how: how the box was won, ledger: has Ashkbus's ledger, truce: a deal was struck}
func toll() -> Dictionary:
	var d = state.get("toll", null)
	if typeof(d) != TYPE_DICTIONARY:
		d = {"st": "none", "how": "", "ledger": false, "truce": false}
		state["toll"] = d
	return d

func toll_st() -> String:
	return str(toll().get("st", "none"))

func toll_set(st: String, how := "") -> void:
	var d := toll()
	d["st"] = st
	if how != "":
		d["how"] = how
	save_game()
	stats_changed.emit()

## Sindokht's friends' price (-20%) once the quest is done
func friends_price() -> bool:
	return toll_st() == "done"

# ---------------------------------------------------------------- where to go next (quest compass, minimap, world map)
var _graph := {}

## every region's size, exits, villagers and bosses (data/world_graph.json, made from the map files)
func world_graph() -> Dictionary:
	if _graph.is_empty():
		var g = _json(DATA + "world_graph.json")
		_graph = g if typeof(g) == TYPE_DICTIONARY else {}
	return _graph

## the place the current objective points at: {"map", "pos", "kind": "npc" | "boss"} or {} when free to explore
func quest_target() -> Dictionary:
	var tt: Dictionary = Tut.target()      # (v0.24) Rostam's yard first, while the training is offered or under way
	if not tt.is_empty():
		return tt
	if not rush.is_empty():
		return {}
	var g := world_graph()
	var elder := {"map": "village", "pos": _v(g.get("village", {}).get("npcs", {}).get("elder", [443, 334])), "kind": "npc"}
	if q(1) == "complete" or q(2) == "complete" or q(3) == "complete":
		return elder            # (v0.24) as the objective: Zal's reward first
	if ["core", "anvil_done", "ignarok_done"].has(brann_sync()):
		return brann_target()
	if q(1) == "not_started" or q(1) == "complete" or q(2) == "complete" or q(3) == "complete":
		return elder
	if q(1) == "active":
		return {"map": "dungeon", "pos": _v(g.get("dungeon", {}).get("bosses", {}).get("boss", [874, 708])), "kind": "boss"}
	if q(2) == "not_started":
		return elder
	if q(2) == "active":
		return {"map": "peaks", "pos": _v(g.get("peaks", {}).get("bosses", {}).get("boss2", [588, 186])), "kind": "boss"}
	if q(3) == "not_started":
		return elder
	if q(3) == "active":
		return {"map": "shadowfen", "pos": _v(g.get("shadowfen", {}).get("bosses", {}).get("matriarch", [700, 180])), "kind": "boss"}
	var c2t: Dictionary = Ch2.target()
	if not c2t.is_empty():
		return c2t
	var c3t: Dictionary = Ch3.target()
	if not c3t.is_empty() and Ch3.step() != "":
		return c3t
	if brann_objective() != "":
		return brann_target()
	if toll_st() == "active":
		return {"map": "camp", "pos": _v(g.get("camp", {}).get("bosses", {}).get("captain", [600, 430])), "kind": "boss"}
	if toll_st() == "box":
		return {"map": "village", "pos": _v(g.get("village", {}).get("npcs", {}).get("merchant", [313, 214])), "kind": "npc"}
	if not c3t.is_empty():
		return c3t
	return shrine_target()

static func _v(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if typeof(a) == TYPE_ARRAY and a.size() >= 2 else Vector2.ZERO

## the next region on the shortest walk from `from` to `to` ("" if none)
func next_hop(from: String, to: String) -> String:
	if from == to:
		return to
	var g := world_graph()
	var prev := {from: ""}
	var queue := [from]
	while not queue.is_empty():
		var m: String = queue.pop_front()
		for e in g.get(m, {}).get("exits", []):
			var n := str(e["to"])
			if prev.has(n):
				continue
			prev[n] = m
			if n == to:
				var step := n
				while prev[step] != from:
					step = prev[step]
				return step
			queue.append(n)
	return ""

## where the compass points in `map`: the target itself, or the exit towards it; {} when nowhere
func compass_point(map: String) -> Dictionary:
	var t := quest_target()
	if t.is_empty():
		return {}
	if t["map"] == map:
		return {"pos": t["pos"], "kind": t["kind"], "exit": false}
	var hop := next_hop(map, str(t["map"]))
	for e in world_graph().get(map, {}).get("exits", []):
		if str(e["to"]) == hop:
			var r: Array = e["r"]
			return {"pos": Vector2(float(r[0]) + float(r[2]) * 0.5, float(r[1]) + float(r[3]) * 0.5), "kind": "exit", "exit": true, "to": hop}
	return {}

# ---------------------------------------------------------------- shops
func shop_items(vendor: String) -> Array:
	var out := []
	var shop: Dictionary = table("SHOPS").get(vendor, {})
	var owned := int(state.get("weapon" if vendor == "merchant" else "armor", 0))
	for it in shop.get("items", []):
		if it.has("tier"):
			if owned >= int(it["tier"]):
				continue
			if it.has("requires") and owned < int(it["requires"]):
				continue
		out.append(it)
	return out

func buy(vendor: String, it: Dictionary) -> String:
	var price := int(it.get("price", 0))
	if int(state.get("gold", 0)) < price:
		return ""
	if it.has("tier") and int(it["tier"]) != int(state.get("weapon" if vendor == "merchant" else "armor", 0)) + 1:
		return ""
	state["gold"] = int(state["gold"]) - price
	var id := str(it.get("id", ""))
	if id == "hp_potion":
		state["potions"] = int(state.get("potions", 0)) + 1
	elif id == "mp_potion":
		state["mana_potions"] = int(state.get("mana_potions", 0)) + 1
	elif id == "greater_potion":
		state["greater"] = int(state.get("greater", 0)) + 1
	elif it.has("tier"):
		state["weapon" if vendor == "merchant" else "armor"] = int(it["tier"])
	save_game()
	stats_changed.emit()
	return t("Bought %s." % it.get("name", ""), "%s خریدی." % t(str(it.get("name", ""))))

## every item a vendor has, with its state for the shop cards: "buy" (potions), "owned", "next", "locked"
func shop_catalog(vendor: String) -> Array:
	var out := []
	var shop: Dictionary = table("SHOPS").get(vendor, {})
	var owned := int(state.get("weapon" if vendor == "merchant" else "armor", 0))
	for it in shop.get("items", []):
		var st := "buy"
		if it.has("tier"):
			var tier := int(it["tier"])
			if owned >= tier:
				st = "owned"
			elif tier == owned + 1:
				st = "next"
			else:
				st = "locked"
		var e: Dictionary = it.duplicate()
		e["state"] = st
		if vendor == "merchant" and friends_price() and e.has("price"):
			e["price"] = max(1, int(round(float(e["price"]) * 0.8)))
		out.append(e)
	return out

# ---------------------------------------------------------------- saving
## whole-number fields of the saved state (load_game turns JSON's floats back into ints)
const INT_KEYS := ["level", "xp", "xp_next", "gold", "potions", "mana_potions", "greater", "weapon", "armor", "herbs", "essence",
	"obsidian", "elites", "ng"]

func save_game() -> void:
	write_safe(SAVE_PATH, JSON.stringify({"v": 2, "cls": cls, "state": state, "hp": hp, "mp": mp}))
	Ach.save_if_dirty()

## (v0.27, engineering: "Android kills the app while the save is written: the file is left empty, Continue starts a new
## game and saves over it") written to a side file first, then put in place; the last good file is kept as .bak
static func write_safe(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(tmp) != text:
		return false
	if FileAccess.file_exists(path) and typeof(_parse_quiet(FileAccess.get_file_as_string(path))) == TYPE_DICTIONARY:
		DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path) == OK

## the file's JSON, or its .bak's when the file is damaged
static func read_safe(path: String) -> Variant:
	for p in [path, path + ".bak"]:
		if FileAccess.file_exists(p):
			var d = _parse_quiet(FileAccess.get_file_as_string(p))
			if typeof(d) == TYPE_DICTIONARY:
				return d
	return null

## JSON without an error in the log when the text is broken (a cut save is expected, not an engine error)
static func _parse_quiet(text: String) -> Variant:
	var j := JSON.new()
	return j.data if j.parse(text) == OK else null

func has_save() -> bool:
	return typeof(read_safe(SAVE_PATH)) == TYPE_DICTIONARY

func load_game() -> bool:
	if not has_save():
		return false
	var d = read_safe(SAVE_PATH)
	if typeof(d) != TYPE_DICTIONARY or not d.has("state"):
		return false
	cls = d.get("cls", "warrior")
	state = d["state"]
	# (v0.23) JSON gives every number back as a float: the counts and tiers are whole numbers again (a weapon tier read as
	# "1.0" found no row in WEAPON_TIERS, so after a reload the hero lost his weapon's attack and his armour's defence)
	for k in INT_KEYS:
		if state.has(k) and typeof(state[k]) == TYPE_FLOAT:
			state[k] = int(state[k])
	hp = float(d.get("hp", max_hp()))
	if hp <= 0.0:          # saved while the "You have fallen" panel was open
		hp = max_hp()
	mp = clamp(float(d.get("mp", max_mp())), 0.0, max_mp())
	# a hero saved before v0.6: no talents yet (all his points are free), default spell buttons
	talents()
	slots()
	if not state.has("mana_potions"):
		state["mana_potions"] = 1
	fight = {}
	rush = {}
	Rush.restore_kept()        # (v0.21) a Boss Rush cut short by quitting gives back what it set aside
	return true

func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH) or FileAccess.file_exists(SETTINGS_PATH + ".bak"):
		var d = read_safe(SETTINGS_PATH)
		if typeof(d) == TYPE_DICTIONARY:
			lang = d.get("lang", "fa")
			for k in settings:
				if d.has(k):
					settings[k] = d[k]
	_apply_settings()

func _save_settings() -> void:
	var d := settings.duplicate()
	d["lang"] = lang
	write_safe(SETTINGS_PATH, JSON.stringify(d))

func set_setting(k: String, v) -> void:
	settings[k] = v
	_apply_settings()
	_save_settings()
	settings_changed.emit()

func _apply_settings() -> void:
	var sfx = get_node_or_null("/root/Sfx")
	if sfx:
		sfx.muted = not bool(settings.get("sound", true))
		sfx.apply_volume()
	var mu = get_node_or_null("/root/Music")
	if mu:
		mu.apply_volume()

func ui_scale() -> float:
	return float(UI_SCALES[clamp(int(settings.get("ui", 1)), 0, 2)])

func cam_zoom() -> float:
	return float(CAM_ZOOMS[clamp(int(settings.get("cam", 1)), 0, 2)])

# ---------------------------------------------------------------- setup
func _setup_font() -> void:
	var base = load("res://assets/fonts/vazir_latin.woff2")
	var ar = load("res://assets/fonts/vazir_arabic.woff2")
	if base is Font and ar is Font:
		var fb: Array[Font] = [ar]
		base.fallbacks = fb
		ThemeDB.fallback_font = base
		ThemeDB.fallback_font_size = 15

func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"attack": [KEY_SPACE, KEY_J], "dodge": [KEY_V, KEY_K], "potion": [KEY_Q], "interact": [KEY_E],
		"skill1": [KEY_SHIFT, KEY_1, KEY_L], "skill2": [KEY_X, KEY_2, KEY_I], "ult": [KEY_R, KEY_3, KEY_U], "mana": [KEY_T], "block": [KEY_C, KEY_N], "sneak": [KEY_Z, KEY_CTRL], "scroll": [KEY_V, KEY_B], "shove": [KEY_F, KEY_H],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)

extends RefCounted
## (v0.20) Achievements (`Game.Ach`, static). The HTML game's 21 (ACHIEVEMENTS.json, Persian names from V12_ACH.json) and
## the port's own, for what the port added (the Toll, the forge, the shrines, the bounty board, the elites, Jamshid, chapter 2,
## Hom). They live in a profile apart from the save (user://profile.json), as the HTML game kept them in its own storage:
## what was earned stays through a new game (and New Game+). Some unlock a hero look (scripts/looks.gd).
##   add(stat, n)  — a lifetime counter (kills, crits, parries, dodges, crafts, backstabs, ults, boss_kills) and what it unlocks
##   check()       — the ones read from the save (level, gold, bosses defeated, quests...); Game.stats_changed calls it
##   unlock(id)    — Game.achieved(id) is emitted and the HUD shows the card
##   sync()        — at the start of a session: counts what an older save already did (quietly) and returns how many
## Profile: {"v": 1, "ach": {id: unix time}, "stats": {name: n}, "look": look id, "new": [ids not looked at yet]}

const PATH := "user://profile.json"
const TEST_PATH := "user://profile_test.json"     # the test runs never touch a player's profile

## [id, icon, name en, name fa, description en, description fa, counter ("" = read from the save), need, secret]
const LIST := [
	["first_blood", "sword", "First Blood", "نخستین خون", "Defeat your first enemy", "نخستین دشمنت را شکست بده", "kills", 1, false],
	["slayer", "swords", "Slayer", "شکارچی", "Defeat 50 enemies", "۵۰ دشمن را شکست بده", "kills", 50, false],
	["exterminator", "skull", "Exterminator", "نابودگر", "Defeat 200 enemies", "۲۰۰ دشمن را شکست بده", "kills", 200, false],
	["boss_slayer", "trophy", "Boss Slayer", "سرکرده‌کُش", "Defeat your first boss", "نخستین سرکرده را شکست بده", "boss_kills", 1, false],
	["boss_master", "crown", "Boss Master", "استاد سرکرده‌ها", "Defeat 5 bosses", "۵ سرکرده را شکست بده", "boss_kills", 5, false],
	["untouched", "shield", "Untouched", "بی‌زخم", "Defeat a boss without taking damage", "سرکرده‌ای را بی‌آنکه آسیب ببینی شکست بده", "", 1, false],
	["rich", "coins", "Rich", "ثروتمند", "Hold 1000 gold at once", "۱۰۰۰ سکه یک‌جا داشته باش", "", 1000, false],
	["apprentice", "star", "Apprentice", "شاگرد", "Reach level 10", "به سطح ۱۰ برس", "", 10, false],
	["veteran", "medal", "Veteran", "کارکشته", "Reach level 20", "به سطح ۲۰ برس", "", 20, false],
	["master", "award", "Master", "استاد", "Reach level 35", "به سطح ۳۵ برس", "", 35, false],
	["crit_master", "zap", "Critical Master", "استاد ضربهٔ کاری", "Land 50 critical hits", "۵۰ ضربهٔ کاری بزن", "crits", 50, false],
	["first_ult", "sparkles", "Ultimate Power", "قدرت نهایی", "Use your first Ultimate", "نخستین ضربهٔ نهایی‌ات را بزن", "ults", 1, false],
	["frost_heart", "snowflake", "Frost Heart", "قلب یخ", "Have Jamshid forge Akvan's frost-heart", "بگذار جمشید قلبِ یخیِ اکوان دیو را به فولاد بدل کند", "", 1, false],
	["parry_master", "shield-half", "Parry Master", "استاد دفع", "Land 20 perfect parries", "۲۰ بار دفاعِ بی‌نقص کن", "parries", 20, false],
	["dodge_master", "wind", "Shadow Step", "گام سایه", "Dodge 30 times", "۳۰ بار جاخالی بده", "dodges", 30, false],
	["alchemist", "flask-conical", "Alchemist", "کیمیاگر", "Craft 10 items", "۱۰ چیز بساز", "crafts", 10, false],
	["champion", "flame", "Champion", "قهرمان", "Defeat the King of Mazandaran", "شاه مازندران را شکست بده", "", 1, false],
	["legend", "droplets", "Legend", "افسانه", "Defeat the Sorceress", "زنِ جادو را شکست بده", "", 1, false],
	["frost_slayer", "mountain-snow", "Winter Born", "زادهٔ زمستان", "Defeat the White Div", "دیو سپید را شکست بده", "", 1, false],
	["wyrm_slayer", "flame-kindling", "Wyrmslayer", "اژدهاکُش", "Defeat the Dragon of Kashaf", "اژدهای کشف‌رود را شکست بده", "", 1, true],
	["trial10", "castle", "Ashen Veteran", "کهنه‌سربازِ خاکستر", "Clear 10 waves in the Trial of Embers", "۱۰ موج در آزمونِ اخگر را پشت سر بگذار", "", 10, false],
	# ---- the port's own
	["ignarok", "flame-kindling", "The First Flame", "شعلهٔ نخستین", "Defeat Puladvand in the Emberforge", "پولادوند را در آهنگرخانهٔ اخگر شکست بده", "", 1, false],
	["titan", "gem", "Glacier Breaker", "یخ‌کوه‌شکن", "Defeat Akvan the Div", "اکوان دیو را شکست بده", "", 1, false],
	["toll_ghost", "ghost", "Phantom of Thornwood", "شبحِ خارزار", "Take back Sindokht's strongbox without being seen", "صندوقچهٔ سیندخت را بی‌آنکه دیده شوی پس بگیر", "", 1, false],
	["toll_words", "message-circle", "Sweet-Spoken", "شیرین‌سخن", "Settle the Thornwood Toll with words, not steel", "باجِ خارزار را با زبان حل کن، نه با شمشیر", "", 1, false],
	["forge_max", "anvil", "Master Smith", "استادِ آهنگری", "Forge your weapon and your armour to +5", "سلاح و زره‌ات را تا +۵ ارتقا بده", "", 10, false],
	["shrines7", "sparkle", "Seeker of Sigils", "جویندهٔ نشان‌ها", "Complete all seven ancient shrines", "هر هفت زیارتگاهِ کهن را کامل کن", "", 7, false],
	["bounty25", "target", "Wayfarer", "رهسپار", "Complete 25 bounty contracts", "۲۵ قرارداد از تابلوی جایزه انجام بده", "", 25, false],
	["elite25", "crosshair", "Elite Hunter", "شکارچیِ نخبه‌ها", "Slay 25 elite foes", "۲۵ دشمنِ نخبه را بکش", "", 25, false],
	["backstab25", "eye", "Silent Blade", "تیغِ خاموش", "Land 25 backstabs while sneaking", "در حالت پنهان‌کاری ۲۵ ضربه از پشت بزن", "backstabs", 25, false],
	["brann", "hammer", "Jamshid's Debt", "دینِ جمشید", "Finish the tale of the Shade of Jamshid", "داستانِ روانِ جمشید را به پایان برسان", "", 1, false],
	["hesk", "dog", "Friend of the Trapper", "دوستِ تله‌گذار", "Finish both of Hom's tasks", "هر دو کارِ هوم را انجام بده", "", 2, false],
	["legendary", "gem", "Legendary Find", "یافتهٔ افسانه‌ای", "Find a legendary accessory", "یک زیورِ افسانه‌ای پیدا کن", "", 1, false],
	# ---- (v0.21) the Boss Rush and New Game+
	["rush", "swords", "Keeper of Battles", "نگهبانِ نبردها", "Clear the Boss Rush: all seven battles remembered", "نبردهای به‌یادمانده را کامل کن: هر هفت نبرد", "", 1, false],
	["rush_fast", "hourglass", "Memory Unbroken", "یادِ ناگسسته", "Clear the Boss Rush in under seven minutes", "نبردهای به‌یادمانده را در کمتر از هفت دقیقه کامل کن", "", 1, false],
	["rush_clean", "flask-conical", "Without a Draught", "بی‌جرعه", "Clear the Boss Rush without drinking a potion", "نبردهای به‌یادمانده را بی‌آنکه معجونی بنوشی کامل کن", "", 1, false],
	["ng_start", "book-open", "A Twice-Told Tale", "داستانِ دوباره", "Begin New Game+", "بازیِ نو+ را آغاز کن", "", 1, false],
	["ng_wyrm", "flame", "Ashen Saint", "پارسای خاکستر", "Defeat the Dragon of Kashaf in New Game+", "اژدهای کشف‌رود را در بازیِ نو+ شکست بده", "", 1, false],
	# (v0.23) chapter 3: the Chains of Damavand
	["kaviani", "flag", "The Smith's Banner", "درفشِ آهنگر", "Raise the Derafsh-e Kaviani again", "درفشِ کاویانی را دوباره برافراز", "", 1, false],
	["altars", "flame", "Three Fires", "سه آتش", "Light the fire temple's three altars on Damavand together", "سه آتشدانِ آتشکدهٔ دماوند را با هم روشن کن", "", 1, false],
	["zahhak", "mountain", "Bound in Damavand", "در بندِ دماوند", "Overcome Zahhak and bind him to the mountain", "ضحاک را شکست بده و به کوه ببند", "", 1, true],
	["completionist", "crown", "Gilded Sovereign", "شهریارِ زرین", "Earn every other achievement", "همهٔ دستاوردهای دیگر را به دست بیاور", "", 1, false],
]

static var prof := {}
static var _loaded := false
static var _dirty := false
static var _by_id := {}
static var quiet := false          # sync(): unlock without the cards

static func path() -> String:
	return TEST_PATH if Game.testing else PATH

static func load_profile() -> void:
	_loaded = true
	prof = {}
	var d = Game.read_safe(path())
	if typeof(d) == TYPE_DICTIONARY:
		prof = d
	for k in ["ach", "stats"]:
		if typeof(prof.get(k)) != TYPE_DICTIONARY:
			prof[k] = {}
	if typeof(prof.get("new")) != TYPE_ARRAY:
		prof["new"] = []
	if not prof.has("look"):
		prof["look"] = "ember"
	prof["v"] = 1

static func p() -> Dictionary:
	if not _loaded:
		load_profile()
	return prof

static func save() -> void:
	if Game.write_safe(path(), JSON.stringify(p())):
		_dirty = false

static func save_if_dirty() -> void:
	if _dirty:
		save()

## tests: start from nothing
static func reset() -> void:
	prof = {}
	_loaded = true
	load_profile()
	prof = {"v": 1, "ach": {}, "stats": {}, "look": "ember", "new": []}
	save()

static func entry(id: String) -> Array:
	if _by_id.is_empty():
		for e in LIST:
			_by_id[e[0]] = e
	return _by_id.get(id, [])

static func ids() -> Array:
	return LIST.map(func(e): return e[0])

static func has(id: String) -> bool:
	return p()["ach"].has(id)

static func count() -> int:
	return p()["ach"].size()

static func total() -> int:
	return LIST.size()

static func stat(n: String) -> int:
	return int(p()["stats"].get(n, 0))

static func title(id: String) -> String:
	var e := entry(id)
	return Game.t(e[2], e[3]) if not e.is_empty() else id

static func desc(id: String) -> String:
	var e := entry(id)
	if e.is_empty():
		return ""
	if e[8] and not has(id):
		return Game.t("A secret — keep going.", "رازی است — ادامه بده.")
	return Game.t(e[4], e[5])

static func icon(id: String) -> String:
	var e := entry(id)
	return str(e[1]) if not e.is_empty() else "trophy"

## [have, need] for the list's progress bars
static func progress(id: String) -> Array:
	var e := entry(id)
	if e.is_empty():
		return [0, 1]
	var need := int(e[7])
	if has(id):
		return [need, need]
	var have := 0
	if str(e[6]) != "":
		have = stat(str(e[6]))
	else:
		have = _have(id)
	return [mini(have, need), need]

## a lifetime counter went up
static func add(n: String, by := 1) -> void:
	var s: Dictionary = p()["stats"]
	s[n] = int(s.get(n, 0)) + by
	_dirty = true
	for e in LIST:
		if str(e[6]) == n and not has(e[0]) and int(s[n]) >= int(e[7]):
			unlock(e[0])

## a counter that can be set from the save (an older save that already did more than the profile knows)
static func at_least(n: String, v: int) -> void:
	if stat(n) < v:
		p()["stats"][n] = v
		_dirty = true

static func unlock(id: String) -> void:
	if has(id) or entry(id).is_empty():
		return
	p()["ach"][id] = int(Time.get_unix_time_from_system())
	if not id in p()["new"]:
		p()["new"].append(id)
	_dirty = true
	if not quiet:
		Game.achieved.emit(id)
	if id != "completionist" and not has("completionist"):
		var all := true
		for e in LIST:
			if e[0] != "completionist" and not has(e[0]):
				all = false
				break
		if all:
			unlock("completionist")
	save()

## what the save says, for the achievements that are not counters
static func _have(id: String) -> int:
	if Game.state.is_empty():
		return 0
	var d: Dictionary = Game.state.get("defeated", {})
	match id:
		"rich": return int(Game.state.get("gold", 0))
		"apprentice", "veteran", "master": return Game.lvl()
		"frost_heart": return 1 if str(Game.Ch2.st().get("heart", "none")) == "forged" else 0
		"champion": return 1 if d.has("boss2") else 0
		"legend": return 1 if d.has("matriarch") else 0
		"frost_slayer": return 1 if d.has("arbiter") else 0
		"wyrm_slayer": return 1 if d.has("ancientwyrm") else 0
		"ignarok": return 1 if d.has("ignarok") else 0
		"titan": return 1 if d.has("glaciertitan") else 0
		"trial10": return int(Game.trial().get("best", 0))
		"toll_ghost": return 1 if Game.toll_st() == "done" and str(Game.toll().get("how", "")) == "ghost" else 0
		"toll_words": return 1 if Game.toll_st() == "done" and str(Game.toll().get("how", "")) in ["fame", "oath", "hand", "ledger"] else 0
		"forge_max": return mini(Game.forge_level("w"), Game.FORGE_MAX) + mini(Game.forge_level("a"), Game.FORGE_MAX)
		"shrines7": return Game.shrines_done()
		"bounty25": return Game.contracts_done()
		"elite25": return Game.elites_slain()
		"brann": return 1 if Game.brann() == "done" else 0
		"hesk":
			var h: Dictionary = Game.Ch2.hesk()
			return (1 if h.get("wolves_st", "") == "done" else 0) + (1 if h.get("pages_st", "") == "done" else 0)
		"legendary": return 1 if _legendary() else 0
		"untouched", "completionist", "rush", "rush_fast", "rush_clean": return 0
		"ng_start": return 1 if Game.ng() > 0 else 0
		"ng_wyrm": return 1 if Game.ng() > 0 and d.has("ancientwyrm") else 0
		"kaviani": return 1 if bool(Game.Ch3.st().get("banner", false)) else 0
		"altars": return 1 if bool(Game.Ch3.st().get("altars_lit", false)) else 0
		"zahhak": return 1 if d.has("zahhak") else 0
	return 0

static func _legendary() -> bool:
	var g = Game.state.get("gear", {})
	if typeof(g) != TYPE_DICTIONARY:
		return false
	var items := []
	for k in g.get("eq", {}):
		items.append(g["eq"][k])
	items.append_array(g.get("bag", []))
	for it in items:
		if typeof(it) == TYPE_DICTIONARY and str(it.get("rarity", "")) == "legendary" and not bool(it.get("relic", false)):
			return true
	return false

## the ones the save decides: called whenever the stats change (cheap: only the ones still locked are looked at)
static func check() -> void:
	if Game.state.is_empty():
		return
	for e in LIST:
		if str(e[6]) != "" or has(e[0]):
			continue
		var need := int(e[7])
		if e[0] in ["untouched", "completionist", "rush", "rush_fast", "rush_clean"]:
			continue
		if _have(e[0]) >= need:
			unlock(e[0])

## the start of a session: what an older save already did counts (quietly, no card for each); returns how many came in
static func sync() -> int:
	var before := count()
	var d: Dictionary = Game.state.get("defeated", {})
	var bk := 0
	for k in Game.v18().get("kills", {}):
		bk += int(Game.v18()["kills"][k])
	at_least("boss_kills", maxi(bk, d.size()))
	at_least("kills", d.size())
	quiet = true
	for e in LIST:
		var n := str(e[6])
		if n != "" and not has(e[0]) and stat(n) >= int(e[7]):
			unlock(e[0])
	check()
	quiet = false
	save_if_dirty()
	return count() - before

## a boss fell: Game.boss_defeated calls this (the fight's "hurt" flag says whether the hero was touched)
static func on_boss(type: String) -> void:
	add("boss_kills")
	var f: Dictionary = Game.fight
	if f.get("type", "") == type and not bool(f.get("hurt", false)):
		unlock("untouched")
	check()

## the "new" marks: the achievements and looks the player has not looked at yet
static func unseen() -> Array:
	return p()["new"]

static func mark_seen() -> void:
	if not p()["new"].is_empty():
		p()["new"] = []
		save()

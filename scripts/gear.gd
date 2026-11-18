extends RefCounted
## Gear (v0.10): accessories and boss relics. Four slots (ring, belt, boots, amulet); the stats feed Game.max_hp(), atk(),
## defense(), crit_chance(), speed() ... and the six relics carry a unique effect (voidward, thorns, venom, frostbite,
## vengeance, emberfall). Items are plain dictionaries: {slot, rarity, name: [en, fa], stat: {key, val, label}, uniq?, desc?}.

const SLOTS := ["ring", "belt", "boots", "amulet"]
const SLOT_ICON := {"ring": "gem", "belt": "shield", "boots": "footprints", "amulet": "heart"}
const SLOT_NAME := {"ring": ["Ring", "حلقه"], "belt": ["Belt", "کمربند"], "boots": ["Boots", "چکمه"], "amulet": ["Amulet", "گردنبند"]}
const RARITY_COL := {"common": Color(0.82, 0.82, 0.88), "rare": Color(0.45, 0.72, 1.0), "epic": Color(0.78, 0.55, 1.0), "legendary": Color(1.0, 0.78, 0.32)}
const RARITY_NAME := {"common": ["Common", "معمولی"], "rare": ["Rare", "کمیاب"], "epic": ["Epic", "حماسی"], "legendary": ["Legendary", "افسانه‌ای"]}
const SELL := {"common": 8, "rare": 25, "epic": 70, "legendary": 200}
const POOL := [{"slot": "ring", "rarity": "common", "name": "Iron Band", "stat": {"key": "atk", "val": 2, "label": "+2 ATK"}, "fa": "حلقهٔ آهنی"}, {"slot": "ring", "rarity": "common", "name": "Copper Signet", "stat": {"key": "crit", "val": 0.05, "label": "+5% Crit"}, "fa": "مهر مسی"}, {"slot": "ring", "rarity": "rare", "name": "Band of Fury", "stat": {"key": "atk", "val": 5, "label": "+5 ATK"}, "fa": "حلقهٔ خشم"}, {"slot": "ring", "rarity": "rare", "name": "Scholar's Signet", "stat": {"key": "mpMax", "val": 5, "label": "+5 Max MP"}, "fa": "مهر دانشمند"}, {"slot": "ring", "rarity": "epic", "name": "Bloodstone", "stat": {"key": "lifesteal", "val": 0.08, "label": "+8% Lifesteal"}, "fa": "سنگ خون"}, {"slot": "ring", "rarity": "epic", "name": "Critical Eye", "stat": {"key": "crit", "val": 0.15, "label": "+15% Crit"}, "fa": "چشم بحرانی"}, {"slot": "ring", "rarity": "legendary", "name": "Wyrmfang", "stat": {"key": "atk", "val": 12, "label": "+12 ATK"}, "fa": "نیش اژدها"}, {"slot": "belt", "rarity": "common", "name": "Leather Belt", "stat": {"key": "def", "val": 1, "label": "+1 DEF"}, "fa": "کمربند چرمی"}, {"slot": "belt", "rarity": "common", "name": "Pouch Belt", "stat": {"key": "potionBonus", "val": 5, "label": "+5 HP/Pot"}, "fa": "کمربند کیسه‌دار"}, {"slot": "belt", "rarity": "rare", "name": "Ironweave Belt", "stat": {"key": "def", "val": 3, "label": "+3 DEF"}, "fa": "کمربند آهن‌بافت"}, {"slot": "belt", "rarity": "rare", "name": "Stamina Cord", "stat": {"key": "stamMax", "val": 20, "label": "+20 Max Stamina"}, "fa": "طناب نیرو"}, {"slot": "belt", "rarity": "epic", "name": "Aegis Girdle", "stat": {"key": "blockBonus", "val": 0.2, "label": "+20% Block"}, "fa": "کمربند سپر"}, {"slot": "belt", "rarity": "legendary", "name": "Titanforge", "stat": {"key": "def", "val": 8, "label": "+8 DEF"}, "fa": "تیتان‌فورج"}, {"slot": "boots", "rarity": "common", "name": "Leather Boots", "stat": {"key": "speed", "val": 0.15, "label": "+5% Speed"}, "fa": "چکمهٔ چرمی"}, {"slot": "boots", "rarity": "common", "name": "Worn Sandals", "stat": {"key": "dodgeBonus", "val": 0.1, "label": "+0.1s Dodge"}, "fa": "صندل کهنه"}, {"slot": "boots", "rarity": "rare", "name": "Swift Greaves", "stat": {"key": "speed", "val": 0.3, "label": "+10% Speed"}, "fa": "ساق‌بند تند"}, {"slot": "boots", "rarity": "rare", "name": "Shadow Treads", "stat": {"key": "crit", "val": 0.08, "label": "+8% Crit"}, "fa": "گام‌های سایه"}, {"slot": "boots", "rarity": "epic", "name": "Phase Walkers", "stat": {"key": "dashCd", "val": 0.2, "label": "-20% Dash CD"}, "fa": "گام‌زنانِ گذرا"}, {"slot": "boots", "rarity": "legendary", "name": "Wyrmstride", "stat": {"key": "speed", "val": 0.5, "label": "+18% Speed"}, "fa": "گام اژدها"}, {"slot": "amulet", "rarity": "common", "name": "Bone Charm", "stat": {"key": "hpMax", "val": 8, "label": "+8 Max HP"}, "fa": "طلسم استخوان"}, {"slot": "amulet", "rarity": "common", "name": "Mana Locket", "stat": {"key": "mpRegen", "val": 0.5, "label": "+0.5 MP/s"}, "fa": "گردنبند مانا"}, {"slot": "amulet", "rarity": "rare", "name": "Vital Pendant", "stat": {"key": "hpMax", "val": 20, "label": "+20 Max HP"}, "fa": "آویز حیات"}, {"slot": "amulet", "rarity": "rare", "name": "Sorcerer's Stone", "stat": {"key": "mpMax", "val": 10, "label": "+10 Max MP"}, "fa": "سنگ جادوگر"}, {"slot": "amulet", "rarity": "epic", "name": "Simurgh's Feather", "stat": {"key": "revive", "val": 1, "label": "Revive 1× (death)"}, "fa": "پرِ سیمرغ"}, {"slot": "amulet", "rarity": "epic", "name": "Regen Charm", "stat": {"key": "hpRegen", "val": 0.5, "label": "+0.5 HP/s"}, "fa": "طلسم بازسازی"}, {"slot": "amulet", "rarity": "legendary", "name": "Wyrmsoul", "stat": {"key": "ultCharge", "val": 0.3, "label": "+30% Ult charge"}, "fa": "روح اژدها"}]
const LABEL_FA := {"ATK": "حمله", "Crit": "ضربهٔ کاری", "Max MP": "مانای بیشینه", "Lifesteal": "جان‌ربایی", "DEF": "دفاع", "HP/Pot": "جان/معجون", "Max Stamina": "استقامت بیشینه", "Block": "سپر", "Speed": "سرعت", "Dodge": "غلت", "Dash CD": "زمان‌انتظار غلت", "Max HP": "جان بیشینه", "MP/s": "مانا/ثانیه", "HP/s": "جان/ثانیه", "Ult charge": "پُرشدنِ ضربهٔ نهایی"}
const RELIC_DESC := {"boss": ["Take 10% less damage", "۱۰٪ آسیب کمتر می‌بینی"], "boss2": ["Reflect 30% of damage taken", "۳۰٪ آسیب دریافتی را بازتاب می‌دهی"], "matriarch": ["25% chance to poison on hit", "۲۵٪ شانس مسموم‌کردن با هر ضربه"], "arbiter": ["18% chance to freeze on hit", "۱۸٪ شانس یخ‌زدن دشمن"], "ancientwyrm": ["+40% ATK below 40% HP", "زیر ۴۰٪ جان، ۴۰٪ حمله بیشتر"], "ignarok": ["Every 5th hit erupts in flame", "هر ضربهٔ پنجم شعله می‌شود"]}

static func _g() -> Dictionary:
	var g = Game.state.get("gear", null)
	if typeof(g) != TYPE_DICTIONARY:
		g = {"eq": {}, "bag": []}
		Game.state["gear"] = g
	if not g.has("eq") or typeof(g["eq"]) != TYPE_DICTIONARY:
		g["eq"] = {}
	if not g.has("bag") or typeof(g["bag"]) != TYPE_ARRAY:
		g["bag"] = []
	return g

static func eq() -> Dictionary:
	return _g()["eq"]

static func bag() -> Array:
	return _g()["bag"]

static func sum(key: String) -> float:
	var t := 0.0
	var e := eq()
	for slot in e:
		var it = e[slot]
		if typeof(it) == TYPE_DICTIONARY and str(it.get("stat", {}).get("key", "")) == key:
			t += float(it["stat"]["val"])
	return t

static func uniq(id: String) -> bool:
	var e := eq()
	for slot in e:
		var it = e[slot]
		if typeof(it) == TYPE_DICTIONARY and str(it.get("uniq", "")) == id:
			return true
	return false

static func has_relic(id: String) -> bool:
	for it in bag():
		if str(it.get("uniq", "")) == id:
			return true
	return uniq(id)

static func item_name(it: Dictionary) -> String:
	var n = it.get("name", "?")
	if typeof(n) == TYPE_ARRAY:
		return Game.t(str(n[0]), str(n[1]))
	return str(n)

static func stat_label(it: Dictionary) -> String:
	var s: Dictionary = it.get("stat", {})
	var en := str(s.get("label", ""))
	if Game.lang != "fa":
		return en
	var out := en
	for k in LABEL_FA:
		if en.find(k) >= 0:
			out = en.replace(k, LABEL_FA[k])
			break
	return Game.num(out)          # (v0.23, playtest) Persian digits and percent sign

static func desc_of(it: Dictionary) -> String:
	var d = it.get("desc", null)
	if typeof(d) == TYPE_ARRAY:
		return Game.t(str(d[0]), str(d[1]))
	return ""

static func rarity_col(it: Dictionary) -> Color:
	return RARITY_COL.get(str(it.get("rarity", "common")), RARITY_COL["common"])

## a relic: the boss's own item. Returns {} for bosses that drop none.
static func relic(boss: String) -> Dictionary:
	var r = Game.table("CH_RELICS").get(boss, null)
	if r == null:
		return {}
	return {"slot": r["slot"], "rarity": "legendary", "name": r["name"], "stat": r["stat"].duplicate(), "uniq": r["uniq"], "desc": r["desc"], "relic": true}

## roll a random accessory. min_rarity floors the roll (bosses and chests never give junk)
static func roll(min_rarity := "common") -> Dictionary:
	var order := ["common", "rare", "epic", "legendary"]
	var w := [60.0, 28.0, 10.0, 2.0]
	var lo := order.find(min_rarity)
	for i in lo:
		w[i] = 0.0
	var tot := 0.0
	for x in w:
		tot += x
	var r := randf() * tot
	var rar := "common"
	for i in 4:
		if r < w[i]:
			rar = order[i]
			break
		r -= w[i]
	var cands := []
	for p in POOL:
		if p["rarity"] == rar:
			cands.append(p)
	if cands.is_empty():
		cands = POOL
	var p: Dictionary = cands[randi() % cands.size()]
	return {"slot": p["slot"], "rarity": p["rarity"], "name": [p["name"], p["fa"]], "stat": p["stat"].duplicate()}

## put an item in the bag; into an empty slot it is worn at once. Returns "worn" or "bag"
static func add(it: Dictionary) -> String:
	var slot := str(it["slot"])
	if not eq().has(slot) or eq()[slot] == null:
		eq()[slot] = it
		Game.stats_changed.emit()
		return "worn"
	bag().append(it)
	Game.stats_changed.emit()
	return "bag"

static func equip(i: int) -> void:
	var b := bag()
	if i < 0 or i >= b.size():
		return
	var it: Dictionary = b[i]
	var slot := str(it["slot"])
	var old = eq().get(slot, null)
	eq()[slot] = it
	b.remove_at(i)
	if old != null:
		b.append(old)
	Game.hp = min(Game.hp, Game.max_hp())
	Game.save_game()
	Game.stats_changed.emit()

static func unequip(slot: String) -> void:
	var old = eq().get(slot, null)
	if old == null:
		return
	eq().erase(slot)
	bag().append(old)
	Game.hp = min(Game.hp, Game.max_hp())
	Game.save_game()
	Game.stats_changed.emit()

static func sell(i: int) -> int:
	var b := bag()
	if i < 0 or i >= b.size():
		return 0
	var g: int = int(SELL.get(str(b[i].get("rarity", "common")), 8))
	b.remove_at(i)
	Game.state["gold"] = int(Game.state.get("gold", 0)) + g
	Game.save_game()
	Game.stats_changed.emit()
	return g

## found an item: announce it (a toast through Game.item_found)
static func grant(it: Dictionary) -> String:
	var where := add(it)
	var col: Color = rarity_col(it)
	var txt := Game.t("Found: ", "پیدا شد: ") + item_name(it) + " (" + stat_label(it) + ")"
	if where == "worn":
		txt += Game.t(" — equipped", " — پوشیده شد")
	Game.item_found.emit(txt, col)
	Game.save_game()
	return where

## a foe falls: now and then it leaves an accessory behind (the chief of a camp always does)
static func drop_from(type: String, boss: bool) -> void:
	if boss:
		return
	var chance := 0.035
	var floor_r := "common"
	if type == "captain":
		chance = 1.0
		floor_r = "rare"
	if randf() < chance:
		grant(roll(floor_r))

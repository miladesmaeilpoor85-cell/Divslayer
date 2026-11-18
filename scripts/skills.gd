extends RefCounted
## v0.6 skills, in one place:
## - the HTML game's ten spells (FF_SKILLS): every class learns them as it levels and binds any two to the
##   spell buttons; cost and cooldown come from the table, the mage pays half (CLASSES.manaMul) and hits
##   harder (V12_BAL.MAGE_BOLT for the bolt, a spell bonus for the rest);
## - each class's ultimate (CLASSES.ultimate), charged by fighting;
## - the three-branch talent tree (TALENT_TREE), one point per level.
## Numbers the exported tables do not carry (damage, radius, speed) are set here, scaled on the hero's attack.

const ORDER := ["bolt", "nova", "chain", "icelance", "mend", "blink", "quake", "drain", "roar", "firewall"]

## kind: shot (projectile) | fan (several shots) | nova (ring around the hero) | chain | heal | blink | buff | drain
## dmg = x the hero's attack
const SPELL := {
	"bolt": {"kind": "shot", "dmg": 1.2, "speed": 540.0, "range": 430.0, "col": Color(0.74, 0.62, 1.0), "size": 1.0, "icon": "sparkle"},
	"nova": {"kind": "nova", "dmg": 1.4, "r": 84.0, "col": Color(1.0, 0.52, 0.22), "status": "burn", "sec": 2.5, "icon": "flame"},
	"chain": {"kind": "chain", "dmg": 1.5, "reach": 270.0, "jump": 150.0, "jumps": 4, "falloff": 0.7, "col": Color(0.66, 0.86, 1.0), "icon": "zap"},
	"icelance": {"kind": "shot", "dmg": 1.6, "speed": 620.0, "range": 470.0, "col": Color(0.62, 0.93, 1.0), "size": 1.35, "pierce": true,
		"status": "freeze", "sec": 2.0, "icon": "snowflake"},
	"mend": {"kind": "heal", "heal": 0.3, "col": Color(0.6, 1.0, 0.62), "icon": "heart"},
	"blink": {"kind": "blink", "dist": 170.0, "col": Color(0.72, 0.86, 1.0), "icon": "wind"},
	"quake": {"kind": "nova", "dmg": 1.3, "r": 112.0, "col": Color(0.9, 0.74, 0.48), "status": "stun", "sec": 1.2, "icon": "mountain"},
	"drain": {"kind": "drain", "dmg": 1.8, "reach": 175.0, "col": Color(0.72, 0.46, 1.0), "icon": "droplets"},
	"roar": {"kind": "buff", "mul": 1.4, "sec": 8.0, "col": Color(1.0, 0.46, 0.3), "icon": "crown"},
	"firewall": {"kind": "fan", "dmg": 1.0, "n": 7, "spread": 0.62, "speed": 470.0, "range": 380.0, "col": Color(1.0, 0.56, 0.2), "size": 1.1,
		"status": "burn", "sec": 2.5, "icon": "flame-kindling"},
}

## the mage's spells hit harder (the bolt uses the HTML MAGE_BOLT factor instead)
const MAGE_SPELL := 1.8
## mana: class pool + 2 per level; regeneration per second (the mage gets V12_BAL.MAGE_REGEN_EXTRA more);
## every melee blow that lands gives a little back, so fighters can weave spells into their combos
const MP_PER_LEVEL := 2.0
const MP_REGEN := 0.9
const MP_PER_HIT := 0.5

## ultimates: meter 0..100, filled by fighting (see Game.add_ult)
const ULT := {
	"warrior": {"id": "whirlwind", "icon": "swords", "col": Color(1.0, 0.74, 0.38),
		"name": ["Whirlwind Strike", "ضربهٔ گردباد"], "shout": ["WHIRLWIND!", "گردباد!"],
		"desc": ["Spin for 3 s, striking everything around you; you take half damage while spinning.",
			"۳ ثانیه می‌چرخی و هرچه دورت باشد را می‌زنی؛ در چرخش نصف آسیب می‌بینی."]},
	"mage": {"id": "arcane_tempest", "icon": "sparkles", "col": Color(0.78, 0.6, 1.0),
		"name": ["Arcane Tempest", "توفانِ جادو"], "shout": ["TEMPEST!", "توفان!"],
		"desc": ["Meteors fall on every enemy in sight — three on a boss — and set them burning.",
			"شهاب‌ها بر سر هر دشمنی که در دید است می‌بارند — سه‌تا بر سر سرکرده — و آتششان می‌زنند."]},
	"rogue": {"id": "shadow_dance", "icon": "moon", "col": Color(0.62, 0.86, 1.0),
		"name": ["Shadow Dance", "رقصِ سایه"], "shout": ["SHADOW DANCE!", "رقصِ سایه!"],
		"desc": ["Five teleporting critical strikes on the nearest foe; nothing can touch you meanwhile.",
			"پنج ضربهٔ کاری با جهش آنی بر نزدیک‌ترین دشمن؛ در این میان هیچ‌چیز به تو نمی‌رسد."]},
	"paladin": {"id": "holy_smite", "icon": "sun", "col": Color(1.0, 0.88, 0.5),
		"name": ["Farr Smite", "کوبهٔ فرّه"], "shout": ["FARR SMITE!", "کوبهٔ فرّه!"],
		"desc": ["A pillar of light: damages and stuns everything near you, heals you 30% and cleanses poison, fire and ice.",
			"ستونی از نور: هرچه نزدیکت باشد آسیب می‌بیند و گیج می‌شود، ۳۰٪ جانت برمی‌گردد و زهر و آتش و یخ پاک می‌شود."]},
}

## (v0.26, both testers: "four callings, one moveset") each calling's own move, on the button that was Shove: it costs
## stamina and a cooldown, never mana. The way of Rostam: his lasso. Of Zal: the Simorgh's feather. Of Gordafarid: the
## arrow from hiding. Of Siavash: the walk through fire.
const SIG := {
	"warrior": {"id": "lasso", "icon": "lasso", "col": Color(0.95, 0.72, 0.38), "cd": 6.0, "sta": 15.0, "name": ["Lasso", "کمند"],
		"desc": ["Drags the foe before you to your feet and stuns it; a boss is not dragged, but loses its footing.",
			"دشمنِ پیشِ رو را تا پای تو می‌کشد و گیجش می‌کند؛ سرکرده را نمی‌کشد، اما از تعادل می‌اندازد."]},
	"mage": {"id": "ward", "icon": "feather", "col": Color(1.0, 0.82, 0.45), "cd": 10.0, "sta": 20.0, "name": ["Simorgh's Feather", "پرِ سیمرغ"],
		"desc": ["For 6 s the first blow does not touch you: you gain mana instead, and the feather's light stuns the foes near you.", "تا ۶ ثانیه نخستین ضربه به تو نمی‌رسد: به‌جایش مانا می‌گیری و فروغِ پر دشمنانِ نزدیک را گیج می‌کند."]},
	"rogue": {"id": "arrow", "icon": "target", "col": Color(0.7, 0.9, 0.6), "cd": 2.5, "sta": 12.0, "name": ["Khadang Arrow", "تیرِ خدنگ"],
		"desc": ["A fast arrow; loosed from hiding it bites three times as deep.", "تیری تند؛ از نهان که رها شود، سه‌برابر کاری‌تر است."]},
	"paladin": {"id": "fire", "icon": "flame", "col": Color(1.0, 0.6, 0.3), "cd": 12.0, "sta": 20.0, "name": ["Fire-walk", "گذر از آتش"],
		"desc": ["4 s of fire around you: it burns every foe that comes near, and washes poison, burning and frost from you.",
			"۴ ثانیه آتش پیرامونت: هر دشمنی را که نزدیک شود می‌سوزاند و زهر و سوختگی و یخ را از تو می‌شوید."]},
}

static func sig() -> Dictionary:
	return SIG.get(Game.cls, SIG["warrior"])

static func sig_name() -> String:
	var s := sig()
	return Game.t(s["name"][0], s["name"][1])

static func sig_desc() -> String:
	var s := sig()
	return Game.t(s["desc"][0], s["desc"][1])

## talent trees in the HTML order; descriptions that had no counterpart in this port were rewritten
const TREES := ["might", "fortitude", "cunning"]
const TREE_COL := {"might": Color(1.0, 0.55, 0.38), "fortitude": Color(0.55, 0.78, 1.0), "cunning": Color(0.55, 0.92, 0.55)}
const TREE_ICON := {"might": "sword", "fortitude": "shield", "cunning": "footprints"}
const DESC_OVERRIDE := {
	"block_mastery": ["Hits you take −15%", "۱۵٪ آسیب کمتر از ضربه‌ها"],
	"dodge_master": ["+0.1 s roll invulnerability per rank", "+۰٫۱ ثانیه آسیب‌ناپذیری غلت در هر رتبه"],
	"treasure": ["+25% gold from foes", "+۲۵٪ سکه از دشمن‌ها"],
	"power_atk": ["Heavy (held) attacks +25% damage", "ضربهٔ سنگین (نگه‌داشته) +۲۵٪ آسیب"],
}

# ---------------------------------------------------------------- spells
static func spell(id: String) -> Dictionary:
	var d: Dictionary = Game.table("FF_SKILLS").get(id, {}).duplicate()
	d.merge(SPELL.get(id, {}), true)
	return d

static func spell_name(id: String) -> String:
	var d: Dictionary = Game.table("FF_SKILLS").get(id, {})
	return Game.t(str(d.get("nameEn", id)), str(d.get("nameFa", "")))

static func spell_desc(id: String) -> String:
	var d: Dictionary = Game.table("FF_SKILLS").get(id, {})
	return Game.t(str(d.get("dEn", "")), str(d.get("dFa", "")))

static func spell_icon(id: String) -> String:
	return str(SPELL.get(id, {}).get("icon", "sparkles"))

static func spell_col(id: String) -> Color:
	return SPELL.get(id, {}).get("col", Color(1, 1, 1))

## level the spell is learned at; Emberwall is Jamshid's gift (after the King of Mazandaran falls)
static func spell_level(id: String) -> int:
	return int(Game.table("FF_SKILLS").get(id, {}).get("lvl", 1))

static func is_gift(id: String) -> bool:
	return spell_level(id) >= 99

static func known(id: String) -> bool:
	if not SPELL.has(id):
		return false
	if is_gift(id):
		return bool(Game.state.get("gift_" + id, false))
	return Game.lvl() >= spell_level(id)

static func cost(id: String) -> int:
	var mp := float(Game.table("FF_SKILLS").get(id, {}).get("mp", 1))
	return max(1, int(round(mp * float(Game.class_def().get("manaMul", 1.0)))))

static func cooldown(id: String) -> float:
	return float(Game.table("FF_SKILLS").get(id, {}).get("cd", 1000)) / 1000.0

## spells learned exactly at level `lv` (for the "Skill learned" message)
static func learned_at(lv: int) -> Array:
	var out := []
	for id in ORDER:
		if not is_gift(id) and spell_level(id) == lv:
			out.append(id)
	return out

## the spell's damage factor on the hero's attack, with the mage's bonus
static func power(id: String) -> float:
	var k := float(SPELL.get(id, {}).get("dmg", 1.0))
	if Game.cls == "mage":
		if id == "bolt":
			return k * float(Game.table("V12_BAL").get("MAGE_BOLT", 2.2))
		return k * MAGE_SPELL
	return k

# ---------------------------------------------------------------- ultimates
static func ult(c := "") -> Dictionary:
	return ULT.get(c if c != "" else Game.cls, ULT["warrior"])

static func ult_name(c := "") -> String:
	var u := ult(c)
	return Game.t(u["name"][0], u["name"][1])

static func ult_desc(c := "") -> String:
	var u := ult(c)
	return Game.t(u["desc"][0], u["desc"][1])

# ---------------------------------------------------------------- talents
static func tree_nodes(tree: String) -> Array:
	return Game.table("TALENT_TREE").get(tree, {}).get("nodes", [])

static func node(id: String) -> Dictionary:
	for tr in TREES:
		for n in tree_nodes(tr):
			if str(n["id"]) == id:
				return n
	return {}

static func tree_name(tree: String) -> String:
	var en := str(Game.table("TALENT_TREE").get(tree, {}).get("name", tree))
	return Game.t(en, str(Game.table("V12_TAL").get(en, "")))

static func talent_name(id: String) -> String:
	var en := str(node(id).get("name", id))
	return Game.t(en, str(Game.table("V12_TAL").get(en, "")))

static func talent_desc(id: String) -> String:
	if DESC_OVERRIDE.has(id):
		return Game.t(DESC_OVERRIDE[id][0], DESC_OVERRIDE[id][1])
	var en := str(node(id).get("desc", ""))
	return Game.t(en, str(Game.table("V12_TAL").get(en, "")))

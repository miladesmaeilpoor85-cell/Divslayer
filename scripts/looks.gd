extends RefCounted
## (v0.20) Hero looks (`Game.Looks`, static): the HTML game's hero skins (MON_SKINS.json: three colours, an aura, a trail,
## a crown), earned here by achievements instead of bought. A look recolours the class's cloth on the hero's own sprite
## sheet (scripts/fx/hero_look.gdshader with the sheet's mask from tools/make_hero_masks.py), keeps everything else
## (face, hair, weapon), and may add a soft aura on the ground, a coloured trail (the dodge's after-images, motes while
## walking) and a crown. The look is part of the profile (scripts/achievements.gd), like the achievements.

const Ach = preload("res://scripts/achievements.gd")
const SHADER := preload("res://scripts/fx/hero_look.gdshader")

## the order in the wardrobe, and the achievement that earns each look ("" = free)
const ORDER := ["ember", "crimson", "verdant", "frost", "azure", "obsidian", "sunfire", "ranger", "void", "pahlavan", "ashen", "kaviani", "gold"]
const EARN := {"ember": "", "crimson": "boss_master", "verdant": "legend", "frost": "frost_slayer", "azure": "shrines7",
	"obsidian": "forge_max", "sunfire": "ignarok", "ranger": "bounty25", "void": "wyrm_slayer", "pahlavan": "rush",
	"ashen": "ng_wyrm", "kaviani": "zahhak", "gold": "completionist"}

static var _mats := {}
static var _keys := {}

static func def(id: String) -> Dictionary:
	return Game.table("MON_SKINS").get(id, {})

static func title(id: String) -> String:
	var d := def(id)
	return Game.t(str(d.get("nameEn", id)), str(d.get("nameFa", id)))

static func unlocked(id: String) -> bool:
	if not EARN.has(id):
		return false
	var a: String = EARN[id]
	return a == "" or Ach.has(a)

## the look worn now (a look that is not earned, or unknown, falls back to the default)
static func current() -> String:
	var id := str(Ach.p().get("look", "ember"))
	return id if unlocked(id) else "ember"

static func wear(id: String) -> bool:
	if not unlocked(id):
		return false
	Ach.p()["look"] = id
	Ach.save()
	return true

## the looks a just-unlocked achievement brings
static func earned_by(ach_id: String) -> Array:
	var out := []
	for k in ORDER:
		if EARN[k] == ach_id and ach_id != "":
			out.append(k)
	return out

static func earn_text(id: String) -> String:
	var a: String = EARN.get(id, "")
	if a == "":
		return Game.t("Always yours", "همیشه در اختیار توست")
	return Game.t("Earned by: ", "با دستاوردِ: ") + Ach.title(a)

static func _col(hex) -> Color:
	return Color.html(str(hex)) if typeof(hex) == TYPE_STRING and str(hex) != "" else Color(0, 0, 0, 0)

static func aura(id := "") -> Color:
	return _col(def(id if id != "" else current()).get("aura", null))

static func trail(id := "") -> Color:
	return _col(def(id if id != "" else current()).get("trail", null))

static func crown(id := "") -> bool:
	return bool(def(id if id != "" else current()).get("crown", false))

static func colors(id: String) -> Array:
	var pal: Array = def(id).get("pal", ["#b8632e", "#6e3a1c", "#e0a23c"])
	return [_col(pal[0]), _col(pal[1]), _col(pal[2])]

static func _key(sheet: String) -> float:
	if _keys.is_empty():
		var d = Game._json("res://data/hero_masks.json")
		_keys = d if typeof(d) == TYPE_DICTIONARY else {"_": {}}
	return float(_keys.get(sheet, {}).get("key", 0.4))

## the material that paints `id` on `sheet` (null for the default look: the sheet as drawn)
static func material(sheet: String, id: String) -> Material:
	if id == "ember" or id == "" or def(id).is_empty():
		return null
	var k := sheet + "/" + id
	if _mats.has(k):
		return _mats[k]
	var mask_path := Game.ART + "Heroes/" + sheet + "_mask.png"
	if not ResourceLoader.exists(mask_path):
		return null
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("mask_tex", load(mask_path))
	var c := colors(id)
	m.set_shader_parameter("mid", Vector3(c[0].r, c[0].g, c[0].b))
	m.set_shader_parameter("dark", Vector3(c[1].r, c[1].g, c[1].b))
	m.set_shader_parameter("light", Vector3(c[2].r, c[2].g, c[2].b))
	m.set_shader_parameter("key", _key(sheet))
	m.set_shader_parameter("amount", 1.0)
	_mats[k] = m
	return m

## paint a hero sprite (the hero, his after-images, the Hero page's figure, the wardrobe's)
static func apply(spr: CanvasItem, sheet: String, id := "") -> void:
	if spr == null:
		return
	spr.material = material(sheet, id if id != "" else current())

## where the top of the head is (px above the feet), per class: the crown floats just over it
const HEAD := {"warrior": 47.0, "mage": 50.0, "rogue": 45.0, "paladin": 45.0}

extends Node
## (v0.21) The Boss Rush — "Battles Remembered" (the HTML game's RUSH_BOSSES, with the port's two new bosses and Puladvand) —
## hosted by Sorush in the Crystal Sanctum once chapter 2 is over. The seven great fights again, back to back,
## each in its own arena but as a memory: a cold tint over the world, no other foes, no way out. Every boss comes as an
## endgame fight (its own health and damage for the run, rising toward the Wyrm). The potions are the memory's own (four,
## and two of mana; yours wait outside); between fights the memory gives back part of your health and all your mana. Dying
## ends the run (no gold is lost): you wake by Sorush. Clear all seven: gold (more the first time), the time, a best time.
##   Game.rush (not saved) = {i, type, map, hp, dmg, elapsed, ...} while a run is on (the scaling reads it: Game.area_scale,
##   Game.enemy_stats; the world builds a memory from it: world.rush).
##   state.rush_keep = what the run set aside (potions, where you stood) — given back at the end, and on load if the game was
##   closed mid-run (restore_kept, from Game.load_game).

signal finished(won: bool)

## boss, its map, where the hero stands when the memory opens (feet), its health in the run, the run's damage scale
const ORDER := [
	["boss", "dungeon", Vector2(663, 764), 11000.0, 1.8],
	["boss2", "peaks", Vector2(373, 234), 13000.0, 1.9],
	["matriarch", "shadowfen", Vector2(473, 234), 15000.0, 1.9],
	["arbiter", "sanctum", Vector2(413, 254), 17000.0, 2.0],
	["ignarok", "emberforge", Vector2(433, 264), 16000.0, 1.25],
	["glaciertitan", "frostvale", Vector2(951, 602), 16000.0, 2.1],
	["ancientwyrm", "wyrmhollow", Vector2(428, 939), 30000.0, 1.6],
]
const POUCH := 4                  # the memory's health potions
const MANA_POUCH := 2
const HEAL_BETWEEN := 0.4         # of your health, given back after each fight
const FAST_SEC := 420.0           # "Memory Unbroken": the seven in under seven minutes (the clock stops between fights)
const FIRST_GOLD := 1500
const GOLD := 300
const WAKE := Vector2(613, 590)   # by Sorush (Crystal Sanctum)

var main: Node = null
var _tick := 0.0
var busy := false                 # between fights (the trip to the next memory)
var over := false

# ---------------------------------------------------------------- static: for the menus, the HUD and the save
## after chapter 2; in New Game+ whenever Sorush has no part of the story to tell (he does at "keeper" and "forge")
static func available() -> bool:
	var st: String = Game.Ch2.step()
	if st == "done":
		return true
	return Game.ng() > 0 and not st in ["keeper", "forge"]

static func best() -> float:
	return float(Game.Ach.stat("rush_best_ms")) / 1000.0

static func clock(sec: float) -> String:
	var s := int(sec)
	return Game.num("%d:%02d" % [s / 60, s % 60])

## the HUD's objective line during a run
static func objective() -> String:
	var r: Dictionary = Game.rush
	var i := int(r.get("i", 0))
	return Game.t("Boss Rush · memory %d of %d · %s" % [i + 1, ORDER.size(), clock(float(r.get("elapsed", 0.0)))],
		"نبردهای به‌یادمانده، یادِ %s از %s، %s" % [Game.num(i + 1), Game.num(ORDER.size()), clock(float(r.get("elapsed", 0.0)))])

## a run cut short by closing the game: give back the potions and the place it set aside
static func restore_kept() -> void:
	var k = Game.state.get("rush_keep", null)
	if typeof(k) != TYPE_DICTIONARY:
		return
	for n in ["potions", "mana_potions", "greater"]:
		Game.state[n] = int(k.get(n, Game.state.get(n, 0)))
	Game.state["map"] = str(k.get("map", "sanctum"))
	Game.state["x"] = float(k.get("x", WAKE.x))
	Game.state["y"] = float(k.get("y", WAKE.y))
	Game.state.erase("rush_keep")

# ---------------------------------------------------------------- a run
func begin() -> void:
	var st: Dictionary = Game.state
	st["rush_keep"] = {"potions": int(st.get("potions", 0)), "mana_potions": int(st.get("mana_potions", 0)),
		"greater": int(st.get("greater", 0)), "map": "sanctum", "x": WAKE.x, "y": WAKE.y}
	st["potions"] = POUCH
	st["mana_potions"] = MANA_POUCH
	st["greater"] = 0
	Game.rush = {"i": 0, "elapsed": 0.0, "drank": 0}
	Game.hp = Game.max_hp()
	Game.mp = Game.max_mp()
	Game.save_game()
	Game.Ach.add("rush_runs")
	_go(0)

func _set_fight(i: int) -> void:
	var e: Array = ORDER[i]
	Game.rush["i"] = i
	Game.rush["type"] = e[0]
	Game.rush["map"] = e[1]
	# in New Game+ the memories grow with the world (as every region does)
	Game.rush["hp"] = float(e[3]) * (1.0 + Game.NG_HP * Game.ng())
	Game.rush["dmg"] = float(e[4]) * (1.0 + Game.NG_DMG * Game.ng())

## the next memory: a fade, the boss's own arena, a banner
func _go(i: int) -> void:
	busy = true
	_set_fight(i)
	if main == null or main.hud == null:
		return
	main.hud.pad.release_all()
	await main.hud.fade_out()
	if over or main == null or main.hud == null:
		return
	var e: Array = ORDER[i]
	main.player.refresh_between()
	Game.mp = Game.max_mp()
	main.goto_map(str(e[1]), e[2])
	main.hud.fade_in()
	busy = false
	main.hud.banner(Game.t("Memory %d of %d" % [i + 1, ORDER.size()], "یادِ %s از %s" % [Game.num(i + 1), Game.num(ORDER.size())]),
		Game.boss_name(str(e[0])), Game.boss_cfg(str(e[0])).get("rgb", Color(0.7, 0.85, 1.0)), 1.8)
	Sfx.play("phase", -4.0)
	main.hud.refresh()

func _physics_process(dt: float) -> void:
	if Game.rush.is_empty() or over:
		return
	if not busy and main and main.player and not main.player.dead:
		Game.rush["elapsed"] = float(Game.rush.get("elapsed", 0.0)) + dt
	_tick -= dt
	if _tick <= 0.0 and main and main.hud:
		_tick = 0.5
		main.hud.quest_l.text = objective()

## a potion drunk in the run (for "no potions" and the result line)
func drank() -> void:
	Game.rush["drank"] = int(Game.rush.get("drank", 0)) + 1

## the boss of this memory fell
func on_victory(b: Node) -> void:
	if over or Game.rush.is_empty() or b.type != str(Game.rush.get("type", "")):
		return
	busy = true
	var i := int(Game.rush["i"])
	# the memory is won: nothing left in it can hurt the hero (a burn ticking, a wyrmling still flying)
	if main and main.player:
		main.player.clear_statuses()
		main.player.invuln = max(main.player.invuln, 6.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e != b and not e.dead:
			e.queue_free()
	await get_tree().create_timer(2.8).timeout
	if over or main == null or main.hud == null:
		return
	if i + 1 >= ORDER.size():
		_complete()
		return
	Game.hp = min(Game.max_hp(), Game.hp + Game.max_hp() * HEAL_BETWEEN)
	main.hud.toast(Game.t("The memory fades — %d of %d. Health returns." % [i + 1, ORDER.size()],
		"یاد محو می‌شود — %s از %s. جانت کمی برمی‌گردد." % [Game.num(i + 1), Game.num(ORDER.size())]), "sparkles", Color(0.7, 0.88, 1.0))
	main.hud.refresh()
	await get_tree().create_timer(1.6).timeout
	if over or main == null:
		return
	_go(i + 1)

## the hero fell in a memory: the run ends, he wakes by Sorush
func on_died() -> void:
	if over:
		return
	over = true
	var reached := int(Game.rush.get("i", 0))
	var sec := float(Game.rush.get("elapsed", 0.0))
	Music.set_boss(false)
	await get_tree().create_timer(1.6).timeout
	if main == null or main.hud == null:
		return
	await main.hud.fade_out()
	_end()
	main.player.revive()
	main.goto_map("sanctum", WAKE)
	main.hud.fade_in()
	main.hud.banner(Game.t("The memory fades", "یاد محو شد"), Game.t("%d of %d battles · %s" % [reached, ORDER.size(), clock(sec)],
		"%s از %s نبرد، %s" % [Game.num(reached), Game.num(ORDER.size()), clock(sec)]), Color(0.7, 0.85, 1.0), 2.6)
	finished.emit(false)
	queue_free()

## all seven: the time, the gold, the achievements, back to Sorush
func _complete() -> void:
	over = true
	var sec := float(Game.rush.get("elapsed", 0.0))
	var clean := int(Game.rush.get("drank", 0)) == 0
	var first := not Game.Ach.has("rush")
	var g := FIRST_GOLD if first else GOLD
	var prev := best()
	var new_best := prev <= 0.0 or sec < prev
	if new_best:
		Game.Ach.p()["stats"]["rush_best_ms"] = int(sec * 1000.0)
		Game.Ach.save()
	Game.Ach.add("rush_clears")
	Music.set_boss(false)
	Sfx.play("victory")
	main.hud.banner(Game.t("THE BATTLES REMEMBERED", "نبردها به یاد ماندند"), Game.t("All seven · %s%s" % [clock(sec), "  · new best!" if new_best and prev > 0.0 else ""],
		"هر هفت، %s%s" % [clock(sec), "، رکوردِ تازه!" if new_best and prev > 0.0 else ""]), UI.GOLD_HI, 3.0)
	await get_tree().create_timer(3.4).timeout
	if main == null or main.hud == null:
		return
	await main.hud.fade_out()
	_end()
	Game.state["gold"] = int(Game.state.get("gold", 0)) + g
	Game.Ach.unlock("rush")
	if sec < FAST_SEC:
		Game.Ach.unlock("rush_fast")
	if clean:
		Game.Ach.unlock("rush_clean")
	main.player.revive()
	main.goto_map("sanctum", WAKE)
	main.hud.fade_in()
	main.hud.toast(Game.t("+%d gold — Sorush's thanks. Your time: %s (best %s)" % [g, clock(sec), clock(best())],
		"+%s سکه — سپاسِ سروش. زمانت: %s (بهترین %s)" % [Game.num(g), clock(sec), clock(best())]), "trophy", UI.GOLD_HI)
	Sfx.play("coin")
	Game.save_game()
	main.hud.refresh()
	finished.emit(true)
	queue_free()

## give back what the run set aside and close it
func _end() -> void:
	Game.rush = {}
	Game.fight = {}
	restore_kept()
	Game.save_game()

## the game is quitting to the title mid-run
func abort() -> void:
	over = true
	_end()
	queue_free()

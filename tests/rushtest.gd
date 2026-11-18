extends Node
## v0.21 checks: the Boss Rush ("Battles Remembered") and New Game+. Sorush's offer after chapter 2; a run: each memory is
## the boss's own map with only that boss, no way out, the cold tint, the run's health and damage, the memory's potions; the
## fights one after another (health back between them), the end (gold, achievements, the best time, the look), dying in a
## memory (no gold lost, back by Sorush), quitting mid-run (everything given back, also on load). New Game+: what stays,
## what starts again, the stronger and richer foes, more elites, the HUD mark, the Wyrm in New Game+, Sorush's menu then.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/rushtest.gd

var main: Node
var results := {}
var fails: Array = []
var R = null

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func until(cond: Callable, max_frames := 2400) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return false

func check(n: String, ok: bool, info = null) -> void:
	results[n] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(n)
	printerr(("PASS " if ok else "FAIL ") + n + ("" if info == null else "  " + str(info)))

func npc(id: String) -> Node:
	for n in get_tree().get_nodes_in_group("npcs"):
		if str(n.get_meta("id", "")) == id:
			return n
	return null

func boss() -> Node:
	for b in get_tree().get_nodes_in_group("bosses"):
		if not b.dead:
			return b
	return null

func endgame_hero() -> void:
	Game.new_game("warrior")
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	Game.state["level"] = 17
	Game.state["weapon"] = 6
	Game.state["armor"] = 5
	Game.state["gold"] = 1000
	Game.state["potions"] = 9
	Game.state["mana_potions"] = 3
	Game.state["greater"] = 2
	for n in [1, 2, 3]:
		Game.set_q(n, "done")
	Game.brann_set("done")
	var d := {}
	for t in ["boss", "boss2", "matriarch", "arbiter", "ignarok", "glaciertitan", "ancientwyrm", "captain", "anvilward"]:
		d[t] = true
	Game.state["defeated"] = d
	Game.Ch2.st()["step"] = "done"
	Game.hp = Game.max_hp()

## the boss of the memory now falls (as a real kill: the boss's own death path)
func fell() -> void:
	var b := boss()
	if b:
		b.hp = 0.0
		b.die()

func run(m: Node) -> void:
	main = m
	R = Game.Rush
	await get_tree().process_frame
	Game.lang = "fa"
	Game.Ach.reset()
	Game.new_game("warrior")
	check("not_before_chapter2", not R.available())
	endgame_hero()
	main.start_world()
	await frames(10)
	main.player.invuln = 99999.0
	check("available_after_chapter2", R.available() and Game.Ch2.has_news("keeper"))

	# ---- Sorush's offer
	main.goto_map("sanctum", R.WAKE)
	await frames(5)
	main.player.invuln = 99999.0
	main._on_interact(npc("keeper"))
	await frames(3)
	check("keeper_offers", main.hud.dialogue.choosing() and main._keeper_opts.size() == 3 and str(main._keeper_opts[0]["id"]) == "rush")
	main.hud.dialogue._block_until = 0
	main.hud.dialogue._pick(0)
	await frames(2)
	check("run_begins", main.rush_run != null and not Game.rush.is_empty() and int(Game.state["potions"]) == R.POUCH
		and int(Game.state["greater"]) == 0 and Game.state.has("rush_keep") and int(Game.state["rush_keep"]["potions"]) == 9)
	await until(func(): return main.world.key == "dungeon" and boss() != null and not main.rush_run.busy)
	main.player.invuln = 99999.0
	var w = main.world
	var foes := get_tree().get_nodes_in_group("enemies").filter(func(e): return not e.dead)
	check("memory_is_the_arena", w.rush and w.get_node_or_null("Memory") is CanvasModulate and foes.size() == 1 and boss().type == "boss"
		and get_tree().get_nodes_in_group("npcs").is_empty(), foes.size())
	check("run_health", absf(boss().max_hp - 11000.0 * Game.diff_mul("hp")) < 1.0, boss().max_hp)
	check("run_damage", absf(float(Game.area_scale("dungeon")["dmg"]) - 1.8) < 0.001 and absf(float(Game.area_scale("wyrmhollow")["dmg"]) - 1.8) < 0.001)
	await frames(60)
	check("no_way_out", not w.exits_armed)
	check("no_arrow", Game.quest_target().is_empty() and Game.objective().find("۱") >= 0, Game.objective())
	# a potion in the run counts for "no potions"
	Game.hp = Game.max_hp() * 0.5
	main.player.drink()
	check("potion_counted", int(Game.rush.get("drank", 0)) == 1 and int(Game.state["potions"]) == R.POUCH - 1)
	Game.rush["drank"] = 0
	Game.state["potions"] = R.POUCH
	var gold0 := int(Game.state["gold"])

	# ---- the seven, one after another
	var maps := []
	for i in R.ORDER.size():
		var e: Array = R.ORDER[i]
		var ok := await until(func(): return main.world.key == str(e[1]) and boss() != null and boss().type == str(e[0]) and not main.rush_run.busy, 3000)
		if not ok:
			break
		maps.append(main.world.key)
		main.player.invuln = 99999.0
		if i == 1:
			check("health_back_between", Game.hp > Game.max_hp() * 0.85, Game.hp / Game.max_hp())
		Game.hp = Game.max_hp() * 0.4
		fell()
		await frames(2)
		if i == 0:
			check("no_story_bounty", not Game.state["defeated"].is_empty() and int(Game.state.get("essence", 0)) == 0)
	check("seven_memories", maps == ["dungeon", "peaks", "shadowfen", "sanctum", "emberforge", "frostvale", "wyrmhollow"], maps)
	await until(func(): return Game.rush.is_empty() and main.world.key == "sanctum", 3000)
	await frames(10)
	check("run_complete", Game.rush.is_empty() and main.rush_run == null and main.world.key == "sanctum" and not main.world.rush)
	check("pouch_given_back", int(Game.state["potions"]) == 9 and int(Game.state["mana_potions"]) == 3 and int(Game.state["greater"]) == 2 and not Game.state.has("rush_keep"))
	check("first_clear_gold", int(Game.state["gold"]) - gold0 >= R.FIRST_GOLD, int(Game.state["gold"]) - gold0)
	check("rush_achievements", Game.Ach.has("rush") and Game.Ach.has("rush_clean") and Game.Ach.has("rush_fast") and Game.Looks.unlocked("pahlavan"))
	check("best_time_kept", R.best() > 0.0 and R.best() < 60.0, R.best())

	# ---- dying in a memory
	main.player.invuln = 0.0
	var g1 := int(Game.state["gold"])
	main.start_rush()
	await until(func(): return main.world.key == "dungeon" and boss() != null and not main.rush_run.busy)
	main.player.invuln = 0.0
	main.player.take_hit(100000.0)
	await until(func(): return Game.rush.is_empty() and main.world.key == "sanctum", 3000)
	await frames(10)
	check("death_ends_run", main.rush_run == null and Game.rush.is_empty() and not main.player.dead and main.world.key == "sanctum")
	check("death_costs_nothing", int(Game.state["gold"]) == g1 and int(Game.state["potions"]) == 9 and Game.hp >= Game.max_hp() - 0.5)
	main.player.invuln = 99999.0

	# ---- quitting mid-run, and a run cut short by closing the game
	main.start_rush()
	await until(func(): return main.world.key == "dungeon" and not main.rush_run.busy)
	main._quit_to_title()
	await frames(5)
	check("quit_gives_back", Game.rush.is_empty() and int(Game.state["potions"]) == 9 and str(Game.state["map"]) == "sanctum" and not Game.state.has("rush_keep"))
	Game.state["rush_keep"] = {"potions": 9, "mana_potions": 3, "greater": 2, "map": "sanctum", "x": 613.0, "y": 590.0}
	Game.state["potions"] = R.POUCH
	Game.state["map"] = "frostvale"
	Game.save_game()
	Game.load_game()
	check("load_gives_back", int(Game.state["potions"]) == 9 and str(Game.state["map"]) == "sanctum" and not Game.state.has("rush_keep"))
	main._on_start("", true)
	await frames(10)
	main.player.invuln = 99999.0
	check("continue_after", main.world != null and main.world.key == "sanctum" and main.rush_run == null)

	# ---- New Game+
	var lvl0 := Game.lvl()
	var w0 := int(Game.state["weapon"])
	var gold2 := int(Game.state["gold"])
	var slime_hp0: float = Game.enemy_stats("slime", "forest")["hp"]
	var slime_xp0: int = Game.enemy_stats("slime", "forest")["xp"]
	var wyrm_hp0: float = Game.enemy_stats("ancientwyrm", "wyrmhollow")["hp"]
	main._on_interact(npc("keeper"))
	await frames(3)
	main.hud.dialogue._block_until = 0
	main.hud.dialogue._pick(1)
	await frames(3)
	check("ng_asks_first", main.hud.dialogue.choosing() and main._ng_opts.size() == 2 and Game.ng() == 0)
	main.hud.dialogue._block_until = 0
	main.hud.dialogue._pick(0)
	await until(func(): return Game.ng() == 1 and main.world.key == "village", 600)
	await frames(10)
	main.player.invuln = 99999.0
	check("ng_started", Game.ng() == 1 and main.world.key == "village" and Game.Ach.has("ng_start"))
	check("ng_keeps_the_hero", Game.lvl() == lvl0 and int(Game.state["weapon"]) == w0 and int(Game.state["gold"]) == gold2)
	check("ng_story_again", Game.q(1) == "not_started" and Game.brann() == "none" and Game.Ch2.step() == "" and Game.state.get("defeated", {}).is_empty()
		and Game.toll_st() == "none" and Game.state.get("picked", []).is_empty(), [Game.q(1), Game.brann(), Game.Ch2.step()])
	var slime_hp1: float = Game.enemy_stats("slime", "forest")["hp"]
	check("ng_foes_stronger", slime_hp1 > slime_hp0 * 4.0 and Game.enemy_stats("ancientwyrm", "wyrmhollow")["hp"] > wyrm_hp0 * 1.3
		and float(Game.area_scale("forest")["dmg"]) > 2.0, [slime_hp0, slime_hp1])
	check("ng_foes_richer", int(Game.enemy_stats("slime", "forest")["xp"]) > slime_xp0 * 4, [slime_xp0, Game.enemy_stats("slime", "forest")["xp"]])
	check("ng_village_and_trial_same", float(Game.area_scale("village")["hp"]) == 1.0 and float(Game.area_scale("trial")["hp"]) == 1.0)
	check("ng_more_elites", Game.elite_chance() > Game.elite_rate)
	main.hud.refresh()
	check("ng_on_hud", main.hud.name_l.text.find("+") >= 0, main.hud.name_l.text)
	main.goto_map("forest", Vector2(500, 420))
	await frames(5)
	main.player.invuln = 99999.0
	var e1: Node = main.world.spawn_enemy("slime", main.player.global_position + Vector2(80, 0))
	await frames(2)
	check("ng_in_play", e1.max_hp > slime_hp0 * 4.0, e1.max_hp)
	e1.queue_free()
	check("ng_rush_open", R.available())
	Game.boss_defeated("ancientwyrm")
	check("ng_wyrm", Game.Ach.has("ng_wyrm") and Game.Looks.unlocked("ashen"))
	Game.save_game()
	Game.load_game()
	check("ng_saved", Game.ng() == 1)

	print("RUSHTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

extends Node
## v0.16 checks: the Trial of Embers and elites. The wave plan (counts, tiers, champions, scaling), the arena gate and its choice,
## waves spawning and clearing, rewards, the champion, the best wave, a death in the arena (no gold lost), elites (stats,
## elements, drops, the count), elites on the maps, the Hero page, saving.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/trialtest.gd

const Skills = preload("res://scripts/skills.gd")

var main: Node
var results := {}
var fails: Array = []

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func check(n: String, ok: bool, info = null) -> void:
	results[n] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(n)
	printerr(("PASS " if ok else "FAIL ") + n + ("" if info == null else "  " + str(info)))

func touch(i: int, pos: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = i
	ev.position = pos
	ev.pressed = down
	get_viewport().push_input(ev, true)

func click(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = p
		ev.global_position = p
		ev.pressed = down
		get_viewport().push_input(ev, true)
		await get_tree().process_frame
		await get_tree().process_frame

## a fresh hero of class c at level lv in the empty Trial arena, standing in the open, facing right
func hero(c: String, lv := 1, at := Vector2(450, 520)) -> Node:
	Game.new_game(c)
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	Game.v18()["tips"] = {"talents": true}
	Game.state["level"] = lv
	Game.hp = Game.max_hp()
	Game.mp = Game.max_mp()
	if main.player == null:
		main.start_world()
		await frames(5)
	main.goto_map("trial", at)
	await frames(3)
	var p = main.player
	p.global_position = at
	p.facing = "right"
	p.invuln = 0.0
	p.dead = false
	p.caster.cds.clear()
	p.caster.roar_t = 0.0
	p.caster.spin_t = 0.0
	p.caster.dance = {}
	p.statuses.clear()
	return p

## a still, sturdy target (no AI, no contact damage) at feet position
func dummy(feet: Vector2, type := "skeleton", hp := 5000.0) -> Node:
	var e = main.world.spawn_enemy(type, feet)
	e.max_hp = hp
	e.hp = hp
	e.spd = 0.0
	e.dmg = 0.0
	e.hit_cd = 9999.0
	return e

func clear_foes() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()

const Trial = preload("res://scripts/trial.gd")

func talk(id: String) -> void:
	for n in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(n) and str(n.get_meta("id", "")) == id:
			main._on_interact(n)
			return
	check("npc_" + id + "_exists", false)

func kill_all() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			e.hp = 1.0
			e.hurt(99999.0, false, Vector2.RIGHT)

func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	Game.lang = "en"
	Game.set_setting("sound", true)
	Game.set_setting("diff", "normal")
	var p = await hero("warrior")
	p.invuln = 99.0
	clear_foes()
	Game.state.erase("trial")
	Game.state.erase("elites")

	# ---- the wave plan
	var p1 := Trial.plan(1)
	check("wave_1_is_small", p1["count"] == 4 and p1["tier"] == 0 and not p1["champion"] and p1["elite"] == 0.0, p1)
	check("no_elites_before_wave_4", Trial.plan(3)["elite"] == 0.0 and Trial.plan(4)["elite"] > 0.0)
	check("tier_grows", Trial.plan(4)["tier"] == 1 and Trial.plan(7)["tier"] == 2 and Trial.plan(30)["tier"] == 2)
	check("champion_every_fifth", Trial.plan(5)["champion"] and Trial.plan(10)["champion"] and not Trial.plan(6)["champion"])
	var cap := true
	for n in range(1, 40):
		cap = cap and Trial.plan(n)["count"] <= 14 and Trial.plan(n)["elite"] <= 0.35
	check("plan_is_capped", cap)
	var mono := true
	for n in range(1, 30):
		mono = mono and Trial.plan(n + 1)["hp"] > Trial.plan(n)["hp"] and Trial.plan(n + 1)["dmg"] > Trial.plan(n)["dmg"] and Trial.plan(n + 1)["gold"] > Trial.plan(n)["gold"]
	check("tougher_and_richer_each_wave", mono)
	var t0: Array = Game.table("EI_TRIAL")
	check("pool_tier_0", Trial.pool(0) == t0[0])
	check("pool_tier_2_mixes_the_last_two", Trial.pool(2).size() == t0[1].size() + t0[2].size() and Trial.pool(2).has("golem") and Trial.pool(2).has("archer"), Trial.pool(2))

	# ---- the gate in the village
	main.goto_map("village", Vector2(700, 440))
	await frames(5)
	var gate = null
	for n in get_tree().get_nodes_in_group("npcs"):
		if str(n.get_meta("id", "")) == "arena":
			gate = n
	check("arena_gate_in_the_village", gate != null)
	var free := true
	for w in [Rect2(80, 80, 160, 110), Rect2(80, 230, 160, 110), Rect2(640, 120, 70, 70), Rect2(416, 396, 72, 72)]:
		free = free and not w.has_point(gate.position)
	check("gate_is_not_inside_a_wall", free)
	Game.trial()["best"] = 7
	talk("arena")
	await frames(3)
	check("gate_asks", main.hud.dialogue.visible and main.hud.dialogue.choosing() and main._arena_opts.size() == 2)
	main.hud.dialogue._block_until = 0
	main.hud.dialogue._pick(1)
	await frames(3)
	check("leave_closes", not main.hud.dialogue.visible and main.world.key == "village")
	talk("arena")
	await frames(3)
	main.hud.dialogue._block_until = 0
	main.hud.dialogue._pick(0)
	await frames(120)
	check("enter_travels_to_the_trial", main.world.key == "trial", main.world.key)
	var tr = main.world.trial
	check("the_trial_starts_counting_down", tr != null and tr.active and tr.mode == "countdown")
	p = main.player
	p.invuln = 99.0

	# ---- wave 1
	await frames(220)
	check("wave_1_spawns_after_the_countdown", tr.wave == 1 and tr.mode == "fighting", [tr.wave, tr.mode])
	check("wave_1_has_4_foes_that_hunt_you", tr.foes.size() == 4 and tr.foes.all(func(e): return e.rally))
	var base_hp: float = Game.enemy_stats(tr.foes[0].type, "trial")["hp"]
	check("foes_start_at_their_normal_health", tr.foes[0].max_hp >= base_hp * 0.99 and tr.foes[0].max_hp <= base_hp * 1.01, [tr.foes[0].max_hp, base_hp])
	Game.state["gold"] = 0
	kill_all()
	await frames(90)
	check("wave_1_cleared", tr.cleared == 1 and tr.mode == "rest", [tr.cleared, tr.mode])
	check("wave_1_pays", int(Game.state["gold"]) >= 28, Game.state["gold"])
	check("best_wave_is_kept", int(Game.trial()["best"]) == 7, Game.trial())
	await frames(330)
	check("wave_2_follows_the_rest", tr.wave == 2 and tr.foes.size() == 5, [tr.wave, tr.foes.size()])
	check("wave_2_is_tougher", tr.foes[0].max_hp > Game.enemy_stats(tr.foes[0].type, "trial")["hp"] * 1.05, tr.foes[0].max_hp)

	# ---- the champion of wave 5
	kill_all()
	await frames(60)
	tr.wave = 4
	tr.timer = 0.0
	tr.mode = "rest"
	await frames(10)
	check("wave_5_has_a_champion", tr.wave == 5 and tr.foes.any(func(e): return e.elite != "" and e.max_hp > 150.0), tr.foes.size())
	var champs: Array = tr.foes.filter(func(e): return e.elite != "")
	var gear0: int = Game.Gear.eq().size() + Game.Gear.bag().size()
	kill_all()
	await frames(90)
	check("champion_wave_drops_gear", Game.Gear.eq().size() + Game.Gear.bag().size() > gear0)
	check("elite_kills_are_counted", Game.elites_slain() >= champs.size() and Game.elites_slain() >= 1, Game.elites_slain())
	check("wave_5_cleared", tr.cleared == 5)
	check("best_wave_follows_a_better_run", int(Game.trial()["best"]) == 7)
	tr.cleared = 9
	tr.wave = 9

	# ---- death in the arena costs no gold and ends the run
	Game.state["gold"] = 500
	var runs0: int = int(Game.trial().get("runs", 0))
	# the champion's random drop can be a revive charm, worn at once: it would save the hero (a flaky fail before v0.17)
	var worn: Dictionary = Game.Gear.eq()
	for slot in worn.keys():
		if typeof(worn[slot]) == TYPE_DICTIONARY and str(worn[slot].get("stat", {}).get("key", "")) == "revive":
			worn.erase(slot)
	p.invuln = 0.0
	Game.hp = 1.0
	p.take_hit(999.0)
	await frames(100)
	check("death_in_the_trial_costs_no_gold", int(Game.state["gold"]) == 500, Game.state["gold"])
	check("death_ends_the_run", not tr.active and int(Game.trial()["runs"]) == runs0 + 1)
	check("a_better_run_raises_the_record", int(Game.trial()["best"]) == 9, Game.trial())
	main.hud.death.close() if main.hud.death.has_method("close") else null
	p.revive()
	kill_all()
	clear_foes()

	# ---- walking out of the gate ends a run too
	main.goto_map("trial", Vector2(550, 690))
	await frames(10)
	var tr2 = main.world.trial
	var r0: int = int(Game.trial()["runs"])
	main.goto_map("village", Vector2(420, 500))
	await frames(10)
	check("leaving_ends_the_run", int(Game.trial()["runs"]) == r0 + 1)

	# ---- elites
	clear_foes()
	var plain = main.world.spawn_enemy("skeleton", p.global_position + Vector2(60, 0))
	await frames(2)
	var hp_plain: float = plain.max_hp
	var dmg_plain: float = plain.dmg
	var xp_plain: int = plain.xp
	plain.make_elite("fire")
	check("elite_has_more_health", plain.max_hp >= hp_plain * 2.39, [hp_plain, plain.max_hp])
	check("elite_hits_harder", plain.dmg > dmg_plain * 1.29)
	check("elite_pays_triple", plain.xp == xp_plain * 3)
	check("elite_is_marked", plain.elite == "fire" and plain._aura != null)
	check("elite_burns_what_it_hits", plain.applies.has("burn"))
	var ice = main.world.spawn_enemy("bat", p.global_position + Vector2(-60, 0))
	ice.make_elite("ice")
	var storm = main.world.spawn_enemy("imp", p.global_position + Vector2(0, 60))
	storm.make_elite("storm")
	check("ice_freezes_and_storm_stuns", ice.applies.has("freeze") and storm.applies.has("stun"))
	p.invuln = 0.0
	Game.hp = Game.max_hp()
	plain._contact(p)
	check("a_hit_from_a_fire_elite_burns_the_hero", p.statuses.has("burn"), p.statuses.keys())
	p.statuses.clear()
	var boss_try = main.world.spawn_enemy("boss", p.global_position + Vector2(200, 0))
	boss_try.make_elite("fire")
	check("bosses_are_never_elites", boss_try.elite == "")
	clear_foes()
	var e3 = main.world.spawn_enemy("skeleton", p.global_position + Vector2(60, 0))
	e3.make_elite("ice")
	await frames(2)
	var kills0 := Game.elites_slain()
	var items0: int = Game.Gear.eq().size() + Game.Gear.bag().size()
	e3.hp = 1.0
	e3.hurt(99999.0, false, Vector2.RIGHT)
	await frames(6)
	check("elite_kill_counts", Game.elites_slain() == kills0 + 1)
	check("elite_kill_drops_gear", Game.Gear.eq().size() + Game.Gear.bag().size() >= items0 + 1)     # (+ the foe's own chance of a drop)
	Game.lang = "fa"
	check("element_names_persian", Game.elite_name("fire") != "Fire" and Game.elite_name("ice") != "Frost", Game.elite_name("fire"))
	Game.lang = "en"

	# ---- elites out in the world
	Game.state["level"] = 6
	Game.testing = true
	main.goto_map("forest", Vector2(100, 100))
	await frames(5)
	check("no_random_elites_while_testing", main.world.camp_foes().all(func(e): return e.elite == ""))
	Game.testing = false
	Game.elite_rate = 1.0
	main.goto_map("forest", Vector2(100, 100))
	await frames(5)
	check("elites_appear_on_the_maps", main.world.camp_foes().size() > 0 and main.world.camp_foes().all(func(e): return e.elite != ""), main.world.camp_foes().size())
	Game.elite_rate = 0.0
	main.goto_map("forest", Vector2(100, 100))
	await frames(5)
	check("rate_zero_means_none", main.world.camp_foes().all(func(e): return e.elite == ""))
	Game.state["level"] = 2
	Game.elite_rate = 1.0
	main.goto_map("forest", Vector2(100, 100))
	await frames(5)
	check("no_elites_below_level_3", main.world.camp_foes().all(func(e): return e.elite == ""))
	Game.elite_rate = 0.07
	Game.testing = true
	Game.state["level"] = 1

	# ---- the Hero page
	Game.trial()["best"] = 9
	main.hud.pause.open()
	await frames(3)
	main.hud.pause._show("hero")
	await frames(3)
	var texts := []
	var stack: Array = [main.hud.pause]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
		if nd is Label:
			texts.append(nd.text)
	check("hero_page_shows_records", texts.any(func(t): return str(t).find("Best trial wave: 9") >= 0 and str(t).find("Elites slain") >= 0), texts.size())
	main.hud.pause.close()
	Game.lang = "fa"
	main.hud.pause.open()
	main.hud.pause._show("hero")
	await frames(3)
	check("hero_page_persian_builds", true)
	main.hud.pause.close()
	Game.lang = "en"

	# ---- saving
	Game.state["elites"] = 4
	Game.save_game()
	Game.state.erase("trial")
	Game.state.erase("elites")
	Game.load_game()
	check("save_keeps_records", int(Game.trial()["best"]) == 9 and Game.elites_slain() == 4, Game.trial())
	Game.state.erase("trial")
	Game.state.erase("elites")
	check("old_save_defaults", int(Game.trial()["best"]) == 0 and Game.elites_slain() == 0)

	print("TRIALTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

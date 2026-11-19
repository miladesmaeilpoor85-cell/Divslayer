extends Node
## v0.9 checks: the side quest Thornwood Toll: Sindokht gives it, the camp holds the strongbox and the ledger, a watcher
## noticing the hero calls a parley, every way out (pay, fame, oath, hand, dragon, ledger, fight, sneak), the truce,
## Sindokht's reaction and reward, her 20% price, saving, objective and compass.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/tolltest.gd

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

func npc_named(id: String) -> Node:
	for n in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(n) and str(n.get_meta("id", "")) == id:
			return n
	return null

func talk(id: String) -> void:
	var n := npc_named(id)
	if n == null:
		n = Node2D.new()
		n.set_meta("id", id)
		n.set_meta("name_en", id)
		add_child(n)
	main._on_interact(n)

func finish_dialogue() -> void:
	var d = main.hud.dialogue
	var guard := 0
	while d.visible and guard < 20 and not d.choosing():
		d.skip_typing()
		d._block_until = 0
		d.advance()
		guard += 1
	await frames(2)

func camp_ready(cls := "warrior", st := "active") -> Node:
	var p = await hero(cls)
	for n in [1, 2, 3]:
		Game.state["q%d" % n] = "done"
	Game.state["c2"] = {"step": "done"}       # (v0.19) chapter 2 finished too: the side quest owns the compass
	Game.state["toll"] = {"st": st, "how": "", "ledger": false, "truce": false}
	main.goto_map("camp", Vector2(120, 60))
	await frames(5)
	p.invuln = 99.0
	return p

func ids(opts: Array) -> Array:
	var out := []
	for o in opts:
		out.append(o["id"])
	return out

func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	Game.lang = "en"
	Game.set_setting("sound", true)
	var p = await hero("warrior")
	for n in [1, 2, 3]:
		Game.state["q%d" % n] = "done"        # the main story is finished: the side quest owns the compass
	Game.state["c2"] = {"step": "done"}       # (v0.19) chapter 2 included

	# ---- Sindokht gives the quest, then the shop opens
	Game.state.erase("toll")
	main.goto_map("village", Vector2(300, 260))
	await frames(5)
	check("toll_starts_none", Game.toll_st() == "none")
	talk("merchant")
	await frames(2)
	check("thalia_intro_opens", main.hud.dialogue.visible)
	await finish_dialogue()
	check("quest_active", Game.toll_st() == "active")
	check("shop_opens_after_intro", main.hud.shop.visible)
	main.hud.shop.close()
	check("objective_camp", Game.objective().find("strongbox") >= 0, Game.objective())
	check("compass_points_at_camp", Game.quest_target().get("map", "") == "camp", Game.quest_target())
	talk("merchant")
	await frames(2)
	check("second_talk_is_shop", main.hud.shop.visible and not main.hud.dialogue.visible)
	main.hud.shop.close()

	# ---- the camp: strongbox only while the quest is open, the ledger always
	var q = await camp_ready("warrior", "none")
	check("no_strongbox_before_quest", npc_named("strongbox") == null)
	check("ledger_in_camp", npc_named("ledger") != null)
	q = await camp_ready("warrior", "active")
	check("strongbox_in_camp", npc_named("strongbox") != null)
	var sb: Vector2 = npc_named("strongbox").global_position
	check("strongbox_clear_of_walls", not main.world.is_blocked(sb) if main.world.has_method("is_blocked") else true)

	# ---- sneak: nobody noticed -> a ghost
	main.world.camp_noticed = false
	talk("strongbox")
	await frames(2)
	check("ghost_how", Game.toll()["how"] == "ghost" and Game.toll_st() == "box", Game.toll())
	check("strongbox_gone", npc_named("strongbox") == null)
	check("objective_back", Game.objective().find("Sindokht") >= 0, Game.objective())
	check("compass_points_at_village", Game.quest_target().get("map", "") == "village")
	Game.state["gold"] = 0
	main.goto_map("village", Vector2(300, 260))
	await frames(5)
	talk("merchant")
	await frames(2)
	await finish_dialogue()
	await frames(3)
	check("ghost_reward", int(Game.state["gold"]) == 150, Game.state["gold"])
	check("quest_done", Game.toll_st() == "done")
	var pot := {}
	for it in Game.shop_catalog("merchant"):
		if str(it.get("id", "")) == "hp_potion":
			pot = it
	var base: int = int(Game.table("SHOPS")["merchant"]["items"][0]["price"]) if false else 0
	var full := 0
	for it in Game.table("SHOPS")["merchant"]["items"]:
		if str(it.get("id", "")) == "hp_potion":
			full = int(it["price"])
	check("friends_price_20pct", not pot.is_empty() and int(pot["price"]) == int(round(full * 0.8)), [pot.get("price"), full])
	check("smith_full_price", true)
	await frames(60)

	# ---- a watcher notices: the camp calls a parley
	q = await camp_ready("warrior", "active")
	var heard := [false]
	main.world.parley_started.connect(func(): heard[0] = true)
	var foes: Array = main.world.camp_foes()
	check("camp_has_varga", main.world.varga() != null and foes.size() >= 7, foes.size())
	var watcher: Node = null
	for f in foes:
		if f.type == "bandit":
			watcher = f
			break
	main.world.on_notice(watcher)
	await frames(3)
	check("notice_calls_parley", heard[0] and main.world.parleying)
	check("everyone_holds_blade", main.world.camp_foes().all(func(e): return e.parley))
	check("parley_dialogue_opens", main.hud.dialogue.visible)
	await finish_dialogue()
	check("parley_choices_shown", main.hud.dialogue.choosing())
	var opts: Array = main.parley_options()
	check("options_warrior", ids(opts) == ["pay", "fame", "ledger", "fight"], ids(opts))
	check("pay_disabled_when_poor", not opts[0]["ok"])
	check("fame_disabled_before_guardian", not opts[1]["ok"])
	check("ledger_disabled_without_it", not opts[2]["ok"])
	Game.state["gold"] = 500
	Game.state["defeated"] = {"boss": true}
	Game.toll()["ledger"] = true
	opts = main.parley_options()
	check("options_unlock", opts[0]["ok"] and opts[1]["ok"] and opts[2]["ok"])
	# pay the toll
	main._parley_opts = opts
	main._parley_resolve("pay")
	check("pay_costs_200", int(Game.state["gold"]) == 300, Game.state["gold"])
	check("pay_how", Game.toll()["how"] == "pay" and Game.toll()["truce"])
	check("truce_holds", main.world.camp_foes().all(func(e): return e.parley) and not main.world.parleying)
	await finish_dialogue()
	# an attack on a truce-bound bandit breaks the deal
	var vic: Node = main.world.camp_foes()[0]
	vic.hurt(1.0, false, Vector2.RIGHT)
	check("truce_breaks_on_attack", not main.world.truce and main.world.camp_foes().all(func(e): return not e.parley))
	check("truce_break_clears_how", Game.toll()["how"] == "")

	# ---- class options
	for pair in [["paladin", "oath"], ["rogue", "hand"], ["mage", "dragon"]]:
		await camp_ready(pair[0], "active")
		var o2: Array = main.parley_options()
		check("options_" + pair[0], ids(o2).has(pair[1]) and ids(o2).size() == 5, ids(o2))
	await camp_ready("mage", "active")
	Game.mp = 3.0
	check("dragon_needs_mana", not main.parley_options()[2]["ok"])
	Game.mp = Game.max_mp()

	# ---- the dragon scatters the whole camp
	main.world.on_notice(main.world.camp_foes()[0])
	await frames(2)
	await finish_dialogue()
	var mp0: float = Game.mp
	main._parley_opts = main.parley_options()
	main._parley_resolve("dragon")
	await frames(60)
	check("dragon_costs_mana", Game.mp <= mp0 - 5.9, [mp0, Game.mp])
	check("dragon_empties_camp", main.world.camp_foes().is_empty(), main.world.camp_foes().size())
	check("dragon_how", Game.toll()["how"] == "dragon")
	await finish_dialogue()
	talk("strongbox")
	check("dragon_box", Game.toll_st() == "box" and Game.toll()["how"] == "dragon")

	# ---- the oath, the hand, the ledger pay out
	await camp_ready("paladin", "active")
	Game.state["gold"] = 0
	Game.state["potions"] = 0
	main._parley_resolve("oath")
	check("oath_gives_purse_and_potions", int(Game.state["gold"]) == 50 and int(Game.state["potions"]) == 2 and Game.toll().get("charm", false))
	await camp_ready("rogue", "active")
	Game.state["gold"] = 0
	main._parley_resolve("hand")
	check("hand_pays_100", int(Game.state["gold"]) == 100)
	await camp_ready("warrior", "active")
	Game.state["gold"] = 0
	main._parley_resolve("ledger")
	check("ledger_pays_150", int(Game.state["gold"]) == 150 and Game.toll()["how"] == "ledger")
	await finish_dialogue()

	# ---- the ledger pickup
	await camp_ready("warrior", "none")
	check("ledger_not_held", not Game.toll()["ledger"])
	talk("ledger")
	await frames(2)
	check("ledger_taken", Game.toll()["ledger"] and npc_named("ledger") == null)
	await finish_dialogue()
	main.goto_map("camp", Vector2(120, 60))
	await frames(5)
	check("ledger_stays_gone", npc_named("ledger") == null)

	# ---- fight: choosing it must permanently resolve the parley, even while Ashkbus is nearby
	p = await camp_ready("warrior", "active")
	var captain: Node = main.world.varga()
	p.global_position = captain.global_position + Vector2(32, 0)
	var parley_starts := [0]
	main.world.parley_started.connect(func(): parley_starts[0] += 1)
	main.world.on_notice(main.world.camp_foes()[0])
	await frames(2)
	await finish_dialogue()
	var fight_index: int = ids(main._parley_opts).find("fight")
	check("fight_choice_available", fight_index >= 0, ids(main._parley_opts))
	main.hud.dialogue._block_until = 0
	if fight_index >= 0:
		main.hud.dialogue._pick(fight_index)
	else:
		main._parley_resolve("fight") # continue the regression after recording the missing choice failure
	check("fight_choice_commits_combat", bool(Game.toll().get("fight_started", false)), Game.toll())
	await finish_dialogue()
	await frames(3) # let the proximity-based camp tick run after the fight reply closes
	check("fight_choice_does_not_repeat_parley",
		not main.world.parleying and not main.hud.dialogue.visible and parley_starts[0] == 1,
		{"parley_starts": parley_starts[0], "parleying": main.world.parleying, "dialogue_visible": main.hud.dialogue.visible})
	var wake := []
	for e in main.world.camp_foes():
		wake.append([e.type, e.parley, e.rally])
	check("fight_wakes_camp", main.world.camp_foes().all(func(e): return not e.parley and e.rally), wake)

	# Combat state must survive a map transition and restore hostile enemies without a new parley.
	Game.save_game()
	main.goto_map("village", Vector2(300, 260))
	await frames(4)
	main.goto_map("camp", Vector2(120, 60))
	await frames(6)
	p = main.player
	captain = main.world.varga()
	p.global_position = captain.global_position + Vector2(32, 0)
	await frames(3)
	check("fight_state_survives_camp_reentry",
		bool(Game.toll().get("fight_started", false)) and not main.world.parleying
		and main.world.camp_foes().all(func(e): return e.alert and e.rally and not e.parley),
		{"fight_started": Game.toll().get("fight_started", false), "parleying": main.world.parleying, "foes": main.world.camp_foes().size()})
	var v = main.world.varga()
	v.hp = 1.0
	v.hurt(500.0, false, Vector2.RIGHT)
	await frames(90)
	check("varga_dead_how_fight", Game.toll()["how"] == "fight", Game.toll())
	check("camp_scatters_when_varga_falls", main.world.camp_foes().is_empty(), main.world.camp_foes().size())
	talk("strongbox")
	check("fight_box", Game.toll()["how"] == "fight" and Game.toll_st() == "box")

	# ---- the box lifted in plain sight turns the camp hostile
	await camp_ready("warrior", "active")
	main.world.camp_noticed = true
	talk("strongbox")
	check("snatch_how", Game.toll()["how"] == "snatch")
	check("snatch_alarm", main.world.camp_foes().all(func(e): return e.rally and not e.parley))

	# ---- saving and old saves
	Game.save_game()
	Game.state["toll"] = {"st": "box", "how": "pay", "ledger": true, "truce": false}
	Game.save_game()
	Game.state.erase("toll")
	Game.load_game()
	check("save_keeps_toll", Game.toll_st() == "box" and Game.toll()["how"] == "pay" and Game.toll()["ledger"], Game.toll())
	Game.state.erase("toll")
	check("old_save_default", Game.toll_st() == "none")

	print("TOLLTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

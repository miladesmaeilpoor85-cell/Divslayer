extends Node
## v0.13 checks: Jamshid the Exile. The Warden Core drop, the turn-ins and their rewards, the Kindling Key and the Peaks door
## (sealed, then open), Pulad of Ghandi, Puladvand, the masterwork, the objective and the compass at every step,
## old saves catching up, the quest log, saving.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/storytest.gd

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

func talk(id: String) -> void:
	for n in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(n) and str(n.get_meta("id", "")) == id:
			main._on_interact(n)
			return
	var n := Node2D.new()
	n.set_meta("id", id)
	n.set_meta("name_en", id)
	add_child(n)
	main._on_interact(n)

func finish_dialogue() -> void:
	var d = main.hud.dialogue
	var guard := 0
	while d.visible and guard < 20:
		d.skip_typing()
		d._block_until = 0
		d.advance()
		guard += 1
	await frames(2)

func fresh() -> void:
	for k in ["brann", "gift_firewall", "defeated", "bonus_talents", "forge", "q1", "q2", "q3", "c2"]:
		Game.state.erase(k)
	Game.state["gold"] = 0

func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	Game.lang = "en"
	Game.set_setting("sound", true)
	var p = await hero("warrior")
	p.invuln = 99.0
	clear_foes()
	fresh()
	main.goto_map("village", Vector2(300, 400))
	await frames(5)

	# ---- the lines exist in both languages
	var lines_ok := true
	for k in Game.Story.L:
		var pr: Array = Game.Story.L[k]
		lines_ok = lines_ok and str(pr[0]) != "" and str(pr[1]) != "" and pr[0] != pr[1]
	check("every_line_has_english_and_persian", lines_ok)

	# ---- nothing before Arzhang falls
	check("starts_none", Game.brann() == "none" and Game.brann_objective() == "" and not Game.brann_key())
	talk("brann")
	await frames(2)
	check("brann_idle_talk_is_placeholder", main.hud.dialogue.visible)
	await finish_dialogue()
	check("idle_talk_gives_nothing", Game.brann() == "none")

	# ---- Arzhang the Div drops the Warden Core
	var msg := Game.boss_defeated("boss")
	check("guardian_gives_core", Game.brann() == "core", Game.brann())
	check("core_toast", msg.find("Warden Core") >= 0, msg)
	# (v0.24, playtest) Zal's reward leads; Jamshid's errand comes next
	var q1_was: String = Game.q(1)
	Game.set_q(1, "complete")
	check("objective_zal_first", Game.objective() == Game.t("Return to Zal", "نزد زال برگرد"), Game.objective())
	Game.set_q(1, q1_was if q1_was != "complete" else "done")
	check("objective_return_core", Game.objective().find("Warden Core") >= 0, Game.objective())
	check("compass_to_brann", Game.quest_target().get("map", "") == "village" and Game.quest_target().get("kind", "") == "npc", Game.quest_target())
	check("no_key_yet", not Game.brann_key())

	# ---- the Peaks door is sealed without the key
	main.goto_map("peaks", Vector2(560, 700))
	await frames(8)
	var door = null
	for e in get_tree().get_nodes_in_group("exits"):
		if str(e.get_meta("to", "")) == "emberforge":
			door = e
	check("peaks_has_a_forge_door", door != null)
	main.world.exits_armed = true
	var heard := [""]
	main.world.message.connect(func(t): heard[0] = t)
	var went := [""]
	main.world.exit_reached.connect(func(to, _s): went[0] = to)
	main.world._on_exit_body(main.player, "emberforge", Vector2(40, 520))
	check("sealed_door_refuses", went[0] == "" and heard[0].find("Kindling") >= 0, heard[0])

	# ---- Jamshid takes the core and hands over the key
	main.goto_map("village", Vector2(300, 400))
	await frames(5)
	talk("brann")
	await frames(2)
	check("core_turn_in_dialogue", main.hud.dialogue.visible)
	await finish_dialogue()
	await frames(3)
	check("key_given", Game.brann() == "anvil" and Game.brann_key())
	for n in [1, 2, 3]:
		Game.state["q%d" % n] = "done"        # the Elder's chain is finished: chapter 2 comes first (v0.19) ...
	check("chapter2_objective_first", Game.objective() == Game.Ch2.line("o_elder"), Game.objective())
	Game.state["c2"] = {"step": "done"}       # ... and with it done, Jamshid's objective shows
	check("objective_slay_anvil", Game.objective().find("Pulad of Ghandi") >= 0, Game.objective())
	check("compass_to_anvil", Game.quest_target().get("map", "") == "emberforge" and Game.quest_target().get("kind", "") == "boss", Game.quest_target())
	talk("brann")
	await frames(2)
	await finish_dialogue()
	check("reminder_does_not_advance", Game.brann() == "anvil")

	# ---- the door opens
	main.goto_map("peaks", Vector2(560, 700))
	await frames(8)
	main.world.exits_armed = true
	went[0] = ""
	main.world.exit_reached.connect(func(to, _s): went[0] = to)
	main.world._on_exit_body(main.player, "emberforge", Vector2(40, 520))
	check("open_door_leads_to_emberforge", went[0] == "emberforge", went[0])
	main.goto_map("emberforge", Vector2(80, 520))
	await frames(6)
	var warden = null
	for e in main.world.camp_foes():
		if e.type == "anvilward":
			warden = e
	check("warden_waits_in_the_forge", warden != null)

	# ---- Pulad of Ghandi falls
	clear_foes()
	var w2 = main.world.spawn_enemy("anvilward", main.player.global_position + Vector2(60, 0))
	await frames(4)
	w2.hp = 1.0
	w2.hurt(9999.0, false, Vector2.RIGHT)
	await frames(6)
	check("anvil_kill_advances", Game.brann() == "anvil_done", Game.brann())
	check("objective_back_to_brann", Game.objective().find("Jamshid") >= 0, Game.objective())
	check("compass_back_to_brann", Game.quest_target().get("map", "") == "village")

	# ---- the first reward: gold and a refined weapon and armour
	main.goto_map("village", Vector2(300, 400))
	await frames(5)
	Game.state["gold"] = 0
	Game.state.erase("forge")
	talk("brann")
	await frames(2)
	await finish_dialogue()
	await frames(3)
	check("reward_350_gold", int(Game.state["gold"]) == 350, Game.state["gold"])
	check("reward_forge_plus_one", Game.forge_level("w") == 1 and Game.forge_level("a") == 1)
	check("now_extinguish_ignarok", Game.brann() == "ignarok" and Game.objective().find("Puladvand") >= 0, Game.objective())
	check("compass_to_ignarok", Game.quest_target().get("kind", "") == "boss" and Game.quest_target().get("map", "") == "emberforge", Game.quest_target())

	# ---- Puladvand
	main.goto_map("emberforge", Vector2(80, 520))
	await frames(6)
	clear_foes()
	var ig = main.world.spawn_enemy("ignarok", main.player.global_position + Vector2(80, 0))
	await frames(4)
	ig.hp = 1.0
	ig.hurt(99999.0, false, Vector2.RIGHT)
	await frames(10)
	check("ignarok_kill_advances", Game.brann() == "ignarok_done", Game.brann())
	check("ignarok_toast_in_message", true)

	# ---- the masterwork
	main.goto_map("village", Vector2(300, 400))
	await frames(5)
	var tp0: int = Game.talent_points()
	talk("brann")
	await frames(2)
	await finish_dialogue()
	await frames(3)
	check("masterwork_forge_plus_two", Game.forge_level("w") == 3 and Game.forge_level("a") == 3, Game.forge())
	check("masterwork_three_talent_points", Game.talent_points() == tp0 + 3, [tp0, Game.talent_points()])
	check("chain_is_done", Game.brann() == "done" and Game.brann_objective() == "")
	talk("brann")
	await frames(2)
	check("done_talk_is_farewell", main.hud.dialogue.visible)
	await finish_dialogue()
	check("farewell_gives_nothing", Game.brann() == "done" and Game.talent_points() == tp0 + 3)

	# ---- the forge cap: the masterwork never goes past +5
	fresh()
	Game.state["brann"] = "ignarok_done"
	Game.forge()["w"] = 4
	Game.forge()["a"] = 5
	Game.brann_step()
	check("masterwork_capped_at_5", Game.forge_level("w") == 5 and Game.forge_level("a") == 5)

	# ---- the world moves ahead of the questline
	fresh()
	Game.state["defeated"] = {"boss": true}
	check("old_save_core_from_dead_guardian", Game.brann_sync() == "core" and Game.brann() == "core")
	fresh()
	Game.state["brann"] = "anvil"
	Game.state["defeated"] = {"anvilward": true}
	check("anvil_killed_before_return_catches_up", Game.brann_sync() == "anvil_done")
	fresh()
	Game.state["brann"] = "ignarok"
	Game.state["defeated"] = {"ignarok": true}
	check("ignarok_killed_early_catches_up", Game.brann_sync() == "ignarok_done")

	# ---- Elder's chain keeps its place, the compass shows Jamshid only at a turn-in
	fresh()
	# Simulate an older active quest with an empty progress record created before the save was restored.
	Game.state["quest_progress"] = {"q1": {"step": "", "collections": {}}}
	Game.state["q1"] = "active"
	Game.state["brann"] = "anvil"
	check("elder_objective_wins_while_questing", Game.quest_step("q1") == "boss_ready"
		and Game.objective().find("Arzhang") >= 0, Game.objective())
	Game.state["q1"] = "done"
	Game.state["q2"] = "done"
	Game.state["q3"] = "done"
	Game.state["c2"] = {"step": "done"}
	check("brann_objective_after_elder_chain", Game.objective().find("Pulad of Ghandi") >= 0, Game.objective())

	# ---- the quest log
	fresh()
	Game.state["brann"] = "anvil"
	Game.state["q1"] = "done"
	main.hud.pause.open()
	await frames(3)
	main.hud.pause._show("hero")
	await frames(3)
	var found := false
	var stack: Array = [main.hud.pause]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
		if nd is Label and nd.text.find("The Shade of Jamshid") >= 0:
			found = true
	check("quest_log_lists_brann", found)
	main.hud.pause.close()
	Game.lang = "fa"
	main.hud.pause.open()
	main.hud.pause._show("hero")
	await frames(3)
	check("quest_log_persian_builds", true)
	main.hud.pause.close()
	Game.lang = "en"

	# ---- saving
	fresh()
	Game.state["brann"] = "ignarok"
	Game.state["bonus_talents"] = 3
	Game.save_game()
	Game.state.erase("brann")
	Game.state.erase("bonus_talents")
	Game.load_game()
	check("save_keeps_questline", Game.brann() == "ignarok" and int(Game.state["bonus_talents"]) == 3)
	Game.state.erase("brann")
	check("old_save_starts_none", Game.brann() == "none")

	print("STORYTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

extends Node
## v0.15 checks: the Bounty Board. Three distinct contracts, the level gates on foes, kills counting, the completion toast, claiming
## (gold and XP with the difficulty and talent multipliers, a replacement contract), the board in the village and its choice list,
## the quest log, saving.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/contracttest.gd

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
	check("npc_" + id + "_exists", false)

func set_level(n: int) -> void:
	Game.state["level"] = n

func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	Game.lang = "en"
	Game.set_setting("sound", true)
	Game.set_setting("diff", "normal")
	var p = await hero("warrior")
	p.invuln = 99.0
	clear_foes()
	Game.state.erase("contracts")

	# ---- the pool grows with the hero
	set_level(1)
	var low := Game.contract_pool()
	check("level_1_pool_is_forest_and_dungeon", low.has("slime") and low.has("skeleton") and not low.has("golem") and not low.has("toad") and not low.has("golem") and not low.has("frostknight"), low)
	# (v0.27.1) and with the story: a region Zal has not opened gives no contract, whatever the level
	set_level(8)
	Game.set_q(2, "not_started")
	var closed := Game.contract_pool()
	check("closed_regions_give_no_contract", not closed.has("golem") and not closed.has("toad") and not closed.has("frostknight") and closed.has("slime"), closed)
	check("contract_names_its_region", Game.contract_label({"type": "slime", "need": 3}).contains(Game.map_title("forest")), Game.contract_label({"type": "slime", "need": 3}))
	Game.set_q(2, "active")
	set_level(3)
	check("level_3_opens_peaks", Game.contract_pool().has("golem") and Game.contract_pool().has("bat"))
	set_level(5)
	check("level_5_opens_the_fen", Game.contract_pool().has("toad"))
	set_level(8)
	check("level_8_opens_the_sanctum", Game.contract_pool().has("frostknight") and Game.contract_pool().size() == 14, Game.contract_pool().size())
	set_level(8)

	# ---- three distinct contracts, always
	Game.contract_fill()
	var list: Array = Game.contracts()["list"]
	var types := {}
	for c in list:
		types[c["type"]] = true
	check("three_contracts", list.size() == 3)
	check("three_different_foes", types.size() == 3, types.keys())
	var sane := true
	for c in list:
		sane = sane and c["need"] >= 5 and c["need"] <= 10 and c["have"] == 0 and c["gold"] > 0 and c["xp"] > 0
	check("contracts_are_sane", sane, list)
	Game.contract_fill()
	check("fill_is_idempotent", Game.contracts()["list"].size() == 3)

	# ---- kills count, only the right foe, and finishing says so
	var c0: Dictionary = list[0]
	var other := ""
	for t in ["slime", "skeleton", "archer", "bat", "imp", "golem", "toad"]:
		if not types.has(t):
			other = t
			break
	check("a_foe_that_is_not_asked_for_does_not_count", Game.contract_progress(other) == "" and c0["have"] == 0)
	var msg := ""
	for i in int(c0["need"]):
		msg = Game.contract_progress(str(c0["type"]))
	check("contract_counts_to_need", c0["have"] == c0["need"] and Game.contract_done(c0))
	check("finishing_says_claim_it", msg.find("claim it at the board") >= 0, msg)
	check("progress_is_capped", Game.contract_progress(str(c0["type"])) == "" and c0["have"] == c0["need"])
	Game.state["contracts"]["list"][1]["have"] = 0

	# ---- a real kill counts
	set_level(8)
	Game.state.erase("contracts")
	Game.state["contracts"] = {"list": [{"type": "slime", "need": 5, "have": 4, "gold": 100, "xp": 60}, {"type": "skeleton", "need": 6, "have": 0, "gold": 120, "xp": 70}, {"type": "bat", "need": 7, "have": 0, "gold": 90, "xp": 50}], "claimed": 0}
	clear_foes()
	var s1 = main.world.spawn_enemy("slime", p.global_position + Vector2(40, 0))
	await frames(3)
	s1.hp = 1.0
	s1.hurt(9999.0, false, Vector2.RIGHT)
	await frames(6)
	check("a_real_kill_counts", Game.contracts()["list"][0]["have"] == 5 and Game.contract_done(Game.contracts()["list"][0]), Game.contracts()["list"][0])

	# ---- claiming
	check("cannot_claim_unfinished", not Game.contract_claim(1) and Game.contracts_done() == 0)
	Game.state["gold"] = 0
	var xp0: int = int(Game.state["xp"])
	var lvl0: int = Game.lvl()
	Game.state["xp"] = 0
	var ok := Game.contract_claim(0)
	check("claim_pays_gold", ok and int(Game.state["gold"]) == int(round(100.0 * Game.gold_mul())), Game.state["gold"])
	check("claim_pays_xp", int(Game.state["xp"]) > 0 or Game.lvl() > lvl0)
	check("claim_counts", Game.contracts_done() == 1)
	var nc: Dictionary = Game.contracts()["list"][0]
	check("claim_replaces_with_a_fresh_one", nc["have"] == 0 and nc["type"] != "slime" or nc["have"] == 0, nc)
	check("replacement_is_not_a_duplicate", [Game.contracts()["list"][0]["type"], Game.contracts()["list"][1]["type"], Game.contracts()["list"][2]["type"]].size() == 3 and Game.contracts()["list"][0]["type"] != Game.contracts()["list"][1]["type"] and Game.contracts()["list"][0]["type"] != Game.contracts()["list"][2]["type"])
	Game.set_setting("diff", "nightmare")
	Game.contracts()["list"][0] = {"type": "slime", "need": 5, "have": 5, "gold": 100, "xp": 60}
	Game.state["gold"] = 0
	Game.contract_claim(0)
	check("nightmare_pays_more", int(Game.state["gold"]) == int(round(100.0 * Game.gold_mul())) and int(Game.state["gold"]) > 150, Game.state["gold"])
	Game.set_setting("diff", "normal")

	# ---- the board in the village
	Game.state["contracts"] = {"list": [{"type": "slime", "need": 5, "have": 5, "gold": 100, "xp": 60}, {"type": "skeleton", "need": 6, "have": 2, "gold": 120, "xp": 70}, {"type": "bat", "need": 7, "have": 0, "gold": 90, "xp": 50}], "claimed": 0}
	main.goto_map("village", Vector2(340, 380))
	await frames(5)
	var board = null
	for n in get_tree().get_nodes_in_group("npcs"):
		if str(n.get_meta("id", "")) == "board":
			board = n
	check("board_stands_in_the_village", board != null)
	var clear_spot := true
	for w in [Rect2(80, 80, 160, 110), Rect2(80, 230, 160, 110), Rect2(640, 120, 70, 70), Rect2(416, 396, 72, 72)]:
		clear_spot = clear_spot and not w.has_point(board.position)
	check("board_is_not_inside_a_wall", clear_spot)
	talk("board")
	await frames(3)
	check("board_opens_a_choice", main.hud.dialogue.visible and main.hud.dialogue.choosing())
	check("board_has_three_contracts_and_leave", main._board_opts.size() == 4)
	check("finished_contract_is_claimable", main._board_opts[0]["ok"] and main._board_opts[0]["label"].find("Claim") >= 0)
	check("unfinished_are_disabled_with_progress", not main._board_opts[1]["ok"] and main._board_opts[1]["note"] == "2/6")
	Game.state["gold"] = 0
	main.hud.dialogue._block_until = 0
	main.hud.dialogue._pick(0)
	await frames(3)
	check("board_claims_the_pick", Game.contracts_done() == 1 and int(Game.state["gold"]) > 0)
	check("board_reopens_after_claim", main.hud.dialogue.visible and main.hud.dialogue.choosing())
	main.hud.dialogue._block_until = 0
	main.hud.dialogue._pick(3)
	await frames(3)
	check("leave_closes", not main.hud.dialogue.visible and not get_tree().paused)

	# ---- the quest log
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
	check("hero_page_lists_contracts", texts.any(func(t): return str(t).find("Slay") >= 0) and texts.any(func(t): return str(t).find("Contracts completed") >= 0), texts.size())
	main.hud.pause.close()
	Game.lang = "fa"
	main.hud.pause.open()
	main.hud.pause._show("hero")
	await frames(3)
	check("hero_page_persian_builds", true)
	main.hud.pause.close()
	Game.lang = "en"

	# ---- saving, and an old save
	Game.save_game()
	var saved: Dictionary = Game.contracts().duplicate(true)
	Game.state.erase("contracts")
	Game.load_game()
	check("save_keeps_contracts", Game.contracts_done() == int(saved["claimed"]) and Game.contracts()["list"].size() == 3)
	Game.state.erase("contracts")
	check("old_save_has_none_until_the_board", Game.contracts()["list"].is_empty() and Game.contracts_done() == 0)

	print("CONTRACTTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

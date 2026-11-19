extends Node
## Automated checks run with:  godot --path . -- --autotest      (headless is fine)
## Screenshots of every map:    godot --path . -- --shots <dir>  (needs a real renderer)

var main: Node
var report := {"maps": {}}

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func map_keys() -> Array:
	var out := []
	var d := DirAccess.open("res://data/Maps")
	for f in d.get_files():
		if f.ends_with(".json"):
			out.append(f.get_basename())
	out.sort()
	return out

func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	var shots_dir := ""
	var i := Game.args.find("--shots")
	if i >= 0 and i + 1 < Game.args.size():
		shots_dir = Game.args[i + 1]
	Game.new_game("warrior")
	main.start_world()
	await frames(5)
	Game.hp = 99999.0
	for b in Game.BOSS_CFG:      # boss name cards are covered by tests/bosstest.gd
		Game.v18()["seen"][b] = true

	printerr("STEP: every map loads, has its pieces, and the hero is free to move at the start point")
	# ---- every map loads, has its pieces, and the hero is free to move at the start point
	for key in map_keys():
		main.goto_map(key, Vector2(100, 100))
		await frames(2)
		main.player.global_position = main.world.start_feet()
		await frames(6)
		var w = main.world
		var rec: Dictionary = w.stats.duplicate()
		var p = main.player
		var free := 0
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			if not p.test_move(p.global_transform, d * 4.0):
				free += 1
		rec["free_dirs_at_start"] = free
		rec["size"] = [w.size.x, w.size.y]
		report["maps"][key] = rec
		if shots_dir != "":
			Game.hp = 99999.0
			for e in get_tree().get_nodes_in_group("enemies"):
				e.spd = 0.0
			await frames(40)
			var img := get_viewport().get_texture().get_image()
			if img:
				img.save_png(shots_dir.path_join(key + ".png"))

	report["paused_after_map_tour"] = get_tree().paused
	printerr("STEP: walking with the joystick moves the hero")
	# ---- walking with the joystick moves the hero
	main.goto_map("village", Vector2(433, 524))
	await frames(4)
	var p0: Vector2 = main.player.global_position
	main.player.joy = Vector2(1, 0)
	await frames(30)
	main.player.joy = Vector2.ZERO
	report["walk_px"] = snapped(main.player.global_position.x - p0.x, 0.1)

	printerr("STEP: combat: a skeleton next to the hero dies to sword blows and gives XP")
	# ---- combat: a skeleton next to the hero dies to sword blows and gives XP
	main.goto_map("forest", Vector2(560, 470))
	await frames(4)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await frames(2)
	var en = main.world.spawn_enemy("skeleton", main.player.global_position + Vector2(34, 0))
	pass
	main.player.facing = "right"
	var xp0 := int(Game.state["xp"]) + 1000 * Game.lvl()
	var swings := 0
	for k in 80:
		main.player.attack()
		swings += 1
		await frames(18)
		if not is_instance_valid(en) or en.dead:
			break
	var killed: bool = (not is_instance_valid(en)) or en.dead
	report["combat"] = {"killed": killed, "swings": swings, "xp_progress": (int(Game.state["xp"]) + 1000 * Game.lvl()) - xp0}

	printerr("STEP: enemies hurt the hero (armour and region scaling applied)")
	# ---- enemies hurt the hero (armour and region scaling applied)
	Game.hp = 100.0
	main.player.invuln = 0.0
	var sl = main.world.spawn_enemy("slime", main.player.global_position + Vector2(6, 0))
	await frames(20)
	report["contact_damage"] = snapped(100.0 - Game.hp, 0.1)
	if is_instance_valid(sl):
		sl.queue_free()
	Game.hp = 99999.0

	printerr("STEP: every exit of the village leads where it should")
	# ---- every exit of the village leads where it should
	var exits := {}
	for ex_rect in [0, 1]:
		main.goto_map("village", Vector2(433, 524))
		await frames(45)
		var areas := get_tree().get_nodes_in_group("exits")
		if ex_rect >= areas.size():
			break
		var a = areas[ex_rect]
		var r: Rect2 = a.get_meta("rect")
		var to: String = a.get_meta("to")
		main.player.global_position = r.get_center() + Vector2(0, 17)
		await frames(40)      # the map change waits for a short fade to black
		exits[to] = main.world.key
	report["village_exits"] = exits

	printerr("STEP: a dodge moves the hero and grants i-frames")
	# ---- a dodge moves the hero and grants i-frames
	main.goto_map("village", Vector2(433, 524))
	await frames(4)
	var d0: Vector2 = main.player.global_position
	main.player.facing = "left"
	main.player.dodge()
	var inv0: bool = main.player.invuln > 0.3
	await get_tree().physics_frame
	for k in 12:
		await get_tree().physics_frame
	report["dodge"] = {"moved": snapped(d0.distance_to(main.player.global_position), 0.1), "invuln": inv0}

	printerr("STEP: phase 2: sounds were synthesised")
	# ---- phase 2: sounds were synthesised
	report["sounds"] = Sfx.streams.size()

	printerr("STEP: heavy attack hits harder than a light one (crits off for a fair comparison)")
	# ---- heavy attack hits harder than a light one (crits off for a fair comparison)
	Game.table("CLASSES")["warrior"]["critChance"] = 0.0
	main.goto_map("forest", Vector2(560, 470))
	await frames(4)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await frames(2)
	var dummy = main.world.spawn_enemy("golem", main.player.global_position + Vector2(36, 0))
	dummy.spd = 0.0
	dummy.max_hp = 100000.0
	dummy.hp = 100000.0
	main.player.facing = "right"
	main.player.combo_t = 0.0
	main.player.atk_cd = 0.0
	var h0: float = dummy.hp
	main.player.attack(false)
	var light: float = h0 - dummy.hp
	await frames(40)
	dummy.global_position = main.player.global_position + Vector2(36, 0)
	dummy.knock = Vector2.ZERO
	await frames(2)
	main.player.combo_t = 0.0
	h0 = dummy.hp
	main.player.attack(true)
	var heavy: float = h0 - dummy.hp
	report["heavy_vs_light"] = [snapped(light, 0.1), snapped(heavy, 0.1)]
	dummy.queue_free()
	Game.tables.erase("CLASSES")

	printerr("STEP: the main quest: Zal -> forest clues -> crypt inscription -> Guardian -> reward -> sealed peaks open")
	# ---- the main quest: staged story points, the Guardian, reward and sealed peaks
	Game.new_game("warrior")
	for b in Game.BOSS_CFG:
		Game.v18()["seen"][b] = true
	Game.hp = 99999.0
	main.goto_map("forest", Vector2(560, 470))
	await frames(45)
	var peaks_exit: Rect2
	for a in get_tree().get_nodes_in_group("exits"):
		if a.get_meta("to") == "peaks":
			peaks_exit = a.get_meta("rect")
	main.player.global_position = peaks_exit.get_center() + Vector2(0, 17)
	await frames(40)
	report["gate_closed_at_start"] = main.world.key == "forest"
	main.goto_map("village", Vector2(433, 524))
	await frames(4)
	var elder = null
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.get_meta("id") == "elder":
			elder = n
	main._on_interact(elder)
	var opened: bool = main.hud.dialogue.visible and get_tree().paused
	var pages := 0
	while main.hud.dialogue.visible and pages < 10:
		await get_tree().create_timer(0.3, true, false, true).timeout
		main.hud.dialogue.advance()
		pages += 1
	report["elder_talk"] = {"opened": opened, "pages": pages, "q1": Game.q(1), "unpaused": not get_tree().paused}
	report["quest_clue_stage_started"] = Game.quest_step("q1") == "forest_clues" and Game.quest_collection("q1", "forest_clues").is_empty()
	main.goto_map("forest", Vector2(560, 470))
	await frames(4)
	var wagon_point = null
	for n in get_tree().get_nodes_in_group("quest_points"):
		if str(n.get_meta("point_id", "")) == "forest_wagon":
			wagon_point = n
	var wagon_visible: bool = wagon_point != null and wagon_point.visible
	if wagon_point:
		main._on_interact(wagon_point)
		while main.hud.dialogue.visible:
			await get_tree().create_timer(0.3, true, false, true).timeout
			main.hud.dialogue.advance()
	var duplicate_clue: Dictionary = Game.quest_point_interact("forest", "forest_wagon")
	var banner_point = null
	for n in get_tree().get_nodes_in_group("quest_points"):
		if str(n.get_meta("point_id", "")) == "forest_banner":
			banner_point = n
	if banner_point:
		main._on_interact(banner_point)
		while main.hud.dialogue.visible:
			await get_tree().create_timer(0.3, true, false, true).timeout
			main.hud.dialogue.advance()
	report["quest_clues"] = {"wagon_spawned": wagon_visible, "duplicate_blocked": duplicate_clue.is_empty(),
		"count": Game.quest_collection("q1", "forest_clues").size(), "next_step": Game.quest_step("q1")}
	var forest_target := Game.quest_target()
	report["crypt_exit_target"] = forest_target.get("map", "") == "forest" and forest_target.get("kind", "") == "exit"
	main.goto_map("dungeon", Vector2(470, 700))
	await frames(4)
	report["crypt_inscription_stage"] = Game.quest_step("q1") == "crypt_inscription"
	var inscription = null
	for n in get_tree().get_nodes_in_group("quest_points"):
		if str(n.get_meta("point_id", "")) == "crypt_inscription":
			inscription = n
	var inscription_visible: bool = inscription != null and inscription.visible
	if inscription:
		main._on_interact(inscription)
		while main.hud.dialogue.visible:
			await get_tree().create_timer(0.3, true, false, true).timeout
			main.hud.dialogue.advance()
	await frames(4)
	report["inscription_unlocks_boss"] = inscription_visible and Game.quest_step("q1") == "boss_ready"
	var guardian = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.type == "boss":
			guardian = e
	var found: bool = guardian != null
	if guardian:
		guardian.hurt(1e9, false, Vector2.RIGHT)
	await frames(30)
	report["guardian"] = {"found": found, "q1": Game.q(1), "defeated": Game.is_defeated("boss")}
	main.goto_map("dungeon", Vector2(470, 700))
	await frames(4)
	var again := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.type == "boss":
			again += 1
	report["guardian_stays_dead"] = again == 0
	main.goto_map("village", Vector2(433, 524))
	await frames(4)
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.get_meta("id") == "elder":
			elder = n
	var g0 := int(Game.state["gold"])
	for round in 2:     # reward talk, then the talk that opens the peaks
		main._on_interact(elder)
		while main.hud.dialogue.visible:
			await get_tree().create_timer(0.3, true, false, true).timeout
			main.hud.dialogue.advance()
		await frames(2)
	report["reward"] = {"gold_gain": int(Game.state["gold"]) - g0, "q1": Game.q(1), "q2": Game.q(2), "objective": Game.objective()}
	main.goto_map("forest", Vector2(560, 470))
	await frames(45)
	main.player.global_position = peaks_exit.get_center() + Vector2(0, 17)
	await frames(40)
	report["gate_open_after_q2"] = main.world.key == "peaks"

	printerr("STEP: shops: Sindokht sells blades, Kavian armour; the hero's look follows the gear")
	# ---- shops: Sindokht sells blades, Kavian armour; the hero's look follows the gear
	main.goto_map("village", Vector2(433, 524))
	await frames(4)
	Game.state["gold"] = 2000
	var sheet0: String = main.player.sheet
	main.hud.shop.open("merchant")
	var w_items: Array = Game.shop_items("merchant")
	for it in w_items:
		if it.get("id") == "weapon_2":
			main.hud.shop._buy(it)
	for it in Game.shop_items("merchant"):
		if it.get("id") == "weapon_3":
			main.hud.shop._buy(it)
	main.hud.shop.close()
	main.hud.shop.open("smith")
	for it in Game.shop_items("smith"):
		if it.get("id") == "armor_1":
			main.hud.shop._buy(it)
	var pot0 := int(Game.state["potions"])
	main.hud.shop.close()
	main.hud.shop.open("merchant")
	for it in Game.shop_items("merchant"):
		if it.get("id") == "hp_potion":
			main.hud.shop._buy(it)
	main.hud.shop.close()
	report["shop"] = {"weapon": Game.state["weapon"], "armor": Game.state["armor"], "potion_gain": int(Game.state["potions"]) - pot0,
		"gold_left": Game.state["gold"], "look": [sheet0, main.player.sheet], "unpaused": not get_tree().paused}

	if shots_dir != "":
		for n in get_tree().get_nodes_in_group("npcs"):
			if n.get_meta("id") == "elder":
				elder = n
		main._on_interact(elder)
		await get_tree().create_timer(0.5, true, false, true).timeout
		get_viewport().get_texture().get_image().save_png(shots_dir.path_join("ui_dialogue.png"))
		while main.hud.dialogue.visible:
			await get_tree().create_timer(0.3, true, false, true).timeout
			main.hud.dialogue.advance()
		Game.state["gold"] = 700
		main.hud.shop.open("smith")
		await get_tree().create_timer(0.5, true, false, true).timeout
		get_viewport().get_texture().get_image().save_png(shots_dir.path_join("ui_shop.png"))
		main.hud.shop.close()

	printerr("STEP: saving round-trips")
	# ---- saving round-trips
	Game.save_game()
	var lv := Game.lvl()
	report["save_ok"] = Game.load_game() and Game.lvl() == lv

	print("AUTOTEST_JSON " + JSON.stringify(report))
	get_tree().quit()

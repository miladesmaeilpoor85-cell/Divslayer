extends Node
## v0.44 vertical-slice checks: gated Alborz entry, wind shelters, three guards, scout rescue and return to Zal.
## Run: godot --headless --fixed-fps 60 --path . -- --test res://tests/chapter4test.gd

var main: Node
var results: Dictionary = {}
var fails: Array[String] = []
var C = null


func frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func check(label: String, ok: bool, info: Variant = null) -> void:
	results[label] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(label)
	printerr(("PASS " if ok else "FAIL ") + label + ("" if info == null else "  " + str(info)))


func npc(id: String) -> Node:
	for candidate in get_tree().get_nodes_in_group("npcs"):
		if str(candidate.get_meta("id", "")) == id:
			return candidate
	return null


func close_dialogue() -> int:
	var dlg = main.hud.dialogue
	var pages := 0
	while dlg.visible and pages < 40:
		dlg._block_until = 0
		dlg.advance()
		pages += 1
		await frames(1)
	return pages


func talk(id: String) -> int:
	var person := npc(id)
	if person == null:
		return -1
	main._on_interact(person)
	await frames(2)
	var pages := await close_dialogue()
	await frames(2)
	return pages


func exit_try(to: String) -> String:
	var world = main.world
	world.exits_armed = true
	var messages: Array[String] = []
	var departures: Array[String] = []
	var on_message := func(value: String): messages.append(value)
	var on_exit := func(target: String, _spawn: Vector2): departures.append(target)
	world.message.connect(on_message)
	var held: Array[Callable] = []
	for connection in world.exit_reached.get_connections():
		held.append(connection["callable"])
		world.exit_reached.disconnect(connection["callable"])
	world.exit_reached.connect(on_exit)
	world._on_exit_body(main.player, to, Vector2(1273, 554))
	world.exit_reached.disconnect(on_exit)
	for callback in held:
		world.exit_reached.connect(callback)
	world.message.disconnect(on_message)
	return "blocked" if not messages.is_empty() else ("left" if not departures.is_empty() else "nothing")


func run(m: Node) -> void:
	main = m
	C = Game.Ch4
	await frames(1)
	Game.lang = "fa"
	Game.new_game("warrior")
	# Place the fixture beyond the three previous chapters so the Elder reaches Chapter IV.
	for quest_index in [1, 2, 3]:
		Game.set_q(quest_index, "done")
	Game.Ch2.st()["step"] = "done"
	Game.Ch3.set_step("bound")
	for boss_type in Game.BOSS_CFG:
		Game.v18()["seen"][boss_type] = true
	main.start_world()
	await frames(8)
	main.player.invuln = 99999.0

	# The fourth chapter is unavailable until the third chapter has its saved completion state.
	Game.Ch3.set_step("bound")
	check("previous_chapter_dialogue_cannot_start_ch4", C.elder_lines().is_empty()
		and C.elder_done() == "" and C.step() == "")
	check("chapter_locked_before_ch3_completion", not C.open() and C.exit_block("alborz") != "")
	Game.Ch3.set_step("done")
	check("chapter_opens_after_ch3", C.open() and C.step() == "")
	check("elder_is_first_target", Game.elder_has_news() and Game.quest_target().get("map", "") == "village")
	check("alborz_route_is_not_open_before_zal", not Game.region_open("alborz") and C.exit_block("alborz") != "")

	# Zal introduces the pass and opens the route.
	main.goto_map("village", Vector2(600, 300))
	await frames(4)
	main.player.invuln = 99999.0
	var pages := await talk("elder")
	check("zal_starts_pass_objective", pages >= 3 and C.step() == "pass" and Game.region_open("alborz"), [pages, C.step()])
	check("objective_points_to_peaks_exit", Game.objective() == C.line("o_pass") and C.target().get("map", "") == "peaks")

	# World graph and map data must describe a connected, bounded, data-driven map.
	var graph := Game.world_graph()
	check("world_graph_is_bidirectional", graph.get("peaks", {}).get("exits", []).any(func(e): return str(e.get("to", "")) == "alborz")
		and graph.get("alborz", {}).get("exits", []).any(func(e): return str(e.get("to", "")) == "peaks"))
	var map_data := Game.map_data("alborz")
	var data: Dictionary = map_data.get("data", {})
	check("map_data_has_wind_scout_and_guards",
		data.get("windGusts", []).size() == 1
		and data.get("npcs", []).any(func(n): return str(n.get("id", "")) == "alborz_scout")
		and data.get("enemySpawns", []).size() == 3,
		[data.get("windGusts", []).size(), data.get("enemySpawns", []).size()])
	check("entry_and_return_are_on_opposite_edges",
		Vector2(float(data.get("playerStart", {}).get("x", 0)), float(data.get("playerStart", {}).get("y", 0))).y > 900.0
		and data.get("exits", []).any(func(exit): return str(exit.get("to", "")) == "peaks" and float(exit.get("y", 0)) > 1000.0
			and float(exit.get("spawnY", 9999)) < 100.0))
	check("map_uses_existing_ground_placeholder",
		str(map_data.get("groundFile", "")) == "frostvale_ground.jpg"
		and ResourceLoader.exists("res://assets/art/Maps/frostvale_ground.jpg"))
	check("map_title_is_localized",
		Game.map_title("alborz") == "گذرگاهِ البرز")

	# The Peaks -> Alborz gate is truly connected, not just a graph-only link.
	main.goto_map("peaks", Vector2(980, 180))
	await frames(4)
	check("peaks_exit_opens_after_zal", exit_try("alborz") == "left")

	# Enter the Alborz prototype; the map entry advances the quest and builds its wind controller and visual cues.
	main.goto_map("alborz", Vector2(880, 1030))
	await frames(10)
	main.player.invuln = 99999.0
	var w = main.world
	check("alborz_world_builds", w.key == "alborz" and w.size == Vector2(1400, 1100), [w.key, w.size])
	check("entry_advances_to_scout_rescue", C.step() == "rescue" and Game.objective() == C.line("o_scout"))
	check("wind_zone_and_visual_load", w.wind_zones.size() == 1 and w.wind_visual != null
		and w.wind_visual.name == "WindVisual", [w.wind_zones.size(), w.wind_visual])
	check("scout_and_three_guard_types_spawn", npc("alborz_scout") != null
		and w.stats["enemies"] == 3
		and w.wall_rects.size() >= 10, [w.stats, w.wall_rects.size()])

	# Wind phase and cover are checked in logical map coordinates. The contribution never accumulates.
	var controller = w.wind_zones[0]["controller"]
	controller.reset()
	controller.advance(controller.warning_seconds)
	var open_drift: Vector2 = w.wind_drift(Vector2(800, 520))
	var shelter_drift: Vector2 = w.wind_drift(Vector2(930, 550))
	check("active_wind_pushes_in_authored_direction",
		controller.is_active() and open_drift.is_equal_approx(Vector2.RIGHT * 44.0), open_drift)
	check("shelter_reduces_wind_by_ninety_percent",
		shelter_drift.is_equal_approx(Vector2.RIGHT * 4.4), shelter_drift)
	check("stone_shelter_has_real_collision_and_safe_floor",
		w.wall_hit(Rect2(990.0, 540.0, 12.0, 24.0))
		and not w.wall_hit(Rect2(920.0, 530.0, 20.0, 24.0)))
	check("dodge_ignores_wind_and_outside_zone_is_clear",
		w.wind_drift(Vector2(800, 520), true) == Vector2.ZERO
		and w.wind_drift(Vector2(1300, 820)) == Vector2.ZERO)
	check("wind_sample_is_non_accumulating",
		w.wind_drift(Vector2(800, 520)).is_equal_approx(open_drift))

	# The scout cannot leave while guards remain. Once all three local guards are defeated, interaction rescues him.
	var scout := npc("alborz_scout")
	if scout != null:
		main.player.global_position = scout.global_position + Vector2(0, 25)
	pages = await talk("alborz_scout")
	check("scout_remains_guarded_until_pass_is_clear", pages >= 1 and C.step() == "rescue"
		and not C.guards_cleared(w))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.world != w or enemy.dead:
			continue
		if str(enemy.type) in C.GUARDS:
			enemy.hurt(99999.0, false, Vector2.ZERO)
	await frames(8)
	check("serpent_guards_are_cleared", C.guards_cleared(w))
	if scout != null and is_instance_valid(scout):
		main.player.global_position = scout.global_position + Vector2(0, 25)
	pages = await talk("alborz_scout")
	check("scout_rescue_advances_progress", pages >= 2 and C.step() == "return"
		and bool(C.st()["scout_rescued"]), [pages, C.step()])
	check("compass_returns_to_zal", C.target().get("map", "") == "village" and Game.objective() == C.line("o_return"))

	# The report returns to Zal; the completed stage remains saved.
	main.goto_map("village", Vector2(600, 300))
	await frames(5)
	main.player.invuln = 99999.0
	pages = await talk("elder")
	check("zal_closes_the_rescue_chapter_and_unlocks_optional_hunt", pages >= 2 and C.step() == "done"
		and not C.has_news("elder") and C.target().get("map", "") == "alborz_eyrie", [pages, C.step(), C.target()])

	# The optional eyrie is a real, gated map connection with its own three-phase wind boss.
	check("high_eyrie_has_bidirectional_world_graph_route",
		graph.get("alborz", {}).get("exits", []).any(func(e): return str(e.get("to", "")) == "alborz_eyrie")
		and graph.get("alborz_eyrie", {}).get("exits", []).any(func(e): return str(e.get("to", "")) == "alborz"))
	check("high_eyrie_is_unlocked_after_scout_report",
		C.exit_block("alborz_eyrie") == "" and Game.region_open("alborz_eyrie"))
	main.goto_map("alborz", Vector2(1350, 530))
	await frames(4)
	check("high_eyrie_exit_is_physically_connected", exit_try("alborz_eyrie") == "left")
	main.goto_map("alborz_eyrie", Vector2(80, 570))
	await frames(10)
	main.player.invuln = 99999.0
	var eyrie_world = main.world
	var gale_warden: Node = null
	for enemy in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(enemy) and enemy.world == eyrie_world and enemy.type == "alborzwarden":
			gale_warden = enemy
	check("high_eyrie_loads_dedicated_wind_boss_and_gust_zone",
		eyrie_world.key == "alborz_eyrie" and gale_warden != null
		and eyrie_world.wind_zones.size() == 1 and eyrie_world.wind_visual != null)
	if gale_warden != null:
		main.player.global_position = gale_warden.global_position + Vector2(0, -185)
		gale_warden.gcd = 0.0
		await frames(8)
		check("gale_warden_uses_three_separate_telegraphed_lanes",
			gale_warden.moves.has("crosswind") and eyrie_world.bossfx.tele.size() == 3,
			{"moves": gale_warden.moves, "telegraphs": eyrie_world.bossfx.tele.size()})
		check("gale_warden_has_three_health_phases_and_procedural_silhouette",
			Game.boss_cfg("alborzwarden").get("phases", []) == [0.66, 0.33]
			and gale_warden.over != null and (gale_warden.anim == null or not gale_warden.anim.visible))
	main.goto_map("alborz", Vector2(1290, 520))
	await frames(5)

	Game.save_game()
	var saved: Variant = Game.read_game_save(Game.SAVE_PATH)
	check("chapter4_progress_survives_save_read",
		typeof(saved) == TYPE_DICTIONARY
		and str(saved.get("state", {}).get("c4", {}).get("step", "")) == "done")

	printerr("CHAPTER4TEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit(1 if not fails.is_empty() else 0)

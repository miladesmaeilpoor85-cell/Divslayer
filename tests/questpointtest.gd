extends Node
## Regression coverage for the staged Arzhang quest:
## Zal -> 2 of 3 forest clues -> Sunken Crypt inscription -> Arzhang -> Zal.
## Also checks save persistence and migration of legacy active q1 saves.
## Run: godot --headless --fixed-fps 60 --path . -- --test res://tests/questpointtest.gd

var main: Node
var results: Dictionary = {}
var fails: Array[String] = []

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func check(label: String, ok: bool, info = null) -> void:
	results[label] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(label)
	printerr(("PASS " if ok else "FAIL ") + label + ("" if info == null else "  " + str(info)))

func npc(id: String) -> Node:
	for node in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(node) and str(node.get_meta("id", "")) == id:
			return node
	return null

func quest_point(id: String) -> Node:
	for node in get_tree().get_nodes_in_group("quest_points"):
		if is_instance_valid(node) and str(node.get_meta("point_id", "")) == id:
			return node
	return null

func live_arzhang_count() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(enemy) and enemy.world == main.world and enemy.type == "boss" and not enemy.dead:
			count += 1
	return count

func finish_dialogue() -> void:
	var dialogue = main.hud.dialogue
	var guard := 0
	while dialogue.visible and not dialogue.choosing() and guard < 40:
		if not dialogue.typing_done():
			dialogue._block_until = 0
			dialogue.advance()
		dialogue._block_until = 0
		dialogue.advance()
		guard += 1
		await frames(1)
	await frames(2)

func run(m: Node) -> void:
	main = m
	await frames(1)
	Game.lang = "en"
	Game.new_game("warrior")
	# The tutorial remains optional, but this regression suite focuses on Zal's quest.
	Game.state["tut"] = {"step": "skipped", "hits": 0, "rolls": 0}
	main.start_world()
	await frames(5)
	main.player.invuln = 99999.0
	main.goto_map("village", Vector2(600, 560))
	await frames(5)

	# Accept the quest through the real Zal interaction.
	var zal := npc("elder")
	check("zal_npc_exists", zal != null)
	if zal == null:
		get_tree().quit(1)
		return
	main._on_interact(zal)
	await frames(2)
	await finish_dialogue()
	check("zal_starts_forest_clue_stage",
		Game.q(1) == "active" and Game.quest_step("q1") == "forest_clues"
		and Game.quest_collection("q1", "forest_clues").is_empty(),
		{"q1": Game.q(1), "step": Game.quest_step("q1")})

	# All three clue points appear in the forest.
	main.goto_map("forest", Vector2(560, 470))
	await frames(5)
	var wagon := quest_point("forest_wagon")
	var banner := quest_point("forest_banner")
	var stone := quest_point("forest_stone")
	check("three_clue_points_spawn",
		wagon != null and banner != null and stone != null
		and wagon.visible and banner.visible and stone.visible)

	# Collect the first clue through the same interaction path used by the game.
	if wagon != null:
		main.player.global_position = wagon.global_position + Vector2(0, 24)
		main._on_interact(wagon)
		await frames(2)
		await finish_dialogue()
	check("first_clue_counts_once",
		Game.quest_collection("q1", "forest_clues").size() == 1
		and Game.quest_step("q1") == "forest_clues",
		Game.quest_collection("q1", "forest_clues"))
	check("duplicate_clue_is_rejected",
		Game.quest_point_interact("forest", "forest_wagon").is_empty())

	# A save/load round trip must keep the partial collection.
	Game.save_game()
	var loaded := Game.load_game()
	check("one_clue_survives_save_load",
		loaded and Game.quest_step("q1") == "forest_clues"
		and Game.quest_collection("q1", "forest_clues").size() == 1)

	# The second clue is sufficient; the third must remain optional.
	if banner != null:
		main.player.global_position = banner.global_position + Vector2(0, 24)
		main._on_interact(banner)
		await frames(2)
		await finish_dialogue()
	check("two_of_three_unlocks_crypt_route",
		Game.quest_collection("q1", "forest_clues").size() == 2
		and Game.quest_step("q1") == "crypt_entry",
		{"clues": Game.quest_collection("q1", "forest_clues"), "step": Game.quest_step("q1")})
	var forest_target := Game.quest_target()
	check("compass_targets_northern_crypt_exit",
		forest_target.get("map", "") == "forest" and forest_target.get("kind", "") == "exit",
		forest_target)
	check("third_clue_is_not_required",
		not Game.quest_point_available("forest", "forest_stone")
		and (stone == null or not stone.visible))

	# Entering the Crypt changes the stage to the inscription; Arzhang stays locked.
	main.goto_map("dungeon", Vector2(470, 700))
	await frames(5)
	var inscription := quest_point("crypt_inscription")
	check("crypt_entry_advances_to_inscription",
		Game.quest_step("q1") == "crypt_inscription"
		and inscription != null and inscription.visible,
		{"step": Game.quest_step("q1"), "inscription": inscription != null})
	check("arzhang_is_locked_before_inscription", live_arzhang_count() == 0, live_arzhang_count())

	# Reading the inscription unlocks exactly one existing Arzhang boss.
	if inscription != null:
		main.player.global_position = inscription.global_position + Vector2(0, 24)
		main._on_interact(inscription)
		await frames(2)
		await finish_dialogue()
	await frames(3)
	check("inscription_unlocks_single_arzhang",
		Game.quest_step("q1") == "boss_ready" and live_arzhang_count() == 1,
		{"step": Game.quest_step("q1"), "bosses": live_arzhang_count()})

	# Defeating the existing boss completes q1 and points back to Zal.
	var arzhang: Node = null
	for enemy in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(enemy) and enemy.world == main.world and enemy.type == "boss" and not enemy.dead:
			arzhang = enemy
			break
	if arzhang != null:
		arzhang.hurt(1e9, false, Vector2.RIGHT)
	await frames(35)
	check("arzhang_defeat_completes_q1",
		arzhang != null and Game.is_defeated("boss")
		and Game.q(1) == "complete" and Game.quest_step("q1") == "complete",
		{"defeated": Game.is_defeated("boss"), "q1": Game.q(1), "step": Game.quest_step("q1")})
	check("completed_quest_points_back_to_zal",
		Game.objective() == Game.t("Return to Zal", "Return to Zal"),
		Game.objective())

	# A previous save with active q1 but no new progress must skip the new clue route.
	Game.new_game("rogue")
	Game.state["tut"] = {"step": "skipped", "hits": 0, "rolls": 0}
	Game.set_q(1, "active")
	Game.state.erase("quest_progress")
	check("legacy_active_save_migrates_to_boss_ready",
		Game.quest_step("q1") == "boss_ready", Game.quest_step("q1"))
	main.goto_map("dungeon", Vector2(470, 700))
	await frames(5)
	check("legacy_save_spawns_exactly_one_arzhang",
		live_arzhang_count() == 1, live_arzhang_count())

	printerr("QUESTPOINTTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit(1 if not fails.is_empty() else 0)

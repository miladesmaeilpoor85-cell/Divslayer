extends Node
## v0.19 checks: chapter 2, "The Sleeper Beneath". The new maps build (the Hoarfrost Vale, the Wyrm's Hollow) with their
## art, foes, villager and sounds; the whole story runs through the real talk paths: the Elder's tremor, the Memory
## Keeper, the gates (rimeglass east, the Wyrm's door), the three shards (the White Div, Akvan the Div, the vault broken
## by heavy blows), Hom's two quests (eight wolves, three journal pages) and his shop, Jamshid's frost-steel, the Wyrm Key,
## the descent, the two new boss fights (their moves, phases, minions), the Wyrm's own music, the end of the chapter
## (the epilogue and the ending card), the quest log, saving, the shooters' frost bolts.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/chapter2test.gd

var main: Node
var results := {}
var fails: Array = []
var C = null

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func secs(t: float) -> void:
	var w := Time.get_ticks_msec()
	while Time.get_ticks_msec() - w < int(t * 1000.0):
		await get_tree().process_frame

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

## close whatever dialogue is open, page by page (the dialogue blocks a page for a moment in real time)
func close_dialogue() -> int:
	var dlg = main.hud.dialogue
	var pages := 0
	while dlg.visible and pages < 80:
		dlg._block_until = 0
		dlg.advance()
		pages += 1
		await frames(1)
	return pages

func talk(id: String) -> int:
	var n := npc(id)
	if n == null:
		return -1
	main._on_interact(n)
	await frames(2)
	var p := await close_dialogue()
	await frames(2)
	if main.hud.shop.visible:
		main.hud.shop.close()
	if main.hud.ending.visible:
		pass
	return p

func foes(type: String) -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.type == type and not e.dead:
			out.append(e)
	return out

func exit_try(to: String) -> String:
	# walk into the exit: the world's own handler, armed — but the trip itself is held back (main's travel is unhooked)
	var w = main.world
	w.exits_armed = true
	var msgs := []
	var left := []
	var cb := func(t): msgs.append(t)
	var cb2 := func(a, b): left.append(a)
	w.message.connect(cb)
	var held := []
	for c in w.exit_reached.get_connections():
		held.append(c["callable"])
		w.exit_reached.disconnect(c["callable"])
	w.exit_reached.connect(cb2)
	w._on_exit_body(main.player, to, Vector2(40, 540))
	w.exit_reached.disconnect(cb2)
	for c in held:
		w.exit_reached.connect(c)
	w.message.disconnect(cb)
	w.exits_armed = true
	return "blocked" if not msgs.is_empty() else ("left" if not left.is_empty() else "nothing")

func run(m: Node) -> void:
	main = m
	C = Game.Ch2
	await get_tree().process_frame
	Game.lang = "fa"
	Game.new_game("warrior")
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	main.start_world()
	await frames(10)
	main.player.invuln = 99999.0

	# ---- data and art
	var g := Game.world_graph()
	var ex := []
	for e in g["sanctum"]["exits"]:
		ex.append(str(e["to"]))
	check("graph_links_new_maps", ex.has("frostvale") and ex.has("wyrmhollow") and g["frostvale"]["exits"][0]["to"] == "sanctum"
		and g["wyrmhollow"]["exits"][0]["to"] == "sanctum" and g["frostvale"]["npcs"].has("hesk") and g["wyrmhollow"]["bosses"].has("ancientwyrm"), ex)
	check("map_titles", Game.map_title("frostvale") == "درهٔ یخ‌بندان" and Game.map_title("wyrmhollow") == "مغاکِ اژدها", [Game.map_title("frostvale"), Game.map_title("wyrmhollow")])
	var Sheets = load("res://scripts/sheets.gd")
	var arts := []
	for t in ["frostwolf", "rimewraith", "wyrmling", "glaciertitan", "ancientwyrm"]:
		if Sheets.enemy(t).is_empty():
			arts.append(t)
	check("new_foes_have_art", arts.is_empty() and not Sheets.character("npcs", "hesk").is_empty(), arts)
	check("bosses_configured", Game.boss_cfg("glaciertitan").get("mini", false) and Game.boss_cfg("ancientwyrm").get("rework", false)
		and Game.is_boss_type("glaciertitan") and Game.enemy_name("frostwolf") == "گرگِ هفت‌خوان")   # (v0.34) the foes take their names from the Shahnameh
	check("titan_and_wyrm_strength", Game.enemy_stats("glaciertitan", "frostvale")["hp"] > 4000 and Game.enemy_stats("ancientwyrm", "wyrmhollow")["hp"] > 12000,
		[Game.enemy_stats("glaciertitan", "frostvale")["hp"], Game.enemy_stats("ancientwyrm", "wyrmhollow")["hp"]])
	check("new_tracks", Music.has_track("frostvale") and Music.has_track("wyrmhollow") and Music.has_track("boss_ancientwyrm"))

	# ---- before the chapter: Sorush is quiet, the gates are shut, the vault does not scratch
	check("not_open_before_the_elder_quests", not C.open() and C.objective() == "" and C.target().is_empty())
	main.goto_map("sanctum", Vector2(560, 560))
	await frames(5)
	main.player.invuln = 99999.0
	check("sanctum_pieces", main.world.vault != null and main.world.vault.cells.size() == 5 and main.world.get_node_or_null("WyrmDoor") != null
		and not main.world.vault.chest.is_empty(), main.world.vault.cells.size() if main.world.vault else -1)
	check("east_gate_shut", exit_try("frostvale") == "blocked")
	check("wyrm_door_shut", exit_try("wyrmhollow") == "blocked")
	var cell0: Dictionary = main.world.vault.cells[1]
	main.world.vault.strike(cell0["rect"].grow(2), Vector2.RIGHT, true)
	check("vault_unbreakable_before", float(cell0["hp"]) == main.world.vault.HP)
	await talk("keeper")
	check("keeper_quiet_before", C.step() == "")

	# ---- the Elder's three quests done: the tremor
	for n in [1, 2, 3]:
		Game.set_q(n, "done")
	Game.brann_set("done")         # Jamshid's own "return to me" steps come first in the objective line
	var dfd: Dictionary = Game.state.get("defeated", {})
	for b in ["boss", "boss2", "matriarch"]:
		dfd[b] = true
	Game.state["defeated"] = dfd
	check("chapter_opens", C.open() and C.objective() == C.line("o_elder") and C.target()["map"] == "village" and Game.elder_has_news())
	main.goto_map("village", Vector2(450, 470))
	await frames(5)
	main.player.invuln = 99999.0
	var pages := await talk("elder")
	check("elder_tells_of_the_wyrm", C.step() == "keeper" and pages >= 4, [C.step(), pages])
	check("objective_keeper", Game.objective() == C.line("o_keeper") and Game.quest_target()["map"] == "sanctum")

	# ---- Sorush: the shards; the east passage and the vault open
	main.goto_map("sanctum", Vector2(560, 560))
	await frames(5)
	main.player.invuln = 99999.0
	await talk("keeper")
	check("keeper_sets_the_task", C.step() == "shards" and C.east_open() and C.shards_have() == 0, [C.step(), C.shards_have()])
	check("objective_names_next_shard", Game.objective().find(C.line("o_judgement")) >= 0 and Game.quest_target()["kind"] == "boss", Game.objective())
	check("east_gate_open", exit_try("frostvale") == "left")
	main.goto_map("sanctum", Vector2(1100, 160))
	await frames(5)
	main.player.invuln = 99999.0
	check("wyrm_door_still_shut", exit_try("wyrmhollow") == "blocked")

	# ---- the vault: a plain blow only chips, two heavy blows break a cell; then the chest
	var v = main.world.vault
	var c1: Dictionary = v.cells[1]
	v.strike(c1["rect"].grow(2), Vector2.RIGHT, false)
	check("plain_blow_chips", float(c1["hp"]) < v.HP and float(c1["hp"]) > 0.0, c1["hp"])
	v.strike(c1["rect"].grow(2), Vector2.RIGHT, true)
	v.strike(c1["rect"].grow(2), Vector2.RIGHT, true)
	await frames(3)
	check("heavy_blows_break_rimeglass", float(c1["hp"]) <= 0.0 and c1["body"] == null and C.st()["vault"].has(c1["id"]))
	var gold0: int = int(Game.state["gold"])
	main.player.global_position = v.chest["rect"].get_center() + Vector2(0, 8)
	await frames(4)
	check("vault_chest_gives_shard_of_memory", v.is_open() and bool(C.st()["shards"]["memory"]) and int(Game.state["gold"]) > gold0 and C.shards_have() == 1, [v.is_open(), C.shards_have()])
	# fire melts at once (a fire spell's element)
	var c3: Dictionary = v.cells[3]
	v.element(c3["rect"].get_center(), 40.0, "burn")
	check("fire_melts_rimeglass", float(c3["hp"]) <= 0.0)

	# ---- the White Div falls: the Shard of Judgement
	var arb := foes("arbiter")
	check("arbiter_present", arb.size() == 1)
	if not arb.is_empty():
		arb[0].die()
	await frames(3)
	check("arbiter_gives_shard_of_judgement", bool(C.st()["shards"]["judgement"]) and C.shards_have() == 2 and Game.objective().find(C.line("o_frost")) >= 0, Game.objective())
	check("compass_to_the_vale", Game.quest_target()["map"] == "frostvale" and Game.next_hop("sanctum", "frostvale") == "frostvale")

	# ---- the Hoarfrost Vale: Hom, his shop and quests; foes; Akvan
	main.goto_map("frostvale", main.world.start_feet() if false else Vector2(53, 540))
	await frames(8)
	main.player.invuln = 99999.0
	var w = main.world
	check("vale_built", w.key == "frostvale" and w.stats["objects"] > 100 and w.stats["walls"] > 60 and npc("hesk") != null and foes("glaciertitan").size() == 1
		and foes("frostwolf").size() == 9 and foes("rimewraith").size() == 2, w.stats)
	check("vale_start_is_free", not w.wall_hit(Rect2(Vector2(53, 540) - Vector2(10, 20), Vector2(20, 20))))
	check("vale_music_and_air", Music.region == "frostvale" and w.atmos.weather in ["", "snow"] and Music._amb_want["wind"])
	check("hesk_has_news", C.has_news("hesk") and w._markers.any(func(mk): return mk.get_meta("id", "") == "hesk" and mk.visible))
	main._on_interact(npc("hesk"))
	await frames(2)
	await close_dialogue()
	await frames(2)
	check("hesk_opens_his_shop", main.hud.shop.visible and main.hud.shop.vendor == "hesk")
	var gp0: int = int(Game.state.get("greater", 0))
	Game.state["gold"] = int(Game.state["gold"]) + 100
	var bought: String = Game.buy("hesk", {"id": "greater_potion", "name": "Greater Potion", "price": 40})
	check("hesk_sells_greater_potions", bought != "" and int(Game.state.get("greater", 0)) == gp0 + 1)
	main.hud.shop.close()
	check("hesk_quests_start", bool(C.hesk()["met"]) and C.hesk()["wolves_st"] == "active" and C.hesk()["pages_st"] == "active")
	# a shooter looses frost bolts at the hero
	var wr := foes("rimewraith")
	var shots0: int = w.bossfx.shots.size()
	if not wr.is_empty():
		main.player.global_position = wr[0].global_position + Vector2(180, 0)
		wr[0].shoot_t = 0.0
		await frames(4)
	check("rime_wraith_shoots", w.bossfx.shots.size() > shots0, [shots0, w.bossfx.shots.size()])
	main.player.global_position = Vector2(300, 760)
	# eight wolves
	var wolves := foes("frostwolf")
	for i in min(8, wolves.size()):
		wolves[i].die()
	await frames(3)
	check("eight_wolves_counted", C.hesk()["wolves_st"] == "ready" and int(C.hesk()["wolves"]) == 8 and C.has_news("hesk"), C.hesk())
	# the three pages: walk onto each
	var page_nodes := []
	for n in get_tree().get_nodes_in_group("pickups"):
		if str(n.get_meta("kind", "")).begins_with("page"):
			page_nodes.append(n)
	var lore_open := 0
	for n in page_nodes:
		main.player.global_position = n.global_position
		await frames(3)
		if main.hud.dialogue.visible:
			lore_open += 1
		await close_dialogue()
	check("three_pages_found_and_read", page_nodes.size() == 3 and lore_open == 3 and C.hesk()["pages_st"] == "ready", [page_nodes.size(), lore_open, C.hesk()])
	var gold1: int = int(Game.state["gold"])
	main.player.global_position = Vector2(300, 830)
	await talk("hesk")
	check("hesk_pays_both", C.hesk()["wolves_st"] == "done" and C.hesk()["pages_st"] == "done" and int(Game.state["gold"]) >= gold1 + 500, [int(Game.state["gold"]) - gold1])

	# ---- Akvan the Div: its kit, its second phase, its minions; it drops the Shard of Frost and the frost-heart
	var ti := foes("glaciertitan")
	var titan = ti[0] if not ti.is_empty() else null
	check("titan_is_a_boss", titan != null and titan.is_in_group("bosses") and titan.mini)
	if titan:
		main.player.global_position = titan.global_position + Vector2(-110, 10)
		await secs(0.2)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 9000 and titan.moves.size() < 4:
			main.player.global_position = titan.global_position + Vector2(-90 - 60 * sin(Time.get_ticks_msec() / 700.0), 20)
			await frames(1)
		check("titan_engages", titan.engaged, titan.moves)
		check("titan_uses_its_moves", titan.moves.size() >= 3, titan.moves)
		titan.hp = titan.max_hp * 0.45
		await frames(3)
		t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 12000 and not titan.moves.has("call"):
			await frames(1)
		check("titan_phase_two_calls_icelings", titan.ph == 2 and titan.moves.has("call") and titan._alive_minions() > 0, [titan.ph, titan.moves])
		titan.die()
	await frames(3)
	check("titan_gives_shard_of_frost", bool(C.st()["shards"]["frost"]) and C.shards_have() == 3 and C.step() == "forge" and C.st()["heart"] == "have", [C.step(), C.shards_have()])
	check("objective_forge", Game.objective() == C.line("o_forge"))

	# ---- Jamshid forges the Frostreaver and the Glacial Aegis
	Game.state["weapon"] = 5
	Game.state["armor"] = 4
	main.goto_map("village", Vector2(260, 520))
	await frames(5)
	main.player.invuln = 99999.0
	check("brann_has_news", C.has_news("brann"))
	var atk0: float = Game.atk()
	await talk("brann")
	check("brann_forges_frost_steel", int(Game.state["weapon"]) == 6 and int(Game.state["armor"]) == 5 and C.st()["heart"] == "forged" and Game.atk() > atk0 + 10.0
		and main.player.sheet.ends_with("endgame"), [Game.state["weapon"], Game.state["armor"], main.player.sheet])

	# ---- Sorush mends the Wyrm Key; the door opens
	main.goto_map("sanctum", Vector2(560, 560))
	await frames(5)
	main.player.invuln = 99999.0
	await talk("keeper")
	check("wyrm_key_forged", C.step() == "descend" and C.door_open() and Game.quest_target()["map"] == "wyrmhollow", C.step())
	main.goto_map("sanctum", Vector2(660, 120))
	await frames(5)
	check("wyrm_door_opens", exit_try("wyrmhollow") == "left")

	# ---- the Wyrm's Hollow and the Dragon of Kashaf
	main.goto_map("wyrmhollow", Vector2(650, 74))
	await frames(8)
	main.player.invuln = 99999.0
	w = main.world
	check("hollow_built", w.key == "wyrmhollow" and Game.indoor("wyrmhollow") and w.stats["walls"] > 50 and foes("ancientwyrm").size() == 1
		and foes("wyrmling").size() == 3, [w.stats, foes("wyrmling").size()])
	check("hollow_start_is_free", not w.wall_hit(Rect2(Vector2(650, 74) - Vector2(10, 20), Vector2(20, 20))))
	check("hollow_ambience", Music._amb_want["cave"] and Music.region == "wyrmhollow")
	var wy := foes("ancientwyrm")
	var wyrm = wy[0] if not wy.is_empty() else null
	if wyrm:
		main.player.global_position = wyrm.global_position + Vector2(-150, 0)
		await secs(0.2)
		check("wyrm_music", Music.boss and Music.track_key() == "boss_ancientwyrm", Music.track_key())
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 12000 and wyrm.moves.size() < 4:
			main.player.global_position = wyrm.global_position + Vector2(-120 - 90 * sin(Time.get_ticks_msec() / 800.0), 30)
			await frames(1)
		check("wyrm_phase_one_moves", wyrm.moves.size() >= 3 and (wyrm.moves.has("breath") or wyrm.moves.has("tail") or wyrm.moves.has("shards")), wyrm.moves)
		wyrm.hp = wyrm.max_hp * 0.6
		await frames(3)
		check("wyrm_spreads_its_wings", wyrm.ph == 2 and wyrm.anim.animation == "v1", [wyrm.ph, wyrm.anim.animation])
		t1 = Time.get_ticks_msec()
		var flew := false
		while Time.get_ticks_msec() - t1 < 15000 and not (wyrm.moves.has("fly") and wyrm.moves.has("brood")):
			main.player.global_position = wyrm.global_position + Vector2(-160, 40) if not wyrm.cloaked else main.player.global_position
			flew = flew or wyrm.cloaked
			await frames(1)
		flew = flew or wyrm.cloaked
		var landed := false
		var t2 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t2 < 6000 and flew and not landed:
			landed = not wyrm.cloaked and not wyrm.shadow_on
			await frames(1)
		check("wyrm_flies_and_dives", wyrm.moves.has("fly") and flew and landed, [wyrm.moves, flew, landed])
		check("wyrm_calls_its_brood", wyrm.moves.has("brood"), wyrm.moves)
		wyrm.hp = wyrm.max_hp * 0.3
		await frames(3)
		check("wyrm_final_phase", wyrm.ph == 3)
		wyrm.die()
	await frames(5)
	check("wyrm_slain", C.step() == "slain" and Game.is_defeated("ancientwyrm") and Game.objective() == C.line("o_slain"))
	check("wyrmking_crown", Game.Gear.has_relic("vengeance"))

	# ---- the epilogue and the end of the chapter
	main.goto_map("village", Vector2(450, 470))
	await frames(5)
	main.player.invuln = 99999.0
	await talk("elder")
	await secs(0.6)
	check("chapter_done", C.step() == "done" and C.objective() == "")
	check("ending_card", main.hud.ending.visible and get_tree().paused and main.hud.ending.stats_box.get_child_count() >= 4)
	main.hud.ending.close()
	await frames(2)
	check("ending_closes", not main.hud.ending.visible and not get_tree().paused)
	check("objective_moves_on", Game.objective() != "" and Game.objective() != C.line("o_slain"))

	# ---- the quest log and saving
	var log: Array = C.log_lines()
	check("quest_log", log.size() == 4 and log.all(func(l): return bool(l[3])), log)
	Game.save_game()
	var keep: Dictionary = C.st().duplicate(true)
	Game.state["c2"] = {}
	Game.load_game()
	check("chapter_saved", C.step() == "done" and C.st()["shards"] == keep["shards"] and C.hesk()["pages_st"] == "done")
	var WM = load("res://scripts/ui/world_map.gd")
	check("world_map_regions", WM.region_of("wyrmhollow") == "sanctum" and WM.region_of("frostvale") == "frostvale" and WM.region_of("shrine_light") == "sanctum")
	check("snow_underfoot", Sfx.GROUND.get("frostvale", "") == "snow")

	print("CHAPTER2TEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

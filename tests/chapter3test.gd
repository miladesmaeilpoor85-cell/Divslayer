extends Node
## v0.23 checks: chapter 3, "The Chains of Damavand". The new maps build (the Slopes of Damavand, the Cave of Chains) with
## their art, foes, villager and sounds; the story runs through the real talk paths: Kaveh's black forge-fire, the road
## east of the Ashen Peaks, the three jewels (Kondrow, the fire temple's altars, Qaren's ten serpent guards), the
## Derafsh-e Kaviani, the Gate of Damavand, Zahhak's fight (his moves, phases, chains and serpents), Sorush's binding,
## the Elder's epilogue and the ending card, the quest log, achievements, the new look, saving and New Game+.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/chapter3test.gd

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

func close_dialogue() -> int:
	var dlg = main.hud.dialogue
	var pages := 0
	while dlg.visible and pages < 80:
		if dlg.choosing():
			dlg._block_until = 0
			dlg._pick(dlg._choice_box.get_child_count() - 1)       # "Leave"
			await frames(1)
			break
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
	for k in ["shop", "forge"]:
		var c = main.hud.get(k)
		if c and c.visible:
			c.close()
	return p

func foes(type: String) -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.type == type and not e.dead:
			out.append(e)
	return out

func exit_try(to: String) -> String:
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
	C = Game.Ch3
	await get_tree().process_frame
	Game.lang = "fa"
	Game.new_game("warrior")
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	main.start_world()
	await frames(10)
	main.player.invuln = 99999.0

	# ---- data, art, sound
	var g := Game.world_graph()
	var pe := []
	for e in g["peaks"]["exits"]:
		pe.append(str(e["to"]))
	var de := []
	for e in g["damavand"]["exits"]:
		de.append(str(e["to"]))
	check("graph_links_new_maps", pe.has("damavand") and de.has("peaks") and de.has("zahhakcave") and g["damavand"]["npcs"].has("qaren")
		and g["damavand"]["bosses"].has("kondrow") and g["zahhakcave"]["bosses"].has("zahhak"), [pe, de])
	check("map_titles", Game.map_title("damavand") == "دامنهٔ دماوند" and Game.map_title("zahhakcave") == "غارِ زنجیرها", [Game.map_title("damavand"), Game.map_title("zahhakcave")])
	var Sheets = load("res://scripts/sheets.gd")
	var arts := []
	for t in ["serpentguard", "serpentarcher", "serpent", "kondrow", "zahhak"]:
		if Sheets.enemy(t).is_empty():
			arts.append(t)
	check("new_foes_have_art", arts.is_empty() and not Sheets.character("npcs", "qaren").is_empty(), arts)
	check("bosses_configured", Game.boss_cfg("kondrow").get("mini", false) and Game.boss_cfg("zahhak").get("rework", false)
		and Game.boss_name("zahhak") == "ضحاک" and Game.enemy_name("serpentguard") == "پاسدارِ ماردوش")
	var zs: Dictionary = Game.enemy_stats("zahhak", "zahhakcave")
	check("zahhak_strength", zs["hp"] > Game.enemy_stats("ancientwyrm", "wyrmhollow")["hp"], [zs, Game.enemy_stats("ancientwyrm", "wyrmhollow")])
	check("borrowed_tracks", Music.has_track("damavand") and Music.has_track("zahhakcave") and Music.has_track("boss_zahhak"))
	check("ground_and_air", Sfx.GROUND.get("damavand", "") == "stone" and Game.indoor("zahhakcave") and not Game.indoor("damavand"))

	# ---- before the chapter: Kaveh is only a smith, the road east is blocked
	check("not_open_before_chapter_two", not C.open() and C.objective() == "" and C.target().is_empty() and not C.has_news("smith"))
	main.goto_map("peaks", Vector2(1080, 626))
	await frames(5)
	main.player.invuln = 99999.0
	check("rubble_on_the_road", main.world.find_child("DamavandRubble", true, false) != null)
	check("road_blocked", exit_try("damavand") == "blocked")

	# ---- chapter 2 done: the forge-fire burns black
	for n in [1, 2, 3]:
		Game.set_q(n, "done")
	Game.brann_set("done")
	var dfd: Dictionary = Game.state.get("defeated", {})
	for b in ["boss", "boss2", "matriarch", "arbiter", "glaciertitan", "ancientwyrm"]:
		dfd[b] = true
	Game.state["defeated"] = dfd
	Game.Ch2.st()["step"] = "done"
	check("chapter_opens", C.open() and C.objective() == C.line("o_kaveh") and C.target()["map"] == "village" and C.has_news("smith"))
	main.goto_map("village", Vector2(600, 300))
	await frames(5)
	main.player.invuln = 99999.0
	var mk_ok := false
	var sm := npc("smith")
	if sm:
		var mk = sm.get_node_or_null("NewsMarker")
		mk_ok = mk != null and mk.visible
	check("kaveh_has_news_marker", mk_ok)
	main._on_interact(npc("elder"))
	await frames(2)
	var el_text: String = str(main.hud.dialogue.text_l.text) if main.hud.dialogue.visible else ""
	await close_dialogue()
	check("elder_points_to_kavian", C.step() == "" and el_text.find("کاویان") >= 0, el_text)
	var pages := await talk("smith")
	check("kaveh_tells_of_zahhak", C.step() == "jewels" and pages >= 5 and C.road_open(), [C.step(), pages])
	check("objective_jewels", Game.objective().begins_with(C.fmt("o_jewels", [0])) and C.target()["map"] == "damavand", Game.objective())

	# ---- the road east is open
	main.goto_map("peaks", Vector2(1080, 626))
	await frames(5)
	check("road_opens", exit_try("damavand") == "left")

	# ---- the Slopes of Damavand
	main.goto_map("damavand", Vector2(60, 626))
	await frames(8)
	main.player.invuln = 99999.0
	var w = main.world
	check("damavand_built", w.key == "damavand" and w.altars != null and w.altars.altars.size() == 3 and not w.altars.chest.is_empty()
		and w.get_node_or_null("DamavandGate") != null and npc("qaren") != null and foes("kondrow").size() == 1
		and foes("serpentguard").size() >= 4 and foes("serpentarcher").size() >= 2, [w.stats, foes("serpentguard").size(), foes("serpentarcher").size()])
	check("damavand_start_is_free", not w.wall_hit(Rect2(Vector2(60, 626) - Vector2(10, 20), Vector2(20, 20))))
	check("ash_on_damavand", w.atmos.weather in ["", "ash"] and Music.region == "damavand" and Music._amb_want["fire"], [w.atmos.weather, Music.region])
	check("gate_sealed", exit_try("zahhakcave") == "blocked")

	# ---- Qaren: ten serpent guards
	main.player.global_position = npc("qaren").global_position + Vector2(0, 26)
	await frames(3)
	pages = await talk("qaren")
	check("qaren_gives_his_task", bool(C.qaren()["met"]) and C.qaren()["st"] == "active" and pages >= 4, [C.qaren(), pages])
	var killed := 0
	for t in ["serpentguard", "serpentarcher"]:
		for e in foes(t):
			if killed < 6:
				e.hurt(99999.0, false, Vector2.ZERO)
				killed += 1
	await frames(5)
	check("guards_count", int(C.qaren()["kills"]) == killed, [C.qaren()["kills"], killed])
	for i in 10:
		C.on_kill("serpentguard")
	check("guards_done", C.qaren()["st"] == "ready" and int(C.qaren()["kills"]) == 10)
	check("qaren_has_news", C.has_news("qaren"))
	var gold0 := int(Game.state["gold"])
	main.player.global_position = npc("qaren").global_position + Vector2(0, 26)
	await talk("qaren")
	check("qaren_pays_a_jewel", C.qaren()["st"] == "done" and bool(C.st()["jewels"]["qaren"]) and C.jewels_have() == 1 and int(Game.state["gold"]) > gold0,
		[C.qaren(), C.jewels_have()])

	# ---- the fire temple: three altars burning together
	var al = w.altars
	var a0: Dictionary = al.altars[0]
	Game.state["weapon"] = 1
	for i in 2:
		al.strike(a0["rect"].grow(2), Vector2.RIGHT, false)
	check("altar_two_sparks_cold", float(a0["left"]) == 0.0 and float(a0["heat"]) == 2.0, [a0["heat"], a0["left"]])
	al.strike(a0["rect"].grow(2), Vector2.RIGHT, false)
	check("altar_lit_by_blows", float(a0["left"]) > 5.0 and al.lit_count() == 1, [a0["left"]])
	a0["left"] = 0.05
	await frames(6)
	check("altar_goes_out", float(a0["left"]) == 0.0 and al.lit_count() == 0 and not al.solved)
	al.strike(al.altars[1]["rect"].grow(2), Vector2.RIGHT, true)
	check("heavy_blow_two_sparks", float(al.altars[1]["heat"]) == 2.0)
	al.element(al.altars[0]["pos"], 40.0, "burn")
	check("fire_lights_at_once", float(al.altars[0]["left"]) > 12.0)
	check("chest_sealed_before", not al.solved and not al.is_open())
	main.player.global_position = al.chest["rect"].get_center() + Vector2(0, 8)
	await frames(4)
	check("sealed_chest_stays_shut", not al.is_open())
	main.player.global_position = Vector2(1145, 1000)
	await frames(2)
	check("shot_stops_at_altar", al.shot_at(al.altars[2]["rect"].get_center(), "burn") and float(al.altars[2]["left"]) > 12.0)
	al.strike(al.altars[1]["rect"].grow(2), Vector2.RIGHT, false)
	await frames(2)
	check("temple_solved", al.solved and bool(C.st()["altars_lit"]) and Game.Ach.has("altars"), al.lit_count())
	main.player.global_position = al.chest["rect"].get_center() + Vector2(0, 8)
	await frames(4)
	check("temple_chest_gives_jewel", al.is_open() and bool(C.st()["jewels"]["temple"]) and C.jewels_have() == 2)

	# ---- Kondrow, the steward
	var kd := foes("kondrow")
	check("kondrow_is_a_boss", not kd.is_empty() and kd[0].is_in_group("bosses") and kd[0].mini)
	if not kd.is_empty():
		kd[0].die()
	await frames(5)
	check("kondrow_jewel", bool(C.st()["jewels"]["kondrow"]) and C.jewels_have() == 3 and C.step() == "forge", [C.step(), C.jewels_have()])
	check("objective_forge", Game.objective() == C.line("o_forge") and C.target()["map"] == "village" and C.has_news("smith"))

	# ---- Kaveh raises the banner
	main.goto_map("village", Vector2(600, 300))
	await frames(5)
	main.player.invuln = 99999.0
	pages = await talk("smith")
	check("banner_raised", C.step() == "descend" and bool(C.st()["banner"]) and Game.Ach.has("kaviani") and pages >= 3, [C.step(), pages])
	check("banner_only_on_damavand", is_equal_approx(C.banner_mul(), 1.0))
	main.goto_map("damavand", Vector2(760, 130))
	await frames(5)
	main.player.invuln = 99999.0
	check("banner_strength_on_damavand", is_equal_approx(C.banner_mul(), C.BANNER_MUL) and main.player.caster.dmg_mul() >= C.BANNER_MUL - 0.001)
	check("gate_opens", exit_try("zahhakcave") == "left")
	check("objective_descend", Game.objective() == C.line("o_descend") and C.target()["map"] == "zahhakcave")

	# ---- the Cave of Chains and Zahhak
	main.goto_map("zahhakcave", Vector2(600, 60))
	await frames(8)
	main.player.invuln = 99999.0
	w = main.world
	check("cave_built", w.key == "zahhakcave" and w.get_node_or_null("Chains") != null and foes("zahhak").size() == 1 and Game.indoor("zahhakcave"), w.stats)
	check("cave_start_is_free", not w.wall_hit(Rect2(Vector2(600, 60) - Vector2(10, 20), Vector2(20, 20))))
	var zz := foes("zahhak")
	var zh = zz[0] if not zz.is_empty() else null
	if zh:
		main.player.global_position = zh.global_position + Vector2(-150, 0)
		await secs(0.3)
		check("zahhak_music", Music.boss and Music.track_key() == "boss_zahhak" and Music.has_track("boss_zahhak"), Music.track_key())
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 14000 and zh.moves.size() < 3:
			main.player.global_position = zh.global_position + Vector2(-110 - 100 * sin(Time.get_ticks_msec() / 700.0), 30)
			await frames(1)
		check("zahhak_phase_one_moves", zh.moves.size() >= 2 and (zh.moves.has("bite") or zh.moves.has("venom") or zh.moves.has("sword")), zh.moves)
		check("four_chains_hold", zh.zh_chains() == 4 and zh.zh_lair.x > 0.0)
		# the chains hold him near his lair
		zh.global_position = zh.zh_lair + Vector2(500, 0)
		await frames(3)
		check("leash", zh.global_position.distance_to(zh.zh_lair) <= zh.ZH_LEASH[1] + 2.0, zh.global_position.distance_to(zh.zh_lair))
		zh.hp = zh.max_hp * 0.6
		await frames(3)
		check("phase_two_breaks_a_chain", zh.ph == 2 and zh.zh_chains() == 3)
		t1 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 18000 and not (zh.moves.has("call") and (zh.moves.has("lash") or zh.moves.has("quake"))):
			main.player.global_position = zh.global_position + Vector2(-140, 40)
			await frames(1)
		check("zahhak_calls_serpents", zh.moves.has("call") and (foes("serpent").size() >= 1 or zh.minions.size() >= 1), [zh.moves, foes("serpent").size()])
		check("zahhak_phase_two_moves", zh.moves.has("lash") or zh.moves.has("quake"), zh.moves)
		zh.hp = zh.max_hp * 0.3
		await frames(3)
		check("final_phase", zh.ph == 3 and zh.zh_chains() == 2)
		zh.die()
	await frames(5)
	check("zahhak_bound", C.step() == "bound" and Game.is_defeated("zahhak") and Game.Ach.has("zahhak") and Game.objective() == C.line("o_bound"))
	await secs(6.2)
	var sorush: bool = main.hud.dialogue.visible and str(main.hud.dialogue.text_l.text) == C.line("s1")
	await close_dialogue()
	check("sorush_stays_the_blade", sorush)
	check("kaviani_look_earned", Game.Looks.unlocked("kaviani"))

	# ---- the cave after: Zahhak stands chained
	main.goto_map("zahhakcave", Vector2(600, 60))
	await frames(6)
	check("zahhak_stays_bound", foes("zahhak").is_empty() and main.world.zh_bound != null)

	# ---- the epilogue and the end of the chapter
	main.goto_map("village", Vector2(450, 470))
	await frames(5)
	main.player.invuln = 99999.0
	await talk("elder")
	await secs(0.6)
	check("chapter_done", C.step() == "done" and C.objective() == "")
	check("ending_card_three", main.hud.ending.visible and main.hud.ending.chapter == 3 and main.hud.ending.title_l.text == C.line("end_title"))
	main.hud.ending.close()
	await frames(2)
	check("ending_closes", not main.hud.ending.visible and not get_tree().paused)
	check("qaren_after", C.qaren_lines()[0] == C.line("q_bound"))

	# ---- the quest log, saving, the map, New Game+
	var log: Array = C.log_lines()
	check("quest_log", log.size() == 3 and log.all(func(l): return bool(l[3])), log)
	Game.save_game()
	var keep: Dictionary = C.st().duplicate(true)
	Game.state["c3"] = {}
	Game.load_game()
	check("chapter_saved", C.step() == "done" and C.st()["jewels"] == keep["jewels"] and bool(C.st()["banner"]))
	# (v0.23, found by the playtest) a reload must keep the weapon's attack and the armour's defence
	Game.state["weapon"] = 5
	Game.state["armor"] = 4
	var a_before := Game.atk()
	var d_before := Game.defense()
	Game.save_game()
	Game.load_game()
	check("reload_keeps_gear_bonuses", is_equal_approx(Game.atk(), a_before) and is_equal_approx(Game.defense(), d_before)
		and typeof(Game.state["weapon"]) == TYPE_INT and Game.forge_item_name("w") != Game.t("Fists"), [a_before, Game.atk(), d_before, Game.defense()])
	var WM = load("res://scripts/ui/world_map.gd")
	check("world_map_regions", WM.region_of("zahhakcave") == "damavand" and WM.LAYOUT.has("damavand"))
	check("ng_resets_chapter_three", Game.NG_RESET.has("c3"))
	check("l10n_complete", C.L.values().all(func(p): return str(p[1]) != "" and str(p[0]) != ""))

	print("CHAPTER3TEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

extends Node
## v0.27 checks on what the studio's engineering seat found: every sprite sheet the game loads is in the Android
## export (the Wyrm was left out and drawn invisible), the save survives a write cut in half, the Android Back button opens
## the pause menu instead of quitting, the death panel never opens under the pause menu, foe sheets are dropped on a map
## change, and the touch pad no longer redraws every frame when nothing on it changes.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/v27fixtest.gd

var main: Node
var results := {}
var fails: Array = []

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func check(n: String, ok: bool, info = null) -> void:
	results[n] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(n)
	printerr(("PASS " if ok else "FAIL ") + n + ("" if info == null else "  " + str(info)))

## the patterns of export_presets.cfg's exclude_filter for a preset
func excludes(preset: String) -> Array:
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	for sec in cfg.get_sections():
		if sec.ends_with(".options") or not cfg.has_section_key(sec, "name"):
			continue
		if str(cfg.get_value(sec, "name")) == preset:
			var out := []
			for p in str(cfg.get_value(sec, "exclude_filter", "")).split(","):
				if p.strip_edges() != "":
					out.append(p.strip_edges())
			return out
	return []

func run(m: Node) -> void:
	main = m
	await frames(5)
	Game.lang = "fa"

	# ---- every sheet the manifest names ships on Android
	var ex := excludes("Android")
	var left_out := []
	var groups := {"enemies": "Enemies", "heroes": "Heroes", "npcs": "Npcs"}
	for g in groups:
		for k in Game.manifest.get(g, {}):
			var path: String = "assets/art/%s/%s.png" % [groups[g], k]
			for pat in ex:
				if path.match(pat):
					left_out.append(path)
	check("android_preset_read", ex.size() >= 2, ex)
	check("no_sheet_left_out_of_android", left_out.is_empty(), left_out)
	check("wyrm_sheet_ships", not ("assets/art/Enemies/ancientwyrm.png" in left_out) and ResourceLoader.exists("res://assets/art/Enemies/ancientwyrm.png"))

	# ---- the save survives a cut write
	Game.new_game("rogue")
	Game.state["gold"] = 777
	Game.save_game()
	Game.state["gold"] = 778
	Game.save_game()
	check("bak_kept", FileAccess.file_exists(Game.SAVE_PATH + ".bak") and not FileAccess.file_exists(Game.SAVE_PATH + ".tmp"))
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{\"v\": 2, \"cls\": \"rog")     # Android killed the app mid-write (the old way)
	f = null
	Game.state = {}
	check("cut_save_falls_back", Game.load_game() and Game.cls == "rogue" and int(Game.state["gold"]) == 777, Game.state.get("gold"))
	check("menu_reads_the_fallback", main.menu == null or main.menu._save_info() != "")
	# a profile cut in half keeps the last good one too
	Game.Ach.p()["stats"]["probe"] = 5
	Game.Ach.save()
	Game.Ach.p()["stats"]["probe"] = 6
	Game.Ach.save()
	var pf := FileAccess.open(Game.Ach.path(), FileAccess.WRITE)
	pf.store_string("{\"ach\":")
	pf = null
	Game.Ach.load_profile()
	check("cut_profile_falls_back", int(Game.Ach.p()["stats"].get("probe", 0)) == 5, Game.Ach.p()["stats"].get("probe"))

	# ---- the world
	Game.new_game("warrior")
	Game.Tut.skip()
	if main.menu:
		main.menu.get_parent().queue_free()
		main.menu = null
	main.start_world()
	await frames(10)
	check("back_does_not_quit_setting", not ProjectSettings.get_setting("application/config/quit_on_go_back", true))
	main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(3)
	check("back_opens_pause", get_tree().paused and main.hud.pause.visible)
	main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(3)
	check("back_again_closes_it", not get_tree().paused and not main.hud.pause.visible)

	# ---- Save & quit keeps the spot the hero stands on (QA)
	main.player.global_position = Vector2(656, 649)
	main._quit_to_title()
	await frames(6)
	Game.state = {}
	Game.load_game()
	check("save_and_quit_keeps_the_spot", Vector2(float(Game.state.get("x", 0)), float(Game.state.get("y", 0))).distance_to(Vector2(656, 649)) < 1.0, [Game.state.get("x"), Game.state.get("y")])
	if main.menu:
		main.menu.get_parent().queue_free()
		main.menu = null
	main.start_world()
	await frames(10)

	# ---- the pad redraws only when something can change
	var p = main.player
	p.global_position = Vector2(470, 300)
	p.dodge_cd = 0.0
	p.shove_cd = 0.0
	for id in Game.slots():
		p.caster.cds[id] = 0.0
	Game.state["ult"] = 0.0
	main.hud.clear_msgs()
	await frames(30)
	var n := [0]
	var cb := func(): n[0] += 1
	main.hud.pad.draw.connect(cb)
	await frames(60)
	var idle: int = n[0]
	n[0] = 0
	p.shove_cd = 5.0
	await frames(60)
	var ticking: int = n[0]
	main.hud.pad.draw.disconnect(cb)
	check("pad_rests_when_idle", idle >= 4 and idle <= 12, idle)
	check("pad_follows_a_cooldown", ticking >= 25, ticking)

	# ---- the death panel never opens under the pause menu
	p.shove_cd = 0.0
	p.invuln = 0.0
	Game.hp = 1.0
	p.take_hit(999.0)
	await frames(2)
	main.hud.open_pause()
	await frames(2)
	check("no_pause_while_dying", not main.hud.pause.visible)
	await frames(80)
	check("death_panel_opens", main.hud.death.visible)

	# ---- exits (QA): a map change goes where it was asked; an exit entered too early still works once armed
	main.hud.death._on_respawn()
	await frames(10)
	Game.set_q(1, "active")
	main.goto_map("forest", Vector2(500, 500))
	await frames(4)
	var crypt: Node = null
	for a in get_tree().get_nodes_in_group("exits"):
		if a.get_parent() == main.world and str(a.get_meta("to")) == "dungeon":
			crypt = a
	check("forest_has_crypt_exit", crypt != null)
	if crypt:
		var r: Rect2 = crypt.get_meta("rect")
		main.player.global_position = r.get_center() + Vector2(0, r.size.y * 0.5 + 30.0)
		await frames(4)
		main.player.global_position = r.get_center()          # in the exit before it is armed
		await frames(6)
		check("early_exit_does_not_fire", main.world.key == "forest" and not main.switching)
		main.goto_map("shadowfen", r.get_center())            # a map change with the hero standing in the old exit
		await frames(30)
		check("map_change_lands_where_asked", main.world.key == "shadowfen", main.world.key)
		main.goto_map("forest", r.get_center() + Vector2(0, r.size.y * 0.5 + 60.0))
		for i in 20:                              # a first-visit card or word on the way: read it through
			if not get_tree().paused:
				break
			main.hud.dialogue.skip_typing()
			main.hud.dialogue.advance()
			await frames(2)
		main.goto_map("forest", r.get_center() + Vector2(0, r.size.y * 0.5 + 60.0))
		await frames(12)
		main.player.joy = Vector2(0, -1)          # he walks straight in, before the exits are armed
		await frames(18)
		check("walked_in_before_armed", main.world.key == "forest" and not main.world.exits_armed and main.player.global_position.y < r.end.y + 30.0, [main.player.global_position, get_tree().paused, main.player.dead, main.player.joy, Game.hp, main.hud.death.visible, main.hud.pause.visible])
		main.player.joy = Vector2.ZERO
		await frames(70)
		check("armed_exit_takes_the_hero", main.switching or main.world.key == "dungeon", [main.world.key, main.player.global_position])
		await frames(60)

	# ---- foe sheets are dropped on a map change
	var S = preload("res://scripts/sheets.gd")
	S.enemy("boss")
	check("sheet_cached", S._cache.has("enemies/boss"))
	main.goto_map("forest", Vector2(500, 500))
	await frames(6)
	check("sheets_forgotten_on_map_change", not S._cache.has("enemies/boss"))

	# ---- no common foe stands in a wall (level design)
	var stuck := []
	for mk in ["zahhakcave", "wyrmhollow", "frostvale", "damavand", "sanctum"]:
		main.goto_map(mk, Vector2(-1, -1))
		await frames(4)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.world != main.world or e.boss:
				continue
			for w in main.world.data.get("walls", []):
				if Rect2(float(w["x"]), float(w["y"]), float(w["w"]), float(w["h"])).has_point(e.global_position + Vector2(0, -3)):
					stuck.append([mk, e.type, e.global_position])
	check("no_foe_in_a_wall", stuck.is_empty(), stuck.slice(0, 5))

	print("V27FIXTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

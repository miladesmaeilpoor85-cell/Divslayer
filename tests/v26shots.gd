extends Node
## Screenshots of v0.26 (the callings' own moves):  -- --test res://tests/v26shots.gd --out <dir>
## the small pad in Zabol, the calling's drill in the yard, the four moves in the forest (with the wait on the button), the
## hero at the forest's east edge with the whole pad, Arzhang's card, the Skills page.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 854x400 -- --test res://tests/v26shots.gd --out DIR
var main: Node
var out := "/tmp/claude-0/v26shots"

func _arg(k: String, d: String) -> String:
	var i := Game.args.find(k)
	return Game.args[i + 1] if i >= 0 and i + 1 < Game.args.size() else d

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func real(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await frames(1)

func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(n + ".png"))
	printerr("SHOT ", n)

## one plain foe at `off` from the hero, the rest far away
func foe_at(off: Vector2) -> Node:
	var foe: Node = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e.boss:
			continue
		if foe == null:
			foe = e
			e.global_position = main.player.global_position + off
			e.calm = 99.0
		else:
			e.global_position = Vector2(-4000, -4000)
			e.calm = 999.0
	return foe

func hero(cls: String, map: String, at: Vector2) -> Node:
	Game.new_game(cls)
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	Game.state["day_t"] = 0.37
	Game.state["level"] = 4
	Game.state["pad_all"] = true
	Game.Tut.skip()
	Game.set_q(1, "active")
	main.goto_map(map, at)
	await frames(12)
	main.hud.clear_msgs()
	var p = main.player
	p.invuln = 99999.0
	p.stamina = 100.0
	p.shove_cd = 0.0
	return p

func run(m: Node) -> void:
	main = m
	out = _arg("--out", out)
	DirAccess.make_dir_recursive_absolute(out)
	Game.lang = _arg("--lang", "fa")
	await frames(20)
	# 00: the four callings, each with its own move
	main.show_menu()
	await frames(4)
	if main.menu:
		main.menu.view = "classes"
		main.menu._build()
		await real(700)
		await snap("00_callings")
		if _arg("--only", "") == "callings":
			get_tree().quit()
			return
	if main.menu:
		main.menu.get_parent().queue_free()
		main.menu = null
	if main.menu_bg:
		main.menu_bg.queue_free()
		main.menu_bg = null
	Game.new_game("warrior")
	Game.state["day_t"] = 0.37
	main.start_world()
	await frames(20)
	var p = main.player
	var T = Game.Tut
	var tr = main.world.training
	var post: Vector2 = tr.POST
	p.invuln = 99999.0
	main.hud.clear_msgs()
	# 01: the small pad in Zabol
	p.global_position = Vector2(470, 300)
	await real(700)
	await snap("01_small_pad")
	# 02: the calling's drill
	T.start()
	T.set_step("spell")
	p.global_position = post + Vector2(-70, 26)
	await frames(6)
	tr.on_cast("x")
	await real(900)
	await snap("02_drill_lasso")
	# 03: walked off: the tale leads, Rostam says the yard waits
	p.global_position = post + Vector2(-380, 150)
	await real(900)
	await snap("03_walked_off")
	T.skip()

	# 04: the lasso
	p = await hero("warrior", "forest", Vector2(520, 520))
	var foe := foe_at(Vector2(170, 0))
	p.facing = "right"
	await frames(4)
	p.signature()
	await real(260)
	await snap("04_lasso")
	await real(1600)
	await snap("05_lasso_wait")
	# 06: the feather turning a blow
	p = await hero("mage", "forest", Vector2(520, 520))
	foe = foe_at(Vector2(56, 6))
	await frames(4)
	p.signature()
	await real(500)
	p.invuln = 0.0
	p.take_hit(30.0)
	p.invuln = 99999.0
	await real(220)
	await snap("06_feather")
	# 07: the arrow
	p = await hero("rogue", "forest", Vector2(520, 520))
	foe = foe_at(Vector2(200, 0))
	p.facing = "right"
	await frames(4)
	p.signature()
	await real(130)
	await snap("07_arrow")
	# 08: the fire-walk
	p = await hero("paladin", "forest", Vector2(520, 520))
	foe = foe_at(Vector2(50, 10))
	await frames(4)
	p.signature()
	await real(1250)
	await snap("08_fire_walk")
	# 09: the forest's east edge, the whole pad
	p = await hero("rogue", "forest", Vector2(520, 520))
	foe_at(Vector2(-3000, -3000))
	var w: float = float(p.cam.map_size.x)
	p.global_position = Vector2(w - 30.0, 520)
	p.shove_cd = 2.4
	await real(1200)
	p.shove_cd = 2.4
	await frames(2)
	await snap("09_east_edge")
	# 11: Rostam on the White Div (the longest of his memories), Jamshid's shade
	p = await hero("warrior", "village", post + Vector2(-60, 30))
	main.hud.dialogue.open("رستم", [Game.Tut.line("h_ch2")], "hero:warrior_endgame:npc_rostam")
	await real(600)
	main.hud.dialogue.skip_typing()
	await real(300)
	await snap("11_rostam_ch2")
	main.hud.dialogue.skip_typing()
	main.hud.dialogue.advance()
	get_tree().paused = false
	await frames(3)
	main.hud.dialogue.open("روانِ جمشید", [Game.Story.line("d_done")], "brann")
	await real(2200)
	await snap("12_jamshid")
	main.hud.dialogue.skip_typing()
	main.hud.dialogue.advance()
	get_tree().paused = false
	await frames(3)
	# 13: Arzhang's echo and its card; 14: his fall
	p = await hero("warrior", "dungeon", Vector2(470, 700))
	Game.v18()["seen"].erase("boss")
	var arz: Node = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.boss and e.type == "boss":
			arz = e
		elif not e.dead:
			e.global_position = Vector2(-4000, -4000)
	if arz:
		p.global_position = arz.global_position + Vector2(-150, 60)
		await real(700)
		await snap("13_arzhang_card")
		main.hud.intro.finish()
		get_tree().paused = false
		await real(1500)
		await snap("14_arzhang_echo")
		arz.hurt(1e9, false, Vector2.ZERO)
		await real(900)
		await snap("15_dust_again")
	# 16: the White Div's card from afar
	p = await hero("warrior", "sanctum", Vector2(-1, -1))
	Game.v18()["seen"].erase("arbiter")
	var wd: Node = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.boss and e.type == "arbiter":
			wd = e
	if wd:
		p.global_position = wd.global_position + Vector2(40, -330)
		for i in 40:
			p.global_position += Vector2(0, 6)
			await frames(2)
			if get_tree().paused:
				break
		await real(900)
		await snap("16_white_div_card")
		main.hud.intro.finish()
		get_tree().paused = false
	# 17: the bottom-right corner of Zabol, the whole pad
	p = await hero("warrior", "village", post)
	p.global_position = Vector2(float(p.cam.map_size.x) - 40.0, float(p.cam.map_size.y) - 40.0)
	await real(1500)
	await snap("17_zabol_corner")
	p.global_position = Vector2(40.0, float(p.cam.map_size.y) - 40.0)
	await real(1500)
	await snap("18_zabol_corner_left")
	# 10: the Skills page
	main.hud.clear_msgs()
	main.hud.pause.open()
	main.hud.pause._show("skills")
	await real(600)
	await snap("10_skills_page")
	main.hud.pause.close()
	get_tree().quit()

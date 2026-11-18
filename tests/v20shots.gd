extends Node
## Screenshots of v0.20:  -- --test res://tests/v20shots.gd --out <dir> [--only a,b]
## the fountain (day, night), an achievement card, the Hero page (sheet, achievements, looks), the hero in a few looks.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 854x400 -- --test res://tests/v20shots.gd --out DIR
var main: Node
var out := "/tmp/claude-0/v20shots"
var only := []

func _arg(k: String, d: String) -> String:
	var i := Game.args.find(k)
	return Game.args[i + 1] if i >= 0 and i + 1 < Game.args.size() else d

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(n + ".png"))
	printerr("SHOT ", n)

func want(n: String) -> bool:
	return only.is_empty() or n in only

func run(m: Node) -> void:
	main = m
	out = _arg("--out", out)
	var o := _arg("--only", "")
	if o != "":
		only = Array(o.split(","))
	DirAccess.make_dir_recursive_absolute(out)
	if main.menu:
		main.menu.get_parent().queue_free()
		main.menu = null
	if main.menu_bg:
		main.menu_bg.queue_free()
		main.menu_bg = null
	Game.Ach.reset()
	var cls := _arg("--cls", "warrior")
	Game.new_game(cls)
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	Game.state["level"] = 12
	Game.state["day_t"] = 0.37
	main.start_world()
	await frames(10)
	main.player.invuln = 99999.0
	main.hud.clear_msgs()
	if want("fountain_day"):
		main.player.global_position = Vector2(452, 520)
		await frames(30)
		main.hud.title.modulate.a = 0.0
		main.player.cam.reset_smoothing()
		await frames(2)
		await snap("fountain_day")
	if want("fountain_night"):
		Game.state["day_t"] = 0.86
		main.world.lighting.forced_phase = 3
		main.player.global_position = Vector2(400, 380)
		main.player.facing = "right"
		await frames(30)
		main.player.cam.reset_smoothing()
		await frames(2)
		await snap("fountain_night")
		main.world.lighting.forced_phase = -1
		Game.state["day_t"] = 0.37
	if want("ach_card"):
		main.player.global_position = Vector2(600, 520)
		await frames(10)
		Game.Ach.unlock("boss_master")
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 700:
			await frames(1)
		await snap("ach_card")
		while main.hud.ach_card._busy:
			await frames(5)
	# some achievements for the pages
	for id in ["first_blood", "slayer", "boss_slayer", "rich", "apprentice", "frost_slayer", "legend", "parry_master", "titan"]:
		Game.Ach.quiet = true
		Game.Ach.unlock(id)
	Game.Ach.quiet = false
	Game.Ach.add("kills", 37)
	Game.Ach.add("crits", 12)
	if want("menu_sheet"):
		main.hud.pause.open()
		main.hud.pause.hsub = "sheet"
		main.hud.pause._show("hero")
		await frames(6)
		await snap("menu_sheet")
		main.hud.pause.close()
	if want("menu_ach"):
		Game.Ach.p()["new"] = ["boss_master", "titan"]
		main.hud.pause.open()
		main.hud.pause.hsub = "ach"
		main.hud.pause._show("hero")
		await frames(6)
		await snap("menu_ach")
		var sc: ScrollContainer = main.hud.pause.body.get_parent()
		sc.scroll_vertical = 900
		await frames(4)
		await snap("menu_ach2")
		main.hud.pause.close()
	if want("menu_looks"):
		Game.Looks.wear("crimson")
		main.player.refresh_look()
		main.hud.pause.open()
		main.hud.pause.hsub = "looks"
		main.hud.pause._show("hero")
		await frames(8)
		await snap("menu_looks")
		main.hud.pause.close()
		main.hud.pause.hsub = "sheet"
	# the hero in looks, in the forest
	var looks := ["crimson", "frost", "gold", "void", "sunfire"]
	Game.Ach.quiet = true
	for id in ["completionist", "wyrm_slayer", "ignarok"]:
		Game.Ach.unlock(id)
	Game.Ach.quiet = false
	for lk in looks:
		if not want("look_" + lk):
			continue
		Game.Looks.wear(lk)
		main.player.refresh_look()
		if main.world.key != "forest":
			main.goto_map("forest", Vector2(500, 420))
			await frames(10)
		main.player.invuln = 99999.0
		for e in get_tree().get_nodes_in_group("enemies"):
			e.spd = 0.0
		main.hud.clear_msgs()
		main.player.global_position = Vector2(500, 420)
		main.player.joy = Vector2(1, 0.3)
		await frames(30)
		main.hud.title.modulate.a = 0.0
		main.player.cam.reset_smoothing()
		await frames(2)
		await snap("look_" + lk)
		main.player.joy = Vector2.ZERO
	get_tree().quit()

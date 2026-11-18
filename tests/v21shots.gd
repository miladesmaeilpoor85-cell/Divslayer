extends Node
## Screenshots of v0.21:  -- --test res://tests/v21shots.gd --out <dir> [--only a,b]
## Sorush's offer, a memory of the Boss Rush (the tint, the timer line), the Wyrm's memory, the end of a run, New Game+
## (the warning, the banner, the HUD), the ending card's new line, the two new looks.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 854x400 -- --test res://tests/v21shots.gd --out DIR
var main: Node
var out := "/tmp/claude-0/v21shots"
var only := []

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

func until(cond: Callable, max_frames := 2400) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return false

func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(n + ".png"))
	printerr("SHOT ", n)

func want(n: String) -> bool:
	return only.is_empty() or n in only

func boss() -> Node:
	for b in get_tree().get_nodes_in_group("bosses"):
		if not b.dead:
			return b
	return null

func npc(id: String) -> Node:
	for n in get_tree().get_nodes_in_group("npcs"):
		if str(n.get_meta("id", "")) == id:
			return n
	return null

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
	Game.new_game("warrior")
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	Game.state["level"] = 17
	Game.state["weapon"] = 6
	Game.state["armor"] = 5
	Game.state["day_t"] = 0.37
	for n in [1, 2, 3]:
		Game.set_q(n, "done")
	Game.brann_set("done")
	var d := {}
	for t in ["boss", "boss2", "matriarch", "arbiter", "ignarok", "glaciertitan", "ancientwyrm"]:
		d[t] = true
	Game.state["defeated"] = d
	Game.Ch2.st()["step"] = "done"
	Game.hp = Game.max_hp()
	main.start_world()
	await frames(10)
	main.player.refresh_look()
	main.hud.clear_msgs()
	if want("ending"):
		main.hud.ending.open()
		await real(900)
		await snap("ending")
		main.hud.ending.close()
	main.goto_map("sanctum", Game.Rush.WAKE)
	await frames(20)
	main.hud.clear_msgs()
	main.hud.title.modulate.a = 0.0
	if want("keeper_menu"):
		main._on_interact(npc("keeper"))
		await frames(30)
		await snap("keeper_menu")
		main.hud.dialogue.visible = false
		get_tree().paused = false
	if want("rush_fight") or want("rush_wyrm") or want("rush_end"):
		main.start_rush()
		await until(func(): return main.world.key == "dungeon" and boss() != null and not main.rush_run.busy)
		main.player.invuln = 99999.0
		await real(2600)
		await snap("rush_fight")
		# skip to the Wyrm's memory
		for i in 6:
			var b := boss()
			if b:
				b.hp = 0.0
				b.die()
			await until(func(): return boss() != null and not main.rush_run.busy and int(Game.rush.get("i", 0)) == i + 1, 3000)
			main.player.invuln = 99999.0
		await real(3200)
		await snap("rush_wyrm")
		var wb := boss()
		if wb:
			wb.hp = 0.0
			wb.die()
		await until(func(): return Game.rush.is_empty() and main.world.key == "sanctum", 3000)
		await real(500)
		await snap("rush_end")
	if want("ng_warn"):
		main.hud.clear_msgs()
		main._keeper_who = Game.t("Sorush", "سروش")
		main._ng_confirm()
		await frames(30)
		await snap("ng_warn")
		main.hud.dialogue.visible = false
		get_tree().paused = false
	if want("ng_start"):
		main.start_ng()
		await until(func(): return Game.ng() == 1 and main.world.key == "village", 600)
		await real(900)
		await snap("ng_start")
	if want("looks_new"):
		main.hud.pause.open()
		main.hud.pause.hsub = "looks"
		main.hud.pause._show("hero")
		await frames(8)
		var sc: ScrollContainer = main.hud.pause.body.get_parent()
		sc.scroll_vertical = 400
		await frames(4)
		await snap("looks_new")
		main.hud.pause.close()
	if want("look_pahlavan") or want("look_ashen"):
		Game.Ach.quiet = true
		Game.Ach.unlock("ng_wyrm")
		Game.Ach.quiet = false
		for lk in ["pahlavan", "ashen"]:
			Game.Looks.wear(lk)
			main.player.refresh_look()
			main.goto_map("forest", Vector2(500, 420))
			await frames(10)
			for e in get_tree().get_nodes_in_group("enemies"):
				e.spd = 0.0
			main.hud.clear_msgs()
			main.player.invuln = 0.0
			main.player.joy = Vector2(1, 0.3)
			await frames(30)
			main.hud.title.modulate.a = 0.0
			main.player.cam.reset_smoothing()
			await frames(2)
			await snap("look_" + lk)
			main.player.joy = Vector2.ZERO
	get_tree().quit()

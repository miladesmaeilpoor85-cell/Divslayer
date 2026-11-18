extends Node
## Screenshots of chapter 2 (v0.19):  -- --test res://tests/ch2shots.gd --out <dir> [--only a,b]
## the Vale (the camp, the lake, Akvan's clearing, the watch-post), Hom, the Hollow (the hall, a chamber, the lair),
## the two bosses in action, the sanctum's door and vault, the ending card.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 854x400 -- --test res://tests/ch2shots.gd --out DIR
var main: Node
var out := "/tmp/claude-0/ch2shots"
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

## a moment at feet in map; freeze: foes stand still; hud: keep the HUD
func scene(n: String, map: String, feet: Vector2, freeze := true, hud := true, wait := 30) -> void:
	if main.world == null or main.world.key != map:
		main.goto_map(map, feet)
	else:
		main.player.global_position = feet
	main.player.invuln = 99999.0
	main.hud.fade.modulate.a = 0.0
	if freeze:
		for e in get_tree().get_nodes_in_group("enemies"):
			e.spd = 0.0
	main.hud.clear_msgs()
	main.hud.visible = hud
	await frames(wait)
	main.hud.title.modulate.a = 0.0
	main.player.cam.reset_smoothing()
	await frames(2)
	await snap(n)
	main.hud.visible = true

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
	Game.new_game("warrior")
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	Game.state["level"] = 14
	Game.state["weapon"] = 6
	Game.state["armor"] = 5
	Game.state["day_t"] = 0.37
	for n in [1, 2, 3]:
		Game.set_q(n, "done")
	Game.brann_set("done")
	Game.Ch2.st()["step"] = "shards"
	main.start_world()
	await frames(10)
	main.player.refresh_look()
	if want("vale_camp"):
		await scene("vale_camp", "frostvale", Vector2(330, 900))
	if want("vale_lake"):
		await scene("vale_lake", "frostvale", Vector2(560, 470))
	if want("vale_post"):
		await scene("vale_post", "frostvale", Vector2(1000, 330))
	if want("vale_grotto"):
		await scene("vale_grotto", "frostvale", Vector2(1120, 990))
	if want("vale_titan"):
		await scene("vale_titan", "frostvale", Vector2(990, 560))
	if want("titan_fight"):
		await scene("titan_fight", "frostvale", Vector2(1060, 580), false, true, 4)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2600:
			await frames(1)
		await snap("titan_fight")
		var ti = null
		for e in get_tree().get_nodes_in_group("bosses"):
			ti = e
		if ti:
			ti.hp = ti.max_hp * 0.45
		t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 4200:
			await frames(1)
		await snap("titan_fight2")
	if want("sanctum_door"):
		Game.Ch2.st()["step"] = "shards"
		await scene("sanctum_door", "sanctum", Vector2(660, 110), true, false)
	if want("sanctum_vault"):
		await scene("sanctum_vault", "sanctum", Vector2(1060, 150), true, false)
	if want("sanctum_east"):
		Game.Ch2.st()["step"] = "keeper"
		Game.stats_changed.emit()
		await scene("sanctum_east", "sanctum", Vector2(1120, 540), true, false)
		Game.Ch2.st()["step"] = "shards"
	Game.Ch2.st()["step"] = "descend"
	if want("hollow_hall"):
		await scene("hollow_hall", "wyrmhollow", Vector2(650, 120))
	if want("hollow_west"):
		await scene("hollow_west", "wyrmhollow", Vector2(300, 480))
	if want("hollow_east"):
		await scene("hollow_east", "wyrmhollow", Vector2(1010, 500))
	if want("hollow_lair"):
		await scene("hollow_lair", "wyrmhollow", Vector2(650, 760))
	if want("wyrm_fight"):
		await scene("wyrm_fight", "wyrmhollow", Vector2(520, 880), false, true, 4)
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 2400:
			await frames(1)
		await snap("wyrm_fight")
		var wy = null
		for e in get_tree().get_nodes_in_group("bosses"):
			wy = e
		if wy:
			wy.hp = wy.max_hp * 0.6
		t1 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 3500:
			await frames(1)
		await snap("wyrm_fight2")
		t1 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 3500:
			await frames(1)
		await snap("wyrm_fight3")
	if want("hesk_talk"):
		await scene("hesk_talk", "frostvale", Vector2(330, 880))
		Game.Ch2.hesk()["met"] = false
		for n in get_tree().get_nodes_in_group("npcs"):
			if str(n.get_meta("id", "")) == "hesk":
				main._on_interact(n)
		await frames(40)
		await snap("hesk_talk")
		main.hud.dialogue.visible = false
		get_tree().paused = false
	if want("ending"):
		main.hud.ending.open()
		var t2 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t2 < 900:
			await frames(1)
		await snap("ending")
		main.hud.ending.close()
	get_tree().quit()

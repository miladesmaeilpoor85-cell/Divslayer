extends Node
## The world's look, region by region, day and night, with weather:
##   -- --test res://tests/fxshots.gd --out <dir> [--only name,name]
var main: Node
var out := "/tmp/claude-0/fx"
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

## go to a map at a time of day (0 dawn .. 3 night) with a weather, freeze the enemies, take a picture
func scene(n: String, map: String, feet: Vector2, phase: int, weather := "", wait := 60) -> void:
	if not only.is_empty() and not n in only:
		return
	Game.state["day_t"] = phase * 0.25 + 0.12
	main.goto_map(map, feet)
	main.hud.fade.modulate.a = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		e.spd = 0.0
	if main.world.atmos:
		main.world.atmos.forced = weather
		main.world.atmos.set_weather(weather)
		main.world.atmos.fog_k = 1.0 if weather == "fog" else 0.0
	main.hud.clear_msgs()
	main.hud.title.modulate.a = 0.0
	await frames(wait)
	main.hud.title.modulate.a = 0.0
	await snap(n)

func run(m: Node) -> void:
	main = m
	out = _arg("--out", out)
	var o := _arg("--only", "")
	if o != "":
		only = Array(o.split(","))
	DirAccess.make_dir_recursive_absolute(out)
	if only.is_empty() or "title" in only:
		main.show_menu()
		await frames(60)
		await snap("title")
	if main.menu:
		main.menu.get_parent().queue_free()
		main.menu = null
	if main.menu_bg:
		main.menu_bg.queue_free()
		main.menu_bg = null
	Game.new_game("warrior")
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	Game.state["level"] = 5
	Game.state["weapon"] = 3
	main.start_world()
	await frames(30)
	await scene("village_day", "village", Vector2(450, 470), 1)
	await scene("village_night_rain", "village", Vector2(450, 470), 3, "rain")
	await scene("forest_dusk_fog", "forest", Vector2(560, 470), 2, "fog")
	await scene("forest_night", "forest", Vector2(560, 470), 3)
	await scene("dungeon", "dungeon", Vector2(430, 420), 1)
	await scene("peaks_ash", "peaks", Vector2(560, 500), 1, "ash")
	await scene("sanctum_snow", "sanctum", Vector2(600, 520), 3, "snow")
	await scene("emberforge", "emberforge", Vector2(620, 520), 1)
	await scene("trial", "trial", Vector2(550, 420), 1)
	await scene("shadowfen_night", "shadowfen", Vector2(600, 500), 3)
	await scene("camp_night", "camp", Vector2(600, 450), 3)
	# combat: a swing landing with sparks
	if only.is_empty() or "combat" in only:
		Game.state["day_t"] = 0.37
		main.goto_map("forest", Vector2(560, 470))
		main.hud.fade.modulate.a = 0.0
		await frames(20)
		var e = null
		for x in get_tree().get_nodes_in_group("enemies"):
			if e == null or x.global_position.distance_to(main.player.global_position) < e.global_position.distance_to(main.player.global_position):
				e = x
		if e:
			e.spd = 0.0
			e.max_hp = 9999.0
			e.hp = 9999.0
			main.player.global_position = e.global_position + Vector2(-34, 4)
			await frames(10)
			main.player.facing = "right"
			main.player.attack()
			await frames(5)
			await snap("combat_swing")
			main.player.attack(true)
			await frames(3)
			await snap("combat_heavy")
			e.hp = 1.0
			main.player.attack()
			await frames(12)
			await snap("combat_kill")
	print("FXSHOTS_DONE")
	get_tree().quit()

extends Node
## Screenshots of the puzzle shrines (v0.18):  -- --test res://tests/shrineshots.gd --out <dir> [--only shrine_embers,...]
var main: Node
var out := "/tmp/claude-0/shrines"
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

func scene(n: String, map: String, feet: Vector2, overview := false) -> void:
	if not only.is_empty() and not n in only:
		return
	main.goto_map(map, feet)
	main.hud.fade.modulate.a = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		e.spd = 0.0
	main.hud.clear_msgs()
	await frames(30)
	main.hud.title.modulate.a = 0.0
	var cam: Camera2D = main.player.cam
	if overview:
		# the whole room, without the HUD
		main.hud.visible = false
		cam.set_physics_process(false)
		cam.zoom = Vector2(0.769, 0.769)
		main.player.global_position = Vector2(340, 300)
		cam.reset_smoothing()
		await frames(8)
	await snap(n)
	main.hud.visible = true
	cam.set_physics_process(true)

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
	Game.state["level"] = 8
	Game.state["day_t"] = 0.37
	main.start_world()
	await frames(20)
	main.player.invuln = 99999.0
	if Game.args.has("--states"):
		await states()
		get_tree().quit()
		return
	var solved := Game.args.has("--solved")
	if solved:
		for s in Game.table("V16_SHRINE_LIST"):
			Game.shrine(str(s["key"]))["door"] = true
	for s in Game.table("V16_SHRINE_LIST"):
		var k := str(s["key"])
		var d: Dictionary = Game.map_data(k).get("data", {})
		var ps: Dictionary = d.get("playerStart", {"x": 330, "y": 440})
		await scene(k + "_all", k, Vector2(float(ps["x"]), float(ps["y"])), true)
		await scene(k, k, Vector2(float(ps["x"]) + 13.0, float(ps["y"]) + 34.0))
		if solved:
			continue
		await scene(k + "_parent", str(s["parent"]), Vector2(float(s["at"][0]), float(s["at"][1]) + 50.0))
	get_tree().quit()

# ---------------------------------------------------------------- moments in play (--states)
func shot_at(n: String, at: Vector2, overview := false) -> void:
	var cam: Camera2D = main.player.cam
	main.hud.clear_msgs()
	main.hud.title.modulate.a = 0.0
	if overview:
		main.hud.visible = false
		cam.set_physics_process(false)
		cam.zoom = Vector2(0.769, 0.769)
	main.player.global_position = at
	cam.reset_smoothing()
	await frames(6)
	await snap(n)
	main.hud.visible = true
	cam.set_physics_process(true)

func go(k: String) -> Node:
	main.goto_map(k, Vector2(340, 477))
	main.hud.fade.modulate.a = 0.0
	await frames(20)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.spd = 0.0
	return main.world.shrine

func states() -> void:
	Game.new_game("warrior")
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	Game.state["level"] = 8
	main.start_world()
	await frames(20)
	main.player.invuln = 99999.0
	# embers: the burning blade, a bramble on fire, the oil running
	var sh = await go("shrine_embers")
	sh.fire_t = 9.0
	sh.light(sh.by_id["f0"])
	for o in sh.objs:
		if o["t"] == "bramble":
			sh.burn(o)
	sh.ignite_oil()
	await frames(14)
	await shot_at("st_embers", Vector2(150, 250))
	await shot_at("st_embers_oil", Vector2(470, 300))
	# weight: a block on its plate
	sh = await go("shrine_weight")
	var b0 = sh.by_id["b0"]
	sh.push(b0, Vector2i(1, 0))
	for i in 3:
		sh.push(b0, Vector2i(0, -1))
	await frames(20)
	await shot_at("st_weight", Vector2(300, 330))
	# fuse: the lit barrel by the cracked wall
	sh = await go("shrine_fuse")
	var bar = null
	for o in sh.objs:
		if o["t"] == "barrel":
			bar = o
	for i in 6:
		sh.push(bar, Vector2i(1, 0))
	for i in 4:
		sh.push(bar, Vector2i(0, -1))
	await frames(12)
	sh.fire_t = 5.0
	sh.ignite_barrel(bar)
	await frames(30)
	await shot_at("st_fuse_lit", Vector2(420, 330))
	await frames(150)
	await shot_at("st_fuse_after", Vector2(420, 330))
	# tides: an ice path and the storm
	sh = await go("shrine_tides")
	sh.frost_t = 8.0
	sh.freeze(Vector2i(3, 7))
	sh.freeze(Vector2i(3, 6))
	sh.zap()
	await frames(6)
	await shot_at("st_tides", Vector2(140, 360))
	# light: the solved path
	sh = await go("shrine_light")
	for id in ["m2", "m1", "m0"]:
		sh.turn(sh.by_id[id])
	for o in sh.objs:
		if o["t"] == "icewall":
			sh.melt(o)
	await frames(60)
	await shot_at("st_light", Vector2(340, 300), true)
	await shot_at("st_light_play", Vector2(380, 260))
	# echoes: two runes lit, a timed brazier burning
	sh = await go("shrine_echoes")
	var runes: Array = sh.objs.filter(func(o): return o["t"] == "rune")
	runes.sort_custom(func(a, b): return int(a["n"]) < int(b["n"]))
	sh.step_rune(runes[0])
	sh.step_rune(runes[1])
	sh.fire_t = 5.0
	sh.light(sh.by_id["t0"])
	await frames(90)
	await shot_at("st_echoes", Vector2(160, 300))
	# shadows: sneaking in the grass under the Watchers' light
	sh = await go("shrine_shadows")
	main.player.sneaking = true
	await frames(30)
	await shot_at("st_shadows", Vector2(80, 370))
	# the altar and the sigil
	Game.shrine("shrine_embers")["door"] = true
	sh = await go("shrine_embers")
	main.player.global_position = Vector2(340, 112)
	await frames(10)
	await shot_at("st_altar", Vector2(340, 112))
	for o in sh.objs:
		if o["t"] == "altar":
			main._on_interact(o["node"])
	await frames(20)
	await snap("st_sigil")

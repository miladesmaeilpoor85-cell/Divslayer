extends Node
## Screenshots of the v0.27 UX fixes: a Persian dialogue, the HUD and pad with the Large interface, the Map page with the
## Large interface, the Skills page, the calling cards.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x720 -- --test res://tests/v27shots.gd --out DIR
var main: Node
var out := "/tmp/v27shots"

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

func run(m: Node) -> void:
	main = m
	out = _arg("--out", out)
	DirAccess.make_dir_recursive_absolute(out)
	Game.lang = _arg("--lang", "fa")
	await frames(20)
	if main.menu:
		main.menu.get_parent().queue_free()
		main.menu = null
	if main.menu_bg:
		main.menu_bg.queue_free()
		main.menu_bg = null
	Game.new_game("mage")
	Game.state["day_t"] = 0.37
	Game.state["level"] = 6
	Game.state["pad_all"] = true
	Game.Tut.skip()
	Game.set_q(1, "active")
	main.start_world()
	await frames(20)
	var p = main.player
	p.invuln = 99999.0
	p.global_position = Vector2(470, 330)
	main.hud.clear_msgs()
	await real(600)
	main.hud.dialogue.open("زال", [Game.elder_lines()[0]], "")
	await real(400)
	main.hud.dialogue.skip_typing()
	await real(300)
	await snap("01_dialogue")
	main.hud.dialogue.advance()
	get_tree().paused = false
	await frames(4)
	for ui in [2, 0]:
		Game.set_setting("ui", ui)
		main.hud.apply_layout()
		await real(500)
		await snap("02_hud_ui%d" % ui)
	Game.set_setting("ui", 2)
	main.hud.apply_layout()
	await frames(3)
	main.hud.open_pause("map")
	await real(600)
	await snap("03_map_ui2")
	main.hud.pause._show("skills")
	await real(500)
	await snap("04_skills_ui2")
	main.hud.pause.close()
	Game.set_setting("ui", 1)
	get_tree().quit()

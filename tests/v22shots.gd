extends Node
## Screenshots of v0.22 (the names of the Shahnameh):  -- --test res://tests/v22shots.gd --out <dir>
## the four heroes on the title screen, the village and its people, a talk with Zal, a boss's name card, the Hero page.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 854x400 -- --test res://tests/v22shots.gd --out DIR
var main: Node
var out := "/tmp/claude-0/v22shots"

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

func npc(id: String) -> Node:
	for n in get_tree().get_nodes_in_group("npcs"):
		if str(n.get_meta("id", "")) == id:
			return n
	return null

func run(m: Node) -> void:
	main = m
	out = _arg("--out", out)
	DirAccess.make_dir_recursive_absolute(out)
	Game.lang = _arg("--lang", "fa")
	await frames(20)
	main.show_menu()
	await frames(10)
	if main.menu:
		main.menu.view = "classes"
		main.menu._build()
		await real(800)
		await snap("classes")
		main.menu.get_parent().queue_free()
		main.menu = null
	if main.menu_bg:
		main.menu_bg.queue_free()
		main.menu_bg = null
	Game.new_game("mage")
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	Game.state["day_t"] = 0.37
	main.start_world()
	await frames(20)
	main.player.invuln = 99999.0
	main.hud.clear_msgs()
	main.player.global_position = Vector2(440, 380)
	await real(600)
	main.hud.title.modulate.a = 0.0
	await snap("village")
	main._on_interact(npc("elder"))
	await real(1500)
	await snap("elder_talk")
	main.hud.dialogue.visible = false
	get_tree().paused = false
	Game.v18()["seen"].erase("boss")
	main.goto_map("dungeon", Vector2(663, 764))
	await frames(10)
	for b in get_tree().get_nodes_in_group("bosses"):
		main.hud.intro.play(b.type)
	await real(1200)
	await snap("boss_card")
	await real(2500)
	main.hud.pause.open()
	main.hud.pause._show("hero")
	await frames(6)
	await snap("hero_page")
	main.hud.pause.close()
	get_tree().quit()

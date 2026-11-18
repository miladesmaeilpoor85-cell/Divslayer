extends Node
## Every UI screen, for design reviews:  -- --test res://tests/uishots.gd --out <dir> [--tag <name>] [--lang en]
var main: Node
var out := "/tmp/claude-0/ui/godot"
var tag := ""

func _arg(k: String, d: String) -> String:
	var i := Game.args.find(k)
	return Game.args[i + 1] if i >= 0 and i + 1 < Game.args.size() else d

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(tag + n + ".png"))
	printerr("SHOT ", tag + n)

func run(m: Node) -> void:
	main = m
	out = _arg("--out", out)
	tag = _arg("--tag", "")
	DirAccess.make_dir_recursive_absolute(out)
	if Game.has_arg("--lang"):
		Game.lang = _arg("--lang", "fa")
	# title screen
	main.show_menu()
	await frames(30)
	await snap("01_title")
	main.menu._go("classes")
	await frames(20)
	await snap("01b_classes")
	main.menu._go("settings")
	await frames(10)
	await snap("01c_settings")
	main.menu.get_parent().queue_free()
	main.menu = null
	main.menu_bg.queue_free()
	main.menu_bg = null
	Game.new_game("warrior")
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	Game.state["gold"] = 640
	Game.state["level"] = 5
	Game.hp = Game.max_hp() * 0.72
	main.start_world()
	await frames(80)
	await snap("02_hud_village")
	var elder = null
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.get_meta("id") == "elder":
			elder = n
	main.player.global_position = elder.global_position + Vector2(30, 6)
	await frames(10)
	await snap("03_near_npc")
	main._on_interact(elder)
	await frames(30)
	await snap("04_dialogue")
	while main.hud.dialogue.visible:
		main.hud.dialogue._block_until = 0
		main.hud.dialogue.advance()
		await frames(2)
	main.hud.shop.open("smith")
	await frames(20)
	await snap("05_shop")
	main.hud.shop.close()
	main.goto_map("forest", Vector2(560, 470))
	await frames(10)
	main.player.apply_status("poison", 9.0, 1.0)
	main.player.apply_status("burn", 6.0, 1.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.spd = 0.0
	main.hud.toast(Game.t("Level up!", "سطح بالاتر!"))
	await frames(30)
	await snap("06_forest_status_toast")
	main.hud.open_pause()
	await frames(20)
	await snap("06b_pause_hero")
	main.hud.pause._show("settings")
	await frames(10)
	await snap("06c_pause_settings")
	main.hud.pause._show("map")
	await frames(10)
	await snap("06d_pause_map")
	main.hud.pause.close()
	main.goto_map("dungeon", Vector2(850 - 200 + 13, 650 + 80 + 34))
	await frames(40)
	await snap("07_boss")
	Game.hp = 1.0
	main.player.invuln = 0.0
	main.player.take_hit(9999.0)
	await get_tree().create_timer(1.5, true, false, true).timeout
	await snap("08_death")
	print("UISHOTS_DONE")
	get_tree().quit()

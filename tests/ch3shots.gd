extends Node
## Screenshots of chapter 3 (v0.23):  -- --test res://tests/ch3shots.gd --out <dir>
## the road east (rubble), the Slopes of Damavand, Qaren's camp, the fire temple (cold, then burning), Kondrow, the Gate,
## Kaveh and the banner, the Cave of Chains, Zahhak (intro card, a bite, phase III), Zahhak bound, the ending card.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 854x400 -- --test res://tests/ch3shots.gd --out DIR
var main: Node
var out := "/tmp/claude-0/ch3shots"

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

func foes(type: String) -> Array:
	var o := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.type == type and not e.dead:
			o.append(e)
	return o

func go(map: String, feet: Vector2) -> void:
	main.goto_map(map, feet)
	await frames(8)
	main.player.invuln = 99999.0
	main.hud.clear_msgs()
	main.hud.title.modulate.a = 0.0

func run(m: Node) -> void:
	main = m
	out = _arg("--out", out)
	DirAccess.make_dir_recursive_absolute(out)
	Game.lang = _arg("--lang", "fa")
	await frames(10)
	Game.new_game("paladin")
	Game.state["level"] = 18
	Game.state["weapon"] = 6
	Game.state["armor"] = 5
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	for n in [1, 2, 3]:
		Game.set_q(n, "done")
	Game.brann_set("done")
	var dfd := {}
	for b in ["boss", "boss2", "matriarch", "arbiter", "glaciertitan", "ancientwyrm"]:
		dfd[b] = true
	Game.state["defeated"] = dfd
	Game.Ch2.st()["step"] = "done"
	Game.state["day_t"] = 0.4
	main.start_world()
	await frames(20)
	main.player.invuln = 99999.0
	var C = Game.Ch3
	# the road east, still blocked
	await go("peaks", Vector2(1040, 640))
	await real(500)
	await snap("01_peaks_rubble")
	# Kaveh's tale
	await go("village", Vector2(600, 290))
	main._on_interact(npc("smith"))
	await real(1400)
	await snap("02_kaveh_tale")
	while main.hud.dialogue.visible:
		main.hud.dialogue._block_until = 0
		main.hud.dialogue.advance()
		await frames(1)
	await real(300)
	# the Slopes of Damavand
	await go("damavand", Vector2(80, 626))
	await real(700)
	await snap("03_damavand_arrival")
	await go("damavand", npc("qaren").global_position + Vector2(40, 40) if npc("qaren") else Vector2(400, 860))
	await real(500)
	await snap("04_qaren_camp")
	main._on_interact(npc("qaren"))
	await real(1300)
	await snap("05_qaren_talk")
	while main.hud.dialogue.visible:
		main.hud.dialogue._block_until = 0
		main.hud.dialogue.advance()
		await frames(1)
	# the fire temple, cold, then one altar burning, then all three
	await go("damavand", Vector2(1145, 990))
	await real(500)
	await snap("06_temple_cold")
	var al = main.world.altars
	al.light(al.altars[0], 6.0)
	await real(500)
	await snap("07_temple_one_fire")
	al.light(al.altars[1], 14.0)
	al.light(al.altars[2], 14.0)
	await real(900)
	await snap("08_temple_solved")
	# Kondrow on his terrace
	var kd := foes("kondrow")
	if not kd.is_empty():
		await go("damavand", kd[0].global_position + Vector2(-150, 40))
		main.player.invuln = 99999.0
		await real(1600)
		await snap("09_kondrow")
	# the Gate, sealed
	await go("damavand", Vector2(760, 150))
	await real(500)
	await snap("10_gate_sealed")
	# the banner
	for k in C.JEWELS:
		C.st()["jewels"][k] = true
	C.st()["step"] = "forge"
	await go("village", Vector2(600, 290))
	main._on_interact(npc("smith"))
	while main.hud.dialogue.visible:
		main.hud.dialogue._block_until = 0
		main.hud.dialogue.advance()
		await frames(1)
	await real(700)
	await snap("11_banner_raised")
	await real(2500)
	await go("damavand", Vector2(760, 150))
	await real(500)
	await snap("12_gate_open")
	# the Cave of Chains and Zahhak
	Game.v18()["seen"].erase("zahhak")
	await go("zahhakcave", Vector2(600, 90))
	await real(500)
	await snap("13_cave_arrival")
	var zz := foes("zahhak")
	if not zz.is_empty():
		var zh = zz[0]
		main.hud.intro.play("zahhak")
		await real(1300)
		await snap("14_zahhak_card")
		await real(3000)
		main.player.global_position = zh.global_position + Vector2(-170, 30)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 9000 and not zh.zh_strike.size() > 0:
			await frames(1)
		await real(250)
		await snap("15_zahhak_bite")
		zh.hp = zh.max_hp * 0.3
		await real(2200)
		main.player.global_position = zh.global_position + Vector2(-160, 50)
		await real(1800)
		await snap("16_zahhak_final_phase")
		zh.die()
		await real(3300)
		await snap("17_bound_banner")
		await real(2600)
		await snap("18_sorush")
		while main.hud.dialogue.visible:
			main.hud.dialogue._block_until = 0
			main.hud.dialogue.advance()
			await frames(1)
	await go("zahhakcave", Vector2(600, 600))
	await real(600)
	await snap("19_zahhak_chained")
	# the epilogue and the card
	await go("village", Vector2(450, 470))
	main._on_interact(npc("elder"))
	while main.hud.dialogue.visible:
		main.hud.dialogue._block_until = 0
		main.hud.dialogue.advance()
		await frames(1)
	await real(1500)
	await snap("20_ending_card")
	main.hud.ending.close()
	main.hud.pause.open()
	main.hud.pause._show("hero")
	await frames(8)
	await snap("21_quest_log")
	main.hud.pause.close()
	get_tree().quit()

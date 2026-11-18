extends Node
## Screenshots of v0.24 (the Ember-bearer):  -- --test res://tests/v24shots.gd --out <dir>
## the callings on the title screen, Zabol's people (Rostam, Siavash, Gordafarid by the yard), Rostam's talk and choice, the post,
## a marked blow (roll), the shield drill, the gift, Zal's first words, Siavash and Gordafarid, the hero page.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 854x400 -- --test res://tests/v24shots.gd --out DIR
var main: Node
var out := "/tmp/claude-0/v24shots"

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

func close_dialogue() -> void:
	var dlg = main.hud.dialogue
	if dlg.choosing():
		dlg._block_until = 0
		dlg._pick(dlg._choice_box.get_child_count() - 1)
	else:
		dlg.visible = false
	get_tree().paused = false
	await frames(2)

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
		await snap("01_callings")
		main.menu.get_parent().queue_free()
		main.menu = null
	if main.menu_bg:
		main.menu_bg.queue_free()
		main.menu_bg = null
	Game.new_game("warrior")
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	Game.state["day_t"] = 0.37
	main.start_world()
	await frames(20)
	var p = main.player
	p.invuln = 99999.0
	main.hud.clear_msgs()
	p.global_position = Vector2(600, 470)
	await real(700)
	main.hud.title.modulate.a = 0.0
	await snap("02_zabol_yard")
	# Rostam
	var rs = npc("rostam")
	p.global_position = rs.global_position + Vector2(-30, 18)
	await frames(2)
	main._on_interact(rs)
	await real(1400)
	await snap("03_rostam_talk")
	var dlg = main.hud.dialogue
	var guard := 0
	while dlg.visible and not dlg.choosing() and guard < 20:
		dlg._block_until = 0
		dlg.advance()
		await real(200)
		guard += 1
	await real(600)
	await snap("04_rostam_choice")
	dlg._block_until = 0
	dlg._pick(0)
	await frames(4)
	var tr = main.world.training
	p.global_position = tr.POST + Vector2(-34, 6)
	p.facing = "right"
	await real(500)
	await snap("05_the_post")
	for i in 3:
		tr.strike(tr.rect.grow(2), Vector2.RIGHT, false)
	tr.strike(tr.rect.grow(2), Vector2.RIGHT, true)
	p.global_position = tr.POST + Vector2(-90, 24)
	# wait for Rostam's mark, snap it half-way
	guard = 0
	while main.world.bossfx.tele.is_empty() and guard < 400:
		await frames(1)
		guard += 1
	await real(600)
	await snap("06_marked_blow")
	await real(900)
	await snap("07_after_the_mark")
	# move to the shield drill
	Game.Tut.st()["rolls"] = Game.Tut.ROLLS
	Game.Tut.set_step("block")
	main.hud.refresh()
	guard = 0
	while main.world.bossfx.tele.is_empty() and guard < 400:
		await frames(1)
		guard += 1
	p.hold_block = true
	p.block_start()
	await real(700)
	await snap("08_shield_drill")
	guard = 0
	while Game.Tut.step() == "block" and guard < 300:
		await frames(1)
		guard += 1
	p.hold_block = false
	p.block_end()
	await real(1500)
	await snap("08b_spell_drill")
	Game.mp = Game.max_mp()
	p.caster.cast_slot(0)
	await real(1200)
	await snap("09_rostam_gift")
	await close_dialogue()
	main.hud.clear_msgs()
	# Zal
	p.global_position = npc("elder").global_position + Vector2(0, 26)
	main._on_interact(npc("elder"))
	await real(1500)
	await snap("10_zal")
	await close_dialogue()
	# Siavash, Gordafarid
	p.global_position = npc("siavash").global_position + Vector2(0, 26)
	main._on_interact(npc("siavash"))
	await real(1300)
	await snap("11_siavash")
	await close_dialogue()
	p.global_position = npc("gordafarid").global_position + Vector2(0, 26)
	main._on_interact(npc("gordafarid"))
	await real(1300)
	await snap("12_gordafarid")
	await close_dialogue()
	main.hud.clear_msgs()
	await real(400)
	await snap("13_hud")
	main.hud.pause.open()
	main.hud.pause._show("hero")
	await frames(6)
	await snap("14_hero_page")
	main.hud.pause.close()
	await frames(4)
	# Sindokht's first words (three pages now) and the death panel's Story offer
	main.goto_map("village", Vector2(320, 240))
	await frames(8)
	main.hud.clear_msgs()
	main._on_interact(npc("merchant"))
	await real(1300)
	await snap("14b_sindokht")
	await close_dialogue()
	main.hud.shop.close()
	get_tree().paused = false
	Game.fight = {"type": "boss", "map": "dungeon", "feet": Vector2(663, 764), "potions": 3, "retries": 1}
	main.hud.death.open(12, "boss")
	await real(400)
	await snap("14c_death_story")
	main.hud.death._close()
	Game.fight = {}
	# the apron: a hero by the walls is no longer pushed under the buttons
	for spot in [["15_apron_crypt", "dungeon", Vector2(900, 700)], ["16_apron_village", "village", Vector2(840, 600)],
			["17_apron_forest_nw", "forest", Vector2(60, 60)]]:
		main.goto_map(spot[1], spot[2])
		await frames(8)
		main.player.invuln = 99999.0
		main.hud.clear_msgs()
		main.hud.title.modulate.a = 0.0
		main.player.cam.reset_smoothing()
		await real(900)
		await snap(spot[0])
	get_tree().quit()

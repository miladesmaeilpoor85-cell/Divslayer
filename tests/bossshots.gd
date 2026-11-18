extends Node
## Screenshots of the v18 boss systems (needs a real renderer):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1708x800 -- --test res://tests/bossshots.gd --out <dir>

var main: Node
var out := "user://shots"
var bt: Node

func run(m: Node) -> void:
	main = m
	var i := Game.args.find("--out")
	if i >= 0 and i + 1 < Game.args.size():
		out = Game.args[i + 1]
	DirAccess.make_dir_recursive_absolute(out)
	await get_tree().process_frame
	Game.new_game("warrior")
	main.start_world()
	bt = load("res://tests/bosstest.gd").new()
	bt.main = main
	add_child(bt)
	await bt.frames(5)

	# the name card, part-way in
	Game.v18()["seen"].clear()
	await bt.arena("boss", false)
	await bt.real(1.3)
	await snap("intro_guardian")
	await bt.real(2.0)

	for t in ["boss", "boss2", "matriarch", "arbiter"]:
		await fight_shot(t)

	# Arzhang staggered (stars, glowing bar), then phase II with his pillars and their tethers
	var b: Node = await bt.arena("boss")
	await bt.frames(20)
	bt.hold(b)
	b.global_position = main.player.global_position + Vector2(60, -10)
	b.stagger()
	await bt.frames(20)
	await snap("stagger")
	b.staggered = 0.0
	b.busy = 0.0
	b.gcd = 0.0
	b.cd.clear()
	b.hp = b.max_hp * 0.6
	await bt.secs(2.6)
	b.busy = 0.0
	b.gcd = 0.0
	b.cd.clear()
	b.global_position = main.player.global_position + Vector2(160, -40)
	await bt.secs(1.2)
	bt.hold(b)
	await bt.frames(10)
	await snap("pillars")

	# the King of Mazandaran erupts: core exposed, shockwave rolling out
	b = await bt.arena("boss2")
	await bt.frames(10)
	bt.hold(b)
	b.global_position = main.player.global_position + Vector2(130, -30)
	b._fire_erupt({}, b.center(), 1)
	await bt.frames(14)
	await snap("colossus_erupt")

	# the Sorceress's eggs and poison pool; then her dive shadow
	b = await bt.arena("matriarch")
	await bt.frames(10)
	bt.hold(b)
	b.global_position = main.player.global_position + Vector2(150, -40)
	for spot in main.world.ring(b.center() + Vector2(0, 20), 3, 80.0, 170.0, Vector2(22, 20)):
		main.world.spawn_arena("bogegg", spot, {"hp": 40.0, "owner": b, "hatch": 99.0, "kids": []})
	main.world.bossfx.pool(main.player.pc() + Vector2(-70, 10), 100.0, 9.0)
	await bt.frames(30)
	await snap("matriarch_eggs")
	b.busy = 0.0
	b.gcd = 0.0
	b.cd.clear()
	b.cd["eggs"] = 99.0
	await bt.secs(0.8)
	await snap("matriarch_dive")

	# the White Div's echoes and an ice-lance line
	b = await bt.arena("arbiter")
	await bt.frames(10)
	bt.hold(b)
	b.ph = 2
	b.set_variant(1)
	b.global_position = main.player.global_position + Vector2(170, -30)
	for spot in main.world.ring(b.center(), 2, 110.0, 170.0, b.box):
		main.world.spawn_arena("arbiterclone", spot, {"hp": 1.0, "speed": 0.0, "owner": b, "dmg": 9.0, "born": main.world.bossfx.clock})
	b.busy = 0.0
	b.gcd = 0.0
	b.cd.clear()
	b.cd["echo"] = 99.0
	b.cd["leap"] = 99.0
	await bt.frames(30)
	await snap("arbiter_echoes")

	# death -> rematch panel, then the victory banner
	b = await bt.arena("boss")
	await bt.frames(10)
	main.player.invuln = 0.0
	main.player.take_hit(99999.0)
	await bt.real(1.6)
	await snap("death_rematch")
	await bt.click(main.hud.death.re_btn)
	await bt.frames(30)
	for e in get_tree().get_nodes_in_group("bosses"):
		b = e
	b.hurt(1e9, false, Vector2.ZERO)
	await bt.frames(25)
	await snap("victory")

	# English, for comparison
	Game.set_lang("en")
	Game.v18()["seen"].clear()
	await bt.arena("boss2", false)
	await bt.real(1.3)
	await snap("intro_colossus_en")
	await bt.real(2.0)
	Game.set_lang("fa")
	print("SHOTS_DONE")
	get_tree().quit()

## let the boss fight a hero who cannot die, and grab the frame while telegraphs are on the ground
func fight_shot(t: String) -> void:
	var b: Node = await bt.arena(t)
	var p: Node = main.player
	var best := 0
	var waited := 0
	while waited < 60 * 14:
		await bt.frames(1)
		waited += 1
		Game.hp = Game.max_hp()
		if p.dead:
			p.revive()
		var to: Vector2 = b.center() - p.pc()
		p.joy = to.normalized() if to.length() > 90.0 else Vector2.ZERO
		var n: int = main.world.bossfx.tele.size() + main.world.bossfx.waves.size() + main.world.bossfx.lobs.size() + main.world.bossfx.shots.size()
		if waited > 120 and n >= 2 and n > best and _half_done(main.world.bossfx):
			best = n
			p.joy = Vector2.ZERO
			await snap("fight_" + t)
			if n >= 4:
				break
	p.joy = Vector2.ZERO

func _half_done(bfx: Node) -> bool:
	for tl in bfx.tele:
		var k: float = 1.0 - float(tl["t"]) / float(tl["total"])
		if k > 0.45 and k < 0.9:
			return true
	return not bfx.shots.is_empty() or not bfx.waves.is_empty()

func snap(shot: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(shot + ".png"))
	printerr("SHOT ", shot)

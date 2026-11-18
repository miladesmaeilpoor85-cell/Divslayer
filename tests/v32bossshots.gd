extends Node
## (v0.32) Screenshots of every boss in his painted sheet, calm and in his later phase (needs a real renderer):
##   xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 -- --test res://tests/v32bossshots.gd --out <dir>

var main: Node
var out := "user://shots"
var bt: Node
const WHERE := {"toadking": ["shadowfen", Vector2(380, 880)], "anvilward": ["emberforge", Vector2(620, 900)],
	"kondrow": ["damavand", Vector2(303, 214)], "captain": ["camp", Vector2(586, 392)], "ignarok": ["emberforge", Vector2(620, 150)]}

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
	var only := Game.args[Game.args.find("--only") + 1].split(",") if Game.args.has("--only") else PackedStringArray()
	for t in ["boss", "boss2", "matriarch", "toadking", "captain", "arbiter", "glaciertitan", "ancientwyrm", "anvilward", "kondrow", "zahhak", "ignarok"]:
		if not only.is_empty() and not t in only:
			continue
		var b: Node = null
		if WHERE.has(t):
			Game.new_game("warrior")
			Game.state["level"] = 16
			Game.hp = Game.max_hp()
			main.player.revive()
			main.goto_map(WHERE[t][0], WHERE[t][1] + Vector2(-120, 60))
			await bt.frames(3)
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.type == t:
					b = e
		else:
			b = await bt.arena(t)
		if b == null:
			printerr("NO BOSS ", t)
			continue
		await bt.frames(10)
		bt.hold(b)
		b.global_position = main.player.global_position + Vector2(110, -6)
		await bt.real(0.6)
		await snap(t + "_1")
		if b.has_method("_check_phase"):
			b.hp = b.max_hp * 0.3
			b._check_phase()
			bt.hold(b)
			b.global_position = main.player.global_position + Vector2(110, -6)
			await bt.real(1.2)
			await snap(t + "_2")
			if b.cfg.get("phases", []).size() >= 2:
				b.hp = b.max_hp * 0.08
				b._check_phase()
				bt.hold(b)
				b.global_position = main.player.global_position + Vector2(110, -6)
				await bt.real(1.2)
				await snap(t + "_3")
	get_tree().quit()

func snap(shot: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(shot + ".png"))
	printerr("SHOT ", shot)

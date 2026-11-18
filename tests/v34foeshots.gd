extends Node
## (v0.34) Screenshots of the Shahnameh foes in their own lands, a row of each beside the hero (needs a real renderer):
##   xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 -- --test res://tests/v34foeshots.gd --out <dir> [--only map,map]

var main: Node
var out := "user://shots"
const LANDS := {
	"dungeon": ["skeleton", "archer", "wraith", "bat", "imp", "slime"],
	"peaks": ["golem", "skeleton", "archer", "imp"],
	"emberforge": ["cinderhound", "slagbrute", "moltencore", "bellowdrone"],
	"shadowfen": ["lurker", "toad", "mosquito"],
	"frostvale": ["frostwolf", "rimewraith", "frostknight", "crystalSpider", "iceling"],
	"sanctum": ["icegolem", "frostknight", "iceling"],
	"camp": ["bandit", "banditArcher"],
	"forest": ["slime", "wraith", "bat", "bellowdrone", "mosquito"],
	"damavand": ["serpentguard", "serpentarcher", "serpent", "imp"],
	"wyrmhollow": ["wyrmling", "rimewraith", "skeleton"],
}

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func run(m: Node) -> void:
	main = m
	var i := Game.args.find("--out")
	if i >= 0 and i + 1 < Game.args.size():
		out = Game.args[i + 1]
	DirAccess.make_dir_recursive_absolute(out)
	var only := Game.args[Game.args.find("--only") + 1].split(",") if Game.args.has("--only") else PackedStringArray()
	await get_tree().process_frame
	Game.new_game("warrior")
	Game.state["level"] = 20
	for t in Game.BOSS_CFG:
		Game.v18()["seen"][t] = true      # no boss introductions in the way of the pictures
	main.start_world()
	await frames(5)
	for land in LANDS:
		if not only.is_empty() and not land in only:
			continue
		Game.hp = Game.max_hp()
		main.player.revive()
		main.goto_map(land, Vector2(200, 200))
		await frames(3)
		var w: Node = main.world
		var start: Vector2 = w.start_feet()
		main.player.global_position = start
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		for a in get_tree().get_nodes_in_group("exits"):
			a.remove_from_group("exits")
			a.queue_free()
		await frames(2)
		var row: Array = LANDS[land]
		var x := 46.0
		var y := 4.0
		for t in row:
			var e: Node = w.spawn_enemy(t, start + Vector2(x, y))
			e.parley = true
			e.calm = 1e6
			x += 58.0 if t in ["golem", "icegolem", "slagbrute", "frostknight", "cinderhound", "crystalSpider", "frostwolf", "lurker"] else 46.0
			if x > 200.0:      # a second line below, so a wall to the right hides nobody
				x = 46.0
				y += 56.0
		await frames(260)
		for e in get_tree().get_nodes_in_group("enemies"):
			e.velocity = Vector2.ZERO
		await snap(land)
	get_tree().quit()

func snap(shot: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(shot + ".png"))
	printerr("SHOT ", shot)

extends Node
## (v0.35) Screenshots of the painted maps from several places, in daylight, no weather, the HUD hidden (needs a renderer):
##   xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 -- --test res://tests/v35mapshots.gd --out <dir> [--only village,forest] [--phase 1] [--hud]

var main: Node
var out := "user://shots"
const VIEWS := {
	"village": [Vector2(450, 430), Vector2(200, 300), Vector2(690, 260), Vector2(450, 600)],
	"forest": [Vector2(550, 420), Vector2(250, 300), Vector2(850, 600), Vector2(560, 120)],
	"camp": [Vector2(600, 480), Vector2(330, 300), Vector2(860, 360), Vector2(600, 860)],
}

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func run(m: Node) -> void:
	main = m
	var i := Game.args.find("--out")
	if i >= 0 and i + 1 < Game.args.size():
		out = Game.args[i + 1]
	DirAccess.make_dir_recursive_absolute(out)
	var only := Game.args[Game.args.find("--only") + 1].split(",") if Game.args.has("--only") else PackedStringArray()
	var phase := int(Game.args[Game.args.find("--phase") + 1]) if Game.args.has("--phase") else 1
	await get_tree().process_frame
	Game.new_game("warrior")
	Game.state["level"] = 20
	for t in Game.BOSS_CFG:
		Game.v18()["seen"][t] = true
	main.start_world()
	await frames(5)
	for land in VIEWS:
		if not only.is_empty() and not land in only:
			continue
		main.goto_map(land, Vector2(200, 200))
		await frames(3)
		var w: Node = main.world
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		for a in get_tree().get_nodes_in_group("exits"):
			a.remove_from_group("exits")
			a.queue_free()
		if w.lighting:
			w.lighting.forced_phase = phase
		if w.atmos:
			w.atmos.calm = true
			w.atmos.set_weather("")
		main.hud.visible = Game.args.has("--hud")
		var n := 0
		for p in VIEWS[land]:
			main.player.global_position = p
			main.player.revive()
			await frames(30)
			await snap("%s_%d" % [land, n])
			n += 1
	get_tree().quit()

func snap(shot: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(shot + ".png"))
	printerr("SHOT ", shot)

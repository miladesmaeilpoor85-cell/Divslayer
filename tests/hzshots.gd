extends Node
## screenshots of the hazard layer on the four maps that have one
var main: Node

func run(m: Node) -> void:
	main = m
	var out := "/tmp/claude-0/hzshots"
	DirAccess.make_dir_recursive_absolute(out)
	await get_tree().process_frame
	Game.new_game("warrior")
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	main.start_world()
	for spec in [["peaks", Vector2(615, 330)], ["sanctum", Vector2(440, 330)], ["shadowfen", Vector2(580, 340)], ["emberforge", Vector2(560, 520)]]:
		Game.hp = 99999.0
		main.goto_map(spec[0], spec[1])
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		for i in 100:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join(spec[0] + ".png"))
	print("HZ_DONE")
	get_tree().quit()

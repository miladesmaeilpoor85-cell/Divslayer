extends Node
## Script cost per frame, region by region, at night with weather (the heaviest case for the effects):
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/perftest.gd
## Prints PERF_JSON {map: {process_ms, physics_ms, nodes, particles}}. Rendering cost is not measured here.
var main: Node

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func run(m: Node) -> void:
	main = m
	Game.new_game("warrior")
	Game.state["level"] = 6
	main.start_world()
	await frames(10)
	var out := {}
	var maps := {"village": ["rain", Vector2(450, 470)], "forest": ["fog", Vector2(560, 470)], "dungeon": ["", Vector2(430, 420)],
		"peaks": ["ash", Vector2(560, 700)], "shadowfen": ["fog", Vector2(1000, 600)], "sanctum": ["snow", Vector2(600, 820)],
		"emberforge": ["", Vector2(150, 520)], "camp": ["", Vector2(600, 450)]}
	for k in maps:
		Game.state["day_t"] = 0.87
		main.goto_map(k, maps[k][1])
		main.world.atmos.forced = maps[k][0]
		main.world.atmos.set_weather(maps[k][0])
		Game.hp = 99999.0
		await frames(30)
		var pt := 0.0
		var ft := 0.0
		var n := 240
		for i in n:
			# keep fighting: the hero swings at whatever is near, so sparks, numbers and loot are in the mix
			if i % 20 == 0:
				main.player.attack()
			if i % 60 == 0:
				main.player.dodge()
			Game.hp = 99999.0
			var t0 := Time.get_ticks_usec()
			await get_tree().process_frame
			var dt_us := Time.get_ticks_usec() - t0
			pt += dt_us / 1000000.0
			ft = max(ft, dt_us / 1000000.0)
		var parts := 0
		for e in main.world.find_children("*", "CPUParticles2D", true, false):
			if e.emitting:
				parts += e.amount
		out[k] = {"frame_ms": snapped(pt / n * 1000.0, 0.01), "worst_ms": snapped(ft * 1000.0, 0.01),
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "particles": parts}
		printerr(k, " ", out[k])
	print("PERF_JSON " + JSON.stringify(out))
	get_tree().quit()

extends Node
## Regression test for enemy spawn clearance against bottom-pivoted collision shapes.
## Checks both the clearance helper and the actual enemy created by World.build().
## Run through tools/run_all_tests.sh or:
## godot --headless --fixed-fps 60 --path . -- --test res://tests/spawncleartest.gd

const World = preload("res://scripts/world.gd")

var results: Dictionary = {}
var fails: Array[String] = []


func check(label: String, ok: bool, info: Variant = null) -> void:
	results[label] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(label)
	printerr(("PASS " if ok else "FAIL ") + label + ("" if info == null else "  " + str(info)))


func _overlaps_wall(rect: Rect2, walls: Array) -> bool:
	for wall in walls:
		var wall_rect := Rect2(
			float(wall["x"]),
			float(wall["y"]),
			float(wall["w"]),
			float(wall["h"])
		)
		if rect.intersects(wall_rect):
			return true
	return false


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame
		await get_tree().physics_frame


func _runtime_hitbox(enemy: Node) -> Rect2:
	var collision := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not (collision.shape is RectangleShape2D):
		return Rect2()
	var shape := collision.shape as RectangleShape2D
	return Rect2(
		enemy.global_position + collision.position - shape.size * 0.5,
		shape.size
	)


func run(main: Node) -> void:
	var map_doc = JSON.parse_string(FileAccess.get_file_as_string("res://data/Maps/wyrmhollow.json"))
	check("wyrmhollow_fixture_loads", typeof(map_doc) == TYPE_DICTIONARY)
	if typeof(map_doc) != TYPE_DICTIONARY:
		get_tree().quit(1)
		return

	var map_data: Dictionary = map_doc.get("data", {})
	var walls: Array = map_data.get("walls", [])
	var enemy_data: Dictionary = Game.enemy_def("frostknight")
	var enemy_w: float = float(enemy_data.get("w", 28.0))
	var enemy_h: float = float(enemy_data.get("h", 38.0))
	var collision_h: float = minf(enemy_h, 18.0)

	# The real Frostknight spawn at (640, 210) was the case missed by the old
	# 14 px search rectangle: its collision box clips the wall below the arena.
	var spawn_feet := Vector2(640.0 + enemy_w * 0.5, 210.0 + enemy_h)
	var raw_hitbox := Rect2(
		spawn_feet.x - enemy_w * 0.4,
		spawn_feet.y - collision_h,
		enemy_w * 0.8,
		collision_h
	)
	check("fixture_reproduces_raw_wall_overlap", _overlaps_wall(raw_hitbox, walls), raw_hitbox)

	var helper_world = World.new()
	helper_world.data = map_data
	var safe_feet: Vector2 = helper_world._clear_feet(
		spawn_feet,
		enemy_w * 0.5,
		collision_h
	)
	var safe_hitbox := Rect2(
		safe_feet.x - enemy_w * 0.4,
		safe_feet.y - collision_h,
		enemy_w * 0.8,
		collision_h
	)
	check("frostknight_spawn_is_relocated", safe_feet != spawn_feet, safe_feet)
	check(
		"full_collision_shape_clears_all_walls",
		not _overlaps_wall(safe_hitbox, walls),
		{"feet": safe_feet, "hitbox": safe_hitbox}
	)
	check(
		"relocated_hitbox_stays_inside_map",
		safe_hitbox.position.x >= 0.0
		and safe_hitbox.position.y >= 0.0
		and safe_hitbox.end.x <= float(map_data.get("w", 0.0))
		and safe_hitbox.end.y <= float(map_data.get("h", 0.0)),
		safe_hitbox
	)
	helper_world.free()

	# Integration path: construct the real map, let World.build() spawn the
	# Frostknight, then inspect the live CollisionShape2D rather than rebuilding
	# the shape dimensions from the data fixture.
	Game.new_game("warrior")
	main.start_world()
	await _frames(5)
	main.goto_map("wyrmhollow", Vector2(640.0, 210.0))
	await _frames(6)
	var live_world: Node = main.world
	check("runtime_wyrmhollow_world_loaded", live_world != null and live_world.key == "wyrmhollow")

	var expected_spawn := Vector2(640.0 + enemy_w * 0.5, 210.0 + enemy_h)
	var target_enemy: Node = null
	var closest_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.world != live_world or enemy.type != "frostknight":
			continue
		var distance: float = enemy.home.distance_to(expected_spawn)
		if distance < closest_distance:
			closest_distance = distance
			target_enemy = enemy

	check("runtime_frostknight_spawn_found", target_enemy != null, closest_distance)
	if target_enemy != null:
		var live_collision := target_enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
		check("runtime_collision_shape_exists", live_collision != null)
		if live_collision != null and live_collision.shape is RectangleShape2D:
			var live_shape := live_collision.shape as RectangleShape2D
			var live_rect := _runtime_hitbox(target_enemy)
			check(
				"runtime_collision_dimensions_match_enemy_contract",
				live_shape.size.is_equal_approx(Vector2(enemy_w * 0.8, collision_h)),
				live_shape.size
			)
			check(
				"runtime_frostknight_is_moved_from_blocked_source",
				target_enemy.home.distance_to(expected_spawn) > 0.1,
				{"source": expected_spawn, "actual_feet": target_enemy.home}
			)
			check(
				"runtime_full_hitbox_does_not_intersect_walls",
				not _overlaps_wall(live_rect, walls),
				{"feet": target_enemy.global_position, "hitbox": live_rect}
			)
			check(
				"runtime_hitbox_remains_inside_map",
				live_rect.position.x >= 0.0
				and live_rect.position.y >= 0.0
				and live_rect.end.x <= float(map_data.get("w", 0.0))
				and live_rect.end.y <= float(map_data.get("h", 0.0)),
				live_rect
			)
	else:
		check("runtime_collision_shape_exists", false, "No live Frostknight instance found")

	printerr("SPAWNCLEARTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit(1 if not fails.is_empty() else 0)

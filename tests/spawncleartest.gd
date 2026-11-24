extends Node
## Regression test for enemy spawn clearance against bottom-pivoted collision shapes.
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


func run(_main: Node) -> void:
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

	var test_world = World.new()
	test_world.data = map_data
	var safe_feet: Vector2 = test_world._clear_feet(
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
	check("full_collision_shape_clears_all_walls",
		not _overlaps_wall(safe_hitbox, walls),
		{"feet": safe_feet, "hitbox": safe_hitbox})
	check("relocated_hitbox_stays_inside_map",
		safe_hitbox.position.x >= 0.0
		and safe_hitbox.position.y >= 0.0
		and safe_hitbox.end.x <= float(map_data.get("w", 0.0))
		and safe_hitbox.end.y <= float(map_data.get("h", 0.0)),
		safe_hitbox)

	test_world.free()
	printerr("SPAWNCLEARTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit(1 if not fails.is_empty() else 0)

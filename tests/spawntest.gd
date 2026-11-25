extends Node
## Regression tests for spawn placement against the actual Enemy collision shape.
## Run through tools/run_all_tests.sh or:
## godot --headless --fixed-fps 60 --path . -- --test res://tests/spawntest.gd

var results: Dictionary = {}
var fails: Array[String] = []


func check(label: String, ok: bool, info: Variant = null) -> void:
	results[label] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(label)
	printerr(("PASS " if ok else "FAIL ") + label + ("" if info == null else "  " + str(info)))


func run(_main: Node) -> void:
	var world_script = load("res://scripts/world.gd")
	var probe = world_script.new()
	var map_names := ["frostvale", "wyrmhollow", "damavand", "zahhakcave"]
	var remaining_collisions: Array[String] = []
	var relocated := 0
	var checked := 0
	var wyrmhollow_case_seen := false
	var wyrmhollow_case_relocated := false

	for map_name in map_names:
		var map_record: Dictionary = Game.map_data(map_name)
		var map_data: Dictionary = map_record.get("data", {})
		if map_data.is_empty():
			remaining_collisions.append("%s: map data is missing or empty" % map_name)
			continue
		probe.data = map_data
		for spawn in map_data.get("enemySpawns", []):
			var enemy_type := str(spawn.get("type", ""))
			# Bosses intentionally use their authored arena coordinates and their own
			# unstick logic. This regression covers ordinary Enemy collision shapes.
			if Game.BOSS_CFG.has(enemy_type):
				continue
			var definition: Dictionary = Game.enemy_def(enemy_type)
			if definition.is_empty():
				remaining_collisions.append("%s:%s has no enemy definition" % [map_name, enemy_type])
				continue
			var width := float(definition.get("w", 24.0))
			var height := float(definition.get("h", 24.0))
			var body_height := minf(height, 18.0)
			var original_feet := Vector2(float(spawn["x"]) + width * 0.5, float(spawn["y"]) + height)
			var final_feet: Vector2 = probe._clear_feet(original_feet, width * 0.5, body_height)
			checked += 1
			if not final_feet.is_equal_approx(original_feet):
				relocated += 1
			if map_name == "wyrmhollow" and enemy_type == "frostknight" and is_equal_approx(float(spawn["x"]), 640.0) and is_equal_approx(float(spawn["y"]), 210.0):
				wyrmhollow_case_seen = true
				wyrmhollow_case_relocated = not final_feet.is_equal_approx(original_feet)

			# Mirror Enemy.setup(): shape width is 80% of the artwork width and
			# height is capped at 18 px, positioned immediately above the feet.
			var body := Rect2(
				final_feet.x - width * 0.4,
				final_feet.y - body_height,
				width * 0.8,
				body_height
			)
			for wall in map_data.get("walls", []):
				var wall_rect := Rect2(
					float(wall["x"]), float(wall["y"]),
					float(wall["w"]), float(wall["h"])
				)
				if body.intersects(wall_rect):
					remaining_collisions.append(
						"%s:%s at %s intersects wall %s" % [map_name, enemy_type, str(final_feet), str(wall_rect)]
					)
					break

	check("audited_enemy_spawns_have_definitions", checked > 0 and remaining_collisions.is_empty(), remaining_collisions)
	check("wyrmhollow_frostknight_regression_case_exists", wyrmhollow_case_seen)
	check("wyrmhollow_frostknight_is_relocated", wyrmhollow_case_relocated)
	check("spawn_probe_relocates_only_when_needed", relocated > 0, {"checked": checked, "relocated": relocated})

	probe.free()
	printerr("SPAWNTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit(1 if not fails.is_empty() else 0)

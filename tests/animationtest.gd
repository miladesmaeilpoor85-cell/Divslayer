extends Node
## Regression coverage for the first multi-frame directional hero attack atlas.

const Sheets = preload("res://scripts/sheets.gd")
var results := {}
var fails: Array = []

func check(label: String, ok: bool, info = null) -> void:
	results[label] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(label)
	printerr(("PASS " if ok else "FAIL ") + label + ("" if info == null else "  " + str(info)))

func run(_main: Node) -> void:
	await get_tree().process_frame
	var hero: Dictionary = Sheets.character("heroes", "warrior_starter")
	var frames: SpriteFrames = hero.get("frames")
	check("warrior_starter_sheet_loaded", frames != null)
	if frames != null:
		for direction in ["down", "up", "side"]:
			var animation := "attack_" + direction
			check("warrior_" + direction + "_attack_has_four_frames", frames.has_animation(animation) and frames.get_frame_count(animation) == 4, frames.get_frame_count(animation) if frames.has_animation(animation) else -1)
			if frames.has_animation(animation):
				check("warrior_" + direction + "_attack_uses_24_fps", is_equal_approx(frames.get_animation_speed(animation), 25.0), frames.get_animation_speed(animation))
				check("warrior_" + direction + "_attack_is_one_shot", not frames.get_animation_loop(animation))
		check("warrior_walk_keeps_four_original_frames", frames.get_frame_count("walk_down") == 4)
	var skeleton: Dictionary = Sheets.enemy("skeleton")
	var enemy_frames: SpriteFrames = skeleton.get("frames")
	check("skeleton_original_animation_remains_available", enemy_frames != null and enemy_frames.get_frame_count("v0") == 4)
	print("ANIMATIONTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit(1 if not fails.is_empty() else 0)

extends Node
## Regression test for the project's currently tracked directional sprite sheets.

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
	var hero_frames: SpriteFrames = hero.get("frames")
	check("warrior_starter_sheet_loaded", hero_frames != null)
	if hero_frames != null:
		for direction in ["down", "up", "side"]:
			check("warrior_" + direction + "_walk_has_four_frames", hero_frames.has_animation("walk_" + direction) and hero_frames.get_frame_count("walk_" + direction) == 4)
			check("warrior_" + direction + "_idle_has_one_frame", hero_frames.has_animation("idle_" + direction) and hero_frames.get_frame_count("idle_" + direction) == 1)
			check("warrior_" + direction + "_attack_uses_existing_single_frame", hero_frames.has_animation("attack_" + direction) and hero_frames.get_frame_count("attack_" + direction) == 1)
			check("warrior_" + direction + "_attack_is_one_shot", not hero_frames.get_animation_loop("attack_" + direction))
	var creature: Dictionary = Sheets.enemy("skeleton")
	var enemy_frames: SpriteFrames = creature.get("frames")
	check("current_horned_creature_animation_remains_available", enemy_frames != null and enemy_frames.get_frame_count("v0") == 4)
	print("ANIMATIONTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit(1 if not fails.is_empty() else 0)

extends Node
## Regression tests for existing sheets and metadata-driven multi-frame hero attacks.

const Sheets = preload("res://scripts/sheets.gd")
var results := {}
var fails: Array = []

func check(label: String, ok: bool, info = null) -> void:
	results[label] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(label)
	printerr(("PASS " if ok else "FAIL ") + label + ("" if info == null else "  " + str(info)))

func _make_test_sheet(columns: int) -> Texture2D:
	var cell_w := 16
	var cell_h := 12
	var image := Image.create(cell_w * columns, cell_h * 3, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for row in range(3):
		for column in range(columns):
			image.fill_rect(
				Rect2i(column * cell_w, row * cell_h, cell_w, cell_h),
				Color(1.0, 1.0, 1.0, 1.0)
			)
	return ImageTexture.create_from_image(image)

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

	# Future-ready format: the four walk columns are followed by four attack columns.
	var extended_meta := {
		"cellW": 16,
		"cellH": 12,
		"cols": ["walk0", "walk1", "walk2", "walk3", "attack0", "attack1", "attack2", "attack3"],
		"walkFps": 9.0,
		"attackFps": 24.0,
	}
	var extended_frames := Sheets.character_frames(_make_test_sheet(8), extended_meta)
	for direction in ["down", "up", "side"]:
		check("extended_" + direction + "_attack_has_four_frames", extended_frames.get_frame_count("attack_" + direction) == 4)
		check("extended_" + direction + "_attack_is_one_shot", not extended_frames.get_animation_loop("attack_" + direction))
		check("extended_" + direction + "_walk_is_unchanged", extended_frames.get_frame_count("walk_" + direction) == 4)
	check("extended_attack_uses_configured_fps", is_equal_approx(extended_frames.get_animation_speed("attack_down"), 24.0))
	var first_attack := extended_frames.get_frame_texture("attack_up", 0) as AtlasTexture
	var last_attack := extended_frames.get_frame_texture("attack_up", 3) as AtlasTexture
	check(
		"extended_attack_columns_keep_atlas_order",
		first_attack != null and last_attack != null
		and first_attack.region.position == Vector2(64, 12)
		and last_attack.region.position == Vector2(112, 12)
	)

	var creature: Dictionary = Sheets.enemy("skeleton")
	var enemy_frames: SpriteFrames = creature.get("frames")
	check("current_horned_creature_animation_remains_available", enemy_frames != null and enemy_frames.get_frame_count("v0") == 4)
	print("ANIMATIONTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit(1 if not fails.is_empty() else 0)

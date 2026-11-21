extends Node
## Regression tests for all production character sheets and metadata-driven multi-frame attacks.

const Sheets = preload("res://scripts/sheets.gd")
const PlayerCombat = preload("res://scripts/player.gd")
const ClassCardArt = preload("res://scripts/ui/class_card_art.gd")
const USER_CLASS_ATLAS: Texture2D = preload("res://assets/art/ClassCards/class_motion_atlas.webp")
const USER_PORTRAIT_ATLAS: Texture2D = preload("res://assets/art/Portraits/character_portraits_2026.webp")
const Portrait = preload("res://scripts/ui/portrait.gd")
var results := {}
var fails: Array = []

func check(label: String, ok: bool, info = null) -> void:
	results[label] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(label)
	printerr(("PASS " if ok else "FAIL ") + label + ("" if info == null else "  " + str(info)))

func make_test_sheet(columns: int) -> Texture2D:
	var cell_w := 16
	var cell_h := 12
	var image := Image.create(cell_w * columns, cell_h * 3, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for row in range(3):
		for column in range(columns):
			image.fill_rect(Rect2i(column * cell_w, row * cell_h, cell_w, cell_h), Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(image)

func run(_main: Node) -> void:
	await get_tree().process_frame

	# User-supplied 2026 art: verify the imported WebP atlases, four six-pose card
	# clips and the story portraits wired to the supplied turnaround artwork.
	check("user_class_motion_atlas_imported", USER_CLASS_ATLAS != null
		and USER_CLASS_ATLAS.get_width() == 384 and USER_CLASS_ATLAS.get_height() == 384)
	for calling in ["warrior", "mage", "rogue", "paladin"]:
		var card_frames: Array[Texture2D] = ClassCardArt.frames_for(calling)
		check("user_%s_class_card_has_six_motion_frames" % calling, card_frames.size() == 6)
		if card_frames.size() == 6:
			var first_frame := card_frames[0] as AtlasTexture
			var last_frame := card_frames[5] as AtlasTexture
			check("user_%s_class_card_frames_have_expected_cell_size" % calling,
				first_frame != null and first_frame.get_size() == Vector2(96, 64)
				and last_frame != null and last_frame.get_size() == Vector2(96, 64))
	check("user_story_portrait_atlas_imported", USER_PORTRAIT_ATLAS != null
		and USER_PORTRAIT_ATLAS.get_width() == 384 and USER_PORTRAIT_ATLAS.get_height() == 384)
	for actor in ["npc_rostam", "npc_siavash", "npc_gordafarid", "alchemist"]:
		check("user_story_portrait_%s_is_registered" % actor, Portrait.has_art(actor))

	var hero_manifest: Dictionary = Game.manifest.get("heroes", {})
	var hero_names: Array = hero_manifest.keys()
	hero_names.sort()
	check("all_twelve_hero_looks_are_registered", hero_names.size() == 12, hero_names.size())
	for raw_name in hero_names:
		var sheet_name := str(raw_name)
		var hero: Dictionary = Sheets.character("heroes", sheet_name)
		var hero_frames: SpriteFrames = hero.get("frames")
		check(sheet_name + "_sheet_loaded", hero_frames != null)
		if hero_frames == null:
			continue
		var expected_attack_frames := int(hero_manifest[sheet_name].get("attackFrames", 1))
		for direction in ["down", "up", "side"]:
			var walk: String = "walk_" + str(direction)
			var idle: String = "idle_" + str(direction)
			var attack: String = "attack_" + str(direction)
			check(sheet_name + "_" + direction + "_walk_has_four_frames",
				hero_frames.has_animation(walk) and hero_frames.get_frame_count(walk) == 4)
			check(sheet_name + "_" + direction + "_idle_has_one_frame",
				hero_frames.has_animation(idle) and hero_frames.get_frame_count(idle) == 1)
			check(sheet_name + "_" + direction + "_attack_matches_manifest",
				hero_frames.has_animation(attack) and hero_frames.get_frame_count(attack) == expected_attack_frames)
			check(sheet_name + "_" + direction + "_attack_is_one_shot",
				hero_frames.has_animation(attack) and not hero_frames.get_animation_loop(attack))

	# Production candidate: Warrior Starter uses 4 individual PNG frames per direction.
	var warrior_meta: Dictionary = hero_manifest.get("warrior_starter", {})
	var warrior_file_rows: Array = warrior_meta.get("attackFrameFiles", [])
	check("warrior_starter_attack_frame_files_have_three_direction_rows",
		warrior_file_rows.size() == 3)
	check("warrior_starter_attack_frame_files_have_four_frames_each",
		warrior_file_rows.size() == 3 and warrior_file_rows.all(func(row): return row.size() == 4))
	var warrior_entry: Dictionary = Sheets.character("heroes", "warrior_starter")
	var warrior_frames: SpriteFrames = warrior_entry.get("frames")
	for direction in ["down", "up", "side"]:
		var clip: String = "attack_" + str(direction)
		check("warrior_starter_" + direction + "_frames_are_individual_160x156_textures",
			warrior_frames.get_frame_count(clip) == 4
			and (warrior_frames.get_frame_texture(clip, 0) as Texture2D).get_width() == 160
			and (warrior_frames.get_frame_texture(clip, 0) as Texture2D).get_height() == 156)
	check("warrior_starter_contact_frame_matches_24_fps_timing",
		is_equal_approx(Sheets.animation_impact_time(warrior_frames, "attack_down", 2), 2.0 / 24.0))

	# Future format A: four walk columns followed by four attack columns in one atlas.
	var embedded_meta := {
		"cellW": 16,
		"cellH": 12,
		"cols": ["walk0", "walk1", "walk2", "walk3", "attack0", "attack1", "attack2", "attack3"],
		"walkFps": 9.0,
		"attackFps": 24.0,
	}
	var embedded := Sheets.character_frames(make_test_sheet(8), embedded_meta)
	for direction in ["down", "up", "side"]:
		var attack: String = "attack_" + str(direction)
		var walk: String = "walk_" + str(direction)
		check("embedded_" + direction + "_attack_has_four_frames", embedded.get_frame_count(attack) == 4)
		check("embedded_" + direction + "_attack_is_one_shot", not embedded.get_animation_loop(attack))
		check("embedded_" + direction + "_walk_is_unchanged", embedded.get_frame_count(walk) == 4)
	var first_embedded := embedded.get_frame_texture("attack_up", 0) as AtlasTexture
	var last_embedded := embedded.get_frame_texture("attack_up", 3) as AtlasTexture
	check("embedded_attack_columns_keep_atlas_order",
		first_embedded.region.position == Vector2(64, 12) and last_embedded.region.position == Vector2(112, 12))

	# Future format B: keep the walk atlas unchanged and register a separate attack atlas.
	var separate_meta := {
		"cellW": 16,
		"cellH": 12,
		"cols": ["walk0", "walk1", "walk2", "walk3", "attack"],
		"attackFrames": 4,
		"walkFps": 9.0,
		"attackFps": 24.0,
	}
	var separate := Sheets.character_frames(make_test_sheet(5), separate_meta, make_test_sheet(4))
	for direction in ["down", "up", "side"]:
		var attack: String = "attack_" + str(direction)
		var walk: String = "walk_" + str(direction)
		check("separate_" + direction + "_attack_has_four_frames", separate.get_frame_count(attack) == 4)
		check("separate_" + direction + "_attack_is_one_shot", not separate.get_animation_loop(attack))
		check("separate_" + direction + "_walk_is_unchanged", separate.get_frame_count(walk) == 4)
	var first_separate := separate.get_frame_texture("attack_side", 0) as AtlasTexture
	var last_separate := separate.get_frame_texture("attack_side", 3) as AtlasTexture
	check("separate_attack_atlas_row_and_order",
		first_separate.region.position == Vector2(0, 24) and last_separate.region.position == Vector2(48, 24))
	check("separate_attack_uses_configured_speed",
		is_equal_approx(separate.get_animation_speed("attack_down"), 24.0))

	# The attack pose remains visible for at least the legacy gameplay window,
	# but a longer future multi-frame clip is allowed to finish.
	var legacy_attack_frames := SpriteFrames.new()
	legacy_attack_frames.add_animation("attack_down")
	legacy_attack_frames.set_animation_speed("attack_down", 24.0)
	legacy_attack_frames.add_frame("attack_down", separate.get_frame_texture("attack_down", 0))
	check("single_frame_attack_keeps_legacy_minimum",
		is_equal_approx(Sheets.animation_duration(legacy_attack_frames, "attack_down", 0.16), 0.16))
	check("four_frame_attack_duration_matches_clip_length",
		is_equal_approx(Sheets.animation_duration(embedded, "attack_up", 0.16), 4.0 / 24.0))
	check("heavy_attack_keeps_legacy_minimum_for_short_clip",
		is_equal_approx(Sheets.animation_duration(embedded, "attack_up", 0.26), 0.26))
	check("animation_duration_respects_playback_scale",
		is_equal_approx(Sheets.animation_duration(embedded, "attack_up", 0.0, 2.0), 2.0 / 24.0))
	check("missing_animation_uses_safe_minimum",
		is_equal_approx(Sheets.animation_duration(embedded, "missing", 0.16), 0.16))

	# Impact-frame scheduling uses zero-based frame indices and the runtime clip speed.
	check("impact_frame_zero_is_immediate",
		is_equal_approx(Sheets.animation_impact_time(embedded, "attack_down", 0), 0.0))
	check("impact_frame_two_matches_attack_fps",
		is_equal_approx(Sheets.animation_impact_time(embedded, "attack_down", 2), 2.0 / 24.0))
	check("impact_frame_respects_playback_scale",
		is_equal_approx(Sheets.animation_impact_time(embedded, "attack_down", 2, 2.0), 2.0 / 48.0))
	check("negative_impact_frame_clamps_to_start",
		is_equal_approx(Sheets.animation_impact_time(embedded, "attack_down", -1), 0.0))
	check("oversized_impact_frame_clamps_to_last_frame",
		is_equal_approx(Sheets.animation_impact_time(embedded, "attack_down", 99), 3.0 / 24.0))
	check("missing_impact_animation_fails_safe",
		is_equal_approx(Sheets.animation_impact_time(embedded, "missing", 2), 0.0))

	# Directional hitboxes must extend forward while retaining the player's body.
	var combat_body := Rect2(100.0, 100.0, 26.0, 34.0)
	check("hitbox_down_extends_forward",
		PlayerCombat.swing_box_for(combat_body, "down", 20.0) == Rect2(96.0, 96.0, 34.0, 58.0))
	check("hitbox_up_extends_forward",
		PlayerCombat.swing_box_for(combat_body, "up", 20.0) == Rect2(96.0, 80.0, 34.0, 58.0))
	check("hitbox_left_extends_forward",
		PlayerCombat.swing_box_for(combat_body, "left", 26.0) == Rect2(74.0, 96.0, 56.0, 42.0))
	check("hitbox_right_extends_forward",
		PlayerCombat.swing_box_for(combat_body, "right", 26.0) == Rect2(96.0, 96.0, 56.0, 42.0))
	check("zero_reach_hitbox_still_covers_player_body",
		PlayerCombat.swing_box_for(combat_body, "down", 0.0) == combat_body.grow(4.0))
	check("negative_reach_is_clamped_to_zero",
		PlayerCombat.swing_box_for(combat_body, "down", -12.0) == combat_body.grow(4.0))

	# Validate every enemy atlas and each declared variant, then release the cache.
	var enemy_manifest: Dictionary = Game.manifest.get("enemies", {})
	var expected_enemy_sheets := 0
	var checked_enemy_sheets := 0
	for enemy_key in enemy_manifest.keys():
		var meta: Dictionary = enemy_manifest[enemy_key]
		if not meta.has("cellW"):
			continue # Wisp is drawn procedurally and intentionally has no sprite sheet.
		expected_enemy_sheets += 1
		var enemy: Dictionary = Sheets.enemy(str(enemy_key))
		var enemy_frames: SpriteFrames = enemy.get("frames")
		check(str(enemy_key) + "_enemy_sheet_loaded", enemy_frames != null)
		if enemy_frames == null:
			continue
		var frame_count := int(meta.get("frames", 1))
		var variants := int(meta.get("variants", 1))
		for variant in range(variants):
			var animation := "v%d" % variant
			var valid := enemy_frames.has_animation(animation)
			if valid:
				valid = enemy_frames.get_frame_count(animation) == frame_count
				var texture := enemy_frames.get_frame_texture(animation, 0) as AtlasTexture
				valid = valid and texture != null and texture.atlas != null
			check(str(enemy_key) + "_" + animation + "_matches_manifest", valid)
		checked_enemy_sheets += 1
	check("all_enemy_sprite_sheets_checked", checked_enemy_sheets == expected_enemy_sheets,
		{"checked": checked_enemy_sheets, "expected": expected_enemy_sheets})
	Sheets.forget_enemies()

	print("ANIMATIONTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit(1 if not fails.is_empty() else 0)

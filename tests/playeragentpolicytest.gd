extends Node
## Regression checks for the real-player agent's Arzhang pillar decision.
## A player should break all but one active grave pillar to avoid triggering another wave.

const PlayerAgent = preload("res://tests/player_agent.gd")
const PlayerBrain = preload("res://tests/player_brain.gd")
const PlayerObservation = preload("res://tests/player_observation.gd")
const PlayerVisualPerception = preload("res://tests/player_visual_perception.gd")
const PlayerMemory = preload("res://tests/player_memory.gd")
const Sheets = preload("res://scripts/sheets.gd")

var results: Dictionary = {}
var fails: Array[String] = []

func check(label: String, ok: bool, info = null) -> void:
	results[label] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(label)
	printerr(("PASS " if ok else "FAIL ") + label + ("" if info == null else "  " + str(info)))

func run(_main: Node) -> void:
	var visible_choices: Array = [
		{"text": "Leave", "enabled": true, "visible": true},
		{"text": "Buy armour", "enabled": true, "visible": true},
		{"text": "Continue", "enabled": false, "visible": true},
		{"text": "Hidden action", "enabled": true, "visible": false}
	]
	check("screen_brain_selects_the_matching_visible_choice",
		PlayerBrain.find_visible_button(visible_choices, ["Buy armour"]) == 1)
	check("screen_brain_ignores_disabled_choices",
		PlayerBrain.find_visible_button(visible_choices, ["Continue"]) == -1)
	check("screen_brain_ignores_invisible_choices",
		PlayerBrain.find_visible_button(visible_choices, ["Hidden action"]) == -1)
	check("screen_brain_uses_first_enabled_choice_only_when_fallback_is_requested",
		PlayerBrain.find_visible_button(visible_choices, ["not present"], true) == 0)
	check("screen_brain_does_not_guess_when_no_matching_choice_exists",
		PlayerBrain.find_visible_button(visible_choices, ["not present"]) == -1)
	var death_choices: Array = [
		{"text": "Return to Zabol", "enabled": true, "visible": true},
		{"text": "Rematch", "enabled": true, "visible": true}
	]
	check("screen_brain_prefers_a_visible_boss_rematch",
		PlayerBrain.find_death_recovery_button(death_choices) == 1)
	var adaptive_death_choices: Array = [
		{"text": "Rematch — Anvilward", "enabled": true, "visible": true},
		{"text": "Story difficulty — then fight again", "enabled": true, "visible": true}
	]
	check("screen_brain_adapts_when_story_difficulty_is_visibly_offered",
		PlayerBrain.find_death_recovery_button(adaptive_death_choices) == 1)
	check("screen_brain_recognizes_persian_story_difficulty",
		PlayerBrain.find_death_recovery_button([{"text": "سختی را «داستانی» کن و دوباره بجنگ", "enabled": true, "visible": true}]) == 0)
	check("screen_brain_uses_persian_respawn_label",
		PlayerBrain.find_death_recovery_button([{"text": "زنده شدن در زابل", "enabled": true, "visible": true}]) == 0)
	check("screen_brain_uses_visible_respawn_when_no_rematch_exists",
		PlayerBrain.find_death_recovery_button([{"text": "Respawn in Zabol", "enabled": true, "visible": true}]) == 0)
	check("screen_brain_refuses_unknown_death_actions",
		PlayerBrain.find_death_recovery_button([{"text": "Quit", "enabled": true, "visible": true}]) == -1)
	var hud_status := {"meters": {"HealthMeter": 0.42, "StaminaMeter": 0.65, "ManaMeter": 0.8}, "resources": {"potions_text": "۳"}}
	var parsed_status := PlayerBrain.read_visible_combat_status(hud_status)
	check("screen_brain_reads_health_from_visible_hud_meter", is_equal_approx(float(parsed_status.health_ratio), 0.42))
	check("screen_brain_reads_stamina_from_visible_hud_meter", is_equal_approx(float(parsed_status.stamina_ratio), 0.65))
	check("screen_brain_parses_persian_potion_count", int(parsed_status.potions) == 3)
	check("visible_potion_policy_uses_hud_health_and_stock", PlayerBrain.should_use_visible_potion(parsed_status, 1, 0.68))
	check("visible_potion_policy_respects_reserve", not PlayerBrain.should_use_visible_potion(parsed_status, 3, 0.68))
	check("visible_potion_policy_does_not_guess_missing_hud_values", not PlayerBrain.should_use_visible_potion({"health_ratio": -1.0, "potions": -1}, 0, 0.68))
	var visual_candidates: Array = [
		{"kind": "enemy", "confidence": 0.91, "rect": [0.2, 0.3, 0.1, 0.2]},
		{"kind": "boss", "confidence": 0.88, "rect": [0.7, 0.3, 0.2, 0.3]},
		{"kind": "telegraph", "confidence": 0.94, "rect": [0.45, 0.4, 0.2, 0.2]},
		{"kind": "projectile", "confidence": 0.2, "rect": [0.4, 0.4, 0.03, 0.03]},
		{"kind": "unknown", "confidence": 0.99, "rect": [0.1, 0.1, 0.2, 0.2]}
	]
	var visual_detections := PlayerVisualPerception.normalize_detections(visual_candidates, Vector2i(1600, 720))
	check("visual_perception_rejects_low_confidence_and_unknown_classes", visual_detections.size() == 3)
	check("visual_brain_selects_nearest_confident_target", str(PlayerBrain.select_visual_target(visual_detections, Vector2(0.5, 0.5)).get("kind", "")) == "enemy")
	check("visual_brain_prefers_visible_boss_when_encounter_policy_requests_it", str(PlayerBrain.select_visual_target(visual_detections, Vector2(0.5, 0.5), true).get("kind", "")) == "boss")
	var evade := PlayerBrain.visible_evasion_vector(visual_detections, Vector2(0.5, 0.5))
	check("visual_brain_evades_away_from_visible_telegraph", evade.length() > 0.99 and evade.x < 0.0)
	check("visual_brain_does_not_evade_on_low_confidence_threat", PlayerBrain.visible_evasion_vector([{"kind":"projectile","confidence":0.2,"center":Vector2(0.4,0.4)}], Vector2(0.5,0.5)) == Vector2.ZERO)
	check("visual_perception_rejects_invalid_frame_dimensions", PlayerVisualPerception.normalize_detections(visual_candidates, Vector2i.ZERO).is_empty())

	var brain_source := FileAccess.get_file_as_string("res://tests/player_brain.gd")
	var observer_source := FileAccess.get_file_as_string("res://tests/player_observation.gd")
	check("player_brain_has_no_game_state_or_world_queries",
		not brain_source.contains("Game.") and not brain_source.contains("get_nodes_in_group")
		and not brain_source.contains("quest_target") and not brain_source.contains("main.player"))
	check("screen_observer_has_no_enemy_or_quest_telemetry",
		not observer_source.contains("Game.") and not observer_source.contains("get_nodes_in_group")
		and not observer_source.contains("quest_target"))
	var test_layer := CanvasLayer.new()
	add_child(test_layer)
	var screen_button := Button.new()
	screen_button.text = "PLAYER_OBSERVATION_VISIBLE_SENTINEL"
	screen_button.position = Vector2(32, 32)
	screen_button.size = Vector2(240, 42)
	test_layer.add_child(screen_button)
	var hidden_button := Button.new()
	hidden_button.text = "PLAYER_OBSERVATION_HIDDEN_SENTINEL"
	hidden_button.position = Vector2(32, 82)
	hidden_button.size = Vector2(240, 42)
	hidden_button.visible = false
	test_layer.add_child(hidden_button)
	var hud_fixture := Control.new()
	hud_fixture.name = "HudFixture"
	add_child(hud_fixture)
	var health_meter := Control.new()
	health_meter.name = "HealthMeter"
	health_meter.set_meta("unused", true)
	health_meter.set_script(load("res://scripts/ui/bar.gd"))
	health_meter.set("value", 0.4)
	health_meter.position = Vector2(32, 132)
	health_meter.size = Vector2(180, 15)
	hud_fixture.add_child(health_meter)
	var potion_chip := HBoxContainer.new()
	potion_chip.name = "PotionChip"
	potion_chip.position = Vector2(32, 152)
	potion_chip.size = Vector2(80, 20)
	var potion_value := Label.new()
	potion_value.name = "Value"
	potion_value.text = "۳"
	potion_chip.add_child(potion_value)
	hud_fixture.add_child(potion_chip)
	var captured_screen := PlayerObservation.capture(self, _main.get_viewport())
	var saw_visible := false
	var saw_hidden := false
	for item in captured_screen.get("buttons", []):
		var label := str(item.get("text", ""))
		saw_visible = saw_visible or label == "PLAYER_OBSERVATION_VISIBLE_SENTINEL"
		saw_hidden = saw_hidden or label == "PLAYER_OBSERVATION_HIDDEN_SENTINEL"
	check("screen_observer_captures_visible_buttons", saw_visible)
	check("screen_observer_ignores_hidden_buttons", not saw_hidden)
	check("screen_observer_captures_visible_health_meter", is_equal_approx(float(captured_screen.get("meters", {}).get("HealthMeter", -1.0)), 0.4))
	check("screen_observer_captures_visible_potion_count", str(captured_screen.get("resources", {}).get("potions_text", "")) == "۳")
	var captured_frame := PlayerVisualPerception.capture_frame(_main.get_viewport())
	if DisplayServer.get_name() == "headless":
		check("visual_perception_refuses_viewport_readback_when_rendering_is_disabled", captured_frame.is_empty())
	else:
		check("visual_perception_captures_a_real_viewport_image", not captured_frame.is_empty() and captured_frame.get("image") is Image)
		check("visual_perception_records_frame_dimensions", int(captured_frame.get("width", 0)) > 0 and int(captured_frame.get("height", 0)) > 0)

	# Template matching is image-only and remains testable in headless CI.
	var sprite_template := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	sprite_template.fill(Color(0.0, 0.0, 0.0, 0.0))
	for sy in 2:
		for sx in 2:
			sprite_template.set_pixel(3 + sx, 3 + sy, Color(1.0, 0.0, 0.0, 1.0))
			sprite_template.set_pixel(7 + sx, 7 + sy, Color(0.0, 0.0, 1.0, 1.0))
	var synthetic_frame := Image.create(48, 36, false, Image.FORMAT_RGBA8)
	synthetic_frame.fill(Color(0.2, 0.2, 0.2, 1.0))
	for sy in 12:
		for sx in 12:
			var pixel := sprite_template.get_pixel(sx, sy)
			if pixel.a > 0.0:
				synthetic_frame.set_pixel(21 + sx, 9 + sy, pixel)
	var sprite_match := PlayerVisualPerception.match_template(synthetic_frame, sprite_template, "boss", 1, 0.98)
	check("sprite_template_match_finds_exact_rendered_frame", not sprite_match.is_empty() and str(sprite_match.get("kind", "")) == "boss")
	var sparse_coarse_match := PlayerVisualPerception.match_template(synthetic_frame, sprite_template, "boss", 3, 0.98)
	check("sprite_template_match_falls_back_when_coarse_stride_skips_sparse_pixels",
		not sparse_coarse_match.is_empty()
		and Vector2(sparse_coarse_match.get("rect", [0.0, 0.0])[0], sparse_coarse_match.get("rect", [0.0, 0.0])[1]).distance_to(Vector2(21.0 / 48.0, 9.0 / 36.0)) < 0.001)
	var matched_rect: Array = sprite_match.get("rect", [])
	check("sprite_template_match_returns_normalized_screen_bounds",
		matched_rect.size() == 4
		and float(matched_rect[0]) >= 0.0 and float(matched_rect[1]) >= 0.0
		and float(matched_rect[0]) + float(matched_rect[2]) <= 1.0
		and float(matched_rect[1]) + float(matched_rect[3]) <= 1.0)
	# Match scores cannot exceed 1.0; 1.01 therefore exercises the rejection boundary.
	var wrong_match := PlayerVisualPerception.match_template(synthetic_frame, sprite_template, "boss", 1, 1.01)
	check("sprite_template_match_rejects_threshold_above_perfect_score", wrong_match.is_empty())

	# Exercise the multi-resolution path with a sprite close to the game's rendered size.
	var large_template := Image.create(40, 48, false, Image.FORMAT_RGBA8)
	large_template.fill(Color(0.0, 0.0, 0.0, 0.0))
	for sy in range(4, 44):
		for sx in range(8, 32):
			large_template.set_pixel(sx, sy, Color(
				0.2 + float(sx - 8) / 48.0,
				0.25 + float(sy - 4) / 64.0,
				0.72 - float(sx - 8) / 120.0,
				1.0
			))
	var large_frame := Image.create(240, 160, false, Image.FORMAT_RGBA8)
	large_frame.fill(Color(0.08, 0.09, 0.1, 1.0))
	for sy in large_template.get_height():
		for sx in large_template.get_width():
			var large_pixel := large_template.get_pixel(sx, sy)
			if large_pixel.a > 0.0:
				large_frame.set_pixel(123 + sx, 61 + sy, large_pixel)
	var large_match := PlayerVisualPerception.match_template(large_frame, large_template, "player", 4, 0.98)
	var large_rect: Array = large_match.get("rect", [])
	check("sprite_template_multiresolution_match_refines_exact_large_sprite_position",
		large_rect.size() == 4
		and absf(float(large_rect[0]) - 123.0 / 240.0) < 0.005
		and absf(float(large_rect[1]) - 61.0 / 160.0) < 0.005
		and absf(float(large_rect[2]) - 40.0 / 240.0) < 0.005
		and absf(float(large_rect[3]) - 48.0 / 160.0) < 0.005)

	if DisplayServer.get_name() == "headless":
		for label in [
			"sprite_template_extractor_crops_real_atlas_region_and_trims_transparency",
			"sprite_template_builder_reads_frames_from_actual_spriteframes",
			"sprite_template_builder_detects_a_cropped_atlas_sprite_in_screen_pixels",
			"sprite_template_builder_extracts_actual_anvilward_game_art",
			"sprite_template_match_locates_actual_anvilward_sprite_art"
		]:
			results[label] = {"skipped": "requires a rendering backend; covered by Xvfb player journey"}
			printerr("SKIP " + label + " (headless renderer has no texture readback)")
	else:
		var actual_atlas_image := Image.create(32, 20, false, Image.FORMAT_RGBA8)
		actual_atlas_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		for sy in range(5, 11):
			for sx in range(6, 10):
				actual_atlas_image.set_pixel(sx, sy, Color(0.2 + float(sx - 6) * 0.12, 0.3 + float(sy - 5) * 0.08, 0.85, 1.0))
		var actual_atlas_texture := ImageTexture.create_from_image(actual_atlas_image)
		var actual_sprite_region := AtlasTexture.new()
		actual_sprite_region.atlas = actual_atlas_texture
		actual_sprite_region.region = Rect2(4, 3, 10, 10)
		var cropped_actual_sprite := PlayerVisualPerception.sprite_image_from_texture(actual_sprite_region, 1.0)
		var sprite_image_fixture := cropped_actual_sprite
		if sprite_image_fixture == null:
			sprite_image_fixture = Image.create(4, 6, false, Image.FORMAT_RGBA8)
			sprite_image_fixture.fill(Color(0.2, 0.3, 0.85, 1.0))
		check("sprite_template_extractor_crops_real_atlas_region_and_trims_transparency",
			cropped_actual_sprite != null and cropped_actual_sprite.get_width() == 4 and cropped_actual_sprite.get_height() == 6)
		var actual_sprite_frames := SpriteFrames.new()
		actual_sprite_frames.add_animation("idle_down")
		actual_sprite_frames.add_frame("idle_down", actual_sprite_region)
		var actual_sprite_templates := PlayerVisualPerception.build_sprite_templates(
			actual_sprite_frames, ["idle_down"], "player", "hero:test", 1.0, 1
		)
		check("sprite_template_builder_reads_frames_from_actual_spriteframes",
			actual_sprite_templates.size() == 1
			and str(actual_sprite_templates[0].get("id", "")) == "hero:test:idle_down:0"
			and actual_sprite_templates[0].get("image") is Image)
		var actual_sprite_frame := Image.create(36, 28, false, Image.FORMAT_RGBA8)
		actual_sprite_frame.fill(Color(0.08, 0.08, 0.08, 1.0))
		for sy in sprite_image_fixture.get_height():
			for sx in sprite_image_fixture.get_width():
				actual_sprite_frame.set_pixel(17 + sx, 12 + sy, sprite_image_fixture.get_pixel(sx, sy))
		var actual_sprite_detections: Array[Dictionary] = []
		if not actual_sprite_templates.is_empty():
			actual_sprite_detections = PlayerVisualPerception.detect_sprite_templates(
				actual_sprite_frame, actual_sprite_templates, 1, 0.98
			)
		check("sprite_template_builder_detects_a_cropped_atlas_sprite_in_screen_pixels",
			actual_sprite_detections.size() == 1
			and str(actual_sprite_detections[0].get("template_id", "")) == "hero:test:idle_down:0"
			and str(actual_sprite_detections[0].get("kind", "")) == "player")
	
		var anvilward_sheet: Dictionary = Sheets.enemy("anvilward")
		var anvilward_frames: SpriteFrames = anvilward_sheet.get("frames") as SpriteFrames
		var anvilward_templates := PlayerVisualPerception.build_sprite_templates(
			anvilward_frames, ["v0", "v1"], "boss", "boss:anvilward", Sheets.SCALE * 1.15, 1
		)
		check("sprite_template_builder_extracts_actual_anvilward_game_art",
			not anvilward_templates.is_empty()
			and str(anvilward_templates[0].get("kind", "")) == "boss"
			and str(anvilward_templates[0].get("id", "")).begins_with("boss:anvilward:"))
		var actual_anvilward_image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		actual_anvilward_image.fill(Color(0.8, 0.3, 0.2, 1.0))
		if not anvilward_templates.is_empty():
			actual_anvilward_image = anvilward_templates[0].get("image")
		var anvilward_render_fixture := Image.create(
			actual_anvilward_image.get_width() + 32,
			actual_anvilward_image.get_height() + 24,
			false, Image.FORMAT_RGBA8
		)
		anvilward_render_fixture.fill(Color(0.12, 0.13, 0.14, 1.0))
		for sy in actual_anvilward_image.get_height():
			for sx in actual_anvilward_image.get_width():
				var boss_pixel := actual_anvilward_image.get_pixel(sx, sy)
				if boss_pixel.a > 0.0:
					anvilward_render_fixture.set_pixel(13 + sx, 9 + sy, boss_pixel)
		var actual_anvilward_match: Array[Dictionary] = []
		if not anvilward_templates.is_empty():
			actual_anvilward_match = PlayerVisualPerception.detect_sprite_templates(
				anvilward_render_fixture, [anvilward_templates[0]], 1, 0.98
			)
		check("sprite_template_match_locates_actual_anvilward_sprite_art",
			actual_anvilward_match.size() == 1
			and str(actual_anvilward_match[0].get("template_id", "")) == str(anvilward_templates[0].get("id", ""))
			and str(actual_anvilward_match[0].get("kind", "")) == "boss")
	
	var heuristic_warning := PlayerVisualPerception.warning_proposals([
		{"kind": "warm_telegraph_candidate", "rect": Rect2i(40, 30, 20, 12), "confidence": 0.9}
	], Vector2i(160, 90))
	check("heuristic_telegraph_proposal_is_screen_normalized_and_confidence_capped",
		heuristic_warning.size() == 1
		and str(heuristic_warning[0].get("kind", "")) == "telegraph"
		and is_equal_approx(float(heuristic_warning[0].get("confidence", 1.0)), PlayerVisualPerception.MAX_HEURISTIC_WARNING_CONFIDENCE)
		and heuristic_warning[0].get("rect", Rect2()).position.distance_to(Vector2(0.25, 0.333333)) < 0.01)
	var visual_plan_detections: Array = [
		{"kind":"player","confidence":0.96,"rect":[0.45,0.40,0.06,0.12]},
		{"kind":"enemy","confidence":0.92,"rect":[0.68,0.40,0.08,0.13]},
		{"kind":"boss","confidence":0.94,"rect":[0.56,0.38,0.08,0.2]}
	]
	var normalized_visual_plan_detections := PlayerVisualPerception.normalize_detections(
		visual_plan_detections, Vector2i(1600, 720)
	)
	var visual_plan := PlayerBrain.visual_combat_plan(normalized_visual_plan_detections, true)
	check("visual_combat_plan_requires_player_sprite_and_prefers_visible_boss",
		bool(visual_plan.get("valid", false))
		and str(visual_plan.get("target", {}).get("kind", "")) == "boss"
		and Vector2(visual_plan.get("target_direction_screen", Vector2.ZERO)).x > 0.9)
	check("visual_combat_plan_fails_closed_without_player_sprite",
		not bool(PlayerBrain.visual_combat_plan([{"kind":"boss","confidence":0.99,"rect":[0.7,0.4,0.1,0.2]}]).get("valid", false)))
	check("heuristic_warning_never_directly_triggers_visual_evasion",
		PlayerBrain.visible_evasion_vector(heuristic_warning, Vector2(0.5, 0.5)) == Vector2.ZERO)

	test_layer.free()
	hud_fixture.free()

	check("no_pillars_do_not_trigger_pillar_chase", not PlayerAgent.should_prioritize_grave_pillars(0))
	check("leave_one_pillar_as_low_shield_anchor", not PlayerAgent.should_prioritize_grave_pillars(1))
	check("break_second_pillar_before_engaging_boss", PlayerAgent.should_prioritize_grave_pillars(2))
	check("break_two_of_three_pillars", PlayerAgent.should_prioritize_grave_pillars(3))
	check("break_three_of_four_pillars", PlayerAgent.should_prioritize_grave_pillars(4))
	check("invalid_negative_count_is_not_a_target", not PlayerAgent.should_prioritize_grave_pillars(-1))

	check("potion_is_used_when_below_threshold_and_ready", PlayerAgent.should_use_health_potion(55.0, 100.0, 2, 0, 3.0, 2.0, 0.68))
	check("potion_reserve_is_never_spent", not PlayerAgent.should_use_health_potion(20.0, 100.0, 1, 1, 3.0, 2.0, 0.68))
	check("potion_cooldown_prevents_rapid_reuse", not PlayerAgent.should_use_health_potion(20.0, 100.0, 3, 0, 3.0, 4.0, 0.68))
	check("potion_is_not_wasted_above_health_threshold", not PlayerAgent.should_use_health_potion(80.0, 100.0, 3, 0, 3.0, 2.0, 0.68))
	check("potion_is_not_used_without_stock", not PlayerAgent.should_use_health_potion(20.0, 100.0, 0, 0, 3.0, 2.0, 0.68))
	check("potion_becomes_ready_at_cooldown_boundary", PlayerAgent.should_use_health_potion(20.0, 100.0, 2, 0, 4.0, 4.0, 0.68))
	check("potion_cooldown_is_measured_from_current_fight_time", is_equal_approx(PlayerAgent.next_health_potion_time(3.0, 1.6), 4.6))

	check("focused_boss_is_kept_when_temporarily_cloaked", PlayerAgent.should_keep_focus_boss("matriarch", "matriarch", true))
	check("focused_boss_is_not_kept_after_defeat", not PlayerAgent.should_keep_focus_boss("matriarch", "matriarch", false))
	check("different_boss_cannot_replace_requested_objective", not PlayerAgent.should_keep_focus_boss("matriarch", "ancientwyrm", true))
	check("empty_boss_focus_does_not_lock_target_selection", not PlayerAgent.should_keep_focus_boss("", "matriarch", true))
	check("mage_seeks_a_casting_lane_when_a_wall_blocks_spells", PlayerAgent.should_seek_casting_lane("mage", false, 150.0, 62.0, false))
	check("mage_keeps_ranged_spacing_when_a_casting_lane_is_clear", not PlayerAgent.should_seek_casting_lane("mage", false, 180.0, 62.0, true))
	check("mage_does_not_seek_a_lane_for_a_melee_pillar_target", not PlayerAgent.should_seek_casting_lane("mage", true, 180.0, 62.0, false))
	check("non_mage_classes_do_not_use_mage_lane_policy", not PlayerAgent.should_seek_casting_lane("warrior", false, 180.0, 62.0, false))
	check("mage_can_close_only_when_already_inside_melee_reach", not PlayerAgent.should_seek_casting_lane("mage", false, 68.0, 62.0, false))
	check("mage_does_not_spam_dodge_at_safe_midrange", not PlayerAgent.should_dodge_mage(88.0, 77.0, 84.0, 57.0, 0.0))
	check("mage_dodges_at_immediate_contact_range", PlayerAgent.should_dodge_mage(45.0, 77.0, 84.0, 60.0, 0.0))
	check("mage_uses_emergency_dodge_when_critical_and_close", PlayerAgent.should_dodge_mage(110.0, 30.0, 84.0, 50.0, 0.0))
	check("mage_preserves_dodge_when_stamina_is_low", not PlayerAgent.should_dodge_mage(38.0, 8.0, 84.0, 24.0, 0.0))
	check("mage_does_not_repeat_dodge_during_cooldown", not PlayerAgent.should_dodge_mage(38.0, 8.0, 84.0, 60.0, 0.2))

	check("anvilward_circle_slam_uses_evasion_not_guard", PlayerAgent.should_evade_boss_telegraph("circle"))
	check("anvilward_forge_furrows_use_evasion", PlayerAgent.should_evade_boss_telegraph("lane"))
	check("predicted_boss_projectile_uses_evasion", PlayerAgent.should_evade_boss_telegraph("projectile"))
	check("boss_cone_remains_guardable_or_parryable", not PlayerAgent.should_evade_boss_telegraph("cone"))
	check("unknown_telegraph_is_not_marked_as_unavoidable_evasion", not PlayerAgent.should_evade_boss_telegraph("unknown"))
	check("mage_roll_window_fits_032_second_iframes", PlayerAgent.boss_dodge_window("mage") < 0.32 and is_equal_approx(PlayerAgent.boss_dodge_window("mage"), 0.22))
	check("warrior_roll_window_fits_042_second_iframes", PlayerAgent.boss_dodge_window("warrior") < 0.42)
	check("rogue_uses_its_longer_iframe_window", PlayerAgent.boss_dodge_window("rogue") > PlayerAgent.boss_dodge_window("warrior"))
	check("mage_uses_chain_casting_range_against_bosses", PlayerAgent.mage_boss_preferred_range() < 270.0 and PlayerAgent.mage_boss_preferred_range() > 230.0)
	check("mage_retreats_before_entering_anvilward_slam_range", PlayerAgent.mage_boss_retreat_distance() > 150.0)
	check("area_attack_uses_emergency_guard_when_roll_is_cooling_down", PlayerAgent.should_guard_boss_telegraph("circle", 0.12, false, 18.0, 0.0))
	check("area_attack_does_not_guard_while_roll_is_ready", not PlayerAgent.should_guard_boss_telegraph("lane", 0.12, true, 80.0, 0.0))
	check("area_attack_does_not_guard_before_impact", not PlayerAgent.should_guard_boss_telegraph("circle", 0.25, false, 80.0, 0.0))
	check("area_attack_does_not_guard_with_broken_guard", not PlayerAgent.should_guard_boss_telegraph("circle", 0.12, false, 80.0, 0.5))
	check("area_attack_does_not_guard_without_stamina", not PlayerAgent.should_guard_boss_telegraph("projectile", 0.12, false, 7.0, 0.0))
	var open_escape := PlayerAgent.safe_evasion_direction(Rect2(0, 0, 26, 34), Vector2.LEFT, [])
	check("wall_aware_evasion_keeps_open_primary_direction", open_escape.distance_to(Vector2.LEFT) < 0.001)
	var blocked_escape := PlayerAgent.safe_evasion_direction(Rect2(0, 0, 26, 34), Vector2.LEFT, [Rect2(-80, -10, 80, 60)], 72.0)
	check("wall_aware_evasion_sideslips_when_direct_route_is_blocked", absf(blocked_escape.x) < 0.75 and absf(blocked_escape.y) > 0.65)

	check("anvilward_alerted_close_adds_get_priority", PlayerAgent.should_prioritize_focus_add("anvilward", "slagbrute", false, 200.0, true))
	check("anvilward_alerted_ranged_adds_inside_aggro_are_prioritized", PlayerAgent.should_prioritize_focus_add("anvilward", "moltencore", false, 230.0, true))
	check("anvilward_does_not_pull_unalerted_adds_into_the_duel", not PlayerAgent.should_prioritize_focus_add("anvilward", "moltencore", false, 200.0, false))
	check("anvilward_prioritizes_alerted_squad_add_inside_extended_chase_range", PlayerAgent.should_prioritize_focus_add("anvilward", "moltencore", false, 400.0, true))
	check("anvilward_accepts_active_add_at_squad_alert_boundary", PlayerAgent.should_prioritize_focus_add("anvilward", "cinderhound", false, 445.5, true))
	check("anvilward_does_not_chase_alerted_add_beyond_squad_alert_range", not PlayerAgent.should_prioritize_focus_add("anvilward", "moltencore", false, 445.6, true))
	check("anvilward_itself_is_never_classified_as_an_add", not PlayerAgent.should_prioritize_focus_add("anvilward", "anvilward", true, 40.0, true))
	check("ordinary_boss_encounters_clear_immediate_pressure_adds", PlayerAgent.should_prioritize_focus_add("boss", "skeleton", false, 180.0, true))
	check("ordinary_boss_encounters_do_not_chase_distant_adds", not PlayerAgent.should_prioritize_focus_add("boss", "skeleton", false, 260.0, true))
	check("ancient_wyrm_keeps_close_alerted_wyrmling_priority", PlayerAgent.should_prioritize_focus_add("ancientwyrm", "wyrmling", false, 180.0, true))
	check("ancient_wyrm_does_not_chase_unalerted_wyrmlings", not PlayerAgent.should_prioritize_focus_add("ancientwyrm", "wyrmling", false, 100.0, false))

	var had_brann := Game.state.has("brann")
	var saved_brann: Variant = Game.state.get("brann", null)
	var had_defeated := Game.state.has("defeated")
	var saved_defeated: Variant = Game.state.get("defeated", null)
	Game.state["defeated"] = {}
	Game.state["brann"] = "none"
	check("emberforge_route_stays_sealed_without_kindling_key", Game.next_hop("peaks", "emberforge") == "")
	Game.state["brann"] = "anvil"
	check("village_to_emberforge_route_starts_through_forest", Game.next_hop("village", "emberforge") == "forest")
	check("forest_to_emberforge_route_uses_ash_peaks", Game.next_hop("forest", "emberforge") == "peaks")
	check("kindling_key_opens_dynamic_peaks_to_emberforge_route", Game.next_hop("peaks", "emberforge") == "emberforge")
	check("emberforge_return_route_uses_peaks", Game.next_hop("emberforge", "village") == "peaks")
	if had_brann:
		Game.state["brann"] = saved_brann
	else:
		Game.state.erase("brann")
	if had_defeated:
		Game.state["defeated"] = saved_defeated
	else:
		Game.state.erase("defeated")

	var saved_q1: Variant = Game.state.get("q1", null)
	var had_q1 := Game.state.has("q1")
	var saved_q2: Variant = Game.state.get("q2", null)
	var had_q2 := Game.state.has("q2")
	var saved_q3: Variant = Game.state.get("q3", null)
	var had_q3 := Game.state.has("q3")
	Game.state["q1"] = "done"
	Game.state["q2"] = "not_started"
	Game.state["q3"] = "not_started"
	Game.state["defeated"] = {}
	Game.state["brann"] = "anvil"
	var locked_route_target: Dictionary = Game.quest_target()
	check("kindling_key_routes_back_to_zal_before_q2_starts",
		str(locked_route_target.get("map", "")) == "village"
		and str(locked_route_target.get("kind", "")) == "npc")
	check("locked_peaks_gate_is_the_current_hud_objective",
		Game.objective() == Game.t("Speak with Zal", "با زال صحبت کن"), Game.objective())
	Game.state["q2"] = "active"
	var pulad_target: Dictionary = Game.quest_target()
	check("active_pulad_contract_resumes_after_zal_opens_peaks",
		str(pulad_target.get("map", "")) == "emberforge"
		and str(pulad_target.get("kind", "")) == "boss")
	check("pulad_objective_resumes_after_zal_opens_peaks",
		Game.objective() == Game.brann_objective(), Game.objective())
	Game.state["brann"] = "anvil_done"
	var turn_in_target: Dictionary = Game.quest_target()
	check("pulad_reward_turn_in_still_targets_jamshid",
		str(turn_in_target.get("map", "")) == "village"
		and str(turn_in_target.get("kind", "")) == "npc")
	Game.state["brann"] = "ignarok"
	var puladvand_target: Dictionary = Game.quest_target()
	check("active_puladvand_contract_keeps_priority_after_q2_starts",
		str(puladvand_target.get("map", "")) == "emberforge"
		and str(puladvand_target.get("kind", "")) == "boss")
	if had_q1:
		Game.state["q1"] = saved_q1
	else:
		Game.state.erase("q1")
	if had_q2:
		Game.state["q2"] = saved_q2
	else:
		Game.state.erase("q2")
	if had_q3:
		Game.state["q3"] = saved_q3
	else:
		Game.state.erase("q3")
	if had_brann:
		Game.state["brann"] = saved_brann
	else:
		Game.state.erase("brann")
	if had_defeated:
		Game.state["defeated"] = saved_defeated
	else:
		Game.state.erase("defeated")
	check("boss_arena_does_not_run_generic_route_threat_sweep", not PlayerAgent.should_clear_route_threats_before_objective("emberforge", "emberforge", "boss"))
	check("anvilward_reward_return_does_not_chase_forge_adds",
		not PlayerAgent.should_clear_route_threats_before_objective("emberforge", "village", "npc", "anvil_done"))
	check("anvilward_reward_return_defers_peaks_adds",
		not PlayerAgent.should_clear_route_threats_before_objective("peaks", "village", "npc", "anvil_done"))
	check("anvilward_reward_return_defers_forest_adds",
		not PlayerAgent.should_clear_route_threats_before_objective("forest", "village", "npc", "anvil_done"))
	check("puladvand_reward_return_uses_same_safe_turn_in_route",
		not PlayerAgent.should_clear_route_threats_before_objective("peaks", "village", "npc", "ignarok_done"))
	check("ordinary_village_npc_route_still_clears_threats",
		PlayerAgent.should_clear_route_threats_before_objective("forest", "village", "npc", "none"))
	check("boss_objective_keeps_route_clearance_on_intermediate_maps", PlayerAgent.should_clear_route_threats_before_objective("peaks", "emberforge", "boss"))
	check("ordinary_objective_travel_keeps_route_clearance", PlayerAgent.should_clear_route_threats_before_objective("forest", "peaks", "exit"))
	check("route_threat_at_player_position_is_engaged", PlayerAgent.should_engage_route_threat(0.0))
	check("near_route_threat_is_engaged", PlayerAgent.should_engage_route_threat(180.0))
	check("route_threat_at_radius_boundary_is_engaged", PlayerAgent.should_engage_route_threat(420.0))
	check("route_threat_outside_radius_is_not_engaged", not PlayerAgent.should_engage_route_threat(420.1))
	check("negative_route_distance_is_invalid", not PlayerAgent.should_engage_route_threat(-1.0))

	var forge_exit := [{ "x": 520.0, "y": 790.0, "w": 110.0, "h": 16.0, "to": "emberforge" }]
	check("enemy_on_forge_threshold_is_deferred_to_exit_travel",
		PlayerAgent.should_skip_route_threat_near_exit(Vector2(575, 798), forge_exit))
	check("enemy_inside_forge_exit_safety_margin_is_deferred",
		PlayerAgent.should_skip_route_threat_near_exit(Vector2(700, 798), forge_exit))
	check("peaks_imp_spawn_path_is_deferred_from_forge_exit",
		PlayerAgent.should_skip_route_threat_near_exit(Vector2(360, 620), forge_exit))

	check("second_peaks_imp_chase_path_crossing_forge_exit_is_deferred",
		PlayerAgent.should_skip_route_path_near_exit(Vector2(200, 850), Vector2(850, 650), forge_exit))
	check("peaks_spawn_to_second_imp_route_is_deferred",
		PlayerAgent.should_skip_route_path_near_exit(Vector2(560, 856), Vector2(850, 650), forge_exit))
	check("route_far_from_forge_exit_remains_engageable",
		not PlayerAgent.should_skip_route_path_near_exit(Vector2(180, 200), Vector2(250, 280), forge_exit))

	var forest_exit := [{ "x": 880.0, "y": 300.0, "w": 20.0, "h": 80.0, "to": "peaks" }]
	var unrelated_exits: Array = forest_exit + forge_exit
	check("forest_keeps_normal_enemy_clearance_near_its_exits",
		PlayerAgent.route_exit_safety_candidates("forest", unrelated_exits).is_empty())
	var peaks_safety_exits: Array = PlayerAgent.route_exit_safety_candidates("peaks", unrelated_exits)
	check("peaks_only_defers_the_emberforge_exit",
		peaks_safety_exits.size() == 1 and str(peaks_safety_exits[0].get("to", "")) == "emberforge")
	check("enemy_outside_forge_exit_safety_margin_remains_engageable",
		not PlayerAgent.should_skip_route_threat_near_exit(Vector2(575, 1000), forge_exit))
	check("empty_exit_list_does_not_hide_route_threats",
		not PlayerAgent.should_skip_route_threat_near_exit(Vector2(575, 798), []))
	check("visual_target_prefers_a_confident_visible_boss", PlayerBrain.choose_visual_target([
		{"label": "enemy", "visible": true, "confidence": 0.9, "distance": 45.0},
		{"label": "boss", "visible": true, "confidence": 0.7, "distance": 180.0}
	]) == 1)
	check("visual_target_ignores_low_confidence_candidates", PlayerBrain.choose_visual_target([
		{"label": "boss", "visible": true, "confidence": 0.4, "distance": 20.0},
		{"label": "enemy", "visible": true, "confidence": 0.9, "distance": 80.0}
	]) == 1)
	check("visual_target_does_not_guess_unknown_actor_labels", PlayerBrain.choose_visual_target([
		{"label": "unknown", "visible": true, "confidence": 0.95, "distance": 10.0}
	]) == -1)
	check("visual_dodge_escapes_away_from_confident_warning", PlayerBrain.visual_dodge_direction(
		Rect2(100, 100, 24, 32),
		[{"rect": Rect2(40, 100, 30, 30), "confidence": 0.9}]
	).x > 0.9)
	check("visual_dodge_refuses_low_confidence_warning", PlayerBrain.visual_dodge_direction(
		Rect2(100, 100, 24, 32),
		[{"rect": Rect2(40, 100, 30, 30), "confidence": 0.2}]
	) == Vector2.ZERO)
	check("visual_dodge_refuses_unknown_player_bounds", PlayerBrain.visual_dodge_direction(
		Rect2(), [{"rect": Rect2(40, 100, 30, 30), "confidence": 0.9}]
	) == Vector2.ZERO)

	var memory := PlayerMemory.new()
	var visible_observation := {
		"texts": [{"text": "Anvilward", "kind": "text"}, {"text": "Potion ۳", "kind": "text"}],
		"panels": ["combat"],
		"meters": {"HealthMeter": 0.45, "StaminaMeter": 0.7, "ManaMeter": 0.8},
		"resources": {"potions_text": "۳"},
		"vision": {"warnings": [{"kind": "warm_telegraph_candidate"}]}
	}
	var memory_observation_result: Dictionary = {}
	for observation_index in PlayerMemory.STAGNATION_SAMPLE_COUNT:
		memory_observation_result = memory.observe(visible_observation)
	check("player_memory_detects_repeated_unchanged_visible_state",
		bool(memory_observation_result.get("stagnant", false))
		and int(memory_observation_result.get("repeat_count", 0)) >= PlayerMemory.STAGNATION_SAMPLE_COUNT)
	var first_action_failure: Dictionary = memory.record_action("ui_tap:/root/Shop/Buy", false, "button did not activate")
	var second_action_failure: Dictionary = memory.record_action("ui_tap:/root/Shop/Buy", false, "button still did not activate")
	check("player_memory_waits_for_repeated_failure_before_replanning",
		str(first_action_failure.get("recovery_hint", "")).is_empty()
		and str(second_action_failure.get("recovery_hint", "")) == "reobserve_controls")
	memory.record_action("ui_tap:/root/Shop/Buy", true, "button activated")
	check("player_memory_clears_action_failure_after_verified_success",
		int(memory.record_action("ui_tap:/root/Shop/Buy", false, "later unrelated failure").get("failure_count", 0)) == 1)
	var anvilward_death: Dictionary = memory.record_combat({
		"encounter": "anvilward",
		"hero_class": "mage",
		"boss_hp_before": 100.0,
		"boss_hp_after": 18.0,
		"player_alive": false,
		"boss_defeated": false,
		"hits_landed": 3,
		"swings": 10,
		"damage_taken": 206.0,
		"duration_sec": 113.5
	})
	check("player_memory_classifies_boss_damage_without_player_survival_as_failure",
		str(anvilward_death.get("status", "")) == "survival_failure"
		and str(anvilward_death.get("hint", "")) == "survival_priority")
	check("player_memory_exposes_learned_survival_hint",
		memory.combat_hint("anvilward") == "survival_priority")
	var no_contact: Dictionary = memory.record_combat({
		"encounter": "matriarch",
		"hero_class": "mage",
		"boss_hp_before": 100.0,
		"boss_hp_after": 100.0,
		"player_alive": true,
		"boss_defeated": false,
		"hits_landed": 0,
		"swings": 0,
		"damage_taken": 12.0,
		"duration_sec": 15.0
	})
	check("player_memory_turns_zero_contact_into_reposition_recommendation",
		str(no_contact.get("status", "")) == "no_boss_damage"
		and str(no_contact.get("hint", "")) == "reposition_and_reacquire")
	check("player_memory_retains_a_separate_hint_per_encounter",
		memory.combat_hint("matriarch") == "reposition_and_reacquire"
		and memory.combat_hint("anvilward") == "survival_priority")
	var successful_boss: Dictionary = memory.record_combat({
		"encounter": "anvilward",
		"hero_class": "mage",
		"boss_hp_before": 18.0,
		"boss_hp_after": 0.0,
		"player_alive": true,
		"boss_defeated": true,
		"hits_landed": 5,
		"swings": 8,
		"damage_taken": 30.0,
		"duration_sec": 35.0
	})
	check("player_memory_stops_retry_adaptation_after_confirmed_boss_victory",
		str(successful_boss.get("status", "")) == "victory"
		and memory.combat_hint("anvilward") == "encounter_complete")
	var memory_report := memory.summary()
	check("player_memory_emits_bounded_evidence_summary",
		int(memory_report.get("observations", 0)) <= PlayerMemory.MAX_OBSERVATIONS
		and int(memory_report.get("combat_samples", 0)) == 3
		and int(memory_report.get("actions", 0)) >= 3)
	var memory_source := FileAccess.get_file_as_string("res://tests/player_memory.gd")
	check("player_memory_cannot_read_hidden_game_or_world_state",
		not memory_source.contains("Game.")
		and not memory_source.contains("get_nodes_in_group")
		and not memory_source.contains("quest_target"))

	print("PLAYERAGENTPOLICYTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit(1 if not fails.is_empty() else 0)

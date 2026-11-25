extends Node
## Regression checks for the real-player agent's Arzhang pillar decision.
## A player should break all but one active grave pillar to avoid triggering another wave.

const PlayerAgent = preload("res://tests/player_agent.gd")
const PlayerBrain = preload("res://tests/player_brain.gd")
const PlayerObservation = preload("res://tests/player_observation.gd")

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
	var captured_screen := PlayerObservation.capture(self, _main.get_viewport())
	var saw_visible := false
	var saw_hidden := false
	for item in captured_screen.get("buttons", []):
		var label := str(item.get("text", ""))
		saw_visible = saw_visible or label == "PLAYER_OBSERVATION_VISIBLE_SENTINEL"
		saw_hidden = saw_hidden or label == "PLAYER_OBSERVATION_HIDDEN_SENTINEL"
	check("screen_observer_captures_visible_buttons", saw_visible)
	check("screen_observer_ignores_hidden_buttons", not saw_hidden)
	test_layer.free()

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
	print("PLAYERAGENTPOLICYTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit(1 if not fails.is_empty() else 0)

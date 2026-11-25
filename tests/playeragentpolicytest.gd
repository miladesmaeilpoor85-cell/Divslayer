extends Node
## Regression checks for the real-player agent's Arzhang pillar decision.
## A player should break all but one active grave pillar to avoid triggering another wave.

const PlayerAgent = preload("res://tests/player_agent.gd")

var results: Dictionary = {}
var fails: Array[String] = []

func check(label: String, ok: bool, info = null) -> void:
	results[label] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(label)
	printerr(("PASS " if ok else "FAIL ") + label + ("" if info == null else "  " + str(info)))

func run(_main: Node) -> void:
	check("no_pillars_do_not_trigger_pillar_chase", not PlayerAgent.should_prioritize_grave_pillars(0))
	check("leave_one_pillar_as_low_shield_anchor", not PlayerAgent.should_prioritize_grave_pillars(1))
	check("break_second_pillar_before_engaging_boss", PlayerAgent.should_prioritize_grave_pillars(2))
	check("break_two_of_three_pillars", PlayerAgent.should_prioritize_grave_pillars(3))
	check("break_three_of_four_pillars", PlayerAgent.should_prioritize_grave_pillars(4))
	check("invalid_negative_count_is_not_a_target", not PlayerAgent.should_prioritize_grave_pillars(-1))

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

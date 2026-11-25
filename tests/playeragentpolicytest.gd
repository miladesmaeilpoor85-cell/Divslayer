extends Node
## Regression checks for the real-player agent's Arzhang pillar decision.
## A player should break all but one active grave pillar to avoid triggering another wave.

const PlayerAgent = preload("res://tests/player_agent.gd")

var results: Dictionary = {}
var fails: Array[String] = []

func check(label: String, ok: bool) -> void:
	results[label] = ok
	if not ok:
		fails.append(label)
	printerr(("PASS " if ok else "FAIL ") + label)

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
	var pulad_target: Dictionary = Game.quest_target()
	check("active_pulad_contract_preempts_next_chapter_elder_target",
		str(pulad_target.get("map", "")) == "emberforge"
		and str(pulad_target.get("kind", "")) == "boss")
	Game.state["brann"] = "ignarok"
	var puladvand_target: Dictionary = Game.quest_target()
	check("active_puladvand_contract_preempts_next_chapter_elder_target",
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
	check("route_threat_at_player_position_is_engaged", PlayerAgent.should_engage_route_threat(0.0))
	check("near_route_threat_is_engaged", PlayerAgent.should_engage_route_threat(180.0))
	check("route_threat_at_radius_boundary_is_engaged", PlayerAgent.should_engage_route_threat(420.0))
	check("route_threat_outside_radius_is_not_engaged", not PlayerAgent.should_engage_route_threat(420.1))
	check("negative_route_distance_is_invalid", not PlayerAgent.should_engage_route_threat(-1.0))
	print("PLAYERAGENTPOLICYTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

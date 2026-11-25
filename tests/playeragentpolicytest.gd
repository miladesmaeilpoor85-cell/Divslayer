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
	print("PLAYERAGENTPOLICYTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

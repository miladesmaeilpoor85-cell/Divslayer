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
	print("PLAYERAGENTPOLICYTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

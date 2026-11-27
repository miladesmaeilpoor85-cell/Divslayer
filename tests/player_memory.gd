extends RefCounted
## Short-lived episodic memory for one natural-player run.
## It stores only visible observations and explicit outcomes supplied by the QA harness.
## It never reads Game state, world nodes, enemy instances, or quest internals.

const MAX_OBSERVATIONS := 24
const MAX_ACTIONS := 48
const MAX_ENCOUNTERS_PER_BOSS := 8
const STAGNATION_SAMPLE_COUNT := 4
const ACTION_FAILURE_THRESHOLD := 2

var _observations: Array[Dictionary] = []
var _actions: Array[Dictionary] = []
var _action_failures: Dictionary = {}
var _encounters: Dictionary = {}
var _last_fingerprint := ""
var _repeated_observations := 0

func observe(observation: Dictionary) -> Dictionary:
	var visible_texts: Array[String] = []
	for item in observation.get("texts", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var value := str(item.get("text", "")).strip_edges()
		if not value.is_empty():
			visible_texts.append(value)
	var panels: Array[String] = []
	for value in observation.get("panels", []):
		var panel := str(value).strip_edges().to_lower()
		if not panel.is_empty() and not panels.has(panel):
			panels.append(panel)
	var meters: Dictionary = observation.get("meters", {})
	var resources: Dictionary = observation.get("resources", {})
	var vision: Dictionary = observation.get("vision", {})
	var warnings: Array[String] = []
	for warning in vision.get("warnings", []):
		if typeof(warning) == TYPE_DICTIONARY:
			var kind := str(warning.get("kind", "")).strip_edges()
			if not kind.is_empty() and not warnings.has(kind):
				warnings.append(kind)
	var compact := {
		"texts": visible_texts,
		"panels": panels,
		"health": _bucket(float(meters.get("HealthMeter", -1.0))),
		"stamina": _bucket(float(meters.get("StaminaMeter", -1.0))),
		"mana": _bucket(float(meters.get("ManaMeter", -1.0))),
		"potions": str(resources.get("potions_text", "")),
		"warnings": warnings
	}
	var fingerprint := JSON.stringify(compact)
	if fingerprint == _last_fingerprint:
		_repeated_observations += 1
	else:
		_last_fingerprint = fingerprint
		_repeated_observations = 1
	_observations.append({
		"at_msec": Time.get_ticks_msec(),
		"fingerprint": fingerprint,
		"panels": panels,
		"warning_kinds": warnings
	})
	while _observations.size() > MAX_OBSERVATIONS:
		_observations.pop_front()
	return {
		"sampled": true,
		"repeat_count": _repeated_observations,
		"stagnant": _repeated_observations >= STAGNATION_SAMPLE_COUNT
	}

func record_action(action_key: String, succeeded: bool, outcome: String = "", context: Dictionary = {}) -> Dictionary:
	var key := action_key.strip_edges().to_lower()
	if key.is_empty():
		return {"recorded": false, "failure_count": 0, "recovery_hint": ""}
	var failures := int(_action_failures.get(key, 0))
	if succeeded:
		_action_failures.erase(key)
		failures = 0
	else:
		failures += 1
		_action_failures[key] = failures
	_actions.append({
		"at_msec": Time.get_ticks_msec(),
		"action": key,
		"success": succeeded,
		"outcome": outcome.substr(0, 240),
		"context": context.duplicate(true)
	})
	while _actions.size() > MAX_ACTIONS:
		_actions.pop_front()
	var hint := _action_recovery_hint(key) if failures >= ACTION_FAILURE_THRESHOLD else ""
	return {
		"recorded": true,
		"failure_count": failures,
		"recovery_hint": hint,
		"action": key
	}

func record_combat(sample: Dictionary) -> Dictionary:
	var encounter := str(sample.get("encounter", "")).strip_edges().to_lower()
	if encounter.is_empty():
		return {"recorded": false, "status": "ignored", "hint": "continue"}
	var hp_before := clampf(float(sample.get("boss_hp_before", 100.0)), 0.0, 100.0)
	var hp_after := clampf(float(sample.get("boss_hp_after", hp_before)), 0.0, 100.0)
	var boss_damage := maxf(0.0, hp_before - hp_after)
	var hits := maxi(0, int(sample.get("hits_landed", 0)))
	var swings := maxi(0, int(sample.get("swings", 0)))
	var alive := bool(sample.get("player_alive", true))
	var defeated := bool(sample.get("boss_defeated", false))
	var status := "progress"
	var hint := "continue_pressure"
	if defeated:
		status = "victory"
		hint = "encounter_complete"
	elif not alive:
		status = "survival_failure"
		hint = "survival_priority"
	elif boss_damage <= 0.1:
		status = "no_boss_damage"
		hint = "reposition_and_reacquire" if hits == 0 else "inspect_target_window"
	elif hits == 0:
		status = "damage_without_registered_hits"
		hint = "verify_combat_evidence"
	var entry := {
		"at_msec": Time.get_ticks_msec(),
		"hero_class": str(sample.get("hero_class", "unknown")),
		"status": status,
		"hint": hint,
		"boss_hp_before": hp_before,
		"boss_hp_after": hp_after,
		"boss_damage": boss_damage,
		"hits_landed": hits,
		"swings": swings,
		"damage_taken": maxf(0.0, float(sample.get("damage_taken", 0.0))),
		"duration_sec": maxf(0.0, float(sample.get("duration_sec", 0.0))),
		"player_alive": alive,
		"boss_defeated": defeated
	}
	var history: Array = _encounters.get(encounter, [])
	history.append(entry)
	while history.size() > MAX_ENCOUNTERS_PER_BOSS:
		history.pop_front()
	_encounters[encounter] = history
	return {
		"recorded": true,
		"encounter": encounter,
		"status": status,
		"hint": hint,
		"boss_damage": boss_damage,
		"hits_landed": hits
	}

func combat_hint(encounter: String) -> String:
	var key := encounter.strip_edges().to_lower()
	var history: Array = _encounters.get(key, [])
	if history.is_empty():
		return "continue"
	return str(history[history.size() - 1].get("hint", "continue"))

func summary() -> Dictionary:
	var encounter_count := 0
	for history in _encounters.values():
		encounter_count += history.size()
	return {
		"observations": _observations.size(),
		"actions": _actions.size(),
		"action_failure_keys": _action_failures.size(),
		"combat_samples": encounter_count,
		"encounters": _encounters.keys(),
		"repeated_observation_count": _repeated_observations
	}

func _bucket(value: float) -> int:
	if value < 0.0:
		return -1
	return int(round(clampf(value, 0.0, 1.0) * 20.0))

func _action_recovery_hint(key: String) -> String:
	if key.begins_with("ui_tap:") or key.begins_with("dialogue:"):
		return "reobserve_controls"
	if key.contains("route") or key.contains("navigate"):
		return "replan_route"
	if key.contains("cast") or key.contains("spell"):
		return "reposition_casting_lane"
	if key.contains("attack") or key.contains("target"):
		return "change_target_or_range"
	return "choose_alternative"

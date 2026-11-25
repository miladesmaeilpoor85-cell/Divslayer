extends RefCounted
## Pure player decisions from visible button observations.
## Keep this file independent of Godot game state and world/runtime objects.

static func find_visible_button(buttons: Array, preferred_terms: Array, fallback_to_first_enabled := false) -> int:
	for term_value in preferred_terms:
		var term := str(term_value).strip_edges().to_lower()
		if term.is_empty():
			continue
		for index in buttons.size():
			var item: Variant = buttons[index]
			if typeof(item) != TYPE_DICTIONARY:
				continue
			if not bool(item.get("visible", false)) or not bool(item.get("enabled", false)):
				continue
			var label := str(item.get("text", "")).strip_edges().to_lower()
			if not label.is_empty() and label.contains(term):
				return index
	if fallback_to_first_enabled:
		for index in buttons.size():
			var item: Variant = buttons[index]
			if typeof(item) == TYPE_DICTIONARY and bool(item.get("visible", false)) and bool(item.get("enabled", false)):
				return index
	return -1

static func find_death_recovery_button(buttons: Array) -> int:
	# The game offers this visible option only after the player has already failed
	# a rematch. Treat it as a clear recovery hint and adapt rather than repeat blindly.
	var adaptive_difficulty := find_visible_button(buttons, [
		"story difficulty", "سختی را", "داستانی"
	])
	if adaptive_difficulty >= 0:
		return adaptive_difficulty
	var rematch := find_visible_button(buttons, [
		"rematch", "retry", "try again", "دوباره", "تلاش مجدد", "شروع دوباره"
	])
	if rematch >= 0:
		return rematch
	return find_visible_button(buttons, [
		"respawn", "return to zabol", "return", "home", "بازگشت", "بازگشت به زابل", "ادامه", "زنده شدن"
	])


## Parse only the resource values rendered by the HUD. Missing values stay unknown.
static func read_visible_combat_status(observation: Dictionary) -> Dictionary:
	var meters: Dictionary = observation.get("meters", {})
	var resources: Dictionary = observation.get("resources", {})
	var result := {
		"health_ratio": float(meters.get("HealthMeter", -1.0)),
		"stamina_ratio": float(meters.get("StaminaMeter", -1.0)),
		"mana_ratio": float(meters.get("ManaMeter", -1.0)),
		"potions": -1
	}
	var raw := str(resources.get("potions_text", "")).strip_edges()
	if not raw.is_empty():
		var normalized := raw
		var persian := ["۰","۱","۲","۳","۴","۵","۶","۷","۸","۹"]
		var arabic := ["٠","١","٢","٣","٤","٥","٦","٧","٨","٩"]
		for i in 10:
			normalized = normalized.replace(persian[i], str(i)).replace(arabic[i], str(i))
		var digits := ""
		for character in normalized:
			if character >= "0" and character <= "9":
				digits += character
			elif not digits.is_empty():
				break
		if not digits.is_empty():
			result["potions"] = int(digits)
	return result

static func should_use_visible_potion(status: Dictionary, reserve: int, threshold: float) -> bool:
	var hp := float(status.get("health_ratio", -1.0))
	var stock := int(status.get("potions", -1))
	return hp >= 0.0 and stock > maxi(0, reserve) and hp <= clampf(threshold, 0.05, 0.95)

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
	var rematch := find_visible_button(buttons, [
		"rematch", "retry", "try again", "دوباره", "تلاش مجدد", "شروع دوباره"
	])
	if rematch >= 0:
		return rematch
	return find_visible_button(buttons, [
		"respawn", "return to zabol", "return", "home", "بازگشت", "بازگشت به زابل", "ادامه"
	])

extends RefCounted
## A player-facing decision layer for touch-input QA.
## It never edits Game.state, grants currency, teleports the hero, or applies test presets.
## All menu/shop/talent actions are delivered as screen touches through the existing playtest driver.

var driver: Node

const TALENT_ORDER := {
	"warrior": ["vit1", "str1", "swift"],
	"mage": ["vit1", "str1", "swift"],
	"rogue": ["swift", "vit1", "str1"],
	"paladin": ["vit1", "swift", "str1"],
}

func attach(playtest_driver: Node) -> void:
	driver = playtest_driver

func _first_button(node: Node) -> Button:
	if node is Button and (node as Button).is_visible_in_tree():
		return node as Button
	for child in node.get_children():
		var found := _first_button(child)
		if found != null:
			return found
	return null

func _mouse_tap(window_point: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = window_point
	down.pressed = true
	Input.parse_input_event(down)
	await driver.frames(4)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = window_point
	up.pressed = false
	Input.parse_input_event(up)
	await driver.frames(4)

func _tap_control(control: Control) -> bool:
	if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
		return false
	# Give Container-based menus one layout pass before computing the touch target.
	await driver.frames(2)
	var canvas_point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	var window_point: Vector2 = driver._win(canvas_point)
	var button := _first_button(control)
	var signal_state := {"pressed": false}
	var callback := func(): signal_state["pressed"] = true
	if button != null:
		button.pressed.connect(callback)
	await driver.tap(window_point)
	await driver.wait(0.12)
	if button != null and not bool(signal_state["pressed"]):
		# Xvfb does not always map ScreenTouch to standard desktop Button controls.
		# Fall back to a mouse click at the same visible control centre, then verify
		# that the real Button.pressed signal fired.
		await _mouse_tap(window_point)
	if button != null:
		if is_instance_valid(button) and button.pressed.is_connected(callback):
			button.pressed.disconnect(callback)
		await driver.wait(0.15)
		return bool(signal_state["pressed"])
	await driver.wait(0.15)
	return true

func _named_control(wanted: String) -> Control:
	for node in driver._all(driver.get_tree().root):
		if node is Control and str(node.name) == wanted and (node as Control).is_visible_in_tree():
			return node as Control
	return null

func _tap_text(label: String) -> bool:
	var control: Control = driver.find_text(label)
	return await _tap_control(control)

func _open_pause() -> bool:
	var hud = driver.main.hud
	if hud.pause.visible:
		return true
	if not await _tap_control(hud.menu_btn):
		return false
	return hud.pause.visible

func _close_pause() -> void:
	if driver.main.hud.pause.visible:
		var resume := Game.t("Resume", "ادامهٔ بازی")
		if not await _tap_text(resume):
			driver._log("PLAYER_AGENT_RESUME_BUTTON_NOT_FOUND")
		await driver.wait(0.35)

func _training_warning() -> Dictionary:
	var world = driver.main.world
	if world == null or world.bossfx == null:
		return {}
	# Rostam's warning is drawn as a visible orange circle. Observe the same live
	# warning a player sees; the tutorial counter is only used to confirm the drill advances.
	for warning in world.bossfx.tele:
		if str(warning.get("kind", "")) == "circle" and world.bossfx.inside(warning):
			return warning
	return {}

func complete_training() -> String:
	var elapsed := 0.0
	var attempts := {}
	var actions := 0
	while elapsed < 55.0:
		var stage := Game.Tut.step()
		if stage == "done":
			driver._log("PLAYER_AGENT_TRAINING_DONE actions=%d" % actions)
			return "completed Rostam's training through touch controls (%d actions)" % actions
		if stage == "skipped" or stage == "":
			break
		var n := int(attempts.get(stage, 0))
		attempts[stage] = n + 1
		match stage:
			"strike":
				await driver.press("attack", 0.10)
				await driver.wait(0.30)
			"heavy":
				await driver.press("attack", 0.85)
				await driver.wait(0.45)
			"roll":
				# Read the visible ground marker and roll shortly before impact. A fixed blind delay
				# repeatedly dodged too early; the marker's remaining lifetime is the cue a person sees.
				var rolls_before := int(Game.Tut.st().get("rolls", 0))
				var roll_wait := 0.0
				while Game.Tut.step() == "roll" and int(Game.Tut.st().get("rolls", 0)) == rolls_before and roll_wait < 8.0:
					var warning := _training_warning()
					if warning.is_empty():
						await driver.wait(0.05)
						roll_wait += 0.05
						continue
					var eta := float(warning.get("t", 1.15))
					if eta > 0.28:
						var pause := min(eta - 0.28, 0.08)
						await driver.wait(pause)
						roll_wait += pause
						continue
					await driver.wait(randf_range(0.04, 0.07))
					await driver.press("dodge")
					await driver.wait(0.45)
					actions += 1
					roll_wait += 0.5
			"block":
				# Raise the shield after the blue warning appears and keep it held through impact.
				var block_wait := 0.0
				while Game.Tut.step() == "block" and block_wait < 8.0:
					var warning := _training_warning()
					if warning.is_empty():
						await driver.wait(0.05)
						block_wait += 0.05
						continue
					var eta := float(warning.get("t", 1.4))
					if eta > 0.5:
						var pause := min(eta - 0.5, 0.08)
						await driver.wait(pause)
						block_wait += pause
						continue
					await driver.wait(randf_range(0.04, 0.07))
					await driver.press("block", 0.65)
					await driver.wait(0.25)
					actions += 1
					block_wait += 0.9
			"spell":
				await driver.press("skill1")
				await driver.wait(0.55)
			"sig":
				await driver.press("shove")
				await driver.wait(0.55)
			_:
				break
		actions += 1
		elapsed += 0.7
		if n >= 10:
			break
	if Game.Tut.step() != "done":
		var failure := "real-player training stopped at '%s' after %d touches" % [Game.Tut.step(), actions]
		driver.assertion_failures.append(failure)
		driver._log("ASSERTION_FAILED " + failure)
		return failure
	return "completed Rostam's training through touch controls"

func tap_text(label: String) -> String:
	var control: Control = driver.find_text(label)
	if control == null:
		return "NOT FOUND. On screen: " + " | ".join(driver._texts().map(func(t): return str(t.get("t", ""))))
	if not await _tap_control(control):
		return "visible text was found but its control did not receive a tap: " + label
	return "tapped UI text through its actual control: " + label

func spend_talents() -> String:
	if Game.talent_points() <= 0:
		return "no talent points available; no menu action needed"
	if not await _open_pause():
		return "could not open the in-game pause menu"
	if not await _tap_text(Game.t("Skills", "مهارت‌ها")):
		await _close_pause()
		return "could not open Skills page through its visible tab"
	if not await _tap_text(Game.t("Talents", "استعدادها")):
		await _close_pause()
		return "could not open Talents page through its visible tab"

	var points_before := Game.talent_points()
	var gained: Array[String] = []
	var order: Array = TALENT_ORDER.get(Game.cls, TALENT_ORDER["warrior"])
	var safety := 0
	while Game.talent_points() > 0 and safety < 12:
		safety += 1
		var selected := ""
		for id in order:
			if Game.talent_block(str(id)) == "":
				selected = str(id)
				break
		if selected == "":
			break
		var rank_before := Game.talent(selected)
		var card := _named_control("Talent_" + selected)
		if card == null:
			driver._log("PLAYER_AGENT_TALENT_NOT_VISIBLE id=%s" % selected)
			break
		if not await _tap_control(card):
			break
		if Game.talent(selected) > rank_before:
			gained.append("%s:%d" % [selected, Game.talent(selected)])
			driver._log("PLAYER_AGENT_TALENT_LEARNED id=%s rank=%d points_left=%d" % [selected, Game.talent(selected), Game.talent_points()])
		else:
			driver._log("PLAYER_AGENT_TALENT_TAP_NO_CHANGE id=%s" % selected)
			break

	await _close_pause()
	var spent := points_before - Game.talent_points()
	if spent > 0:
		Game.save_game()
	return "spent %d/%d talent points through the Skills UI (%s)" % [spent, points_before, ", ".join(gained)]

func visit_shop(vendor: String) -> String:
	if vendor not in ["merchant", "smith", "hesk"]:
		return "unsupported vendor: " + vendor
	var npc: Node = driver.npc_node(vendor)
	if npc == null:
		return "no %s vendor on the current map" % vendor
	var route: String = await driver.walk_to(npc.global_position + Vector2(0, 26), 30.0, 22.0)
	await driver.wait(0.25)
	if driver.main.player.near_npc == null:
		return "could not reach %s: %s" % [vendor, route]
	await driver.press("talk")
	await driver.wait(0.5)
	var shop = driver.main.hud.shop
	if not shop.visible:
		return "talked to %s but its shop did not open" % vendor

	var catalog: Array = Game.shop_catalog(vendor)
	var selected: Dictionary = {}
	# A genuine buyer prefers the next equipment tier, but will not buy beyond the visible purse.
	for item in catalog:
		if str(item.get("state", "")) != "next" or not item.has("tier"):
			continue
		if int(Game.state.get("gold", 0)) >= int(item.get("price", 0)):
			selected = item
			break

	# If equipment is not yet affordable, keep enough gold for the next armour tier before
	# buying consumables. Refill health supplies only when the carried stock is low.
	if selected.is_empty() and vendor == "merchant" and int(Game.state.get("potions", 0)) < 2:
		var armor_next := 0
		for armor_item in Game.table("SHOPS").get("smith", {}).get("items", []):
			if armor_item.has("tier") and int(armor_item.get("tier", 0)) == int(Game.state.get("armor", 0)) + 1:
				armor_next = int(armor_item.get("price", 0))
				break
		for item in catalog:
			if str(item.get("id", "")) == "hp_potion" and int(Game.state.get("gold", 0)) >= armor_next + int(item.get("price", 0)):
				selected = item
				break
	if selected.is_empty() and vendor == "hesk" and int(Game.state.get("potions", 0)) < 2:
		for item in catalog:
			if str(item.get("id", "")) == "greater_potion" and int(Game.state.get("gold", 0)) >= int(item.get("price", 0)):
				selected = item
				break

	if selected.is_empty():
		var purse := int(Game.state.get("gold", 0))
		var weapon := int(Game.state.get("weapon", 0))
		var armor := int(Game.state.get("armor", 0))
		await _tap_control(shop.close_btn)
		return "no sensible purchase: purse=%d weapon_tier=%d armour_tier=%d; saved currency" % [purse, weapon, armor]

	var item_name := Game.t(str(selected.get("name", "")))
	var old_weapon := int(Game.state.get("weapon", 0))
	var old_armor := int(Game.state.get("armor", 0))
	var old_potions := int(Game.state.get("potions", 0))
	if not await _tap_text(item_name):
		await _tap_control(shop.close_btn)
		return "visible shop item was not tappable: " + item_name
	if selected.has("tier"):
		# Weapon and armour cards intentionally require two taps in the real shop UI.
		await driver.wait(0.3)
		if not await _tap_text(item_name):
			await _tap_control(shop.close_btn)
			return "second confirmation tap failed for " + item_name
	await driver.wait(0.4)

	var bought := false
	if vendor == "merchant" and selected.has("tier"):
		bought = int(Game.state.get("weapon", 0)) > old_weapon
	elif vendor == "smith" and selected.has("tier"):
		bought = int(Game.state.get("armor", 0)) > old_armor
	elif str(selected.get("id", "")) == "hp_potion":
		bought = int(Game.state.get("potions", 0)) > old_potions
	elif str(selected.get("id", "")) == "greater_potion":
		bought = int(Game.state.get("greater", 0)) > 0

	var purse_after := int(Game.state.get("gold", 0))
	await _tap_control(shop.close_btn)
	if bought:
		Game.save_game()
		return "purchased %s through the shop UI; gold now %d" % [item_name, purse_after]
	return "purchase did not register for %s; gold now %d" % [item_name, purse_after]

func _gear_score(item: Dictionary) -> float:
	var stat: Dictionary = item.get("stat", {})
	var value := float(stat.get("val", 0.0))
	match str(stat.get("key", "")):
		"atk": return value * 3.0
		"def": return value * 1.7
		"hpMax": return value * 0.16
		"mpMax": return value * 0.08
		"crit": return value * 22.0
		"critDmg": return value * 12.0
		"dodgeBonus": return value * 28.0
		"dashCd": return value * 30.0
		"lifesteal": return value * 24.0
		"haste": return value * 22.0
		"xp": return value * 5.0
		"gold": return value * 4.0
	return value

func equip_best_accessory() -> String:
	var worn_before: Dictionary = {}
	for slot in Game.Gear.SLOTS:
		worn_before[slot] = Game.Gear.eq().get(slot, null)
	var equipped: Array[String] = []
	var guard := 0
	while guard < 4:
		guard += 1
		var best_index := -1
		var best_gain := 0.01
		var bag: Array = Game.Gear.bag()
		for i in bag.size():
			var item: Dictionary = bag[i]
			var slot := str(item.get("slot", ""))
			if slot not in Game.Gear.SLOTS:
				continue
			var current: Dictionary = Game.Gear.eq().get(slot, {})
			var gain := _gear_score(item) - _gear_score(current)
			if gain > best_gain:
				best_gain = gain
				best_index = i
		if best_index < 0:
			break
		if not await _open_pause():
			return "could not open menu to inspect accessory bag"
		if not await _tap_text(Game.t("Gear", "تجهیزات")):
			await _close_pause()
			return "could not open Gear page"
		var control := _named_control("Wear_%d" % best_index)
		if control == null or not await _tap_control(control):
			await _close_pause()
			return "better accessory was not visible or tappable"
		await driver.wait(0.25)
		var after: Dictionary = Game.Gear.eq()
		var slot_after := str(after.keys()[0]) if not after.is_empty() else ""
		if Game.Gear.bag().size() < bag.size():
			equipped.append("bag-index-%d" % best_index)
		else:
			break
	await _close_pause()
	var changed: Array[String] = []
	for slot in Game.Gear.SLOTS:
		var before = worn_before.get(slot, null)
		var after = Game.Gear.eq().get(slot, null)
		if before != after:
			changed.append("%s:%s" % [slot, Game.Gear.item_name(after) if typeof(after) == TYPE_DICTIONARY else "empty"])
	if changed.is_empty():
		return "kept current accessories; no bag item had a better stat score"
	Game.save_game()
	driver._log("PLAYER_AGENT_ACCESSORIES_EQUIPPED %s" % ", ".join(changed))
	return "equipped better accessories from the bag: " + ", ".join(changed)

func bind_adaptive_spells() -> String:
	var priorities: Dictionary = {
		"warrior": ["roar", "nova", "quake", "bolt", "mend"],
		"mage": ["icelance", "chain", "firewall", "nova", "bolt", "mend"],
		"rogue": ["blink", "drain", "bolt", "nova", "mend"],
		"paladin": ["mend", "roar", "nova", "quake", "bolt"],
	}
	var preferred: Array = priorities.get(Game.cls, priorities["warrior"])
	var chosen: Array[String] = []
	for id in preferred:
		if Game.Skills.known(str(id)) and not chosen.has(str(id)):
			chosen.append(str(id))
			if chosen.size() == 2:
				break
	if chosen.size() < 2:
		for id in Game.Skills.ORDER:
			if Game.Skills.known(str(id)) and not chosen.has(str(id)):
				chosen.append(str(id))
				if chosen.size() == 2:
					break
	if chosen.size() < 2:
		return "only %d known spells; kept current bindings" % chosen.size()
	if not await _open_pause():
		return "could not open Skills menu to bind spells"
	if not await _tap_text(Game.t("Skills", "مهارت‌ها")):
		await _close_pause()
		return "could not open Skills page"
	var before: Array = Game.slots().duplicate()
	for slot_index in 2:
		var id := chosen[slot_index]
		if str(Game.slots()[slot_index]) == id:
			continue
		var button := _named_control("Bind%d_%s" % [slot_index, id])
		if button == null or not await _tap_control(button):
			driver._log("PLAYER_AGENT_SPELL_BIND_UNAVAILABLE slot=%d spell=%s" % [slot_index, id])
			continue
		await driver.wait(0.2)
	var after: Array = Game.slots().duplicate()
	await _close_pause()
	if after != before:
		Game.save_game()
		driver._log("PLAYER_AGENT_SPELLS_BOUND before=%s after=%s" % [str(before), str(after)])
	return "spell bindings: %s -> %s" % [str(before), str(after)]

func collect_nearby_pickups(max_items := 8) -> String:
	var collected: Array[String] = []
	var skipped := 0
	for attempt in max_items:
		var nearest: Node2D = null
		var best := INF
		for node in driver.get_tree().get_nodes_in_group("pickups"):
			if not is_instance_valid(node) or node.get_parent() == null:
				continue
			if not driver.main.world.ysort.is_ancestor_of(node):
				continue
			var distance: float = driver._feet().distance_to(node.global_position)
			if distance < best:
				best = distance
				nearest = node
		if nearest == null:
			break
		var pickup_kind := str(nearest.get_meta("kind", "unknown"))
		var pickup_key := str(nearest.get_meta("key", ""))
		var before_count := Game.state.get("picked", []).size()
		var route: String = await driver.walk_to(nearest.global_position, 22.0, 16.0)
		await driver.wait(0.35)
		var taken := not is_instance_valid(nearest) or not driver.get_tree().get_nodes_in_group("pickups").has(nearest)
		var after_count := Game.state.get("picked", []).size()
		if taken or after_count > before_count or pickup_key in Game.state.get("picked", []):
			collected.append(pickup_kind)
			driver._log("PLAYER_AGENT_PICKUP kind=%s key=%s route=%s" % [pickup_kind, pickup_key, route])
		else:
			skipped += 1
			if skipped >= 2:
				break
			# Avoid getting stuck repeatedly targeting the same unreachable object.
			if best > 260.0:
				break
			await driver.wait(0.2)
	return "collected %d ground pickups%s" % [collected.size(), " (" + ", ".join(collected) + ")" if not collected.is_empty() else ""]

func _choose_dialogue_option() -> String:
	var dialogue = driver.main.hud.dialogue
	if dialogue == null or not dialogue.visible or not dialogue.choosing():
		return "no dialogue choice pending"
	var preferred := ["Train with me", "با من تمرین کن", "Continue", "ادامه", "Accept", "قبول", "Enter", "ورود", "Take", "بگیر", "Begin", "شروع", "Investigate", "بررسی"]
	var buttons: Array = dialogue._choice_box.get_children()
	var picked: Button = null
	for term in preferred:
		for control in buttons:
			if control is Button and (control as Button).is_visible_in_tree() and str((control as Button).text).find(term) >= 0:
				picked = control as Button
				break
		if picked != null:
			break
	if picked == null:
		for control in buttons:
			if control is Button and not (control as Button).disabled:
				picked = control as Button
				break
	if picked == null:
		return "no enabled dialogue option"
	var chosen_text := picked.text
	if not await _tap_control(picked):
		return "dialogue option failed to receive input"
	await driver.wait(0.35)
	driver._log("PLAYER_AGENT_DIALOGUE_CHOICE %s" % chosen_text)
	return "selected dialogue option: " + chosen_text

func follow_objective(max_steps := 8) -> String:
	var report: Array[String] = []
	for step_index in max_steps:
		var target: Dictionary = Game.quest_target()
		if target.is_empty():
			return "no active objective; " + " | ".join(report)
		var target_map := str(target.get("map", ""))
		var current_map := str(driver.main.world.key)
		if target_map != current_map:
			var hop := Game.next_hop(current_map, target_map)
			if hop == "":
				report.append("no world-graph route from %s to %s" % [current_map, target_map])
				break
			var exit_data: Dictionary = {}
			for exit in driver.main.world.data.get("exits", []):
				if str(exit.get("to", "")) == hop:
					exit_data = exit
					break
			if exit_data.is_empty():
				report.append("route exit to %s is not present in the current region" % hop)
				break
			var exit_center := Vector2(float(exit_data.get("x", 0)) + float(exit_data.get("w", 0)) * 0.5, float(exit_data.get("y", 0)) + float(exit_data.get("h", 0)) * 0.5)
			var route: String = await driver.walk_to(exit_center, 50.0, 6.0, hop)
			await driver.wait(0.4)
			if str(driver.main.world.key) == current_map:
				report.append("could not pass exit to %s: %s" % [hop, route])
				break
			report.append("travelled %s -> %s" % [current_map, str(driver.main.world.key)])
			continue
		var target_pos: Vector2 = target.get("pos", driver._feet())
		var kind := str(target.get("kind", ""))
		if kind == "boss":
			var boss: Node = null
			var nearest_boss := INF
			for node in driver.get_tree().get_nodes_in_group("bosses"):
				if node.world != driver.main.world or node.dead:
					continue
				var distance: float = node.global_position.distance_to(target_pos)
				if distance < nearest_boss:
					nearest_boss = distance
					boss = node
			if boss == null:
				report.append("objective boss is not spawned on %s" % current_map)
				break
			await driver.walk_to(boss.global_position, 45.0, 110.0)
			await driver.wait(0.3)
			var outcome: String = await driver.fight(75.0, 0.0, str(boss.type))
			report.append("boss %s: %s" % [str(boss.type), outcome])
			if not is_instance_valid(boss) or boss.dead:
				continue
			break
		var candidate: Node2D = null
		var distance_best := INF
		var group_name := "quest_points" if kind == "quest_point" else "npcs"
		for node in driver.get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(node) or node.get_parent() == null:
				continue
			if not driver.main.world.ysort.is_ancestor_of(node):
				continue
			var distance: float = node.global_position.distance_to(target_pos)
			if distance < distance_best:
				distance_best = distance
				candidate = node
		var goal := target_pos
		if candidate != null:
			goal = candidate.global_position + Vector2(0, 24)
		var route: String = await driver.walk_to(goal, 32.0, 20.0)
		await driver.wait(0.25)
		if kind == "npc" or kind == "quest_point":
			if driver.main.player.near_npc != null:
				await driver.press("talk")
				await driver.wait(0.35)
				if driver.main.hud.dialogue.choosing():
					report.append(await _choose_dialogue_option())
				if driver.main.hud.dialogue.visible:
					report.append(await driver.dialog_all())
				else:
					await driver.wait(0.2)
				report.append("interacted with objective on %s: %s" % [current_map, route])
			else:
				report.append("objective interaction range not reached: %s" % route)
				break
		else:
			report.append("approached objective %s: %s" % [kind, route])
			break
	return " | ".join(report)

func prepare_loadout() -> String:
	var armor_before := int(Game.state.get("armor", 0))
	var weapon_before := int(Game.state.get("weapon", 1))
	var report: Array[String] = []
	report.append(await visit_shop("merchant"))
	report.append(await visit_shop("smith"))
	report.append(await spend_talents())
	var armor_after := int(Game.state.get("armor", 0))
	var weapon_after := int(Game.state.get("weapon", 1))
	if armor_before == 0 and armor_after == 0:
		var failure := "fresh player could not buy the first armour tier through the shop UI"
		driver.assertion_failures.append(failure)
		driver._log("ASSERTION_FAILED " + failure)
	driver._log("PLAYER_AGENT_LOADOUT weapon=%d->%d armour=%d->%d gold=%d" % [weapon_before, weapon_after, armor_before, armor_after, int(Game.state.get("gold", 0))])
	return " | ".join(report)

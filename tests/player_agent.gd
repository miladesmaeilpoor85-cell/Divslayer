extends RefCounted
## A player-facing decision layer for touch-input QA.
## It never edits Game.state, grants currency, teleports the hero, or applies test presets.
## All menu/shop/talent actions are delivered as screen touches through the existing playtest driver.

const PlayerObservation = preload("res://tests/player_observation.gd")
const PlayerBrain = preload("res://tests/player_brain.gd")

var driver: Node

const TALENT_ORDER := {
	"warrior": ["vit1", "str1", "swift"],
	"mage": ["vit1", "str1", "swift"],
	"rogue": ["swift", "vit1", "str1"],
	"paladin": ["vit1", "swift", "str1"],
}

## Keep one Arzhang grave pillar alive once the shield is down to a single stack.
## This leaves the boss at 15% damage reduction and stops its repeating 17-second summon cycle.
static func should_prioritize_grave_pillars(active_pillars: int) -> bool:
	return active_pillars > 1

## A real player cannot consume the whole potion stack in successive touch frames.
## Keep a short human-use interval and respect the deliberately held reserve.
static func should_use_health_potion(hp: float, max_hp: float, stock: int, reserve: int, now: float, ready_at: float, threshold: float) -> bool:
	return max_hp > 0.0 and hp > 0.0 and stock > maxi(reserve, 0) and now >= ready_at and hp < max_hp * clampf(threshold, 0.0, 1.0)

static func next_health_potion_time(now: float, cooldown: float = 1.6) -> float:
	return now + maxf(0.5, cooldown)

## Mage dodges only to escape immediate contact or a critical close-range threat.
## Readable boss telegraphs are handled by the shared reaction policy above this branch.
static func should_dodge_mage(distance: float, hp: float, max_hp: float, stamina: float, dodge_cd: float) -> bool:
	if max_hp <= 0.0 or hp <= 0.0 or distance < 0.0 or stamina < 45.0 or dodge_cd > 0.0:
		return false
	return distance <= 52.0 or (distance <= 120.0 and hp <= max_hp * 0.42)

## Area slams, marked lanes and predicted projectiles cannot be safely tanked by a shield.
## Cones remain guardable/parryable, but circles must be rolled or stepped out of.
static func should_evade_boss_telegraph(kind: String) -> bool:
	return kind in ["circle", "lane", "projectile"]

## The roll's actual invulnerability differs by calling: Mage 0.32 s, Warrior/Paladin
## 0.42 s, Rogue 0.58 s. Start the roll late enough for those frames to cover impact.
static func boss_dodge_window(hero_class: String) -> float:
	match hero_class:
		"mage": return 0.22
		"rogue": return 0.46
		_: return 0.30

## If the roll is cooling down or stamina is short, a just-in-time guard can parry
## the marked area hit or at least reduce it. Do not spend stamina blocking early.
static func should_guard_boss_telegraph(kind: String, eta: float, roll_ready: bool, stamina: float, guard_broken: float) -> bool:
	return should_evade_boss_telegraph(kind) and eta >= 0.0 and eta <= 0.18 \
		and not roll_ready and stamina >= 8.0 and guard_broken <= 0.0

## Mage's Bolt/Chain reach allows it to fight outside Anvilward's close slam radius.
static func mage_boss_preferred_range() -> float:
	return 250.0

static func mage_boss_retreat_distance() -> float:
	return 230.0

## If the direct escape vector runs into a wall or the map edge, sidestep around it.
## Probe the player's real body rectangle; no teleporting or collision bypass is used.
static func safe_evasion_direction(body_bounds: Rect2, desired: Vector2, wall_rects: Array, probe_distance := 72.0) -> Vector2:
	if desired.length_squared() < 0.0001:
		return Vector2.ZERO
	var base := desired.normalized()
	var step := maxf(24.0, probe_distance)
	var candidates := [
		base,
		base.rotated(PI / 3.0),
		base.rotated(-PI / 3.0),
		base.rotated(PI / 2.0),
		base.rotated(-PI / 2.0),
	]
	for candidate in candidates:
		var probe := body_bounds
		probe.position += candidate * step
		var blocked := false
		for wall_data in wall_rects:
			var wall: Rect2 = wall_data
			if probe.intersects(wall):
				blocked = true
				break
		if not blocked:
			return candidate.normalized()
	return base.orthogonal()

## Prioritize only enemies that have actually noticed the player and remain inside
## their active chase envelope. Emberforge mobs acquire aggro at 270 px; squad calls
## extend that envelope to 1.65x (445.5 px). Never pull passive packs into the duel.
static func should_prioritize_focus_add(focus_type: String, enemy_type: String, is_boss: bool, distance: float, is_alerted: bool, radius: float = 240.0) -> bool:
	if is_boss or distance < 0.0 or not is_alerted:
		return false
	var pressure_radius := 445.5 if focus_type == "anvilward" else radius
	if distance > pressure_radius:
		return false
	if focus_type in ["anvilward", "boss"]:
		return true
	return focus_type == "ancientwyrm" and enemy_type == "wyrmling"

## Route combat is allowed only for nearby, reachable threats. The player must not
## run through an active pack just because the objective marker is on the far edge.
static func should_engage_route_threat(distance: float, radius: float = 420.0) -> bool:
	return distance >= 0.0 and distance <= radius

static func should_clear_route_threats_before_objective(current_map: String, target_map: String, target_kind: String, brann_state := "") -> bool:
	# After either forge boss falls, Jamshid's reward turn-in is the active objective.
	# Defer optional Emberforge/Peaks/Forest mobs while the player takes the authored
	# route back to Zabol; otherwise a nearby Moltencore can strand the player before
	# the reward interaction is reached.
	if brann_state in ["anvil_done", "ignarok_done"] and target_map == "village" and target_kind == "npc" and current_map in ["emberforge", "peaks", "forest"]:
		return false
	# The focused encounter driver handles adds while it pursues the authored boss.
	return not (current_map == target_map and target_kind == "boss")

## Reused for both map traversal and destination-boss approach so the arena policy stays explicit.

## Do not chase an enemy through a nearby exit while clearing a world-map route.
## The player can take the authored exit normally and encounter that enemy on its destination map.
static func should_skip_route_threat_near_exit(position: Vector2, exits: Array, margin: float = 180.0) -> bool:
	var safe_margin := maxf(margin, 0.0)
	for exit_data in exits:
		if typeof(exit_data) != TYPE_DICTIONARY:
			continue
		var exit_rect := Rect2(
			float(exit_data.get("x", 0.0)),
			float(exit_data.get("y", 0.0)),
			float(exit_data.get("w", 0.0)),
			float(exit_data.get("h", 0.0))
		)
		if exit_rect.grow(safe_margin).has_point(position):
			return true
	return false

## Do not chase a threat along a path that crosses the safety margin of a map exit.
## A foe may stand outside the portal margin while the shortest approach still runs through it.
## Only the Ashen Peaks -> Emberforge gate needs route-threat deferral.
## Other regions keep their normal nearby-enemy clearing before map traversal.
static func route_exit_safety_candidates(map_key: String, exits: Array) -> Array:
	if map_key != "peaks":
		return []
	var selected: Array = []
	for exit_data in exits:
		if typeof(exit_data) != TYPE_DICTIONARY:
			continue
		if str(exit_data.get("to", "")) == "emberforge":
			selected.append(exit_data)
	return selected

static func should_skip_route_path_near_exit(origin: Vector2, destination: Vector2, exits: Array, margin: float = 180.0) -> bool:
	if should_skip_route_threat_near_exit(origin, exits, margin):
		return true
	if should_skip_route_threat_near_exit(destination, exits, margin):
		return true
	var distance := origin.distance_to(destination)
	var sample_count := maxi(1, int(ceil(distance / 8.0)))
	for sample_index in range(1, sample_count):
		var sample_position := origin.lerp(destination, float(sample_index) / float(sample_count))
		if should_skip_route_threat_near_exit(sample_position, exits, margin):
			return true
	return false

func attach(playtest_driver: Node) -> void:
	driver = playtest_driver

## Capture only text and controls that are visible in the rendered viewport.
## Decisions consume this snapshot; hidden game telemetry remains in the QA driver.
func _screen_observation() -> Dictionary:
	if driver == null:
		return {}
	return PlayerObservation.capture(driver.get_tree().root, driver.get_viewport())

func _visible_screen_texts() -> Array[String]:
	var result: Array[String] = []
	var observation := _screen_observation()
	for item in observation.get("texts", []):
		var value := str(item.get("text", "")).strip_edges()
		if not value.is_empty():
			result.append(value)
	return result

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
						var pause: float = minf(eta - 0.28, 0.08)
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
						var pause: float = minf(eta - 0.5, 0.08)
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
		return "NOT FOUND. On screen: " + " | ".join(_visible_screen_texts())
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

func _tap_dialogue_choice(terms: Array) -> String:
	var observation := _screen_observation()
	var visible_buttons: Array = observation.get("buttons", [])
	var selected_index := PlayerBrain.find_visible_button(visible_buttons, terms)
	if selected_index < 0:
		var labels: Array[String] = []
		for item in visible_buttons:
			if bool(item.get("visible", false)) and bool(item.get("enabled", false)):
				labels.append(str(item.get("text", "")))
		return "matching visible choice not found; enabled choices=%s" % " | ".join(labels)
	var selected: Dictionary = visible_buttons[selected_index]
	var choice := selected.get("control") as Button
	var label := str(selected.get("text", ""))
	if choice == null or not await _tap_control(choice):
		return "visible choice could not receive a touch: " + label
	await driver.wait(0.35)
	driver._log("PLAYER_AGENT_DIALOGUE_CHOICE " + label)
	return "selected dialogue choice: " + label

func visit_shop(vendor: String, prioritize_health := false) -> String:
	if vendor not in ["merchant", "smith", "hesk"]:
		return "unsupported vendor: " + vendor
	var npc: Node = driver.npc_node(vendor)
	if npc == null:
		return "no %s vendor on the current map" % vendor
	var route: String = await driver.walk_to(npc.global_position + Vector2(0, 26), 30.0, 22.0)
	await driver.wait(0.25)
	if driver.main.player.near_npc == null:
		return "could not reach %s: %s" % [vendor, route]

	await driver.shot("shop_%s_arrival" % vendor)
	var shop = driver.main.hud.shop
	# A first conversation with Kaveh may only advance the chapter story. The shop
	# appears after the dialogue is dismissed and the player talks to him again.
	# Observe each UI state and select the visible armour choice directly; do not
	# infer success from a talk-button press alone.
	var interaction_pass := 0
	var last_observation := ""
	while not shop.visible and interaction_pass < 6:
		interaction_pass += 1
		var dialogue = driver.main.hud.dialogue
		var visible_texts: Array[String] = []
		visible_texts = _visible_screen_texts()
		last_observation = "dialogue=%s choosing=%s near_npc=%s text=%s" % [
			str(dialogue.visible),
			str(dialogue.visible and dialogue.choosing()),
			str(driver.main.player.near_npc != null),
			" | ".join(visible_texts).substr(0, 420)
		]
		driver._log("PLAYER_AGENT_SHOP_OBSERVE vendor=%s pass=%d shop=%s %s" % [
			vendor, interaction_pass, str(shop.visible), last_observation
		])

		if dialogue.visible:
			if dialogue.choosing():
				if vendor == "smith":
					var choice_result := await _tap_dialogue_choice(["Buy armour", "خرید زره"])
					if not choice_result.begins_with("selected dialogue choice:"):
						await driver.shot("shop_smith_choice_unavailable")
						# Do not leave a modal dialogue paused while the next vendor is
						# approached. Dismiss only through the visible Leave option.
						var leave_result := await _tap_dialogue_choice(["Leave", "برگشتن"])
						if not leave_result.begins_with("selected dialogue choice:"):
							driver._log("PLAYER_AGENT_SHOP_DISMISS_FAILED " + leave_result)
						return "smith dialogue choice blocked shop opening: %s; cleanup=%s" % [choice_result, leave_result]
				else:
					var generic_choice := await _choose_dialogue_option()
					if generic_choice.find("selected dialogue option:") < 0:
						await driver.shot("shop_%s_choice_unavailable" % vendor)
						var leave_result := await _tap_dialogue_choice(["Leave", "برگشتن"])
						return "vendor %s dialogue choice could not be selected: %s; cleanup=%s" % [vendor, generic_choice, leave_result]
			else:
				var read_result: String = await driver.dialog_all()
				driver._log("PLAYER_AGENT_SHOP_DIALOGUE vendor=%s result=%s" % [vendor, read_result])
		else:
			if driver.main.player.near_npc == null:
				route = await driver.walk_to(npc.global_position + Vector2(0, 26), 12.0, 22.0)
				await driver.wait(0.25)
				if driver.main.player.near_npc == null:
					break
			await driver.press("talk")
			await driver.wait(0.55)

		await driver.wait(0.25)

	if not shop.visible:
		var dialogue = driver.main.hud.dialogue
		var final_texts: Array[String] = []
		final_texts = _visible_screen_texts()
		var failure := "talked to %s but its shop did not open after %d interaction passes; dialogue_visible=%s choosing=%s near_npc=%s visible_text=%s" % [
			vendor,
			interaction_pass,
			str(dialogue.visible),
			str(dialogue.visible and dialogue.choosing()),
			str(driver.main.player.near_npc != null),
			" | ".join(final_texts).substr(0, 420)
		]
		driver._log("PLAYER_AGENT_SHOP_FAILED " + failure)
		await driver.shot("shop_%s_not_open" % vendor)
		# Release a story/choice modal using its visible Leave action so the next
		# recovery attempt does not walk while the game remains paused.
		var cleanup := "no modal cleanup required"
		if dialogue.visible and dialogue.choosing():
			cleanup = await _tap_dialogue_choice(["Leave", "برگشتن"])
		elif dialogue.visible:
			cleanup = await driver.dialog_all()
		return failure + "; cleanup=" + cleanup

	await driver.shot("shop_%s_open" % vendor)
	driver._log("PLAYER_AGENT_SHOP_OPEN vendor=%s passes=%d" % [vendor, interaction_pass])
	var catalog: Array = Game.shop_catalog(vendor)
	var selected: Dictionary = {}
	# On a dangerous expedition, a player with fewer than two health potions
	# can deliberately prioritize a visible consumable before another upgrade.
	if vendor == "merchant" and prioritize_health and int(Game.state.get("potions", 0)) < 3:
		for item in catalog:
			if str(item.get("id", "")) == "hp_potion" and int(Game.state.get("gold", 0)) >= int(item.get("price", 0)):
				selected = item
				break
	# Otherwise the normal buyer prefers the next equipment tier.
	if selected.is_empty():
		for item in catalog:
			if str(item.get("state", "")) != "next" or not item.has("tier"):
				continue
			if int(Game.state.get("gold", 0)) >= int(item.get("price", 0)):
				selected = item
				break

	# If equipment is not yet affordable, keep enough gold for the next armour tier before
	# buying consumables. Refill health supplies only when the carried stock is low.
	if selected.is_empty() and vendor == "merchant" and int(Game.state.get("potions", 0)) < 3:
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
	var selected_id := str(selected.get("id", ""))
	var selected_price := int(selected.get("price", 0))
	var gold_before := int(Game.state.get("gold", 0))
	var old_weapon := int(Game.state.get("weapon", 0))
	var old_armor := int(Game.state.get("armor", 0))
	var old_potions := int(Game.state.get("potions", 0))
	driver._log("PLAYER_AGENT_SHOP_PURCHASE_ATTEMPT vendor=%s id=%s price=%d gold=%d weapon=%d armour=%d potions=%d" % [
		vendor, selected_id, selected_price, gold_before, old_weapon, old_armor, old_potions
	])
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
	driver._log("PLAYER_AGENT_SHOP_PURCHASE_RESULT vendor=%s id=%s bought=%s gold=%d->%d weapon=%d->%d armour=%d->%d potions=%d->%d" % [
		vendor, selected_id, str(bought), gold_before, purse_after,
		old_weapon, int(Game.state.get("weapon", 0)),
		old_armor, int(Game.state.get("armor", 0)),
		old_potions, int(Game.state.get("potions", 0))
	])
	await driver.shot("shop_%s_purchase_result" % vendor)
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
	var bag_start := Game.Gear.bag().size()
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
		var bag_before_size := bag.size()
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
		if Game.Gear.bag().size() < bag_before_size:
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
	driver._log("PLAYER_AGENT_GEAR_SCAN class=%s bag_start=%d bag_end=%d upgrades=%d" % [Game.cls, bag_start, Game.Gear.bag().size(), changed.size()])
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
	var spells_tab := _named_control("Sub_spells")
	if spells_tab != null and not await _tap_control(spells_tab):
		await _close_pause()
		return "could not open the Spells subpage"
	driver._log("PLAYER_AGENT_SPELL_POLICY class=%s priorities=%s selected=%s" % [Game.cls, str(priorities.get(Game.cls, priorities["warrior"])), str(chosen)])
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
	var blocked_pickups: Dictionary = {}
	for attempt in max_items:
		var nearest: Node2D = null
		var best := INF
		for node in driver.get_tree().get_nodes_in_group("pickups"):
			if not is_instance_valid(node) or node.get_parent() == null:
				continue
			if blocked_pickups.has(node.get_instance_id()):
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
		# Skip loot inside an exit's safety margin. The Sunken Crypt chest is
		# deliberately close to the hidden Shrine of Weight arch; a direct approach
		# can cross that portal even though the player only intended to loot a chest.
		var nearby_exit := ""
		for exit_data in driver.main.world.data.get("exits", []):
			var exit_rect := Rect2(float(exit_data.get("x", 0)), float(exit_data.get("y", 0)), float(exit_data.get("w", 0)), float(exit_data.get("h", 0)))
			if exit_rect.grow(72.0).has_point(nearest.global_position):
				nearby_exit = str(exit_data.get("to", "unknown"))
				break
		if nearby_exit != "":
			blocked_pickups[nearest.get_instance_id()] = true
			skipped += 1
			driver._log("PLAYER_AGENT_PICKUP_SKIPPED_NEAR_EXIT kind=%s key=%s exit=%s" % [pickup_kind, pickup_key, nearby_exit])
			continue
		var map_before := str(driver.main.world.key)
		var before_count: int = Game.state.get("picked", []).size()
		var route: String = await driver.walk_to(nearest.global_position, 22.0, 16.0)
		if driver.main.world == null or not is_instance_valid(driver.main.world) or str(driver.main.world.key) != map_before:
			var map_after := str(driver.main.world.key) if driver.main.world != null else "none"
			var route_failure := "pickup route unexpectedly changed map from %s to %s" % [map_before, map_after]
			driver.assertion_failures.append(route_failure)
			driver._log("ASSERTION_FAILED " + route_failure)
			return "aborted pickup scan after an unintended map transition: " + route_failure
		await driver.wait(0.35)
		var taken := not is_instance_valid(nearest) or not driver.get_tree().get_nodes_in_group("pickups").has(nearest)
		var after_count: int = Game.state.get("picked", []).size()
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
	driver._log("PLAYER_AGENT_PICKUP_SCAN map=%s collected=%d skipped=%d kinds=%s" % [str(driver.main.world.key), collected.size(), skipped, ", ".join(collected)])
	return "collected %d ground pickups%s" % [collected.size(), " (" + ", ".join(collected) + ")" if not collected.is_empty() else ""]

func _choose_dialogue_option() -> String:
	var observation := _screen_observation()
	var visible_buttons: Array = observation.get("buttons", [])
	var preferred := ["Train with me", "با من تمرین کن", "Continue", "ادامه", "Accept", "قبول", "Enter", "ورود", "Take", "بگیر", "Begin", "شروع", "Investigate", "بررسی"]
	var selected_index := PlayerBrain.find_visible_button(visible_buttons, preferred, true)
	if selected_index < 0:
		return "no enabled visible dialogue option"
	var selected: Dictionary = visible_buttons[selected_index]
	var picked := selected.get("control") as Button
	var chosen_text := str(selected.get("text", ""))
	if picked == null or not await _tap_control(picked):
		return "dialogue option failed to receive input"
	await driver.wait(0.35)
	driver._log("PLAYER_AGENT_DIALOGUE_CHOICE " + chosen_text)
	return "selected dialogue option: " + chosen_text

func recover_from_death() -> String:
	var death = driver.main.hud.death
	if death == null or not death.visible:
		return "no death screen to recover from"
	# Recovery decisions now come from the visible death-screen choices, not hidden retry counters.
	var observation := _screen_observation()
	var visible_buttons: Array = observation.get("buttons", [])
	var choice_index := PlayerBrain.find_death_recovery_button(visible_buttons)
	if choice_index < 0:
		var labels: Array[String] = []
		for item in visible_buttons:
			if bool(item.get("visible", false)) and bool(item.get("enabled", false)):
				labels.append(str(item.get("text", "")))
		driver._log("PLAYER_AGENT_RECOVERY_BLOCKED visible_buttons=%s" % " | ".join(labels))
		return "death screen had no recognizable visible recovery action"
	var choice_data: Dictionary = visible_buttons[choice_index]
	var choice := choice_data.get("control") as Button
	var label := str(choice_data.get("text", ""))
	var is_rematch := PlayerBrain.find_visible_button(visible_buttons, ["rematch", "retry", "try again", "دوباره", "تلاش مجدد", "شروع دوباره"]) == choice_index
	var action := "requested a rematch using the visible '%s' choice" % label if is_rematch else "used the visible respawn/home choice '%s'" % label
	if choice == null or not await _tap_control(choice):
		return "death screen choice could not receive a real touch: " + label
	await driver.wait(1.2)
	var recovered: bool = driver.main.player != null and not driver.main.player.dead and not death.visible
	if recovered:
		driver._log("PLAYER_AGENT_RECOVERY action=%s map=%s hp=%d" % [action, str(driver.main.world.key), int(Game.hp)])
		return action
	return "recovery choice was tapped but the player did not return to play"

func prepare_route_supplies(minimum_potions := 2) -> String:
	var target_stock := clampi(int(minimum_potions), 1, 3)
	var report: Array[String] = []
	var initial_stock := int(Game.state.get("potions", 0))
	for purchase_index in range(3):
		var stock_before := int(Game.state.get("potions", 0))
		if stock_before >= target_stock:
			break
		var purchase_result: String = await visit_shop("merchant", true)
		report.append(purchase_result)
		var stock_after := int(Game.state.get("potions", 0))
		driver._log("PLAYER_AGENT_ROUTE_SUPPLIES pass=%d stock=%d->%d gold=%d" % [
			purchase_index + 1, stock_before, stock_after, int(Game.state.get("gold", 0))
		])
		if stock_after <= stock_before:
			break
	var final_stock := int(Game.state.get("potions", 0))
	if final_stock < target_stock:
		driver._log("PLAYER_AGENT_ROUTE_SUPPLIES_LIMITED stock=%d target=%d gold=%d" % [
			final_stock, target_stock, int(Game.state.get("gold", 0))
		])
	else:
		driver._log("PLAYER_AGENT_ROUTE_SUPPLIES_READY stock=%d" % final_stock)
	return "route supplies: potions %d->%d (target %d); %s" % [
		initial_stock, final_stock, target_stock, " | ".join(report)
	]

## Find living enemies close enough to threaten a normal map transition.
## This only reads the live scene; it does not change enemy or quest state.
func _nearest_route_threat(radius: float = 420.0, excluded_type := "") -> Dictionary:
	if driver == null or driver.main == null or driver.main.player == null or driver.main.world == null:
		return {}
	var origin: Vector2 = driver.main.player.global_position + Vector2(0, -17)
	var threat_count := 0
	var nearest_distance := INF
	var nearest_position := Vector2.ZERO
	var nearest_type := ""
	var deferred_near_exit: Array[String] = []
	var exits: Array = route_exit_safety_candidates(str(driver.main.world.key), driver.main.world.data.get("exits", []))
	for foe in driver.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(foe) or foe.get_parent() == null:
			continue
		if foe.world != driver.main.world or bool(foe.dead):
			continue
		if excluded_type != "" and str(foe.type) == excluded_type:
			continue
		var foe_center: Vector2 = foe.center()
		if should_skip_route_path_near_exit(origin, foe_center, exits):
			var deferred_type := str(foe.type)
			if not deferred_near_exit.has(deferred_type):
				deferred_near_exit.append(deferred_type)
			continue
		var distance: float = foe_center.distance_to(origin)
		if not should_engage_route_threat(distance, radius):
			continue
		threat_count += 1
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_position = foe.global_position
			nearest_type = str(foe.type)
	if not deferred_near_exit.is_empty():
		driver._log("PLAYER_AGENT_ROUTE_THREATS_DEFERRED_NEAR_EXIT map=%s foes=%s margin=180" % [
			str(driver.main.world.key), ", ".join(deferred_near_exit)
		])
	return {
		"count": threat_count,
		"nearest_type": nearest_type,
		"nearest_position": nearest_position,
		"nearest_distance": nearest_distance
	}

## A human player clears nearby pressure before crossing to another region.
## Every attack is an ordinary touch-driven combat action; no enemy is removed,
## isolated, or made invulnerable for route traversal.
func _clear_route_threats(max_rounds := 4, radius := 420.0, excluded_type := "") -> Dictionary:
	var rounds := clampi(int(max_rounds), 1, 5)
	var before_map := str(driver.main.world.key) if driver.main.world else "none"
	for round_index in range(rounds):
		if driver.main.player == null or driver.main.player.dead or driver.get_tree().paused:
			return {"safe": false, "message": "route sweep stopped because the player is dead or the game is paused"}
		var threat := _nearest_route_threat(float(radius), str(excluded_type))
		if threat.is_empty() or int(threat.get("count", 0)) == 0:
			if round_index == 0:
				driver._log("PLAYER_AGENT_ROUTE_CLEAR map=%s nearby=0" % before_map)
			return {"safe": true, "message": "nearby route clear after %d combat round(s)" % round_index}
		var threat_count := int(threat.get("count", 0))
		var threat_type := str(threat.get("nearest_type", "unknown"))
		var threat_position: Vector2 = threat.get("nearest_position", driver._feet())
		var threat_distance := float(threat.get("nearest_distance", INF))
		driver._log("PLAYER_AGENT_ROUTE_THREAT map=%s round=%d/%d nearby=%d nearest=%s distance=%d hp=%d/%d potions=%d" % [
			before_map, round_index + 1, rounds, threat_count, threat_type, int(threat_distance),
			int(Game.hp), int(Game.max_hp()), int(Game.state.get("potions", 0))
		])
		# A player uses a healing item before a dangerous approach, while a Mage
		# keeps one potion in reserve for the upcoming boss encounter.
		var potion_reserve := 1 if Game.cls == "mage" else 0
		if Game.hp <= Game.max_hp() * 0.68 and int(Game.state.get("potions", 0)) > potion_reserve:
			await driver.press("potion")
			await driver.wait(0.2)
		var approach: String = await driver.walk_to(threat_position, 10.0, 82.0)
		if driver.main.world == null or str(driver.main.world.key) != before_map:
			return {"safe": false, "message": "route threat approach changed map unexpectedly: " + approach}
		if driver.main.player.dead or driver.get_tree().paused:
			return {"safe": false, "message": "player fell while approaching route threat %s" % threat_type}
		var combat_result: String = await driver.fight(18.0, 0.0)
		driver._log("PLAYER_AGENT_ROUTE_COMBAT map=%s round=%d target=%s approach=%s result=%s hp=%d/%d" % [
			before_map, round_index + 1, threat_type, approach, combat_result, int(Game.hp), int(Game.max_hp())
		])
		if driver.main.world == null or str(driver.main.world.key) != before_map:
			return {"safe": false, "message": "route combat changed map unexpectedly from %s" % before_map}
		if driver.main.player.dead or driver.get_tree().paused:
			return {"safe": false, "message": "player fell while clearing route threats in %s" % before_map}
		await driver.wait(0.25)
	var remaining := _nearest_route_threat(260.0, str(excluded_type))
	if not remaining.is_empty() and int(remaining.get("count", 0)) > 0:
		var blocked := "route remains unsafe: %d nearby foes, nearest %s at %d px" % [
			int(remaining.get("count", 0)), str(remaining.get("nearest_type", "unknown")),
			int(remaining.get("nearest_distance", 0.0))
		]
		driver._log("PLAYER_AGENT_ROUTE_BLOCKED map=%s %s" % [before_map, blocked])
		return {"safe": false, "message": blocked}
	driver._log("PLAYER_AGENT_ROUTE_CLEAR map=%s rounds=%d" % [before_map, rounds])
	return {"safe": true, "message": "cleared nearby route threats in %d combat round(s)" % rounds}

func follow_objective(max_steps := 8, stop_after_interaction := false, boss_fight_sec := 75.0) -> String:
	var report: Array[String] = []
	for step_index in max_steps:
		var target: Dictionary = Game.quest_target()
		if target.is_empty():
			return "no active objective; " + " | ".join(report)
		var target_map := str(target.get("map", ""))
		var current_map := str(driver.main.world.key)
		driver._log("PLAYER_AGENT_OBJECTIVE map=%s target_map=%s kind=%s pos=%s" % [current_map, target_map, str(target.get("kind", "")), str(target.get("pos", Vector2.ZERO))])
		if target_map != current_map:
			if current_map == "village" and target_map == "emberforge" and Game.brann_sync() == "anvil":
				report.append(await prepare_route_supplies(3))
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
			var route_safety: Dictionary = {"safe": true, "message": "destination is on another map"}
			var objective_kind := str(target.get("kind", ""))
			var clear_route := should_clear_route_threats_before_objective(current_map, target_map, objective_kind, Game.brann_sync())
			if clear_route:
				route_safety = await _clear_route_threats(4, 420.0)
			else:
				var reason := "focused boss encounter" if current_map == target_map and objective_kind == "boss" else "priority Jamshid reward turn-in"
				driver._log("PLAYER_AGENT_ROUTE_CLEARANCE_SKIPPED map=%s target=%s reason=%s" % [current_map, target_map, reason])
				route_safety = {"safe": true, "message": "optional route threats deferred for " + reason}
			report.append(str(route_safety.get("message", "route safety check unavailable")))
			if not bool(route_safety.get("safe", false)):
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
		if kind == "exit":
			var next_map := ""
			for exit_data in driver.main.world.data.get("exits", []):
				var rect := Rect2(float(exit_data.get("x", 0)), float(exit_data.get("y", 0)), float(exit_data.get("w", 0)), float(exit_data.get("h", 0)))
				if rect.grow(8.0).has_point(target_pos):
					next_map = str(exit_data.get("to", ""))
					break
			if next_map == "":
				report.append("objective exit has no matching authored map exit")
				break
			var exit_route: String = await driver.walk_to(target_pos, 45.0, 6.0, next_map)
			await driver.wait(0.4)
			if str(driver.main.world.key) == current_map:
				report.append("could not cross objective exit to %s: %s" % [next_map, exit_route])
				break
			report.append("followed the quest arrow through exit to %s" % str(driver.main.world.key))
			continue
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
			var boss_type := str(boss.type)
			if should_clear_route_threats_before_objective(current_map, target_map, kind):
				var boss_route_safety: Dictionary = await _clear_route_threats(4, 420.0, boss_type)
				report.append(str(boss_route_safety.get("message", "boss route safety check unavailable")))
				if not bool(boss_route_safety.get("safe", false)):
					break
			else:
				driver._log("PLAYER_AGENT_BOSS_PRIORITY type=%s policy=focused_combat ambient_threats=not_precleared" % boss_type)
			if not is_instance_valid(boss) or boss.dead:
				report.append("objective boss %s was no longer available before focused combat" % boss_type)
				break
			# Let the live combat controller approach and prioritize this boss. A plain
			# walk_to plus nearest-threat sweep strands the player in the boss arena's adds.
			var fight_limit := clampf(float(boss_fight_sec), 30.0, 240.0)
			await driver.shot("objective_boss_%s_start" % boss_type)
			var outcome: String = await driver.fight(fight_limit, 0.0, boss_type)
			var boss_defeated := not is_instance_valid(boss)
			if is_instance_valid(boss):
				boss_defeated = bool(boss.dead)
			driver._log("PLAYER_AGENT_OBJECTIVE_BOSS type=%s defeated=%s duration_limit=%.1f outcome=%s" % [
				boss_type, str(boss_defeated), fight_limit, outcome
			])
			await driver.shot("objective_boss_%s_end" % boss_type)
			report.append("boss %s: %s" % [boss_type, outcome])
			if boss_defeated:
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
		if driver.main.world == null or str(driver.main.world.key) != current_map:
			var actual_map := str(driver.main.world.key) if driver.main.world else "none"
			var route_failure := "objective approach left %s unexpectedly (now %s): %s" % [current_map, actual_map, route]
			driver.assertion_failures.append(route_failure)
			driver._log("PLAYER_AGENT_ROUTE_MISROUTED " + route_failure)
			report.append(route_failure)
			break
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
				if stop_after_interaction:
					break
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
	# The first purse is enough for armour but not both upgrades. A sensible new player
	# buys protection first and returns for a better weapon after earning more gold.
	var smith_result: String = await visit_shop("smith")
	report.append(smith_result)
	var hud = driver.main.hud
	if hud.dialogue.visible or hud.shop.visible or hud.forge.visible:
		var blocker := "merchant visit skipped because the smith interaction left a modal panel open: dialogue=%s shop=%s forge=%s" % [
			str(hud.dialogue.visible), str(hud.shop.visible), str(hud.forge.visible)
		]
		report.append(blocker)
		driver._log("PLAYER_AGENT_LOADOUT_MODAL_BLOCK " + blocker)
	else:
		report.append(await visit_shop("merchant"))
	report.append(await spend_talents())
	var armor_after := int(Game.state.get("armor", 0))
	var weapon_after := int(Game.state.get("weapon", 1))
	if armor_before == 0 and armor_after == 0:
		var failure := "fresh player could not buy the first armour tier through the shop UI"
		driver.assertion_failures.append(failure)
		driver._log("ASSERTION_FAILED " + failure)
	driver._log("PLAYER_AGENT_LOADOUT weapon=%d->%d armour=%d->%d gold=%d" % [weapon_before, weapon_after, armor_before, armor_after, int(Game.state.get("gold", 0))])
	return " | ".join(report)

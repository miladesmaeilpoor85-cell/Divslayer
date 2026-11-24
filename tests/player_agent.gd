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

func _tap_control(control: Control) -> bool:
	if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
		return false
	var canvas_point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	await driver.tap(driver._win(canvas_point))
	await driver.wait(0.25)
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
				# Rostam launches repeated marked strikes. Wait for a fresh cue, then try a roll;
				# imperfect timing is intentional and the drill itself decides whether it counted.
				await driver.wait(randf_range(0.55, 0.95))
				await driver.press("dodge")
				await driver.wait(0.30)
			"block":
				await driver.wait(randf_range(0.45, 0.85))
				await driver.press("block", 0.28)
				await driver.wait(0.30)
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

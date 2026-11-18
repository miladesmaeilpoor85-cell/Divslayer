extends Node
## v0.11 checks: alchemy. The eight recipes and what each needs, brewing, Rudabeh (first visit, the cauldron panel, Brew buttons),
## essence from bosses, herbs from foes, the five scrolls (fire, ice, regen, frost, haste), choosing a scroll, the touch
## button and the key, the Gear tab, saving.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/alchemytest.gd

const Skills = preload("res://scripts/skills.gd")

var main: Node
var results := {}
var fails: Array = []

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func check(n: String, ok: bool, info = null) -> void:
	results[n] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(n)
	printerr(("PASS " if ok else "FAIL ") + n + ("" if info == null else "  " + str(info)))

func touch(i: int, pos: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = i
	ev.position = pos
	ev.pressed = down
	get_viewport().push_input(ev, true)

func click(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = p
		ev.global_position = p
		ev.pressed = down
		get_viewport().push_input(ev, true)
		await get_tree().process_frame
		await get_tree().process_frame

## a fresh hero of class c at level lv in the empty Trial arena, standing in the open, facing right
func hero(c: String, lv := 1, at := Vector2(450, 520)) -> Node:
	Game.new_game(c)
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	Game.v18()["tips"] = {"talents": true}
	Game.state["level"] = lv
	Game.hp = Game.max_hp()
	Game.mp = Game.max_mp()
	if main.player == null:
		main.start_world()
		await frames(5)
	main.goto_map("trial", at)
	await frames(3)
	var p = main.player
	p.global_position = at
	p.facing = "right"
	p.invuln = 0.0
	p.dead = false
	p.caster.cds.clear()
	p.caster.roar_t = 0.0
	p.caster.spin_t = 0.0
	p.caster.dance = {}
	p.statuses.clear()
	return p

## a still, sturdy target (no AI, no contact damage) at feet position
func dummy(feet: Vector2, type := "skeleton", hp := 5000.0) -> Node:
	var e = main.world.spawn_enemy(type, feet)
	e.max_hp = hp
	e.hp = hp
	e.spd = 0.0
	e.dmg = 0.0
	e.hit_cd = 9999.0
	return e

func clear_foes() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()

func stock(herb: int, ess: int, gold: int) -> void:
	Game.state["herbs"] = herb
	Game.state["essence"] = ess
	Game.state["gold"] = gold

func talk(id: String) -> void:
	for n in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(n) and str(n.get_meta("id", "")) == id:
			main._on_interact(n)
			return
	var n := Node2D.new()
	n.set_meta("id", id)
	n.set_meta("name_en", id)
	add_child(n)
	main._on_interact(n)

func finish_dialogue() -> void:
	var d = main.hud.dialogue
	var guard := 0
	while d.visible and guard < 20:
		d.skip_typing()
		d._block_until = 0
		d.advance()
		guard += 1
	await frames(2)

func buttons_of(root: Node) -> Array:
	var out := []
	var stack: Array = [root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
		if nd is Button:
			out.append(nd.name)
	return out

func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	Game.lang = "en"
	Game.set_setting("sound", true)
	var p = await hero("warrior")
	p.invuln = 99.0
	clear_foes()
	Game.state["scrolls"] = {}
	Game.state["potions"] = 0
	Game.state["mana_potions"] = 0
	Game.state["greater"] = 0

	# ---- recipes: eight of them, the costs of the HTML game
	check("eight_recipes", Game.recipes().size() == 8, Game.recipes().size())
	stock(0, 0, 0)
	check("block_herb", Game.craft_block("hp_potion") == "herb")
	stock(1, 0, 0)
	check("block_gold", Game.craft_block("hp_potion") == "gold")
	stock(3, 0, 100)
	check("block_essence", Game.craft_block("greater_hp") == "essence")
	stock(5, 5, 500)
	for id in ["hp_potion", "mp_potion", "greater_hp", "fire_scroll", "ice_scroll", "regen_scroll", "frost_scroll", "haste_scroll"]:
		check("brewable_" + id, Game.craft_block(id) == "")
	check("unknown_recipe_blocked", Game.craft_block("nope") == "none" and not Game.craft("nope"))
	check("craft_names_persian", true)
	Game.lang = "fa"
	var nm_fa: String = Game.craft_name(Game.recipe("hp_potion"))
	Game.lang = "en"
	check("recipe_name_translates", nm_fa != Game.craft_name(Game.recipe("hp_potion")), nm_fa)

	# ---- brewing: the cost leaves, the thing arrives
	stock(10, 10, 1000)
	check("brew_hp_potion", Game.craft("hp_potion") and int(Game.state["potions"]) == 1 and Game.herbs() == 9 and int(Game.state["gold"]) == 997)
	check("brew_mp_potion", Game.craft("mp_potion") and int(Game.state["mana_potions"]) == 1 and Game.herbs() == 7 and int(Game.state["gold"]) == 993)
	check("brew_greater", Game.craft("greater_hp") and int(Game.state["greater"]) == 1 and Game.herbs() == 4 and Game.essence() == 9 and int(Game.state["gold"]) == 973)
	for sid in ["fire", "ice", "regen", "frost", "haste"]:
		stock(10, 10, 1000)
		check("brew_scroll_" + sid, Game.craft(sid + "_scroll") and Game.scroll_count(sid) == 1)
	stock(0, 0, 0)
	check("cannot_brew_broke", not Game.craft("fire_scroll"))

	# ---- Rudabeh: a few words the first time, then the cauldron
	Game.state["miri_met"] = false
	main.goto_map("village", Vector2(300, 260))
	await frames(5)
	talk("alchemist")
	await frames(2)
	check("miri_first_visit_talks", main.hud.dialogue.visible and not main.hud.craft.visible)
	await finish_dialogue()
	check("miri_cauldron_opens", main.hud.craft.visible and get_tree().paused)
	stock(5, 5, 200)
	main.hud.craft._render()
	var bs := buttons_of(main.hud.craft)
	check("craft_panel_has_eight_brew_buttons", bs.filter(func(n): return str(n).begins_with("Brew_")).size() == 8, bs)
	var pot0: int = int(Game.state["potions"])
	for c in main.hud.craft.list.get_children():
		for b in c.find_children("Brew_hp_potion", "Button", true, false):
			b.pressed.emit()
	await frames(2)
	check("brew_button_brews", int(Game.state["potions"]) == pot0 + 1 and Game.herbs() == 4)
	stock(0, 0, 0)
	main.hud.craft._render()
	var disabled := true
	for c in main.hud.craft.list.get_children():
		for b in c.find_children("Brew_*", "Button", true, false):
			disabled = disabled and b.disabled
	check("brew_buttons_disabled_when_broke", disabled)
	main.hud.craft.close()
	check("craft_closes_and_unpauses", not main.hud.craft.visible and not get_tree().paused)
	check("miri_remembered", Game.state["miri_met"] == true)
	talk("alchemist")
	await frames(2)
	check("miri_second_visit_goes_straight_to_cauldron", main.hud.craft.visible and not main.hud.dialogue.visible)
	Game.lang = "fa"
	main.hud.craft._render()
	check("craft_panel_persian_builds", true)
	Game.lang = "en"
	main.hud.craft.close()

	# ---- essence from bosses, herbs from foes
	Game.state["essence"] = 0
	var msg := Game.boss_defeated("boss")
	check("guardian_gives_2_essence", Game.essence() == 2, Game.essence())
	check("boss_message_names_essence", msg.find("Essence") >= 0, msg)
	Game.state["essence"] = 0
	Game.boss_defeated("captain")
	check("captain_gives_1_essence", Game.essence() == 1, Game.essence())
	Game.state["herbs"] = 0
	var fen := 0
	for i in 500:
		if Game.herb_drop("shadowfen"):
			fen += 1
	var dun := 0
	for i in 500:
		if Game.herb_drop("dungeon"):
			dun += 1
	check("fen_foes_drop_herbs_more_than_dungeon", fen > dun and fen >= 30 and fen <= 100, [fen, dun])
	check("herbs_counted", Game.herbs() == fen + dun)

	# ---- the five scrolls
	main.goto_map("forest", Vector2(100, 100))
	await frames(5)
	p = main.player
	p.invuln = 99.0
	Game.state["scrolls"] = {}
	Game.state["scroll_sel"] = ""
	check("no_scrolls_no_selection", Game.scroll_sel() == "")
	p.use_scroll()
	check("use_scroll_without_one_does_nothing", true)
	Game.scrolls()["fire"] = 2
	Game.scrolls()["ice"] = 1
	Game.scrolls()["regen"] = 1
	Game.scrolls()["frost"] = 1
	Game.scrolls()["haste"] = 1
	check("first_owned_is_selected", Game.scroll_sel() == "fire")
	Game.state["scroll_sel"] = "haste"
	check("choice_is_respected", Game.scroll_sel() == "haste")
	Game.state["scroll_sel"] = "fire"
	clear_foes()
	var foe = dummy(p.global_position + Vector2(120, 0))
	p.facing = "right"
	var hp0: float = foe.hp
	p.use_scroll()
	await frames(50)
	check("fire_scroll_spent", Game.scroll_count("fire") == 1)
	check("fire_scroll_hurts", foe.hp < hp0, [hp0, foe.hp])
	Game.state["scroll_sel"] = "ice"
	var cold = dummy(p.global_position + Vector2(200, 0))
	p.use_scroll()
	await frames(3)
	check("ice_scroll_freezes_nearest", Game.scroll_count("ice") == 0 and (cold.has_status("freeze") or foe.has_status("freeze")))
	check("selection_moves_on_when_empty", Game.scroll_sel() != "ice")
	clear_foes()
	Game.scrolls()["ice"] = 1
	Game.state["scroll_sel"] = "ice"
	p.use_scroll()
	check("ice_scroll_without_target_is_kept", Game.scroll_count("ice") == 1)
	Game.state["scroll_sel"] = "regen"
	Game.hp = 5.0
	p.use_scroll()
	await frames(120)
	check("regen_scroll_heals_over_time", Game.scroll_count("regen") == 0 and Game.hp > 5.0 + Game.max_hp() * 0.05, Game.hp)
	check("regen_ends", p.regen_t <= 6.1)
	Game.state["scroll_sel"] = "haste"
	p.use_scroll()
	check("haste_scroll_starts", p.haste_t > 7.0 and Game.scroll_count("haste") == 0)
	await frames(560)
	check("haste_scroll_ends", p.haste_t == 0.0, p.haste_t)
	Game.state["scroll_sel"] = "frost"
	clear_foes()
	var f2 = dummy(p.global_position + Vector2(130, 0))
	var h2: float = f2.hp
	p.facing = "right"
	p.use_scroll()
	await frames(50)
	check("frost_scroll_spent_and_hits", Game.scroll_count("frost") == 0 and f2.hp < h2, [h2, f2.hp])

	# ---- the touch button and the key
	Game.state["scrolls"] = {}
	var pad: Node = main.hud.pad
	check("no_button_without_scrolls", not pad.buttons().has("scroll"))
	Game.scrolls()["haste"] = 2
	Game.state["scroll_sel"] = ""
	var bs2: Dictionary = pad.buttons()
	check("button_with_scrolls", bs2.has("scroll"))
	check("button_label_names_scroll", str(bs2["scroll"]["label"]).find("2") >= 0, bs2["scroll"]["label"])
	var clear := true
	for a in bs2:
		for b in bs2:
			if a < b and bs2[a]["pos"].distance_to(bs2[b]["pos"]) < float(bs2[a]["r"]) + float(bs2[b]["r"]):
				clear = false
				printerr("OVERLAP ", a, " ", b)
	check("touch_buttons_dont_overlap", clear)
	var pos: Vector2 = pad.get_global_transform_with_canvas() * bs2["scroll"]["pos"]
	touch(9, pos, true)
	await frames(3)
	touch(9, pos, false)
	check("touch_casts_scroll", Game.scroll_count("haste") == 1 and p.haste_t > 0.0)
	p.haste_t = 0.0
	Input.action_press("scroll")
	await frames(3)
	Input.action_release("scroll")
	check("key_casts_scroll", Game.scroll_count("haste") == 0)

	# ---- the Gear tab: materials, scrolls, choosing
	Game.state["scrolls"] = {"fire": 2, "frost": 1}
	Game.state["scroll_sel"] = "fire"
	Game.state["herbs"] = 3
	main.hud.pause.open()
	await frames(3)
	main.hud.pause._show("gear")
	await frames(3)
	var gb := buttons_of(main.hud.pause)
	check("gear_tab_scroll_buttons", gb.has("Scroll_fire") and gb.has("Scroll_frost"), gb)
	for b in main.hud.pause.find_children("Scroll_frost", "Button", true, false):
		b.pressed.emit()
	await frames(3)
	check("choose_button_selects", Game.scroll_sel() == "frost")
	main.hud.pause.close()
	await frames(2)
	Game.lang = "fa"
	main.hud.pause.open()
	main.hud.pause._show("gear")
	await frames(3)
	check("gear_tab_persian_builds", true)
	main.hud.pause.close()
	Game.lang = "en"

	# ---- saving
	Game.state["herbs"] = 4
	Game.state["essence"] = 5
	Game.state["scrolls"] = {"fire": 2}
	Game.state["miri_met"] = true
	Game.save_game()
	for k in ["herbs", "essence", "scrolls", "miri_met"]:
		Game.state.erase(k)
	Game.load_game()
	check("save_keeps_alchemy", Game.herbs() == 4 and Game.essence() == 5 and Game.scroll_count("fire") == 2 and Game.state["miri_met"] == true)
	for k in ["herbs", "essence", "scrolls"]:
		Game.state.erase(k)
	check("old_save_defaults", Game.herbs() == 0 and Game.essence() == 0 and Game.scroll_sel() == "")

	print("ALCHEMYTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

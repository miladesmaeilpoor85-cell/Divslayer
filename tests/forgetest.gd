extends Node
## v0.12 checks: the forge. Costs per level, what blocks an upgrade, the effect on ATK and DEF, the +5 maximum, obsidian from
## the fourth level, the panel and its buttons, Kavian's choice (armour / forge / leave), saving.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/forgetest.gd

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

func stock(herb: int, ess: int, obs: int, gold: int) -> void:
	Game.state["herbs"] = herb
	Game.state["essence"] = ess
	Game.state["obsidian"] = obs
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
	Game.state.erase("forge")

	# ---- the ladder of costs
	check("starts_unrefined", Game.forge_level("w") == 0 and Game.forge_level("a") == 0)
	var expect := [[1, 1, 0, 40], [2, 1, 0, 80], [3, 2, 0, 120], [4, 2, 1, 160], [5, 3, 2, 200]]
	for lv in 5:
		Game.forge()["w"] = lv
		var c := Game.forge_cost("w")
		var e: Array = expect[lv]
		check("cost_level_%d" % (lv + 1), int(c["herb"]) == e[0] and int(c["essence"]) == e[1] and int(c["obsidian"]) == e[2] and int(c["gold"]) == e[3], c)
	Game.forge()["w"] = 5
	check("max_has_no_cost", Game.forge_cost("w").is_empty() and Game.forge_block("w") == "max")
	check("max_cannot_upgrade", not Game.forge_upgrade("w") and Game.forge_level("w") == 5)
	Game.forge()["w"] = 0

	# ---- what blocks an upgrade
	stock(0, 0, 0, 0)
	check("block_herb", Game.forge_block("w") == "herb")
	stock(1, 0, 0, 0)
	check("block_essence", Game.forge_block("w") == "essence")
	stock(1, 1, 0, 0)
	check("block_gold", Game.forge_block("w") == "gold")
	stock(1, 1, 0, 40)
	check("level_one_ok", Game.forge_block("w") == "")
	Game.forge()["a"] = 3
	stock(9, 9, 0, 999)
	check("block_obsidian_from_level_4", Game.forge_block("a") == "obsidian")
	stock(9, 9, 1, 999)
	check("obsidian_unblocks", Game.forge_block("a") == "")
	Game.forge()["a"] = 0

	# ---- upgrading: the cost leaves, the stat arrives
	var atk0 := Game.atk()
	var def0 := Game.defense()
	stock(20, 20, 3, 2000)
	check("upgrade_weapon_1", Game.forge_upgrade("w") and Game.forge_level("w") == 1 and Game.herbs() == 19 and Game.essence() == 19 and int(Game.state["gold"]) == 1960)
	check("weapon_adds_2_atk", Game.atk() == atk0 + 2.0, [atk0, Game.atk()])
	check("armor_untouched_by_weapon", Game.defense() == def0)
	check("upgrade_armor_1", Game.forge_upgrade("a") and Game.forge_level("a") == 1)
	check("armor_adds_1_def", Game.defense() == def0 + 1.0, [def0, Game.defense()])
	for i in 4:
		check("weapon_up_%d" % (i + 2), Game.forge_upgrade("w"), Game.forge_level("w"))
	check("weapon_reaches_5", Game.forge_level("w") == 5 and Game.atk() == atk0 + 10.0)
	check("obsidian_spent", int(Game.state["obsidian"]) == 0, Game.state["obsidian"])
	check("forge_is_capped", not Game.forge_upgrade("w") and Game.forge_level("w") == 5)

	# ---- the panel
	Game.state.erase("forge")
	stock(5, 5, 0, 500)
	main.goto_map("village", Vector2(300, 260))
	await frames(5)
	main.hud.forge.open()
	await frames(2)
	check("forge_opens_and_pauses", main.hud.forge.visible and get_tree().paused)
	var bs := buttons_of(main.hud.forge)
	check("forge_panel_has_two_buttons", bs.has("Forge_w") and bs.has("Forge_a"), bs)
	for b in main.hud.forge.find_children("Forge_w", "Button", true, false):
		b.pressed.emit()
	await frames(2)
	check("forge_button_upgrades", Game.forge_level("w") == 1)
	stock(0, 0, 0, 0)
	main.hud.forge._render()
	await frames(2)
	var dis := true
	for b in main.hud.forge.find_children("Forge_*", "Button", true, false):
		dis = dis and b.disabled
	check("buttons_disabled_when_broke", dis)
	Game.forge()["w"] = 5
	Game.forge()["a"] = 5
	main.hud.forge._render()
	await frames(2)
	check("max_buttons_disabled", main.hud.forge.find_children("Forge_*", "Button", true, false).all(func(b): return b.disabled))
	Game.lang = "fa"
	main.hud.forge._render()
	await frames(2)
	check("forge_panel_persian_builds", true)
	Game.lang = "en"
	main.hud.forge.close()
	check("forge_closes_and_unpauses", not main.hud.forge.visible and not get_tree().paused)

	# ---- Kaveh: armour, forge, leave
	Game.state.erase("forge")
	main.goto_map("village", Vector2(300, 260))
	await frames(5)
	talk("smith")
	await frames(2)
	check("garen_asks", main.hud.dialogue.visible and main.hud.dialogue.choosing())
	check("garen_three_options", main._garen_opts.size() == 3)
	main.hud.dialogue._block_until = 0
	main.hud.dialogue._pick(1)
	await frames(3)
	check("garen_forge_option_opens_forge", main.hud.forge.visible)
	main.hud.forge.close()
	talk("smith")
	await frames(2)
	main.hud.dialogue._block_until = 0
	main.hud.dialogue._pick(0)
	await frames(3)
	check("garen_shop_option_opens_shop", main.hud.shop.visible)
	main.hud.shop.close()
	talk("smith")
	await frames(2)
	main.hud.dialogue._block_until = 0
	main.hud.dialogue._pick(2)
	await frames(3)
	check("garen_leave_closes", not main.hud.shop.visible and not main.hud.forge.visible and not get_tree().paused)

	# ---- saving
	Game.forge()["w"] = 3
	Game.forge()["a"] = 2
	Game.save_game()
	Game.state.erase("forge")
	Game.load_game()
	check("save_keeps_forge", Game.forge_level("w") == 3 and Game.forge_level("a") == 2)
	Game.state.erase("forge")
	check("old_save_defaults", Game.forge_level("w") == 0 and Game.forge_level("a") == 0)

	print("FORGETEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

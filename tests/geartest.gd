extends Node
## v0.10 checks: gear. Rolls, wearing and swapping, selling, every stat on every slot, the six relic effects, a Phoenix Heart,
## boss relics and camp-chief drops, things lying about the maps (walk over them, found once), the Gear tab, saving.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/geartest.gd

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

const Gear = preload("res://scripts/gear.gd")

func item(slot: String, key: String, val: float, label := "x", rarity := "common", uniq := "") -> Dictionary:
	var it := {"slot": slot, "rarity": rarity, "name": ["Test " + key, "تست"], "stat": {"key": key, "val": val, "label": label}}
	if uniq != "":
		it["uniq"] = uniq
	return it

func wear(it: Dictionary) -> void:
	Gear.eq()[str(it["slot"])] = it

func bare() -> void:
	Game.state["gear"] = {"eq": {}, "bag": []}

func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	Game.lang = "en"
	Game.set_setting("sound", true)
	var p = await hero("warrior")
	p.invuln = 0.0
	clear_foes()
	for n in [1, 2, 3]:
		Game.state["q%d" % n] = "done"

	# ---- rolls: every roll is a whole item, rarities respect the floor
	var rars := {}
	var ok := true
	for i in 200:
		var it := Gear.roll("common")
		rars[it["rarity"]] = true
		ok = ok and Gear.SLOTS.has(it["slot"]) and it.has("stat") and str(it["name"][1]) != ""
	check("rolls_are_whole", ok)
	check("rolls_vary", rars.size() >= 3, rars.keys())
	var floor_ok := true
	for i in 100:
		floor_ok = floor_ok and ["epic", "legendary"].has(Gear.roll("epic")["rarity"])
	check("roll_floor", floor_ok)
	var pool_keys := {}
	for pi in Gear.POOL:
		pool_keys[pi["stat"]["key"]] = true
	check("pool_covers_16_stats", pool_keys.size() == 16, pool_keys.size())

	# ---- wearing: an empty slot wears at once, the second goes to the bag, wear swaps, remove, sell
	bare()
	var a := item("ring", "atk", 5, "+5 ATK", "rare")
	var b := item("ring", "crit", 0.1, "+10% Crit", "epic")
	check("add_wears_empty_slot", Gear.add(a) == "worn" and Gear.eq()["ring"] == a)
	check("add_second_to_bag", Gear.add(b) == "bag" and Gear.bag().size() == 1)
	Gear.equip(0)
	check("equip_swaps", Gear.eq()["ring"]["stat"]["key"] == "crit" and Gear.bag()[0]["stat"]["key"] == "atk")
	Gear.unequip("ring")
	check("unequip_to_bag", not Gear.eq().has("ring") and Gear.bag().size() == 2)
	Game.state["gold"] = 0
	var g := Gear.sell(0)
	check("sell_pays_by_rarity", g == int(Gear.SELL["rare"]) and int(Game.state["gold"]) == g and Gear.bag().size() == 1, g)

	# ---- every stat feeds the hero
	bare()
	var hp0 := Game.max_hp()
	var atk0 := Game.atk()
	var def0 := Game.defense()
	var crit0 := Game.crit_chance()
	var spd0 := Game.speed()
	var mp0 := Game.max_mp()
	var reg0 := Game.mp_regen()
	var stam0 := Game.max_stamina()
	wear(item("amulet", "hpMax", 20))
	check("stat_hpMax", Game.max_hp() == hp0 + 20)
	bare(); wear(item("ring", "atk", 5))
	check("stat_atk", Game.atk() == atk0 + 5)
	bare(); wear(item("belt", "def", 3))
	check("stat_def", Game.defense() == def0 + 3)
	bare(); wear(item("ring", "crit", 0.15))
	check("stat_crit", is_equal_approx(Game.crit_chance(), crit0 + 0.15))
	bare(); wear(item("boots", "speed", 0.3))
	check("stat_speed", Game.speed() > spd0)
	bare(); wear(item("ring", "mpMax", 5))
	check("stat_mpMax", Game.max_mp() == mp0 + 5)
	bare(); wear(item("amulet", "mpRegen", 0.5))
	check("stat_mpRegen", is_equal_approx(Game.mp_regen(), reg0 + 0.5))
	bare(); wear(item("belt", "stamMax", 20))
	check("stat_stamMax", Game.max_stamina() == stam0 + 20)
	bare(); wear(item("amulet", "ultCharge", 0.3))
	Game.state["ult"] = 0.0
	Game.add_ult(10.0)
	check("stat_ultCharge", is_equal_approx(Game.ult(), 13.0), Game.ult())
	bare(); wear(item("belt", "potionBonus", 5))
	Game.hp = 1.0
	Game.state["potions"] = 3
	Game.state["greater"] = 0
	p.drink()
	var healed := Game.hp - 1.0
	bare()
	Game.hp = 1.0
	p.drink()
	check("stat_potionBonus", healed - (Game.hp - 1.0) >= 4.9, [healed, Game.hp - 1.0])
	bare(); wear(item("belt", "blockBonus", 0.2))
	Game.hp = Game.max_hp()
	p.stamina = 100.0
	p.hold_block = true
	p.block_start()
	await frames(20)
	var hb: float = Game.hp
	p.invuln = 0.0
	p.take_hit(20.0)
	var lost: float = hb - Game.hp
	bare()
	p.block_end(); p.invuln = 0.0; Game.hp = hb
	p.hold_block = true
	p.block_start()
	await frames(20)
	p.invuln = 0.0
	p.take_hit(20.0)
	check("stat_blockBonus", lost <= (hb - Game.hp), [lost, hb - Game.hp])
	p.block_end()
	bare(); wear(item("boots", "dashCd", 0.2))
	p.stamina = 100.0
	p.dodge_cd = 0.0
	p.dodge()
	check("stat_dashCd", is_equal_approx(p.dodge_cd, 0.8 * 0.8), p.dodge_cd)
	await frames(40)

	# ---- lifesteal and regen
	bare(); wear(item("ring", "lifesteal", 0.5))
	clear_foes()
	var dm = dummy(p.global_position + Vector2(24, 0))
	Game.hp = 5.0
	p.facing = "right"
	p.atk_cd = 0.0
	p.attack()
	await frames(4)
	check("stat_lifesteal", Game.hp > 5.0, Game.hp)
	bare(); wear(item("amulet", "hpRegen", 5.0))
	Game.hp = 5.0
	await frames(30)
	check("stat_hpRegen", Game.hp > 7.0, Game.hp)

	# ---- the six relic effects
	bare(); wear(item("belt", "def", 5, "+5 DEF", "legendary", "voidward"))
	var with_v: int = Game.incoming(20.0, "forest")
	bare()
	var without_v: int = Game.incoming(20.0, "forest")
	check("relic_voidward_10pct", with_v < without_v, [with_v, without_v])
	bare(); wear(item("amulet", "atk", 15, "+15 ATK", "legendary", "vengeance"))
	Game.hp = Game.max_hp()
	var hi: float = Game.atk()
	Game.hp = Game.max_hp() * 0.3
	check("relic_vengeance_below_40", is_equal_approx(Game.atk(), hi * 1.4), [hi, Game.atk()])
	Game.hp = Game.max_hp()
	bare(); wear(item("amulet", "hpMax", 35, "+35 HP", "legendary", "thorns"))
	clear_foes()
	var th = dummy(p.global_position + Vector2(40, 0))
	var th_hp: float = th.hp
	p.invuln = 0.0
	p.take_hit(30.0)
	check("relic_thorns_reflects", th.hp < th_hp, [th_hp, th.hp])
	bare(); wear(item("ring", "lifesteal", 0.12, "x", "legendary", "venom"))
	clear_foes()
	var vf = dummy(p.global_position + Vector2(40, 0))
	var got := false
	for i in 60:
		p._procs(vf)
		got = got or vf.has_status("poison")
	check("relic_venom_poisons", got)
	bare(); wear(item("boots", "speed", 0.35, "x", "legendary", "frostbite"))
	clear_foes()
	var ff = dummy(p.global_position + Vector2(40, 0))
	got = false
	for i in 60:
		p._procs(ff)
		got = got or ff.has_status("freeze")
	check("relic_frostbite_freezes", got)
	bare(); wear(item("ring", "atk", 18, "x", "legendary", "emberfall"))
	clear_foes()
	var ef = dummy(p.global_position + Vector2(40, 0))
	var ef_hp: float = ef.hp
	p.hits_landed = 4
	p._procs(ef)
	check("relic_emberfall_fifth_hit", ef.hp < ef_hp and ef.has_status("burn"), [ef_hp, ef.hp])

	# ---- a Phoenix Heart saves the hero once
	bare(); wear(item("amulet", "revive", 1, "Revive 1x", "epic"))
	Game.hp = 1.0
	p.invuln = 0.0
	p.dead = false
	p.take_hit(999.0)
	check("phoenix_revives", not p.dead and Game.hp > 1.0, Game.hp)
	check("phoenix_burns_up", not Gear.eq().has("amulet"))
	p.invuln = 0.0
	p.take_hit(9999.0)
	check("second_death_is_death", p.dead)
	p.revive()

	# ---- boss relics and the chief's drop
	bare()
	var msg := Game.boss_defeated("boss")
	check("guardian_drops_relic", Gear.has_relic("voidward"), msg)
	check("relic_worn", Gear.uniq("voidward"))
	var n_before := Gear.bag().size()
	Game.boss_defeated("boss")
	check("no_duplicate_relic", Gear.bag().size() == n_before and Gear.eq().size() == 1)
	bare()
	Gear.drop_from("captain", false)
	check("chief_always_drops_rare_plus", Gear.eq().size() + Gear.bag().size() == 1 and ["rare", "epic", "legendary"].has((Gear.eq().values() + Gear.bag())[0]["rarity"]))
	bare()
	for i in 400:
		Gear.drop_from("slime", false)
	var drops: int = Gear.eq().size() + Gear.bag().size()
	check("common_foes_drop_rarely", drops >= 2 and drops <= 45, drops)
	bare()
	Gear.drop_from("boss", true)
	check("bosses_drop_no_accessories", Gear.eq().size() + Gear.bag().size() == 0)

	# ---- things lying about the maps: walk over them, found once
	bare()
	Game.state["picked"] = []
	Game.state["potions"] = 0
	main.goto_map("forest", Vector2(100, 100))
	await frames(5)
	var pk := get_tree().get_nodes_in_group("pickups")
	check("forest_has_potion", pk.size() == 1, pk.size())
	p = main.player
	p.global_position = pk[0].global_position
	await frames(4)
	check("potion_collected", int(Game.state["potions"]) == 1 and get_tree().get_nodes_in_group("pickups").is_empty())
	main.goto_map("forest", Vector2(100, 100))
	await frames(5)
	check("potion_found_once", get_tree().get_nodes_in_group("pickups").is_empty())
	main.goto_map("shadowfen", Vector2(100, 100))
	await frames(5)
	var herbs := 0
	var essence = null
	for n in get_tree().get_nodes_in_group("pickups"):
		if n.get_meta("kind") == "herb":
			herbs += 1
		if n.get_meta("kind") == "relic_essence":
			essence = n
	check("shadowfen_has_4_herbs_and_a_relic", herbs == 4 and essence != null, herbs)
	Game.state["herbs"] = 0
	main.player.global_position = essence.global_position
	await frames(4)
	check("relic_pickup_gives_epic", Gear.eq().size() + Gear.bag().size() == 1 and ["epic", "legendary"].has((Gear.eq().values() + Gear.bag())[0]["rarity"]))
	main.goto_map("dungeon", Vector2(100, 100))
	await frames(5)
	Game.state["gold"] = 0
	bare()
	var chest = get_tree().get_nodes_in_group("pickups")[0]
	main.player.global_position = chest.global_position
	await frames(4)
	check("chest_gives_gold_and_item", int(Game.state["gold"]) >= 100 and Gear.eq().size() + Gear.bag().size() == 1, Game.state["gold"])
	main.goto_map("emberforge", Vector2(100, 100))
	await frames(5)
	var gp = null
	for n in get_tree().get_nodes_in_group("pickups"):
		if n.get_meta("kind") == "greater_potion":
			gp = n
	main.player.global_position = gp.global_position
	await frames(4)
	check("greater_potion_counted", int(Game.state["greater"]) == 1)
	Game.test_hp = 120.0
	Game.hp = 5.0
	Game.state["potions"] = 0
	main.player.drink()
	check("greater_potion_drunk_when_hurt", int(Game.state["greater"]) == 0 and Game.hp >= 55.0, Game.hp)
	Game.test_hp = -1.0

	# ---- the Gear tab
	bare()
	Gear.add(item("ring", "atk", 5, "+5 ATK", "rare"))
	Gear.add(item("ring", "crit", 0.1, "+10% Crit", "epic"))
	main.hud.pause.open()
	await frames(3)
	main.hud.pause._show("gear")
	await frames(3)
	var btns := []
	var stack: Array = [main.hud.pause]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
		if nd is Button:
			btns.append(nd.name)
	check("gear_tab_lists_unequip_wear_sell", btns.has("Unequip_ring") and btns.has("Wear_0") and btns.has("Sell_0"), btns)
	main.hud.pause._gear()
	main.hud.pause._show("gear")
	await frames(3)
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
	bare()
	Gear.add(item("ring", "atk", 5, "+5 ATK", "rare"))
	Game.state["picked"] = ["forest:0"]
	Game.save_game()
	Game.state.erase("gear")
	Game.load_game()
	check("save_keeps_gear", Gear.eq().has("ring") and Gear.eq()["ring"]["stat"]["key"] == "atk" and Game.state["picked"].has("forest:0"))
	Game.state.erase("gear")
	check("old_save_has_no_gear", Gear.eq().is_empty() and Gear.bag().is_empty())

	print("GEARTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

extends Node
## v0.6 checks: mana, the ten spells, cooldowns, mana potions (bought, drunk, drunk for you), spell buttons
## (touch and keys) and binding, the four ultimates and their meter, the talent tree (points, ranks,
## requirements, every effect, reset), saving, old saves, the Skills tab, Jamshid's gift, the HUD.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/skilltest.gd

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

func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	Game.lang = "fa"
	Game.set_setting("sound", true)

	# ---- mana pools and prices (the mage pays half)
	var p = await hero("warrior")
	check("mana_warrior_l1", is_equal_approx(Game.max_mp(), 8.0), Game.max_mp())
	Game.state["level"] = 5
	check("mana_grows_per_level", is_equal_approx(Game.max_mp(), 16.0), Game.max_mp())
	check("costs_warrior", Skills.cost("bolt") == 2 and Skills.cost("nova") == 4, [Skills.cost("bolt"), Skills.cost("nova")])
	p = await hero("mage")
	check("costs_mage_half", Skills.cost("bolt") == 1 and Skills.cost("nova") == 2 and Game.max_mp() == 20.0, [Skills.cost("bolt"), Skills.cost("nova")])
	Game.mp = 0.0
	await frames(60)
	check("mana_regen_mage", Game.mp > 1.6 and Game.mp < 2.2, Game.mp)

	# ---- Arcane Bolt: flies at the foe, hurts it, costs mana, starts the cooldown; a second cast waits
	p = await hero("warrior", 3)
	var e = dummy(Vector2(650, 520))
	var mp0: float = Game.mp
	var ok: bool = p.caster.cast("bolt")
	var again: bool = p.caster.cast("bolt")
	await frames(30)
	check("bolt_hits", ok and e.hp < e.max_hp and Game.mp < mp0, [e.hp, Game.mp, mp0])
	check("bolt_cooldown", not again and p.caster.cd_left("bolt") == 0.0)
	clear_foes()
	# a bolt shot at a wall stops there
	p.global_position = Vector2(650, 395)
	p.facing = "right"
	p.caster.cds.clear()
	p.caster.cast("bolt")
	await frames(10)
	check("bolt_stops_at_wall", main.world.spells.shots.is_empty())

	# ---- Ember Nova: everything close burns
	p = await hero("warrior")
	var ring := []
	for a in [0.0, 2.1, 4.2]:
		ring.append(dummy(Vector2(450, 520) + Vector2.from_angle(a) * 50.0))
	p.caster.cast("nova")
	await frames(2)
	var burned := 0
	for x in ring:
		if x.hp < x.max_hp and x.has_status("burn"):
			burned += 1
	check("nova_burns_all_around", burned == 3, burned)
	clear_foes()

	# ---- Chain Lightning: four foes in a line, each hit weaker than the last
	p = await hero("warrior", 4)
	var line := []
	for i in 4:
		line.append(dummy(Vector2(560 + i * 110, 520)))
	p.caster.cast("chain")
	await frames(2)
	var dmg := []
	for x in line:
		dmg.append(x.max_hp - x.hp)
	check("chain_jumps_four", dmg[0] > 0 and dmg[3] > 0, dmg)
	check("chain_falloff", dmg[0] > dmg[3], dmg)
	clear_foes()

	# ---- Ice Lance: passes through and freezes
	p = await hero("warrior", 6)
	var l1 = dummy(Vector2(600, 520))
	var l2 = dummy(Vector2(700, 520))
	p.caster.cast("icelance")
	await frames(30)
	check("icelance_pierces_and_freezes", l1.hp < l1.max_hp and l2.hp < l2.max_hp and l1.has_status("freeze") and l2.has_status("freeze"))
	clear_foes()

	# ---- Mending Light, Soul Drain, Battle Roar
	p = await hero("warrior", 16)
	Game.hp = 10.0
	p.caster.cast("mend")
	check("mend_heals_30pct", is_equal_approx(Game.hp, 10.0 + Game.max_hp() * 0.3), [Game.hp, Game.max_hp()])
	Game.hp = 10.0
	var de = dummy(Vector2(560, 520))
	p.caster.cast("drain")
	await frames(1)
	check("drain_heals", Game.hp > 10.0 and de.hp < de.max_hp, [Game.hp, de.hp])
	clear_foes()
	var m0: float = p.caster.dmg_mul()
	p.caster.cast("roar")
	check("roar_buffs_attack", is_equal_approx(p.caster.dmg_mul(), m0 * 1.4) and p.caster.roar_t > 7.0, p.caster.dmg_mul())
	await frames(4)
	var chip := false
	for c in main.hud.status_row.get_children():
		chip = true
	check("roar_status_chip", chip)

	# ---- Stoneshatter stuns; Blink moves 170 px, but never through a wall
	p = await hero("warrior", 12)
	var q = dummy(Vector2(520, 520))
	p.caster.cast("quake")
	await frames(1)
	check("quake_stuns", q.has_status("stun") and q.hp < q.max_hp)
	clear_foes()
	p = await hero("warrior", 10)
	var x0: float = p.global_position.x
	p.caster.cast("blink")
	check("blink_170", absf(p.global_position.x - x0 - 170.0) < 9.0 and p.invuln > 0.0, p.global_position.x - x0)
	p.global_position = Vector2(650, 395)
	p.facing = "right"
	p.caster.cds.clear()
	p.caster.cast("blink")
	check("blink_stops_at_wall", p.global_position.x <= 710.0 - 12.0 and p.global_position.x > 650.0, p.global_position.x)

	# ---- locked spells, mana, mana potions (drunk by hand, and for you when a spell needs one)
	p = await hero("warrior", 1)
	check("locked_until_level", not p.caster.cast("chain") and p.caster.block("chain") == "locked")
	Game.mp = 0.0
	Game.state["mana_potions"] = 0
	check("no_mana_no_spell", not p.caster.cast("bolt") and p.caster.block("bolt") == "mana")
	Game.state["mana_potions"] = 1
	var cast_ok: bool = p.caster.cast("bolt")
	check("auto_mana_potion", cast_ok and int(Game.state["mana_potions"]) == 0 and Game.mp > 0.0, Game.mp)
	Game.mp = 0.0
	Game.state["mana_potions"] = 2
	p.caster.drink_mana()
	check("drink_mana_potion", int(Game.state["mana_potions"]) == 1 and is_equal_approx(Game.mp, Game.max_mp()))
	var cat := {}
	for it in Game.shop_catalog("merchant"):
		cat[it["id"]] = it["state"]
	Game.state["gold"] = 100
	var mpi := {}
	for it in Game.shop_catalog("merchant"):
		if it["id"] == "mp_potion":
			mpi = it
	Game.buy("merchant", mpi)
	check("shop_sells_mana_potions", cat.get("mp_potion") == "buy" and int(Game.state["mana_potions"]) == 2 and int(Game.state["gold"]) == 94)

	# ---- spell buttons: binding swaps; touch and keys cast what is bound
	p = await hero("warrior", 6)
	Game.state["slots"] = ["bolt", "nova"]
	Game.bind_slot(0, "nova")
	check("bind_swaps", Game.slots() == ["nova", "bolt"], Game.slots())
	Game.bind_slot(1, "icelance")
	var pad = main.hud.pad
	var bs: Dictionary = pad.buttons()
	check("pad_has_spell_buttons", bs.has("skill1") and bs.has("skill2") and bs.has("ult") and bs.has("attack") and bs.has("potion") and bs.has("dodge"))
	var small := []
	for k in bs:
		if float(bs[k]["r"]) * 2.0 < 44.0:
			small.append(k)
	var overlap := []
	for a in bs:
		for b in bs:
			if a < b and (bs[a]["pos"] as Vector2).distance_to(bs[b]["pos"]) < float(bs[a]["r"]) + float(bs[b]["r"]) + 4.0:
				overlap.append(a + "/" + b)
	check("pad_buttons_thumb_sized_apart", small.is_empty() and overlap.is_empty(), [small, overlap])
	var c0: int = p.caster.casts
	var sp: Vector2 = pad.get_global_transform_with_canvas() * bs["skill1"]["pos"]
	touch(4, sp, true)
	await frames(2)
	touch(4, sp, false)
	await frames(2)
	check("touch_casts_slot1", p.caster.casts == c0 + 1 and p.caster.cd_left("nova") > 0.0)
	Input.action_press("skill2")
	await frames(2)
	Input.action_release("skill2")
	await frames(2)
	check("key_casts_slot2", p.caster.cd_left("icelance") > 0.0)

	# ---- the ultimate meter fills by fighting and says when it is ready
	p = await hero("warrior", 3)
	Game.state["ult"] = 0.0
	var t1 = dummy(Vector2(480, 520))
	p.attack()
	await frames(2)
	check("ult_fills_on_hits", Game.ult() > 0.0, Game.ult())
	main.hud.notify.clear()
	var u_before: float = Game.ult()
	Game.add_ult(200.0)
	# the toast pops off the queue, waits a frame, then fades in: poll for it instead of guessing the frame count
	var told := ""
	for i in 30:
		await frames(1)
		told = main.hud.notify.showing_text() + " " + str(main.hud.notify.queue)
		if told.find(Skills.ult_name()) >= 0:
			break
	check("ult_ready_toast", Game.ult() == 100.0 and told.find(Skills.ult_name()) >= 0, [u_before, told])
	clear_foes()

	# ---- the four ultimates
	# Whirlwind: hits all around for 3 s, half damage taken while spinning
	p = await hero("warrior", 5)
	var ww := []
	for a in [0.0, 1.6, 3.2, 4.7]:
		ww.append(dummy(Vector2(450, 520) + Vector2.from_angle(a) * 46.0))
	Game.state["ult"] = 100.0
	check("ultimate_needs_full_meter", p.caster.ultimate() and Game.ult() == 0.0 and p.caster.spin_t > 2.9)
	var hp0: float = Game.hp
	p.take_hit(20.0)
	var spun_loss: float = hp0 - Game.hp
	await frames(200)
	var all_hit := true
	var ww_dmg := []
	for x in ww:
		ww_dmg.append(int(x.max_hp - x.hp))
		all_hit = all_hit and (x.max_hp - x.hp) > Game.atk() * 3.0
	p.invuln = 0.0
	hp0 = Game.hp
	p.take_hit(20.0)
	check("whirlwind_hits_all_around", all_hit and p.caster.spin_t == 0.0, ww_dmg)
	check("whirlwind_halves_damage", spun_loss < hp0 - Game.hp, [spun_loss, hp0 - Game.hp])
	check("whirlwind_blocks_meter", Game.ult() > 0.0 and Game.ult() < 20.0, Game.ult())
	clear_foes()
	# Arcane Tempest: a meteor on every foe in view, three on a boss
	p = await hero("mage", 5)
	var tm := [dummy(Vector2(600, 500)), dummy(Vector2(650, 600)), dummy(Vector2(300, 600))]
	var bossy = dummy(Vector2(700, 450), "boss2", 50000.0)
	Game.state["ult"] = 100.0
	p.caster.ultimate()
	var nm: int = main.world.spells.meteors.size()
	var on_boss := 0
	for mt in main.world.spells.meteors:
		if (mt["p"] as Vector2).distance_to(bossy.global_position) < 20.0:
			on_boss += 1
	await frames(120)
	var thit := true
	for x in tm:
		thit = thit and x.hp < x.max_hp and x.has_status("burn")
	check("tempest_meteors", nm == 3 + 3 and on_boss == 3 and thit and bossy.hp < bossy.max_hp, [nm, on_boss])
	clear_foes()
	# Shadow Dance: five critical strikes, untouchable meanwhile
	p = await hero("rogue", 5)
	var sd = dummy(Vector2(560, 520))
	Game.state["ult"] = 100.0
	p.caster.ultimate()
	var inv_ok := true
	for i in 100:
		await frames(1)
		if not p.caster.dance.is_empty():
			inv_ok = inv_ok and p.invuln > 0.0
	var per: float = Game.atk() * Game.melee_mul() * 1.5 * 2.3
	check("shadow_dance_five_crits", absf((sd.max_hp - sd.hp) - per * 5.0) < per * 0.6 and p.caster.dance.is_empty(), [sd.max_hp - sd.hp, per * 5.0])
	check("shadow_dance_untouchable", inv_ok)
	clear_foes()
	Game.state["ult"] = 100.0
	check("shadow_dance_needs_target", not p.caster.ultimate() and Game.ult() == 100.0)
	# Holy Smite: damage, stun, heal, cleanse
	p = await hero("paladin", 5)
	var hs := [dummy(Vector2(520, 520)), dummy(Vector2(380, 470))]
	Game.hp = 10.0
	p.apply_status("poison", 5.0)
	Game.state["ult"] = 100.0
	p.caster.ultimate()
	await frames(1)
	var hs_ok := true
	for x in hs:
		hs_ok = hs_ok and x.hp < x.max_hp and x.has_status("stun")
	check("holy_smite", hs_ok and Game.hp > 10.0 + Game.max_hp() * 0.25 and p.statuses.is_empty(), Game.hp)
	clear_foes()

	# ---- talents: one point a level, ranks, requirements, effects, reset
	p = await hero("warrior", 8)
	check("talent_points_per_level", Game.talent_points() == 7)
	var a0: float = Game.atk()
	Game.learn_talent("str1")
	check("str1_adds_attack", is_equal_approx(Game.atk(), a0 + 1.0) and Game.talent_points() == 6)
	check("str2_needs_str1_3", not Game.learn_talent("str2") and Game.talent_block("str2") != "")
	Game.learn_talent("str1")
	Game.learn_talent("str1")
	check("rank_cap", not Game.learn_talent("str1") and Game.talent("str1") == 3)
	check("str2_opens", Game.learn_talent("str2") and is_equal_approx(Game.atk(), a0 + 5.0))
	var mh: float = Game.max_hp()
	var h0: float = Game.hp
	Game.learn_talent("vit1")
	check("vit1_health_comes_filled", is_equal_approx(Game.max_hp(), mh + 10.0) and is_equal_approx(Game.hp, h0 + 10.0))
	Game.learn_talent("crit")
	check("crit_talent", is_equal_approx(Game.crit_chance(), 0.23), Game.crit_chance())
	Game.learn_talent("swift")
	check("swift_talent", is_equal_approx(Game.speed(), 2.7 * Game.PXS * 1.05))
	check("no_points_left", Game.talent_points() == 0 and not Game.learn_talent("def1"))
	Game.reset_talents()
	check("reset_frees_points", Game.talent_points() == 7 and is_equal_approx(Game.atk(), a0))
	# the other effects
	Game.state["level"] = 20
	Game.state["talents"] = {"def1": 3, "block_mastery": 1, "dodge_master": 2, "haste": 1, "swift": 3, "scholar": 2, "treasure": 1, "power_atk": 1, "str1": 3, "str2": 2, "ult_pwr": 1, "vit1": 3, "vit2": 2, "second_wind": 1}
	check("guard_mastery", Game.incoming(100.0, "trial") < int(round(100.0 * (1.0 - Game.defense() / (Game.defense() + 60.0)))), Game.incoming(100.0, "trial"))
	check("talent_multipliers", is_equal_approx(Game.atk_speed_mul(), 0.9) and is_equal_approx(Game.xp_mul(), 1.4) and is_equal_approx(Game.gold_mul(), 1.25) and is_equal_approx(Game.heavy_mul(), 1.25) and is_equal_approx(Game.ult_mul(), 1.3))
	Game.hp = Game.max_hp() * 0.2
	check("second_wind", is_equal_approx(p.caster.dmg_mul(), 1.5))
	Game.hp = Game.max_hp()
	p.dodge_cd = 0.0
	p.stamina = 100.0
	p.dodge()
	check("dodge_master_iframes", is_equal_approx(p.dodge_iframes, 0.62), p.dodge_iframes)
	p.atk_cd = 0.0
	p.attack()
	check("haste_attack_speed", is_equal_approx(p.atk_cd, 0.28 * 0.9), p.atk_cd)
	var g0 := int(Game.state.get("gold", 0))
	var killme = dummy(Vector2(480, 520), "slime", 1.0)
	var gold_each: int = killme.gold
	killme.hurt(10.0, false, Vector2.RIGHT)
	check("treasure_gold", int(Game.state["gold"]) - g0 == int(round(gold_each * 1.25)), [int(Game.state["gold"]) - g0, gold_each])
	clear_foes()

	# ---- save and load keep talents, spell buttons and mana; a v0.5 save gets its points and defaults
	p = await hero("mage", 9)
	Game.learn_talent("vit1")
	Game.bind_slot(0, "chain")
	Game.mp = 7.0
	Game.save_game()
	Game.state = {}
	Game.mp = 0.0
	Game.load_game()
	check("save_keeps_skills", Game.talent("vit1") == 1 and Game.slots()[0] == "chain" and is_equal_approx(Game.mp, 7.0) and Game.talent_points() == 7)
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"v": 1, "cls": "rogue", "state": {"level": 6, "xp": 0, "xp_next": 200, "gold": 50, "potions": 2, "weapon": 2, "armor": 1, "map": "village", "x": 433.0, "y": 524.0}, "hp": 40.0}))
	f = null
	Game.load_game()
	check("old_save_migrates", Game.cls == "rogue" and Game.talent_points() == 5 and Game.slots() == ["bolt", "nova"] and is_equal_approx(Game.mp, Game.max_mp()) and int(Game.state["mana_potions"]) == 1)

	# ---- level up: mana refills; a new spell is announced
	p = await hero("warrior", 3)
	Game.mp = 0.0
	main.hud.notify.clear()
	Game.state["xp"] = 0
	var lvl_up := false
	lvl_up = Game.add_xp(int(Game.state["xp_next"]))
	main.world.level_up.emit(Game.lvl())
	await frames(4)
	var said: String = main.hud.notify.showing_text() + " " + str(main.hud.notify.queue)
	check("level_up_refills_mana", lvl_up and is_equal_approx(Game.mp, Game.max_mp()))
	check("new_spell_announced", Game.lvl() == 4 and said.find(Skills.spell_name("chain")) >= 0, said)

	# ---- the Skills tab: ten spell cards, binding by tapping, fifteen talents, learning by tapping
	p = await hero("warrior", 6)
	main.hud.open_pause("skills")
	await frames(3)
	var pm = main.hud.pause
	pm.sub = "spells"
	pm._show("skills")
	await get_tree().process_frame
	await get_tree().process_frame
	var cards := 0
	for id in Skills.ORDER:
		if pm.body.find_child("Spell_" + id, true, false):
			cards += 1
	check("skills_tab_spell_cards", cards == 10, cards)
	var bind: Control = pm.body.find_child("Bind0_icelance", true, false)
	if bind:
		await click(bind)
	check("skills_tab_binds", Game.slots()[0] == "icelance", Game.slots())
	pm.sub = "talents"
	pm._show("skills")
	await get_tree().process_frame
	await get_tree().process_frame
	var tc := 0
	for tr in Skills.TREES:
		for n in Skills.tree_nodes(tr):
			if pm.body.find_child("Talent_" + str(n["id"]), true, false):
				tc += 1
	check("skills_tab_talent_cards", tc == 15, tc)
	var tb: Control = pm.body.find_child("Talent_vit1", true, false)
	if tb:
		await click(tb)
	check("skills_tab_learns", Game.talent("vit1") == 1)
	check("menu_dot_while_points", main.hud.menu_dot.visible == (Game.talent_points() > 0))
	pm.close()
	await frames(2)

	# ---- Jamshid's gift after the King of Mazandaran: Emberwall, seven burning bolts
	p = await hero("warrior", 12)
	check("emberwall_locked_at_first", not Skills.known("firewall"))
	Game.state["defeated"] = {"boss2": true}
	main.goto_map("village", Vector2(433, 524))
	await frames(5)
	var brann: Node = null
	for n in get_tree().get_nodes_in_group("npcs"):
		if str(n.get_meta("id", "")) == "brann":
			brann = n
	if brann:
		main._on_interact(brann)
		await frames(2)
		var dl = main.hud.dialogue
		while dl.visible:
			dl._block_until = 0
			dl.advance()
			await frames(1)
	check("brann_gives_emberwall", brann != null and Skills.known("firewall"))
	p = main.player
	p.caster.cds.clear()
	Game.mp = Game.max_mp()
	p.caster.cast("firewall")
	check("emberwall_seven_bolts", main.world.spells.shots.size() == 7, main.world.spells.shots.size())

	# ---- the HUD's mana bar, and spells light up the night
	Game.mp = Game.max_mp() * 0.5
	await frames(2)
	check("hud_mana_bar", absf(main.hud.mp_bar.value - 0.5) < 0.05, main.hud.mp_bar.value)
	Game.state["day_t"] = 0.87
	main.world.lighting.set_process(true)
	p.caster.cds.clear()
	p.caster.cast("bolt")
	await frames(3)
	check("spells_give_light", main.world.spells.lights_now().size() >= 1)

	print("SKILLTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

extends Node
## v0.7 checks: sneak (toggle, speed, sight range, tall grass, night, backstab) and shove (stun, push, stamina,
## cooldown, whiff, shield bash, boss stagger), touch buttons and keys.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/stealthtest.gd

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

func seen(p: Node) -> void:
	p.world.tip("sneak", "", "")
	p.world.tip("block", "", "")

func walk(p: Node, frames_n: int) -> float:
	var x0: float = p.global_position.x
	p.joy = Vector2.RIGHT
	await frames(frames_n)
	p.joy = Vector2.ZERO
	return p.global_position.x - x0

func regional_attack_test(map_key: String, enemy_type: String, skill: String, status: String, label: String, interrupt := false) -> void:
	clear_foes()
	main.goto_map(map_key, Vector2(600, 520))
	clear_foes()
	await frames(4)
	var hero_now: Node = main.player
	hero_now.global_position = Vector2(600, 520)
	hero_now.joy = Vector2.ZERO
	hero_now.invuln = 0.0
	hero_now.dodge_iframes = 0.0
	hero_now.statuses.clear()
	hero_now.dead = false
	Game.hp = Game.max_hp()
	var foe: Node = main.world.spawn_enemy(enemy_type, Vector2(760, 520))
	foe.spd = 0.0
	foe.alert = true
	foe.regional_cooldown = 0.0
	await frames(1)
	check(label + "_region_move_selected", foe.regional_skill == skill)
	check(label + "_ground_warning_shown", foe.regional_attack_pending and main.world.bossfx.tele.size() == 1,
		{"skill": foe.regional_skill, "telegraphs": main.world.bossfx.tele.size()})
	if interrupt:
		foe.apply_status("stun", 1.0)
		await frames(55)
		check(label + "_stun_interrupts_special", not foe.regional_attack_pending and not hero_now.statuses.has(status), hero_now.statuses)
	else:
		await frames(55)
		check(label + "_special_applies_element", hero_now.statuses.has(status), hero_now.statuses)
		if skill == "bog_spit":
			var damaging_pool := false
			for puddle in main.world.bossfx.pools:
				if puddle.get("en", null) == foe and float(puddle.get("mult", 0.0)) > 0.0:
					damaging_pool = true
			check(label + "_leaves_a_real_poison_pool", damaging_pool)
			# The direct splash also applies poison-over-time. Clear that status and
			# restore HP so this assertion measures only the lingering pool itself.
			hero_now.statuses.clear()
			Game.hp = Game.max_hp()
			var hp_before_pool_tick: int = Game.hp
			# The world hazard system owns pool damage cadence; keep the hero inside
			# the pool long enough for its poison hazard tick to land.
			for i in 70:
				hero_now.invuln = 0.0
				hero_now.dodge_iframes = 0.0
				await frames(1)
			var pool_diagnostics: Array = []
			for puddle in main.world.bossfx.pools:
				pool_diagnostics.append({"life": puddle.get("life", -1.0), "tick": puddle.get("tick", -1.0),
					"mult": puddle.get("mult", 0.0), "contains_hero": puddle["rect"].has_point(hero_now.pc()),
					"owner_alive": is_instance_valid(foe) and not foe.dead})
			check(label + "_poison_pool_hurts_if_ignored", Game.hp < hp_before_pool_tick and hero_now.statuses.has("poison"),
				{"hp_before": hp_before_pool_tick, "hp_after": Game.hp, "poison_active": hero_now.statuses.has("poison"),
					"pools": pool_diagnostics})
	clear_foes()
	await frames(2)


func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	Game.lang = "fa"
	Game.set_setting("sound", true)
	Game.set_setting("left_hand", false)
	Game.table("CLASSES")["warrior"]["critChance"] = 0.0
	var p = await hero("warrior")
	seen(p)
	Game.state["day_t"] = 0.3
	clear_foes()

	# ---- toggle, speed, sight range
	check("not_sneaking_at_start", not p.sneaking and is_equal_approx(p.stealth_mul(), 1.0))
	p.toggle_sneak()
	check("sneak_on", p.sneaking)
	check("stealth_mul_sneaking", is_equal_approx(p.stealth_mul(), 0.45), p.stealth_mul())
	var slow: float = await walk(p, 30)
	p.toggle_sneak()
	check("sneak_off", not p.sneaking)
	p.global_position = Vector2(450, 520)
	var fast: float = await walk(p, 30)
	check("sneak_is_slower", slow > 5.0 and slow < fast * 0.7, [slow, fast])

	# ---- tall grass and night make it harder still
	p.global_position = Vector2(450, 520)
	p.toggle_sneak()
	var base_m: float = p.stealth_mul()
	p.world.grass.append(Rect2(400, 480, 100, 100))
	check("grass_hides", p.stealth_mul() < base_m * 0.7 and p.world.in_grass(p.global_position), [base_m, p.stealth_mul()])
	p.world.grass.clear()
	Game.state["day_t"] = 0.87
	var night_m: float = p.stealth_mul()
	check("night_helps_outdoors", night_m <= base_m or Game.indoor(p.world.key), [night_m, base_m])
	Game.state["day_t"] = 0.3
	p.toggle_sneak()

	# ---- enemy movement archetypes: a leaping nahang and a flanking sorcerer
	clear_foes()
	var leaper: Node = main.world.spawn_enemy("toad", p.global_position + Vector2(140, 0))
	leaper.alert = true
	leaper.leap_cooldown = 0.0
	await frames(1)
	check("toad_warns_before_leaping", leaper.can_leap and leaper.leap_windup > 0.0)
	await frames(28)
	check("toad_commits_to_leap", leaper.leap_time > 0.0 and leaper.global_position.distance_to(p.global_position) < 140.0)
	var interrupted_leaper: Node = main.world.spawn_enemy("toad", p.global_position + Vector2(-140, 0))
	interrupted_leaper.alert = true
	interrupted_leaper.leap_cooldown = 0.0
	await frames(1)
	interrupted_leaper.apply_status("stun", 0.5)
	await frames(1)
	check("stun_interrupts_a_leap_windup", interrupted_leaper.leap_windup == 0.0 and interrupted_leaper.leap_time == 0.0)

	clear_foes()
	var sorcerer: Node = main.world.spawn_enemy("wraith", p.global_position + Vector2(210, 0))
	sorcerer.alert = true
	sorcerer.teleport_cooldown = 0.0
	var sorcerer_start: Vector2 = sorcerer.global_position
	await frames(1)
	check("sorcerer_marks_a_flank_before_blinking", sorcerer.can_teleport and sorcerer.teleport_windup > 0.0)
	await frames(20)
	var sorcerer_range: float = sorcerer.global_position.distance_to(p.global_position)
	check("sorcerer_blinks_to_an_open_flank", sorcerer.global_position.distance_to(sorcerer_start) > 80.0 and sorcerer_range >= 65.0 and sorcerer_range <= 145.0, [sorcerer_start, sorcerer.global_position, sorcerer_range])
	var body_h: float = minf(sorcerer.box.y, 18.0)
	var blink_body := Rect2(sorcerer.global_position + Vector2(-sorcerer.box.x * 0.4, -body_h), Vector2(sorcerer.box.x * 0.8, body_h))
	check("sorcerer_does_not_blink_into_a_wall", not main.world.wall_hit(blink_body))
	clear_foes()

	# ---- a spotted hero alerts a nearby ally, even when the ally has not seen him yet
	var scout: Node = main.world.spawn_enemy("rimewraith", p.global_position + Vector2(165, 0))
	var answering_ally: Node = main.world.spawn_enemy("skeleton", p.global_position + Vector2(0, 120))
	scout.alert = true
	main.world.on_notice(scout)
	check("nearby_ally_hears_the_alarm", answering_ally.alert and answering_ally.squad_alert_t > 0.0)

	# ---- archers take turns, while the front line uses the opening to flank
	clear_foes()
	main.world.enemy_volley_ready_at = 0.0
	var archer_one: Node = main.world.spawn_enemy("rimewraith", p.global_position + Vector2(205, 0))
	var archer_two: Node = main.world.spawn_enemy("rimewraith", p.global_position + Vector2(-205, 0))
	var front_one: Node = main.world.spawn_enemy("skeleton", p.global_position + Vector2(0, 120))
	var front_two: Node = main.world.spawn_enemy("bandit", p.global_position + Vector2(0, -120))
	for foe in [archer_one, archer_two, front_one, front_two]:
		foe.alert = true
	archer_one.shoot_t = 0.001
	archer_two.shoot_t = 0.001
	await frames(1)
	check("nearby_archers_do_not_fire_together", main.world.bossfx.shots.size() == 1, main.world.bossfx.shots.size())
	check("volley_sends_front_line_to_flank", front_one.squad_pressure_t > 0.0 and front_two.squad_pressure_t > 0.0, [front_one.squad_pressure_t, front_two.squad_pressure_t])
	await frames(45)
	check("second_archer_fires_after_the_first_volley", main.world.bossfx.shots.size() >= 2, main.world.bossfx.shots.size())
	clear_foes()

	# ---- the later regions teach distinct, telegraphed elemental attacks
	await regional_attack_test("shadowfen", "mosquito", "bog_spit", "poison", "shadowfen_mosquito")
	await regional_attack_test("emberforge", "cinderhound", "flame_charge", "burn", "emberforge_hound")
	await regional_attack_test("frostvale", "frostwolf", "rime_pounce", "freeze", "frostvale_wolf")
	await regional_attack_test("damavand", "serpentguard", "venom_lash", "poison", "damavand_serpent", true)
	main.goto_map("trial", Vector2(450, 520))
	clear_foes()
	await frames(4)
	var out_of_region: Node = main.world.spawn_enemy("mosquito", Vector2(600, 520))
	check("regional_signature_stays_in_its_own_biome", out_of_region.regional_skill == "")
	clear_foes()
	await frames(2)

	# ---- foes see a sneaking hero only from close by
	p.global_position = Vector2(450, 520)
	var far = main.world.spawn_enemy("skeleton", Vector2(650, 520))
	p.sneaking = true
	await frames(5)
	check("far_foe_does_not_notice_sneaker", not far.alert, far.alert)
	p.sneaking = false
	await frames(5)
	check("far_foe_notices_visible_hero", far.alert)
	clear_foes()
	var near = main.world.spawn_enemy("skeleton", Vector2(540, 520))
	p.sneaking = true
	await frames(3)
	check("near_foe_notices_sneaker", near.alert)
	clear_foes()

	# ---- backstab: triple damage on an unaware foe, once; the swing ends the sneak
	p = await hero("warrior")
	seen(p)
	clear_foes()
	var a = dummy(Vector2(480, 520))
	p.sneaking = true
	a.alert = false
	p.atk_cd = 0.0
	p.combo_t = 0.0
	p.attack()
	check("sneak_remains_through_windup", p.sneaking)
	await frames(7)
	var stab: float = 5000.0 - a.hp
	check("backstab_counted", p.backstabs == 1)
	check("sneak_ends_on_attack", not p.sneaking)
	await frames(30)
	clear_foes()
	var b = dummy(Vector2(480, 520))
	p.sneaking = false
	p.atk_cd = 0.0
	p.combo_t = 0.0
	p.attack()
	await frames(7)
	var plain: float = 5000.0 - b.hp
	check("backstab_is_triple", plain > 0.0 and absf(stab / plain - 3.0) < 0.15, [stab, plain])
	await frames(30)
	clear_foes()
	var c = dummy(Vector2(480, 520))
	p.sneaking = true
	c.alert = true
	p.atk_cd = 0.0
	p.combo_t = 0.0
	p.attack()
	await frames(7)
	var spotted: float = 5000.0 - c.hp
	check("no_backstab_on_alert_foe", absf(spotted / plain - 1.0) < 0.15, [spotted, plain])
	check("sneak_ends_after_any_swing", not p.sneaking)

	# ---- being hit breaks the sneak
	await frames(60)
	p.invuln = 0.0
	p.sneaking = true
	p.take_hit(3.0)
	check("hit_breaks_sneak", not p.sneaking)

	# ---- shove: the foe flies back and is stunned, it costs stamina and has a cooldown
	p = await hero("warrior")
	seen(p)
	clear_foes()
	var s1 = dummy(Vector2(476, 520))
	p.stamina = 100.0
	p.sneaking = true
	var x0: float = s1.global_position.x
	p.shove()
	check("shove_stuns", s1.has_status("stun"))
	check("shove_pushes", s1.knock.x > 100.0, s1.knock)
	check("shove_costs_stamina", p.stamina <= 85.5 and p.stamina > 80.0, p.stamina)
	check("shove_cooldown_after_hit", is_equal_approx(p.shove_cd, 2.2), p.shove_cd)
	check("shove_breaks_sneak", not p.sneaking)
	var n: int = p.shoves
	p.shove()
	check("no_double_shove", p.shoves == n)
	await frames(20)
	check("shoved_foe_moved_back", s1.global_position.x > x0 + 4.0, [x0, s1.global_position.x])

	# ---- a shove into thin air is cheap on time; not enough stamina means no shove
	clear_foes()
	await frames(30)
	p.shove_cd = 0.0
	p.stamina = 100.0
	p.attacking = 0.0
	p.shove()
	check("whiff_short_cooldown", is_equal_approx(p.shove_cd, 0.8), p.shove_cd)
	p.shove_cd = 0.0
	p.attacking = 0.0
	p.stamina = 10.0
	n = p.shoves
	p.shove()
	check("no_shove_without_stamina", p.shoves == n)

	# ---- shield bash: shove with the shield up, and the shield stays up
	p.stamina = 100.0
	p.shove_cd = 0.0
	p.attacking = 0.0
	var s2 = dummy(Vector2(476, 520))
	p.hold_block = true
	p.block_start()
	p.shove()
	check("shield_bash_works", s2.has_status("stun") and p.blocking)
	p.block_end()

	# ---- a boss is not thrown around, but loses some stagger
	await frames(30)
	clear_foes()
	var boss = main.world.spawn_enemy("boss", Vector2(480, 520))
	await frames(5)
	p.global_position = Vector2(450, 520)
	p.facing = "right"
	p.shove_cd = 0.0
	p.stamina = 100.0
	p.attacking = 0.0
	boss.stag = 0.0
	p.shove()
	check("shove_feeds_boss_stagger", boss.stag > 0.0 or boss.staggered > 0.0, boss.stag)
	check("boss_not_stunned_by_shove", not boss.has_status("stun"))
	clear_foes()

	# ---- keys
	p = await hero("warrior")
	seen(p)
	p.stamina = 100.0
	Input.action_press("sneak")
	await frames(3)
	Input.action_release("sneak")
	await frames(3)
	check("key_toggles_sneak", p.sneaking)
	Input.action_press("sneak")
	await frames(3)
	Input.action_release("sneak")
	await frames(3)
	check("key_toggles_sneak_off", not p.sneaking)
	# (v0.26) the key and the button that were Shove now give the calling's own move
	n = p.sig_uses
	p.shove_cd = 0.0
	p.attacking = 0.0
	Input.action_press("shove")
	await frames(3)
	Input.action_release("shove")
	check("key_shoves", p.sig_uses == n + 1)

	# ---- touch
	var pad: Node = main.hud.pad
	var bs: Dictionary = pad.buttons()
	check("touch_has_sneak_and_shove", bs.has("sneak") and bs.has("shove"))
	var clear := true
	for x in bs:
		for y in bs:
			if x < y and bs[x]["pos"].distance_to(bs[y]["pos"]) < float(bs[x]["r"]) + float(bs[y]["r"]) + 4.0:
				clear = false
				printerr("OVERLAP ", x, " ", y)
	check("touch_buttons_dont_overlap", clear)
	var inside := true
	for x in bs:
		var q: Vector2 = bs[x]["pos"]
		if q.x < 0.0 or q.y < 0.0 or q.x > pad.size.x or q.y > pad.size.y:
			inside = false
	check("touch_buttons_on_screen", inside)
	var pos: Vector2 = pad.get_global_transform_with_canvas() * bs["sneak"]["pos"]
	touch(5, pos, true)
	await frames(2)
	touch(5, pos, false)
	await frames(2)
	check("touch_sneak_toggles", p.sneaking)
	p.sneaking = false
	p.shove_cd = 0.0
	p.stamina = 100.0
	p.attacking = 0.0
	n = p.sig_uses
	pos = pad.get_global_transform_with_canvas() * bs["shove"]["pos"]
	touch(6, pos, true)
	await frames(2)
	touch(6, pos, false)
	check("touch_shove", p.sig_uses == n + 1)

	# ---- left-handed layout mirrors the action cluster and moves the joystick to the right half
	var move_left: Vector2 = pad.get_global_transform_with_canvas() * Vector2(100, pad.size.y - 100)
	touch(7, move_left, true)
	await frames(2)
	check("right_hand_movement_starts_on_left", pad.joy_id == 7)
	touch(7, move_left, false)
	await frames(2)
	Game.set_setting("left_hand", true)
	var left_bs: Dictionary = pad.buttons()
	check("left_hand_action_cluster_mirrors", left_bs["attack"]["pos"].x < pad.size.x * 0.5 and left_bs["ult"]["pos"].x < pad.size.x * 0.5)
	p.shove_cd = 0.0
	p.stamina = 100.0
	p.attacking = 0.0
	n = p.sig_uses
	var left_shove: Vector2 = pad.get_global_transform_with_canvas() * left_bs["shove"]["pos"]
	touch(8, left_shove, true)
	await frames(2)
	touch(8, left_shove, false)
	check("left_hand_action_button_works", p.sig_uses == n + 1)
	var move_right: Vector2 = pad.get_global_transform_with_canvas() * Vector2(pad.size.x - 100, pad.size.y - 100)
	touch(9, move_right, true)
	await frames(2)
	check("left_hand_movement_starts_on_right", pad.joy_id == 9)
	touch(9, move_right, false)
	await frames(2)
	check("left_hand_cluster_stays_on_screen", left_bs.values().all(func(b): return b["pos"].x >= 0.0 and b["pos"].x <= pad.size.x))
	Game.set_setting("left_hand", false)

	print("STEALTHTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

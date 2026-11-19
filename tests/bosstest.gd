extends Node
## v18 boss checks.  godot --headless --fixed-fps 60 --path . -- --test res://tests/bosstest.gd [--bot] [--natural]
## Mechanics (default): boss health, intro card + tap to skip, stagger, phases, telegraphs, perfect dodge,
## wall/pillar crashes, pillar shield, magma armour, eggs, echoes, death -> rematch / respawn, victory,
## exit-safe knockback, touch controls, status effects, contact graze.
## --bot: a scripted player fights each story boss (as the HTML balance bot did); --natural uses the
## Godot hero's own stats instead of the HTML hero's (which include talents).

var main: Node
var results := {}
var fails: Array = []

const SPEC := {  # boss: map, spawn top-left in the HTML map, level, weapon tier, armour tier, HTML hero hp/atk
	"boss": ["dungeon", Vector2(850, 650), 4, 1, 0, 64.0, 20.0],
	"boss2": ["peaks", Vector2(560, 120), 7, 2, 1, 118.0, 31.0],
	"matriarch": ["shadowfen", Vector2(660, 120), 9, 3, 2, 134.0, 42.0],
	"arbiter": ["sanctum", Vector2(600, 140), 12, 4, 2, 158.0, 60.0],
	# (v0.19) chapter 2: no HTML numbers — the hero's own stats at the level and gear a player has by then
	"glaciertitan": ["frostvale", Vector2(1138, 488), 13, 5, 4, 0.0, 0.0],
	"ancientwyrm": ["wyrmhollow", Vector2(615, 825), 15, 6, 5, 0.0, 0.0],
	# (v0.23) chapter 3: the hero comes to Zahhak a few levels on, with the Derafsh-e Kaviani (+12% on Damavand)
	"zahhak": ["zahhakcave", Vector2(570, 698), 18, 6, 5, 0.0, 0.0],
}

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func secs(s: float) -> void:
	await frames(int(round(s * 60.0)))

func real(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func check(name: String, ok: bool, info = null) -> void:
	results[name] = {"ok": ok, "info": info} if info != null else ok
	if not ok:
		fails.append(name)
	printerr(("PASS " if ok else "FAIL ") + name + ("" if info == null else "  " + str(info)))

func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	Game.new_game("warrior")
	main.start_world()
	await frames(5)
	if Game.has_arg("--bot"):
		await bots()
	else:
		await mechanics()
	print("BOSSTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

## a fresh hero at the HTML route's level and gear, standing where the HTML bot stood
func arena(t: String, intro_seen := true, html_stats := true) -> Node:
	var s: Array = SPEC.get(t, ["dungeon", Vector2(850, 650), 4, 1, 0, 64.0, 20.0])
	Game.new_game("warrior")
	Game.state["level"] = s[2]
	Game.state["weapon"] = s[3]
	Game.state["armor"] = s[4]
	Game.state["potions"] = 5
	Game.test_hp = float(s[5]) if html_stats and float(s[5]) > 0.0 else -1.0
	Game.test_atk = float(s[6]) if html_stats and float(s[6]) > 0.0 else -1.0
	Game.hp = Game.max_hp()
	if t == "zahhak":
		Game.Ch3.st()["banner"] = true
	if intro_seen:
		Game.v18()["seen"][t] = true
	main.player.revive()
	main.player.refresh_look()
	main.goto_map(s[0], s[1] + Vector2(-200 + 13, 80 + 34))
	await frames(2)
	var b: Node = null
	for e in get_tree().get_nodes_in_group("bosses"):
		if e.type == t:
			b = e
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != b:
			e.queue_free()
	for a in get_tree().get_nodes_in_group("exits"):
		a.remove_from_group("exits")
		a.queue_free()
	await frames(1)
	return b

func hold(b: Node) -> void:
	b.busy = 1e6
	b.windup = false
	b.motion = {}

# ================================================================ mechanics
func mechanics() -> void:
	Game.table("CLASSES")["warrior"]["critChance"] = 0.0
	var bfx: Node

	printerr("STEP: boss health matches the HTML game (no double v18 bump)")
	var want := {"boss": 3047.0, "boss2": 4816.0, "matriarch": 9853.0, "arbiter": 16505.0}
	var got := {}
	for t in want:
		var b: Node = await arena(t)
		got[t] = b.max_hp if b else -1
	check("hp_matches_html", got == want, got)

	printerr("STEP: the name card plays once, pauses the world, ends by itself")
	Game.v18()["seen"].clear()
	var b: Node = await arena("boss", false)
	await frames(2)
	var shown: bool = main.hud.intro.on and get_tree().paused
	var name_ok: bool = main.hud.intro.name_l.text == Game.boss_name("boss")
	await real(3.1)
	check("intro_plays_and_ends", shown and name_ok and not main.hud.intro.on and not get_tree().paused and Game.v18()["seen"].has("boss"),
		{"shown": shown, "paused_after": get_tree().paused})
	main.goto_map("dungeon", Vector2(650 + 13, 730 + 34))
	await frames(4)
	check("second_meeting_banner_not_card", not main.hud.intro.on and main.hud.boss_ui.showing() and main.hud.boss_ui.banner_box.modulate.a > 0.0)

	printerr("STEP: tap skips the card (real touch event through the input pipeline)")
	Game.v18()["seen"].clear()
	b = await arena("boss", false)
	await frames(2)
	var was_on: bool = main.hud.intro.on
	var tap := InputEventScreenTouch.new()
	tap.index = 0
	tap.position = Vector2(427, 200)
	tap.pressed = true
	get_viewport().push_input(tap, true)
	await real(0.1)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = Vector2(427, 200)
	up.pressed = false
	get_viewport().push_input(up, true)
	await real(0.1)
	check("tap_skips_intro", was_on and not main.hud.intro.on and not get_tree().paused)

	printerr("STEP: stagger meter")
	b = await arena("boss")
	hold(b)
	b.inv = 0.0
	b.hurt(10.0, false, Vector2.RIGHT, true)
	var after_one: float = b.stag
	for i in 9:
		b.hurt(10.0, false, Vector2.RIGHT, true)
	var stg: bool = b.staggered > 3.0 and b.n_stag == 1 and is_equal_approx(b.res, 1.2)
	var h0: float = b.hp
	b.hurt(100.0, false, Vector2.ZERO)
	var during: float = h0 - b.hp
	b.staggered = 0.0
	h0 = b.hp
	b.hurt(100.0, false, Vector2.ZERO)
	var normal: float = h0 - b.hp
	b.stag = 50.0
	b.last_gain = 0.0
	await secs(1.0)
	check("stagger_heavy_adds_10", is_equal_approx(after_one, 10.0), after_one)
	check("stagger_after_100", stg, {"staggered": b.staggered, "res": b.res})
	check("staggered_takes_150pct", is_equal_approx(during, 150.0) and is_equal_approx(normal, 100.0), [during, normal])
	check("stagger_decays_6_per_s", abs(b.stag - 44.0) < 0.6, b.stag)

	printerr("STEP: phase change at 66%: invulnerable roar, banner, shockwave, and transient cleanup")
	b = await arena("boss2")
	hold(b)
	bfx = main.world.bossfx
	var phase2_pool_pos: Vector2 = b.center() + Vector2(360.0, 0.0)
	bfx.shoot(b, 2, 2.6, 0.5, Color8(95, 191, 90), "poison")
	bfx.pool(phase2_pool_pos, 96.0, 8.0, "poison", b, 0.5, ["poison", 3.0])
	var phase2_effects_seeded: bool = bfx.shots.size() == 2 and bfx.pool_at(phase2_pool_pos) == "poison"
	var phase_rings_before: int = main.world.fx.rings.size()
	b.hp = b.max_hp * 0.655
	await frames(2)
	var phase_rings_added: int = main.world.fx.rings.size() - phase_rings_before
	var ph_ok: bool = b.ph == 2 and b.inv > 1.0
	var phase2_effects_cleared: bool = bfx.shots.is_empty() and bfx.pools.is_empty() and bfx.pool_at(phase2_pool_pos) == ""
	h0 = b.hp
	b.hurt(500.0, false, Vector2.ZERO)
	var immune: bool = is_equal_approx(h0, b.hp)
	var ban: String = main.hud.boss_ui.banner_a.text
	var variant: String = b.anim.animation
	await secs(1.6)
	b.armor = false
	h0 = b.hp
	b.hurt(100.0, false, Vector2.ZERO)
	check("phase2_at_66", ph_ok and immune and ban == Game.t("Phase II", "مرحلهٔ دوم") and variant == "v1", {"ph": b.ph, "banner": ban, "variant": variant})
	var expected_phase_rings := 2 if main.world.fx.quality > 0 else 1
	check("phase_change_adds_quality_scaled_visual_rings", phase_rings_added >= expected_phase_rings,
		{"added": phase_rings_added, "expected": expected_phase_rings})
	check("phase2_clears_previous_projectiles_and_pools", phase2_effects_seeded and phase2_effects_cleared, {"seeded": phase2_effects_seeded, "shots_left": bfx.shots.size(), "pools_left": bfx.pools.size()})
	check("damage_after_phase_roar", h0 - b.hp > 99.0)
	var phase3_pool_pos: Vector2 = b.center() + Vector2(360.0, 0.0)
	bfx.shoot(b, 1, 2.6, 0.5, Color8(95, 191, 90), "poison")
	bfx.pool(phase3_pool_pos, 96.0, 8.0, "poison", b, 0.5, ["poison", 3.0])
	var phase3_effects_seeded: bool = bfx.shots.size() == 1 and bfx.pool_at(phase3_pool_pos) == "poison"
	b.hp = b.max_hp * 0.3
	await frames(2)
	var phase3_effects_cleared: bool = bfx.shots.is_empty() and bfx.pools.is_empty() and bfx.pool_at(phase3_pool_pos) == ""
	check("phase3_at_33", b.ph == 3 and main.hud.boss_ui.banner_a.text == Game.t("Final phase", "واپسین مرحله"))
	check("phase3_clears_previous_projectiles_and_pools", phase3_effects_seeded and phase3_effects_cleared, {"seeded": phase3_effects_seeded, "shots_left": bfx.shots.size(), "pools_left": bfx.pools.size()})

	printerr("STEP: telegraphs land; a roll through the strike is a perfect dodge")
	b = await arena("boss")
	hold(b)
	bfx = main.world.bossfx
	var p: Node = main.player
	p.invuln = 0.0
	var hp0: float = Game.hp
	bfx.circle(p.pc(), 60.0, 0.4, Color.RED, _tfire.bind(bfx, b, 1.0, {}), b)
	await secs(0.5)
	check("telegraph_circle_hits", Game.hp < hp0, hp0 - Game.hp)
	await secs(1.0)
	p.invuln = 0.0
	p.stamina = 100.0
	hp0 = Game.hp
	var st0: float = b.stag
	bfx.circle(p.pc(), 160.0, 0.4, Color.RED, _tfire.bind(bfx, b, 1.0, {}), b)
	await secs(0.25)
	p.facing = "left"
	p.dodge()
	await secs(0.3)
	check("perfect_dodge", is_equal_approx(Game.hp, hp0) and b.stag > st0 + 11.0 and bfx.counts["perfect"] == 1, {"stag": b.stag, "hp_lost": hp0 - Game.hp})
	await secs(1.0)
	p.invuln = 0.0
	hp0 = Game.hp
	bfx.lane(p.pc() + Vector2(-100, 0), p.pc() + Vector2(100, 0), 40.0, 0.3, Color.RED, _tfire.bind(bfx, b, 1.0, {}), b)
	await secs(0.4)
	var lane_hit: bool = Game.hp < hp0
	await secs(1.0)
	p.invuln = 0.0
	hp0 = Game.hp
	bfx.cone(p.pc() + Vector2(-60, 0), 112.0, PI, 0.5, 0.3, Color.RED, _tfire.bind(bfx, b, 1.0, {}), b)
	await secs(0.4)
	check("lane_hits_cone_aims", lane_hit and is_equal_approx(Game.hp, hp0))
	p.invuln = 0.0
	hp0 = Game.hp
	var v: Dictionary = bfx.vol()
	var hits0: int = int(bfx.counts["hits"])
	for i in 4:
		bfx.circle(p.pc(), 60.0, 0.2 + i * 0.05, Color.RED, _tfire.bind(bfx, b, 0.5, v), b)
	await secs(0.5)
	p.invuln = 0.0
	var vol_hits: int = int(bfx.counts["hits"]) - hits0
	check("volley_hits_once", v["hit"] == true and vol_hits == 1, vol_hits)

	printerr("STEP: charge into a wall or a grave pillar staggers Arzhang")
	b = await arena("boss")
	hold(b)
	b.busy = 0.0
	b.global_position = Vector2(60, 400)
	b._dash(PI, 7.6, 2.0, 1.3)
	await secs(0.5)
	var wall_st: bool = b.staggered > 0.0 and b.n_stag == 1
	b.staggered = 0.0
	b.global_position = Vector2(400, 400)
	var pil: Node = main.world.spawn_arena("gravepillar", Vector2(520, 420), {"hp": 60.0, "owner": b})
	b.pillars = [pil]
	hold(b)
	b.busy = 0.0
	b._dash(0.0, 7.6, 2.0, 1.3)
	await secs(0.5)
	check("charge_wall_staggers", wall_st)
	var pdead: bool = not is_instance_valid(pil) or pil.dead
	check("charge_breaks_pillar_and_staggers", pdead and b.n_stag == 2, {"pillar_dead": pdead, "n_stag": b.n_stag})

	printerr("STEP: grave pillars shield Arzhang (20% each, at least 40% gets through)")
	b.staggered = 0.0
	b.inv = 0.0
	b.shield = 2
	h0 = b.hp
	b.hurt(100.0, false, Vector2.ZERO)
	var two: float = h0 - b.hp
	b.shield = 4
	h0 = b.hp
	b.hurt(100.0, false, Vector2.ZERO)
	var four: float = h0 - b.hp
	check("pillar_shield", is_equal_approx(two, 70.0) and is_equal_approx(four, 55.0), [two, four])     # (v0.23) 15% a pillar, at most 45%
	b.shield = 0
	hold(b)
	b.busy = 0.0
	b.gcd = 0.0
	b.ph = 2
	b.cd.clear()
	b.global_position = main.player.global_position + Vector2(200, 0)
	await frames(2)
	var n_pillars: int = main.world.count_arena("gravepillar")
	check("phase2_raises_pillars", n_pillars >= 2 and b.moves.get("pillars", 0) == 1, n_pillars)

	printerr("STEP: the King's magma armour halves damage until the eruption vents his core")
	b = await arena("boss2")
	await frames(2)
	hold(b)
	var arm: bool = b.armor
	h0 = b.hp
	b.hurt(100.0, false, Vector2.ZERO)
	var armoured: float = h0 - b.hp
	b._fire_erupt({}, b.center(), 1)
	var vented: bool = b.vent > 5.0 and b.heat == 0.0 and not b.armor
	h0 = b.hp
	b.hurt(100.0, false, Vector2.ZERO)
	var open_core: float = h0 - b.hp
	check("magma_armour", arm and is_equal_approx(armoured, 50.0) and vented and is_equal_approx(open_core, 100.0), [armoured, open_core])
	check("eruption_shockwave", main.world.bossfx.waves.size() == 1)
	b.apply_status("freeze", 2.0)
	check("ice_feeds_stagger_not_freeze", not b.has_status("freeze") and b.stag > 0.0, b.stag)

	printerr("STEP: bog eggs hatch after 7 s; fire burns them")
	b = await arena("matriarch")
	hold(b)
	var spot: Vector2 = main.player.global_position + Vector2(-90, 0)
	var egg: Node = main.world.spawn_arena("bogegg", spot, {"hp": 30.0, "owner": b, "hatch": 7.0, "kids": ["mosquito", "mosquito"]})
	var n_en0 := get_tree().get_nodes_in_group("enemies").size()
	await secs(6.5)
	var still_egg: bool = is_instance_valid(egg) and not egg.dead
	await secs(0.8)
	var kids := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.type == "mosquito":
			kids += 1
	check("egg_hatches_at_7s", still_egg and kids == 2, {"enemies_before": n_en0, "kids": kids})
	var egg2: Node = main.world.spawn_arena("bogegg", spot + Vector2(0, 40), {"hp": 30.0, "owner": b, "hatch": 7.0, "kids": ["mosquito"]})
	egg2.apply_status("burn", 2.5)
	check("fire_burns_egg", egg2.dead)

	printerr("STEP: the Sorceress dives, surfaces under the hero, and is dazed")
	b = await arena("matriarch")
	hold(b)
	b.busy = 0.0
	b.gcd = 0.0
	b.cd.clear()
	b.cd["eggs"] = 99.0
	b.global_position = main.player.global_position + Vector2(120, -30)
	await frames(2)
	var dove: bool = b.cloaked and b.shadow_on
	await secs(2.6)
	check("dive_and_surface", dove and not b.cloaked and b.global_position.distance_to(main.player.global_position) < 120.0 and b.moves.get("dive", 0) == 1,
		{"dist": b.global_position.distance_to(main.player.global_position)})

	printerr("STEP: ice echoes: break both within 7 s for a big stagger")
	b = await arena("arbiter")
	hold(b)
	bfx = main.world.bossfx
	var e1: Node = main.world.spawn_arena("arbiterclone", main.player.global_position + Vector2(80, -60), {"hp": 1.0, "owner": b, "born": bfx.clock, "speed": 0.0})
	var e2: Node = main.world.spawn_arena("arbiterclone", main.player.global_position + Vector2(-80, -60), {"hp": 1.0, "owner": b, "born": bfx.clock, "speed": 0.0})
	await frames(2)
	e1.hurt(5.0, false, Vector2.ZERO)
	e2.hurt(5.0, false, Vector2.ZERO)
	var shattered: float = b.stag
	b.stag = 0.0
	var e3: Node = main.world.spawn_arena("arbiterclone", main.player.global_position + Vector2(80, -60), {"hp": 1.0, "owner": b, "born": bfx.clock - 8.0, "speed": 0.0})
	e3.hurt(5.0, false, Vector2.ZERO)
	check("echoes_shatter_bonus", is_equal_approx(shattered, 45.0) and b.stag == 0.0, shattered)

	printerr("STEP: contact with a rebuilt boss only grazes (25%, once per 1.5 s)")
	b = await arena("boss")
	hold(b)
	p = main.player
	p.invuln = 0.0
	hp0 = Game.hp
	b.global_position = p.global_position + Vector2(10, 0)
	await secs(1.0)
	var graze: float = hp0 - Game.hp
	check("contact_graze", graze >= 1.0 and graze <= float(Game.incoming(round(b.dmg * 0.25), "dungeon")), {"lost": graze, "boss_dmg": b.dmg})

	printerr("STEP: boss knockback never shoves the hero through a map exit")
	Game.new_game("warrior")
	main.player.revive()
	main.goto_map("dungeon", Vector2(470, 700))
	await frames(40)
	var ex: Area2D = null
	for a in get_tree().get_nodes_in_group("exits"):
		ex = a
	var er: Rect2 = ex.get_meta("rect")
	var outside := er.get_center() + Vector2(0, er.size.y * 0.5 + 40)
	if outside.y > main.world.size.y - 5:
		outside = er.get_center() - Vector2(0, er.size.y * 0.5 + 6)
	main.player.global_position = outside
	await frames(2)
	main.player.knock((er.get_center() - main.player.pc()).normalized() * 80.0)
	await frames(6)
	check("knock_never_through_exit", main.world.key == "dungeon" and not main.player.body_rect().intersects(er), {"map": main.world.key})

	printerr("STEP: death in a boss fight -> Rematch (gold back, potions back, at the arena)")
	b = await arena("boss")
	await frames(3)
	Game.state["gold"] = 500
	Game.state["potions"] = 5
	main._on_engage(b)
	Game.state["potions"] = 1
	main.player.invuln = 0.0
	main.player.take_hit(99999.0)
	await real(1.4)
	var panel: Control = main.hud.death
	var offered: bool = panel.visible and panel.re_btn.visible and get_tree().paused
	var gold_lost: int = 500 - int(Game.state["gold"])
	await click(panel.re_btn)
	await frames(4)
	var nb: Node = null
	for e in get_tree().get_nodes_in_group("bosses"):
		nb = e
	check("rematch_offered_without_gold_deduction", offered and gold_lost == 0, {"gold_lost": gold_lost})
	check("rematch_restores", not get_tree().paused and int(Game.state["gold"]) == 500 and int(Game.state["potions"]) == 5
		and not main.player.dead and Game.hp == Game.max_hp() and main.world.key == "dungeon" and nb != null and nb.hp == nb.max_hp,
		{"gold": Game.state["gold"], "potions": Game.state["potions"], "map": main.world.key})
	check("rematch_quiet_no_card", not main.hud.intro.on)
	main.player.invuln = 0.0
	main.player.take_hit(99999.0)
	await real(1.4)
	await click(main.hud.death.home_btn)
	await frames(4)
	check("respawn_in_village", main.world.key == "village" and int(Game.state["gold"]) == 400 and not get_tree().paused, {"map": main.world.key, "gold": Game.state["gold"]})

	printerr("STEP: boss death clears active projectiles and damaging pools")
	b = await arena("boss")
	await frames(3)
	bfx = main.world.bossfx
	var death_pool_pos: Vector2 = b.center() + Vector2(360.0, 0.0)
	bfx.shoot(b, 2, 2.6, 0.5, Color8(95, 191, 90), "poison")
	bfx.pool(death_pool_pos, 96.0, 8.0, "poison", b, 0.5, ["poison", 3.0])
	var death_effects_seeded: bool = bfx.shots.size() == 2 and bfx.pool_at(death_pool_pos) == "poison"
	Game.set_q(1, "active")
	main.world.spawn_arena("gravepillar", main.player.global_position + Vector2(100, 0), {"hp": 60.0, "owner": b})
	b.hurt(1e9, false, Vector2.ZERO)
	var death_effects_cleared: bool = bfx.shots.is_empty() and bfx.pools.is_empty() and bfx.pool_at(death_pool_pos) == ""
	check("boss_death_clears_projectiles_and_pools", death_effects_seeded and death_effects_cleared, {"seeded": death_effects_seeded, "shots_left": bfx.shots.size(), "pools_left": bfx.pools.size()})
	await frames(30)
	check("victory", main.hud.boss_ui.banner_a.text == Game.t("DUST AGAIN", "به خاک برگشت") and Game.fight.is_empty() and main.world.count_arena("gravepillar") == 0
		and int(Game.v18()["kills"].get("boss", 0)) == 1 and Game.q(1) == "complete" and not main.hud.boss_ui.showing(), {"banner": main.hud.boss_ui.banner_a.text, "q1": Game.q(1)})

	printerr("STEP: touch controls: stick, attack button, release during a pause")
	Game.new_game("warrior")
	main.player.revive()
	main.goto_map("village", Vector2(433, 524))
	await frames(10)
	var x0: float = main.player.global_position.x
	touch(0, Vector2(150, 300), true)
	drag(0, Vector2(200, 300))
	await frames(20)
	var walked: float = main.player.global_position.x - x0
	get_tree().paused = true
	touch(0, Vector2(200, 300), false)
	await real(0.05)
	get_tree().paused = false
	var stick_freed: bool = main.player.joy == Vector2.ZERO
	var ab: Dictionary = main.hud.pad.buttons()["attack"]
	touch(1, ab["pos"], true)
	await frames(2)
	var swung: bool = main.player.attacking > 0.0 or main.player.hold_attack
	touch(1, ab["pos"], false)
	await frames(2)
	check("touch_stick_moves", walked > 40.0, walked)
	check("touch_release_while_paused", stick_freed)
	check("touch_attack_button", swung and not main.player.hold_attack)

	printerr("STEP: status effects on the hero: poison ticks, freeze slows")
	main.player.invuln = 0.0
	hp0 = Game.hp
	main.player.apply_status("poison", 1.3, 1.0)
	await secs(1.4)
	var poison_lost: float = hp0 - Game.hp
	x0 = main.player.global_position.x
	main.player.joy = Vector2(1, 0)
	await frames(20)
	var free_walk: float = main.player.global_position.x - x0
	main.player.apply_status("freeze", 2.0, 1.0)
	x0 = main.player.global_position.x
	await frames(20)
	var frozen_walk: float = main.player.global_position.x - x0
	main.player.joy = Vector2.ZERO
	check("poison_ticks", poison_lost >= 2.0 and poison_lost <= 4.0 and not main.player.statuses.has("poison"), poison_lost)
	check("freeze_halves_speed", abs(frozen_walk - free_walk * 0.5) < 3.0, [free_walk, frozen_walk])

	printerr("STEP: hazards as in the HTML game: lava burns, ice freezes, Sorceress pools poison")
	Game.new_game("warrior")
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	main.player.revive()
	main.goto_map("peaks", Vector2(400, 600))
	await frames(4)
	var lava: Rect2 = main.world.hazards[0]["rect"]
	main.player.global_position = lava.get_center() + Vector2(0, 17)
	main.player.invuln = 0.0
	hp0 = Game.hp
	await frames(3)
	check("peaks_lava_hurts", main.world.hazards[0]["type"] == "lava" and Game.hp < hp0,
		{"lost": hp0 - Game.hp, "dead": main.player.dead, "paused": get_tree().paused})
	main.goto_map("sanctum", Vector2(600, 700))
	await frames(4)
	var ice: Rect2 = main.world.hazards[0]["rect"]
	main.player.global_position = ice.get_center() + Vector2(0, 17)
	await frames(3)
	check("sanctum_ice_freezes", main.player.statuses.has("freeze"))
	main.player.global_position = Vector2(600, 760)
	main.player.statuses.clear()
	main.world.bossfx.pool(main.player.pc(), 100.0, 6.0)
	main.player.invuln = 0.0
	hp0 = Game.hp
	await frames(3)
	check("pool_poisons", main.player.statuses.has("poison") and Game.hp < hp0)

	printerr("STEP: aim assist: a swing turns to a diagonal enemy and hits it")
	main.goto_map("forest", Vector2(560, 470))
	await frames(4)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await frames(2)
	var dg: Node = main.world.spawn_enemy("golem", main.player.global_position + Vector2(34, 30))
	dg.spd = 0.0
	main.player.facing = "up"
	main.player.atk_cd = 0.0
	h0 = dg.hp
	main.player.attack()
	check("aim_assist_diagonal", dg.hp < h0 and main.player.facing != "up", {"facing": main.player.facing})

	printerr("STEP: hints do not follow you to another map; the hero is drawn over a boss standing on him")
	b = await arena("boss2")
	main.hud.boss_ui.tip("test hint")
	await frames(2)
	main.goto_map("village", Vector2(433, 524))
	await frames(2)
	check("tip_cleared_on_map_change", main.hud.notify.showing_text() == "" and main.hud.notify.queue.is_empty())
	b = await arena("matriarch")
	hold(b)
	b.global_position = main.player.global_position + Vector2(0, 8)
	await frames(2)
	check("hero_drawn_over_boss", main.player.z_index == 1)
	b.global_position = main.player.global_position + Vector2(300, 0)
	await frames(2)
	check("hero_back_to_ysort", main.player.z_index == 0)

## fire callback for test telegraphs: hit if the hero is inside (a non-empty volley dict = hit once)
func _tfire(t: Dictionary, bfx: Node, b: Node, mult: float, v: Dictionary) -> void:
	if not bfx.inside(t):
		return
	if v.has("hit"):
		bfx.hit_v(v, b, mult)
	else:
		bfx.hit(b, mult)

func click(btn: Control) -> void:
	var c := btn.get_global_rect().get_center()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = c
	ev.global_position = c
	ev.pressed = true
	get_viewport().push_input(ev, true)
	await real(0.05)
	var ev2 := ev.duplicate()
	ev2.pressed = false
	get_viewport().push_input(ev2, true)
	await real(0.05)

func touch(i: int, pos: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = i
	ev.position = pos
	ev.pressed = down
	get_viewport().push_input(ev, true)

func drag(i: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = i
	ev.position = pos
	get_viewport().push_input(ev, true)

# ================================================================ balance bot
## (v0.21) a hero at the end of chapter 2 in a memory of the Boss Rush (scripts/rush.gd ORDER[i]): the run's own boss health
## and damage, the memory's potions; `--level N` (default 16)
func rush_arena(i: int) -> Node:
	var R = load("res://scripts/rush.gd")
	var e: Array = R.ORDER[i]
	var lv := 16
	var li := Game.args.find("--level")
	if li >= 0 and li + 1 < Game.args.size():
		lv = int(Game.args[li + 1])
	Game.rush = {}
	Game.new_game("warrior")
	Game.state["level"] = lv
	Game.state["weapon"] = 6
	Game.state["armor"] = 5
	Game.state["potions"] = R.POUCH
	Game.test_hp = -1.0
	Game.test_atk = -1.0
	Game.hp = Game.max_hp()
	Game.v18()["seen"][str(e[0])] = true
	Game.rush = {"i": i, "type": e[0], "map": e[1], "hp": e[3], "dmg": e[4], "elapsed": 0.0, "drank": 0}
	main.player.revive()
	main.player.refresh_look()
	main.goto_map(str(e[1]), e[2])
	await frames(2)
	var b: Node = null
	for x in get_tree().get_nodes_in_group("bosses"):
		if x.type == str(e[0]):
			b = x
	return b

func bots() -> void:
	if Game.has_arg("--rush"):
		var R = load("res://scripts/rush.gd")
		var rruns := 1
		var rj := Game.args.find("--runs")
		if rj >= 0 and rj + 1 < Game.args.size():
			rruns = int(Game.args[rj + 1])
		var ronly := ""
		var ri := Game.args.find("--boss")
		if ri >= 0 and ri + 1 < Game.args.size():
			ronly = Game.args[ri + 1]
		for idx in R.ORDER.size():
			var rt: String = str(R.ORDER[idx][0])
			if ronly != "" and rt != ronly:
				continue
			for k in rruns:
				var res: Dictionary = await fight(rt, false, idx)
				results["rush_%s_%d" % [rt, k]] = res
				printerr("BOT rush ", rt, " ", JSON.stringify(res))
		Game.rush = {}
		return
	var natural := Game.has_arg("--natural")
	var only := ""
	var i := Game.args.find("--boss")
	if i >= 0 and i + 1 < Game.args.size():
		only = Game.args[i + 1]
	var runs := 1
	var j := Game.args.find("--runs")
	if j >= 0 and j + 1 < Game.args.size():
		runs = int(Game.args[j + 1])
	for t in SPEC:
		if only != "" and t != only:
			continue
		for k in runs:
			var res: Dictionary = await fight(t, not natural)
			results["%s_%d" % [t, k]] = res
			printerr("BOT ", t, " ", JSON.stringify(res))

func fight(t: String, html_stats: bool, rush_i := -1) -> Dictionary:
	var b: Node = (await rush_arena(rush_i)) if rush_i >= 0 else (await arena(t, true, html_stats))
	var p: Node = main.player
	var bfx: Node = main.world.bossfx
	if p.died.is_connected(main._on_died):
		p.died.disconnect(main._on_died)
	var deaths := [0]
	var on_die := func():
		deaths[0] += 1
		p.revive()
	p.died.connect(on_die)
	var st := {"t0": -1.0, "ttk": -1.0, "pots0": int(Game.state["potions"]), "dodges": 0, "lp": p.global_position,
		"stuck": 0.0, "side": 0.0, "sv": Vector2.ZERO, "pt": 0.0, "think": 0.0, "ft": 0.0}
	var t_sim := 0.0
	var cap := 200.0
	p.damage_taken = 0.0
	p.swings = 0
	p.hits_landed = 0
	var start_info := {"lvl": Game.lvl(), "hp": Game.max_hp(), "atk": Game.atk(), "def": Game.defense(), "bossHp": b.max_hp, "bossDmg": b.dmg}
	while t_sim < cap:
		await get_tree().physics_frame
		var dt := 1.0 / 60.0
		t_sim += dt
		if get_tree().paused:
			# (v0.23) a story line that opened over the arena (Sorush after Zahhak): read on
			if main.hud.dialogue.visible:
				main.hud.dialogue._block_until = 0
				main.hud.dialogue.advance()
			continue
		if not is_instance_valid(b) or b.dead:
			if st["ttk"] < 0.0:
				st["ttk"] = st["ft"]
			break
		st["ft"] = b.fight_t
		if st["t0"] < 0.0 and b.engaged:
			st["t0"] = t_sim
		st["think"] -= dt
		if st["think"] > 0.0:
			continue
		st["think"] += 0.1
		_bot_step(b, p, bfx, st, t_sim)
	p.joy = Vector2.ZERO
	p.died.disconnect(on_die)
	p.died.connect(main._on_died)
	var out := start_info.duplicate()
	var alive: bool = is_instance_valid(b) and not b.dead
	out.merge({"ttk": snapped(st["ttk"], 0.1) if st["ttk"] >= 0.0 else -1, "bossLeft%": int(100.0 * b.hp / b.max_hp) if alive else 0,
		"taken%": int(100.0 * p.damage_taken / Game.max_hp()), "pots": int(st["pots0"]) - int(Game.state["potions"]), "deaths": deaths[0],
		"stag": b.n_stag if is_instance_valid(b) else -1, "phases": b.phase_at if is_instance_valid(b) else {}, "moves": b.moves if is_instance_valid(b) else {},
		"dodges": st["dodges"], "perfect": bfx.counts["perfect"], "tele": bfx.counts["tele"],
		"dmg_by": _pct(bfx.dmg_by, Game.max_hp()), "swings": p.swings, "hits": p.hits_landed,
		"inreach_s": snapped(st.get("inreach", 0.0), 0.1), "walk_s": snapped(st.get("walk", 0.0), 0.1), "idle_s": snapped(st.get("idle", 0.0), 0.1)})
	Game.test_hp = -1.0
	Game.test_atk = -1.0
	return out

static func _pct(d: Dictionary, mx: float) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = int(round(100.0 * float(d[k]) / mx))
	return out

func _danger(bfx: Node, p: Node) -> Variant:
	var pc: Vector2 = p.pc()
	for t in bfx.tele:
		if not t.has("_bot"):
			t["_bot"] = (0.15 + randf() * 0.15) if randf() < 0.75 else -1.0
		if t["_bot"] < 0.0 or float(t["t"]) > float(t["_bot"]) + 0.12:
			continue
		var inside := false
		var away := Vector2.ZERO
		match str(t["kind"]):
			"circle":
				inside = bfx.in_circle(t, 14.0)
				away = pc - t["pos"]
			"lane":
				inside = bfx.in_lane(t)
				var lv: Vector2 = t["b"] - t["pos"]
				var sg := 1.0 if (pc - t["pos"]).cross(lv) >= 0.0 else -1.0
				away = Vector2(lv.y * sg, -lv.x * sg)
			"cone":
				inside = bfx.in_cone(t)
				away = pc - t["pos"]
		if inside:
			return away
	for w in bfx.waves:
		if not w.has("_bot"):
			w["_bot"] = randf() < 0.75
		if not w["_bot"]:
			continue
		var d: float = pc.distance_to(w["pos"])
		if d - float(w["r"]) > 0.0 and d - float(w["r"]) < 45.0:
			return w["pos"] - pc
	for l in bfx.lobs:
		if not l.has("_bot"):
			l["_bot"] = (0.15 + randf() * 0.15) if randf() < 0.75 else -1.0
		if l["_bot"] < 0.0 or float(l["t"]) > float(l["_bot"]) + 0.12:
			continue
		if pc.distance_to(l["to"]) < float(l["r"]) + 14.0:
			return pc - l["to"]
	return null

func _bot_step(b: Node, p: Node, bfx: Node, st: Dictionary, now: float) -> void:
	if Game.hp < Game.max_hp() * 0.35 and int(Game.state["potions"]) > 0 and now > st["pt"]:
		p.drink()
		st["pt"] = now + 0.9
	var dg = _danger(bfx, p)
	if dg != null and p.dodge_cd <= 0.0 and p.stamina >= 30.0:
		var dv: Vector2 = dg
		if dv.length() < 2.0:
			dv = Vector2.from_angle(randf() * TAU)
		p.joy = dv.normalized()
		p.dodge()
		st["dodges"] += 1
		return
	var pc: Vector2 = p.pc()
	var tgt: Node = b
	for a in get_tree().get_nodes_in_group("arena"):
		if not a.dead and a.center().distance_to(pc) < 420.0:
			tgt = a
			break
	if tgt == b and b.cloaked:
		p.joy = Vector2.ZERO
		st["idle"] = st.get("idle", 0.0) + 0.1
		return
	var to: Vector2 = tgt.center() - pc - Vector2(0, 5)
	var d := to.length()
	var reach: float = max(tgt.box.x, tgt.box.y) * 0.5 + 30.0
	p.facing = p._dir_name(to)
	if d > reach:
		st["walk"] = st.get("walk", 0.0) + 0.1
		if now < st["side"]:
			p.joy = st["sv"]
			return
		if p.global_position.distance_to(st["lp"]) < 1.5:
			st["stuck"] += 0.1
		else:
			st["stuck"] = 0.0
		st["lp"] = p.global_position
		if st["stuck"] >= 0.6:
			st["stuck"] = 0.0
			var s := 1.0 if randf() < 0.5 else -1.0
			st["sv"] = Vector2(-to.y, to.x).normalized() * s
			st["side"] = now + 0.65
			p.joy = st["sv"]
			return
		p.joy = to / d
	else:
		st["inreach"] = st.get("inreach", 0.0) + 0.1
		p.joy = Vector2.ZERO
		p.attack()

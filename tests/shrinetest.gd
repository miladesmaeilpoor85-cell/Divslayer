extends Node
## v0.18 checks: the seven puzzle shrines. Every shrine is built from its data and solved through its own mechanics —
## the burning blade, braziers, brambles and the oil trail; pushing stone blocks onto plates and the lever; the powder
## barrel and the cracked wall, foes in the lava; the frost crystal freezing water (and thawing), the storm crystal, the
## plate and no foe left; mirrors, the ice wall and the light; the runes in the mosaic's order and two timed braziers;
## the Watchers' sight and hearing, sneaking through the grass. Then the altar (gold, treasure, the sigil and its gift),
## a solved shrine seen again, saving, the gates and pillars of light, the compass, spells on the pieces.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/shrinetest.gd

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

func enter(k: String) -> Node:
	var d: Dictionary = Game.map_data(k).get("data", {})
	var ps: Dictionary = d.get("playerStart", {"x": 327, "y": 443})
	main.goto_map(k, Vector2(float(ps["x"]) + 13.0, float(ps["y"]) + 34.0))
	await frames(4)
	main.player.invuln = 99999.0
	Game.hp = Game.max_hp()
	return main.world.shrine

## hold every foe still, far from the puzzle
func still_foes() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.spd = 0.0

func kill_foes() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead:
			e.hurt(99999.0, false, Vector2.ZERO)
	await frames(20)

func obj(sh, t: String, id := "") -> Variant:
	for o in sh.objs:
		if o["t"] == t and (id == "" or o["id"] == id):
			return o
	return null

func hit(sh, o) -> void:
	sh.strike(o["rect"].grow(2.0), Vector2.UP, false)

## the hero walks to a spot (teleport) and stands there a few frames
func stand(at: Vector2, n := 3) -> void:
	main.player.global_position = at
	main.player.velocity = Vector2.ZERO
	await frames(n)

func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	Game.lang = "en"
	Game.new_game("warrior")
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	Game.state["level"] = 10
	main.start_world()
	await frames(10)

	# ---- data: seven shrines, each with its layout, reward, tablet and a door that wants something
	var list: Array = Game.table("V16_SHRINE_LIST")
	var ok_data := list.size() == 7
	for s in list:
		ok_data = ok_data and str(s["key"]) in Game.SHRINE_ORDER and (s["layout"] as Array).size() == 13 and int(s["gold"]) > 0 and not (s["tablets"] as Array).is_empty()
	check("seven_shrines_in_data", ok_data, list.size())

	await _embers()
	await _weight()
	await _fuse()
	await _tides()
	await _light()
	await _echoes()
	await _shadows()
	await _altar_and_after()
	await _spells()
	# the shrine's name in the map title follows the language (it showed in English before)
	var lang0: String = Game.lang
	Game.lang = "fa"
	var fa_name: String = Game.map_title("shrine_embers")
	Game.lang = "en"
	var en_name: String = Game.map_title("shrine_embers")
	Game.lang = lang0
	check("shrine_title_in_both_languages", fa_name == "زیارتگاهِ اخگر" and en_name == "Shrine of Embers", [fa_name, en_name])
	print("SHRINETEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

# ---------------------------------------------------------------- embers: fire on the blade, braziers, brambles, oil
func _embers() -> void:
	var sh = await enter("shrine_embers")
	check("embers_built", sh != null and sh.objs.filter(func(o): return o["t"] == "brazier").size() == 3 and sh.water.size() == 8 and not sh.oil.is_empty(),
		sh.objs.size() if sh else -1)
	check("embers_door_shut", not sh.door_open and sh.needs() == ["f0", "f1", "f2"])
	# the door blocks the way to the altar
	var door = obj(sh, "door")
	check("door_is_solid", main.world.wall_hit(door["rect"].grow(-4.0)))
	# without fire a blow does nothing to a brazier
	var f0 = sh.by_id["f0"]
	hit(sh, f0)
	check("cold_blade_lights_nothing", not f0["lit"])
	# the real blow: stand under the eternal flame, face it, swing (player.attack -> shrine.strike)
	var src = obj(sh, "source")
	await stand(Vector2(src["rect"].get_center().x, src["rect"].end.y + 36.0))
	main.player.facing = "up"
	main.player.atk_cd = 0.0
	main.player.attack()
	# The flame is ignited when the Warrior Starter's contact frame executes.
	await frames(7)
	check("eternal_flame_lights_the_blade", sh.fire_t > 8.0, sh.fire_t)
	hit(sh, f0)
	check("burning_blade_lights_brazier", f0["lit"])
	# the brambles burn away and the hidden brazier can be reached
	var br = obj(sh, "bramble")
	hit(sh, br)
	await frames(70)
	check("bramble_burns_away", float(br["burn"]) >= 1.0 and not br["on"] and not main.world.wall_hit(br["rect"].grow(-6.0)))
	hit(sh, sh.by_id["f2"])
	# the oil: strike its end on the shore, the fire runs over the water to the last brazier
	sh.fire_t = 5.0
	var p0: Vector2 = sh.oil["pts"][0]
	sh.strike(Rect2(p0 - Vector2(10, 10), Vector2(20, 20)), Vector2.RIGHT, false)
	check("oil_catches_fire", sh.oil["lit"])
	await frames(90)
	check("oil_lights_far_brazier", sh.oil["done"] and sh.by_id["f1"]["lit"])
	await frames(5)
	check("embers_door_opens", sh.door_open and Game.shrine("shrine_embers")["door"] and not main.world.wall_hit(door["rect"].grow(-4.0)))
	# the blade cools
	sh.fire_t = 0.5
	await frames(40)
	check("blade_cools", sh.fire_t == 0.0)

# ---------------------------------------------------------------- weight: blocks, plates, the lever
func _weight() -> void:
	var sh = await enter("shrine_weight")
	still_foes()
	var b0 = sh.by_id["b0"]
	var b1 = sh.by_id["b1"]
	check("weight_built", b0 != null and b1 != null and sh.by_id["p0"]["heavy"] and sh.needs() == ["p0", "p1"])
	await stand(Vector2(120, 470))
	# the hero standing on a heavy plate does not press it
	await stand(sh.by_id["p0"]["rect"].get_center() + Vector2(0, 16))
	check("hero_cannot_press_heavy_plate", not sh.pressed(sh.by_id["p0"]))
	await stand(Vector2(120, 470))
	# a block does not go into a wall
	check("block_stops_at_wall", not sh.push(b0, Vector2i(0, 1)) and b0["cell"] == Vector2i(6, 7))
	# leaning on a block with the stick pushes it one cell
	await stand(sh.cell_rect(Vector2i(5, 7)).end - Vector2(20, 2), 2)
	main.player.joy = Vector2(1, 0)
	await frames(30)
	main.player.joy = Vector2.ZERO
	await frames(15)
	check("lean_pushes_block", b0["cell"] == Vector2i(7, 7), b0["cell"])
	await stand(Vector2(120, 470))
	# the lever puts the stones back
	sh.reset_stones()
	await frames(2)
	check("lever_resets_blocks", b0["cell"] == Vector2i(6, 7))
	# solve: b0 right then up three; b1 left then up three
	var ok: bool = sh.push(b0, Vector2i(1, 0))
	for i in 3:
		ok = ok and sh.push(b0, Vector2i(0, -1))
	ok = ok and sh.push(b1, Vector2i(-1, 0))
	for i in 3:
		ok = ok and sh.push(b1, Vector2i(0, -1))
	await frames(20)
	check("blocks_reach_plates", ok and b0["cell"] == Vector2i(7, 4) and b1["cell"] == Vector2i(9, 4), [b0["cell"], b1["cell"]])
	check("weight_door_opens", sh.door_open)

# ---------------------------------------------------------------- fuse: the barrel, the blast, the lava
func _fuse() -> void:
	var sh = await enter("shrine_fuse")
	still_foes()
	var bar = obj(sh, "barrel")
	await stand(Vector2(560, 470))
	var ok: bool = true
	for i in 6:
		ok = ok and sh.push(bar, Vector2i(1, 0))
	for i in 4:
		ok = ok and sh.push(bar, Vector2i(0, -1))
	await frames(12)
	check("barrel_beside_cracked_wall", ok and bar["cell"] == Vector2i(8, 4), bar["cell"])
	# an imp thrown into the lava burns
	var imp = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead and e.type == "imp":
			imp = e
	if imp:
		imp.global_position = Vector2(120, 250)
		await frames(3)
	check("foe_in_lava_dies", imp != null and imp.dead)
	# fire from the eternal flame, light the fuse, stand clear
	hit(sh, obj(sh, "source"))
	hit(sh, bar)
	check("fuse_lit", bar["lit"])
	var hp0 := Game.hp
	await frames(int(sh.FUSE_SEC * 60.0) + 20)
	check("blast_breaks_cracked_wall", sh.door_open and not obj(sh, "cracked")["on"])
	check("standing_clear_is_safe", Game.hp == hp0, [hp0, Game.hp])
	# the barrel comes back for another try
	await frames(120)
	check("barrel_respawns", bar["on"] and bar["cell"] == bar["home"])

# ---------------------------------------------------------------- tides: frost, ice paths, the storm, the plate
func _tides() -> void:
	var sh = await enter("shrine_tides")
	still_foes()
	check("tides_built", sh.water.size() == 38 and sh.needs() == ["p0", "clear"], sh.water.size())
	# deep water is a wall
	check("deep_water_blocks", main.world.wall_hit(sh.cell_rect(Vector2i(4, 6)).grow(-6.0)))
	# the storm: toads standing in water are struck down
	var toads := []
	var wet := [Vector2i(5, 9), Vector2i(10, 9), Vector2i(4, 10)]
	var i := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead and i < wet.size():
			e.global_position = sh.cell_rect(wet[i]).end - Vector2(20, 6)
			toads.append(e)
			i += 1
	await frames(2)
	hit(sh, obj(sh, "storm"))
	await frames(40)
	check("storm_kills_foes_in_water", toads.size() == 3 and toads.all(func(e): return not is_instance_valid(e) or e.dead) and sh.alive_foes() == 0, sh.alive_foes())
	# frost on the blade, strike the water ahead: it freezes into a path
	await stand(sh.cell_rect(Vector2i(3, 9)).end - Vector2(20, 2))
	hit(sh, sh.objs.filter(func(o): return o["t"] == "frost")[1])
	check("frost_crystal_chills_blade", sh.frost_t > 7.0)
	var c1 := Vector2i(3, 7)
	var c2 := Vector2i(3, 6)
	sh.strike(sh.cell_rect(c1).grow(-8.0), Vector2.UP, false)
	sh.strike(sh.cell_rect(c2).grow(-8.0), Vector2.UP, false)
	await frames(3)
	check("water_freezes", float(sh.water[c1]["ice"]) > 10.0 and float(sh.water[c2]["ice"]) > 10.0 and not main.world.wall_hit(sh.cell_rect(c1).grow(-6.0)))
	# walk the ice to the far shore, onto the plate: the door opens (plate held, no foe left)
	await stand(sh.cell_rect(c1).end - Vector2(20, 4))
	await stand(sh.cell_rect(c2).end - Vector2(20, 4))
	check("ice_holds_the_hero", main.player.global_position.y < sh.cell_rect(c2).end.y + 1.0 and sh.water[c2]["ice"] > 0.0)
	await stand(sh.by_id["p0"]["rect"].get_center() + Vector2(0, 14), 6)
	check("tides_door_opens", sh.door_open)
	# ice thaws: standing on it then means a splash back to dry land
	await stand(sh.cell_rect(c2).end - Vector2(20, 4))
	var hp0 := Game.hp
	sh.water[c2]["ice"] = 0.05
	main.player.invuln = 0.0
	await frames(6)
	main.player.invuln = 99999.0
	check("thaw_splashes_hero_ashore", sh.cell_of(main.player.global_position + Vector2(0, -4)) != c2 and Game.hp < hp0, [main.player.global_position, hp0, Game.hp])
	await frames(2)
	check("thawed_water_blocks_again", main.world.wall_hit(sh.cell_rect(c2).grow(-6.0)))

# ---------------------------------------------------------------- light: mirrors, the ice wall, the crystal
func _light() -> void:
	var sh = await enter("shrine_light")
	still_foes()
	await frames(2)
	check("beam_starts_blocked", not sh.target_lit and sh.beam.size() >= 3, sh.beam.size())
	for id in ["m2", "m1", "m0"]:
		sh.turn(sh.by_id[id])
	await frames(2)
	check("ice_wall_stops_light", not sh.target_lit)
	hit(sh, obj(sh, "source"))
	hit(sh, obj(sh, "icewall"))
	await frames(40)
	check("fire_melts_ice_wall", float(obj(sh, "icewall")["melt"]) >= 1.0)
	await frames(3)
	# emitter -> m2 (up) -> m1 (left, through the melted ice) -> m0 (up) -> the crystal
	check("light_reaches_crystal", sh.target_lit and sh.beam.size() == 5, sh.beam)
	check("light_door_opens", sh.door_open)
	# striking a mirror turns it
	var m = sh.by_id["m0"]
	var o0 := int(m["o"])
	sh.fire_t = 0.0
	hit(sh, m)
	check("blow_turns_mirror", int(m["o"]) == 1 - o0)

# ---------------------------------------------------------------- echoes: runes in order, two timed braziers
func _echoes() -> void:
	var sh = await enter("shrine_echoes")
	still_foes()
	var runes: Array = sh.objs.filter(func(o): return o["t"] == "rune")
	runes.sort_custom(func(a, b): return int(a["n"]) < int(b["n"]))
	check("echoes_built", runes.size() == 4 and sh.order.map(func(x): return int(x)) == [2, 4, 1, 3] and obj(sh, "mosaic") != null)
	# wrong order: the runes go dark
	await stand(runes[1]["rect"].get_center() + Vector2(0, 10))
	await stand(Vector2(340, 470))
	check("wrong_rune_resets", sh.seq == 0 and not runes[1]["lit"])
	for r in runes:
		await stand(r["rect"].get_center() + Vector2(0, 10))
		await stand(Vector2(340, 470))
	check("runes_in_order_sing", sh.seq_done, sh.seq)
	# one timed brazier alone goes out
	hit(sh, obj(sh, "source"))
	hit(sh, sh.by_id["t0"])
	check("timed_brazier_lit", sh.by_id["t0"]["lit"])
	await frames(int(sh.by_id["t0"]["timed"] * 60.0) + 10)
	check("timed_brazier_goes_out", not sh.by_id["t0"]["lit"] and not sh.door_open)
	hit(sh, obj(sh, "source"))
	hit(sh, sh.by_id["t0"])
	await frames(60)
	hit(sh, sh.by_id["t1"])
	await frames(3)
	check("echoes_door_opens", sh.door_open)

# ---------------------------------------------------------------- shadows: the Watchers
func _shadows() -> void:
	var sh = await enter("shrine_shadows")
	check("shadows_built", sh.sentinels.size() == 4 and not main.world.grass.is_empty())
	var s0: Dictionary = sh.sentinels[0]
	var in_cone: Vector2 = s0["pos"] + Vector2.from_angle(float(s0["ang"])) * 120.0
	check("watcher_sees_in_light", sh.watcher_sees(s0, in_cone, false, false, false) == "saw")
	check("watcher_blind_to_sneak_in_grass", sh.watcher_sees(s0, in_cone, true, true, true) == "")
	var behind: Vector2 = s0["pos"] - Vector2.from_angle(float(s0["ang"])) * 60.0
	check("watcher_hears_loud_steps", sh.watcher_sees(s0, behind, false, false, true) == "heard" and sh.watcher_sees(s0, behind, true, false, true) == "")
	# caught: back to the door you came in by
	await stand(Vector2(340, 470))
	var n0: int = sh.caught
	sh.sentinels[0]["base"] = PI * 0.5
	sh.sentinels[0]["sweep"] = 0.0
	await stand(s0["pos"] + Vector2(0, 100))
	check("caught_sent_back", sh.caught == n0 + 1 and main.player.global_position.distance_to(main.world.start_feet()) < 2.0, main.player.global_position)
	# the start is out of every Watcher's sight
	var seen_at_start := false
	for t in 60:
		sh.clock = t * 0.1
		for s in sh.sentinels:
			s["ang"] = float(s["base"]) + float(s["sweep"]) * sin(TAU * (sh.clock + float(s["phase"])) / float(s["period"]))
			if sh.watcher_sees(s, main.world.start_feet() + Vector2(0, -6), true, false, false) != "":
				seen_at_start = true
	check("start_is_safe", not seen_at_start)
	# the far plate (reached by sneaking through the grass)
	await stand(sh.by_id["p0"]["rect"].get_center() + Vector2(0, 14), 4)
	check("shadows_door_opens", sh.door_open)

# ---------------------------------------------------------------- the altar, the sigil, a solved shrine again, saving
func _altar_and_after() -> void:
	var sh = await enter("shrine_embers")
	check("solved_shrine_stays_open", sh.door_open and sh.by_id["f0"]["lit"] and sh.by_id["f1"]["lit"] and not main.world.wall_hit(obj(sh, "door")["rect"].grow(-4.0)))
	var gold0 := int(Game.state.get("gold", 0))
	var bag0: int = Game.Gear.bag().size() + Game.Gear.eq().size()
	var hp_max0 := Game.max_hp()
	var altar = obj(sh, "altar")
	await stand(altar["rect"].end + Vector2(-18, 30))
	check("altar_is_near", main.player.near_npc != null and str(main.player.near_npc.get_meta("id", "")) == "altar")
	main._on_interact(altar["node"])
	await frames(2)
	check("altar_gives_gold_and_treasure", int(Game.state["gold"]) > gold0 + 100 and Game.Gear.bag().size() + Game.Gear.eq().size() > bag0, [gold0, Game.state["gold"]])
	check("sigil_choice_opens", main.hud.dialogue.choosing())
	hp_max0 = Game.max_hp()        # the treasure may be an amulet of health, put on at once: count from here
	main.hud.dialogue._block_until = 0
	main.hud.dialogue._pick(0)
	await frames(2)
	check("sigil_vitality_taken", Game.sigil("vit") == 1 and is_equal_approx(Game.max_hp(), hp_max0 + 12.0) and Game.shrine_done("shrine_embers"), [hp_max0, Game.max_hp()])
	check("shrines_done_counts", Game.shrines_done() == 1)
	# a second visit: no second reward
	var gold1 := int(Game.state["gold"])
	main._on_interact(altar["node"])
	await frames(2)
	check("altar_gives_once", int(Game.state["gold"]) == gold1 and not main.hud.dialogue.choosing())
	# the other gifts
	Game.take_sigil("shrine_weight", "might")
	Game.take_sigil("shrine_fuse", "guard")
	Game.take_sigil("shrine_tides", "focus")
	check("gifts_raise_stats", is_equal_approx(Game.sigil_bonus("might"), 2.0) and is_equal_approx(Game.sigil_bonus("guard"), 1.0) and is_equal_approx(Game.sigil_bonus("focus"), 6.0))
	check("one_gift_per_shrine", Game.take_sigil("shrine_weight", "vit") == "" and Game.sigil("vit") == 1)
	# saved and loaded
	Game.save_game()
	var before: Dictionary = Game.state["shrines"].duplicate(true)
	Game.state["shrines"] = {}
	Game.load_game()
	check("shrines_saved", Game.state.get("shrines", {}).get("shrine_embers", {}).get("gift", "") == "vit" and Game.shrines_done() == 4, Game.shrines_done())
	# the gates on the regions' maps, gold once done
	main.goto_map("forest", Vector2(330, 500))
	await frames(4)
	check("gate_and_pillar_on_region_map", main.world.has_node("ShrineGate_shrine_embers") and main.world.has_node("PillarOfLight_shrine_embers"))
	# the compass: the nearest unfinished shrine
	var tg: Dictionary = Game.shrine_target()
	check("compass_finds_next_shrine", not tg.is_empty() and str(tg["map"]) in ["village", "forest", "dungeon", "peaks", "shadowfen", "sanctum", "emberforge"] and str(tg["map"]) != "forest", tg)
	# inside an unfinished shrine the compass points at its altar
	Game.state["map"] = "shrine_light"
	check("compass_inside_points_to_altar", Game.shrine_target().get("map", "") == "shrine_light")
	Game.state["map"] = "forest"

# ---------------------------------------------------------------- spells on the pieces
func _spells() -> void:
	Game.state["shrines"].erase("shrine_embers")
	var sh = await enter("shrine_embers")
	var f0 = sh.by_id["f0"]
	sh.element(f0["rect"].get_center() + Vector2(30, 0), 60.0, "burn")
	check("ember_nova_lights_brazier", f0["lit"])
	var sh2 = await enter("shrine_tides")
	var c := Vector2i(8, 7)
	check("ice_lance_freezes_water", not sh2.shot_at(sh2.cell_rect(c).get_center(), "freeze") and float(sh2.water[c]["ice"]) > 0.0)
	check("shots_stop_at_pieces", sh2.shot_at(obj(sh2, "frost")["rect"].get_center(), ""))

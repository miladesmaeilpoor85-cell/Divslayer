extends Node
## v0.5 checks: light and darkness, day and night, brightness and graphics settings, living props, weather,
## the quest compass and its route over the regions' exits, the minimap, loot that flies to the hero,
## the level-up banner waiting for a boss banner, the camera distance, the dodge dash, swing arcs, music.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/fxtest.gd

var main: Node
var results := {}
var fails: Array = []

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func check(n: String, ok: bool, info = null) -> void:
	results[n] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(n)
	printerr(("PASS " if ok else "FAIL ") + n + ("" if info == null else "  " + str(info)))

func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	Game.lang = "fa"
	for k in ["fx", "bright", "cam", "compass"]:
		Game.settings[k] = {"fx": 1, "bright": 0, "cam": 1, "compass": 1}[k]
	Game.new_game("warrior")
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	main.start_world()
	await frames(20)

	# ---- darkness: outdoors at night is darker than by day; the crypt is dark whatever the hour
	Game.state["day_t"] = 0.37          # day
	main.goto_map("village", Vector2(450, 470))
	main.world.atmos.forced = ""
	main.world.atmos.set_weather("")
	await frames(5)
	var lit = main.world.lighting
	var day_a: float = lit.amb_a
	Game.state["day_t"] = 0.87          # night
	await frames(5)
	var night_a: float = lit.amb_a
	check("night_darker_than_day", night_a > day_a + 0.25 and lit.shade.visible, [day_a, night_a])
	check("hero_carries_light", lit.lights.size() >= 1 + 4, lit.lights.size())
	Game.set_setting("bright", 2)
	await frames(3)
	check("brightness_lifts_darkness", lit.amb_a < night_a * 0.5, lit.amb_a)
	Game.set_setting("bright", 0)
	main.goto_map("dungeon", Vector2(430, 420))
	await frames(5)
	var d_night: float = main.world.lighting.amb_a
	Game.state["day_t"] = 0.37
	await frames(5)
	check("indoors_ignores_time_of_day", is_equal_approx(d_night, main.world.lighting.amb_a) and d_night > 0.4, [d_night, main.world.lighting.amb_a])

	# ---- the crypt's torches and braziers burn again; the trial's fire columns too
	var fires := 0
	for it in main.world.props.items:
		if it["spec"].has("fire"):
			fires += 1
	check("crypt_fires_lit", fires >= 6, fires)
	main.goto_map("trial", Vector2(550, 420))
	await frames(3)
	fires = 0
	for it in main.world.props.items:
		if it["spec"].has("fire"):
			fires += 1
	check("trial_columns_burn", fires >= 7, fires)

	# ---- light graphics turn off lighting and weather
	Game.set_setting("fx", 0)
	await frames(3)
	check("light_graphics_mode", not main.world.lighting.shade.visible and not main.world.atmos.visible)
	Game.set_setting("fx", 1)
	await frames(3)

	# ---- weather: rain falls, and the rain sound is asked for
	Game.state["day_t"] = 0.37
	main.goto_map("village", Vector2(450, 470))
	main.world.atmos.set_weather("rain")
	await frames(5)
	check("rain_falls", main.world.atmos.emitters.has("rain") and main.world.atmos.emitters["rain"].emitting and Music._amb_want["rain"])
	main.world.atmos.set_weather("")
	await frames(2)
	check("rain_stops", not main.world.atmos.emitters["rain"].emitting and not Music._amb_want["rain"])

	# ---- weather and regional ambience now share a slow, readable gust cycle
	var atmos = main.world.atmos
	var calm_leaf: Vector2 = atmos.wind_direction_for("leaves", "", 0.0)
	var ash_gust_leaf: Vector2 = atmos.wind_direction_for("leaves", "ash", 1.0)
	var snow_gust: Vector2 = atmos.wind_direction_for("snow", "snow", 1.0)
	var rain_gust: Vector2 = atmos.wind_direction_for("rain", "rain", 1.0)
	check("wind_gust_directions_are_normalized",
		absf(ash_gust_leaf.length() - 1.0) < 0.001 and absf(snow_gust.length() - 1.0) < 0.001
		and absf(rain_gust.length() - 1.0) < 0.001)
	check("wind_gust_changes_leaf_drift", ash_gust_leaf.x > calm_leaf.x)
	check("snow_and_rain_have_distinct_wind_profiles", snow_gust.x > rain_gust.x)
	atmos.set_weather("rain")
	atmos._apply_wind(-1.0)
	var rain_lull: Vector2 = atmos.emitters["rain"].direction
	atmos._apply_wind(1.0)
	var rain_peak: Vector2 = atmos.emitters["rain"].direction
	check("rain_particles_respond_to_live_gusts", rain_peak.x > rain_lull.x)
	atmos.set_weather("")

	# ---- footfalls carry a subtle palette from the ground beneath the hero
	main.goto_map("sanctum", Vector2(450, 470))
	var snow_dust: Color = main.player._footstep_dust_color()
	main.goto_map("shadowfen", Vector2(450, 470))
	var bog_dust: Color = main.player._footstep_dust_color()
	main.goto_map("village", Vector2(450, 470))
	var soil_dust: Color = main.player._footstep_dust_color()
	check("footstep_dust_matches_region",
		snow_dust.b > snow_dust.r and bog_dust.g > bog_dust.r and soil_dust.r > soil_dust.b,
		[snow_dust, bog_dust, soil_dust])
	main.player._feel(Vector2.RIGHT)
	var lean_right: float = main.player.body.rotation
	main.player._feel(Vector2.LEFT)
	var lean_left: float = main.player.body.rotation
	check("walk_animation_leans_into_direction", lean_right > 0.0 and lean_left < 0.0,
		[lean_right, lean_left])

	# ---- quest compass: the route over the regions' exits, and the arrow
	check("route_village_to_crypt", Game.next_hop("village", "dungeon") == "forest", Game.next_hop("village", "dungeon"))
	check("route_village_to_bog", Game.next_hop("village", "shadowfen") == "forest" and Game.next_hop("forest", "shadowfen") == "peaks")
	var cp: Dictionary = Game.compass_point("village")
	# (v0.24) a new hero is first sent to Rostam's yard; once that is skipped (or done), to Zal
	check("compass_points_to_rostam", not cp.is_empty() and not cp["exit"] and cp["pos"].distance_to(Vector2(565, 178)) < 40.0, cp)
	Game.Tut.skip()
	cp = Game.compass_point("village")
	check("compass_points_to_elder", not cp.is_empty() and not cp["exit"] and cp["pos"].distance_to(Vector2(443, 334)) < 40.0, cp)
	Game.set_q(1, "active")
	cp = Game.compass_point("village")
	check("compass_points_to_exit", cp.get("exit", false) and cp.get("to", "") == "forest", cp)
	main.player.global_position = Vector2(200, 470)
	await frames(30)
	var comp = main.world.fx.overlay.get_node("Compass")
	check("compass_shows", comp.visible and comp._a > 0.5, comp._a)
	Game.set_q(1, "not_started")

	# ---- the minimap: tap opens the map in the pause menu
	var mm = main.hud.minimap
	check("minimap_built", mm != null and mm.visible and mm.size.x >= 100.0, mm.size if mm else null)
	main.hud.open_pause("map")
	await frames(3)
	check("map_tab_opens", main.hud.pause.visible and main.hud.pause.tab == "map")
	main.hud.pause.close()
	await frames(2)

	# ---- loot flies to the hero
	main.goto_map("forest", Vector2(560, 470))
	await frames(10)
	var e = get_tree().get_nodes_in_group("enemies")[0]
	var g0 := int(Game.state["gold"])
	e.hurt(99999.0, false, Vector2.RIGHT)
	await frames(2)
	var n_bits: int = main.world.loot.bits.size()
	main.player.global_position = e.global_position + Vector2(40, 0)
	for i in 150:
		await get_tree().process_frame
	check("loot_flies_to_hero", n_bits >= 2 and main.world.loot.bits.is_empty() and int(Game.state["gold"]) > g0, [n_bits, main.world.loot.bits.size()])

	# ---- a level-up never covers a boss banner
	main.hud.banner("VANQUISHED", "test", Color.WHITE, 1.0)
	main.hud.level_up(9)
	await frames(10)
	var during: String = main.hud.boss_ui.banner_a.text
	for i in 150:
		await get_tree().process_frame
	check("level_banner_waits", during == "VANQUISHED" and main.hud.boss_ui.banner_a.text.contains(Game.num(9)), [during, main.hud.boss_ui.banner_a.text])

	# ---- camera distance setting
	main.goto_map("forest", Vector2(560, 470))
	await frames(5)
	Game.set_setting("cam", 2)
	await frames(3)
	var z2: float = main.player.cam.zoom.x
	Game.set_setting("cam", 0)
	await frames(3)
	var z0: float = main.player.cam.zoom.x
	Game.set_setting("cam", 1)
	check("camera_distance", z2 > z0 + 0.2, [z0, z2])
	# (v0.24) the view may slide past the edges (most on the right, where the buttons are); the apron is drawn there
	await frames(3)
	var cm = main.player.cam
	var ws: Vector2 = main.world.size
	check("camera_apron", cm.limit_left < 0 and cm.limit_top < 0 and cm.limit_right > int(ws.x) and cm.limit_bottom > int(ws.y)
		and cm.limit_right - int(ws.x) > -cm.limit_left and main.world.get_node_or_null("Apron") != null,
		[cm.limit_left, cm.limit_top, cm.limit_right, cm.limit_bottom, ws])

	# ---- the dodge: a fast dash of 95 px with a spin
	await frames(5)
	main.player.facing = "right"
	var p0: Vector2 = main.player.global_position
	main.player.dodge()
	var spun: bool = main.player.roll_t > 0.0
	# The signal fires before physics callbacks. Wait across two ticks so the
	# player's _physics_process -> _feel has emitted the first directional trail.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var dash_fx: Dictionary = main.world.fx.dashes.back() if not main.world.fx.dashes.is_empty() else {}
	check("dodge_has_directional_energy_trail",
		not dash_fx.is_empty() and dash_fx["dir"].dot(main.player.dash_v.normalized()) > 0.99 and float(dash_fx["length"]) >= 30.0,
		dash_fx)
	for i in 15:
		await get_tree().physics_frame
	check("dodge_dash", absf(main.player.global_position.distance_to(p0) - 95.0) < 12.0 and spun, main.player.global_position.distance_to(p0))

	# ---- a swing draws an arc; a hit throws sparks
	await frames(30)
	var e2 = null
	for x in get_tree().get_nodes_in_group("enemies"):
		e2 = x
		break
	if e2:
		e2.spd = 0.0
		e2.max_hp = 9999.0
		e2.hp = 9999.0
		main.player.global_position = e2.global_position + Vector2(-30, 2)
		await frames(3)
		main.player.attack()
		# The slash and hit sparks are emitted at the configured contact frame.
		await frames(7)
		var sparks := false
		for p in main.world.fx.pools["spark"]:
			if p.emitting:
				sparks = true
		check("swing_arc_and_sparks", not main.world.fx.swings.is_empty() and sparks)
		var spell_fx = main.world.spells
		check("projectile_trail_tapers",
			spell_fx._trail_width_at(0, 7, 1.0) > spell_fx._trail_width_at(6, 7, 1.0)
			and spell_fx._trail_width_at(0, 7, 1.5) > spell_fx._trail_width_at(0, 7, 1.0))
		spell_fx.shoot("arcane_bolt", main.player.global_position, Vector2.RIGHT,
			{"col": Color(0.55, 0.78, 1.0), "speed": 500.0, "range": 300.0}, 1.0)
		check("projectile_keeps_typed_trail_data",
			not spell_fx.shots.is_empty() and spell_fx.shots.back()["trail"] is Array
			and spell_fx.shots.back()["v"].length() > 0.0)
		main.world.fx.swing(main.player, Vector2.RIGHT, 48.0, true, 5)
		var heavy_arc: Dictionary = main.world.fx.swings.back()
		check("heavy_swing_uses_enhanced_trail",
			bool(heavy_arc["heavy"]) and float(heavy_arc["dur"]) > 0.22 and float(heavy_arc["r"]) > 48.0,
			heavy_arc)
		# Class-specific attack language stays cosmetic and distinct while using the same hit geometry.
		var previous_class := str(Game.cls)
		var class_swings := {}
		for hero_class in ["warrior", "mage", "rogue", "paladin"]:
			Game.cls = hero_class
			main.world.fx.swing(main.player, Vector2.RIGHT, 42.0, false, 1)
			var class_arc: Dictionary = main.world.fx.swings.back()
			class_swings[hero_class] = class_arc["col"]
			check("swing_records_" + hero_class + "_identity", str(class_arc.get("class", "")) == hero_class)
			var ring_count: int = main.world.fx.rings.size()
			main.world.fx.class_impact(e2.center(), Vector2.RIGHT, hero_class, false)
			check("impact_fx_has_" + hero_class + "_response", main.world.fx.rings.size() > ring_count)
		Game.cls = previous_class
		check("class_swing_palettes_are_distinct",
			class_swings.size() == 4
			and class_swings["mage"] != class_swings["rogue"]
			and class_swings["mage"] != class_swings["paladin"]
			and class_swings["rogue"] != class_swings["paladin"], class_swings)
		e2.make_elite("fire")
		var orbit_a: PackedVector2Array = e2._elite_orbit_points(0.0, 24.0)
		var orbit_b: PackedVector2Array = e2._elite_orbit_points(0.5, 24.0)
		check("elite_aura_has_three_orbiting_runes",
			e2._aura != null and orbit_a.size() == 3 and orbit_b.size() == 3
			and orbit_a[0].distance_to(orbit_b[0]) > 2.0)
		e2.hurt(1.0, false, Vector2.RIGHT, true)
		check("heavy_enemy_hit_has_stronger_reaction",
			e2.hit_pulse_t > 0.0 and e2.hit_pulse_strength >= 0.12,
			[e2.hit_pulse_t, e2.hit_pulse_strength])

	# ---- day turns to night by itself
	Game.state["day_t"] = 0.4999
	var ph0 := Game.phase()
	for i in 30:
		await get_tree().physics_frame
	check("time_passes", Game.phase() != ph0, [ph0, Game.phase()])

	# ---- music: the notes are synthesised in the background and a boss changes the tune
	for i in 300:
		if Music._ready_samples:
			break
		await get_tree().process_frame
	check("music_ready", Music._ready_samples and Music.notes.size() >= 5 and Music.loops.size() == 3)
	check("music_follows_region", Music.region == "forest", Music.region)

	print("FXTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

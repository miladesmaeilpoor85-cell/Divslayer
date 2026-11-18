extends Node
## v0.40 checks: the Venom elite is selected only in poison-themed regions, has the standard elite
## combat rewards and aura, and applies the existing poison status on a successful contact hit.

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

func clear_foes() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.remove_from_group("enemies")
			e.queue_free()

func run(m: Node) -> void:
	main = m
	await frames(2)

	# ---- data and localization
	var venom: Dictionary = Game.elite_def("venom")
	check("venom_definition_exists", not venom.is_empty(), venom)
	check("venom_uses_existing_poison_status", str(venom.get("status", "")) == "poison")
	check("venom_has_green_visuals", str(venom.get("col", "")) == "#83d16d" and str(venom.get("glow", "")) == "#72df65")
	var old_lang := Game.lang
	Game.lang = "fa"
	check("venom_has_persian_name", Game.elite_name("venom") == "زهرآگین", Game.elite_name("venom"))
	Game.lang = "en"
	check("venom_has_english_name", Game.elite_name("venom") == "Venom", Game.elite_name("venom"))
	Game.lang = old_lang

	# ---- the new affix appears only in poison-themed regions
	var fen_pool: Array[String] = Game.elite_pool("shadowfen")
	var damavand_pool: Array[String] = Game.elite_pool("damavand")
	var cave_pool: Array[String] = Game.elite_pool("zahhakcave")
	var forest_pool: Array[String] = Game.elite_pool("forest")
	var forge_pool: Array[String] = Game.elite_pool("emberforge")
	check("venom_available_in_shadowfen", fen_pool.has("venom"), fen_pool)
	check("venom_available_in_damavand", damavand_pool.has("venom"), damavand_pool)
	check("venom_available_in_zahhak_cave", cave_pool.has("venom"), cave_pool)
	check("venom_not_in_forest_pool", not forest_pool.has("venom"), forest_pool)
	check("venom_not_in_emberforge_pool", not forge_pool.has("venom"), forge_pool)
	check("existing_elite_pool_stays_intact", forest_pool == ["fire", "ice", "storm"], forest_pool)

	# ---- stage a real player and a common enemy in a safe test arena
	Game.testing = true
	Game.new_game("warrior")
	if main.player == null:
		main.start_world()
		await frames(5)
	main.goto_map("trial", Vector2(450, 520))
	await frames(5)
	clear_foes()
	await frames(1)
	var p: Node = main.player
	p.global_position = Vector2(450, 520)
	p.dead = false
	p.invuln = 0.0
	p.ward_t = 0.0
	p.fire_t = 0.0
	p.blocking = false
	p.statuses.clear()
	Game.hp = Game.max_hp()

	var foe: Node = main.world.spawn_enemy("skeleton", Vector2(560, 520))
	foe.spd = 0.0
	foe.calm = 99.0
	var base_hp: float = foe.max_hp
	var base_dmg: float = foe.dmg
	var base_xp: int = foe.xp
	var base_gold: int = foe.gold
	foe.make_elite("venom")
	check("venom_elite_tagged", foe.elite == "venom", foe.elite)
	check("venom_elite_health_scaling", is_equal_approx(foe.max_hp, base_hp * 2.4), [base_hp, foe.max_hp])
	check("venom_elite_damage_scaling", is_equal_approx(foe.dmg, base_dmg * 1.3), [base_dmg, foe.dmg])
	check("venom_elite_reward_scaling", foe.xp == int(base_xp * 3) and foe.gold == int(base_gold * 3), [base_xp, foe.xp, base_gold, foe.gold])
	check("venom_elite_has_green_aura", foe._aura != null and is_instance_valid(foe._aura))

	# ---- contact applies poison only after the attack actually damages the hero
	var hp_before_contact: float = Game.hp
	foe._contact(p)
	var poisoned: bool = p.statuses.has("poison")
	var poison_time: float = float(p.statuses.get("poison", {}).get("t", 0.0))
	check("venom_contact_applies_poison", poisoned and Game.hp < hp_before_contact, {"hp_before": hp_before_contact, "hp_after": Game.hp, "statuses": p.statuses})
	check("venom_poison_has_expected_duration", is_equal_approx(poison_time, 2.6), poison_time)
	var hp_before_tick: float = Game.hp
	p._statuses(0.61)
	check("venom_poison_tick_damages_hero", Game.hp < hp_before_tick, {"hp_before": hp_before_tick, "hp_after": Game.hp})

	print("ELITETEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

extends Node
## v0.26 checks: each calling's own move (Skills.SIG, on the button that was Shove). The lasso drags a foe to the hero and
## stuns it (a boss only staggers); the Simorgh's feather turns one blow and gives mana; the arrow flies, and from hiding
## strikes three times as hard; the fire-walk burns what is near and nothing clings to the hero meanwhile.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/sigtest.gd

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

## a fresh hero of the calling in the forest, one plain foe placed at `off` from him (the rest sent far away)
func stage(cls: String, off: Vector2) -> Node:
	Game.new_game(cls)
	Game.state["level"] = 5
	Game.state["pad_all"] = true
	if main.player == null:
		main.start_world()
	main.goto_map("forest", Vector2(500, 500))
	await frames(6)
	var p = main.player
	p.invuln = 0.0
	p.stamina = 100.0
	p.shove_cd = 0.0
	var foe: Node = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e.boss:
			continue
		if foe == null:
			foe = e
			e.global_position = p.global_position + off
			e.calm = 99.0
		else:
			e.global_position = Vector2(-4000, -4000)
			e.calm = 999.0
	await frames(2)
	return foe

func run(m: Node) -> void:
	main = m
	await frames(5)
	Game.lang = "fa"
	Game.new_game("warrior")
	main.start_world()
	await frames(5)

	# ---- the names on the pad
	var names := {}
	for c in ["warrior", "mage", "rogue", "paladin"]:
		Game.cls = c
		names[c] = Game.Skills.sig_name()
	check("four_moves_four_names", names == {"warrior": "کمند", "mage": "پرِ سیمرغ", "rogue": "تیرِ خدنگ", "paladin": "گذر از آتش"}, names)

	# ---- Pahlavan: the lasso
	var foe: Node = await stage("warrior", Vector2(170, 0))
	var p = main.player
	p.facing = "right"
	var d0: float = foe.global_position.distance_to(p.global_position)
	check("pad_shows_the_lasso", str(main.hud.pad.buttons()["shove"]["label"]) == "کمند")
	p.signature()
	check("lasso_stuns", foe.has_status("stun") and p.shove_cd > 5.0 and p.stamina < 100.0, [foe.est.keys(), p.shove_cd])
	await frames(40)
	var d1: float = foe.global_position.distance_to(p.global_position)
	check("lasso_drags_the_foe_in", d1 < d0 - 70.0 and d1 < 90.0, [d0, d1])
	var cd_was: float = p.shove_cd
	p.signature()
	check("cooldown_holds", p.sig_uses == 1 and p.shove_cd <= cd_was)

	# ---- Sage: the Simorgh's feather
	foe = await stage("mage", Vector2(300, 0))
	p = main.player
	Game.mp = 2.0
	var hp0: float = Game.hp
	p.signature()
	check("feather_wards", p.ward_t > 5.0)
	p.take_hit(30.0)
	check("feather_turns_one_blow", Game.hp == hp0 and p.ward_t == 0.0 and Game.mp >= 8.0, [Game.hp, hp0, Game.mp])
	p.invuln = 0.0
	p.take_hit(6.0)
	check("only_one_blow", Game.hp < hp0)

	# ---- Ayyar: the arrow, and from hiding
	foe = await stage("rogue", Vector2(150, 0))
	p = main.player
	p.facing = "right"
	foe.max_hp = 100000.0
	foe.hp = 100000.0
	seed(7)
	p.signature()
	await frames(30)
	var open_dmg: float = 100000.0 - foe.hp
	check("arrow_hits_from_afar", open_dmg > 0.0, open_dmg)
	foe.hp = 100000.0
	foe.calm = 99.0
	p.shove_cd = 0.0
	p.stamina = 100.0
	p.sneaking = true
	seed(7)
	p.signature()
	await frames(30)
	var hid_dmg: float = 100000.0 - foe.hp
	check("arrow_from_hiding_thrice", not p.sneaking and hid_dmg >= open_dmg * 1.4, [open_dmg, hid_dmg])

	# ---- Oathbearer: the walk through fire
	foe = await stage("paladin", Vector2(40, 0))
	p = main.player
	foe.max_hp = 100000.0
	foe.hp = 100000.0
	p.apply_status("poison", 5.0)
	p.signature()
	check("fire_cleanses", p.fire_t > 3.5 and p.statuses.is_empty())
	p.apply_status("freeze", 3.0)
	check("nothing_clings_in_fire", p.statuses.is_empty())
	foe.global_position = p.global_position + Vector2(40, 0)
	await frames(70)
	check("fire_burns_what_is_near", foe.hp < 100000.0 and foe.has_status("burn"), [100000.0 - foe.hp, foe.est.keys()])
	await frames(240)
	check("fire_ends", p.fire_t == 0.0)

	print("SIGTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

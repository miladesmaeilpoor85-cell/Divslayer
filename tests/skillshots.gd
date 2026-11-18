extends Node
## v0.6 screenshots for design reviews: the HUD with the spell buttons, every spell and ultimate in action,
## the Skills tab (spells, talents), the shop's mana potion, the hero sheet.
##   godot --path . --rendering-driver opengl3 -- --test res://tests/skillshots.gd --out <dir> [--lang en]

const Skills = preload("res://scripts/skills.gd")

var main: Node
var out := "/tmp/claude-0/ui/skills"

func _arg(k: String, d: String) -> String:
	var i := Game.args.find(k)
	return Game.args[i + 1] if i >= 0 and i + 1 < Game.args.size() else d

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(n + ".png"))
	printerr("SHOT ", n)

func dummy(feet: Vector2, type := "skeleton") -> Node:
	var e = main.world.spawn_enemy(type, feet)
	e.max_hp = 9000.0
	e.hp = 9000.0
	e.spd = 0.0
	e.dmg = 0.0
	e.hit_cd = 9999.0
	return e

func clear_foes() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()

func hero(c: String, lv: int, map := "forest", at := Vector2(560, 470)) -> Node:
	Game.new_game(c)
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	Game.v18()["tips"] = {"talents": true}
	Game.state["level"] = lv
	Game.state["gift_firewall"] = true
	Game.state["day_t"] = 0.37
	Game.hp = Game.max_hp() * 0.8
	Game.mp = Game.max_mp() * 0.7
	if main.player == null:
		main.start_world()
		await frames(10)
	main.goto_map(map, at)
	await frames(10)
	clear_foes()
	main.hud.notify.clear()
	var p = main.player
	p.global_position = at
	p.facing = "right"
	p.invuln = 999.0
	p.refresh_look()
	p.caster.cds.clear()
	main.world.atmos.forced = ""
	main.world.atmos.set_weather("")
	return p

func run(m: Node) -> void:
	main = m
	out = _arg("--out", out)
	DirAccess.make_dir_recursive_absolute(out)
	Game.lang = _arg("--lang", "fa")
	await get_tree().process_frame

	var p = await hero("mage", 9)
	Game.state["slots"] = ["bolt", "chain"]
	Game.state["ult"] = 64.0
	for i in 3:
		dummy(Vector2(700 + i * 50, 440 + i * 30))
	await frames(40)
	await snap("01_hud_spell_buttons")
	p.caster.cast("bolt")
	await frames(12)
	await snap("02_bolt")
	await frames(30)
	p.caster.cast("chain")
	await frames(3)
	await snap("03_chain")
	await frames(30)
	p.caster.cast("nova")
	await frames(4)
	await snap("04_nova")
	await frames(30)
	p.caster.cast("icelance")
	await frames(10)
	await snap("05_icelance")
	await frames(30)
	p.caster.cast("firewall")
	await frames(10)
	await snap("06_emberwall")
	await frames(40)
	Game.state["ult"] = 100.0
	await frames(20)
	await snap("07_ult_ready")
	p.caster.ultimate()
	await frames(22)
	await snap("08_tempest")
	await frames(40)
	await snap("08b_tempest_impact")

	p = await hero("warrior", 12, "dungeon", Vector2(430, 420))
	for a in [0.0, 1.6, 3.2, 4.7]:
		dummy(p.global_position + Vector2.from_angle(a) * 50.0)
	await frames(20)
	p.caster.cast("roar")
	await frames(10)
	await snap("09_roar_dark")
	Game.state["ult"] = 100.0
	p.caster.ultimate()
	await frames(30)
	await snap("10_whirlwind")
	await frames(160)
	p.caster.cast("quake")
	await frames(4)
	await snap("11_quake")

	p = await hero("rogue", 8, "forest")
	var t = dummy(Vector2(650, 470), "golem")
	await frames(10)
	Game.state["ult"] = 100.0
	p.caster.ultimate()
	await frames(14)
	await snap("12_shadow_dance")
	await frames(40)
	Game.hp = Game.max_hp() * 0.3
	p.caster.cast("drain")
	await frames(6)
	await snap("13_drain")

	p = await hero("paladin", 8, "village", Vector2(450, 470))
	Game.state["day_t"] = 0.87
	for a in [0.5, 2.5, 4.5]:
		dummy(p.global_position + Vector2.from_angle(a) * 80.0, "slime")
	await frames(20)
	Game.state["ult"] = 100.0
	p.caster.ultimate()
	await frames(12)
	await snap("14_holy_smite_night")

	# the Skills tab
	p = await hero("warrior", 9, "village", Vector2(450, 470))
	Game.state["talents"] = {"str1": 3, "crit": 1, "vit1": 2}
	main.hud.open_pause("skills")
	main.hud.pause.sub = "spells"
	main.hud.pause._show("skills")
	await frames(10)
	await snap("15_skills_spells")
	var sc = main.hud.pause.body.get_parent()
	if sc is ScrollContainer:
		sc.scroll_vertical = 400
		await frames(4)
		await snap("15b_skills_spells_scrolled")
	main.hud.pause.sub = "talents"
	main.hud.pause._show("skills")
	await frames(10)
	if sc is ScrollContainer:
		sc.scroll_vertical = 0
	await frames(4)
	await snap("16_skills_talents")
	if sc is ScrollContainer:
		sc.scroll_vertical = 300
		await frames(4)
		await snap("16b_skills_talents_scrolled")
	main.hud.pause._show("hero")
	await frames(10)
	await snap("17_hero_sheet")
	main.hud.pause.close()
	await frames(4)
	main.hud.shop.open("merchant")
	await frames(10)
	await snap("18_shop_mana_potion")
	main.hud.shop.close()
	get_tree().quit()

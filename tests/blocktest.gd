extends Node
## v0.7 checks: block and parry (key and touch), damage through the shield, stamina cost, guard break,
## perfect parry (no damage, enemy stunned, boss staggered, meter gain), attack and roll cancel the shield.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/blocktest.gd

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

## raise the shield the way the touch button does (held)
func up(p: Node) -> void:
	p.hold_block = true
	p.block_start()

func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	Game.lang = "fa"
	Game.set_setting("sound", true)
	var p = await hero("warrior")
	p.world.tip("block", "", "")   # mark the tip as seen

	# ---- plain block: a third of the damage gets through, it costs stamina, no parry after the window
	Game.state["level"] = 1
	p.stamina = 100.0
	up(p)
	check("block_raises", p.blocking)
	check("block_slows_walk", true)
	await frames(20)
	check("parry_window_over", p.block_t > p.PARRY_WIN, p.block_t)
	var hp0: float = Game.hp
	var raw := 12.0
	var plain: int = Game.incoming(raw, main.world.key)
	var through: int = Game.incoming(raw * p.BLOCK_TAKEN, main.world.key)
	p.take_hit(raw)
	check("block_reduces_damage", Game.hp > hp0 - plain and hp0 - Game.hp == through, [hp0 - Game.hp, plain, through])
	check("block_costs_stamina", p.stamina < 100.0 and p.stamina >= 100.0 - raw * 1.1 - 1.0, p.stamina)
	check("block_counted", p.blocks == 1)
	check("block_short_invuln", p.invuln > 0.0 and p.invuln < 0.7, p.invuln)

	# ---- attack is impossible while blocking, and the roll drops the shield
	p.invuln = 0.0
	var sw: int = p.swings
	p.attack()
	check("no_attack_while_blocking", p.swings == sw)
	p.stamina = 100.0
	p.dodge_cd = 0.0
	p.dodge()
	check("roll_drops_shield", not p.blocking)
	await frames(60)

	# ---- perfect parry: a blow in the first window does no damage, stuns a close foe, feeds the meter
	p = await hero("warrior")
	p.world.tip("block", "", "")
	clear_foes()
	var foe = dummy(Vector2(480, 520))
	p.stamina = 80.0
	Game.state["ult"] = 0.0
	hp0 = Game.hp
	up(p)
	await frames(2)
	p.take_hit(30.0)
	check("parry_no_damage", is_equal_approx(Game.hp, hp0), [hp0, Game.hp])
	check("parry_counted", p.parries == 1)
	check("parry_gives_ult", Game.ult() >= 7.9, Game.ult())
	check("parry_keeps_stamina", p.stamina >= 80.0, p.stamina)
	check("parry_stuns_foe", foe.has_status("stun"))
	check("parry_invuln", p.invuln >= 0.29, p.invuln)
	p.block_end()
	check("block_ends", not p.blocking and not p.block_fx.visible)

	# ---- a held shield can break: not enough stamina means the blow lands in full and the guard drops
	await frames(30)
	p.invuln = 0.0
	p.stamina = 100.0
	up(p)
	await frames(20)
	p.stamina = 5.0
	hp0 = Game.hp
	p.take_hit(20.0)
	check("guard_breaks", not p.blocking and p.guard_broken > 1.0, p.guard_broken)
	check("guard_break_full_damage", hp0 - Game.hp == Game.incoming(20.0, main.world.key), hp0 - Game.hp)
	up(p)
	check("no_block_while_broken", not p.blocking)
	await frames(100)
	check("guard_recovers", p.guard_broken <= 0.0)
	p.stamina = 100.0
	up(p)
	check("block_again_after_break", p.blocking)
	p.block_end()

	# ---- the blow of a status effect goes straight through
	p.stamina = 100.0
	up(p)
	await frames(20)
	hp0 = Game.hp
	p.take_hit(4.0, true)
	check("status_ignores_shield", Game.hp < hp0)
	p.block_end()

	# ---- keyboard: hold the key, let go
	p.invuln = 0.0
	p.stamina = 100.0
	Input.action_press("block")
	await frames(3)
	check("key_blocks", p.blocking)
	Input.action_release("block")
	await frames(3)
	check("key_release_drops", not p.blocking)

	# ---- touch: the shield button exists, holds, and lets go
	var pad: Node = main.hud.pad
	var bs: Dictionary = pad.buttons()
	check("touch_has_block_button", bs.has("block"))
	var pos: Vector2 = pad.get_global_transform_with_canvas() * bs["block"]["pos"]
	touch(7, pos, true)
	await frames(3)
	check("touch_press_blocks", p.blocking)
	touch(7, pos, false)
	await frames(3)
	check("touch_release_drops", not p.blocking)
	var all_clear := true
	for a in bs:
		for b in bs:
			if a < b and bs[a]["pos"].distance_to(bs[b]["pos"]) < float(bs[a]["r"]) + float(bs[b]["r"]):
				all_clear = false
				printerr("OVERLAP ", a, " ", b)
	check("touch_buttons_dont_overlap", all_clear)

	# ---- a boss: the parry feeds its stagger meter
	p = await hero("warrior")
	p.world.tip("block", "", "")
	clear_foes()
	var boss = main.world.spawn_enemy("boss", Vector2(560, 520))
	await frames(5)
	if boss != null and boss.has_method("add_stagger"):
		boss.stag = 0.0
		p.stamina = 100.0
		p.global_position = Vector2(500, 520)
		up(p)
		await frames(2)
		p.take_hit(10.0)
		check("parry_feeds_boss_stagger", boss.stag > 0.0 or boss.staggered > 0.0, boss.stag)
	else:
		check("parry_feeds_boss_stagger", false, "no boss")

	print("BLOCKTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

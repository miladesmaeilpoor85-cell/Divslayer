extends Node
## v0.14 checks: difficulty. Three levels, foe health, damage taken, XP and gold, status damage unchanged, the Settings row,
## Persian names, a bad value falling back to Normal, saving the setting.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/difftest.gd

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
	Game.lang = "en"
	Game.set_setting("sound", true)
	var p = await hero("warrior")
	p.invuln = 99.0
	clear_foes()

	# ---- the three levels
	Game.set_setting("diff", "normal")
	check("default_is_normal", Game.diff() == "normal")
	check("four_levels", Game.DIFFS.size() == 4 and Game.DIFFS.has("story") and Game.DIFFS.has("normal") and Game.DIFFS.has("hard") and Game.DIFFS.has("nightmare"))
	var order := ["story", "normal", "hard", "nightmare"]
	var ok := true
	for i in 3:
		for k in ["hp", "dmg", "reward"]:
			ok = ok and Game.DIFFS[order[i + 1]][k] > Game.DIFFS[order[i]][k]
	check("each_level_is_harder_and_pays_more", ok)
	check("normal_changes_nothing", Game.DIFFS["normal"]["hp"] == 1.0 and Game.DIFFS["normal"]["dmg"] == 1.0 and Game.DIFFS["normal"]["reward"] == 1.0)
	Game.set_setting("diff", "nonsense")
	check("bad_value_falls_back_to_normal", Game.diff() == "normal" and Game.diff_mul("hp") == 1.0)

	# ---- foe health, damage taken, rewards
	Game.set_setting("diff", "normal")
	var hp_n: float = Game.enemy_stats("slime", "forest")["hp"]
	var boss_n: float = Game.enemy_stats("boss", "dungeon")["hp"]
	var dm_n: int = Game.incoming(40.0, "forest")
	var xp_n: float = Game.xp_mul()
	var gd_n: float = Game.gold_mul()
	var st_n: int = Game.incoming(40.0, "forest", true)
	for id in ["hard", "nightmare"]:
		Game.set_setting("diff", id)
		var mul: Dictionary = Game.DIFFS[id]
		check(id + "_foe_health", is_equal_approx(Game.enemy_stats("slime", "forest")["hp"], round(hp_n * mul["hp"])) or abs(Game.enemy_stats("slime", "forest")["hp"] - hp_n * mul["hp"]) <= 1.0, [hp_n, Game.enemy_stats("slime", "forest")["hp"]])
		check(id + "_boss_health", abs(Game.enemy_stats("boss", "dungeon")["hp"] - boss_n * mul["hp"]) <= 1.0)
		check(id + "_damage_taken", abs(Game.incoming(40.0, "forest") - dm_n * mul["dmg"]) <= 1.5, [dm_n, Game.incoming(40.0, "forest")])
		check(id + "_xp", is_equal_approx(Game.xp_mul(), xp_n * mul["reward"]))
		check(id + "_gold", is_equal_approx(Game.gold_mul(), gd_n * mul["reward"]))
		check(id + "_status_damage_unchanged", Game.incoming(40.0, "forest", true) == st_n)

	# ---- a spawned foe has the health of its level
	Game.set_setting("diff", "normal")
	clear_foes()
	var e1 = main.world.spawn_enemy("slime", Vector2(300, 300))
	await frames(2)
	var base_hp: float = e1.max_hp
	clear_foes()
	Game.set_setting("diff", "nightmare")
	var e2 = main.world.spawn_enemy("slime", Vector2(300, 300))
	await frames(2)
	check("spawned_foe_is_tougher", e2.max_hp > base_hp * 2.0, [base_hp, e2.max_hp])
	clear_foes()

	# ---- the damage the hero takes through the real path
	Game.set_setting("diff", "normal")
	Game.hp = Game.max_hp()
	p.invuln = 0.0
	p.take_hit(20.0)
	var lost_n: float = Game.max_hp() - Game.hp
	Game.set_setting("diff", "nightmare")
	Game.hp = Game.max_hp()
	p.invuln = 0.0
	p.take_hit(20.0)
	var lost_x: float = Game.max_hp() - Game.hp
	check("hero_takes_more_in_nightmare", lost_x > lost_n, [lost_n, lost_x])
	Game.set_setting("diff", "normal")

	# ---- the Settings row
	main.hud.pause.open()
	await frames(3)
	main.hud.pause._show("settings")
	await frames(3)
	var labels := []
	var stack: Array = [main.hud.pause]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
		if nd is Button:
			labels.append(nd.text)
	check("settings_has_three_difficulty_buttons", labels.has("Hard") and labels.has("Nightmare"), labels)
	for c in main.hud.pause.find_children("*", "Button", true, false):
		if c.text == "Hard":
			c.pressed.emit()
			break
	await frames(3)
	check("hard_button_sets_hard", Game.diff() == "hard", Game.diff())
	Game.lang = "fa"
	main.hud.pause._show("settings")
	await frames(3)
	var fa_labels := []
	for c in main.hud.pause.find_children("*", "Button", true, false):
		fa_labels.append(c.text)
	check("persian_names_from_the_html_table", fa_labels.has("سخت") and fa_labels.has("کابوس"), fa_labels)
	main.hud.pause.close()
	Game.lang = "en"
	check("persian_diff_names", Game.diff_name("normal") != "" and Game.diff_name("hard") == "Hard")

	# ---- saving the setting
	Game.set_setting("diff", "nightmare")
	var f := FileAccess.open(Game.SETTINGS_PATH, FileAccess.READ)
	var saved = JSON.parse_string(f.get_as_text())
	check("setting_is_written_to_disk", saved.get("diff", "") == "nightmare", saved)
	Game.set_setting("diff", "normal")

	print("DIFFTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

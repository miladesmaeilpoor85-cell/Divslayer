extends Node
## Regression tests for the Anvil Warden's three-lane forge-furrow attack.

var main: Node
var fails: Array = []
var results := {}

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func check(label: String, ok: bool, info = null) -> void:
	results[label] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(label)
	printerr(("PASS " if ok else "FAIL ") + label + ("" if info == null else "  " + str(info)))

func clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.remove_from_group("enemies")
			e.queue_free()

func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	Game.new_game("warrior")
	main.start_world()
	await frames(5)
	main.goto_map("trial", Vector2(420, 500))
	await frames(5)
	clear_enemies()
	await frames(2)

	var p: Node = main.player
	p.global_position = Vector2(420, 500)
	p.dead = false
	p.invuln = 0.0
	p.statuses.clear()
	Game.hp = Game.max_hp()
	var player_feet: Vector2 = p.global_position
	var target: Vector2 = p.pc()
	var w = main.world
	var bfx: Node = w.bossfx
	var boss: Node = w.spawn_enemy("anvilward", player_feet + Vector2(-220, 25))
	boss.set_physics_process(false)
	boss.gcd = 0.0
	boss.busy = 0.0
	boss.cd.clear()
	boss.staggered = 0.0

	# The Warden alone selects the three parallel, 0.9-second warning lanes.
	var before: int = bfx.tele.size()
	var direction: Vector2 = target - boss.center()
	boss._ai_generic(1.0 / 60.0, direction.length(), direction)
	var marks: Array = []
	for i in range(before, bfx.tele.size()):
		marks.append(bfx.tele[i])
	var correct_marks := marks.size() == 3
	if correct_marks:
		for mark in marks:
			correct_marks = correct_marks and str(mark.get("kind", "")) == "lane"
			correct_marks = correct_marks and is_equal_approx(float(mark.get("total", 0.0)), 0.9)
			correct_marks = correct_marks and is_equal_approx(float(mark.get("w", 0.0)), 48.0)
	check("anvilward_starts_three_warned_furrows", correct_marks and boss.moves.get("furrows", 0) == 1,
		{"marks": marks.size(), "moves": boss.moves})

	# The lanes are parallel and separated by a wide, usable gap.
	var side: Vector2 = direction.normalized().orthogonal()
	p.global_position = player_feet + side * 60.0
	var gap_safe := true
	for mark in marks:
		gap_safe = gap_safe and not bfx.in_lane(mark)
	check("anvilward_furrows_leave_a_dodge_gap", gap_safe)

	# Standing in the central lane takes one hit, applies burn, and cannot be hit
	# repeatedly by the other two callbacks in the same volley.
	p.global_position = player_feet
	p.invuln = 0.0
	p.statuses.clear()
	Game.hp = Game.max_hp()
	var hp_before: float = Game.hp
	var hits_before: int = int(bfx.counts["hits"])
	for mark in marks:
		var fire: Callable = mark["fire"]
		fire.call(mark)
	var hp_lost: float = hp_before - Game.hp
	check("anvilward_furrows_damage_once_and_burn", hp_lost > 0.0 and int(bfx.counts["hits"]) == hits_before + 1
		and p.statuses.has("burn"), {"hp_lost": hp_lost, "statuses": p.statuses})

	# The new move is explicitly scoped to the Anvil Warden; another generic miniboss
	# keeps its existing charge/volley behavior and never selects this skill.
	var other: Node = w.spawn_enemy("captain", player_feet + Vector2(-220, 25))
	other.set_physics_process(false)
	other.gcd = 0.0
	other.busy = 0.0
	other.cd.clear()
	var other_direction: Vector2 = target - other.center()
	other._ai_generic(1.0 / 60.0, other_direction.length(), other_direction)
	check("other_miniboss_does_not_get_forge_furrows", other.moves.get("furrows", 0) == 0)

	bfx.clear()
	print("ANVILWARDTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

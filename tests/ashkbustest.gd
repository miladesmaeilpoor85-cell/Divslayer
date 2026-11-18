extends Node
## Regression tests for Ashkbus's warned Turanian arrowfall.

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

func _watchdog() -> void:
	printerr("ASHKBUSTEST_WATCHDOG: test exceeded 40 seconds")
	get_tree().quit(1)

func run(m: Node) -> void:
	get_tree().create_timer(40.0).timeout.connect(_watchdog)
	print("ASHKBUSTEST_STEP start")
	main = m
	await get_tree().process_frame
	Game.testing = true
	Game.new_game("warrior")
	main.start_world()
	await frames(5)
	print("ASHKBUSTEST_STEP world_started")
	main.goto_map("trial", Vector2(420, 500))
	await frames(5)
	clear_enemies()
	await frames(2)
	print("ASHKBUSTEST_STEP trial_ready")

	var p: Node = main.player
	p.global_position = Vector2(420, 500)
	p.dead = false
	p.invuln = 0.0
	p.blocking = false
	p.statuses.clear()
	Game.hp = Game.max_hp()
	var feet: Vector2 = p.global_position
	var target: Vector2 = p.pc()
	var world = main.world
	var bfx: Node = world.bossfx
	var boss: Node = world.spawn_enemy("captain", feet + Vector2(-230, 25))
	boss.set_physics_process(false)
	boss.gcd = 0.0
	boss.busy = 0.0
	boss.cd.clear()
	boss.staggered = 0.0

	# Ashkbus alone creates three circular arrowfall warnings around the player's last position.
	var tele_before: int = bfx.tele.size()
	var direction: Vector2 = target - boss.center()
	boss._ai_generic(1.0 / 60.0, direction.length(), direction)
	var marks: Array = []
	for i in range(tele_before, bfx.tele.size()):
		marks.append(bfx.tele[i])
	var marks_ok: bool = marks.size() == 3 and boss.moves.get("arrowfall", 0) == 1
	if marks.size() == 3:
		for mark in marks:
			marks_ok = marks_ok and str(mark.get("kind", "")) == "circle"
			marks_ok = marks_ok and is_equal_approx(float(mark.get("r", 0.0)), 30.0)
			marks_ok = marks_ok and is_equal_approx(float(mark.get("total", 0.0)), 0.85)
		marks_ok = marks_ok and is_equal_approx(marks[0]["pos"].distance_to(marks[1]["pos"]), 112.0)
		marks_ok = marks_ok and is_equal_approx(marks[1]["pos"].distance_to(marks[2]["pos"]), 112.0)
	print("ASHKBUSTEST_STEP marks_collected " + str(marks.size()))
	check("ashkbus_marks_three_spaced_arrowfall_targets", marks_ok, {"marks": marks.size(), "moves": boss.moves})

	# The space between neighboring impact circles is wide enough to stand in safely.
	var side: Vector2 = direction.normalized().orthogonal()
	p.global_position = feet + side * 56.0
	var gap_safe: bool = true
	for mark in marks:
		gap_safe = gap_safe and not bfx.in_circle(mark)
	check("ashkbus_arrowfall_leaves_a_walkable_gap", gap_safe)

	# Staggering Ashkbus during the warning cancels the pending arrows.
	var lobs_before_cancel: int = bfx.lobs.size()
	boss.staggered = 0.5
	var first_fire: Callable = marks[0]["fire"]
	first_fire.call(marks[0])
	check("ashkbus_arrowfall_is_canceled_by_stagger", bfx.lobs.size() == lobs_before_cancel)
	boss.staggered = 0.0

	# All three impacts use the arrow visual and one shared volley token.
	for mark in marks:
		var fire: Callable = mark["fire"]
		fire.call(mark)
	print("ASHKBUSTEST_STEP cancellation_checked")
	var new_lobs: Array = bfx.lobs.slice(lobs_before_cancel)
	var arrows_ok: bool = new_lobs.size() == 3
	if new_lobs.size() == 3:
		for lob in new_lobs:
			arrows_ok = arrows_ok and str(lob.get("img", "")) == "arrow"
			arrows_ok = arrows_ok and is_equal_approx(float(lob.get("total", 0.0)), 0.38)
		arrows_ok = arrows_ok and is_same(new_lobs[0]["vol"], new_lobs[1]["vol"])
		arrows_ok = arrows_ok and is_same(new_lobs[1]["vol"], new_lobs[2]["vol"])
	print("ASHKBUSTEST_STEP lobs_collected " + str(new_lobs.size()))
	check("ashkbus_spawns_three_arrow_lobs_with_shared_hit_token", arrows_ok, {"lobs": new_lobs.size()})

	# The player can stay in the lane between the warnings while the arrows land.
	for lob in bfx.lobs:
		lob["t"] = 0.01
	var hp_before_gap: float = Game.hp
	bfx._physics_process(0.02)
	print("ASHKBUSTEST_STEP gap_resolved")
	check("ashkbus_arrowfall_gap_avoids_all_damage", is_equal_approx(Game.hp, hp_before_gap), {"before": hp_before_gap, "after": Game.hp})

	# If multiple arrow impacts overlap the hero, the volley token still permits one hit only.
	bfx.clear()
	p.global_position = feet
	p.invuln = 0.0
	Game.hp = Game.max_hp()
	boss.cd["arrowfall"] = 0.0
	boss.gcd = 0.0
	boss.busy = 0.0
	boss.staggered = 0.0
	tele_before = bfx.tele.size()
	target = p.pc()
	direction = target - boss.center()
	boss._ai_generic(1.0 / 60.0, direction.length(), direction)
	marks.clear()
	for i in range(tele_before, bfx.tele.size()):
		marks.append(bfx.tele[i])
	for mark in marks:
		var fire: Callable = mark["fire"]
		fire.call(mark)
	for lob in bfx.lobs:
		lob["to"] = p.pc()
		lob["t"] = 0.01
	var hp_before_hit: float = Game.hp
	var hits_before: int = int(bfx.counts["hits"])
	bfx._physics_process(0.02)
	print("ASHKBUSTEST_STEP damage_volley_resolved")
	check("ashkbus_arrowfall_shared_volley_deals_at_most_one_hit",
		Game.hp < hp_before_hit and int(bfx.counts["hits"]) == hits_before + 1,
		{"hp_lost": hp_before_hit - Game.hp, "hit_count": int(bfx.counts["hits"]) - hits_before})

	# A different miniboss retains its own move set and never selects Arrowfall.
	bfx.clear()
	var other: Node = world.spawn_enemy("anvilward", feet + Vector2(-230, 25))
	other.set_physics_process(false)
	other.gcd = 0.0
	other.busy = 0.0
	other.cd.clear()
	other.staggered = 0.0
	var other_direction: Vector2 = p.pc() - other.center()
	other._ai_generic(1.0 / 60.0, other_direction.length(), other_direction)
	check("ashkbus_arrowfall_is_exclusive_to_ashkbus", other.moves.get("arrowfall", 0) == 0)
	print("ASHKBUSTEST_STEP isolation_checked")

	bfx.clear()
	clear_enemies()
	print("ASHKBUSTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()

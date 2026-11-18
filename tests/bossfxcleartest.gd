extends Node
## Regression test for transient boss effects being removed at phase changes and boss death.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/bossfxcleartest.gd

const BossFx = preload("res://scripts/bossfx.gd")

var fails: Array = []

func check(label: String, ok: bool, info = null) -> void:
	if not ok:
		fails.append(label)
	printerr(("PASS " if ok else "FAIL ") + label + ("" if info == null else "  " + str(info)))

func run(_main: Node) -> void:
	var fx: Node = BossFx.new()
	add_child(fx)
	await get_tree().process_frame

	# Populate every transient collection, including the two collections that
	# were previously omitted from clear(): live bolts and damaging ground pools.
	fx.tele.append({})
	fx.waves.append({})
	fx.lobs.append({})
	fx.shots.append({})
	fx.pools.append({
		"rect": Rect2(Vector2.ZERO, Vector2(100, 100)),
		"life": 5.0,
		"max": 5.0,
		"type": "poison",
		"tick": 0.8
	})
	fx.laters.append({})

	fx.clear()
	check("clear_removes_telegraphs", fx.tele.is_empty())
	check("clear_removes_waves", fx.waves.is_empty())
	check("clear_removes_lobs", fx.lobs.is_empty())
	check("clear_removes_projectiles", fx.shots.is_empty())
	check("clear_removes_damaging_pools", fx.pools.is_empty() and fx.pool_at(Vector2(50, 50)) == "")
	check("clear_removes_delayed_actions", fx.laters.is_empty())
	check("clear_leaves_no_busy_effects", not fx.busy())

	# clear() is used by both phase transitions and death; repeated calls must
	# remain safe when the first call has already emptied all transient state.
	fx.clear()
	check("clear_is_idempotent", fx.tele.is_empty() and fx.waves.is_empty() and fx.lobs.is_empty()
		and fx.shots.is_empty() and fx.pools.is_empty() and fx.laters.is_empty())

	print("BOSSFXCLEARTEST_JSON " + JSON.stringify({"fails": fails}))
	fx.queue_free()
	get_tree().quit()

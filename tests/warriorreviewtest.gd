extends Node
## Regression coverage for the isolated ImageGen warrior animation review scene.
## godot --headless --fixed-fps 60 --path . -- --test res://tests/warriorreviewtest.gd

var fails: Array = []

func check(label: String, ok: bool, info = null) -> void:
	if not ok:
		fails.append(label)
	printerr(("PASS " if ok else "FAIL ") + label + ("" if info == null else "  " + str(info)))

func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func run(_main: Node) -> void:
	var scene := load("res://scenes/dev/warrior_animation_review.tscn") as PackedScene
	check("review_scene_resource_loads", scene != null)
	if scene == null:
		get_tree().quit(1)
		return
	var review := scene.instantiate()
	add_child(review)
	await frames(3)

	var actor := review.get_node_or_null("Actor") as AnimatedSprite2D
	check("review_actor_exists", actor != null)
	if actor == null or actor.sprite_frames == null:
		get_tree().quit(1)
		return
	var sprite_frames := actor.sprite_frames
	for direction in ["down", "up", "side"]:
		var animation := "walk_" + direction
		check("%s_has_four_walk_frames" % direction,
			sprite_frames.has_animation(animation) and sprite_frames.get_frame_count(animation) == 4)
		var idle := "idle_" + direction
		check("%s_idle_frame_exists" % direction,
			sprite_frames.has_animation(idle) and sprite_frames.get_frame_count(idle) == 1)
		var attack := "attack_" + direction
		check("%s_attack_pose_exists" % direction,
			sprite_frames.has_animation(attack) and sprite_frames.get_frame_count(attack) == 1)

	var atlas := sprite_frames.get_frame_texture("walk_side", 0) as AtlasTexture
	var expected_size := Vector2(Game.manifest["heroes"]["warrior_starter"]["cellW"],
		Game.manifest["heroes"]["warrior_starter"]["cellH"])
	check("atlas_cell_matches_manifest_contract",
		atlas != null and atlas.region.size == expected_size, atlas.region if atlas != null else null)
	var pivot: Array = Game.manifest["heroes"]["warrior_starter"]["pivot"]
	var expected_offset := Vector2(-expected_size.x * float(pivot[0]),
		-expected_size.y * (1.0 - float(pivot[1])))
	check("actor_foot_pivot_matches_manifest", not actor.centered and actor.offset.is_equal_approx(expected_offset),
		{"centered": actor.centered, "offset": actor.offset, "expected": expected_offset})
	check("initial_animation_is_side_walk", actor.animation == "walk_side")

	review._show_walk("up")
	check("up_button_selects_back_walk", actor.animation == "walk_up")
	review._play_attack()
	check("attack_selects_side_pose", actor.animation == "attack_side")
	check("attack_starts_timed_slash_effect", review._slash_time > 0.0 and review._attack_lock > 0.0)
	await frames(30)
	check("attack_returns_to_selected_walk", actor.animation == "walk_up" and review._slash_time == 0.0)

	review.queue_free()
	await frames(1)
	printerr("WARRIOR_REVIEWTEST_JSON " + JSON.stringify({"fails": fails}))
	get_tree().quit(1 if not fails.is_empty() else 0)

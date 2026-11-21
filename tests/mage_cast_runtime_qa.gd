extends Node
## Android-only QA scene. The workflow temporarily selects this scene as the APK entrypoint.
## It exercises the real Mage Starter spell -> cast_done -> Player.cast_front path.

const MainScript = preload("res://tests/mage_cast_runtime_main.gd")

func _ready() -> void:
	call_deferred("_run")

func _physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame

func _process_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func _fail(reason: String) -> void:
	push_error("MAGE_CAST_FRONT_RUNTIME_FAIL: " + reason)

func _run() -> void:
	Game.new_game("mage")
	Game.state["slots"] = ["bolt", "nova"]
	var main = MainScript.new()
	add_child(main)
	await get_tree().process_frame
	Game.mp = Game.max_mp()
	main.start_world()
	await _physics_frames(8)

	var player = main.player
	if player == null or not is_instance_valid(player):
		_fail("Player did not initialize")
		return
	if Game.cls != "mage" or player.sheet != "mage_starter":
		_fail("Expected Mage Starter, got class=%s sheet=%s" % [Game.cls, player.sheet])
		return

	# Remove nearby enemies so the nearest-target auto-aim cannot turn the cast away
	# from the front. No movement input is held: the spell should face down/front.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	await get_tree().process_frame
	player.joy = Vector2.ZERO
	player.move_dir = Vector2.ZERO
	player.moving = false
	player.facing = "down"
	player.attacking = 0.0
	player.blocking = false
	player.sneaking = false
	Game.mp = Game.max_mp()

	var cast_ok: bool = player.caster.cast("bolt")
	if not cast_ok:
		_fail("The Mage Starter bolt spell did not cast successfully")
		return
	if not player._mage_cast_front_active or player.cast_anim == null:
		_fail("Successful spell did not activate the cast-front overlay")
		return
	if player.facing != "down":
		_fail("The spell did not remain front-facing: %s" % player.facing)
		return

	var anim: AnimatedSprite2D = player.cast_anim
	var frames: SpriteFrames = anim.sprite_frames
	var clip_frames := frames.get_frame_count("cast_front") if frames else -1
	var clip_fps := frames.get_animation_speed("cast_front") if frames else -1.0
	var start_ms := Time.get_ticks_msec()
	print("MAGE_CAST_FRONT_DIAG_START playing=%s inside_tree=%s processing=%s process_mode=%d frame_count=%d clip_fps=%.2f speed_scale=%.2f frame=%d progress=%.3f engine_time_scale=%.3f tree_paused=%s" % [
		anim.is_playing(), anim.is_inside_tree(), anim.is_processing(), anim.process_mode,
		clip_frames, clip_fps, anim.speed_scale, anim.frame, anim.frame_progress,
		Engine.time_scale, get_tree().paused
	])

	# Exercise both SceneTree time and a known number of idle frames. This avoids
	# mistaking a timer firing for proof that AnimatedSprite2D has been processed.
	await get_tree().create_timer(0.40, false, false, true).timeout
	await _process_frames(24)
	var elapsed_ms := Time.get_ticks_msec() - start_ms
	print("MAGE_CAST_FRONT_DIAG_AFTER_WAIT elapsed_ms=%d playing=%s inside_tree=%s processing=%s process_mode=%d frame_count=%d clip_fps=%.2f speed_scale=%.2f frame=%d progress=%.3f engine_time_scale=%.3f tree_paused=%s" % [
		elapsed_ms, anim.is_playing(), anim.is_inside_tree(), anim.is_processing(), anim.process_mode,
		clip_frames, clip_fps, anim.speed_scale, anim.frame, anim.frame_progress,
		Engine.time_scale, get_tree().paused
	])

	if not player._mage_cast_front_active or not is_instance_valid(anim):
		_fail("The one-shot ended before the runtime capture")
		return
	if not anim.visible or player.anim.visible:
		_fail("Cast overlay/base sprite visibility state is incorrect")
		return
	if anim.animation != "cast_front" or anim.frame <= 0:
		var frame_before_manual_advance := anim.frame
		anim.advance(0.50)
		print("MAGE_CAST_FRONT_DIAG_AFTER_MANUAL_ADVANCE prior_frame=%d frame=%d progress=%.3f playing=%s" % [
			frame_before_manual_advance, anim.frame, anim.frame_progress, anim.is_playing()
		])
		_fail("The cast-front clip did not advance naturally: animation=%s frame=%d frames=%d fps=%.2f playing=%s processing=%s speed_scale=%.2f progress=%.3f elapsed_ms=%d" % [
			anim.animation, frame_before_manual_advance, clip_frames, clip_fps,
			anim.is_playing(), anim.is_processing(), anim.speed_scale,
			anim.frame_progress, elapsed_ms
		])
		return

	var shot_path := "user://mage-cast-front-active.png"
	var shot := get_viewport().get_texture().get_image()
	if shot == null or shot.save_png(shot_path) != OK:
		_fail("Could not save the active cast-front screenshot")
		return
	print("MAGE_CAST_FRONT_RUNTIME_PASS spell=bolt animation=cast_front frame=%d screenshot=%s" % [
		anim.frame, ProjectSettings.globalize_path(shot_path)
	])

	# Movement must cancel the overlay and restore the standard sprite.
	player.moving = true
	player.move_dir = Vector2.DOWN
	player._animate(Vector2.DOWN)
	if player._mage_cast_front_active or not player.anim.visible:
		_fail("Movement did not cancel the overlay and restore the base sprite")
		return
	print("MAGE_CAST_FRONT_CANCEL_PASS movement=down base_sprite_visible=true")

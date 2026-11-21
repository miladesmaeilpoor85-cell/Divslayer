extends Node
## Android-only QA scene. The workflow temporarily selects this scene as the APK entrypoint.
## It exercises the real Mage Starter spell -> cast_done -> Player.cast_front path.

const MainScript = preload("res://tests/mage_cast_runtime_main.gd")

var _frame_advanced := false
var _frame_advanced_at_ms := 0

func _ready() -> void:
	call_deferred("_run")

func _physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame

func _fail(reason: String) -> void:
	push_error("MAGE_CAST_FRONT_RUNTIME_FAIL: " + reason)

func _on_cast_frame_changed(anim: AnimatedSprite2D) -> void:
	if _frame_advanced or not is_instance_valid(anim) or anim.frame <= 0:
		return
	_frame_advanced = true
	_frame_advanced_at_ms = Time.get_ticks_msec()
	# Hold the first naturally advanced frame only in this QA scene so a slow
	# emulator cannot finish the 1.5s one-shot before the screenshot is saved.
	anim.pause()
	print("MAGE_CAST_FRONT_FRAME_ADVANCED frame=%d progress=%.3f elapsed_ms=%d" % [
		anim.frame, anim.frame_progress, _frame_advanced_at_ms
	])

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
	var started_at := Time.get_ticks_msec()
	print("MAGE_CAST_FRONT_DIAG_START playing=%s inside_tree=%s process_internal=%s process_mode=%d frame_count=%d clip_fps=%.2f speed_scale=%.2f frame=%d progress=%.3f engine_time_scale=%.3f tree_paused=%s" % [
		anim.is_playing(), anim.is_inside_tree(), anim.is_processing_internal(), anim.process_mode,
		clip_frames, clip_fps, anim.speed_scale, anim.frame, anim.frame_progress,
		Engine.time_scale, get_tree().paused
	])

	# Wait for the animation's own frame_changed signal. Do not add a fixed number
	# of process frames: on slower Android emulators those can outlast this one-shot.
	_frame_advanced = false
	_frame_advanced_at_ms = 0
	if not anim.frame_changed.is_connected(_on_cast_frame_changed.bind(anim)):
		anim.frame_changed.connect(_on_cast_frame_changed.bind(anim))
	var wait_frames := 0
	while not _frame_advanced and player._mage_cast_front_active and wait_frames < 60:
		await get_tree().process_frame
		wait_frames += 1
	var elapsed_ms := Time.get_ticks_msec() - started_at

	if not _frame_advanced:
		_fail("No natural frame_changed event: animation=%s frame=%d frames=%d fps=%.2f playing=%s internal_processing=%s speed_scale=%.2f progress=%.3f elapsed_ms=%d tree_paused=%s time_scale=%.3f" % [
			anim.animation, anim.frame, clip_frames, clip_fps,
			anim.is_playing(), anim.is_processing_internal(), anim.speed_scale,
			anim.frame_progress, elapsed_ms, get_tree().paused, Engine.time_scale
		])
		return
	if not player._mage_cast_front_active or not is_instance_valid(anim):
		_fail("The overlay was deactivated before the first advanced frame could be captured")
		return
	if not anim.visible or player.anim.visible or anim.frame <= 0:
		_fail("Cast overlay/base sprite visibility state is incorrect after natural frame advance")
		return
	if anim.animation != "cast_front":
		_fail("Unexpected animation after frame advance: %s" % anim.animation)
		return

	# Let the paused, non-zero frame reach the renderer, then capture it.
	await get_tree().process_frame
	var shot_path := "user://mage-cast-front-active.png"
	var shot := get_viewport().get_texture().get_image()
	if shot == null or shot.save_png(shot_path) != OK:
		_fail("Could not save the active cast-front screenshot")
		return
	print("MAGE_CAST_FRONT_RUNTIME_PASS spell=bolt animation=cast_front frame=%d natural_advance_ms=%d screenshot=%s" % [
		anim.frame, elapsed_ms, ProjectSettings.globalize_path(shot_path)
	])

	# Movement must cancel the overlay and restore the standard sprite.
	player.moving = true
	player.move_dir = Vector2.DOWN
	player._animate(Vector2.DOWN)
	if player._mage_cast_front_active or not player.anim.visible:
		_fail("Movement did not cancel the overlay and restore the base sprite")
		return
	print("MAGE_CAST_FRONT_CANCEL_PASS movement=down base_sprite_visible=true")

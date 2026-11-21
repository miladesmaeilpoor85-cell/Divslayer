extends Node
## Android-only QA scene. The workflow temporarily selects this scene as the APK entrypoint.
## It exercises the real Mage Starter spell -> cast_done -> Player.cast_front path.

signal cast_frame_wait_done

const MainScript = preload("res://tests/mage_cast_runtime_main.gd")

var _cast_frame_anim: AnimatedSprite2D = null
var _cast_frame_advanced := false
var _cast_frame_timeout := false

func _ready() -> void:
	call_deferred("_run")

func _physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame

func _fail(reason: String) -> void:
	push_error("MAGE_CAST_FRONT_RUNTIME_FAIL: " + reason)

func _on_cast_frame_changed() -> void:
	if _cast_frame_advanced or not is_instance_valid(_cast_frame_anim):
		return
	if _cast_frame_anim.frame > 0:
		_cast_frame_advanced = true
		cast_frame_wait_done.emit()

func _on_cast_frame_wait_timeout() -> void:
	if not _cast_frame_advanced:
		_cast_frame_timeout = true
		cast_frame_wait_done.emit()

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

	# Wait for the first real frame-change event, not a fixed number of rendered
	# frames. Software Android emulators can run slowly enough for the whole
	# 1.5-second one-shot to finish before a 24-frame sampling loop completes.
	var anim: AnimatedSprite2D = player.cast_anim
	var frames: SpriteFrames = anim.sprite_frames
	var clip_frames := frames.get_frame_count("cast_front") if frames else -1
	var clip_fps := frames.get_animation_speed("cast_front") if frames else -1.0
	_cast_frame_anim = anim
	_cast_frame_advanced = false
	_cast_frame_timeout = false
	var frame_callback := Callable(self, "_on_cast_frame_changed")
	anim.frame_changed.connect(frame_callback)
	var timeout_timer := get_tree().create_timer(6.0, true, false, true)
	timeout_timer.timeout.connect(_on_cast_frame_wait_timeout, CONNECT_ONE_SHOT)
	print("MAGE_CAST_FRONT_DIAG_START playing=%s inside_tree=%s frame_count=%d clip_fps=%.2f speed_scale=%.2f playing_speed=%.2f frame=%d progress=%.3f engine_time_scale=%.3f tree_paused=%s" % [
		anim.is_playing(), anim.is_inside_tree(), clip_frames, clip_fps,
		anim.speed_scale, anim.get_playing_speed(), anim.frame, anim.frame_progress,
		Engine.time_scale, get_tree().paused
	])
	await cast_frame_wait_done
	if anim.frame_changed.is_connected(frame_callback):
		anim.frame_changed.disconnect(frame_callback)
	if _cast_frame_timeout:
		_fail("Timed out waiting for the first advanced frame: frame=%d progress=%.3f playing=%s playing_speed=%.2f engine_time_scale=%.3f tree_paused=%s" % [
			anim.frame, anim.frame_progress, anim.is_playing(), anim.get_playing_speed(),
			Engine.time_scale, get_tree().paused
		])
		return

	# Capture after the frame containing the frame_changed signal has been drawn.
	await RenderingServer.frame_post_draw
	if not player._mage_cast_front_active or not is_instance_valid(anim):
		_fail("The one-shot ended before the first advanced frame could be captured")
		return
	if not anim.visible or player.anim.visible:
		_fail("Cast overlay/base sprite visibility state is incorrect")
		return
	if anim.animation != "cast_front" or anim.frame <= 0:
		_fail("The cast-front frame changed but was reset before capture: animation=%s frame=%d frames=%d fps=%.2f" % [
			anim.animation, anim.frame, clip_frames, clip_fps
		])
		return

	var shot_path := "user://mage-cast-front-active.png"
	var shot := get_viewport().get_texture().get_image()
	if shot == null or shot.save_png(shot_path) != OK:
		_fail("Could not save the active cast-front screenshot")
		return
	print("MAGE_CAST_FRONT_RUNTIME_PASS spell=bolt animation=cast_front frame=%d frames=%d screenshot=%s" % [
		anim.frame, clip_frames, ProjectSettings.globalize_path(shot_path)
	])

	# Movement must cancel the overlay and restore the standard sprite.
	player.moving = true
	player.move_dir = Vector2.DOWN
	player._animate(Vector2.DOWN)
	if player._mage_cast_front_active or not player.anim.visible:
		_fail("Movement did not cancel the overlay and restore the base sprite")
		return
	print("MAGE_CAST_FRONT_CANCEL_PASS movement=down base_sprite_visible=true")

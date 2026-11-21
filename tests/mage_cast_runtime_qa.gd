extends Node
## Android-only QA scene. The workflow temporarily selects this scene as the APK entrypoint.
## It exercises the real Mage Starter spell -> cast_done -> Player.cast_front path.

const MainScript = preload("res://scripts/main.gd")

func _ready() -> void:
	call_deferred("_run")

func _physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame

func _fail(reason: String) -> void:
	push_error("MAGE_CAST_FRONT_RUNTIME_FAIL: " + reason)

func _run() -> void:
	var main = MainScript.new()
	add_child(main)
	await get_tree().process_frame

	# Main normally creates the title menu first. Remove only that temporary backdrop
	# so this QA scene can start a fresh Mage game without user input.
	if main.menu != null and is_instance_valid(main.menu):
		var menu_layer: Node = main.menu.get_parent()
		main.menu = null
		if is_instance_valid(menu_layer):
			menu_layer.queue_free()
	if main.menu_bg != null and is_instance_valid(main.menu_bg):
		main.menu_bg.queue_free()
		main.menu_bg = null

	Game.new_game("mage")
	Game.state["slots"] = ["bolt", "nova"]
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

	# Wait into the one-shot so the capture is not just its first frame.
	await get_tree().create_timer(0.40, false, false, true).timeout
	if not player._mage_cast_front_active or not is_instance_valid(player.cast_anim):
		_fail("The one-shot ended before the runtime capture")
		return
	if not player.cast_anim.visible or player.anim.visible:
		_fail("Cast overlay/base sprite visibility state is incorrect")
		return
	if player.cast_anim.animation != "cast_front" or player.cast_anim.frame <= 0:
		_fail("The cast-front clip did not advance: animation=%s frame=%d" % [
			player.cast_anim.animation, player.cast_anim.frame
		])
		return

	var shot_path := "user://mage-cast-front-active.png"
	var shot := get_viewport().get_texture().get_image()
	if shot == null or shot.save_png(shot_path) != OK:
		_fail("Could not save the active cast-front screenshot")
		return
	print("MAGE_CAST_FRONT_RUNTIME_PASS spell=bolt animation=cast_front frame=%d screenshot=%s" % [
		player.cast_anim.frame, ProjectSettings.globalize_path(shot_path)
	])

	# Movement must cancel the overlay and restore the standard sprite.
	player.moving = true
	player.move_dir = Vector2.DOWN
	player._animate(Vector2.DOWN)
	if player._mage_cast_front_active or not player.anim.visible:
		_fail("Movement did not cancel the overlay and restore the base sprite")
		return
	print("MAGE_CAST_FRONT_CANCEL_PASS movement=down base_sprite_visible=true")
